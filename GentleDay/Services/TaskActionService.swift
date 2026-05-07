import Foundation
import SwiftData

@MainActor
enum TaskActionService {
    static func markTaskDone(_ task: TaskItem, context: ModelContext) {
        task.status = .done
        task.touch()
        try? context.save()
    }

    static func scheduleSoon(_ task: TaskItem, preferences: UserPlanningPreferences?, context: ModelContext) {
        let minutes = task.estimatedMinutes > 0 ? task.estimatedMinutes : preferences?.defaultTaskDuration ?? 15
        let start = suggestedStart(for: task, preferences: preferences)
        let end = Calendar.current.date(byAdding: .minute, value: minutes, to: start) ?? start
        let block = ScheduleBlock(
            taskId: task.id,
            title: task.title,
            startTime: start,
            endTime: end,
            flexibleWindowLabel: task.preferredWindow?.title ?? task.flexibleWindow ?? DateFormatting.flexibleWindowLabel(for: start),
            category: task.category,
            reminderStyle: preferences?.defaultReminderStyle ?? .gentle,
            aiReason: "Scheduled from the inbox as a small next block."
        )
        task.status = .scheduled
        context.insert(block)
        try? context.save()
    }

    static func shrinkTask(_ task: TaskItem, context: ModelContext) {
        task.status = .shrunk
        task.estimatedMinutes = min(task.estimatedMinutes, 10)
        if let firstOption = task.shrinkOptions.first {
            task.suggestedTinyStep = firstOption
        }
        task.touch()
        try? context.save()
    }

    static func markBlockDone(_ block: ScheduleBlock, tasks: [TaskItem], context: ModelContext) {
        block.status = .done
        if let task = matchingTask(for: block, in: tasks) {
            task.status = .done
        }
        try? context.save()
        ReminderService.shared.cancelReminder(for: block)
    }

    static func snoozeBlock(_ block: ScheduleBlock, minutes: Int, tasks: [TaskItem], context: ModelContext) {
        block.move(byMinutes: minutes)
        block.status = .snoozed
        if let task = matchingTask(for: block, in: tasks) {
            task.status = .snoozed
        }
        try? context.save()
        reschedule(block, tasks: tasks)
    }

    static func moveBlockLater(_ block: ScheduleBlock, tasks: [TaskItem], context: ModelContext) {
        block.move(byMinutes: 60)
        if let task = matchingTask(for: block, in: tasks) {
            task.status = .moved
        }
        try? context.save()
        reschedule(block, tasks: tasks)
    }

    static func moveBlockToTomorrow(_ block: ScheduleBlock, tasks: [TaskItem], context: ModelContext) {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: block.startTime) ?? block.startTime
        let newStart = DateFormatting.combine(day: tomorrow, time: block.startTime)
        let duration = block.durationMinutes
        block.startTime = newStart
        block.endTime = calendar.date(byAdding: .minute, value: duration, to: newStart) ?? newStart
        block.flexibleWindowLabel = DateFormatting.flexibleWindowLabel(for: newStart)
        block.status = .moved
        if let task = matchingTask(for: block, in: tasks) {
            task.status = .moved
        }
        try? context.save()
        reschedule(block, tasks: tasks)
    }

    static func skipWithoutGuilt(_ block: ScheduleBlock, tasks: [TaskItem], context: ModelContext) {
        block.status = .skipped
        if let task = matchingTask(for: block, in: tasks) {
            task.status = .skipped
        }
        try? context.save()
        ReminderService.shared.cancelReminder(for: block)
    }

    static func applyShrinkOption(_ option: String, to block: ScheduleBlock, tasks: [TaskItem], context: ModelContext) {
        block.title = option
        block.resize(toMinutes: minutes(in: option) ?? 10)
        block.status = .planned
        if let task = matchingTask(for: block, in: tasks) {
            task.status = .shrunk
            task.suggestedTinyStep = option
        }
        try? context.save()
        reschedule(block, tasks: tasks)
    }

    static func matchingTask(for block: ScheduleBlock, in tasks: [TaskItem]) -> TaskItem? {
        guard let taskId = block.taskId else { return nil }
        return tasks.first { $0.id == taskId }
    }

    private static func reschedule(_ block: ScheduleBlock, tasks: [TaskItem]) {
        let task = matchingTask(for: block, in: tasks)
        Task {
            try? await ReminderService.shared.rescheduleReminder(for: block, task: task)
        }
    }

    private static func minutes(in option: String) -> Int? {
        let pattern = #"(\d+)\s*-\s*minute|(\d+)\s*min"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let range = NSRange(option.startIndex..<option.endIndex, in: option)
        guard let match = regex.firstMatch(in: option, range: range) else { return nil }

        for index in 1..<match.numberOfRanges {
            let nsRange = match.range(at: index)
            guard nsRange.location != NSNotFound, let swiftRange = Range(nsRange, in: option) else { continue }
            return Int(option[swiftRange])
        }
        return nil
    }

    private static func suggestedStart(for task: TaskItem, preferences: UserPlanningPreferences?) -> Date {
        let calendar = Calendar.current
        let now = Date()
        let targetDay = targetDay(for: task, now: now, calendar: calendar)
        let dayStart = calendar.startOfDay(for: targetDay)
        let defaultStart = preferences.map { DateFormatting.combine(day: dayStart, time: $0.defaultWindowStart) }
            ?? clock(hour: 9, minute: 0, on: dayStart, calendar: calendar)
        let eveningStart = preferences.map { DateFormatting.combine(day: dayStart, time: $0.eveningStartTime) }
            ?? clock(hour: 18, minute: 30, on: dayStart, calendar: calendar)
        let sleepTime = preferences.map { DateFormatting.combine(day: dayStart, time: $0.sleepTime) }
            ?? clock(hour: 22, minute: 30, on: dayStart, calendar: calendar)

        let preferred = switch task.preferredWindow {
        case .morning?:
            clock(hour: 9, minute: 0, on: dayStart, calendar: calendar)
        case .midday?:
            clock(hour: 12, minute: 0, on: dayStart, calendar: calendar)
        case .afternoon?:
            clock(hour: 14, minute: 0, on: dayStart, calendar: calendar)
        case .afterWork?:
            max(eveningStart, clock(hour: 17, minute: 30, on: dayStart, calendar: calendar))
        case .evening?:
            max(eveningStart, clock(hour: 18, minute: 30, on: dayStart, calendar: calendar))
        case .beforeBed?:
            calendar.date(byAdding: .minute, value: -60, to: sleepTime) ?? sleepTime
        case .anytime?, nil:
            defaultStart
        }

        if calendar.isDateInToday(dayStart) {
            let tenMinutesFromNow = calendar.date(byAdding: .minute, value: 10, to: now) ?? now
            return max(preferred, tenMinutesFromNow)
        }
        return preferred
    }

    private static func targetDay(for task: TaskItem, now: Date, calendar: Calendar) -> Date {
        if let dueDate = task.dueDate, task.mustRespectDate {
            return dueDate
        }

        if let dueDate = task.dueDate {
            return dueDate
        }

        if let preferredWeekday = task.preferredWeekday {
            let todayWeekday = calendar.component(.weekday, from: now)
            let delta = (preferredWeekday.calendarWeekday - todayWeekday + 7) % 7
            return calendar.date(byAdding: .day, value: delta, to: now) ?? now
        }

        return now
    }

    private static func clock(hour: Int, minute: Int, on day: Date, calendar: Calendar) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
    }
}
