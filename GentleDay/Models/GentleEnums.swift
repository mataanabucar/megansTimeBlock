import Foundation

enum TaskCategory: String, Codable, CaseIterable, Identifiable, Hashable {
    case home
    case errand
    case family
    case health
    case money
    case appointment
    case meal
    case cleaning
    case personal
    case reminder
    case habit
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Home"
        case .errand: "Errand"
        case .family: "Family"
        case .health: "Health"
        case .money: "Money"
        case .appointment: "Appointment"
        case .meal: "Meal"
        case .cleaning: "Cleaning"
        case .personal: "Personal"
        case .reminder: "Reminder"
        case .habit: "Habit"
        case .other: "Other"
        }
    }

    static func fromStorage(_ rawValue: String) -> TaskCategory {
        switch rawValue {
        case TaskCategory.home.rawValue: .home
        case TaskCategory.errand.rawValue: .errand
        case TaskCategory.family.rawValue: .family
        case TaskCategory.health.rawValue, "wellness": .health
        case TaskCategory.money.rawValue, "bills": .money
        case TaskCategory.appointment.rawValue: .appointment
        case TaskCategory.meal.rawValue, "meals": .meal
        case TaskCategory.cleaning.rawValue: .cleaning
        case TaskCategory.personal.rawValue, "lifeAdmin": .personal
        case TaskCategory.reminder.rawValue: .reminder
        case TaskCategory.habit.rawValue, "routine": .habit
        default: .other
        }
    }
}

enum PriorityLevel: String, Codable, CaseIterable, Identifiable, Hashable {
    case low
    case normal
    case high
    case mustDo

    var id: String { rawValue }

    var title: String {
        switch self {
        case .low: "Low"
        case .normal: "Normal"
        case .high: "High"
        case .mustDo: "Must Do"
        }
    }

    static func fromStorage(_ rawValue: String) -> PriorityLevel {
        switch rawValue {
        case PriorityLevel.low.rawValue, "soft": .low
        case PriorityLevel.normal.rawValue: .normal
        case PriorityLevel.high.rawValue, "important": .high
        case PriorityLevel.mustDo.rawValue, "essential": .mustDo
        default: .normal
        }
    }
}

enum EnergyLevel: String, Codable, CaseIterable, Identifiable, Hashable {
    case low
    case medium
    case high
    case brainTired
    case bodyRestless
    case quickWin
    case calm
    case any

    var id: String { rawValue }

    var title: String {
        switch self {
        case .low: "Low Energy"
        case .medium: "Some Energy"
        case .high: "More Energy"
        case .brainTired: "Brain Tired"
        case .bodyRestless: "Body Restless"
        case .quickWin: "Quick Win"
        case .calm: "Calm"
        case .any: "Any Energy"
        }
    }

    static func fromStorage(_ rawValue: String) -> EnergyLevel {
        EnergyLevel(rawValue: rawValue) ?? .any
    }
}

enum TaskStatus: String, Codable, CaseIterable, Identifiable, Hashable {
    case inbox
    case scheduled
    case inProgress
    case done
    case snoozed
    case moved
    case skipped
    case shrunk

    var id: String { rawValue }

    var title: String {
        switch self {
        case .inbox: "Inbox"
        case .scheduled: "Planned"
        case .inProgress: "Started"
        case .done: "Done"
        case .snoozed: "Snoozed"
        case .moved: "Moved"
        case .skipped: "Skipped Without Guilt"
        case .shrunk: "Shrunk"
        }
    }
}

enum BlockStatus: String, Codable, CaseIterable, Identifiable, Hashable {
    case planned
    case inProgress
    case done
    case snoozed
    case moved
    case skipped

    var id: String { rawValue }

    var title: String {
        switch self {
        case .planned: "Ready"
        case .inProgress: "Started"
        case .done: "Done"
        case .snoozed: "Snoozed"
        case .moved: "Moved Later"
        case .skipped: "Skipped Without Guilt"
        }
    }
}

enum PlanningStyle: String, Codable, CaseIterable, Identifiable, Hashable {
    case balancedDay
    case lightDay
    case catchUpDay
    case errandsDay
    case homeReset
    case minimumDay

    var id: String { rawValue }

