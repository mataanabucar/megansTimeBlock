import Foundation

#if canImport(AlarmKit)
import AlarmKit
#endif

enum AlarmKitReminderService {
    static var isAvailableInCurrentSDK: Bool {
        #if canImport(AlarmKit)
        true
        #else
        false
        #endif
    }

    static let futureSupportNote = """
    AlarmKit is reserved for must-not-miss reminders if the final Xcode and iOS target support it.
    Gentle Day currently uses standard local notifications and does not claim silent-mode bypass.
    """

    // TODO: Add a real AlarmKit adapter only after confirming availability in Xcode and testing on a real iPhone.
}

