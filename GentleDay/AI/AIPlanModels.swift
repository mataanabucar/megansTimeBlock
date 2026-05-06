import Foundation

struct AIPlanRequest: Codable {
    var tasks: [AITaskSnapshot]
    var existingScheduleBlocks: [AIScheduleBlockSnapshot]
    var preferences: AIPlanningPreferencesSnapshot
    var scheduleRange: ScheduleRange
    var planningStyle: PlanningStyle
}

struct AIPlanResponse: Codable {
    var proposedScheduleBlocks: [AIPlannedBlock]
    var updatedTaskStatuses: [AIUpdatedTaskStatus]
    var unscheduledTaskIDs: [UUID]
    var warnings: [AIPlanWarning]
    var friendlySummary: String
}

struct AIPlanWarning: Codable, Identifiable {
    var id: UUID
    var message: String
    var suggestion: String?

    init(id: UUID = UUID(), message: String, suggestion: String? = nil) {
        self.id = id
        self.message = message
        self.suggestion = suggestion
    }
}

struct AITaskSnapshot: Codable, Identifiable {
    var id: UUID
    var rawText: String
    var title: String
    var notes: String
    var category: TaskCategory
    var priority: PriorityLevel
    var energyLevel: EnergyLevel
    var estimatedMinutes: Int
    var dueDate: Date?
    var flexibleWindow: String?
    var preferredDayOfWeek: Int?
    var isRecurring: Bool
    var recurrenceRule: String?
    var status: TaskStatus
    var source: CaptureSource
    var suggestedTinyStep: String
    var shrinkOptions: [String]
}

struct AIScheduleBlockSnapshot: Codable, Identifiable {
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

struct AIPlanningPreferencesSnapshot: Codable {
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
}

struct AIPlannedBlock: Codable, Identifiable {
    var id: UUID
    var taskId: UUID?
    var title: String
    var startTime: Date
    var endTime: Date
    var flexibleWindowLabel: String
    var category: TaskCategory
    var reminderStyle: ReminderStyle
    var aiReason: String
}

struct AIUpdatedTaskStatus: Codable {
    var taskId: UUID
    var status: TaskStatus
}

extension AITaskSnapshot {
    init(task: TaskItem) {
        self.id = task.id
        self.rawText = task.rawText
        self.title = task.title
        self.notes = task.notes
        self.category = task.category
        self.priority = task.priority
        self.energyLevel = task.energyLevel
        self.estimatedMinutes = task.estimatedMinutes
        self.dueDate = task.dueDate
        self.flexibleWindow = task.flexibleWindow
        self.preferredDayOfWeek = task.preferredDayOfWeek
        self.isRecurring = task.isRecurring
        self.recurrenceRule = task.recurrenceRule
        self.status = task.status
        self.source = task.source
        self.suggestedTinyStep = task.suggestedTinyStep
        self.shrinkOptions = task.shrinkOptions
    }
}

extension AIScheduleBlockSnapshot {
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

extension AIPlanningPreferencesSnapshot {
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
    }
}
