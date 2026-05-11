# Gentle Day — Privacy and Sensitive Context Rules

Audience: coding agents (Codex, Claude Code) and human reviewers implementing Gentle Day.

Companion to [`recovery-sensitive-scheduling-spec.md`](./recovery-sensitive-scheduling-spec.md). Where the spec defines *behavior*, this document defines *what must never leak through any surface* — identifiers, labels, copy, payloads, logs, analytics, exports, AI outputs, errors, and comments.

Scope: this is an implementation checklist for a private, on-device iOS planning app. It is not a legal compliance document (HIPAA, GDPR, CCPA) and does not replace legal review. It is also not clinical guidance.

Guiding rule, in one line:

> The fact that a user has recovery-related routines is private metadata. It must influence scheduling, and it must never be visible in any surface — visual, textual, network, on-disk, in-log, in-export, or in-source — that could reveal that context to anyone other than the user opening the app.

---

## 1. Privacy checklist

Use this as a pre-merge gate. Every item must be checkable by reading code, running a test, or grepping the repo.

### A. Identifiers and naming

- [ ] No identifier in source (type names, enum cases, properties, functions, files, assets, string keys, test names, CI job names) references addiction, alcohol, substances, rehab, sobriety, sponsors, programs, twelve-step language, diagnoses, the user's relationship to the developer, or any clinical condition.
- [ ] No identifier encodes a specific real person's name, role, or family relationship.
- [ ] Internal names describe **scheduling behavior** ("daytime recovery window", "low effort errand", "support meeting"), not **personal history** ("post-rehab", "AA because of X").
- [ ] The `TaskCategory` enum and its cases use neutral, behavior-oriented names (see §2).
- [ ] Localized string keys (`.strings`, `.stringsdict`, `Localizable.xcstrings`) use neutral keys. No key like `"aa_meeting_reminder"` or `"sobriety_block_label"`.

### B. Visible surfaces

- [ ] No UI label, button, empty state, onboarding screen, settings row, tooltip, or accessibility label contains any deny-list word from the spec's §9.
- [ ] No calendar/widget/Siri/Shortcuts/Spotlight surface exposes a category word.
- [ ] No notification body, subtitle, or title contains a category word — only the user-typed title and optional user-typed note (spec §8.6, §15 S7).
- [ ] No lock-screen preview, notification grouping summary, or Live Activity surface adds category-identifying text.
- [ ] No icon, color swatch, badge, or visual treatment is used *exclusively* for recovery-tagged items (no implicit visual outing).
- [ ] App name, bundle display name, icon, and launch screen are neutral. Nothing in the SpringBoard tile hints at the category.

### C. Storage

- [ ] All user data persists locally via SwiftData. No iCloud, no CloudKit, no cross-device sync in v1.
- [ ] The `category` field is on-device only, never serialized to any network payload, never written to any export, never included in any debug dump.
- [ ] No App Group, no shared keychain entry, no shared UserDefaults suite exposes category data to other processes (extensions, widgets) unless the extension is also covered by these rules and reviewed.
- [ ] No file written to disk (cache, temp, Documents, Application Support) contains the word "recovery", "AA", "sobriety", etc. in its filename or path.
- [ ] Database/field names are neutral (see §7).

### D. Network

- [ ] The iOS app never calls OpenAI or any third-party LLM directly. All AI traffic goes through the configured Vercel proxy (spec §8.3).
- [ ] The proxy request payload contains: `rawText`, `currentDate`, `timezone`, `locale`, default wake/sleep, planning style, default duration, and generic existing-task context. It does **not** contain `category`, `tag`, `isRecovery`, or any field that labels content as recovery-related.
- [ ] The proxy response is parsed defensively. If a future proxy version returns a `category` hint, the iOS app discards it before persisting.
- [ ] No analytics SDK, crash reporter with PII, attribution SDK, A/B test framework, remote config service, or feature flag service is linked into the iOS target.
- [ ] No background fetch, no silent push, no server-initiated state change.
- [ ] App Transport Security is on. Only the configured proxy host is reachable for AI; everything else routes through standard iOS frameworks (notifications, speech) that stay on-device.

