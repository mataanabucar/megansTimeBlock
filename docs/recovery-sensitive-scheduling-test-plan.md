# Gentle Day — Recovery-Sensitive Scheduling Test Plan

Audience: coding agents (Codex, Claude Code), QA reviewers, and human reviewers verifying that Gentle Day implements the rules in:

- [`recovery-sensitive-scheduling-spec.md`](./recovery-sensitive-scheduling-spec.md) — behavior
- [`privacy-and-sensitive-context-rules.md`](./privacy-and-sensitive-context-rules.md) — privacy and naming
- [`recovery-sensitive-copy-guide.md`](./recovery-sensitive-copy-guide.md) — voice and copy

This document is the **QA contract**. Every scenario here is either an automated test Codex should add, or a manual gate a human must run before release. Anything not listed here is out of scope for this pass.

Scope: this is a test plan for a private, on-device iOS planning app. It is not clinical QA and it does not validate health or safety claims. It validates that the app behaves as specified and that sensitive context does not leak through any surface.

---

## Conventions

- **ID format.** Each scenario has an ID: `UT-*` unit, `IT-*` integration, `UX-*` UI/copy, `PR-*` privacy, `EC-*` edge case, `RG-*` regression.
- **Severity.** `P0` blocks release. `P1` blocks merge to main. `P2` is a follow-up.
- **Spec refs.** Each scenario points at the rule it enforces (e.g. spec §4.1, privacy rules §3, copy guide §9).
- **Automation.** `AUTO` runs in CI. `MANUAL` requires a human reviewer. Hybrid scenarios state both legs explicitly.
- **Time/date assumptions.** Unless a scenario overrides them, use the spec §3 defaults: daytime window 09:00–15:30, evening cutoff 19:30, wake 07:00, sleep 22:30, daycare drop-off/pickup unset, planning style `light`, max blocks/day 5, reserve daily quiet block ON.
- **Fixtures.** Sample data must follow privacy rules §3 — neutral titles, no recovery-identifying words. Tests construct synthetic `Task` and `ScheduleBlock` objects directly; they do not paste real personal text.

---

## 1. Unit test scenarios

Scope: one function, one decision, no I/O. Live under `GentleDayTests/`.

### UT-01 — `recovery` category prefers daytime window
**Severity:** P0. **Automation:** AUTO. **Spec:** §4.3, §5.

GIVEN a `Task { category: .recovery, userTitle: "Meeting at 10", scheduledTime: nil }` and an empty day with daytime window 09:00–15:30 open.
WHEN the planner picks a slot via `SupportSchedulingRules.preferredSlot(for:in:)`.
THEN the returned start time is within `[09:00, 14:00]` local time, and the returned block has the default 60-minute duration and 15-minute buffers from spec §5.

### UT-02 — `recovery` category is never auto-placed after the evening cutoff
**Severity:** P0. **Automation:** AUTO. **Spec:** §4.4, §7.

GIVEN a `Task { category: .recovery }` and a day where the only contiguous free window is 20:00–22:00.
WHEN the planner runs auto-scheduling.
THEN the task is **not** placed; it carries forward to the next eligible daytime window.

### UT-03 — `recovery` category default duration and buffers
**Severity:** P1. **Automation:** AUTO. **Spec:** §5.

GIVEN a new `Task { category: .recovery }` with no user-provided duration.
WHEN a `ScheduleBlock` is constructed from it.
THEN `duration == 60.minutes`, `bufferBefore == 15.minutes`, `bufferAfter == 15.minutes`, unless `PlanningPreferences` overrides any of them.

### UT-04 — `errand` category prefers weekday daytime
**Severity:** P0. **Automation:** AUTO. **Spec:** §6.1.

GIVEN a `Task { category: .errand, userTitle: "Groceries" }` on a Wednesday with daytime window open.
WHEN the planner suggests a slot.
THEN the suggested start is within `[09:00, 15:30]` and the planner prefers the afternoon window `[13:30, 15:30]` when both halves are equally free.

### UT-05 — Kroger pickup is shorter than a full store trip
**Severity:** P0. **Automation:** AUTO. **Spec:** §6.2.

GIVEN a grocery task and `lowEffortErrandEnabled == true`.
WHEN the planner produces options.
THEN exactly two options are returned: `fullStore` (default ≥60 min) and `lowEffortPickup` (default ≤30 min), and `lowEffortPickup.duration < fullStore.duration`.

### UT-06 — Kroger pickup carries an order-by reminder
**Severity:** P1. **Automation:** AUTO. **Spec:** §6.2.

GIVEN the `lowEffortPickup` option is selected for a 13:30 pickup slot.
WHEN the planner finalizes the block.
THEN a companion reminder is created at the user-configured lead time (default 2h earlier or previous-day evening, per `PlanningPreferences`), and its `userTitle` is derived from the user's grocery task title — not "Order Kroger pickup".

### UT-07 — Errands do not stack
**Severity:** P0. **Automation:** AUTO. **Spec:** §6.3.

GIVEN three errand-tagged tasks in the inbox and an empty day.
WHEN the planner runs auto-scheduling.
THEN at most one errand block is scheduled today; the remaining two carry forward.

### UT-08 — Errands avoid late-afternoon pickup collision
**Severity:** P0. **Automation:** AUTO. **Spec:** §6.4.

