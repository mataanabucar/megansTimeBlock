import Foundation

enum ProxyAIParsingServiceError: LocalizedError {
    case missingEndpoint
    case invalidURL
    case networkFailed
    case invalidResponse
    case invalidJSON
    case missingRequiredParsedTaskFields
    case serverRejected(String)

    private var genericFailureMessage: String {
        "AI parsing could not complete. You can try again or use manual entry."
    }

    var errorDescription: String? {
        switch self {
        case .missingEndpoint:
            return "Add your AI proxy endpoint in Settings before using OpenAI parsing."
        case .invalidURL:
            return "The AI proxy endpoint URL is not valid."
        case .networkFailed, .invalidResponse, .invalidJSON, .missingRequiredParsedTaskFields:
            return genericFailureMessage
        case let .serverRejected(message):
            guard let message = message.nilIfBlank else { return genericFailureMessage }
            return "AI parsing could not complete. \(message)"
        }
    }
}

typealias OpenAIProxyParsingServiceError = ProxyAIParsingServiceError

struct ProxyAIParsingService: AIParsingService {
    private enum Route {
        case parseTask
        case buildSchedule

        var pathComponent: String {
            switch self {
            case .parseTask:
                return "parse-task"
            case .buildSchedule:
                return "build-schedule"
            }
        }
    }

    private let endpointURLString: String
    private let session: URLSession

    init(endpointURLString: String, session: URLSession = .shared) {
        self.endpointURLString = endpointURLString
        self.session = session
    }

    func parseTaskCapture(rawText: String, context: AIPlanningContext) async throws -> AITaskParseResponse {
        let request = AITaskParseRequest(rawText: rawText, context: context)
        let data = try await sendData(request, route: .parseTask)
        return try decodeTaskParseResponse(
            from: data,
            originalRawText: rawText,
            context: context
        )
    }

    func buildSchedule(request: AIScheduleBuildRequest) async throws -> AIScheduleBuildResponse {
        let data = try await sendData(request, route: .buildSchedule)
        do {
            return try JSONDecoder.gentleAI.decode(AIScheduleBuildResponse.self, from: data)
        } catch {
            throw ProxyAIParsingServiceError.invalidJSON
        }
    }

    private func sendData<RequestBody: Encodable>(
        _ body: RequestBody,
        route: Route
    ) async throws -> Data {
        let endpointURL = try endpointURL(for: route)
        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30

        do {
            request.httpBody = try JSONEncoder.gentleAI.encode(body)
        } catch {
            throw ProxyAIParsingServiceError.invalidJSON
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw ProxyAIParsingServiceError.networkFailed
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProxyAIParsingServiceError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = serverMessage(from: data)
                ?? "The AI proxy returned status \(httpResponse.statusCode)."
            throw ProxyAIParsingServiceError.serverRejected(message)
        }

        guard JSONSerialization.isValidJSONObjectForDecoding(data) else {
            throw ProxyAIParsingServiceError.invalidJSON
        }

        return data
    }

    private func endpointURL(for route: Route) throws -> URL {
        let trimmed = endpointURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ProxyAIParsingServiceError.missingEndpoint
        }

        guard let baseURL = URL(string: trimmed),
              let scheme = baseURL.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              baseURL.host?.nilIfBlank != nil else {
            throw ProxyAIParsingServiceError.invalidURL
        }

