import Foundation

#if DEBUG
private let DEBUG_AI_PROXY = true
#else
private let DEBUG_AI_PROXY = false
#endif

enum ProxyAIParsingServiceError: LocalizedError {
    case missingEndpoint
    case invalidURL
    case networkFailed
    case invalidResponse
    case invalidJSON
    case missingRequiredParsedTaskFields
    case serverRejected

    var errorDescription: String? {
        switch self {
        case .missingEndpoint:
            return "Add your AI proxy endpoint in Settings before using OpenAI parsing."
        case .invalidURL:
            return "The AI proxy endpoint URL is not valid."
        case .networkFailed, .invalidResponse, .invalidJSON, .missingRequiredParsedTaskFields, .serverRejected:
            return "AI parsing could not complete. You can try again or use manual entry."
        }
    }
}

struct ProxyAIParsingService: AIParsingService {
    private let endpointURLString: String
    private let session: URLSession

    init(endpointURLString: String, session: URLSession = .shared) {
        self.endpointURLString = AIProxyConfiguration.endpointStringByReplacingLegacyEndpoint(endpointURLString)
        self.session = session
    }

    func parseTaskCapture(rawText: String, context: AIParsingContext) async throws -> AITaskParseResponse {
        let endpointURL = try endpointURL()
        print("Gentle Day AI proxy request endpoint: \(AIProxyConfiguration.sanitizedEndpointDescription(endpointURL))")

        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30
        request.httpBody = try JSONEncoder.gentleAI.encode(AITaskParseRequest(rawText: rawText, context: context))

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw ProxyAIParsingServiceError.networkFailed
        }

        logRawResponseBody(data)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProxyAIParsingServiceError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            _ = proxyErrorMessage(from: data)
            throw ProxyAIParsingServiceError.serverRejected
        }

        return try decodeResponse(from: data, originalRawText: rawText, context: context)
    }

    private func endpointURL() throws -> URL {
        let trimmed = endpointURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ProxyAIParsingServiceError.missingEndpoint
        }

        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host?.nilIfBlank != nil else {
            throw ProxyAIParsingServiceError.invalidURL
        }

        if url.path.nilIfBlank == nil {
            return url.appendingPathComponent("api/parse-task")
        }

        return url
    }

    private func decodeResponse(
        from data: Data,
        originalRawText: String,
        context: AIParsingContext
    ) throws -> AITaskParseResponse {
        do {
            let envelope = try JSONDecoder.gentleAI.decode(ProxyTaskParseEnvelope.self, from: data)
            let response = try envelope.makeResponse(originalRawText: originalRawText, context: context)
            guard response.tasks.allSatisfy({ $0.title.nilIfBlank != nil && $0.durationMinutes > 0 }) else {
                throw ProxyAIParsingServiceError.missingRequiredParsedTaskFields
            }
            print("Gentle Day AI decoded task count: \(response.tasks.count)")
            return response
        } catch let error as ProxyAIParsingServiceError {
            throw error
        } catch {
            throw ProxyAIParsingServiceError.invalidJSON
        }
    }

    private func proxyErrorMessage(from data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        if let message = object["message"] as? String {
            return message
        }

        if let error = object["error"] as? String {
            return error
        }

        if let errorObject = object["error"] as? [String: Any],
           let message = errorObject["message"] as? String {
            return message
        }

        return nil
    }

    private func logRawResponseBody(_ data: Data) {
        guard DEBUG_AI_PROXY else { return }

        if let body = String(data: data, encoding: .utf8) {
            print("Gentle Day AI proxy raw response body:\n\(body)")
        } else {
            print("Gentle Day AI proxy raw response body: <non-UTF-8 response, \(data.count) bytes>")
        }
    }
}

private struct ProxyTaskParseEnvelope: Decodable {
    var originalText: String?
    var tasks: [ProxyParsedTask]
    var warnings: [ProxyParseWarning]
    var friendlySummary: String?
    var needsReview: Bool
    var clarificationNeeded: Bool