GIVEN `daycareAvailableWindowEnd == 15:30` (i.e. pickup at 15:30) and an errand needing 60 minutes.
WHEN the planner suggests a slot.
THEN the suggested end time is `≤ 15:30 − 30 min` buffer, i.e. the errand ends by 15:00.

### UT-09 — Daytime cap: at most 1 recovery + 1 errand + 1 admin
**Severity:** P0. **Automation:** AUTO. **Spec:** §4.1.

GIVEN an inbox with 2 recovery, 3 errand, 4 admin tasks and ≥3 hours of open daytime.
WHEN the planner runs auto-scheduling.
THEN the auto-scheduled set today contains ≤1 recovery, ≤1 errand, ≤1 admin block; the rest carry forward.

### UT-10 — Quiet block reserved
**Severity:** P0. **Automation:** AUTO. **Spec:** §4.2.

GIVEN `reserveDailyQuietBlock == true` and a daytime window with no pre-existing blocks.
WHEN the planner runs auto-scheduling against a large inbox.
THEN at least one contiguous unscheduled window of `≥30 min` remains inside `[09:00, 15:30]`, and the planner does not offer to fill it unless the user explicitly requests it.

### UT-11 — Evenings stay empty by default
**Severity:** P0. **Automation:** AUTO. **Spec:** §7.1–§7.2.

GIVEN an inbox with 5 mixed tasks and `eveningCutoff == 19:30`.
WHEN the planner runs auto-scheduling.
THEN zero blocks are auto-placed at or after `eveningCutoff`. Carry-forward targets tomorrow's daytime, not tonight.

### UT-12 — Evening drop offers tomorrow morning
**Severity:** P1. **Automation:** AUTO. **Spec:** §7.3.

GIVEN the user drags a `ScheduleBlock` of duration 90 min onto 20:00.
WHEN the drop is committed via `PlannerInteractor.dropBlock(at:)`.
THEN the interactor returns a prompt action `.offerMoveToTomorrowMorning(block, suggestedStart:)` rather than silently accepting; the prompt accepts both "Move" and "Keep here".

### UT-13 — Al-Anon is not a default
**Severity:** P0. **Automation:** AUTO. **Spec:** §4.5.

GIVEN the onboarding seed list and any recurring-template list shipped with the app.
WHEN inspected.
THEN no template, seed entry, or suggestion contains the strings `Al-Anon`, `Al Anon`, `Alanon`, `partner recovery`, `family of alcoholic`, case-insensitive, in any field.

### UT-14 — Skip carries forward to next recurrence, not later today
**Severity:** P0. **Automation:** AUTO. **Spec:** §4.10, §5, §15 S3.

GIVEN a recovery-tagged recurring block scheduled at 10:00 today (next recurrence: tomorrow at 10:00).
WHEN the user invokes `BlockAction.skipForToday` at 10:05.
THEN the block is removed from today's schedule; the planner does not re-suggest it later today; the next occurrence at tomorrow 10:00 remains intact.

### UT-15 — Overwhelmed mode returns exactly three options
**Severity:** P0. **Automation:** AUTO. **Spec:** §4.9, copy guide §1.

GIVEN any state with ≥1 scheduled block today.
WHEN `OverwhelmedViewModel.enter()` is called.
THEN the public output is exactly three `Option` values: `.startNext(nextBlock)`, `.shrinkToTenMinutes(nextBlock)`, `.skipTodayCarryForward(nextBlock)`. No option references `category`, and the next-block label is the user-typed title.

### UT-16 — Planner output has no rationale field that names category
**Severity:** P0. **Automation:** AUTO. **Spec:** §4.6, privacy §1.H.

GIVEN any planner run.
WHEN the resulting `PlannerOutput` is inspected.
THEN no field — including any optional rationale, explanation, or debug-label — contains the substrings `recovery`, `support`, `AA`, `sobriety`, `category` added by the planner. (User-typed titles are exempt.)

### UT-17 — Notification content is built from user-typed title only
**Severity:** P0. **Automation:** AUTO. **Privacy §4**, copy §9.

GIVEN a `ScheduleBlock` whose task has `userTitle = "Walk"`, `note = nil`, `category = .recovery`.
WHEN `BlockReminderContentBuilder.content(for:)` is called.
THEN `content.title == "Walk"`, `content.subtitle == ""`, `content.body == "Walk"`, `content.threadIdentifier` is not category-derived, and no field on `content` contains the substring `recovery`, `AA`, `support`, `sobriety`.

### UT-18 — Notification content includes user-typed note verbatim
**Severity:** P1. **Automation:** AUTO. **Copy §9**.

GIVEN `userTitle = "Walk"`, `note = "Put on shoes first."`, `category = .recovery`.
WHEN the notification content is built.
THEN `content.body == "Walk. Put on shoes first."` exactly; no app-added trailer, no emoji, no exclamation.

### UT-19 — `ParseTaskRequest` omits category
**Severity:** P0. **Automation:** AUTO. **Spec §8.3, privacy §1.D, privacy §7**.

GIVEN a `Task` with `rawText = "Meeting at noon"`, `category = .recovery`, and `AIMode == .openAIViaProxy`.
WHEN `ParseTaskRequestEncoder.encode(_:)` produces the JSON body sent to the proxy.
THEN the JSON does not contain the keys `category`, `tag`, `isRecovery`, `recovery`, `support`, and does not contain the values `recovery`, `AA`, `sobriety`, `support`, `program` (case-insensitive) added by the encoder. It does contain `rawText` with the original value.

