import SwiftData
import SwiftUI

@main
struct GentleDayApp: App {
    @UIApplicationDelegateAdaptor(AppNotificationDelegate.self) private var notificationDelegate

    private let modelContainer = PersistenceController.makeModelContainer()

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .modelContainer(modelContainer)
        }
    }
}