        let lastPath = baseURL.lastPathComponent.lowercased()
        switch route {
        case .parseTask:
            if ["parse", "parse-task"].contains(lastPath) {
                return baseURL
            }
            return baseURL.appendingPathComponent(route.pathComponent)

        case .buildSchedule:
            if lastPath == route.pathComponent {
                return baseURL
            }
            if ["parse", "parse-task"].contains(lastPath) {
                return baseURL.deletingLastPathComponent().appendingPathComponent(route.pathComponent)
            }
            return baseURL.appendingPathComponent(route.pathComponent)
        }
    }

    private func decodeTaskParseResponse(
        from data: Data,
        originalRawText: String,
        context: AIPlanningContext
    ) throws -> AITaskParseResponse {
        if let strictResponse = try? JSONDecoder.gentleAI.decode(AITaskParseResponse.self, from: data) {
            try validate(strictResponse)
            return strictResponse
        }

        do {
            let hostedResponse = try JSONDecoder.gentleAI.decode(
                HostedTaskParseEnvelope.self,
                from: data
            )
            return try hostedResponse.makeResponse(
                originalRawText: originalRawText,
                context: context
            )
        } catch let error as ProxyAIParsingServiceError {
            throw error
        } catch {
            throw ProxyAIParsingServiceError.invalidJSON
        }
    }

    private func validate(_ response: AITaskParseResponse) throws {
        for task in response.tasks {
            guard task.cleanedTitle.nilIfBlank != nil,
                  task.estimatedMinutes > 0 else {
                throw ProxyAIParsingServiceError.missingRequiredParsedTaskFields
            }
        }
    }

    private func serverMessage(from data: Data) -> String? {
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let message = object["message"] as? String, !message.isEmpty {
                return message
            }
            if let error = object["error"] as? String, !error.isEmpty {
                return error
            }
            if let errorObject = object["error"] as? [String: Any],
               let message = errorObject["message"] as? String,
               !message.isEmpty {
                return message
            }
        }

        guard let string = String(data: data, encoding: .utf8)?.nilIfBlank else {
            return nil
        }
        return string
    }
}

typealias OpenAIProxyParsingService = ProxyAIParsingService

private struct HostedTaskParseEnvelope: Decodable {
    var tasks: [HostedParsedTask]
    var warnings: [HostedImportWarning]
    var friendlySummary: String?
    var needsReview: Bool
    var clarificationNeeded: Bool

    enum CodingKeys: String, CodingKey {
        case tasks
        case task
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

        if let decodedTasks = try container.decodeIfPresent([HostedParsedTask].self, forKey: .tasks) {
            tasks = decodedTasks
        } else if let decodedTask = try container.decodeIfPresent(HostedParsedTask.self, forKey: .task) {
            tasks = [decodedTask]
        } else if let decodedTask = try? HostedParsedTask(from: decoder) {
            tasks = [decodedTask]
        } else {
            tasks = []
        }

        warnings = (try container.decodeIfPresent([HostedImportWarning].self, forKey: .warnings)) ?? []
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

    func makeResponse(
        originalRawText: String,
        context: AIPlanningContext
    ) throws -> AITaskParseResponse {
        guard !tasks.isEmpty else {
            if needsReview || clarificationNeeded {
                let warning = AIImportWarning(
                    code: "clarification_needed",
                    message: friendlySummary ?? "I need a little more detail before importing this task.",
                    taskTitle: nil
                )
                return AITaskParseResponse(
                    tasks: [],
                    warnings: warnings.map(\.aiWarning) + [warning],
                    friendlySummary: warning.message,
                    needsReview: true
                )
            }
            throw ProxyAIParsingServiceError.missingRequiredParsedTaskFields
        }

        let candidates = try tasks.map { hostedTask in
            try hostedTask.makeCandidate(
                originalRawText: originalRawText,
                context: context
            )
        }
        let responseWarnings = warnings.map(\.aiWarning)
        let responseNeedsReview = needsReview
            || clarificationNeeded
            || candidates.contains(where: \.needsReview)

        return AITaskParseResponse(
            tasks: candidates,
            warnings: responseWarnings,
            friendlySummary: friendlySummary ?? Self.defaultSummary(for: candidates),
            needsReview: responseNeedsReview
        )
    }

    private static func defaultSummary(for candidates: [AITaskCandidate]) -> String {
        if candidates.count == 1, let title = candidates.first?.cleanedTitle.nilIfBlank {
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
            if let string = try? container.decodeIfPresent(String.self, forKey: key) {
                switch string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
                case "true", "yes", "1":
                    return true
                case "false", "no", "0":
                    return false
                default:
                    break
                }
            }
        }
        return nil
    }
}

private struct HostedImportWarning: Decodable {
    var code: String
    var message: String
    var taskTitle: String?