    enum CodingKeys: String, CodingKey {
        case tasks
        case task
        case parsed
        case rawText
        case rawTextSnake = "raw_text"
        case originalText
        case originalTextSnake = "original_text"
        case warnings
        case friendlySummary
        case friendlySummarySnake = "friendly_summary"
        case summary
        case message
        case needsReview
        case needsReviewSnake = "needs_review"
        case clarificationNeeded
        case clarificationNeededSnake = "clarification_needed"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        originalText = Self.decodeString(
            container,
            keys: [.rawText, .rawTextSnake, .originalText, .originalTextSnake]
        )

        if let decodedTasks = try container.decodeIfPresent([ProxyParsedTask].self, forKey: .tasks) {
            tasks = decodedTasks
        } else if let decodedTask = try container.decodeIfPresent(ProxyParsedTask.self, forKey: .task) {
            tasks = [decodedTask]
        } else if let decodedTasks = try container.decodeIfPresent([ProxyParsedTask].self, forKey: .parsed) {
            tasks = decodedTasks
        } else if let decodedTask = try container.decodeIfPresent(ProxyParsedTask.self, forKey: .parsed) {
            tasks = [decodedTask]
        } else if let rootTask = try? ProxyParsedTask(from: decoder) {
            tasks = [rootTask]
        } else {
            tasks = []
        }

        warnings = (try container.decodeIfPresent([ProxyParseWarning].self, forKey: .warnings)) ?? []
        friendlySummary = Self.decodeString(
            container,
            keys: [.friendlySummary, .friendlySummarySnake, .summary, .message]
        )
        needsReview = Self.decodeBool(container, keys: [.needsReview, .needsReviewSnake]) ?? false
        clarificationNeeded = Self.decodeBool(
            container,
            keys: [.clarificationNeeded, .clarificationNeededSnake]
        ) ?? false
    }

    func makeResponse(originalRawText: String, context: AIParsingContext) throws -> AITaskParseResponse {
        let flattenedTasks = tasks.flatMap(\.flattenedTasks)
        guard !flattenedTasks.isEmpty else {
            throw ProxyAIParsingServiceError.missingRequiredParsedTaskFields
        }

        let candidates = try flattenedTasks.map { try $0.makeCandidate(originalRawText: originalRawText, context: context) }
        let fallbackCandidates = ProxyLegacyTaskSplitter.candidates(
            from: originalRawText.nilIfBlank ?? originalText,
            context: context
        )

        if candidates.count <= 1, fallbackCandidates.count > candidates.count {
            print("Gentle Day AI fallback split task count: \(fallbackCandidates.count)")
            return AITaskParseResponse(
                tasks: fallbackCandidates,
                warnings: warnings.map(\.warning),
                friendlySummary: defaultSummary(for: fallbackCandidates),
                needsReview: needsReview || clarificationNeeded || fallbackCandidates.contains(where: \.clarificationNeeded)
            )
        }

        return AITaskParseResponse(
            tasks: candidates,
            warnings: warnings.map(\.warning),
            friendlySummary: friendlySummary ?? defaultSummary(for: candidates),
            needsReview: needsReview || clarificationNeeded || candidates.contains(where: \.clarificationNeeded)
        )
    }

    private func defaultSummary(for candidates: [AITaskCandidate]) -> String {
        if candidates.count == 1, let title = candidates.first?.title.nilIfBlank {
            return "I organized '\(title)' for review."
        }
        return "I organized \(candidates.count) tasks for review."
    }

    private static func decodeString(
        _ container: KeyedDecodingContainer<CodingKeys>,
        keys: [CodingKeys]
    ) -> String? {
        for key in keys {
            if let value = try? container.decodeIfPresent(String.self, forKey: key),
               let trimmed = value.nilIfBlank {
                return trimmed
            }
        }
        return nil
    }