### UT-20 — Proxy response: `category` hint is discarded
**Severity:** P0. **Automation:** AUTO. **Privacy §1.D**.

GIVEN a synthetic proxy response that includes a `"category": "recovery"` field.
WHEN `ParseTaskResponseDecoder.decode(_:)` runs.
THEN the decoded `Task` has `category == nil` (or whatever the user already set); the response field is ignored.

### UT-21 — `category` is not serialized in any export DTO
**Severity:** P0. **Automation:** AUTO. **Privacy §1.G, §7**.

GIVEN a day with three blocks, one with `category == .recovery`.
WHEN `DaySummaryExporter.text(for:)` and `DaySummaryExporter.json(for:)` produce share-sheet output.
THEN neither output contains the key `category`, the value `recovery`, or any privacy rules §3 token added by the exporter. The user-typed titles and times do appear.

### UT-22 — No `print` / `Logger` of user content in release
**Severity:** P0. **Automation:** AUTO. **Privacy §5**.

GIVEN the release build configuration (`#if !DEBUG`).
WHEN a static analysis pass scans for `print(`, `NSLog(`, `os_log(`, `Logger().*(`, `debugPrint(` calls whose argument expression references `Task`, `ScheduleBlock`, `rawText`, `userTitle`, `note`, `category`.
THEN zero such calls exist in release-compiled code.

### UT-23 — Redaction helper actually redacts
**Severity:** P1. **Automation:** AUTO. **Privacy §5.8**.

GIVEN `"Meeting at noon".redactedForLog`.
THEN the result is a fixed placeholder (e.g. `"<redacted len=15>"`) and does not contain `"Meeting"`, `"noon"`, or any substring of the input.

### UT-24 — Recurrence is generic, not category-typed
**Severity:** P1. **Automation:** AUTO. **Privacy §7**.

GIVEN the public API of `Recurrence`.
WHEN inspected.
THEN there is no case named `recoveryDaily`, `aaWeekly`, `programRecurrence`, etc. Only generic cases: `.daily`, `.weekdays`, `.weekly(weekdays:)`, etc.

### UT-25 — Preferences round-trip with safe defaults
**Severity:** P1. **Automation:** AUTO. **Spec §13**.

GIVEN a fresh `PlanningPreferences()`.
THEN the defaults exactly match spec §13: wake 07:00, evening cutoff 19:30, sleep 22:30, daytime window 09:00–15:30, default block 30 min, default buffer 15 min, planning style `.light`, max blocks 5, reserve quiet block `true`, AI mode `.mockAI`, low-effort errand enabled `true`.

### UT-26 — All scheduling assumptions are read from preferences
**Severity:** P0. **Automation:** AUTO. **Spec §13, requirement #10**.

GIVEN a planner run.
WHEN static analysis inspects the planner source.
THEN no scheduling constant referenced by the planner is a hardcoded literal (no `9` for daytime start, no `19` for cutoff, no `30` for default block, no `5` for max blocks). All such values are read through `PlanningPreferences`. (Implementation: an `audit-no-magic-numbers.sh` script lists the allowed literal whitelist and fails on any other numeric literal in `Scheduling/` and `Planning/`.)

---

## 2. Integration test scenarios

Scope: real planner end-to-end with SwiftData in-memory store. Live under `GentleDayTests/Integration/`.

### IT-01 — Build My Day on a wide-open weekday
**Severity:** P0. **Automation:** AUTO. **Spec §15 S1**.

GIVEN a Wednesday with no existing blocks, daytime window 09:00–15:30, and an inbox of 8 tasks across all categories (2 recovery, 3 errand, 1 admin, 1 self-care, 1 family).
WHEN `Planner.buildMyDay()` runs.
THEN the resulting day has: ≤1 recovery in `[09:00, 14:00]`, ≤1 errand in `[09:00, 15:00]` (with pickup-collision guard), ≤1 admin, ≥1 quiet block of `≥30 min`, evening empty after `eveningCutoff`, and remaining tasks carried forward to tomorrow.

### IT-02 — AA suggested for daytime
**Severity:** P0. **Automation:** AUTO. **Spec §4.3, §5**.

GIVEN an inbox containing one task `{ category: .recovery, userTitle: "Meeting at 10", scheduledTime: nil }` and an otherwise empty weekday.
WHEN `Planner.suggestSlot(for: task)` runs.
THEN the suggested `start` is on this weekday inside `[09:00, 14:00]`, and `end == start + 60.minutes`.

### IT-03 — Al-Anon never appears
**Severity:** P0. **Automation:** AUTO. **Spec §4.5**.

GIVEN onboarding seed data, template lists, autocomplete suggestion lists, and the planner's recurring-template generator.
WHEN each is enumerated.
THEN no entry contains `Al-Anon`/`Al Anon`/`Alanon` (case-insensitive) in any field.

### IT-04 — Groceries default to weekday daytime
**Severity:** P0. **Automation:** AUTO. **Spec §6.1**.

