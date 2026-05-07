import Foundation

struct AIPlanningContext: Codable {
    var currentDate: Date
    var timezoneIdentifier: String
    var localeIdentifier: String
    var scheduleRange: ScheduleRange
    var planningStyle: PlanningStyle
    var userPreferences: AIUserPreferencesSnapshot
    var existingTasks: [AITaskContextSnapshot]
    var existingScheduleBlocks: [AIScheduleBlockContextSnapshot]

    init(
        currentDate: Date = Date(),
        timezoneIdentifier: String = TimeZone.current.identifier,
        localeIdentifier: String = Locale.current.identifier,
        scheduleRange: ScheduleRange,
        planningStyle: PlanningStyle,
        userPreferences: UserPlanningPreferences,
        existingTasks: [TaskItem],
        existingScheduleBlocks: [ScheduleBlock]
    ) {
        self.currentDate = currentDate
        self.timezoneIdentifier = timezoneIdentifier
        self.localeIdentifier = localeIdentifier
        self.scheduleRange = scheduleRange
        self.planningStyle = planningStyle
        self.userPreferences = AIUserPreferencesSnapshot(preferences: userPreferences)
        self.existingTasks = existingTasks.map(AITaskContextSnapshot.init(task:))
        self.existingScheduleBlocks = existingScheduleBlocks.map(AIScheduleBlockContextSnapshot.init(block:))
    }
}

struct AITaskParseRequest: Codable {
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
    var existingTasks: [AITaskContextSnapshot]
    var existingScheduleBlocks: [AIScheduleBlockContextSnapshot]
    var context: AIPlanningContext

