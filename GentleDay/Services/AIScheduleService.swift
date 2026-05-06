import Foundation

protocol AIScheduleService {
    func generatePlan(
        tasks: [TaskItem],
        existingScheduleBlocks: [ScheduleBlock],
        preferences: UserPlanningPreferences,
        scheduleRange: ScheduleRange,
        planningStyle: PlanningStyle
    ) async throws -> AIPlanResponse
}

