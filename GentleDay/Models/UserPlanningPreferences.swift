import Foundation
import SwiftData

@Model
final class UserPlanningPreferences: Identifiable {
    @Attribute(.unique) var id: UUID
    var wakeTime: Date
    var sleepTime: Date
    var defaultWindowStart: Date
    var defaultWindowEnd: Date
    var eveningStartTime: Date
    var defaultTaskDuration: Int
    var bufferMinutes: Int
    var defaultReminderStyleRawValue: String
    var snoozeOptionsRawValue: String
    var enableTimeSensitiveReminders: Bool
    var customGentleSoundName: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        wakeTime: Date = UserPlanningPreferences.time(hour: 7, minute: 30),
        sleepTime: Date = UserPlanningPreferences.time(hour: 22, minute: 30),
        defaultWindowStart: Date = UserPlanningPreferences.time(hour: 9, minute: 0),
        defaultWindowEnd: Date = UserPlanningPreferences.time(hour: 20, minute: 30),
        eveningStartTime: Date = UserPlanningPreferences.time(hour: 17, minute: 30),
        defaultTaskDuration: Int = 20,
        bufferMinutes: Int = 10,
        defaultReminderStyle: ReminderStyle = .gentle,
        snoozeOptions: [Int] = [5, 15, 30],
        enableTimeSensitiveReminders: Bool = false,
        customGentleSoundName: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.wakeTime = wakeTime
        self.sleepTime = sleepTime
        self.defaultWindowStart = defaultWindowStart
        self.defaultWindowEnd = defaultWindowEnd
        self.eveningStartTime = eveningStartTime
        self.defaultTaskDuration = max(5, defaultTaskDuration)
        self.bufferMinutes = max(0, bufferMinutes)
        self.defaultReminderStyleRawValue = defaultReminderStyle.rawValue
        self.snoozeOptionsRawValue = snoozeOptions.map(String.init).joined(separator: ",")
        self.enableTimeSensitiveReminders = enableTimeSensitiveReminders
        self.customGentleSoundName = customGentleSoundName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var defaultReminderStyle: ReminderStyle {
        get { ReminderStyle(rawValue: defaultReminderStyleRawValue) ?? .gentle }
        set {
            defaultReminderStyleRawValue = newValue.rawValue
            touch()
        }
    }

    var snoozeOptions: [Int] {
        get {
            snoozeOptionsRawValue
                .split(separator: ",")
                .compactMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
        }
        set {
            snoozeOptionsRawValue = newValue.sorted().map(String.init).joined(separator: ",")
            touch()
        }
    }

    func setSnoozeOption(_ minutes: Int, enabled: Bool) {
        var options = Set(snoozeOptions)
        if enabled {
            options.insert(minutes)
        } else {
            options.remove(minutes)
        }
        snoozeOptions = Array(options)
    }

    func touch() {
        updatedAt = Date()
    }

    private static func time(hour: Int, minute: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
    }
}