GIVEN an inbox with one task `{ category: .errand, userTitle: "Groceries" }` and three candidate days (Mon 09:00–15:30 open, Sat 09:00–15:30 open, Tonight evening open).
WHEN `Planner.suggestDay(for: task)` runs.
THEN the suggested day is Monday, not Saturday and not tonight.

### IT-05 — Kroger pickup option appears for grocery tasks
**Severity:** P0. **Automation:** AUTO. **Spec §6.2, §15 S5**.

GIVEN a task whose `userTitle` matches the configured grocery keyword list, **or** whose `category == .errand` with grocery context.
WHEN the task is opened or `OrganizeWithAI` returns.
THEN the UI surface (`GroceryOptionsViewModel.options`) returns exactly two options whose labels match copy guide §6 ("Pickup, 25 min, place order by …", "Full store, 60 min"), and `pickup.duration < fullStore.duration`.

### IT-06 — Open daytime is not overfilled
**Severity:** P0. **Automation:** AUTO. **Spec §4.1**.

GIVEN ≥6 hours of open daytime and an inbox of 12 mixed tasks (including 3 recovery, 4 errand, 3 admin).
WHEN `Planner.buildMyDay()` runs.
THEN the day contains at most 5 auto-scheduled blocks total (the `maxBlocksPerDay` default), at most 1 per category for `.recovery`/`.errand`/`.admin`, and a quiet block of `≥30 min` remains.

### IT-07 — Evenings stay light and family-oriented
**Severity:** P0. **Automation:** AUTO. **Spec §7.1–§7.5**.

GIVEN a Wednesday with `daycareAvailableWindowEnd == 15:30` and the inbox from IT-06.
WHEN `Planner.buildMyDay()` runs.
THEN zero blocks are auto-placed in `[15:30, 23:59]`. Carry-forward targets tomorrow daytime. Family-tagged blocks already present in the evening are preserved untouched.

### IT-08 — Recovery stability is prioritized over throughput
**Severity:** P0. **Automation:** AUTO. **Spec §2.6, §4**.

GIVEN a tie between (a) scheduling a recovery block + 1 errand + 1 admin and (b) scheduling 3 admin blocks (higher total count).
WHEN `Planner.buildMyDay()` runs.
THEN the planner picks (a). Recovery is always selected before admin when both are eligible for the same slot.

### IT-09 — Skipped recovery block re-appears at next recurrence only
**Severity:** P0. **Automation:** AUTO. **Spec §4.10, §15 S3, UT-14**.

GIVEN a recurring `{ category: .recovery, recurrence: .daily, time: 10:00 }`.
WHEN the user invokes `skipForToday` at 10:05 today.
THEN today's instance disappears, the next instance (tomorrow 10:00) is unchanged, and the planner does not insert a make-up block today.

### IT-10 — Wind-down is respected end-to-end
**Severity:** P1. **Automation:** AUTO. **Spec §7.6**.

GIVEN local time `19:45` on a day with carry-forward items pending.
WHEN the user opens the app.
THEN no toast, banner, or push notification fires; "What should I do next?" returns "Quiet for tonight." (copy guide §2); manual entry remains possible.

### IT-11 — Configurable assumptions actually flow through
**Severity:** P0. **Automation:** AUTO. **Requirement #10, spec §13**.

GIVEN `PlanningPreferences` set to wake 06:00, daytime 10:00–14:00, evening cutoff 18:00, maxBlocksPerDay 3, reserveDailyQuietBlock false, lowEffortErrandEnabled false.
WHEN the same inbox as IT-01 is planned.
THEN: no quiet block is reserved; daytime suggestions fall inside `[10:00, 14:00]`; no block is placed after 18:00; at most 3 auto-scheduled blocks; the grocery option set contains only `fullStore` (no pickup).

### IT-12 — Daycare windows drive daytime availability
**Severity:** P0. **Automation:** AUTO. **Requirement #10**.

GIVEN `daycareAvailableWindowStart == 08:30`, `daycareAvailableWindowEnd == 14:30`.
WHEN any planner run produces suggestions for `.recovery`, `.errand`, `.admin`.
THEN suggested blocks fall inside `[08:30, 14:30 − bufferBefore]` and never overlap the windows on either side.

---

## 3. UI / copy review scenarios

Scope: SwiftUI views and copy strings. Mix of snapshot tests and manual review. Live under `GentleDayTests/UI/` and `GentleDayUITests/`.

### UX-01 — Empty states match the allow-list
**Severity:** P0. **Automation:** AUTO (snapshot) + MANUAL (voice check). **Copy §8, §11.6**.

For each empty state — inbox, today, review, search, onboarding — render the view in a snapshot test and assert the string is a verbatim match for an entry in copy guide §8 "Good" lists. A human reviewer reads each one and confirms voice per copy guide §1.

### UX-02 — Action button labels are the six approved strings
**Severity:** P0. **Automation:** AUTO. **Copy §9, §11.5**.

GIVEN the registered `UNNotificationCategory` and any in-app action buttons.
WHEN inspected.
THEN labels are exactly: "Start", "Snooze 5 min", "Snooze 15 min", "Shrink", "Move later", "Skip without guilt". No additions, no variants.

### UX-03 — No app-added emoji or exclamation in routine surfaces
**Severity:** P0. **Automation:** AUTO. **Copy §11.2–§11.3**.