    init(rawText: String, context: AIPlanningContext) {
        self.rawText = rawText
        self.currentDate = context.currentDate
        self.timezone = context.timezoneIdentifier
        self.locale = context.localeIdentifier
        self.planningDay = context.scheduleRange
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

struct AITaskParseResponse: Codable {
    var tasks: [AITaskCandidate]
    var warnings: [AIImportWarning]
    var friendlySummary: String
    var needsReview: Bool
}

struct AITaskCandidate: Codable, Hashable, Identifiable {
    var rawText: String
    var cleanedTitle: String
    var notes: String?
    var category: TaskCategory
    var priority: PriorityLevel
    var energyLevel: EnergyLevel?
    var estimatedMinutes: Int
    var preferredDate: Date?
    var preferredDayOfWeek: Weekday?
    var preferredWindow: FlexibleWindow?
    var flexibleWindowLabel: String?
    var dueDate: Date?
    var isRecurring: Bool
    var recurrenceRule: String?
    var tinyStep: String?
    var shrinkOptions: [String]
    var confidence: Double
    var needsReview: Bool
    var friendlyNote: String?
    var scheduleRule: AIScheduleRule

    var id: String {
        [
            rawText,
            cleanedTitle,
            preferredDate?.ISO8601Format() ?? "",
            preferredDayOfWeek?.rawValue ?? "",
            preferredWindow?.rawValue ?? ""
        ].joined(separator: "|")
    }

    var whenDescription: String {
        var parts: [String] = []
        if let preferredDate {
            if Calendar.current.isDateInToday(preferredDate) {
                parts.append("Today")
            } else if Calendar.current.isDateInTomorrow(preferredDate) {
                parts.append("Tomorrow")
            } else {
                parts.append(DateFormatting.shortDate.string(from: preferredDate))
            }
        } else if let preferredDayOfWeek {
            parts.append(preferredDayOfWeek.title)
        }

        if let preferredWindow {
            parts.append(preferredWindow.title)
        } else if let flexibleWindowLabel = flexibleWindowLabel?.nilIfBlank {
            parts.append(flexibleWindowLabel)
        }

        return parts.isEmpty ? "Anytime" : parts.joined(separator: " ")
    }
}

struct AIScheduleRule: Codable, Hashable {
    var canScheduleToday: Bool
    var canScheduleThisWeek: Bool
    var mustRespectDate: Bool
    var mustRespectDay: Bool
    var mustRespectWindow: Bool
    var allowFlexiblePlacement: Bool
}

struct AIImportWarning: Codable, Hashable, Identifiable {
    var code: String
    var message: String
    var taskTitle: String?

    var id: String {
        [code, taskTitle ?? "", message].joined(separator: "|")
    }
}

struct AIScheduleBuildRequest: Codable {
    var tasks: [AITaskContextSnapshot]
    var existingBlocks: [AIScheduleBlockContextSnapshot]
    var preferences: AIUserPreferencesSnapshot
    var range: ScheduleRange
    var style: PlanningStyle
    var currentDate: Date
    var timezoneIdentifier: String

    init(
        tasks: [TaskItem],
        existingBlocks: [ScheduleBlock],
        preferences: UserPlanningPreferences,
        range: ScheduleRange,
        style: PlanningStyle,
        currentDate: Date = Date(),
        timezoneIdentifier: String = TimeZone.current.identifier
    ) {
        self.tasks = tasks.map(AITaskContextSnapshot.init(task:))
        self.existingBlocks = existingBlocks.map(AIScheduleBlockContextSnapshot.init(block:))
        self.preferences = AIUserPreferencesSnapshot(preferences: preferences)
        self.range = range
        self.style = style
        self.currentDate = currentDate
        self.timezoneIdentifier = timezoneIdentifier
    }
}

struct AIScheduleBuildResponse: Codable {
    var proposedBlocks: [AIScheduleBlockCandidate]
    var unscheduledTaskIds: [UUID]
    var carriedForwardTaskIds: [UUID]
    var warnings: [AIImportWarning]
    var friendlySummary: String
}

struct AIScheduleBlockCandidate: Codable, Hashable, Identifiable {
    var taskId: UUID?
    var title: String
    var startTime: Date
    var endTime: Date
    var flexibleWindowLabel: String
    var category: TaskCategory
    var reminderStyle: ReminderStyle
    var aiReason: String?

    var id: String {
        [
            taskId?.uuidString ?? "",
            title,
            startTime.ISO8601Format(),
            endTime.ISO8601Format()
        ].joined(separator: "|")
    }
}

struct AITaskContextSnapshot: Codable, Identifiable {
    var id: UUID
    var rawText: String
    var title: String
    var notes: String
    var category: TaskCategory
    var priority: PriorityLevel
    var energyLevel: EnergyLevel
    var estimatedMinutes: Int
    var preferredDate: Date?
    var dueDate: Date?
    var preferredDayOfWeek: Weekday?
    var preferredWindow: FlexibleWindow?
    var flexibleWindowLabel: String?
    var isRecurring: Bool
    var recurrenceRule: String?
    var status: TaskStatus
    var source: CaptureSource
    var suggestedTinyStep: String
    var shrinkOptions: [String]
    var confidence: Double
    var friendlyNote: String?
    var scheduleRule: AIScheduleRule
}

struct AIScheduleBlockContextSnapshot: Codable, Identifiable {
    var id: UUID
    var taskId: UUID?
    var title: String
    var startTime: Date
    var endTime: Date
    var flexibleWindowLabel: String
    var category: TaskCategory
    var status: BlockStatus
    var reminderStyle: ReminderStyle
    var snoozeMinutes: Int
    var isLocked: Bool
    var aiReason: String
}

struct AIUserPreferencesSnapshot: Codable {
    var wakeTime: Date
    var sleepTime: Date
    var defaultWindowStart: Date
    var defaultWindowEnd: Date
    var eveningStartTime: Date
    var defaultTaskDuration: Int
    var bufferMinutes: Int
    var defaultReminderStyle: ReminderStyle
    var snoozeOptions: [Int]
    var enableTimeSensitiveReminders: Bool
    var defaultPlanningStyle: PlanningStyle
    var defaultScheduleRange: ScheduleRange
}

extension AITaskContextSnapshot {
    init(task: TaskItem) {
        self.id = task.id
        self.rawText = task.rawText
        self.title = task.title
        self.notes = task.notes
        self.category = task.category
        self.priority = task.priority
        self.energyLevel = task.energyLevel
        self.estimatedMinutes = task.estimatedMinutes
        self.preferredDate = task.dueDate
        self.dueDate = task.dueDate
        self.preferredDayOfWeek = task.preferredWeekday
        self.preferredWindow = task.preferredWindow
        self.flexibleWindowLabel = task.timingSummary
        self.isRecurring = task.isRecurring
        self.recurrenceRule = task.recurrenceRule
        self.status = task.status
        self.source = task.source
        self.suggestedTinyStep = task.suggestedTinyStep
        self.shrinkOptions = task.shrinkOptions
        self.confidence = task.aiConfidence
        self.friendlyNote = task.aiFriendlyNote
        self.scheduleRule = AIScheduleRule(task: task)
    }
}

extension AIScheduleBlockContextSnapshot {
    init(block: ScheduleBlock) {
        self.id = block.id
        self.taskId = block.taskId
        self.title = block.title
        self.startTime = block.startTime
        self.endTime = block.endTime
        self.flexibleWindowLabel = block.flexibleWindowLabel
        self.category = block.category
        self.status = block.status
        self.reminderStyle = block.reminderStyle
        self.snoozeMinutes = block.snoozeMinutes
        self.isLocked = block.isLocked
        self.aiReason = block.aiReason
    }
}

extension AIUserPreferencesSnapshot {
    init(preferences: UserPlanningPreferences) {
        self.wakeTime = preferences.wakeTime
        self.sleepTime = preferences.sleepTime
        self.defaultWindowStart = preferences.defaultWindowStart
        self.defaultWindowEnd = preferences.defaultWindowEnd
        self.eveningStartTime = preferences.eveningStartTime
        self.defaultTaskDuration = preferences.defaultTaskDuration
        self.bufferMinutes = preferences.bufferMinutes
        self.defaultReminderStyle = preferences.defaultReminderStyle
        self.snoozeOptions = preferences.snoozeOptions
        self.enableTimeSensitiveReminders = preferences.enableTimeSensitiveReminders
        self.defaultPlanningStyle = preferences.defaultPlanningStyle
        self.defaultScheduleRange = preferences.defaultScheduleRange
    }
}

extension AITaskContextSnapshot {
    func makeTaskItem() -> TaskItem {
        TaskItem(
            id: id,
            rawText: rawText,
            title: title,
            notes: notes,
            category: category,
            priority: priority,
            energyLevel: energyLevel,
            estimatedMinutes: estimatedMinutes,
            dueDate: dueDate ?? preferredDate,
            flexibleWindow: flexibleWindowLabel ?? preferredWindow?.title,
            preferredDayOfWeek: preferredDayOfWeek?.calendarWeekday,
            preferredWindow: preferredWindow,
            isRecurring: isRecurring,
            recurrenceRule: recurrenceRule,
            status: status,
            source: source,
            suggestedTinyStep: suggestedTinyStep,
            shrinkOptions: shrinkOptions,
            aiConfidence: confidence,
            aiFriendlyNote: friendlyNote,
            canScheduleToday: scheduleRule.canScheduleToday,
            canScheduleThisWeek: scheduleRule.canScheduleThisWeek,
            mustRespectDate: scheduleRule.mustRespectDate,
            mustRespectDay: scheduleRule.mustRespectDay,
            mustRespectWindow: scheduleRule.mustRespectWindow,
            allowFlexiblePlacement: scheduleRule.allowFlexiblePlacement
        )
    }
}

extension AIScheduleBlockContextSnapshot {
    func makeScheduleBlock() -> ScheduleBlock {
        ScheduleBlock(
            id: id,
            taskId: taskId,
            title: title,
            startTime: startTime,
            endTime: endTime,
            flexibleWindowLabel: flexibleWindowLabel,
            category: category,
            status: status,
            reminderStyle: reminderStyle,
            snoozeMinutes: snoozeMinutes,
            isLocked: isLocked,
            aiReason: aiReason
        )
    }
}

extension AIUserPreferencesSnapshot {
    func makePreferences() -> UserPlanningPreferences {
        UserPlanningPreferences(
            wakeTime: wakeTime,
            sleepTime: sleepTime,
            defaultWindowStart: defaultWindowStart,
            defaultWindowEnd: defaultWindowEnd,
            eveningStartTime: eveningStartTime,
            defaultTaskDuration: defaultTaskDuration,
            bufferMinutes: bufferMinutes,
            defaultReminderStyle: defaultReminderStyle,
            snoozeOptions: snoozeOptions,
            enableTimeSensitiveReminders: enableTimeSensitiveReminders,
            defaultPlanningStyle: defaultPlanningStyle,
            defaultScheduleRange: defaultScheduleRange
        )
    }
}

extension AIScheduleRule {
    init(task: TaskItem) {
        self.canScheduleToday = task.canScheduleToday
        self.canScheduleThisWeek = task.canScheduleThisWeek
        self.mustRespectDate = task.mustRespectDate
        self.mustRespectDay = task.mustRespectDay
        self.mustRespectWindow = task.mustRespectWindow
        self.allowFlexiblePlacement = task.allowFlexiblePlacement
    }
}

extension AITaskCandidate {
    func makeTaskItem(source: CaptureSource = .typed, createdAt: Date = Date()) -> TaskItem {
        TaskItem(
            rawText: rawText,
            title: cleanedTitle,
            notes: notes ?? "",
            category: category,
            priority: priority,
            energyLevel: energyLevel ?? .any,
            estimatedMinutes: max(1, estimatedMinutes),
            dueDate: dueDate ?? preferredDate,
            flexibleWindow: flexibleWindowLabel ?? preferredWindow?.title,
            preferredDayOfWeek: preferredDayOfWeek?.calendarWeekday,
            preferredWindow: preferredWindow,
            isRecurring: isRecurring,
            recurrenceRule: recurrenceRule,
            status: .inbox,
            source: source,
            suggestedTinyStep: tinyStep,
            shrinkOptions: shrinkOptions,
            aiConfidence: min(max(confidence, 0), 1),
            aiFriendlyNote: friendlyNote,
            canScheduleToday: scheduleRule.canScheduleToday,
            canScheduleThisWeek: scheduleRule.canScheduleThisWeek,
            mustRespectDate: scheduleRule.mustRespectDate,
            mustRespectDay: scheduleRule.mustRespectDay,
            mustRespectWindow: scheduleRule.mustRespectWindow,
            allowFlexiblePlacement: scheduleRule.allowFlexiblePlacement,
            createdAt: createdAt,
            updatedAt: createdAt
        )
    }
}

extension AIScheduleBlockCandidate {
    func makeScheduleBlock() -> ScheduleBlock {
        ScheduleBlock(
            taskId: taskId,
            title: title,
            startTime: startTime,
            endTime: endTime,
            flexibleWindowLabel: flexibleWindowLabel,
            category: category,
            reminderStyle: reminderStyle,
            aiReason: aiReason ?? ""
        )
    }
}