    enum CodingKeys: String, CodingKey {
        case code
        case message
        case taskTitle
        case taskTitleSnake = "task_title"
        case title
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
        if taskTitle == nil {
            taskTitle = try container.decodeIfPresent(String.self, forKey: .title)
        }
    }

    var aiWarning: AIImportWarning {
        AIImportWarning(
            code: code.nilIfBlank ?? "proxy_warning",
            message: message.nilIfBlank ?? "Please review this task.",
            taskTitle: taskTitle?.nilIfBlank
        )
    }
}

private struct HostedParsedTask: Decodable {
    var rawText: String?
    var title: String?
    var notes: String?
    var dueDateText: String?
    var startDateText: String?
    var startTimeText: String?
    var preferredDateText: String?
    var preferredDayText: String?
    var preferredWindowText: String?
    var flexibleWindowLabel: String?
    var durationMinutes: Int?
    var priorityText: String?
    var categoryText: String?
    var recurrenceText: String?
    var confidence: Double?
    var clarificationNeeded: Bool
    var needsReview: Bool
    var tinyStep: String?
    var shrinkOptions: [String]?
    var scheduleRule: AIScheduleRule?
    var isRecurring: Bool?

    enum CodingKeys: String, CodingKey {
        case rawText
        case rawTextSnake = "raw_text"
        case originalPhrase = "originalPhrase"
        case originalPhraseSnake = "original_phrase"
        case cleanedTitle
        case cleanedTitleSnake = "cleaned_title"
        case title
        case notes
        case dueDate
        case dueDateSnake = "due_date"
        case startDate
        case startDateSnake = "start_date"
        case startTime
        case startTimeSnake = "start_time"
        case preferredDate
        case preferredDateSnake = "preferred_date"
        case preferredDayOfWeek
        case preferredDayOfWeekSnake = "preferred_day_of_week"
        case preferredWindow
        case preferredWindowSnake = "preferred_window"
        case flexibleWindowLabel
        case flexibleWindowLabelSnake = "flexible_window_label"
        case durationMinutes
        case durationMinutesSnake = "duration_minutes"
        case estimatedMinutes
        case estimatedMinutesSnake = "estimated_minutes"
        case priority
        case category
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
        case scheduleRule
        case scheduleRuleSnake = "schedule_rule"
        case isRecurring
        case isRecurringSnake = "is_recurring"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        rawText = Self.decodeString(
            container,
            keys: [.rawText, .rawTextSnake, .originalPhrase, .originalPhraseSnake]
        )
        title = Self.decodeString(
            container,
            keys: [.cleanedTitle, .cleanedTitleSnake, .title]
        )
        notes = Self.decodeString(container, keys: [.notes])
        dueDateText = Self.decodeString(container, keys: [.dueDate, .dueDateSnake])
        startDateText = Self.decodeString(container, keys: [.startDate, .startDateSnake])
        startTimeText = Self.decodeString(container, keys: [.startTime, .startTimeSnake])
        preferredDateText = Self.decodeString(container, keys: [.preferredDate, .preferredDateSnake])
        preferredDayText = Self.decodeString(container, keys: [.preferredDayOfWeek, .preferredDayOfWeekSnake])
        preferredWindowText = Self.decodeString(container, keys: [.preferredWindow, .preferredWindowSnake])
        flexibleWindowLabel = Self.decodeString(container, keys: [.flexibleWindowLabel, .flexibleWindowLabelSnake])
        durationMinutes = Self.decodeInt(
            container,
            keys: [.durationMinutes, .durationMinutesSnake, .estimatedMinutes, .estimatedMinutesSnake]
        )
        priorityText = Self.decodeString(container, keys: [.priority])
        categoryText = Self.decodeString(container, keys: [.category])
        recurrenceText = Self.decodeString(container, keys: [.recurrence, .recurrenceRule, .recurrenceRuleSnake])
        confidence = Self.decodeDouble(container, keys: [.confidence])
        clarificationNeeded = Self.decodeBool(
            container,
            keys: [.clarificationNeeded, .clarificationNeededSnake]
        ) ?? false
        needsReview = Self.decodeBool(container, keys: [.needsReview, .needsReviewSnake]) ?? false
        tinyStep = Self.decodeString(container, keys: [.tinyStep, .tinyStepSnake])
        shrinkOptions = Self.decodeStringArray(container, keys: [.shrinkOptions, .shrinkOptionsSnake])
        scheduleRule = try container.decodeIfPresent(AIScheduleRule.self, forKey: .scheduleRule)
        if scheduleRule == nil {
            scheduleRule = try container.decodeIfPresent(AIScheduleRule.self, forKey: .scheduleRuleSnake)
        }
        isRecurring = Self.decodeBool(container, keys: [.isRecurring, .isRecurringSnake])
    }

