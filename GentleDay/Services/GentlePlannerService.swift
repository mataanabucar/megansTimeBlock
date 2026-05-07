import Foundation

struct GentlePlannerService {
    @MainActor
    func buildSchedule(
        tasks: [TaskItem],
        existingBlocks: [ScheduleBlock],
        preferences: UserPlanningPreferences,
        range: ScheduleRange,
        style: PlanningStyle
    ) async throws -> AIScheduleBuildResponse {
        let request = AIScheduleBuildRequest(
            tasks: tasks,
            existingBlocks: existingBlocks,
            preferences: preferences,
            range: range,
            style: style
        )
        let service = AIParsingServiceFactory.makeService(preferences: preferences)
        let response = try await service.buildSchedule(request: request)
        return validate(response: response, tasks: tasks, range: range)
    }

    private func validate(
        response: AIScheduleBuildResponse,
        tasks: [TaskItem],
        range: ScheduleRange
    ) -> AIScheduleBuildResponse {
        let taskLookup = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0) })
        var warnings = response.warnings
        var filteredBlocks: [AIScheduleBlockCandidate] = []
        var carriedForward = Set(response.carriedForwardTaskIds)
        var unscheduled = Set(response.unscheduledTaskIds)

        for block in response.proposedBlocks {
            guard let taskId = block.taskId, let task = taskLookup[taskId] else {
                filteredBlocks.append(block)
                continue
            }

            if isValid(block: block, for: task, range: range) {
                filteredBlocks.append(block)
            } else {
                carriedForward.insert(task.id)
                unscheduled.insert(task.id)
                warnings.append(
                    AIImportWarning(
                        code: "timing_constraint_respected",
                        message: carryForwardMessage(for: task, attemptedStart: block.startTime),
                        taskTitle: task.title
                    )
                )
            }
        }

        let summary = warnings.last?.code == "timing_constraint_respected"
            ? "I kept a few tasks in their requested time windows instead of forcing them into the wrong slot."
            : response.friendlySummary

        return AIScheduleBuildResponse(
            proposedBlocks: filteredBlocks,
            unscheduledTaskIds: Array(unscheduled),
            carriedForwardTaskIds: Array(carriedForward),
            warnings: warnings,
            friendlySummary: summary
        )
    }

    private func isValid(block: AIScheduleBlockCandidate, for task: TaskItem, range: ScheduleRange) -> Bool {
        let calendar = Calendar.current
        let candidateDay = calendar.startOfDay(for: block.startTime)
        let today = calendar.startOfDay(for: Date())

        switch range {
        case .today:
            guard calendar.isDate(candidateDay, inSameDayAs: today) else { return false }
        case .tomorrow:
            guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today),
                  calendar.isDate(candidateDay, inSameDayAs: tomorrow) else { return false }
        case .thisWeek:
            guard isWithinThisWeek(candidateDay, now: today, calendar: calendar) else { return false }
        }

        if task.mustRespectDate, let dueDate = task.dueDate,
           !calendar.isDate(candidateDay, inSameDayAs: dueDate) {
            return false
        }

        if task.mustRespectDay, let weekday = task.preferredWeekday,
           calendar.component(.weekday, from: candidateDay) != weekday.calendarWeekday,
           !task.allowFlexiblePlacement {
            return false
        }

        if task.mustRespectWindow, let preferredWindow = task.preferredWindow,
           inferredWindow(for: block.startTime) != preferredWindow {
            return false
        }

        if range == .today && !task.canScheduleToday {
            return false
        }

        if range == .thisWeek && !task.canScheduleThisWeek {
            return false
        }

        return true
    }

    private func inferredWindow(for date: Date) -> FlexibleWindow {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<11:
            return .morning
        case 11..<13:
            return .midday
        case 13..<17:
            return .afternoon
        case 17..<20:
            return .evening
        default:
            return .beforeBed
        }
    }

    private func isWithinThisWeek(_ date: Date, now: Date, calendar: Calendar) -> Bool {
        guard let end = calendar.date(byAdding: .day, value: 7, to: now) else { return false }
        return date >= now && date < end
    }

    private func carryForwardMessage(for task: TaskItem, attemptedStart: Date) -> String {
        let attemptedWindow = DateFormatting.flexibleWindowLabel(for: attemptedStart).lowercased()
        let attemptedDay = DateFormatting.shortDate.string(from: attemptedStart)
        let requested = task.timingSummary ?? "its requested time"
        return "I kept '\(task.title)' for \(requested) instead of forcing it into \(attemptedDay) \(attemptedWindow)."
    }
}
