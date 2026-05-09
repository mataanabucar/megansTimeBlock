import Foundation

enum AIProxyConfiguration {
    static let hostedEndpointURLString = "https://gentle-day-ai-proxy.vercel.app/api/parse-task"

    private static let legacyEndpointMarkers = [
        "localhost",
        "127.0.0.1",
        ".local",
        ":8787",
        "voice-dump-text",
        "gentle-day-ai-proxy-q0zvn9zha"
    ]

    private static let legacyUserDefaultsKeys = [
        "aiProxyEndpointURL",
        "AIProxyEndpointURL",
        "GentleDayAIProxyEndpointURL",
        "GentleDayVoiceAPIBaseURL"
    ]

    static func normalizedEndpointString(_ endpoint: String) -> String {
        endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func endpointStringByReplacingLegacyEndpoint(_ endpoint: String) -> String {
        shouldReplaceSavedEndpoint(endpoint) ? hostedEndpointURLString : endpoint
    }

    static func shouldReplaceSavedEndpoint(_ endpoint: String) -> Bool {
        let normalized = normalizedEndpointString(endpoint)
        guard !normalized.isEmpty else { return false }

        let lowercasedEndpoint = normalized.lowercased()
        return legacyEndpointMarkers.contains { lowercasedEndpoint.contains($0) }
    }

    static func migrateLegacyUserDefaults(_ defaults: UserDefaults = .standard) {
        for key in legacyUserDefaultsKeys {
            guard let savedEndpoint = defaults.string(forKey: key),
                  shouldReplaceSavedEndpoint(savedEndpoint) else {
                continue
            }

            defaults.set(hostedEndpointURLString, forKey: key)
        }
    }

    static func sanitizedEndpointDescription(_ url: URL) -> String {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return "\(url.scheme ?? "unknown")://\(url.host ?? "unknown")\(url.path)"
        }

        components.user = nil
        components.password = nil
        components.query = nil
        components.fragment = nil

        return components.url?.absoluteString ?? "\(url.scheme ?? "unknown")://\(url.host ?? "unknown")\(url.path)"
    }
}
