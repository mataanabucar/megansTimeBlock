import Foundation
import SwiftData

@Model
final class ScheduleBlock: Identifiable {
    @Attribute(.unique) var id: UUID
    var taskId: UUID?
    var title: String
    var startTime: Date
    var endTime: Date
    var flexibleWindowLabel: String
    var categoryRawValue: String
    var statusRawValue: String
    var reminderStyleRawValue: String
    var snoozeMinutes: Int
    var isLocked: Bool
    var aiReason: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        taskId: UUID? = nil,
        title: String,
        startTime: Date,
        endTime: Date,
        flexibleWindowLabel: String,
        category: TaskCategory = .other,
        status: BlockStatus = .planned,
        reminderStyle: ReminderStyle = .gentle,
        snoozeMinutes: Int = 0,
        isLocked: Bool = false,
        aiReason: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.taskId = taskId
        self.title = title
        self.startTime = startTime
        self.endTime = endTime
        self.flexibleWindowLabel = flexibleWindowLabel
        self.categoryRawValue = category.rawValue
        self.statusRawValue = status.rawValue
        self.reminderStyleRawValue = reminderStyle.rawValue
        self.snoozeMinutes = snoozeMinutes
        self.isLocked = isLocked
        self.aiReason = aiReason
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var category: TaskCategory {
        get { TaskCategory(rawValue: categoryRawValue) ?? .other }
        set {
            categoryRawValue = newValue.rawValue
            touch()
        }
    }

    var status: BlockStatus {
        get { BlockStatus(rawValue: statusRawValue) ?? .planned }
        set {
            statusRawValue = newValue.rawValue
            touch()
        }
    }

    var reminderStyle: ReminderStyle {
        get { ReminderStyle(rawValue: reminderStyleRawValue) ?? .gentle }
        set {
            reminderStyleRawValue = newValue.rawValue
            touch()
        }
    }

    var durationMinutes: Int {
        max(1, Calendar.current.dateComponents([.minute], from: startTime, to: endTime).minute ?? 1)
    }

    func move(byMinutes minutes: Int) {
        startTime = Calendar.current.date(byAdding: .minute, value: minutes, to: startTime) ?? startTime
        endTime = Calendar.current.date(byAdding: .minute, value: minutes, to: endTime) ?? endTime
        snoozeMinutes = max(0, snoozeMinutes + minutes)
        status = .moved
        flexibleWindowLabel = DateFormatting.flexibleWindowLabel(for: startTime)
        touch()
    }

    func resize(toMinutes minutes: Int) {
        endTime = Calendar.current.date(byAdding: .minute, value: max(1, minutes), to: startTime) ?? endTime
        touch()
    }

    func touch() {
        updatedAt = Date()
    }
}