### E. Logging and diagnostics

- [ ] No `print`, `NSLog`, `os_log`, `Logger`, or `debugPrint` of task titles, raw text, notes, block contents, or category in release builds.
- [ ] Debug-only logs (gated behind `#if DEBUG`) may print task titles **only** if the build configuration is not Release and only to the local console. They must still never print `category`.
- [ ] Crash reports (if Apple's built-in crash collection is enabled by the user via iOS Settings) must not include user content in any custom keys, breadcrumbs, or unhandled-exception payloads.
- [ ] No log file is written to disk that contains user text.
- [ ] `os_signpost` and Instruments traces must not embed user text.

### F. Analytics

- [ ] There are no analytics. No event names, no counters, no funnels, no session tracking, no telemetry endpoints (spec §8.5).
- [ ] If a future analytics feature is proposed, it must be opt-in, on-device-only, aggregated, and reviewed against this document. Until then, the analytics module simply does not exist.

### G. Exports and sharing

- [ ] No automatic export. Any export is user-initiated via the iOS share sheet.
- [ ] Exported content (e.g. a day summary copied to Notes, Mail, Messages) contains **only** the user-typed titles and times. It must not include `category`, the word "recovery", category-derived emoji/icons, or any planner-generated commentary about why a block was scheduled.
- [ ] Share sheet previews (the snippet iOS shows in the share UI) must be safe to display on a lock screen.
- [ ] No "share my day with my sponsor / partner / coach" feature in v1.

### H. AI-generated content

- [ ] AI output is rendered as plain task titles, durations, and times. The app strips any AI-generated commentary that uses deny-list vocabulary before display (spec §9).
- [ ] AI output never gains a "why this was suggested" justification field that names recovery context.
- [ ] If the AI returns a category guess, the app may use it internally for scheduling preference (subject to §7), but must not display it.
- [ ] The proxy prompt template (server-side) must not instruct the model to ask about recovery, sobriety, mood, or feelings. Prompt review is part of this checklist.

### I. Error messages

- [ ] Errors are neutral and short (spec §9).
- [ ] No error message echoes the user's task text back into a UI alert unless that text is already on the same screen.
- [ ] No error message names the category, the recurrence pattern, or any planner heuristic.
- [ ] Network errors say "Couldn't reach the assistant. Your text is saved." — not "Failed to send your AA meeting to OpenAI."

### J. Developer-facing surfaces

- [ ] Source comments, TODOs, FIXMEs, and commit messages do not encode personal context. Describe the *rule* ("recovery-typed blocks prefer daytime"), not the *person* or *reason* ("because user is in recovery from X").
- [ ] PR titles, branch names, issue titles, and CI job names follow the same rule.
- [ ] README, CONTRIBUTING, and any developer docs check into the repo do not narrate the user's personal history.
- [ ] Sample data, fixtures, snapshot tests, and onboarding seed content use neutral example tasks ("Walk", "Groceries", "Meeting at 10") and never reference recovery, AA, sobriety, or substances.
- [ ] Screenshots in the repo (App Store assets, README images, marketing material) do not contain recovery-identifying text.

---

## 2. Safe naming conventions

Use **behavior-oriented, generic** names. Prefer the patterns on the left over anything that encodes diagnosis, substance, program, or relationship.

### Enums and cases

```swift
enum TaskCategory: String, Codable, Sendable {
    case recovery     // private; means "support / routine / meeting" in scheduling rules
    case errand
    case family
    case home
    case admin
    case selfCare
    case other
}
```

`recovery` here is the internal scheduling key only. It is **never** rendered, **never** serialized, **never** logged. Treat it as opaque metadata; the value's spelling matters less than the rules that gate where it can appear (see §7).

If you prefer an even more abstract internal name, `case support` is acceptable. Do not use `aa`, `sobriety`, `program`, `meeting12step`, `rehab`, or anything substance-specific.

### Settings / preferences keys

Prefer:

- `recoveryFocusEnabled` *(boolean, default true)* — whether scheduling rules in spec §4 apply
- `daytimeRecoveryWindowStart` / `daytimeRecoveryWindowEnd`
- `daycareAvailableWindowStart` / `daycareAvailableWindowEnd`
- `eveningCutoff`
- `maxBlocksPerDay`
- `reserveDailyQuietBlock`
- `lowEffortErrandEnabled` *(toggles Kroger-pickup-style shorter form)*
- `defaultSupportMeetingDurationMinutes`
- `defaultSupportMeetingBufferMinutes`

Avoid:

- `aaModeEnabled`, `sobrietyModeOn`, `rehabReminderOn`, `sponsorCheckinEnabled`, `partnerRecoveryMode`, etc.

### Scheduling internals

Prefer:

- `dayTimeWindow`, `eveningWindow`, `windDownWindow`
- `supportBlock`, `supportMeeting`, `supportSession` *(internal, never rendered)*
- `lowEffortErrand`, `fullStoreErrand`
- `quietBlock`, `restBlock`
- `carryForward`, `skipForToday`

Avoid:

- `aaSlot`, `meetingSlot12Step`, `sobrietyBlock`, `clinicalBlock`, `therapyBlock` (unless the user explicitly types those titles)

### File and module names

Prefer:

- `Planning/`, `Scheduling/`, `Categories/`, `SupportRoutines/`
- `SupportSchedulingRules.swift`, `LowEffortErrandOption.swift`, `DaytimeWindow.swift`

Avoid:

- `Recovery/`, `AA/`, `Sobriety/`, `RehabSupport.swift`, anything that names the personal context in a filename.

### Localized string keys

Prefer:

- `"empty_state.inbox"`, `"empty_state.day"`, `"action.skip_today"`, `"action.shrink_block"`, `"action.move_to_morning"`, `"error.network.generic"`, `"error.save.generic"`

Avoid:

- `"aa_reminder_title"`, `"sobriety_streak_label"`, `"recovery_check_in_prompt"` — even if the value is neutral, the *key* leaks context into source and translation memory systems.

---

## 3. Unsafe naming examples

The following patterns are **prohibited** anywhere in source, comments, identifiers, keys, fixtures, tests, branch names, or commit messages. The list is illustrative, not exhaustive — the rule is "no identifier encodes diagnosis, substance, treatment, program, sponsor relationship, or the user's personal history."

Prohibited identifier patterns (any case, any separator):

- `alcohol*`, `addict*`, `substance*`, `drug*`, `relapse*`, `craving*`, `trigger*` (as a clinical noun), `sober*`, `sobriety*`
- `aa*` as a category or feature name (e.g. `aaSlot`, `AAMeetingService`)
- `alAnon*`, `twelveStep*`, `12step*`, `sponsor*`, `programCheckin*`
- `rehab*`, `postRehab*`, `detox*`, `treatment*`, `clinical*`, `therapy*` (as a category, not as a user-typed title)
- `recoveryFromX*`, `*BecauseOf*`, where X is any substance or diagnosis
- Anything encoding the user's relationship to the developer (`wifeMode`, `spouseMode`, `partnerRecovery*`)
- Anything encoding a real person's name or role
- Diagnostic codes (ICD, DSM strings) used as identifiers

Prohibited comment patterns:

- Comments that explain a scheduling rule by naming the user's personal history. Describe the rule, not the person.
- Commit messages or PR descriptions that include "because [person] is in recovery from [substance]". Reference the spec section instead (e.g. "implements spec §4.3").

Prohibited fixture / sample-data patterns:

- Seed tasks named "AA meeting", "12-step call", "sponsor check-in", or anything substance-specific. Use neutral fixtures: "Meeting at 10", "Walk", "Groceries".

---

## 4. Notification rules

Aligned with spec §5 (notifications), §8.6 (lock-screen safety), §9 (copy), and §15 S7.

1. **Body content.** A notification body contains exactly: the user-typed title, optionally followed by ". " and the user-typed note. Nothing else.
2. **No category words.** The notification system layer (the code that builds `UNMutableNotificationContent`) must not have access to the `category` field. Pass it the user-typed strings only.
3. **No app-generated suffix.** No "Tap to start", "Time for your block", "Don't forget your meeting" trailer.
4. **Title field.** The `UNMutableNotificationContent.title` is the user-typed task title. The `subtitle` is empty by default. If a future feature needs a subtitle, it must be reviewed against this rule.
5. **`threadIdentifier`.** Do not group notifications by category. Use a neutral grouping (e.g. by date) or no grouping. A `threadIdentifier` value of `"category.recovery"` is a leak.
6. **`categoryIdentifier`.** The `UNNotificationCategory` registered for action buttons should be a neutral identifier (e.g. `GENTLE_BLOCK_REMINDER` — already used in [README.md](../README.md)). Do not register separate categories for different `TaskCategory` values.
7. **Sound and interruption level.** Time Sensitive is per-block opt-in. Critical Alerts are out of scope. Do not vary sound or interruption level based on `category`.
8. **Action buttons.** Action button titles use the spec §9 allow-list verbs: Start, Snooze 5, Snooze 15, Shrink, Move Later, Skip Without Guilt. No category-specific actions ("Log meeting", "Check in with sponsor").
9. **Rich content / attachments.** No images, no `UNNotificationAttachment` derived from category.
10. **Siri Announce / Shortcuts / Focus filters.** Any speakable text uses only user-typed content. Do not expose `category` to Intents, App Shortcuts, or Focus filter metadata.
11. **Widgets and Live Activities.** Same rules as notifications. The widget timeline entry contains user-typed title and time only.
12. **Notification scheduling time.** Do not bias notification *timing* in a way that fingerprints category (e.g. "all recovery blocks fire 10 minutes earlier" is a soft leak if combined with other signals — keep timing rules in the planner, not the notification layer).

---

## 5. Logging rules

1. **Release builds: no user content in logs.** No `print`, `NSLog`, `os_log`, `Logger`, `debugPrint` of:
   - `rawText`
   - `userTitle`
   - notes
   - block contents
   - `category`
   - recurrence patterns derived from category
   - any field of `Task`, `ScheduleBlock`, `ReviewEntry`
2. **Debug builds: user titles allowed, category forbidden.** Inside `#if DEBUG`, you may log task titles and times to the local Xcode console for development. You may **not** log `category` even in debug. If a planner trace needs to show category-driven behavior, log it as an opaque integer (`category.rawValue`) — and gate that behind a dev-only verbose flag.
3. **No log files on disk.** Do not write any log file to the app sandbox that contains user content. If a diagnostic dump is ever needed, it must be user-initiated, shown to the user before sharing, and free of `category`.
4. **No third-party log shippers.** No Logz, Datadog, Sentry-with-PII, Bugsnag, Crashlytics, etc.
5. **Apple crash reports.** If the user has iOS-level crash sharing enabled, ensure the app does not add custom symbol names, exception messages, or `userInfo` dictionaries that contain user text.
6. **Instruments traces.** `os_signpost` names must be static strings, not user-derived. `signpostID` payloads must not contain user content.
7. **Network logs.** Do not log proxy request/response bodies. Status codes and timings only, and only in debug.
8. **Redaction helper.** Provide one redaction helper (e.g. `String.redactedForLog`) that returns a fixed placeholder. Use it on the rare occasion a developer wants to log a structural fact about user content (length, presence). Never log the content itself.

---

## 6. Analytics rules

1. **There are no analytics.** No event tracking, no counters, no funnels, no session telemetry, no install attribution, no remote config, no A/B testing, no feature-flag service. (Spec §8.5.)
2. **No "anonymous usage stats" toggle.** Do not add a Settings toggle that implies future analytics. If the toggle does not yet do anything, do not ship it.
3. **No event names exist.** A grep for common analytics method names (`logEvent`, `track`, `recordEvent`, `Analytics.`, `Amplitude.`, `Mixpanel.`, `firebase.`, `Segment.`) must return zero matches in the iOS target.
4. **No analytics SDKs linked.** A grep over `Package.resolved`, `Podfile.lock`, project file framework search paths, and `xcframework` references must return zero hits for any analytics or attribution SDK.
5. **If analytics is ever added later**, it must be:
   - opt-in, off by default;
   - on-device aggregated;
   - never sends `category`, `rawText`, `userTitle`, or any user-typed content;
   - reviewed against this document and the spec before merge.

---

## 7. Database and storage rules

Aligned with spec §13 (data model) and §8 (privacy).

### Field naming

Field names in the SwiftData model are **internal**, but they end up in `.sqlite` files, in iOS device backups, and in Xcode previews. Use neutral names.

Acceptable model:

```swift
@Model
final class Task {
    var rawText: String          // verbatim user input, preserved
    var userTitle: String        // what the UI and notifications show
    var note: String?
    var category: TaskCategory?  // opaque scheduling tag, never rendered
    var createdAt: Date
    var completedAt: Date?
}

@Model
final class ScheduleBlock {
    var task: Task?
    var start: Date
    var end: Date
    var bufferBefore: TimeInterval
    var bufferAfter: TimeInterval
    var timeSensitive: Bool
    var recurrence: Recurrence?
}
```

Notes:

- `category` is the most sensitive field. It is private metadata. See the access rules below.
- No field is named `isRecovery`, `isAA`, `sobrietyMetadata`, `sponsorId`, `programType`, etc.
- `Recurrence` is generic. No `RecoveryRecurrence` subtype, no category-specific recurrence rules at the *type* level.

### Access rules

- The `category` field is read by the planner and by tests. It is **not** read by:
  - any view that renders a label, badge, or icon (a category-driven *layout decision* is allowed only if it is visually indistinguishable from the layout used for other categories);
  - the notification builder;
  - the share/export builder;
  - the AI proxy request builder (`Codable` conformance must omit it — see below);
  - any logger.
- The planner reads `category` to apply scheduling preferences from spec §4–§7, then discards it before any output crosses an "egress" boundary (display, network, export, log).

### Serialization

- `Task` and `ScheduleBlock` must **not** use synthesized `Codable` for network payloads. Use an explicit DTO (e.g. `ParseTaskRequest`) that lists only the fields the proxy needs: `rawText`, `currentDate`, `timezone`, `locale`, planning defaults, generic context. `category` is not in the DTO.
- If `Codable` is used for on-disk export (e.g. share-sheet JSON), use a separate `ExportTask` DTO that omits `category`.
- A unit test verifies that no JSON-encoded form of `Task` or `ScheduleBlock` contains the key `"category"` outside of the on-device SwiftData store. (See §9 T1.)

### iCloud and backups

- No CloudKit. No iCloud document storage.
- The SwiftData store lives in the app sandbox. iOS device backups will include it; that is acceptable because backups are user-controlled and encrypted with the user's device backup settings.
- Do not mark the store as "exclude from backup" *unless* the user opts in via a Settings toggle. (Opt-in only; do not change backup behavior silently.)

### App Groups, Keychain, UserDefaults

- No App Group exposes `category` to extensions in v1.
- No Keychain item stores anything beyond the AI proxy endpoint URL (which is not sensitive).
- `UserDefaults` (standard or any suite) does not store task text or `category`.

---

## 8. Acceptance criteria

A build is acceptance-ready for the privacy/safety axis when **all** of the following hold. These complement the spec's §14.

1. **Identifier audit.** A repo-wide grep for the prohibited identifier patterns in §3 returns zero matches in `GentleDay/**` (excluding this file, the spec file, and `README.md`, which intentionally discuss the rules).
2. **String audit.** A repo-wide grep over `GentleDay/**/*.swift`, `*.strings`, `*.stringsdict`, `*.xcstrings`, and asset catalog text returns zero matches for the spec §9 deny-list in user-visible strings.
3. **Localization key audit.** No localization key contains any §3 prohibited token.
4. **Network payload audit.** A unit test serializes `ParseTaskRequest` for representative inputs (including ones with `category == .recovery`) and asserts the resulting JSON does not contain the substring `"category"`, `"recovery"`, `"support"`, or any §3 token.
5. **Notification payload audit.** A unit test builds `UNMutableNotificationContent` for a recovery-tagged block and asserts: `title == userTitle`, `subtitle == ""`, `body` contains only the user-typed title (+ optional note), and the content object has no field whose string value contains `"recovery"`, `"AA"`, or any §3 token (except where the user-typed title itself contains those words — that is the user's choice).
6. **Export audit.** A unit test runs the share/export pipeline on a day containing recovery-tagged blocks and asserts the exported text contains no `category`, no `"recovery"`, no §3 token added by the app.
7. **Log audit.** A debug-build unit test invokes the planner, notification scheduler, AI request builder, and export builder, capturing all log output. It asserts no captured log line contains `category`, `rawText`, or `userTitle`.
8. **Analytics audit.** A repo-wide grep for `logEvent|track\(|recordEvent|Analytics\.|Amplitude\.|Mixpanel\.|firebase\.|Segment\.|Crashlytics` returns zero matches in the iOS target. A scan of `Package.resolved` / `Podfile.lock` / linked frameworks shows no analytics or attribution SDK.
9. **AI prompt audit.** The server-side prompt template (in the proxy repo) is reviewed and contains no instruction to ask about recovery, sobriety, mood, or feelings; contains no field requesting `category`; and rejects `category` if a client ever sends it.
10. **Comment / commit audit.** A reviewer reads diffs and confirms no source comment, TODO, FIXME, commit message, or PR description encodes personal history. (Manual check; CI cannot fully enforce this.)
11. **Fixture audit.** Sample data, snapshot test inputs, and onboarding seed content contain no recovery-identifying titles.
12. **Visual audit.** A reviewer takes screenshots of every screen in the app with a recovery-tagged block present and confirms no badge, icon, color, or label visually distinguishes it. (Manual check.)

---

## 9. Tests Codex should add

Each test is small, deterministic, and runs in CI. File paths are suggestions; align with the existing test target layout.

### T1 — Proxy payload omits category

`GentleDayTests/AI/ParseTaskRequestSerializationTests.swift`

```text
GIVEN a Task with rawText = "Meeting at noon", category = .recovery
WHEN ParseTaskRequest is built and JSON-encoded for the proxy
THEN the encoded JSON does not contain the substrings:
     "category", "recovery", "AA", "sobriety", "support", "program"
AND  the encoded JSON contains "rawText" with the original value.
```

### T2 — Notification content is category-free

`GentleDayTests/Notifications/BlockReminderContentTests.swift`

```text
GIVEN a ScheduleBlock whose Task has userTitle = "Walk", category = .recovery
WHEN the notification content is built
THEN content.title == "Walk"
AND  content.subtitle == ""
AND  content.body == "Walk" (or "Walk. <note>" if a user-typed note exists)
AND  content.threadIdentifier is not category-derived
AND  no field on the content object contains the substring "recovery", "AA", "sobriety", "support" added by the app.
```

### T3 — Export omits category

`GentleDayTests/Export/DaySummaryExportTests.swift`

```text
GIVEN a Day with three ScheduleBlocks, one tagged .recovery
WHEN the share-sheet day summary is generated
THEN the generated text contains each user-typed title and time
AND  contains no "category" key, no "recovery"/"AA"/"sobriety"/"support" word added by the app
AND  contains no planner-generated commentary explaining why a block was scheduled.
```

### T4 — Planner respects daytime preference without leaking category

`GentleDayTests/Planning/DaytimeSupportPreferenceTests.swift`

```text
GIVEN an inbox with a single Task, category = .recovery, no time set
AND  weekday daytime window 09:00–14:00 is open
WHEN the planner suggests a slot
THEN the suggested start time falls within 09:00–14:00
AND  the planner's public output (the suggested ScheduleBlock and any user-facing rationale) does not contain the words "recovery", "support", "AA", "category".
```

### T5 — Skip carries forward, no same-day re-suggestion

`GentleDayTests/Planning/CarryForwardTests.swift`

```text
GIVEN a recovery-tagged block scheduled at 10:00 today
WHEN the user taps "Skip without guilt" at 10:05
THEN the block is removed from today
AND  the block reappears at its next scheduled recurrence
AND  the planner does not re-suggest it later today
AND  any user-facing message reads "Carried forward." (exact spec §9 phrasing).
```

### T6 — Overwhelmed mode is generic

`GentleDayTests/UI/OverwhelmedModeTests.swift`

```text
GIVEN 6 scheduled blocks today, 2 of them category = .recovery
WHEN the user enters Overwhelmed mode
THEN exactly three options are shown
AND  none of the three option labels contain "recovery", "AA", "support", or any §3 token
AND  the next-block action references the next chronological block by user-typed title only.
```

### T7 — Kroger pickup option appears for grocery tasks

`GentleDayTests/Planning/LowEffortErrandOptionTests.swift`

```text
GIVEN a Task with userTitle containing a grocery keyword (configurable list) or category = .errand
WHEN the task is opened or Organize-with-AI is invoked
THEN two options are presented: full store and low-effort pickup
AND  the pickup option has a shorter default duration
AND  the option labels use neutral phrasing (no "easier because...", no "if you can't handle...").
```

### T8 — Deny-list grep over user-visible strings

`scripts/audit-strings.sh` invoked by CI.

```text
GIVEN the spec §9 deny-list and §3 prohibited tokens
WHEN the script greps GentleDay/**/*.swift, *.strings, *.stringsdict, *.xcstrings, and asset text
THEN it exits 0 if there are no matches in user-visible strings
AND  exits non-zero with a file:line report otherwise.
```

### T9 — Identifier audit

`scripts/audit-identifiers.sh` invoked by CI.

```text
GIVEN the §3 prohibited identifier patterns
WHEN the script greps GentleDay/**/*.swift and project file paths
THEN it exits 0 if no identifier (type, property, function, file, key) matches
AND  exits non-zero with a file:line report otherwise.
This script intentionally excludes docs/ and README.md.
```

### T10 — No analytics SDK linked

`scripts/audit-dependencies.sh` invoked by CI.

```text
GIVEN Package.resolved (and Podfile.lock if present)
WHEN the script scans for analytics/attribution/crash-with-PII SDK names
THEN it exits 0 if no such SDK is present
AND  exits non-zero with the offending dependency name otherwise.
```

### T11 — Logger redaction

`GentleDayTests/Logging/RedactionTests.swift`

```text
GIVEN a Task with rawText = "Meeting at noon", userTitle = "Meeting", category = .recovery
WHEN the planner, notification builder, AI request builder, and export builder run
AND  os_log / Logger / print output is captured (in DEBUG, with a test sink)
THEN no captured log line contains the rawText value
AND  no captured log line contains the userTitle value (in release config)
AND  no captured log line contains "category", ".recovery", or the raw enum value text.
```

### T12 — Onboarding sample data is neutral

`GentleDayTests/Onboarding/SeedContentTests.swift`

```text
GIVEN the onboarding seed task list (if any)
WHEN inspected
THEN no seed title contains "AA", "meeting" (in a recovery sense), "sobriety", "Al-Anon", or any §3 token
AND  seed titles are generic (e.g. "Walk", "Groceries", "Quick note").
```

---

## Notes for implementers

- When in doubt about naming: ask "would a recruiter, a babysitter, or a stranger glancing at this screen, log line, or source file learn something private?" If yes, rename.
- When in doubt about an export or share feature: the safe default is "don't ship it." Add it only after running it through this checklist.
- This document and the spec are the source of truth for privacy and tone. If a future request conflicts with them, surface the conflict rather than silently complying.
- Cross-references: spec §4 (recovery-sensitive planning), §5 (AA/recovery activity rules), §8 (privacy rules), §9 (language rules), §13 (data model), §14 (acceptance criteria), §15 (test scenarios).
