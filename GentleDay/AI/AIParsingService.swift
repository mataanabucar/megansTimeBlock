import Foundation

protocol AIParsingService {
    func parseTaskCapture(rawText: String, context: AIParsingContext) async throws -> AITaskParseResponse
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
        switch preferences.aiMode {
        case .mockAI:
            return MockAIParsingService()
        case .openAIProxy:
            let endpoint = AIProxyConfiguration.endpointStringByReplacingLegacyEndpoint(
                preferences.aiProxyEndpointURL
            )
            if endpoint != preferences.aiProxyEndpointURL {
                preferences.aiProxyEndpointURL = endpoint
                preferences.touch()
            }
            return ProxyAIParsingService(endpointURLString: endpoint)
        }
    }
}
