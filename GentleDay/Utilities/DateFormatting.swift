import Foundation

enum DateFormatting {
    static let shortTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()

    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .none
        formatter.dateStyle = .medium
        return formatter
    }()

    static func timeRange(start: Date, end: Date) -> String {
        "\(shortTime.string(from: start)) - \(shortTime.string(from: end))"
    }

    static func flexibleWindowLabel(for date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<12:
            return "Morning"
        case 12..<17:
            return "Afternoon"
        case 17..<21:
            return "Evening"
        case 21...23:
            return "Before bed"
        default:
            return "Gentle window"
        }
    }

    static func combine(day: Date, time: Date) -> Date {
        let calendar = Calendar.current
        let dayComponents = calendar.dateComponents([.year, .month, .day], from: day)
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: time)

        var components = DateComponents()
        components.year = dayComponents.year
        components.month = dayComponents.month
        components.day = dayComponents.day
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute
        components.second = timeComponents.second ?? 0
        return calendar.date(from: components) ?? day
    }

    static func startDate(for range: ScheduleRange) -> Date {
        let calendar = Calendar.current
        switch range {
        case .today:
            return Date()
        case .tomorrow:
            return calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        case .thisWeek:
            return Date()
        }
    }
}
