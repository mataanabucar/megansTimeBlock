import Foundation

struct MockAIParsingService: AIParsingService {
    func parseTaskCapture(rawText: String, context: AIPlanningContext) async throws -> AITaskParseResponse {
        let captureItems = captureItems(from: rawText)
        let candidates = captureItems.map { item in
            candidate(from: item, currentDate: context.currentDate)
        }

        let warnings = candidates.compactMap { candidate -> AIImportWarning? in
            guard candidate.needsReview else { return nil }
            return AIImportWarning(
                code: "needs_review",
                message: candidate.friendlyNote ?? "Please review this task before saving.",
                taskTitle: candidate.cleanedTitle
            )
        }

        let summary = friendlySummary(for: candidates)
        return AITaskParseResponse(
            tasks: candidates,
            warnings: warnings,
            friendlySummary: summary,
            needsReview: candidates.contains(where: \.needsReview)
        )
    }

    func buildSchedule(request: AIScheduleBuildRequest) async throws -> AIScheduleBuildResponse {
        let service = MockAIScheduleService()
        let response = try await service.generatePlan(
            tasks: request.tasks.map { $0.makeTaskItem() },
            existingScheduleBlocks: request.existingBlocks.map { $0.makeScheduleBlock() },
            preferences: request.preferences.makePreferences(),
            scheduleRange: request.range,
            planningStyle: request.style
        )

        return AIScheduleBuildResponse(
            proposedBlocks: response.proposedScheduleBlocks.map(AIScheduleBlockCandidate.init(plannedBlock:)),
            unscheduledTaskIds: response.unscheduledTaskIDs,
            carriedForwardTaskIds: response.unscheduledTaskIDs,
            warnings: response.warnings.map(AIImportWarning.init(planWarning:)),
            friendlySummary: response.friendlySummary
        )
    }

    private func candidate(from rawText: String, currentDate: Date) -> AITaskCandidate {
        let hint = NaturalTimeParser.parse(rawText, now: currentDate)
        let category = inferredCategory(from: rawText)
        let minutes = max(1, hint.estimatedMinutes ?? 15)
        let priority: PriorityLevel
        if let dueDate = hint.preferredDate, Calendar.current.isDateInToday(dueDate) {
            priority = .high
        } else if hint.mustRespectDate {
            priority = .high
        } else {
            priority = .normal
        }

        let note = friendlyNote(for: hint, title: hint.cleanedTitle)
        return AITaskCandidate(
            rawText: rawText,
            cleanedTitle: hint.cleanedTitle,
            notes: nil,
            category: category,
            priority: priority,
            energyLevel: minutes <= 10 ? .quickWin : nil,
            estimatedMinutes: minutes,
            preferredDate: hint.preferredDate,
            preferredDayOfWeek: hint.preferredDayOfWeek,
            preferredWindow: hint.preferredWindow,
            flexibleWindowLabel: hint.preferredWindow?.title ?? hint.flexibleWindowLabel,
            dueDate: hint.preferredDate,
            isRecurring: hint.recurrenceHint != nil,
            recurrenceRule: hint.recurrenceHint,
            tinyStep: TaskItem.makeTinyStep(from: rawText),
            shrinkOptions: TaskItem.makeShrinkOptions(from: rawText, estimatedMinutes: minutes),
            confidence: confidence(for: hint),
            needsReview: hint.cleanedTitle == "Untitled task",
            friendlyNote: note,
            scheduleRule: AIScheduleRule(
                canScheduleToday: hint.canScheduleToday,
                canScheduleThisWeek: hint.canScheduleThisWeek,
                mustRespectDate: hint.mustRespectDate,
                mustRespectDay: hint.mustRespectDay,
                mustRespectWindow: hint.mustRespectWindow,
                allowFlexiblePlacement: hint.allowFlexiblePlacement
            )
        )
    }

    private func captureItems(from rawText: String) -> [String] {
        TaskCaptureSplitter.split(rawText)
    }

    private func inferredCategory(from text: String) -> TaskCategory {
        let lowered = text.lowercased()
        if lowered.contains("laundry") || lowered.contains("kitchen") || lowered.contains("dish") || lowered.contains("trash") {
            return .cleaning
        }
        if lowered.contains("bill") || lowered.contains("pay") || lowered.contains("bank") {
            return .money
        }
        if lowered.contains("doctor") || lowered.contains("dentist") || lowered.contains("appointment") || lowered.contains("med") || lowered.contains("pill") {
            return .health
        }
        if lowered.contains("grocer") || lowered.contains("pickup") || lowered.contains("pick up") || lowered.contains("store") || lowered.contains("errand") {
            return .errand
        }
        if lowered.contains("meal") || lowered.contains("cook") || lowered.contains("prep") {
            return .meal
        }
        if lowered.contains("remind") || lowered.contains("remember") {
            return .reminder
        }
        if lowered.contains("every ") {
            return .habit
        }
        if lowered.contains("mom") || lowered.contains("dad") || lowered.contains("kid") || lowered.contains("family") {
            return .family
        }
        return .personal
    }

    private func confidence(for hint: NaturalTimeHint) -> Double {
        var score = 0.72
        if hint.preferredDate != nil || hint.preferredDayOfWeek != nil {
            score += 0.08
        }
        if hint.preferredWindow != nil {
            score += 0.08
        }
        if hint.estimatedMinutes != nil {
            score += 0.04
        }
        return min(score, 0.96)
    }

    private func friendlySummary(for candidates: [AITaskCandidate]) -> String {
        guard let first = candidates.first else {
            return "I couldn't pull out a task yet. You can still save the raw text."
        }
        if candidates.count == 1, let note = first.friendlyNote {
            return note
        }
        return "I organized \(candidates.count) tasks for review before saving."
    }

    private func friendlyNote(for hint: NaturalTimeHint, title: String) -> String? {
        var targetParts: [String] = []
        if let preferredDate = hint.preferredDate {
            if Calendar.current.isDateInToday(preferredDate) {
                targetParts.append("today")
            } else if Calendar.current.isDateInTomorrow(preferredDate) {
                targetParts.append("tomorrow")
            } else {
                targetParts.append(DateFormatting.shortDate.string(from: preferredDate))
            }
        } else if let preferredDayOfWeek = hint.preferredDayOfWeek {
            targetParts.append(preferredDayOfWeek.title)
        }

        if let preferredWindow = hint.preferredWindow {
            targetParts.append(preferredWindow.title.lowercased())
        }

        guard !targetParts.isEmpty else { return nil }
        return "I'll keep '\(title)' for \(targetParts.joined(separator: " "))."
    }
}

private extension AIScheduleBlockCandidate {
    init(plannedBlock: AIPlannedBlock) {
        self.taskId = plannedBlock.taskId
        self.title = plannedBlock.title
        self.startTime = plannedBlock.startTime
        self.endTime = plannedBlock.endTime
        self.flexibleWindowLabel = plannedBlock.flexibleWindowLabel
        self.category = plannedBlock.category
        self.reminderStyle = plannedBlock.reminderStyle
        self.aiReason = plannedBlock.aiReason
    }
}

private extension AIImportWarning {
    init(planWarning: AIPlanWarning) {
        self.code = "planner_warning"
        self.message = planWarning.message
        self.taskTitle = nil
    }
}
