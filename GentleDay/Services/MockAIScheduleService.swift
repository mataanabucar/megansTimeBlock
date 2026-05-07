import Foundation

struct MockAIScheduleService: AIScheduleService {
    func generatePlan(
        tasks: [TaskItem],
        existingScheduleBlocks: [ScheduleBlock],
        preferences: UserPlanningPreferences,
        scheduleRange: ScheduleRange,
        planningStyle: PlanningStyle
    ) async throws -> AIPlanResponse {
        let request = AIPlanRequest(
            tasks: tasks.map(AITaskSnapshot.init(task:)),
            existingScheduleBlocks: existingScheduleBlocks.map(AIScheduleBlockSnapshot.init(block:)),
            preferences: AIPlanningPreferencesSnapshot(preferences: preferences),
            scheduleRange: scheduleRange,
            planningStyle: planningStyle
        )

        let sortedTasks = sortedCandidates(
            from: tasks,
            request: request,
            style: planningStyle
        )
        let selection = eligibleCandidates(
            from: sortedTasks,
            range: scheduleRange
        )

        let taskLimit = limit(for: planningStyle, range: scheduleRange)
        let limitedTasks = Array(selection.tasks.prefix(taskLimit))
        let planned = makeBlocks(
            from: limitedTasks,
            preferences: preferences,
            range: scheduleRange,
            style: planningStyle
        )

        let plannedTaskIDs = Set(planned.compactMap(\.taskId))
        let unscheduledTaskIDs = sortedTasks
            .filter { !plannedTaskIDs.contains($0.id) }
            .map(\.id)

        var warnings = selection.warnings
        if scheduleRange == .today && totalMinutes(for: limitedTasks, preferences: preferences) > availableMinutes(for: preferences, on: Date()) {
            warnings.append(AIPlanWarning(
                message: "This may be too much for one evening.",
                suggestion: "Try Minimum Day or move a few things to tomorrow."
            ))
        }

        let specificallyExplainedIDs = Set(selection.excludedTaskIDs)
        let notExplainedCount = unscheduledTaskIDs.filter { !specificallyExplainedIDs.contains($0) }.count
        if notExplainedCount > 0 {
            warnings.append(AIPlanWarning(
                message: "I moved a few items forward so today stays realistic.",
                suggestion: "They will stay safe in your inbox."
            ))
        }

        if planningStyle == .minimumDay && selection.tasks.count > planned.count {
            warnings.append(AIPlanWarning(
                message: "Minimum Day is capped at three useful tasks.",
                suggestion: "That is the point: small and recoverable."
            ))
        }

        return AIPlanResponse(
            proposedScheduleBlocks: planned,
            updatedTaskStatuses: plannedTaskIDs.map { AIUpdatedTaskStatus(taskId: $0, status: .scheduled) },
            unscheduledTaskIDs: unscheduledTaskIDs,
            warnings: warnings,
            friendlySummary: summary(for: planned, style: planningStyle, unscheduledCount: unscheduledTaskIDs.count)
        )
    }

    private func sortedCandidates(
        from tasks: [TaskItem],
        request: AIPlanRequest,
        style: PlanningStyle
    ) -> [TaskItem] {
        let scheduledIDs = Set(request.existingScheduleBlocks.compactMap(\.taskId))
        let openStatuses: Set<TaskStatus> = [.inbox, .shrunk, .snoozed, .moved]

        return tasks
            .filter { openStatuses.contains($0.status) && !scheduledIDs.contains($0.id) }
            .sorted { lhs, rhs in
                let leftScore = score(lhs, style: style)
                let rightScore = score(rhs, style: style)
                if leftScore != rightScore { return leftScore > rightScore }
                if lhs.estimatedMinutes != rhs.estimatedMinutes { return lhs.estimatedMinutes < rhs.estimatedMinutes }
                return lhs.createdAt < rhs.createdAt
            }
    }

    private struct CandidateSelection {
        var tasks: [TaskItem]
        var excludedTaskIDs: [UUID]
        var warnings: [AIPlanWarning]
    }

    private struct TaskTimeContext {
        var cleanedTitle: String
        var preferredDate: Date?
        var preferredDayOfWeek: Weekday?
        var flexibleWindowLabel: String?
        var recurrenceHint: String?
        var isThisWeek: Bool
    }