    func makeCandidate(
        originalRawText: String,
        context: AIPlanningContext
    ) throws -> AITaskCandidate {
        guard let cleanedTitle = title?.nilIfBlank else {
            throw ProxyAIParsingServiceError.missingRequiredParsedTaskFields
        }

        let resolvedRawText = rawText?.nilIfBlank ?? originalRawText
        let naturalTime = NaturalTimeParser.parse(resolvedRawText, now: context.currentDate)
        let startDate = FlexibleProxyDateParser.parseDate(startDateText)
        let startDateTime = FlexibleProxyDateParser.parseStartTime(
            startTimeText,
            on: startDate ?? context.currentDate
        )
        let dueDate = FlexibleProxyDateParser.parseDate(dueDateText)
        let preferredDate = FlexibleProxyDateParser.parseDate(preferredDateText)
        let resolvedPreferredDate = dueDate
            ?? startDateTime
            ?? startDate
            ?? preferredDate
            ?? naturalTime.preferredDate
        let resolvedWindow = Self.flexibleWindow(from: preferredWindowText)
            ?? startDateTime.map(Self.inferredWindow)
            ?? naturalTime.preferredWindow
        let resolvedWeekday = Self.weekday(from: preferredDayText)
            ?? naturalTime.preferredDayOfWeek
        let resolvedMinutes = max(1, durationMinutes ?? context.userPreferences.defaultTaskDuration)
        let resolvedConfidence = min(max(confidence ?? 0.72, 0), 1)
        let hasExplicitDate = dueDate != nil || startDate != nil || startDateTime != nil || preferredDate != nil
        let hasExplicitWindow = preferredWindowText?.nilIfBlank != nil || startDateTime != nil
        let resolvedScheduleRule = scheduleRule ?? AIScheduleRule(
            canScheduleToday: resolvedPreferredDate.map { Calendar.current.isDateInToday($0) }
                ?? naturalTime.canScheduleToday,
            canScheduleThisWeek: resolvedPreferredDate.map { Self.isWithinThisWeek($0, now: context.currentDate) }
                ?? naturalTime.canScheduleThisWeek,
            mustRespectDate: hasExplicitDate || naturalTime.mustRespectDate,
            mustRespectDay: resolvedWeekday != nil || naturalTime.mustRespectDay,
            mustRespectWindow: hasExplicitWindow || naturalTime.mustRespectWindow,
            allowFlexiblePlacement: naturalTime.allowFlexiblePlacement
                && !hasExplicitDate
                && !hasExplicitWindow
                && resolvedWeekday == nil
        )
        let reviewNeeded = needsReview || clarificationNeeded || resolvedConfidence < 0.55

        return AITaskCandidate(
            rawText: resolvedRawText,
            cleanedTitle: cleanedTitle,
            notes: notes,
            category: Self.category(from: categoryText),
            priority: Self.priority(from: priorityText),
            energyLevel: resolvedMinutes <= 10 ? .quickWin : nil,
            estimatedMinutes: resolvedMinutes,
            preferredDate: resolvedPreferredDate,
            preferredDayOfWeek: resolvedWeekday,
            preferredWindow: resolvedWindow,
            flexibleWindowLabel: flexibleWindowLabel
                ?? resolvedWindow?.title
                ?? startDateTime.map { DateFormatting.shortTime.string(from: $0) },
            dueDate: dueDate ?? resolvedPreferredDate,
            isRecurring: isRecurring ?? (recurrenceText?.nilIfBlank != nil),
            recurrenceRule: recurrenceText,
            tinyStep: tinyStep ?? TaskItem.makeTinyStep(from: resolvedRawText),
            shrinkOptions: shrinkOptions ?? TaskItem.makeShrinkOptions(
                from: resolvedRawText,
                estimatedMinutes: resolvedMinutes
            ),
            confidence: resolvedConfidence,
            needsReview: reviewNeeded,
            friendlyNote: clarificationNeeded ? "Please review this one before saving." : nil,
            scheduleRule: resolvedScheduleRule
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
            if let string = try? container.decodeIfPresent(String.self, forKey: key) {
                switch string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
                case "true", "yes", "1":
                    return true
                case "false", "no", "0":
                    return false
                default:
                    break
                }
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
            if let value = try? container.decodeIfPresent(String.self, forKey: key),
               let trimmed = value.nilIfBlank {
                return [trimmed]
            }
        }
        return nil
    }

