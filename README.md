# Gentle Day

Gentle Day is a private personal iOS SwiftUI app for everyday life time-blocking. It is designed for chores, errands, reminders, routines, appointments, family/home planning, wellness, meals, bills, and general life admin.

The app is intentionally not built for coding work, tickets, sprints, job productivity, analytics, subscriptions, cloud sync, or App Store distribution.

## ADHD-Friendly Principles

- Capture first, sort later.
- Preserve the original raw input for every captured task.
- Show one next step when the user feels overwhelmed.
- Keep schedules flexible, movable, and recoverable.
- Prefer gentle language: restart, shrink, move later, one small step, minimum day, skip without guilt.
- Carry extra tasks forward instead of forcing them into a packed day.
- Avoid shame-based status, scoring, or streak mechanics.

## Architecture

The app uses a simple SwiftUI + SwiftData structure:

- `GentleDay/Models`: SwiftData models and shared enums.
- `GentleDay/Views`: Home, Quick Capture, Inbox, Plan, Today Schedule, Next Action, Overwhelmed, Review, and Settings screens.
- `GentleDay/ViewModels`: lightweight state for capture, planning, and next-action selection.
- `GentleDay/Services`: planner protocol, mock planner, and task action helpers.
- `GentleDay/Persistence`: SwiftData container and default preference setup.
- `GentleDay/Notifications`: local notification manager, actions, app delegate bridge, and AlarmKit placeholder.
- `GentleDay/AI`: Codable AI request/response structs and an unimplemented OpenAI adapter placeholder.
- `GentleDay/Utilities`: formatting, colors, notification names, and string helpers.

SwiftData persists tasks, schedule blocks, planning preferences, reminder settings, and review entries locally on device.

## What Works Now

- Bottom tabs: Home, Inbox, Plan, Review, Settings.
- Quick Capture saves raw text into the inbox with optional chips.
- Captured items persist locally through SwiftData.
- Inbox shows unscheduled/open items with edit, schedule, done, shrink, and delete actions.
- Build My Day generates a local mock plan from inbox tasks and preferences.
- Minimum Day is capped and conservative.
- Today Schedule supports done, snooze, shrink, move later, tomorrow, and skip without guilt.
- What Should I Do Next shows one recommendation.
- I'm Overwhelmed hides the full list and shows only three tiny actions.
- Settings includes planning windows, buffers, reminder defaults, snooze options, Time Sensitive toggle, Siri guidance, and AlarmKit notes.
- Local notification categories and actions are registered for block reminders.

## What Is Mocked

- AI scheduling is local and deterministic through `MockAIScheduleService`.
- `OpenAIScheduleService` is a placeholder and intentionally throws `notImplemented`.
- Voice capture is a UI placeholder only.
- Notification action handling posts an in-process event; deeper SwiftData updates from background actions should be finished and tested in Xcode.
- AlarmKit is a future adapter path only.

No API keys or network calls are included.

## Notification Behavior

Gentle Day currently uses standard local notifications via UserNotifications.

- Category: `GENTLE_BLOCK_REMINDER`
- Actions: Start, Snooze 5 min, Snooze 15 min, Shrink, Move Later, Skip Without Guilt
- Example body: `Your next block is ready. Start laundry. Put clothes in the washer.`

Time Sensitive notifications can be requested for important reminders when enabled in Settings, but they still depend on iOS permission and user settings.

Critical Alerts are not planned. They require a special Apple entitlement and are not appropriate for this private foundation.

Normal local notifications do not bypass silent mode. The `alarmCandidate` reminder style is only a future AlarmKit path.

## Siri Announce Notifications

The app cannot force Siri to speak reminders. Siri verbal announcements are controlled by iOS Settings.

On iPhone, test this manually through:

1. Open Settings.
2. Go to Notifications.
3. Open Announce Notifications.
4. Enable the setting for the device/headphones setup you use.
5. Trigger a Gentle Day local reminder on device and listen for the announcement.

Notification copy is kept short and voice-friendly so it can be read naturally if the user enables Announce Notifications.

## AlarmKit Future Work

`AlarmKitReminderService` is a compile-safe placeholder. Add real AlarmKit support only if your final Xcode and iOS deployment target support it.

Use AlarmKit only for must-not-miss reminders after real iPhone testing. Do not treat standard notifications as alarms or silent-mode bypass.

## Open In Xcode

1. Open `GentleDay.xcodeproj` in Xcode.
2. Select the `GentleDay` scheme.
3. Select the `GentleDay` target.
4. Set your Apple signing team.
5. Change `PRODUCT_BUNDLE_IDENTIFIER` from `com.example.GentleDay` to your private identifier.
6. Confirm the deployment target. The project currently targets iOS 17.0 for SwiftData and Observation.
7. Build on an iOS Simulator first.
8. Run on a real iPhone for notification behavior.

## Xcode Finishing Checklist

- Open project in Xcode.
- Select signing team.
- Set a private bundle identifier.
- Check deployment target and SwiftData availability.
- Add a real app icon if desired.
- Test Quick Capture persistence after app restart.
- Test local notification permission on real iPhone.
- Test reminder scheduling, snooze, move later, and skip actions.
- Enable Time Sensitive notifications only if supported and appropriate.
- Test Siri Announce Notifications manually in iOS Settings.
- Add AlarmKit only if using a supported Xcode/iOS target.
- Test all reminder actions on device.

## VS Code Validation Notes

This workspace was scaffolded from VS Code. Native Apple build validation could not run in this host because neither `swift` nor `xcodebuild` is available on PATH, and the iOS App Builder plugin's simulator discovery failed with `spawn xcrun ENOENT`.

Completed local checks:

- Confirmed no existing Xcode project or Swift package existed before scaffolding.
- Created one `GentleDay.xcodeproj`; no duplicate app project was created.
- Verified all Swift files are referenced by `project.pbxproj`.
- Ran `git diff --check`.
- Searched the app source for requested shame/work vocabulary and found no matches.

