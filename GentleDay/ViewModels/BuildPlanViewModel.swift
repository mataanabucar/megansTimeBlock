import Foundation
import Observation

@MainActor
@Observable
final class BuildPlanViewModel {
    var selectedRange: ScheduleRange = .today
    var selectedStyle: PlanningStyle = .balancedDay
    var isGenerating = false
    var response: AIPlanResponse?
    var errorMessage: String?

    @ObservationIgnored private let service: any AIScheduleService

    init(service: any AIScheduleService = MockAIScheduleService()) {
        self.service = service
    }

    func generate(
        tasks: [TaskItem],
        existingScheduleBlocks: [ScheduleBlock],
        preferences: UserPlanningPreferences
    ) async -> AIPlanResponse? {
        isGenerating = true
        errorMessage = nil
        defer { isGenerating = false }

        do {
            let result = try await service.generatePlan(
                tasks: tasks,
                existingScheduleBlocks: existingScheduleBlocks,
                preferences: preferences,
                scheduleRange: selectedRange,
                planningStyle: selectedStyle
            )
            response = result
            return result
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}