GIVEN every user-visible string source (`.swift` literals returned from view bodies, `.strings`, `.xcstrings`).
WHEN scanned, **excluding** strings that originate from user-typed task content.
THEN zero emoji code points appear; `!` appears only in validation-error strings on a small whitelist.

### UX-04 — Recovery-tagged blocks render identically to other blocks
**Severity:** P0. **Automation:** AUTO (snapshot) + MANUAL (visual). **Privacy §1.B, spec §5**.

GIVEN a day list containing two blocks with identical times and titles, one `category == .recovery` and one `category == .other`.
WHEN rendered.
THEN the two rows are pixel-identical except for content driven by user-typed fields. No icon, badge, color, accessibility label, or VoiceOver hint distinguishes them.

### UX-05 — Overwhelmed mode shows three small options, no category names
**Severity:** P0. **Automation:** AUTO (snapshot). **Spec §4.9, §15 S8**.

GIVEN a day with 6 blocks including 2 `.recovery`.
WHEN Overwhelmed mode is entered.
THEN exactly three `Option` rows render; their labels match copy guide §2 ("Start the next block.", "Shrink to 10 minutes.", "Skip today, carry forward."); the next-block reference is the user-typed title only.

### UX-06 — Kroger pickup is presented neutrally
**Severity:** P1. **Automation:** AUTO (snapshot). **Spec §6.2, copy §6**.

GIVEN a grocery task open in the editor.
WHEN the options sheet renders.
THEN the two option labels are the copy guide §6 wording. No "easier because…", no "if you can't handle…", no soft-pressure phrasing.

### UX-07 — Onboarding contains no category words and no hype
**Severity:** P0. **Automation:** AUTO (snapshot) + MANUAL. **Copy §11.8, privacy §3**.

For each onboarding screen, snapshot the rendered text and assert it contains zero privacy rules §3 tokens and zero hype words from copy guide §3. A human reviewer reads the full flow and confirms voice.

### UX-08 — Voice review of every user-visible string
**Severity:** P0. **Automation:** MANUAL. **Copy §11.10**.

A human reviewer reads every user-visible string in one sitting and confirms it sounds like copy guide §1 (calm, short, practical, not therapist/coach/sponsor/parent/spouse). This is a release gate. CI cannot judge tone.

### UX-09 — Lock-screen photo review
**Severity:** P0. **Automation:** MANUAL. **Copy §11.11, privacy §4**.

A reviewer triggers every notification path on a physical device with the screen locked, photographs each, and confirms no notification reveals category context. The photo set is attached to the release ticket.

### UX-10 — Siri Announce read-aloud review
**Severity:** P0. **Automation:** MANUAL. **Copy §11.12**.

A reviewer enables Announce Notifications in iOS Settings, triggers each notification path, and confirms the spoken text is safe to hear in a shared room. Recordings (or written transcripts) attach to the release ticket.

### UX-11 — Accessibility labels do not leak category
**Severity:** P0. **Automation:** AUTO (snapshot) + MANUAL (VoiceOver). **Privacy §1.B**.

For each row, button, and action that exposes an `accessibilityLabel`, assert the label contains no privacy rules §3 token. Manual VoiceOver pass on a device confirms no leak.

### UX-12 — Widgets / Live Activities / Spotlight / App Shortcuts
**Severity:** P0. **Automation:** AUTO + MANUAL. **Privacy §1.B, §4.11**.

If any of these surfaces exist, snapshot their timeline content and inspect their `Intent` definitions; assert no category-derived text appears. Manual pass confirms on a device.

---

## 4. Privacy test scenarios

Scope: machine-checkable privacy assertions and a small manual audit list. Live under `GentleDayTests/Privacy/` plus `scripts/`.

### PR-01 — Identifier audit (CI script)
**Severity:** P0. **Automation:** AUTO. **Privacy §3, §8.1**.

`scripts/audit-identifiers.sh` greps `GentleDay/**/*.swift` (and project file paths) for the privacy rules §3 prohibited identifier patterns. Excludes `docs/` and `README.md`. Exits non-zero on any match with a `file:line` report.

### PR-02 — String audit (CI script)
**Severity:** P0. **Automation:** AUTO. **Spec §9, privacy §8.2, copy §11.1**.

`scripts/audit-strings.sh` greps `.swift`, `.strings`, `.stringsdict`, `.xcstrings`, and asset text for the spec §9 / copy §3 deny-list in user-visible strings (string literals returned to views, localization values, asset captions). Excludes user data sources and test fixtures explicitly marked `@neutralFixture`. Exits non-zero on any match.

### PR-03 — Localization key audit (CI script)
**Severity:** P0. **Automation:** AUTO. **Privacy §2 (localized keys)**.

`scripts/audit-localization-keys.sh` greps every localization key (the left-hand side of `=` in `.strings`, the `name` in `.xcstrings`) for privacy rules §3 tokens. Exits non-zero on any match.

### PR-04 — Network payload audit
**Severity:** P0. **Automation:** AUTO. **Privacy §1.D, §7, UT-19**.

A unit test serializes `ParseTaskRequest` for fixtures including `category == .recovery`, asserts the resulting JSON contains neither `"category"` as a key nor privacy rules §3 tokens as values added by the encoder.

### PR-05 — Notification payload audit
**Severity:** P0. **Automation:** AUTO. **Privacy §4, UT-17**.

