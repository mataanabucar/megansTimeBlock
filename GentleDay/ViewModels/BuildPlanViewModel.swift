import Foundation
import Observation

@MainActor
@Observable
final class BuildPlanViewModel {
    var selectedRange: ScheduleRange = .today
    var selectedStyle: PlanningStyle = .balancedDay
    var isGenerating = false
    var response: AIScheduleBuildResponse?
    var errorMessage: String?

    @ObservationIgnored private let planner = GentlePlannerService()

    func applyDefaults(from preferences: UserPlanningPreferences) {
        selectedRange = preferences.defaultScheduleRange
        selectedStyle = preferences.defaultPlanningStyle
    }

    func generate(
        tasks: [TaskItem],
        existingScheduleBlocks: [ScheduleBlock],
        preferences: UserPlanningPreferences
    ) async -> AIScheduleBuildResponse? {
        isGenerating = true
        errorMessage = nil
        defer { isGenerating = false }

        do {
            let result = try await planner.buildSchedule(
                tasks: tasks,
                existingBlocks: existingScheduleBlocks,
                preferences: preferences,
                range: selectedRange,
                style: selectedStyle
            )
            response = result
            return result
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}
