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

        let candidateTasks = sortedCandidates(
            from: tasks,
            request: request,
            style: planningStyle
        )

        let taskLimit = limit(for: planningStyle, range: scheduleRange)
        let limitedTasks = Array(candidateTasks.prefix(taskLimit))
        let planned = makeBlocks(
            from: limitedTasks,
            preferences: preferences,
            range: scheduleRange,
            style: planningStyle
        )

        let plannedTaskIDs = Set(planned.compactMap(\.taskId))
        let unscheduledTaskIDs = candidateTasks
            .filter { !plannedTaskIDs.contains($0.id) }
            .map(\.id)

        var warnings: [AIPlanWarning] = []
        if scheduleRange == .today && totalMinutes(for: limitedTasks, preferences: preferences) > availableMinutes(for: preferences, on: Date()) {
            warnings.append(AIPlanWarning(
                message: "This may be too much for one evening.",
                suggestion: "Try Minimum Day or move a few things to tomorrow."
            ))
        }

        if !unscheduledTaskIDs.isEmpty {
            warnings.append(AIPlanWarning(
                message: "I moved a few items forward so today stays realistic.",
                suggestion: "They will stay safe in your inbox."
            ))
        }

        if planningStyle == .minimumDay && candidateTasks.count > planned.count {
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

    private func score(_ task: TaskItem, style: PlanningStyle) -> Int {
        var value = 0

        switch task.priority {
        case .essential: value += 60
        case .important: value += 40
        case .normal: value += 20
        case .soft: value += 5
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
            if task.category == .home || task.category == .cleaning || task.category == .routine { value += 35 }
        case .catchUpDay:
            if task.priority == .important || task.priority == .essential { value += 20 }
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
        let baseDay = DateFormatting.startDate(for: range)
        let dayCount = range == .thisWeek ? 5 : 1
        var currentDayOffset = 0
        var cursor = startCursor(on: baseDay, preferences: preferences)
        var dayEnd = endCursor(on: baseDay, preferences: preferences)
        var blocks: [AIPlannedBlock] = []

        for task in tasks {
            let duration = adjustedDuration(for: task, style: style, preferences: preferences)
            var end = calendar.date(byAdding: .minute, value: duration, to: cursor) ?? cursor

            while end > dayEnd && currentDayOffset < dayCount - 1 {
                currentDayOffset += 1
                let nextDay = calendar.date(byAdding: .day, value: currentDayOffset, to: baseDay) ?? baseDay
                cursor = startCursor(on: nextDay, preferences: preferences)
                dayEnd = endCursor(on: nextDay, preferences: preferences)
                end = calendar.date(byAdding: .minute, value: duration, to: cursor) ?? cursor
            }

            guard end <= dayEnd else { break }

            let block = AIPlannedBlock(
                id: UUID(),
                taskId: task.id,
                title: task.title,
                startTime: cursor,
                endTime: end,
                flexibleWindowLabel: task.flexibleWindow ?? DateFormatting.flexibleWindowLabel(for: cursor),
                category: task.category,
                reminderStyle: reminderStyle(for: task, preferences: preferences),
                aiReason: reason(for: task, style: style)
            )
            blocks.append(block)

            cursor = calendar.date(byAdding: .minute, value: duration + preferences.bufferMinutes, to: cursor) ?? end
        }

        return blocks
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

    private func reminderStyle(for task: TaskItem, preferences: UserPlanningPreferences) -> ReminderStyle {
        if preferences.enableTimeSensitiveReminders && task.priority == .essential {
            return .timeSensitive
        }
        return preferences.defaultReminderStyle == .alarmCandidate ? .gentle : preferences.defaultReminderStyle
    }

    private func reason(for task: TaskItem, style: PlanningStyle) -> String {
        if style == .minimumDay {
            return "This fits a small, useful day."
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