    private static func decodeBool(
        _ container: KeyedDecodingContainer<CodingKeys>,
        keys: [CodingKeys]
    ) -> Bool? {
        for key in keys {
            if let value = try? container.decodeIfPresent(Bool.self, forKey: key) {
                return value
            }
        }
        return nil
    }
}

private struct ProxyParseWarning: Decodable {
    var code: String
    var message: String
    var taskTitle: String?

    enum CodingKeys: String, CodingKey {
        case code
        case message
        case taskTitle
        case taskTitleSnake = "task_title"
    }

    init(from decoder: Decoder) throws {
        if let string = try? decoder.singleValueContainer().decode(String.self) {
            code = "proxy_warning"
            message = string
            taskTitle = nil
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = (try container.decodeIfPresent(String.self, forKey: .code)) ?? "proxy_warning"
        message = (try container.decodeIfPresent(String.self, forKey: .message)) ?? "Please review this task."
        taskTitle = try container.decodeIfPresent(String.self, forKey: .taskTitle)
        if taskTitle == nil {
            taskTitle = try container.decodeIfPresent(String.self, forKey: .taskTitleSnake)
        }
    }

    var warning: AIParseWarning {
        AIParseWarning(code: code, message: message, taskTitle: taskTitle)
    }
}

private struct ProxyParsedTask: Decodable {
    var rawText: String?
    var title: String?
    var notes: String?
    var dueDate: Date?
    var startDate: Date?
    var startTime: Date?
    var durationMinutes: Int?
    var priority: PriorityLevel?
    var category: TaskCategory?
    var reminderPreference: ReminderStyle?
    var recurrence: String?
    var confidence: Double?
    var clarificationNeeded: Bool
    var tinyStep: String?
    var shrinkOptions: [String]?
    var nestedTasks: [ProxyParsedTask]

    enum CodingKeys: String, CodingKey {
        case tasks
        case subtasks
        case subTasks
        case subTasksSnake = "sub_tasks"
        case rawText
        case rawTextSnake = "raw_text"
        case originalText
        case originalTextSnake = "original_text"
        case originalPhrase
        case originalPhraseSnake = "original_phrase"
        case title
        case cleanedTitle
        case cleanedTitleSnake = "cleaned_title"
        case notes
        case dueDate
        case dueDateSnake = "due_date"
        case dateText
        case dateTextSnake = "date_text"
        case startDate
        case startDateSnake = "start_date"
        case startTime
        case startTimeSnake = "start_time"
        case timeText
        case timeTextSnake = "time_text"
        case durationMinutes
        case durationMinutesSnake = "duration_minutes"
        case estimatedMinutes
        case estimatedMinutesSnake = "estimated_minutes"
        case priority
        case category
        case reminderPreference
        case reminderPreferenceSnake = "reminder_preference"
        case recurrence
        case recurrenceRule
        case recurrenceRuleSnake = "recurrence_rule"
        case confidence
        case clarificationNeeded
        case clarificationNeededSnake = "clarification_needed"
        case needsReview
        case needsReviewSnake = "needs_review"
        case tinyStep
        case tinyStepSnake = "tiny_step"
        case shrinkOptions
        case shrinkOptionsSnake = "shrink_options"
    }

