import Foundation

enum OpenAIScheduleServiceError: LocalizedError {
    case notImplemented

    var errorDescription: String? {
        "OpenAI scheduling is intentionally not connected yet."
    }
}

struct OpenAIScheduleService: AIScheduleService {
    func generatePlan(
        tasks: [TaskItem],
        existingScheduleBlocks: [ScheduleBlock],
        preferences: UserPlanningPreferences,
        scheduleRange: ScheduleRange,
        planningStyle: PlanningStyle
    ) async throws -> AIPlanResponse {
        // Future adapter: convert the Codable AIPlanRequest to JSON and send it to an app-owned API layer.
        // Do not add API keys or direct network calls in this private local foundation.
        throw OpenAIScheduleServiceError.notImplemented
    }
}

