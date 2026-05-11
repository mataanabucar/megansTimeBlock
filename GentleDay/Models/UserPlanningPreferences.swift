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
    var primaryDayWindowStart: Date = UserPlanningPreferences.time(hour: 9, minute: 0)
    var primaryDayWindowEnd: Date = UserPlanningPreferences.time(hour: 15, minute: 30)
    var eveningCutoffTime: Date = UserPlanningPreferences.time(hour: 19, minute: 30)
    var defaultTaskDuration: Int
    var bufferMinutes: Int
    var protectedPlanningEnabled: Bool = true
    var reserveQuietBlock: Bool = true
    var quietBlockMinutes: Int = 30
    var maxAutoScheduledBlocksPerDay: Int = 5
    var lowEffortErrandEnabled: Bool = true
    var groceryPickupDurationMinutes: Int = 25
    var steadyRoutineDurationMinutes: Int = 60
    var steadyRoutineBufferMinutes: Int = 15
    var defaultReminderStyleRawValue: String
    var snoozeOptionsRawValue: String
    var enableTimeSensitiveReminders: Bool
    var customGentleSoundName: String?
    var aiProxyEndpointURL: String = UserPlanningPreferences.defaultAIProxyEndpointURL
    var enableAIParsing: Bool = true
    var aiModeRawValue: String = AIParsingMode.openAIProxy.rawValue
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        wakeTime: Date = UserPlanningPreferences.time(hour: 7, minute: 30),
        sleepTime: Date = UserPlanningPreferences.time(hour: 22, minute: 30),
        defaultWindowStart: Date = UserPlanningPreferences.time(hour: 9, minute: 0),
        defaultWindowEnd: Date = UserPlanningPreferences.time(hour: 20, minute: 30),
        eveningStartTime: Date = UserPlanningPreferences.time(hour: 17, minute: 30),
        primaryDayWindowStart: Date = UserPlanningPreferences.time(hour: 9, minute: 0),
        primaryDayWindowEnd: Date = UserPlanningPreferences.time(hour: 15, minute: 30),
        eveningCutoffTime: Date = UserPlanningPreferences.time(hour: 19, minute: 30),
        defaultTaskDuration: Int = 20,
        bufferMinutes: Int = 10,
        protectedPlanningEnabled: Bool = true,
        reserveQuietBlock: Bool = true,
        quietBlockMinutes: Int = 30,
        maxAutoScheduledBlocksPerDay: Int = 5,
        lowEffortErrandEnabled: Bool = true,
        groceryPickupDurationMinutes: Int = 25,
        steadyRoutineDurationMinutes: Int = 60,
        steadyRoutineBufferMinutes: Int = 15,
        defaultReminderStyle: ReminderStyle = .gentle,
        snoozeOptions: [Int] = [5, 15, 30],
        enableTimeSensitiveReminders: Bool = false,
        customGentleSoundName: String? = nil,
        aiProxyEndpointURL: String = UserPlanningPreferences.defaultAIProxyEndpointURL,
        enableAIParsing: Bool = true,
        aiMode: AIParsingMode = .openAIProxy,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.wakeTime = wakeTime
        self.sleepTime = sleepTime
        self.defaultWindowStart = defaultWindowStart
        self.defaultWindowEnd = defaultWindowEnd
        self.eveningStartTime = eveningStartTime
        self.primaryDayWindowStart = primaryDayWindowStart
        self.primaryDayWindowEnd = primaryDayWindowEnd
        self.eveningCutoffTime = eveningCutoffTime
        self.defaultTaskDuration = max(5, defaultTaskDuration)
        self.bufferMinutes = max(0, bufferMinutes)
        self.protectedPlanningEnabled = protectedPlanningEnabled
        self.reserveQuietBlock = reserveQuietBlock
        self.quietBlockMinutes = max(0, quietBlockMinutes)
        self.maxAutoScheduledBlocksPerDay = max(1, maxAutoScheduledBlocksPerDay)
        self.lowEffortErrandEnabled = lowEffortErrandEnabled
        self.groceryPickupDurationMinutes = max(10, groceryPickupDurationMinutes)
        self.steadyRoutineDurationMinutes = max(10, steadyRoutineDurationMinutes)
        self.steadyRoutineBufferMinutes = max(0, steadyRoutineBufferMinutes)
        self.defaultReminderStyleRawValue = defaultReminderStyle.rawValue
        self.snoozeOptionsRawValue = snoozeOptions.map(String.init).joined(separator: ",")
        self.enableTimeSensitiveReminders = enableTimeSensitiveReminders
        self.customGentleSoundName = customGentleSoundName
        self.aiProxyEndpointURL = aiProxyEndpointURL
        self.enableAIParsing = enableAIParsing
        self.aiModeRawValue = aiMode.rawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    static let defaultAIProxyEndpointURL = AIProxyConfiguration.hostedEndpointURLString

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

    var aiMode: AIParsingMode {
        get { AIParsingMode(rawValue: aiModeRawValue) ?? .openAIProxy }
        set {
            aiModeRawValue = newValue.rawValue
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