For each `ScheduleBlock` fixture (including recovery-tagged), build the `UNMutableNotificationContent`, dump every string field (`title`, `subtitle`, `body`, `threadIdentifier`, `categoryIdentifier`, `targetContentIdentifier`, `userInfo` values), assert no field added by the app contains §3 tokens.

### PR-06 — Export audit
**Severity:** P0. **Automation:** AUTO. **Privacy §1.G, UT-21**.

For each share-sheet export pipeline (`text/plain`, `application/json` if present), generate output from a day with recovery-tagged blocks, assert no §3 token appears in the output (other than inside user-typed titles), and assert no `category` key appears.

### PR-07 — Log audit
**Severity:** P0. **Automation:** AUTO. **Privacy §5, UT-22**.

A test sink captures all logging output (`print`, `Logger`, `os_log`) during planner, notification, AI request, and export operations. In release-configured builds, asserts no captured line contains `Task.rawText`, `userTitle`, `note`, or any §3 token. In debug builds, asserts no captured line contains `category` or the raw enum value text.

### PR-08 — Analytics audit (CI script)
**Severity:** P0. **Automation:** AUTO. **Privacy §6, §8.8**.

`scripts/audit-no-analytics.sh` greps for `logEvent|track\(|recordEvent|Analytics\.|Amplitude\.|Mixpanel\.|firebase\.|Segment\.|Crashlytics|Sentry` in the iOS target source. Inspects `Package.resolved` and `Podfile.lock` for any analytics or attribution SDK. Exits non-zero on any hit.

### PR-09 — Dependency audit (CI script)
**Severity:** P0. **Automation:** AUTO. **Privacy §8.8**.

`scripts/audit-dependencies.sh` enforces an allow-list of SwiftPM dependencies. Any new dependency not on the allow-list fails the build until reviewed. The allow-list is checked into the repo.

### PR-10 — AI prompt audit (server-side)
**Severity:** P0. **Automation:** MANUAL + AUTO regex. **Privacy §1.H, §8.9**.

The server-side prompt template in the proxy repo is reviewed and contains: no instruction to ask about recovery/sobriety/mood/feelings, no field requesting `category`, and explicit logic that rejects a `category` field if a client ever sends it. A CI lint in the proxy repo greps the prompt file for forbidden phrases and fails on match.

### PR-11 — Backup / iCloud audit
**Severity:** P1. **Automation:** AUTO. **Privacy §7 (iCloud and backups)**.

Inspect entitlements and the SwiftData container configuration. Assert: no CloudKit container, no `NSUbiquitousContainerIsDocumentScopePublic`, no automatic iCloud Documents sync. The local store is not marked "exclude from backup" unless the user opts in via Settings.

### PR-12 — Keychain / UserDefaults / App Group audit
**Severity:** P1. **Automation:** AUTO. **Privacy §7**.

Inspect every Keychain query, UserDefaults suite, and App Group identifier. Assert: no Keychain item stores task content; no UserDefaults key stores task content or `category`; no App Group exposes category data to extensions in v1.

### PR-13 — Comment / commit hygiene
**Severity:** P1. **Automation:** MANUAL. **Privacy §1.J, §8.10**.

A reviewer reads diffs and confirms no source comment, TODO, FIXME, commit message, or PR description encodes personal history. This is a manual gate at PR review time.

### PR-14 — Fixture audit
**Severity:** P0. **Automation:** AUTO. **Privacy §1.J, §8.11**.

Sample data, snapshot inputs, and onboarding seed content are grepped for privacy rules §3 tokens. Exits non-zero on any match.

### PR-15 — Visual leak audit
**Severity:** P0. **Automation:** MANUAL. **Privacy §8.12**.

A reviewer screenshots every screen with a recovery-tagged block present and confirms no badge, icon, color, or label visually distinguishes it. Screenshots attach to the release ticket.

---

## 5. Edge cases

Scope: states that are easy to miss and likely to regress.

### EC-01 — User pastes a recovery-identifying word in their own task title
**Spec:** copy guide §3 (user-typed content is exempt). **Severity:** P1. **Automation:** AUTO.

If the user types `"AA meeting"` as `userTitle`, that string appears in the UI and the notification body verbatim. The app must **not** strip, mask, or rewrite it. Test asserts the title round-trips unchanged through display, notification, share, and storage.

> Trade-off note: this means user-typed titles can surface category context on the lock screen. That is the user's choice. If the project decides later to offer an opt-in "private titles" filter, design it as a separate feature; do not bolt it onto the default path.

### EC-02 — User schedules a recovery block at night manually
**Spec:** §4.4 (auto-suggest only); manual placement is allowed.

GIVEN the user drags a recovery-tagged block to 21:00.
WHEN the drop is committed.
THEN the planner offers "Move to tomorrow morning instead?" once per drop (UT-12), accepts the user's confirmation if they decline the move, and does not propagate the manual choice into auto-scheduling defaults.

### EC-03 — Daytime window is closed (e.g. weekend without daycare)
**Spec:** §3 (weekends are family-default).

GIVEN a Saturday with `daycareAvailableWindowStart == nil`.
WHEN the planner runs.
THEN auto-scheduling is fully off by default; only user-placed blocks appear. The planner does not infer a synthetic daytime window from weekday defaults.

### EC-04 — Inbox contains only recovery tasks
**Spec:** §4.1.