    init?(rawTextOnly: String) {
        guard let rawText = rawTextOnly.nilIfBlank else { return nil }

        self.rawText = rawText
        title = nil
        notes = nil
        dueDate = nil
        startDate = nil
        startTime = nil
        durationMinutes = nil
        priority = nil
        category = nil
        reminderPreference = nil
        recurrence = nil
        confidence = nil
        clarificationNeeded = false
        tinyStep = nil
        shrinkOptions = nil
        nestedTasks = []
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        rawText = Self.decodeString(
            container,
            keys: [.rawText, .rawTextSnake, .originalText, .originalTextSnake, .originalPhrase, .originalPhraseSnake]
        )
        title = Self.decodeString(container, keys: [.title, .cleanedTitle, .cleanedTitleSnake])
        notes = Self.decodeString(container, keys: [.notes])
        dueDate = Self.decodeDate(container, keys: [.dueDate, .dueDateSnake, .dateText, .dateTextSnake])
        startDate = Self.decodeDate(container, keys: [.startDate, .startDateSnake])
        startTime = Self.decodeDate(container, keys: [.startTime, .startTimeSnake, .timeText, .timeTextSnake])
        durationMinutes = Self.decodeInt(container, keys: [.durationMinutes, .durationMinutesSnake, .estimatedMinutes, .estimatedMinutesSnake])
        priority = Self.decodePriority(container, keys: [.priority])
        category = Self.decodeCategory(container, keys: [.category])
        reminderPreference = Self.decodeReminder(container, keys: [.reminderPreference, .reminderPreferenceSnake])
        recurrence = Self.decodeString(container, keys: [.recurrence, .recurrenceRule, .recurrenceRuleSnake])
        confidence = Self.decodeDouble(container, keys: [.confidence])
        clarificationNeeded = Self.decodeBool(
            container,
            keys: [.clarificationNeeded, .clarificationNeededSnake, .needsReview, .needsReviewSnake]
        ) ?? false
        tinyStep = Self.decodeString(container, keys: [.tinyStep, .tinyStepSnake])
        shrinkOptions = Self.decodeStringArray(container, keys: [.shrinkOptions, .shrinkOptionsSnake])
        nestedTasks = Self.decodeTaskArray(
            container,
            keys: [.tasks, .subtasks, .subTasks, .subTasksSnake]
        )

        let structuredNotes = Self.structuredContent(from: notes)
        if !structuredNotes.tasks.isEmpty {
            nestedTasks.append(contentsOf: structuredNotes.tasks)
            notes = structuredNotes.humanNotes
        }
    }

    var flattenedTasks: [ProxyParsedTask] {
        let flattenedNestedTasks = nestedTasks.flatMap(\.flattenedTasks)
        guard title?.nilIfBlank != nil || rawText?.nilIfBlank != nil else {
            return flattenedNestedTasks
        }

        var task = self
        task.nestedTasks = []

        guard !flattenedNestedTasks.isEmpty else {
            return [task]
        }

        return [task] + flattenedNestedTasks
    }

    func makeCandidate(originalRawText: String, context: AIParsingContext) throws -> AITaskCandidate {
        let resolvedRawText = rawText?.nilIfBlank ?? originalRawText
        let parsed = NaturalTimeParser.parse(resolvedRawText, now: context.currentDate)
        let resolvedTitle = title?.nilIfBlank
            ?? (parsed.cleanedTitle == "Untitled task" ? TaskItem.makeTitle(from: resolvedRawText) : parsed.cleanedTitle)

        guard let title = resolvedTitle.nilIfBlank else {
            throw ProxyAIParsingServiceError.missingRequiredParsedTaskFields
        }

        let duration = max(1, durationMinutes ?? context.userPreferences.defaultTaskDuration)

        return AITaskCandidate(
            rawText: resolvedRawText,
            title: title,
            notes: Self.cleanedNotes(notes),
            dueDate: dueDate ?? parsed.preferredDate,
            startDate: startDate,
            startTime: startTime,
            durationMinutes: duration,
            priority: priority ?? .normal,
            category: category ?? .other,
            reminderPreference: reminderPreference ?? context.userPreferences.defaultReminderStyle,
            recurrence: recurrence ?? parsed.recurrenceHint,
            confidence: min(max(confidence ?? 0.72, 0), 1),
            clarificationNeeded: clarificationNeeded,
            tinyStep: tinyStep ?? TaskItem.makeTinyStep(from: resolvedRawText),
            shrinkOptions: shrinkOptions ?? TaskItem.makeShrinkOptions(from: resolvedRawText, estimatedMinutes: duration)
        )
    }

