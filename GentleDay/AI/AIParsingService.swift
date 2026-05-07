import Foundation

protocol AIParsingService {
    func parseTaskCapture(rawText: String, context: AIPlanningContext) async throws -> AITaskParseResponse
    func buildSchedule(request: AIScheduleBuildRequest) async throws -> AIScheduleBuildResponse
}

enum AIParsingFeatureError: LocalizedError {
    case disabled

    var errorDescription: String? {
        switch self {
        case .disabled:
            return "AI parsing is turned off in Settings. You can still save the raw task."
        }
    }
}

enum AIParsingServiceFactory {
    @MainActor
    static func makeService(preferences: UserPlanningPreferences) -> any AIParsingService {
        if preferences.aiMode == .mockAI {
            return MockAIParsingService()
        }
        return ProxyAIParsingService(endpointURLString: preferences.aiProxyEndpointURL)
    }
}