GIVEN 4 recovery-tagged tasks and zero others.
WHEN `Planner.buildMyDay()` runs.
THEN at most 1 is auto-scheduled today; the rest carry forward. The planner does not relax the 1-per-day recovery cap just because the inbox has nothing else.

### EC-05 — DST transition day
**Severity:** P1. **Automation:** AUTO.

GIVEN a planner run on a DST transition date.
WHEN the daytime window spans the transition (or the user's preferences cross it).
THEN slot math uses calendar arithmetic, not raw `+3600` seconds; suggested start/end times remain inside the configured local window before and after the transition.

### EC-06 — Timezone change while the app is open
**Severity:** P2. **Automation:** AUTO.

GIVEN the device travels across a timezone boundary mid-day.
WHEN the planner refreshes.
THEN previously scheduled blocks retain their absolute instants; the "today" computation uses the device's current timezone for window calculations; no block silently disappears.

### EC-07 — Conflicting recurrences
**Severity:** P1. **Automation:** AUTO.

GIVEN two recurring recovery-tagged tasks that both want 10:00–11:00.
WHEN planner runs.
THEN only one is auto-placed today; the other carries forward to its next eligible slot. No silent overlap.

### EC-08 — Pickup task without daycare window set
**Severity:** P1. **Automation:** AUTO.

GIVEN `daycareAvailableWindowEnd == nil` and an errand task.
WHEN the planner runs.
THEN the planner falls back to spec §3 daytime defaults (`09:00–15:30`) and does not block on the missing preference.

### EC-09 — Inbox containing only one task and it's an errand
**Severity:** P2. **Automation:** AUTO.

GIVEN one errand task and an empty day.
WHEN planner runs.
THEN the errand is auto-scheduled, the quiet block is preserved, and the planner does not invent additional tasks ("you might want to add a walk") — the planner never fabricates content.

### EC-10 — User toggles `recoveryFocusEnabled` to `false`
**Severity:** P1. **Automation:** AUTO. **Requirement #10**.

GIVEN `recoveryFocusEnabled == false`.
WHEN planning runs against any inbox.
THEN the §4 recovery-sensitive rules no longer apply: recovery-tagged tasks are treated like `.other` for scheduling; quiet-block reservation still respects `reserveDailyQuietBlock`; evening protection still respects `eveningCutoff`. (The toggle relaxes recovery-specific bias; it does not turn off general "don't overload" or "evenings light" rules, which are independent preferences.)

> Implementation note: this is a real fork in the rules. Be explicit in the planner about which rules are gated on `recoveryFocusEnabled` and which are gated on the other independent preferences. The test asserts the fork.

### EC-11 — Offline AI request while AI mode is "OpenAI via Proxy"
**Severity:** P1. **Automation:** AUTO. **Copy §10**.

GIVEN no network and AI mode `.openAIViaProxy`.
WHEN the user invokes "Organize with AI".
THEN the error path returns "Couldn't reach the assistant. Your text is saved in Quick Capture." verbatim; the raw text is preserved.

### EC-12 — Proxy returns malformed JSON
**Severity:** P1. **Automation:** AUTO.

GIVEN a proxy response that is invalid JSON or missing required fields.
WHEN decoded.
THEN the error path returns "Couldn't parse that. Your text is saved." verbatim; no partial state is persisted.

### EC-13 — Notification fires while app is in foreground
**Severity:** P2. **Automation:** AUTO.

GIVEN a scheduled block reminder and the app is foregrounded.
WHEN the notification fires.
THEN the in-app presentation matches the lock-screen rules (no category words, no app-added emoji); the foreground handler does not inject any additional copy.

### EC-14 — Block whose user-typed title is empty
**Severity:** P1. **Automation:** AUTO.

GIVEN a `Task` with `userTitle == ""` (edge case, possibly invalid).
WHEN a notification is built.
THEN the body falls back to `"Block"` (a neutral, non-category word) — not to `category`, not to `rawText`. The save path validates that `userTitle` is non-empty on the user-facing form; this fallback exists only for legacy/imported data.

### EC-15 — Search returns a recovery-tagged result
**Severity:** P1. **Automation:** AUTO.

GIVEN a search query that matches a recovery-tagged block by user-typed title.
WHEN results render.
THEN the result row is identical to non-recovery rows (per UX-04); no "from your recovery routine" subtitle or grouping.

---

## 6. Regression tests

Scope: high-leverage scenarios that protect the rules most likely to regress as new features land. Live under `GentleDayTests/Regression/`.

### RG-01 — Daytime cap holds after a planner refactor
**Source:** IT-06. **Severity:** P0. **Automation:** AUTO.

Pinned fixture (12 mixed tasks, empty day). Assert the planner produces ≤5 auto-scheduled blocks with ≤1 per `.recovery`/`.errand`/`.admin` and ≥1 quiet block of `≥30 min`. Snapshot of `PlannerOutput` is checked in. Any change requires explicit reviewer approval to update.

### RG-02 — Evenings stay empty after a planner refactor
**Source:** IT-07. **Severity:** P0. **Automation:** AUTO.

Pinned fixture (same as RG-01). Assert zero auto-placed blocks at or after `eveningCutoff`. Snapshot pinned.

### RG-03 — AA stays in daytime
**Source:** IT-02. **Severity:** P0. **Automation:** AUTO.

Pinned single-recovery-task fixture. Assert suggested start ∈ `[09:00, 14:00]`. Snapshot pinned.

### RG-04 — Al-Anon stays absent
**Source:** IT-03. **Severity:** P0. **Automation:** AUTO.

Repo-wide grep over source, fixtures, templates, and seeds. Exits non-zero on any `Al-Anon` variant.

### RG-05 — Kroger pickup remains shorter than full store
**Source:** UT-05, IT-05. **Severity:** P0. **Automation:** AUTO.

Pinned grocery-task fixture. Assert `pickup.duration < fullStore.duration` and both options' labels match copy guide §6.

### RG-06 — Notification content excludes category
**Source:** UT-17, PR-05. **Severity:** P0. **Automation:** AUTO.

Pinned recovery-tagged block fixture. Assert built `UNMutableNotificationContent` matches a checked-in snapshot. Any change requires explicit approval.

### RG-07 — `ParseTaskRequest` JSON shape is stable and clean
**Source:** UT-19, PR-04. **Severity:** P0. **Automation:** AUTO.

Pinned fixture. JSON snapshot checked in. Any added field requires a reviewer to confirm it does not carry category context.

### RG-08 — String audit baseline
**Source:** PR-02. **Severity:** P0. **Automation:** AUTO.

`scripts/audit-strings.sh` runs on every PR. The expected match count is `0`. Any non-zero count fails the build.

### RG-09 — Identifier audit baseline
**Source:** PR-01. **Severity:** P0. **Automation:** AUTO.

`scripts/audit-identifiers.sh` runs on every PR. Expected match count is `0`.

### RG-10 — Analytics-free baseline
**Source:** PR-08, PR-09. **Severity:** P0. **Automation:** AUTO.

`scripts/audit-no-analytics.sh` and `scripts/audit-dependencies.sh` run on every PR. Expected match counts are `0`.

### RG-11 — Empty-state strings remain on the allow-list
**Source:** UX-01. **Severity:** P0. **Automation:** AUTO.

Snapshot tests for each empty state. The snapshot equals a verbatim string from copy guide §8. Changing copy requires updating the snapshot and a reviewer's approval.

### RG-12 — Overwhelmed mode shape is stable
**Source:** UT-15, UX-05. **Severity:** P0. **Automation:** AUTO.

Snapshot of the three options. Any deviation fails the build.

---

## 7. Definition of done

A change is "done" — for this rule surface — when **all** of the following hold:

### Must-pass automated gates (CI green)

1. **All UT-* unit tests pass.**
2. **All IT-* integration tests pass.**
3. **All RG-* regression tests pass against pinned snapshots.**
4. **All `scripts/audit-*.sh` privacy scripts (PR-01, PR-02, PR-03, PR-08, PR-09, PR-14) exit zero.**
5. **All snapshot tests (UX-01, UX-04, UX-05, UX-06, UX-07, UX-11) match committed snapshots.**
6. **No new dependency was added without updating the allow-list (PR-09).**
7. **No `print`/`Logger`/`os_log` call references `Task.rawText`, `userTitle`, `note`, or `category` in release-configured code (UT-22).**

### Must-pass manual gates (signed off in the release ticket)

8. **Voice review (UX-08).** A reviewer reads every user-visible string and confirms it matches copy guide §1. The reviewer signs the release ticket.
9. **Lock-screen photo review (UX-09).** Photographs of every notification path on a locked physical device attach to the release ticket.
10. **Siri Announce review (UX-10).** Spoken-aloud transcripts or recordings attach to the release ticket.
11. **VoiceOver pass (UX-11).** A reviewer runs VoiceOver on the main flows and confirms no category leak via accessibility labels.
12. **Visual leak audit (PR-15).** Screenshots of every screen with a recovery-tagged block attach to the release ticket.
13. **Comment / commit hygiene (PR-13).** A reviewer confirms no diff in the release range encodes personal history.

### Documentation and decisions

14. **Spec / privacy / copy / test docs are updated in the same PR as any behavioral change they govern.** A behavior change without a doc update is not done.
15. **Any deviation from the rules is documented as a deliberate exception** with: the section it deviates from, the reason, the reviewer who approved it, and a follow-up issue for re-alignment.
16. **No new user-facing string is added** unless it appears verbatim in one of: copy guide §2, §4, §6, §8, §9, §10 — or has been added to the appropriate section in the same PR.

### Release blockers — any one of these fails the release

- A P0 test fails or a P0 manual gate is unsigned.
- A privacy script exits non-zero.
- An analytics or attribution SDK appears in `Package.resolved` / `Podfile.lock`.
- A new identifier matching the privacy rules §3 patterns lands in `GentleDay/**`.
- A notification path leaks category context on the lock screen or via Siri.
- A non-user-typed user-visible string contains a spec §9 / copy §3 deny-list token.

---

## Notes for implementers

- This test plan is the QA contract. If a feature cannot be made to pass these tests, the feature is wrong, not the tests.
- When in doubt about a new scenario, write the test first and let the failure define the design.
- A test that needs to be loosened to pass should be treated as a design conversation, not a test edit.
- Cross-references: spec §14 (acceptance criteria), §15 (test scenarios); privacy rules §8 (acceptance criteria), §9 (tests Codex should add); copy guide §11 (acceptance criteria for copy).