    private static func decodeString(
        _ container: KeyedDecodingContainer<CodingKeys>,
        keys: [CodingKeys]
    ) -> String? {
        for key in keys {
            if let value = try? container.decodeIfPresent(String.self, forKey: key),
               let trimmed = value.nilIfBlank {
                return trimmed
            }
        }
        return nil
    }

    private static func cleanedNotes(_ notes: String?) -> String? {
        guard let notes = notes?.nilIfBlank else { return nil }
        guard let jsonText = jsonText(from: notes) else { return notes }

        let structuredNotes = structuredContent(from: notes)
        if !structuredNotes.tasks.isEmpty {
            return structuredNotes.humanNotes
        }

        guard let data = jsonText.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        guard let extractedNotes = object["notes"] as? String else {
            return nil
        }

        return extractedNotes.nilIfBlank
    }

    private static func decodeTaskArray(
        _ container: KeyedDecodingContainer<CodingKeys>,
        keys: [CodingKeys]
    ) -> [ProxyParsedTask] {
        keys.reduce(into: []) { tasks, key in
            guard let decodedTasks = try? container.decodeIfPresent([ProxyParsedTask].self, forKey: key) else {
                if let decodedStrings = try? container.decodeIfPresent([String].self, forKey: key) {
                    tasks.append(contentsOf: decodedStrings.compactMap(ProxyParsedTask.init(rawTextOnly:)))
                }
                return
            }
            tasks.append(contentsOf: decodedTasks)
        }
    }

    private static func structuredContent(from notes: String?) -> ProxyStructuredTaskContent {
        guard let jsonText = jsonText(from: notes),
              let data = jsonText.data(using: .utf8) else {
            return ProxyStructuredTaskContent(tasks: [], humanNotes: notes?.nilIfBlank)
        }

        let decoder = JSONDecoder.gentleAI
        if let tasks = try? decoder.decode([ProxyParsedTask].self, from: data) {
            return ProxyStructuredTaskContent(tasks: tasks, humanNotes: nil)
        }

        if let envelope = try? decoder.decode(ProxyNestedTaskEnvelope.self, from: data),
           !envelope.tasks.isEmpty {
            return ProxyStructuredTaskContent(tasks: envelope.tasks, humanNotes: envelope.notes)
        }

        if let task = try? decoder.decode(ProxyParsedTask.self, from: data),
           task.title?.nilIfBlank != nil || !task.nestedTasks.isEmpty {
            return ProxyStructuredTaskContent(tasks: [task], humanNotes: nil)
        }

        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let notes = object["notes"] as? String {
            return ProxyStructuredTaskContent(tasks: [], humanNotes: notes.nilIfBlank)
        }

        return ProxyStructuredTaskContent(tasks: [], humanNotes: nil)
    }

