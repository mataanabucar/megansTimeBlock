import Foundation
import SwiftData

enum SeedDataService {
    @MainActor
    static func ensurePreferences(in context: ModelContext, existing preferences: [UserPlanningPreferences]) {
        guard preferences.isEmpty else { return }
        context.insert(UserPlanningPreferences())
        try? context.save()
    }
}

