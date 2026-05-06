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
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Unable to create SwiftData container: \(error)")
        }
    }
}
