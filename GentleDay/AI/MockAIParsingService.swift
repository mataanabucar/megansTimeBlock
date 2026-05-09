import Foundation

struct MockAIParsingService: AIParsingService {
    func parseTaskCapture(rawText: String, context: AIParsingContext) async throws -> AITaskParseResponse {
        let candidates = captureItems(from: rawText).map { item in
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

        let items = normalized
            .components(separatedBy: CharacterSet(charactersIn: "\n;,"))
            .map(cleanCaptureItem)
            .filter { !$0.isEmpty }

        guard items.count > 1 else { return items }

        let actionLikeCount = items.filter(isActionLike).count
        if items.count >= 3, actionLikeCount >= 2 {
            return items
        }

        if items.count == 2, actionLikeCount == 2 {
            return items
        }

        return [text.trimmingCharacters(in: .whitespacesAndNewlines)].filter { !$0.isEmpty }
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
            "drop", "bring", "pack", "write", "read", "check"
        ].joined(separator: "|")

        return lowered.range(
            of: #"^(?:\#(actionPattern))\b"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
    }

    private func candidate(from rawText: String, context: AIParsingContext) -> AITaskCandidate {
        let hint = NaturalTimeParser.parse(rawText, now: context.currentDate)
        let duration = max(1, hint.estimatedMinutes ?? context.userPreferences.defaultTaskDuration)
        let title = hint.cleanedTitle == "Untitled task" ? TaskItem.makeTitle(from: rawText) : hint.cleanedTitle

        return AITaskCandidate(
            rawText: rawText,
            title: title,
            notes: nil,
            dueDate: hint.preferredDate,
            startDate: hint.preferredDate,
            startTime: nil,
            durationMinutes: duration,
            priority: hint.preferredDate.map { Calendar.current.isDateInToday($0) ? .important : .normal } ?? .normal,
            category: inferredCategory(from: rawText),
            reminderPreference: context.userPreferences.defaultReminderStyle,
            recurrence: hint.recurrenceHint,
            confidence: title == "Untitled task" ? 0.45 : 0.78,
            clarificationNeeded: title == "Untitled task",
            tinyStep: TaskItem.makeTinyStep(from: rawText),
            shrinkOptions: TaskItem.makeShrinkOptions(from: rawText, estimatedMinutes: duration)
        )
    }

    private func inferredCategory(from text: String) -> TaskCategory {
        let lowered = text.lowercased()
        if lowered.contains("laundry") || lowered.contains("kitchen") || lowered.contains("dish") {
            return .cleaning
        }
        if lowered.contains("bill") || lowered.contains("pay") {
            return .bills
        }
        if lowered.contains("doctor") || lowered.contains("appointment") || lowered.contains("dentist") {
            return .appointment
        }
        if lowered.contains("med") || lowered.contains("pharmacy") {
            return .wellness
        }
        if lowered.contains("grocery") || lowered.contains("store") || lowered.contains("pick up") {
            return .errand
        }
        if lowered.contains("meal") || lowered.contains("dinner") || lowered.contains("cook") {
            return .meals
        }
        return .other
    }
}