    private static func jsonText(from notes: String?) -> String? {
        guard var cleaned = notes?.nilIfBlank else { return nil }

        if cleaned.hasPrefix("```") {
            cleaned = cleaned
                .replacingOccurrences(of: #"^```[A-Za-z0-9_-]*\s*"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: #"\s*```$"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard cleaned.hasPrefix("{") || cleaned.hasPrefix("[") else { return nil }
        return cleaned
    }

    private static func decodeDate(
        _ container: KeyedDecodingContainer<CodingKeys>,
        keys: [CodingKeys]
    ) -> Date? {
        for key in keys {
            if let date = try? container.decodeIfPresent(Date.self, forKey: key) {
                return date
            }
            if let string = try? container.decodeIfPresent(String.self, forKey: key),
               let date = FlexibleProxyDateParser.parse(string) {
                return date
            }
        }
        return nil
    }

    private static func decodeInt(
        _ container: KeyedDecodingContainer<CodingKeys>,
        keys: [CodingKeys]
    ) -> Int? {
        for key in keys {
            if let value = try? container.decodeIfPresent(Int.self, forKey: key) {
                return value
            }
            if let value = try? container.decodeIfPresent(Double.self, forKey: key) {
                return Int(value.rounded())
            }
            if let string = try? container.decodeIfPresent(String.self, forKey: key),
               let value = Int(string.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return value
            }
        }
        return nil
    }

    private static func decodeDouble(
        _ container: KeyedDecodingContainer<CodingKeys>,
        keys: [CodingKeys]
    ) -> Double? {
        for key in keys {
            if let value = try? container.decodeIfPresent(Double.self, forKey: key) {
                return value
            }
            if let string = try? container.decodeIfPresent(String.self, forKey: key),
               let value = Double(string.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return value
            }
        }
        return nil
    }

    private static func decodeBool(
        _ container: KeyedDecodingContainer<CodingKeys>,
        keys: [CodingKeys]
    ) -> Bool? {
        for key in keys {
            if let value = try? container.decodeIfPresent(Bool.self, forKey: key) {
                return value
            }
        }
        return nil
    }

    private static func decodeStringArray(
        _ container: KeyedDecodingContainer<CodingKeys>,
        keys: [CodingKeys]
    ) -> [String]? {
        for key in keys {
            if let values = try? container.decodeIfPresent([String].self, forKey: key) {
                let cleaned = values.compactMap(\.nilIfBlank)
                if !cleaned.isEmpty {
                    return cleaned
                }
            }
        }
        return nil
    }

    private static func decodePriority(
        _ container: KeyedDecodingContainer<CodingKeys>,
        keys: [CodingKeys]
    ) -> PriorityLevel? {
        guard let value = decodeString(container, keys: keys) else { return nil }
        switch normalized(value) {
        case "soft", "low":
            return .soft
        case "important", "high":
            return .important
        case "essential", "mustdo", "must":
            return .essential
        default:
            return .normal
        }
    }

    private static func decodeCategory(
        _ container: KeyedDecodingContainer<CodingKeys>,
        keys: [CodingKeys]
    ) -> TaskCategory? {
        guard let value = decodeString(container, keys: keys) else { return nil }
        switch normalized(value) {
        case "home", "chore", "chores":
            return .home
        case "errand", "errands":
            return .errand
        case "family":
            return .family
        case "money":
            return .money
        case "appointment", "appointments":
            return .appointment
        case "cleaning", "clean":
            return .cleaning
        case "wellness", "health":
            return .wellness
        case "meals", "meal":
            return .meals
        case "bills", "bill":
            return .bills
        case "routine", "habit":
            return .routine
        case "lifeadmin", "personal":
            return .lifeAdmin
        default:
            return .other
        }
    }

    private static func decodeReminder(
        _ container: KeyedDecodingContainer<CodingKeys>,
        keys: [CodingKeys]
    ) -> ReminderStyle? {
        guard let value = decodeString(container, keys: keys) else { return nil }
        return ReminderStyle(rawValue: value)
    }

    private static func normalized(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
            .lowercased()
    }
}

private struct ProxyStructuredTaskContent {
    var tasks: [ProxyParsedTask]
    var humanNotes: String?
}

private struct ProxyNestedTaskEnvelope: Decodable {
    var tasks: [ProxyParsedTask]
    var notes: String?

    enum CodingKeys: String, CodingKey {
        case tasks
        case subtasks
        case subTasks
        case subTasksSnake = "sub_tasks"
        case task
        case parsed
        case notes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        var decodedTasks: [ProxyParsedTask] = []

        for key in [CodingKeys.tasks, .subtasks, .subTasks, .subTasksSnake] {
            if let tasks = try container.decodeIfPresent([ProxyParsedTask].self, forKey: key) {
                decodedTasks.append(contentsOf: tasks)
            }
        }

        if let task = try container.decodeIfPresent(ProxyParsedTask.self, forKey: .task) {
            decodedTasks.append(task)
        }

        if let tasks = try container.decodeIfPresent([ProxyParsedTask].self, forKey: .parsed) {
            decodedTasks.append(contentsOf: tasks)
        } else if let task = try container.decodeIfPresent(ProxyParsedTask.self, forKey: .parsed) {
            decodedTasks.append(task)
        }

        tasks = decodedTasks
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
    }
}

private enum ProxyLegacyTaskSplitter {
    static func candidates(from rawText: String?, context: AIParsingContext) -> [AITaskCandidate] {
        guard let rawText = rawText?.nilIfBlank else { return [] }

        let segments = taskSegments(from: rawText)
        guard segments.count > 1 else { return [] }

        let fullTextHint = NaturalTimeParser.parse(rawText, now: context.currentDate)
        let fallbackDate = fullTextHint.preferredDate

        return segments.map { segment in
            candidate(from: segment, fallbackDate: fallbackDate, context: context)
        }
    }

    private static func taskSegments(from rawText: String) -> [String] {
        let normalized = rawText
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "•", with: "\n")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let splitText = normalized.replacingOccurrences(
            of: #"\s+(?:and\s+then|and\s+also|also|plus|then|and)\s+"#,
            with: "\n",
            options: [.regularExpression, .caseInsensitive]
        )

        let segments = splitText
            .components(separatedBy: CharacterSet(charactersIn: "\n;,"))
            .compactMap(cleanSegment)

        guard segments.count > 1 else { return [] }

        let actionLikeCount = segments.filter(isActionLike).count
        if segments.count >= 3, actionLikeCount >= 2 {
            return segments
        }

        if segments.count == 2, actionLikeCount == 2 {
            return segments
        }

        return []
    }

    private static func cleanSegment(_ value: String) -> String? {
        let cleaned = value
            .replacingOccurrences(
                of: #"^(?:today|tomorrow|tonight|this\s+morning|this\s+afternoon|this\s+evening)?\s*(?:i\s+)?(?:need|have|want|got|gotta|should)\s+to\s+"#,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
            .replacingOccurrences(
                of: #"^(?:and|then|also|plus)\s+"#,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
            .trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ".!,;:-")))

        return cleaned.nilIfBlank
    }