    private func eligibleCandidates(
        from tasks: [TaskItem],
        range: ScheduleRange,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> CandidateSelection {
        var included: [TaskItem] = []
        var excludedTaskIDs: [UUID] = []
        var warnings: [AIPlanWarning] = []

        for task in tasks {
            let context = timeContext(for: task)
            if isEligible(task, context: context, for: range, now: now, calendar: calendar) {
                included.append(task)
            } else {
                excludedTaskIDs.append(task.id)
                warnings.append(exclusionWarning(for: task, context: context, range: range, now: now, calendar: calendar))
            }
        }

        return CandidateSelection(tasks: included, excludedTaskIDs: excludedTaskIDs, warnings: warnings)
    }

    private func isEligible(
        _ task: TaskItem,
        context: TaskTimeContext,
        for range: ScheduleRange,
        now: Date,
        calendar: Calendar
    ) -> Bool {
        let preferredDate = task.dueDate ?? context.preferredDate
        switch range {
        case .today:
            if let preferredDate, !calendar.isDate(preferredDate, inSameDayAs: now) {
                return false
            }
            if let weekday = context.preferredDayOfWeek, weekday.calendarWeekday != calendar.component(.weekday, from: now) {
                return false
            }
            return true

        case .tomorrow:
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
            if let preferredDate, !calendar.isDate(preferredDate, inSameDayAs: tomorrow) {
                return false
            }
            if let weekday = context.preferredDayOfWeek, weekday.calendarWeekday != calendar.component(.weekday, from: tomorrow) {
                return false
            }
            return true

        case .thisWeek:
            let baseDay = calendar.startOfDay(for: DateFormatting.startDate(for: .thisWeek))
            if let preferredDate, !isDate(preferredDate, withinDays: 7, from: baseDay, calendar: calendar) {
                return false
            }
            if let weekday = context.preferredDayOfWeek,
               matchingDate(for: weekday.calendarWeekday, from: baseDay, dayCount: 7, calendar: calendar) == nil {
                return false
            }
            return true
        }
    }

    private func exclusionWarning(
        for task: TaskItem,
        context: TaskTimeContext,
        range: ScheduleRange,
        now: Date,
        calendar: Calendar
    ) -> AIPlanWarning {
        let title = context.cleanedTitle.isEmpty ? task.title : context.cleanedTitle
        let target = targetDescription(for: task, context: context, now: now, calendar: calendar)
        let rangeLabel = switch range {
        case .today: "today"
        case .tomorrow: "tomorrow"
        case .thisWeek: "this plan"
        }

        return AIPlanWarning(
            message: "I kept '\(title)' for \(target) instead of adding it to \(rangeLabel).",
            suggestion: "It is still safe in your inbox."
        )
    }

    private func targetDescription(
        for task: TaskItem,
        context: TaskTimeContext,
        now: Date,
        calendar: Calendar
    ) -> String {
        let preferredDate = task.dueDate ?? context.preferredDate
        let datePart: String? = if let weekday = context.preferredDayOfWeek {
            weekday.title
        } else if let preferredDate {
            if calendar.isDate(preferredDate, inSameDayAs: now) {
                "today"
            } else if calendar.isDateInTomorrow(preferredDate) {
                "tomorrow"
            } else {
                DateFormatting.shortDate.string(from: preferredDate)
            }
        } else if context.isThisWeek {
            "this week"
        } else {
            nil
        }

        let windowPart = context.flexibleWindowLabel?.lowercased()
        return [datePart, windowPart]
            .compactMap { $0 }
            .joined(separator: " ")
    }

    private func timeContext(for task: TaskItem) -> TaskTimeContext {
        let parsed = NaturalTimeParser.parse(task.rawText, now: task.createdAt)
        return TaskTimeContext(
            cleanedTitle: parsed.cleanedTitle,
            preferredDate: task.dueDate ?? parsed.preferredDate,
            preferredDayOfWeek: task.preferredWeekday ?? parsed.preferredDayOfWeek,
            flexibleWindowLabel: NaturalTimeParser.normalizedWindowLabel(task.flexibleWindow) ?? parsed.flexibleWindowLabel,
            recurrenceHint: task.recurrenceRule ?? parsed.recurrenceHint,
            isThisWeek: parsed.isThisWeek || task.flexibleWindow?.localizedCaseInsensitiveContains("this week") == true
        )
    }

    private func score(_ task: TaskItem, style: PlanningStyle) -> Int {
        var value = 0

        switch task.priority {
        case .mustDo: value += 60
        case .high: value += 40
        case .normal: value += 20
        case .low: value += 5
        }

        if let dueDate = task.dueDate {
            let daysAway = Calendar.current.dateComponents([.day], from: Date(), to: dueDate).day ?? 0
            if daysAway <= 0 { value += 35 }
            else if daysAway <= 1 { value += 25 }
            else if daysAway <= 7 { value += 10 }
        }

        switch style {
        case .lightDay, .minimumDay:
            if task.estimatedMinutes <= 10 { value += 35 }
            else if task.estimatedMinutes <= 20 { value += 15 }
        case .errandsDay:
            if task.category == .errand || task.category == .appointment { value += 35 }
        case .homeReset:
            if task.category == .home || task.category == .cleaning || task.category == .habit { value += 35 }
        case .catchUpDay:
            if task.priority == .high || task.priority == .mustDo { value += 20 }
        case .balancedDay:
            value += task.energyLevel == .low ? 10 : 0
        }

        if !task.suggestedTinyStep.isEmpty { value += 8 }
        return value
    }

    private func limit(for style: PlanningStyle, range: ScheduleRange) -> Int {
        if range == .thisWeek {
            switch style {
            case .minimumDay: return 9
            case .lightDay: return 12
            default: return 18
            }
        }

        switch style {
        case .minimumDay: return 3
        case .lightDay: return 5
        case .balancedDay: return 7
        case .catchUpDay: return 8
        case .errandsDay: return 6
        case .homeReset: return 6
        }
    }

    private func makeBlocks(
        from tasks: [TaskItem],
        preferences: UserPlanningPreferences,
        range: ScheduleRange,
        style: PlanningStyle
    ) -> [AIPlannedBlock] {
        let calendar = Calendar.current
        let baseDay = calendar.startOfDay(for: DateFormatting.startDate(for: range))
        let dayCount = range == .thisWeek ? 7 : 1
        var cursorsByWindow: [String: Date] = [:]
        var blocks: [AIPlannedBlock] = []

        for task in tasks {
            let context = timeContext(for: task)
            let duration = adjustedDuration(for: task, style: style, preferences: preferences)
            let candidateDays = candidateDays(
                for: task,
                context: context,
                range: range,
                baseDay: baseDay,
                dayCount: dayCount,
                calendar: calendar
            )

            for day in candidateDays {
                let window = schedulingWindow(
                    for: task,
                    context: context,
                    on: day,
                    preferences: preferences,
                    calendar: calendar
                )
                let cursorKey = cursorKey(for: window, on: day, calendar: calendar)
                let proposedStart = cursorsByWindow[cursorKey] ?? startCursor(in: window, on: day)
                let start = max(proposedStart, window.start)
                let end = calendar.date(byAdding: .minute, value: duration, to: start) ?? start

                guard end <= window.end else { continue }

                let block = AIPlannedBlock(
                    id: UUID(),
                    taskId: task.id,
                    title: task.title,
                    startTime: start,
                    endTime: end,
                    flexibleWindowLabel: displayWindowLabel(
                        for: window,
                        start: start,
                        context: context,
                        range: range,
                        calendar: calendar
                    ),
                    category: task.category,
                    reminderStyle: reminderStyle(for: task, preferences: preferences),
                    aiReason: reason(for: task, context: context, style: style)
                )
                blocks.append(block)
                cursorsByWindow[cursorKey] = calendar.date(
                    byAdding: .minute,
                    value: duration + preferences.bufferMinutes,
                    to: start
                ) ?? end
                break
            }
        }

        return blocks.sorted { $0.startTime < $1.startTime }
    }

    private func adjustedDuration(
        for task: TaskItem,
        style: PlanningStyle,
        preferences: UserPlanningPreferences
    ) -> Int {
        let base = task.estimatedMinutes > 0 ? task.estimatedMinutes : preferences.defaultTaskDuration
        switch style {
        case .minimumDay:
            return min(base, 20)
        case .lightDay:
            return min(base, 30)
        default:
            return base
        }
    }

    private struct SchedulingWindow {
        var label: String
        var start: Date
        var end: Date
    }

    private func candidateDays(
        for task: TaskItem,
        context: TaskTimeContext,
        range: ScheduleRange,
        baseDay: Date,
        dayCount: Int,
        calendar: Calendar
    ) -> [Date] {
        if let preferredDate = task.dueDate ?? context.preferredDate {
            let day = calendar.startOfDay(for: preferredDate)
            return isDate(day, withinDays: dayCount, from: baseDay, calendar: calendar) ? [day] : []
        }

        if let weekday = context.preferredDayOfWeek,
           let day = matchingDate(for: weekday.calendarWeekday, from: baseDay, dayCount: dayCount, calendar: calendar) {
            return [day]
        }

        switch range {
        case .today, .tomorrow:
            return [baseDay]
        case .thisWeek:
            return (0..<dayCount).compactMap { offset in
                calendar.date(byAdding: .day, value: offset, to: baseDay)
            }
        }
    }

    private func schedulingWindow(
        for task: TaskItem,
        context: TaskTimeContext,
        on day: Date,
        preferences: UserPlanningPreferences,
        calendar: Calendar
    ) -> SchedulingWindow {
        let label = context.flexibleWindowLabel ?? businessWindowLabel(for: task, context: context)
        let defaultStart = DateFormatting.combine(day: day, time: preferences.defaultWindowStart)
        let defaultEnd = DateFormatting.combine(day: day, time: preferences.defaultWindowEnd)
        let wake = DateFormatting.combine(day: day, time: preferences.wakeTime)
        let sleep = DateFormatting.combine(day: day, time: preferences.sleepTime)
        let noon = clock(hour: 12, minute: 0, on: day, calendar: calendar)
        let fivePM = clock(hour: 17, minute: 0, on: day, calendar: calendar)
        let sixThirtyPM = clock(hour: 18, minute: 30, on: day, calendar: calendar)
        let eveningStart = max(DateFormatting.combine(day: day, time: preferences.eveningStartTime), sixThirtyPM)

        switch label {
        case "Morning":
            let start = defaultStart < noon ? max(defaultStart, wake) : wake
            return SchedulingWindow(label: "Morning", start: start, end: noon)

        case "Afternoon":
            let end = minDateGreaterThanStart([DateFormatting.combine(day: day, time: preferences.eveningStartTime), fivePM], start: noon)
                ?? fivePM
            return SchedulingWindow(label: "Afternoon", start: noon, end: end)

        case "Evening":
            let end = defaultEnd > eveningStart ? defaultEnd : sleep
            return SchedulingWindow(label: "Evening", start: eveningStart, end: max(end, eveningStart))

        case "After work":
            let start = max(DateFormatting.combine(day: day, time: preferences.eveningStartTime), fivePM)
            let end = defaultEnd > start ? defaultEnd : sleep
            return SchedulingWindow(label: "After work", start: start, end: max(end, start))

        case "Before bed":
            let fallbackStart = calendar.date(byAdding: .minute, value: -90, to: sleep) ?? defaultEnd
            let start = max(fallbackStart, eveningStart)
            return SchedulingWindow(label: "Before bed", start: start, end: max(sleep, start))

        case "Business Hours":
            let businessStart = max(defaultStart, clock(hour: 9, minute: 0, on: day, calendar: calendar))
            let businessEnd = min(defaultEnd, fivePM)
            return SchedulingWindow(label: "Business Hours", start: businessStart, end: max(businessEnd, businessStart))

        default:
            return SchedulingWindow(label: "Gentle window", start: defaultStart, end: max(defaultEnd, defaultStart))
        }
    }

    private func businessWindowLabel(for task: TaskItem, context: TaskTimeContext) -> String? {
        guard context.isThisWeek else { return nil }
        let text = "\(task.rawText) \(task.title)".lowercased()
        if text.contains("call")
            || text.contains("dentist")
            || text.contains("doctor")
            || text.contains("bank")
            || text.contains("bill")
            || text.contains("office") {
            return "Business Hours"
        }
        return nil
    }

    private func startCursor(in window: SchedulingWindow, on day: Date) -> Date {
        if Calendar.current.isDateInToday(day) {
            return max(roundUpToNextFive(Date()), window.start)
        }
        return window.start
    }

    private func displayWindowLabel(
        for window: SchedulingWindow,
        start: Date,
        context: TaskTimeContext,
        range: ScheduleRange,
        calendar: Calendar
    ) -> String {
        let baseLabel = window.label == "Gentle window" ? DateFormatting.flexibleWindowLabel(for: start) : window.label
        let shouldShowWeekday = range == .thisWeek || context.preferredDayOfWeek != nil
        guard shouldShowWeekday,
              let weekdayName = NaturalTimeParser.weekdayName(for: calendar.component(.weekday, from: start)) else {
            return baseLabel
        }
        return "\(weekdayName) \(baseLabel)"
    }

    private func cursorKey(for window: SchedulingWindow, on day: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: day)
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)-\(window.label)"
    }

    private func isDate(_ date: Date, withinDays dayCount: Int, from baseDay: Date, calendar: Calendar) -> Bool {
        let day = calendar.startOfDay(for: date)
        guard let rangeEnd = calendar.date(byAdding: .day, value: dayCount, to: baseDay) else {
            return false
        }
        return day >= baseDay && day < rangeEnd
    }

    private func matchingDate(for weekday: Int, from baseDay: Date, dayCount: Int, calendar: Calendar) -> Date? {
        (0..<dayCount)
            .compactMap { calendar.date(byAdding: .day, value: $0, to: baseDay) }
            .first { calendar.component(.weekday, from: $0) == weekday }
    }

    private func clock(hour: Int, minute: Int, on day: Date, calendar: Calendar) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
    }

    private func minDateGreaterThanStart(_ dates: [Date], start: Date) -> Date? {
        dates.filter { $0 > start }.min()
    }

    private func reminderStyle(for task: TaskItem, preferences: UserPlanningPreferences) -> ReminderStyle {
        if preferences.enableTimeSensitiveReminders && task.priority == .mustDo {
            return .timeSensitive
        }
        return preferences.defaultReminderStyle == .alarmCandidate ? .gentle : preferences.defaultReminderStyle
    }

    private func reason(for task: TaskItem, context: TaskTimeContext, style: PlanningStyle) -> String {
        if style == .minimumDay {
            return "This fits a small, useful day."
        }
        if context.flexibleWindowLabel != nil {
            return "I matched the timing hint in the task text."
        }
        if context.preferredDayOfWeek != nil {
            return "I kept this on its requested weekday."
        }
        if task.estimatedMinutes <= 10 {
            return "This is short and can create momentum."
        }
        if let dueDate = task.dueDate, Calendar.current.isDateInToday(dueDate) {
            return "This is connected to today, so it gets a calm spot."
        }
        return "This fits the available window with buffer time."
    }

    private func startCursor(on day: Date, preferences: UserPlanningPreferences) -> Date {
        let start = DateFormatting.combine(day: day, time: preferences.defaultWindowStart)
        if Calendar.current.isDateInToday(day) {
            return max(roundUpToNextFive(Date()), start)
        }
        return start
    }

    private func endCursor(on day: Date, preferences: UserPlanningPreferences) -> Date {
        DateFormatting.combine(day: day, time: preferences.defaultWindowEnd)
    }

    private func availableMinutes(for preferences: UserPlanningPreferences, on day: Date) -> Int {
        let start = startCursor(on: day, preferences: preferences)
        let end = endCursor(on: day, preferences: preferences)
        return max(0, Calendar.current.dateComponents([.minute], from: start, to: end).minute ?? 0)
    }

    private func totalMinutes(for tasks: [TaskItem], preferences: UserPlanningPreferences) -> Int {
        tasks.reduce(0) { partial, task in
            partial + max(task.estimatedMinutes, preferences.defaultTaskDuration) + preferences.bufferMinutes
        }
    }

    private func roundUpToNextFive(_ date: Date) -> Date {
        let calendar = Calendar.current
        let minute = calendar.component(.minute, from: date)
        let remainder = minute % 5
        let minutesToAdd = remainder == 0 ? 0 : 5 - remainder
        let rounded = calendar.date(byAdding: .minute, value: minutesToAdd, to: date) ?? date
        return calendar.date(bySetting: .second, value: 0, of: rounded) ?? rounded
    }

    private func summary(for blocks: [AIPlannedBlock], style: PlanningStyle, unscheduledCount: Int) -> String {
        if blocks.isEmpty {
            return "No plan was added. Your inbox is still safe."
        }

        let blockWord = blocks.count == 1 ? "block" : "blocks"
        if style == .minimumDay {
            return "I made a Minimum Day with \(blocks.count) \(blockWord). This is enough for a restart."
        }

        if unscheduledCount > 0 {
            return "I made \(blocks.count) gentle \(blockWord) and kept \(unscheduledCount) item(s) for later."
        }

        return "I made \(blocks.count) gentle \(blockWord) with buffer space."
    }
}
