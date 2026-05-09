import Foundation

struct AIParsingContext: Codable {
    var currentDate: Date
    var timezone: String
    var locale: String
    var planningDay: ScheduleRange
    var planningStyle: PlanningStyle
    var userPreferences: AIPlanningPreferencesSnapshot
    var existingTasks: [AITaskSnapshot]
    var existingScheduleBlocks: [AIScheduleBlockSnapshot]

    init(
        currentDate: Date = Date(),
        timezone: String = TimeZone.current.identifier,
        locale: String = Locale.current.identifier,
        planningDay: ScheduleRange = .today,
        planningStyle: PlanningStyle = .balancedDay,
        preferences: UserPlanningPreferences,
        existingTasks: [TaskItem],
        existingScheduleBlocks: [ScheduleBlock]
    ) {
        self.currentDate = currentDate
        self.timezone = timezone
        self.locale = locale
        self.planningDay = planningDay
        self.planningStyle = planningStyle
        self.userPreferences = AIPlanningPreferencesSnapshot(preferences: preferences)
        self.existingTasks = existingTasks.map(AITaskSnapshot.init(task:))
        self.existingScheduleBlocks = existingScheduleBlocks.map(AIScheduleBlockSnapshot.init(block:))
    }
}

struct AITaskParseRequest: Encodable {
    var rawText: String
    var currentDate: Date
    var timezone: String
    var locale: String
    var planningDay: ScheduleRange
    var planningStyle: PlanningStyle
    var wakeTime: Date
    var sleepTime: Date
    var preferredReminderBehavior: ReminderStyle
    var defaultTaskDuration: Int
    var existingTasks: [AITaskSnapshot]
    var existingScheduleBlocks: [AIScheduleBlockSnapshot]
    var context: AIParsingContext

    init(rawText: String, context: AIParsingContext) {
        self.rawText = rawText
        self.currentDate = context.currentDate
        self.timezone = context.timezone
        self.locale = context.locale
        self.planningDay = context.planningDay
        self.planningStyle = context.planningStyle
        self.wakeTime = context.userPreferences.wakeTime
        self.sleepTime = context.userPreferences.sleepTime
        self.preferredReminderBehavior = context.userPreferences.defaultReminderStyle
        self.defaultTaskDuration = context.userPreferences.defaultTaskDuration
        self.existingTasks = context.existingTasks
        self.existingScheduleBlocks = context.existingScheduleBlocks
        self.context = context
    }
}

struct AITaskParseResponse: Decodable {
    var tasks: [AITaskCandidate]
    var warnings: [AIParseWarning]
    var friendlySummary: String
    var needsReview: Bool
}

struct AITaskCandidate: Decodable, Hashable, Identifiable {
    var rawText: String
    var title: String
    var notes: String?
    var dueDate: Date?
    var startDate: Date?
    var startTime: Date?
    var durationMinutes: Int
    var priority: PriorityLevel
    var category: TaskCategory
    var reminderPreference: ReminderStyle?
    var recurrence: String?
    var confidence: Double
    var clarificationNeeded: Bool
    var tinyStep: String?
    var shrinkOptions: [String]

    var id: String {
        [
            rawText,
            title,
            dueDate?.ISO8601Format() ?? "",
            startDate?.ISO8601Format() ?? "",
            startTime?.ISO8601Format() ?? ""
        ].joined(separator: "|")
    }

    var whenDescription: String {
        let candidateDate = dueDate ?? startDate ?? startTime
        guard let candidateDate else { return "Anytime" }

        var parts: [String] = []
        if Calendar.current.isDateInToday(candidateDate) {
            parts.append("Today")
        } else if Calendar.current.isDateInTomorrow(candidateDate) {
            parts.append("Tomorrow")
        } else {
            parts.append(DateFormatting.shortDate.string(from: candidateDate))
        }

        if startTime != nil {
            parts.append(DateFormatting.shortTime.string(from: candidateDate))
        }

        return parts.joined(separator: " ")
    }

    func makeTaskItem(source: CaptureSource = .typed, createdAt: Date = Date()) -> TaskItem {
        TaskItem(
            rawText: rawText,
            title: title,
            notes: notes ?? "",
            category: category,
            priority: priority,
            energyLevel: durationMinutes <= 10 ? .low : .any,
            estimatedMinutes: max(1, durationMinutes),
            dueDate: dueDate ?? startDate ?? startTime,
            flexibleWindow: startTime.map { DateFormatting.shortTime.string(from: $0) },
            isRecurring: recurrence?.nilIfBlank != nil,
            recurrenceRule: recurrence,
            source: source,
            suggestedTinyStep: tinyStep,
            shrinkOptions: shrinkOptions,
            createdAt: createdAt,
            updatedAt: createdAt
        )
    }
}

struct AIParseWarning: Decodable, Hashable, Identifiable {
    var code: String
    var message: String
    var taskTitle: String?

    var id: String {
        [code, taskTitle ?? "", message].joined(separator: "|")
    }
}