    private static func isActionLike(_ value: String) -> Bool {
        let lowered = value.lowercased()
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

    private static func candidate(
        from rawText: String,
        fallbackDate: Date?,
        context: AIParsingContext
    ) -> AITaskCandidate {
        let hint = NaturalTimeParser.parse(rawText, now: context.currentDate)
        let duration = max(1, hint.estimatedMinutes ?? inferredDuration(from: rawText) ?? context.userPreferences.defaultTaskDuration)
        let dueDate = hint.preferredDate ?? fallbackDate
        let title = title(from: hint.cleanedTitle == "Untitled task" ? rawText : hint.cleanedTitle)

        return AITaskCandidate(
            rawText: rawText,
            title: title,
            notes: nil,
            dueDate: dueDate,
            startDate: dueDate,
            startTime: clockTime(in: rawText, baseDate: dueDate ?? context.currentDate),
            durationMinutes: duration,
            priority: dueDate.map { Calendar.current.isDateInToday($0) ? .important : .normal } ?? .normal,
            category: inferredCategory(from: rawText),
            reminderPreference: context.userPreferences.defaultReminderStyle,
            recurrence: hint.recurrenceHint,
            confidence: 0.66,
            clarificationNeeded: title == "Untitled task",
            tinyStep: TaskItem.makeTinyStep(from: rawText),
            shrinkOptions: TaskItem.makeShrinkOptions(from: rawText, estimatedMinutes: duration)
        )
    }

    private static func title(from value: String) -> String {
        let cleaned = value
            .replacingOccurrences(
                of: #"\b(?:at|by)\s+\d{1,2}(?::\d{2})?\s*(?:am|pm)?\b"#,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
            .replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ".!,;:-")))

