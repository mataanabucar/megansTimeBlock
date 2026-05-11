import Foundation

struct MockAIParsingService: AIParsingService {
    func parseTaskCapture(rawText: String, context: AIParsingContext) async throws -> AITaskParseResponse {
        let items = captureItems(from: rawText)
        let candidates = items.map { item in
            candidate(from: item, context: context)
        }

        return AITaskParseResponse(
            tasks: candidates,
            warnings: candidates
                .filter(\.clarificationNeeded)
                .map {
                    AIParseWarning(
                        code: "needs_review",
                        message: "Please review this task before saving.",
                        taskTitle: $0.title
                    )
                },
            friendlySummary: candidates.count == 1
                ? "I organized '\(candidates.first?.title ?? "this task")' for review."
                : "I organized \(candidates.count) tasks for review.",
            needsReview: candidates.contains(where: \.clarificationNeeded)
        )
    }

    // MARK: - Splitting run-on natural speech into items

    private func captureItems(from text: String) -> [String] {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "•", with: "\n")
            .replacingOccurrences(
                of: #"\s+(?:and\s+then|and\s+also|also|plus|then|and)\s+"#,
                with: "\n",
                options: [.regularExpression, .caseInsensitive]
            )

        let connectorSplit = normalized
            .components(separatedBy: CharacterSet(charactersIn: "\n;,."))
            .map(cleanCaptureItem)
            .filter { !$0.isEmpty }

        // Second pass: split run-on chunks by mid-sentence action verbs.
        let actionSplit = connectorSplit.flatMap(splitByMidSentenceActionVerbs)

        guard actionSplit.count > 1 else {
            // Fall back to the trimmed full text (single-task mode).
            return [text.trimmingCharacters(in: .whitespacesAndNewlines)].filter { !$0.isEmpty }
        }

