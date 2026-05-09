import Foundation
import SwiftData

enum PersistenceController {
    static var schema: Schema {
        Schema([
            TaskItem.self,
            ScheduleBlock.self,
            UserPlanningPreferences.self,
            ReviewEntry.self
        ])
    }

    static func makeModelContainer() -> ModelContainer {
        do {
            try ensureApplicationSupportDirectoryExists()
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Unable to create SwiftData container: \(error)")
        }
    }

    private static func ensureApplicationSupportDirectoryExists() throws {
        guard let applicationSupportURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            return
        }

        try FileManager.default.createDirectory(
            at: applicationSupportURL,
            withIntermediateDirectories: true
        )
    }
}
