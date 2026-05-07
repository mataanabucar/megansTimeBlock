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
- `GentleDay/AI`: Codable AI request/response structs, the proxy-safe AI service abstraction, mock AI fallback, and the Structured Outputs schema notes.
- `GentleDay/Utilities`: formatting, colors, notification names, and string helpers.

SwiftData persists tasks, schedule blocks, planning preferences, reminder settings, and review entries locally on device.

## Custom Tab Bar Layout

The floating bottom navigation is composed in `AppRootView` with a custom `GentleTabBar` in a dedicated bottom layout slot. That keeps the pill bar visually floating while SwiftUI reserves real space for it, so the bar does not paint over the active screen.

New scrollable screens should use `GentleScrollView` instead of a raw `ScrollView`. It applies the shared page padding and `GentleLayout.scrollBottomReserve`, which lets the final card, row, or action button scroll fully above the floating tab bar. Screens with their own fixed bottom action, like Quick Capture, should use `GentleLayout.fixedBottomActionReserve` for the scroll content and place the action in a `safeAreaInset`.

Avoid adding unrelated one-off bottom padding values to individual screens; update `GentleLayout` when the tab bar dimensions or page rhythm need to change.

## What Works Now

- Bottom tabs: Home, Inbox, Plan, Review, Settings.
- Quick Capture saves raw text into the inbox with optional chips.
- Quick Capture can also use `Organize with AI`, preview structured task parsing, and still fall back to raw save if parsing fails.
- Captured items persist locally through SwiftData.
- Inbox shows unscheduled/open items with edit, schedule, done, shrink, and delete actions.
- Build My Day generates a plan through the shared planner service, with a mock AI fallback available offline.
- Minimum Day is capped and conservative.
- Today Schedule supports done, snooze, shrink, move later, tomorrow, and skip without guilt.
- What Should I Do Next shows one recommendation.
- I'm Overwhelmed hides the full list and shows only three tiny actions.
- Settings includes planning windows, buffers, reminder defaults, snooze options, Time Sensitive toggle, AI proxy/mock settings, Siri guidance, and AlarmKit notes.
- Local notification categories and actions are registered for block reminders.

## AI Parsing Setup

Gentle Day uses a secure proxy architecture for real AI parsing:

`iOS app -> hosted AI proxy endpoint -> OpenAI API -> structured JSON response -> app import`

The iOS app should never call OpenAI directly. Do not put an OpenAI API key in Swift files, `Info.plist`, assets, build settings, or the app bundle. Keep `OPENAI_API_KEY` only on the hosted proxy/backend.

Gentle Day supports two AI modes in Settings:

- `Mock AI`: local fake parsing for testing. It works offline and does not need internet or a backend.
- `OpenAI via Proxy`: real AI parsing through your hosted backend endpoint. This is the recommended real mode for normal personal use.

To use OpenAI via Proxy:

1. Open Gentle Day Settings.
2. Turn on `Enable AI parsing`.
3. Set `AI mode` to `OpenAI via Proxy`.
4. Paste your hosted proxy endpoint in `AI Proxy Endpoint URL`.
5. Test `Organize with AI` from Quick Capture.

Example development endpoint:

```text
http://<mac-wifi-ip>:8787/parse-task
```

Example production endpoint:

```text
https://your-domain.com/parse-task
```

The local Mac proxy is optional and only for development. It requires your Mac to stay awake, the server to keep running, and the iPhone to be on the same network. A hosted HTTPS proxy removes that dependency and lets the app work anywhere the iPhone has internet.

The parse request sends structured JSON with the raw capture text plus planning context: `rawText`, `currentDate`, `timezone`, `locale`, wake/sleep defaults, planning style/day, default reminder behavior, default task duration, and existing task/schedule context when available. The existing nested `context` object is still included so the local development proxy remains compatible.

The proxy response can use the app's strict schema from `GentleDay/AI/AIJSONSchema.md`, or a hosted-friendly task shape with fields such as `title`, `notes`, `dueDate`, `startDate`, `startTime`, `durationMinutes`, `priority`, `category`, `reminderPreference`, `recurrence`, `confidence`, and `clarificationNeeded`. The app normalizes successful responses into the normal AI preview/import flow. If parsing fails, the original text remains in Quick Capture so you can retry or save manually.

Quick Capture flow:

1. Enter raw task text.
2. Tap `Organize with AI`.
3. Review the structured preview.
4. Choose `Save to Inbox`, `Edit First`, or `Use Raw Text Instead`.

The planner validates returned schedule blocks before saving them locally. If a proxy or mock response tries to put a Thursday evening task into a morning slot, the app carries it forward and shows a friendly warning instead of saving the bad block.

## Development Proxy

Use the optional example in [ServerProxyExample/README.md](/Users/mataanabucar/Desktop/timeblock/megansTimeBlock/ServerProxyExample/README.md) when testing locally.

Local testing flow:

1. Start the proxy with `OPENAI_API_KEY` set server-side.
2. In Gentle Day Settings, choose `OpenAI via Proxy`.
3. Add a proxy URL such as `http://<mac-wifi-ip>:8787/parse-task`.
4. Leave `Enable AI parsing` on.
5. Test `Organize with AI` from Quick Capture.

## What Is Mocked

- `MockAIParsingService` provides local deterministic parsing and schedule building when you are offline or not ready to run a proxy yet.
- Voice capture is a UI placeholder only.
- Notification action handling posts an in-process event; deeper SwiftData updates from background actions should be finished and tested in Xcode.
- AlarmKit is a future adapter path only.

The app still contains no API keys.

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

## AI Test Inputs

Use these in Quick Capture when testing mock mode or proxy mode:

1. `Take out the trash on Thursday evening`
2. `Organize pills in the morning`
3. `Pay electric bill tomorrow`
4. `Call dentist this week`
5. `Clean the kitchen tonight but only do 10 minutes`
6. `Every Sunday afternoon meal prep`
7. `Remind me to put the bins out every Thursday night`

## Xcode Finishing Checklist

- Open project in Xcode.
- Select signing team.
- Set a private bundle identifier.
- Check deployment target and SwiftData availability.
- Add a real app icon if desired.
- Test Quick Capture persistence after app restart.
- Test local notification permission on real iPhone.
- Test reminder scheduling, snooze, move later, and skip actions.
- Test `Organize with AI` in mock mode first, then proxy mode.
- Confirm Thursday/evening tasks are not pulled into the wrong day or morning window.
- Enable Time Sensitive notifications only if supported and appropriate.
- Test Siri Announce Notifications manually in iOS Settings.
- Add AlarmKit only if using a supported Xcode/iOS target.
- Test all reminder actions on device.

## VS Code Validation Notes

This workspace was scaffolded from VS Code. When validating from a shell that points `xcode-select` at Command Line Tools, run Xcode builds with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.

Completed local checks:

- Confirmed no existing Xcode project or Swift package existed before scaffolding.
- Created one `GentleDay.xcodeproj`; no duplicate app project was created.
- Verified all Swift files are referenced by `project.pbxproj`.
- Ran `git diff --check`.
- Searched the app source for requested shame/work vocabulary and found no matches.

test