        let actionLikeCount = actionSplit.filter(isActionLike).count
        if actionSplit.count >= 3, actionLikeCount >= 2 {
            return actionSplit
        }
        if actionSplit.count == 2, actionLikeCount == 2 {
            return actionSplit
        }
        return [text.trimmingCharacters(in: .whitespacesAndNewlines)].filter { !$0.isEmpty }
    }

    /// Split "take out trash tomorrow evening give child a bath in the
    /// afternoon go grocery shopping" into separate items by detecting where
    /// a new action verb begins after at least one prior word of context.
    private func splitByMidSentenceActionVerbs(_ chunk: String) -> [String] {
        let trimmed = chunk.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        // Only split chunks that are obviously run-on (≥ 8 words).
        let wordCount = trimmed.split(whereSeparator: { $0.isWhitespace }).count
        guard wordCount >= 8 else { return [trimmed] }

        let actionWords = [
            "take", "give", "go", "make", "do", "pay", "prepare", "cook", "clean",
            "wash", "fold", "call", "text", "email", "send", "buy", "get", "spend",
            "schedule", "book", "organize", "sort", "review", "finish", "start",
            "drop", "bring", "pack", "write", "read", "check", "put", "tackle",
            "tidy", "reset", "pick", "set"
        ].joined(separator: "|")

        // Match an action verb that is NOT at the start of the string,
        // preceded by ≥ 4 word characters (i.e. not just the previous verb).
        let pattern = #"(?<=\w{4})\s+(?=(?:\#(actionWords))\b)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return [trimmed]
        }

        let nsString = trimmed as NSString
        let fullRange = NSRange(location: 0, length: nsString.length)
        let matches = regex.matches(in: trimmed, range: fullRange)
        guard !matches.isEmpty else { return [trimmed] }

        var pieces: [String] = []
        var cursor = 0
        for match in matches {
            let split = match.range.location
            if split > cursor {
                pieces.append(nsString.substring(with: NSRange(location: cursor, length: split - cursor)))
            }
            cursor = match.range.location + match.range.length
        }
        if cursor < nsString.length {
            pieces.append(nsString.substring(with: NSRange(location: cursor, length: nsString.length - cursor)))
        }
        return pieces
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func cleanCaptureItem(_ text: String) -> String {
        text
            .replacingOccurrences(
                of: #"^(?:today|tomorrow|tonight|this\s+morning|this\s+afternoon|this\s+evening)?\s*(?:i\s+)?(?:need|have|want|got|gotta|should)\s+to\s+"#,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
            .trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ".!,;:-")))
    }

    private func isActionLike(_ text: String) -> Bool {
        let lowered = text.lowercased()
        let actionPattern = [
            "take", "cut", "pick", "make", "do", "pay", "prepare", "cook", "clean",
            "wash", "fold", "call", "text", "email", "send", "buy", "get", "go",
            "schedule", "book", "organize", "sort", "review", "finish", "start",
            "drop", "bring", "pack", "write", "read", "check", "spend", "tidy",
            "reset", "tackle", "put"
        ].joined(separator: "|")

        return lowered.range(
            of: #"^(?:\#(actionPattern))\b"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
    }

    // MARK: - Candidate construction

    private func candidate(from rawText: String, context: AIParsingContext) -> AITaskCandidate {
        let hint = NaturalTimeParser.parse(rawText, now: context.currentDate)
        let band = NaturalTimeParser.inferredDurationBand(from: hint.cleanedTitle.isEmpty ? rawText : hint.cleanedTitle)

        // Pick a realistic duration. Use the band's midpoint if we have one.
        // Only fall back to the user's `defaultTaskDuration` when nothing was
        // inferable — this is the fix for "every task became 60 min."
        let duration = max(
            1,
            hint.estimatedMinutes
                ?? band?.midpoint
                ?? minimallyAcceptableDefault(forContext: context)
        )

        let title = hint.cleanedTitle == "Untitled task"
            ? TaskItem.makeTitle(from: rawText)
            : hint.cleanedTitle

        let priority = hint.preferredDate.map {
            Calendar.current.isDateInToday($0) ? PriorityLevel.important : .normal
        } ?? .normal

        let energy: EnergyLevel = {
            if duration <= 10 { return .low }
            if duration <= 30 { return .medium }
            return .high
        }()

        // Surface a startTime only when the parser found a deadline. The
        // scheduler still owns the final placement, but we let the preview
        // hint at e.g. "Today, around 6:00 PM".
        let surfacedStartTime: Date? = nil

        return AITaskCandidate(
            rawText: rawText,
            title: title,
            notes: nil,
            dueDate: hint.preferredDate ?? hint.deadlineTime,
            startDate: hint.preferredDate,
            startTime: surfacedStartTime,
            durationMinutes: duration,
            durationLowerMinutes: band?.lower,
            durationUpperMinutes: band?.upper,
            priority: priority,
            category: inferredCategory(from: rawText),
            reminderPreference: context.userPreferences.defaultReminderStyle,
            recurrence: hint.recurrenceHint,
            confidence: confidence(forTitle: title, hint: hint, band: band),
            clarificationNeeded: title == "Untitled task",
            tinyStep: TaskItem.makeTinyStep(from: rawText),
            shrinkOptions: TaskItem.makeShrinkOptions(from: rawText, estimatedMinutes: duration),
            flexibleWindow: hint.flexibleWindowLabel,
            energyLevel: energy
        )
    }

    /// When neither the explicit minutes nor the inferred band yield a value,
    /// we still want a sensible fallback — but NOT the user's preference of
    /// 60 minutes for every untyped task. Cap at 25 minutes for unknowns so a
    /// brain-dump doesn't compound into an unrealistic plan.
    private func minimallyAcceptableDefault(forContext context: AIParsingContext) -> Int {
        min(context.userPreferences.defaultTaskDuration, 25)
    }

    private func confidence(forTitle title: String, hint: NaturalTimeHint, band: DurationBand?) -> Double {
        if title == "Untitled task" { return 0.45 }
        var score = 0.6
        if hint.flexibleWindowLabel != nil { score += 0.1 }
        if hint.preferredDate != nil { score += 0.1 }
        if hint.deadlineTime != nil { score += 0.1 }
        if band != nil { score += 0.05 }
        return min(0.95, score)
    }

    /// Expanded category inference. Earlier rules first (more specific).
    private func inferredCategory(from text: String) -> TaskCategory {
        let lowered = text.lowercased()

        if lowered.contains("scarlett") || lowered.contains("kid") || lowered.contains("child")
            || lowered.contains("daughter") || lowered.contains("son") || lowered.contains("baby")
            || lowered.contains("with my") {
            return .family
        }
        if lowered.contains("park") || lowered.contains("playground") || lowered.contains("walk") {
            return .wellness
        }
        if lowered.contains("read ") || lowered.contains(" read") || lowered.hasPrefix("read") {
            return .wellness
        }
        if lowered.contains("dinner") || lowered.contains("breakfast") || lowered.contains("lunch")
            || lowered.contains("meal") || lowered.contains("cook") {
            return .meals
        }
        if lowered.contains("meeting") || lowered.contains("daily routine") || lowered.contains("journal")
            || lowered.contains("meditation") {
            return .steadyRoutine
        }
        if lowered.contains("kitchen") || lowered.contains("dish") || lowered.contains("laundry")
            || lowered.contains("vacuum") || lowered.contains("sweep") || lowered.contains("clean")
            || lowered.contains("tidy") || lowered.contains("trash") {
            return .cleaning
        }
        if lowered.contains("bath") || lowered.contains("shower") {
            return .wellness
        }
        if lowered.contains("med") || lowered.contains("pharmacy") {
            return .wellness
        }
        if lowered.contains("bill") || lowered.contains("pay") {
            return .bills
        }
        if lowered.contains("doctor") || lowered.contains("appointment") || lowered.contains("dentist")
            || lowered.contains("vet") {
            return .appointment
        }
        if lowered.contains("grocery") || lowered.contains("groceries") || lowered.contains("store")
            || lowered.contains("pick up") || lowered.contains("errand") || lowered.contains("mall")
            || lowered.contains("target") || lowered.contains("costco") {
            return .errand
        }
        return .other
    }
}
