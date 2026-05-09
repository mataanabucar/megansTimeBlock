import Foundation
import SwiftData

enum SeedDataService {
    @MainActor
    static func ensurePreferences(in context: ModelContext, existing preferences: [UserPlanningPreferences]) {
        AIProxyConfiguration.migrateLegacyUserDefaults()

        guard preferences.isEmpty else {
            migrateLegacyAIProxyEndpoints(in: preferences, context: context)
            return
        }

        context.insert(UserPlanningPreferences())
        try? context.save()
    }

    @MainActor
    private static func migrateLegacyAIProxyEndpoints(
        in preferences: [UserPlanningPreferences],
        context: ModelContext
    ) {
        var didMigrate = false
        for preference in preferences {
            let migratedEndpoint = AIProxyConfiguration.endpointStringByReplacingLegacyEndpoint(
                preference.aiProxyEndpointURL
            )
            guard migratedEndpoint != preference.aiProxyEndpointURL else { continue }

            preference.aiProxyEndpointURL = migratedEndpoint
            preference.touch()
            didMigrate = true
        }

        if didMigrate {
            try? context.save()
        }
    }
}