    private static func category(from rawValue: String?) -> TaskCategory {
        switch normalized(rawValue) {
        case "home":
            return .home
        case "errand", "errands":
            return .errand
        case "family":
            return .family
        case "health", "wellness":
            return .health
        case "money", "bill", "bills":
            return .money
        case "appointment", "appointments":
            return .appointment
        case "meal", "meals":
            return .meal
        case "cleaning", "clean":
            return .cleaning
        case "reminder", "reminders":
            return .reminder
        case "habit", "routine":
            return .habit
        case "other":
            return .other
        default:
            return .personal
        }
    }

    private static func priority(from rawValue: String?) -> PriorityLevel {
        switch normalized(rawValue) {
        case "low", "soft":
            return .low
        case "high", "important":
            return .high
        case "mustdo", "must":
            return .mustDo
        default:
            return .normal
        }
    }

    private static func weekday(from rawValue: String?) -> Weekday? {
        guard let rawValue else { return nil }
        return Weekday(rawValue: normalized(rawValue))
    }

    private static func flexibleWindow(from rawValue: String?) -> FlexibleWindow? {
        guard let rawValue else { return nil }
        switch normalized(rawValue) {
        case "morning":
            return .morning
        case "midday", "noon", "lunch":
            return .midday
        case "afternoon":
            return .afternoon
        case "afterwork":
            return .afterWork
        case "evening", "tonight", "night":
            return .evening
        case "beforebed", "bedtime":
            return .beforeBed
        case "anytime", "any":
            return .anytime
        default:
            return FlexibleWindow.fromLegacyLabel(rawValue)
        }
    }

    private static func inferredWindow(for date: Date) -> FlexibleWindow {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<11:
            return .morning
        case 11..<13:
            return .midday
        case 13..<17:
            return .afternoon
        case 17..<21:
            return .evening
        default:
            return .beforeBed
        }
    }

    private static func isWithinThisWeek(_ date: Date, now: Date) -> Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        guard let end = calendar.date(byAdding: .day, value: 7, to: today) else {
            return false
        }
        return date >= today && date < end
    }

    private static func normalized(_ rawValue: String?) -> String {
        rawValue?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
            .lowercased() ?? ""
    }
}

private enum FlexibleProxyDateParser {
    static func parseDate(_ value: String?) -> Date? {
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

    static func parseStartTime(_ value: String?, on day: Date) -> Date? {
        guard let value = value?.nilIfBlank else { return nil }
        if let date = parseDate(value) {
            return date
        }

        for format in timeFormats {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = format
            if let time = formatter.date(from: value) {
                return DateFormatting.combine(day: day, time: time)
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
        "M/d/yyyy"
    ]

    private static let timeFormats = [
        "HH:mm",
        "HH:mm:ss",
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

private extension JSONSerialization {
    static func isValidJSONObjectForDecoding(_ data: Data) -> Bool {
        (try? jsonObject(with: data)) != nil
    }
}
