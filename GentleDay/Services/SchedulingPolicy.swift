import Foundation

enum SchedulingPolicy {
    enum Bucket {
        case steadyRoutine
        case errand
        case admin
        case family
        case home
        case other
    }

    static func isProtectedPlanningEnabled(_ preferences: UserPlanningPreferences) -> Bool {
        preferences.protectedPlanningEnabled
    }

    static func bucket(for task: TaskItem) -> Bucket {
        if isSteadyRoutine(task) {
            return .steadyRoutine
        }
        if isErrandLike(task) {
            return .errand
        }
        switch task.category {
        case .bills, .lifeAdmin, .money, .appointment:
            return .admin
        case .family, .meals:
            return .family
        case .home, .cleaning, .routine, .wellness:
            return .home
        case .errand, .steadyRoutine:
            return .other
        case .other:
            return inferredBucket(from: task.rawText)
        }
    }

    static func isSteadyRoutine(_ task: TaskItem) -> Bool {
        task.category == .steadyRoutine || inferredBucket(from: task.rawText) == .steadyRoutine
    }

    static func isErrandLike(_ task: TaskItem) -> Bool {
        task.category == .errand || isGroceryTask(task) || inferredBucket(from: task.rawText) == .errand
    }

    static func isGroceryTask(_ task: TaskItem) -> Bool {
        let text = searchableText(for: task)
        return contains(#"\bgrocer(?:y|ies)\b|\bmarket\b|\bfood\s+shop(?:ping)?\b|\bpickup\s+order\b"#, in: text)
    }

    static func isHeavyEveningTask(_ task: TaskItem) -> Bool {
        switch bucket(for: task) {
        case .steadyRoutine, .errand, .admin:
            return true
        case .family, .home, .other:
            return task.estimatedMinutes >= 60
        }
    }

    static func applyDailyCaps(
        to tasks: [TaskItem],
        preferences: UserPlanningPreferences,
        range: ScheduleRange
    ) -> [TaskItem] {
        guard preferences.protectedPlanningEnabled, range != .thisWeek else {
            return Array(tasks.prefix(maxTaskCount(for: range, preferences: preferences)))
        }

        var result: [TaskItem] = []
        var bucketCounts: [Bucket: Int] = [:]
        var smallPracticalCount = 0
        let maxCount = maxTaskCount(for: range, preferences: preferences)

        for task in tasks {
            let bucket = bucket(for: task)
            guard result.count < maxCount else { break }

            switch bucket {
            case .steadyRoutine, .errand:
                guard (bucketCounts[bucket] ?? 0) < 1 else { continue }
            case .family:
                guard (bucketCounts[bucket] ?? 0) < 2 else { continue }
            case .admin, .home, .other:
                guard smallPracticalCount < 1 else { continue }
                smallPracticalCount += 1
            }

            result.append(task)
            bucketCounts[bucket, default: 0] += 1
        }

        return result
    }

    static func maxTaskCount(for range: ScheduleRange, preferences: UserPlanningPreferences) -> Int {
        let dailyLimit = max(1, preferences.maxAutoScheduledBlocksPerDay)
        switch range {
        case .today, .tomorrow:
            return dailyLimit
        case .thisWeek:
            return dailyLimit * 5
        }
    }

    static func primaryDayWindow(on day: Date, preferences: UserPlanningPreferences) -> (start: Date, end: Date) {
        let start = DateFormatting.combine(day: day, time: preferences.primaryDayWindowStart)
        let end = DateFormatting.combine(day: day, time: preferences.primaryDayWindowEnd)
        return (start, max(end, start))
    }

    static func steadyRoutineWindow(on day: Date, preferences: UserPlanningPreferences, calendar: Calendar) -> (start: Date, end: Date) {
        let primary = primaryDayWindow(on: day, preferences: preferences)
        let latestEnd = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: day) ?? primary.end
        return (primary.start, max(primary.start, min(primary.end, latestEnd)))
    }

    static func errandWindow(on day: Date, preferences: UserPlanningPreferences, calendar: Calendar) -> (start: Date, end: Date) {
        let primary = primaryDayWindow(on: day, preferences: preferences)
        let preferredStart = calendar.date(bySettingHour: 13, minute: 30, second: 0, of: day) ?? primary.start
        return (max(primary.start, preferredStart), primary.end)
    }

    static func eveningCutoff(on day: Date, preferences: UserPlanningPreferences) -> Date {
        DateFormatting.combine(day: day, time: preferences.eveningCutoffTime)
    }

    static func dailyPlanningCapacity(on day: Date, preferences: UserPlanningPreferences) -> Int {
        let window: (start: Date, end: Date)
        if preferences.protectedPlanningEnabled {
            window = primaryDayWindow(on: day, preferences: preferences)
        } else {
            let start = DateFormatting.combine(day: day, time: preferences.defaultWindowStart)
            let end = DateFormatting.combine(day: day, time: preferences.defaultWindowEnd)
            window = (start, end)
        }
        let total = Calendar.current.dateComponents([.minute], from: window.start, to: window.end).minute ?? 0
        let reserved = preferences.reserveQuietBlock ? preferences.quietBlockMinutes : 0
        return max(0, total - reserved)
    }

    static func isExplicitEvening(_ label: String?) -> Bool {
        guard let label = NaturalTimeParser.normalizedWindowLabel(label) else { return false }
        return ["Evening", "After work", "Before bed", "Early evening"].contains(label)
    }

    private static func inferredBucket(from rawText: String) -> Bucket {
        let text = rawText.lowercased()

        if contains(#"\bmeeting\b|\bgroup\b|\bjournal(?:ing)?\b|\bmeditat(?:e|ion)\b|\bsteady\s+routine\b|\bdaily\s+routine\b"#, in: text) {
            return .steadyRoutine
        }
        if contains(#"\bgrocer(?:y|ies)\b|\berrand\b|\bpick\s+up\b|\bpharmacy\b|\bstore\b|\bmarket\b"#, in: text) {
            return .errand
        }
        if contains(#"\bbill\b|\binsurance\b|\bbank\b|\bpaperwork\b|\badmin\b|\bappointment\b"#, in: text) {
            return .admin
        }
        return .other
    }

    private static func searchableText(for task: TaskItem) -> String {
        "\(task.rawText) \(task.title)".lowercased()
    }

    private static func contains(_ pattern: String, in text: String) -> Bool {
        text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }
}
