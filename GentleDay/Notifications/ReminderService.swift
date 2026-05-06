import Foundation
import UserNotifications

final class ReminderService {
    static let shared = ReminderService()

    static let blockReminderCategory = "GENTLE_BLOCK_REMINDER"
    static let actionStart = "action_start"
    static let actionSnooze5 = "action_snooze_5"
    static let actionSnooze15 = "action_snooze_15"
    static let actionShrink = "action_shrink"
    static let actionMoveLater = "action_move_later"
    static let actionSkip = "action_skip"

    private let center: UNUserNotificationCenter

    private init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func configure() {
        registerNotificationCategories()
    }

    @discardableResult
    func requestAuthorization(enableTimeSensitive: Bool) async throws -> Bool {
        _ = enableTimeSensitive
        return try await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    func registerNotificationCategories() {
        let actions = [
            UNNotificationAction(
                identifier: Self.actionStart,
                title: "Start",
                options: [.foreground]
            ),
            UNNotificationAction(
                identifier: Self.actionSnooze5,
                title: "Snooze 5 min",
                options: []
            ),
            UNNotificationAction(
                identifier: Self.actionSnooze15,
                title: "Snooze 15 min",
                options: []
            ),
            UNNotificationAction(
                identifier: Self.actionShrink,
                title: "Shrink",
                options: [.foreground]
            ),
            UNNotificationAction(
                identifier: Self.actionMoveLater,
                title: "Move Later",
                options: []
            ),
            UNNotificationAction(
                identifier: Self.actionSkip,
                title: "Skip Without Guilt",
                options: []
            )
        ]

        let category = UNNotificationCategory(
            identifier: Self.blockReminderCategory,
            actions: actions,
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        center.setNotificationCategories([category])
    }

    func scheduleReminder(for block: ScheduleBlock, task: TaskItem?) async throws {
        guard block.reminderStyle != .none else { return }
        guard block.startTime > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Gentle Day"
        content.body = announceableBody(for: block, task: task)
        content.categoryIdentifier = Self.blockReminderCategory
        content.sound = sound(for: task)
        content.userInfo = [
            "blockId": block.id.uuidString,
            "taskId": block.taskId?.uuidString ?? "",
            "reminderStyle": block.reminderStyle.rawValue,
            "alarmCandidate": block.reminderStyle == .alarmCandidate
        ]

        if block.reminderStyle == .timeSensitive {
            content.interruptionLevel = .timeSensitive
        }

        let triggerComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: block.startTime
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)
        let request = UNNotificationRequest(
            identifier: identifier(for: block),
            content: content,
            trigger: trigger
        )

        try await center.add(request)
    }

    func cancelReminder(for block: ScheduleBlock) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier(for: block)])
        center.removeDeliveredNotifications(withIdentifiers: [identifier(for: block)])
    }

    func rescheduleReminder(for block: ScheduleBlock, task: TaskItem?) async throws {
        cancelReminder(for: block)
        try await scheduleReminder(for: block, task: task)
    }

    func identifier(for block: ScheduleBlock) -> String {
        "gentle_block_\(block.id.uuidString)"
    }

    private func announceableBody(for block: ScheduleBlock, task: TaskItem?) -> String {
        let tinyStep = task.flatMap { $0.suggestedTinyStep.nilIfBlank } ?? "One small step is enough."
        return "Your next block is ready. \(block.title). \(tinyStep)"
    }

    private func sound(for task: TaskItem?) -> UNNotificationSound {
        // Future option: return a bundled short gentle sound such as "One small step is enough".
        // Siri verbal announcements are controlled by iOS settings, not by this sound setting.
        _ = task
        return .default
    }
}
