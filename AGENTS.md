# AGENTS.md

Repository guidance for coding agents working in Gentle Day.

## Project Shape

Gentle Day is a private iOS app built with Swift, SwiftUI, Observation, SwiftData, and UserNotifications. The checked-in app target is `GentleDay` inside `GentleDay.xcodeproj`; there is no Swift Package Manager, CocoaPods, Carthage, Tuist, or XcodeGen setup in this repo.

The optional local AI proxy lives in `server/`. It is a Node.js ES module Express app managed with npm and `package-lock.json`.

Primary app directories:

- `GentleDay/Models`: SwiftData models and shared enums.
- `GentleDay/Views`: SwiftUI screens and reusable UI.
- `GentleDay/ViewModels`: lightweight `@Observable` state.
- `GentleDay/Services`: scheduling and task action services.
- `GentleDay/AI`: AI parsing and scheduling request/response models.
- `GentleDay/Persistence`: SwiftData container and seed/migration helpers.
- `GentleDay/Notifications`: local notifications and action delegate.
- `GentleDay/Utilities`: theme, date formatting, strings, notification names.
- `docs/`: recovery-sensitive product, privacy, copy, and QA contracts.

## Commands

Run from the repo root unless noted.

### iOS App

Requires full Xcode selected with `xcode-select`; Command Line Tools alone are not enough.

- Build: `xcodebuild -project GentleDay.xcodeproj -scheme GentleDay -destination 'generic/platform=iOS Simulator' build`
- Test: `xcodebuild -project GentleDay.xcodeproj -scheme GentleDay -destination 'platform=iOS Simulator,name=iPhone 16' test` or the simulator name available locally.
- Privacy audits: `scripts/audit-recovery-sensitive-privacy.sh`, `scripts/audit-strings.sh`, `scripts/audit-identifiers.sh`
- Lint: no SwiftLint or SwiftFormat config is currently checked in. Use `git diff --check` plus the privacy audit as the baseline checks.
- Typecheck: the app build command above is the Swift typecheck gate.

### Local AI Proxy

- Install: `cd server && npm install`
- Run: `cd server && npm run dev`
- Syntax check: `cd server && npm run check`
- Test/lint/typecheck: no server test runner, ESLint config, or TypeScript config is currently checked in.

## Project Conventions

- Keep SwiftUI views declarative and small enough to scan. Put user actions and stateful orchestration in `ViewModels` or small services when behavior grows.
- Use SwiftData `@Model` types for persisted app state. Update `PersistenceController.schema` whenever a persisted model is added.
- Keep scheduling decisions behind `AIScheduleService`; the current implementation is `HeuristicScheduler`.
- Keep task recommendation decisions in `NextActionViewModel`; UI screens should render recommendations, not score them inline.
- Prefer existing design tokens and components from `GentleTheme` and `GentleComponents`.
- Preserve `TaskItem.rawText` verbatim. Derived titles, tiny steps, categories, and schedule hints must not overwrite the original capture.
- Keep notification action identifiers neutral and centralized in `ReminderService`.
- The iOS app must never contain an OpenAI API key. Real AI parsing goes through the configured proxy endpoint only.
- Do not add analytics, crash-reporting SDKs with PII, remote config, A/B testing, cloud sync, accounts, background upload, or silent push behavior.
- Avoid new dependencies unless the feature cannot reasonably be built with the current Apple frameworks and existing server stack.

## Recovery-Sensitive Privacy Constraints

The files in `docs/` are governing contracts for recovery-sensitive scheduling work:

- `docs/recovery-sensitive-scheduling-spec.md`
- `docs/privacy-and-sensitive-context-rules.md`
- `docs/recovery-sensitive-copy-guide.md`
- `docs/recovery-sensitive-scheduling-test-plan.md`

For recovery-sensitive work:

- Private category metadata may influence local scheduling only. It must not be visible in UI copy, notification copy, widgets, Siri/Shortcuts/Spotlight surfaces, exports, logs, screenshots, sample data, branch names, PR titles, or commit messages.
- Do not send category, tag, recovery-identifying metadata, or derived sensitive labels to the AI proxy. Proxy payloads may include raw text the user chose to send plus generic scheduling context only.
- Do not log raw task text, task titles, notes, block contents, category values, or AI request/response bodies. Debug logs must still avoid category values.
- Notifications must be lock-screen safe. Do not add category words, motivational tails, or app-inferred context to notification title/body/subtitle.
- User-facing copy should be short, neutral, practical, and non-clinical. Avoid streaks, scores, shame, crisis routing, therapist/coach/sponsor voice, hype, and blame language.
- Fixtures and examples must use neutral titles such as `Meeting at 10`, `Walk`, or `Groceries`; do not use recovery-identifying sample text.
- Comments and docs should describe scheduling rules, not personal history.

## Definition Of Done

For recovery-sensitive scheduling changes, done means:

- The feature behavior matches the spec, privacy rules, copy guide, and test plan.
- A Swift test target exists and covers the relevant planner, proxy-payload, notification-payload, copy, privacy, and regression scenarios.
- Build passes with the Xcode command above.
- All available automated tests pass.
- `cd server && npm run check` passes when proxy code changes.
- `scripts/audit-strings.sh` and `scripts/audit-identifiers.sh` pass, or any existing failures are explicitly listed for review without being auto-fixed.
- `git diff --check` passes.
- No new user-facing string violates the copy guide deny-list.
- No new log, network payload, export, fixture, identifier, or visual treatment leaks sensitive category context.
- Any behavior change updates the governing docs in the same PR.
- Manual gates called out in the test plan are completed before release when they apply, especially lock-screen notification, Siri Announce, VoiceOver, visual leak, and copy review.
