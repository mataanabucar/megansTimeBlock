import UIKit
import UserNotifications

final class AppNotificationDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        ReminderService.shared.configure()
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        let blockId = userInfo["blockId"] as? String

        NotificationCenter.default.post(
            name: .gentleNotificationActionReceived,
            object: nil,
            userInfo: [
                "actionIdentifier": response.actionIdentifier,
                "blockId": blockId ?? ""
            ]
        )

        // TODO: During Xcode/device testing, connect these action events to SwiftData updates.
        // The delegate is wired here, but background action mutation needs careful ModelContainer access.
    }
}