    var title: String {
        switch self {
        case .balancedDay: "Balanced Day"
        case .lightDay: "Light Day"
        case .catchUpDay: "Catch-Up Day"
        case .errandsDay: "Errands Day"
        case .homeReset: "Home Reset"
        case .minimumDay: "Minimum Day"
        }
    }

    var friendlyDescription: String {
        switch self {
        case .balancedDay: "A steady plan with room to breathe."
        case .lightDay: "Shorter blocks and fewer decisions."
        case .catchUpDay: "A practical reset without trying to do everything."
        case .errandsDay: "Groups outside-the-house tasks together."
        case .homeReset: "Gentle care for your space."
        case .minimumDay: "Only the smallest useful plan."
        }
    }
}

enum ScheduleRange: String, Codable, CaseIterable, Identifiable, Hashable {
    case today
    case tomorrow
    case thisWeek

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: "Today"
        case .tomorrow: "Tomorrow"
        case .thisWeek: "This Week"
        }
    }
}

enum ReminderStyle: String, Codable, CaseIterable, Identifiable, Hashable {
    case none
    case gentle
    case timeSensitive
    case alarmCandidate

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: "None"
        case .gentle: "Gentle"
        case .timeSensitive: "Time Sensitive"
        case .alarmCandidate: "Alarm Candidate"
        }
    }
}

enum SnoozeOption: Int, Codable, CaseIterable, Identifiable, Hashable {
    case five = 5
    case fifteen = 15
    case thirty = 30
    case tomorrow = 1440

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .five: "Snooze 5 min"
        case .fifteen: "Snooze 15 min"
        case .thirty: "Snooze 30 min"
        case .tomorrow: "Tomorrow"
        }
    }
}

enum CaptureSource: String, Codable, CaseIterable, Identifiable, Hashable {
    case typed
    case voice
    case voicePlaceholder

    var id: String { rawValue }
}

enum AIParsingMode: String, Codable, CaseIterable, Identifiable, Hashable {
    case mockAI
    case openAIProxy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mockAI: "Mock AI"
        case .openAIProxy: "OpenAI via Proxy"
        }
    }

    var friendlyDescription: String {
        switch self {
        case .mockAI:
            return "Local testing mode. No internet or backend needed."
        case .openAIProxy:
            return "Hosted backend mode for real AI parsing."
        }
    }
}

enum Weekday: String, Codable, CaseIterable, Identifiable, Hashable {
    case monday
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday
    case sunday

    var id: String { rawValue }

    var title: String {
        switch self {
        case .monday: "Monday"
        case .tuesday: "Tuesday"
        case .wednesday: "Wednesday"
        case .thursday: "Thursday"
        case .friday: "Friday"
        case .saturday: "Saturday"
        case .sunday: "Sunday"
        }
    }

    var calendarWeekday: Int {
        switch self {
        case .sunday: 1
        case .monday: 2
        case .tuesday: 3
        case .wednesday: 4
        case .thursday: 5
        case .friday: 6
        case .saturday: 7
        }
    }

    init?(calendarWeekday: Int) {
        switch calendarWeekday {
        case 1: self = .sunday
        case 2: self = .monday
        case 3: self = .tuesday
        case 4: self = .wednesday
        case 5: self = .thursday
        case 6: self = .friday
        case 7: self = .saturday
        default: return nil
        }
    }
}

enum FlexibleWindow: String, Codable, CaseIterable, Identifiable, Hashable {
    case morning
    case midday
    case afternoon
    case afterWork
    case evening
    case beforeBed
    case anytime

    var id: String { rawValue }

    var title: String {
        switch self {
        case .morning: "Morning"
        case .midday: "Midday"
        case .afternoon: "Afternoon"
        case .afterWork: "After Work"
        case .evening: "Evening"
        case .beforeBed: "Before Bed"
        case .anytime: "Anytime"
        }
    }

    static func fromLegacyLabel(_ rawValue: String?) -> FlexibleWindow? {
        guard let rawValue else { return nil }
        switch rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "morning", "this morning":
            return .morning
        case "midday", "noon", "lunch":
            return .midday
        case "afternoon":
            return .afternoon
        case "after work":
            return .afterWork
        case "evening", "tonight", "night", "after dinner":
            return .evening
        case "before bed", "bedtime":
            return .beforeBed
        case "anytime", "gentle window":
            return .anytime
        default:
            return nil
        }
    }
}