        guard let title = cleaned.nilIfBlank else {
            return "Untitled task"
        }

        return title.prefix(1).uppercased() + title.dropFirst()
    }

    private static func inferredDuration(from text: String) -> Int? {
        let lowered = text.lowercased()
        if lowered.contains("dishes") || lowered.contains("trash") { return 10 }
        if lowered.contains("pick up") { return 15 }
        if lowered.contains("dinner") || lowered.contains("cook") || lowered.contains("prepare") { return 30 }
        if lowered.contains("grass") || lowered.contains("lawn") { return 45 }
        return nil
    }

    private static func inferredCategory(from text: String) -> TaskCategory {
        let lowered = text.lowercased()
        if lowered.contains("scarlett") || lowered.contains("kid") || lowered.contains("school") {
            return .family
        }
        if lowered.contains("dish") || lowered.contains("laundry") || lowered.contains("clean") {
            return .cleaning
        }
        if lowered.contains("bill") || lowered.contains("pay") {
            return .bills
        }
        if lowered.contains("dinner") || lowered.contains("meal") || lowered.contains("cook") || lowered.contains("prepare") {
            return .meals
        }
        if lowered.contains("pick up") || lowered.contains("store") || lowered.contains("errand") {
            return .errand
        }
        if lowered.contains("grass") || lowered.contains("lawn") || lowered.contains("trash") {
            return .home
        }
        return .other
    }

    private static func clockTime(in text: String, baseDate: Date) -> Date? {
        guard let regex = try? NSRegularExpression(
            pattern: #"\b(\d{1,2}):(\d{2})\s*(am|pm)?\b|\b(\d{1,2})\s*(am|pm)\b"#,
            options: .caseInsensitive
        ) else {
            return nil
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range) else {
            return nil
        }

        let firstHour = matchString(at: 1, in: text, match: match)
        let firstMinute = matchString(at: 2, in: text, match: match)
        let firstMeridiem = matchString(at: 3, in: text, match: match)
        let secondHour = matchString(at: 4, in: text, match: match)
        let secondMeridiem = matchString(at: 5, in: text, match: match)

        guard var hour = Int(firstHour ?? secondHour ?? "") else { return nil }
        let minute = Int(firstMinute ?? "0") ?? 0
        let meridiem = (firstMeridiem ?? secondMeridiem)?.lowercased()

        if meridiem == "pm", hour < 12 {
            hour += 12
        } else if meridiem == "am", hour == 12 {
            hour = 0
        } else if meridiem == nil, hour > 0, hour < 7 {
            hour += 12
        }

        return Calendar.current.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: baseDate
        )
    }

    private static func matchString(at index: Int, in text: String, match: NSTextCheckingResult) -> String? {
        guard match.numberOfRanges > index,
              match.range(at: index).location != NSNotFound,
              let range = Range(match.range(at: index), in: text) else {
            return nil
        }

        return String(text[range])
    }
}

private enum FlexibleProxyDateParser {
    static func parse(_ value: String?) -> Date? {
        guard let value = value?.nilIfBlank else { return nil }

        for options in isoOptions {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = options
            if let date = formatter.date(from: value) {
                return date
            }
        }

        for format in dateFormats {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = format
            if let date = formatter.date(from: value) {
                return date
            }
        }

        return nil
    }

    private static let isoOptions: [ISO8601DateFormatter.Options] = [
        [.withInternetDateTime, .withFractionalSeconds],
        [.withInternetDateTime],
        [.withFullDate]
    ]

    private static let dateFormats = [
        "yyyy-MM-dd",
        "MM/dd/yyyy",
        "M/d/yyyy",
        "HH:mm",
        "h:mm a",
        "h a"
    ]
}

private extension JSONEncoder {
    static var gentleAI: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}

private extension JSONDecoder {
    static var gentleAI: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
