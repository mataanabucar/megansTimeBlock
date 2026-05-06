import Foundation

enum TaskCategory: String, Codable, CaseIterable, Identifiable, Hashable {
    case home
    case errand
    case family
    case money
    case appointment
    case cleaning
    case wellness
    case meals
    case bills
    case routine
    case lifeAdmin
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Home"
        case .errand: "Errand"
        case .family: "Family"
        case .money: "Money"
        case .appointment: "Appointment"
        case .cleaning: "Cleaning"
        case .wellness: "Wellness"
        case .meals: "Meals"
        case .bills: "Bills"
        case .routine: "Routine"
        case .lifeAdmin: "Life Admin"
        case .other: "Other"
        }
    }
}

enum PriorityLevel: String, Codable, CaseIterable, Identifiable, Hashable {
    case soft
    case normal
    case important
    case essential

    var id: String { rawValue }

    var title: String {
        switch self {
        case .soft: "Soft"
        case .normal: "Normal"
        case .important: "Important"
        case .essential: "Essential"
        }
    }
}

enum EnergyLevel: String, Codable, CaseIterable, Identifiable, Hashable {
    case low
    case medium
    case high
    case any

    var id: String { rawValue }

    var title: String {
        switch self {
        case .low: "Low Energy"
        case .medium: "Some Energy"
        case .high: "More Energy"
        case .any: "Any Energy"
        }
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
