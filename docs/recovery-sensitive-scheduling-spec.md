# Gentle Day — Product Behavior Spec

Audience: coding agents (Codex, Claude Code) implementing scheduling, planner, and copy behavior in Gentle Day.

Scope: this is a behavior spec for a private, on-device iOS planning app. It is not clinical guidance. The app supports planning and routines only. It is not a therapist, doctor, sponsor, sober coach, or emergency service.

---

## 1. App behavior summary

Gentle Day is a private, on-device iOS time-blocking app for one primary user. It helps the user capture tasks, build a realistic daily plan, see one next step when overwhelmed, and recover gracefully when the day slides.

The planner treats the user's day as a real life with limited energy, not as empty productivity capacity. The default bias is **under-schedule, protect mornings and evenings, and keep recovery, self-care, and family time first-class**, not fit around work-style tasks.

Recovery context (AA meetings, sober routines, self-care) is treated as **normal, important, daytime activity** — not as a crisis feature, not as a night-time afterthought, and not as something the app names, scores, or tracks beyond the user's own opt-in entries.

The app never frames recovery, self-care, or rest as "soft", "extra", or "leftover" time.

---

## 2. Core scheduling principles

1. Capture first, sort later. Quick Capture must never block on categorization.
2. Preserve the raw user input verbatim on every captured task.
3. The day has a real cap. Empty daytime hours are not free capacity.
4. Default to fewer blocks, longer buffers, and more carry-forward than a typical productivity app.
5. Mornings ramp up gently. Evenings wind down. Neither is a slot to backfill.
6. Recovery, self-care, errands, and family time are first-class blocks with equal standing to any task.
7. Every scheduled item is movable, shrinkable, and skippable without penalty.
8. If the user marks themselves overwhelmed, the planner collapses to at most three small visible options.
9. No streaks, scores, completion rates, or comparison metrics. Ever.
10. The planner explains *what* it scheduled, not *why the user should feel a certain way about it*.

---

## 3. Daily availability assumptions

Default weekday model (overridable in Settings):

- **Early morning (wake → ~8:30)**: family/launch-the-day window. Keep light. Used for breakfast, getting the child ready, drop-off prep.
- **Morning (~9:00 – ~12:00)**: primary daytime window. Best slot for AA meetings, appointments, focused self-care, errands, planning, and any task that benefits from energy.
- **Midday (~12:00 – ~13:30)**: lunch + reset. Default to unscheduled or a single light block.
- **Afternoon (~13:30 – ~15:30)**: secondary daytime window. Good for errands, grocery pickup, lower-energy tasks, walks, rest.
- **Late afternoon (~15:30 – pickup)**: wind-down and pickup prep. Avoid scheduling new effortful blocks here.
- **Evening (after pickup)**: family-first. Default to light or unscheduled. Only schedule evening blocks the user has explicitly asked for.
- **Night**: not a planning surface. No suggested blocks.

Weekends:

- Treat as family-default. Do not auto-fill daytime with errands or recovery activity unless the user explicitly schedules them.
- Grocery and errands are allowed but not preferred on weekends if a weekday slot is reasonable.

Daytime is **available**, not **empty**. The planner must not treat an open 10:00–14:00 block as four hours of productivity capacity. See §4.

---

## 4. Recovery-sensitive planning rules

These rules apply globally to the planner, suggestions, and copy.

1. **Do not overload an open day.** If the visible weekday daytime window has ≥3 hours open, the planner may schedule at most:
   - 1 recovery/self-care block, **and**
   - 1 errand block (or grocery pickup), **and**
   - 1 small admin/home block.
   Anything beyond that is carry-forward, not auto-scheduled.
2. **Protect a daily quiet block.** Reserve at least one ≥30-minute unscheduled window during weekday daytime by default. Do not offer to fill it unless the user asks.
3. **Recovery activity is daytime-first.** When suggesting times for AA, meetings, check-ins, journaling, or recovery-adjacent self-care, prefer morning or early afternoon. Do not default these to evening.
4. **Evenings stay light.** The planner must not auto-suggest recovery activity, errands, or heavy admin into the post-pickup evening window. The user can still place them there manually.
5. **Al-Anon is not a default.** Do not treat Al-Anon, family-of-alcoholic groups, or partner-side recovery activities as a recurring evening default for this user. They are not on the suggestion list unless the user types them in.
6. **No clinical or sponsor framing.** The planner never produces text like "your recovery plan", "your sobriety goals", "your sponsor said", "check in with your program". Recovery-typed blocks are surfaced with neutral, user-chosen titles only.
7. **No streak, no count, no day-counter.** The app must not display sober day counts, meeting counts, or any cumulative recovery metric, even if the user logs meetings. Each meeting is a normal completed block.
8. **No crisis routing.** The app does not show hotline numbers, "are you okay?" prompts, mood check-ins, or emergency UI. If the user appears to be in crisis, the app's correct behavior is to stay quiet and let them use real-world support. (One static, opt-in line in Settings pointing to external resources is acceptable; nothing dynamic.)
9. **Overwhelmed mode is generic.** "I'm Overwhelmed" hides the list and offers three tiny actions. It must not single out recovery items, name them, or treat them as the obvious next step.
10. **Carry-forward over pressure.** Unfinished recovery or self-care items carry forward silently. No "you missed" language. See §9.

---

## 5. AA / recovery activity rules

Modeling:

- Recovery-typed tasks are stored as regular `Task` / `ScheduleBlock` records with a private, optional category tag (e.g. `category == .recovery`). The tag is used only for scheduling preference, never for display copy, and never leaves the device.
- The user can rename any recovery block to anything. The planner must respect the user's title verbatim.

Scheduling preferences:

- Default suggested window for a new recovery block: **weekday 09:00–14:00**.
- Default duration: **60 minutes** unless the user sets otherwise.
- Default buffer before/after: **15 minutes**.
- Recurrence: support simple daily / specific-weekdays / weekly patterns. No "intensity ramps", no "streak protection", no "make-up" logic.
- If a recovery block is skipped, it disappears from today and re-appears on its next scheduled occurrence. It is **not** auto-rescheduled to the evening or to "later today".

Display:

- Recovery blocks render with the same visual treatment as any other block. No special icon, color, badge, or label that would identify them as recovery to someone glancing at the screen. (See §8.)
- The block title is whatever the user typed. The app does not append "(recovery)", "(AA)", or any decoration.

Notifications:

- Use the same gentle copy as any other block. Do not reference the category in the notification body.
- Time Sensitive flag is allowed only if the user explicitly enables it on that specific block.

---

## 6. Grocery and errand rules

1. **Daytime by default.** Grocery and household errands suggest weekday daytime slots, preferring the afternoon window (~13:30–15:30) or late morning.
2. **Kroger pickup is a first-class lower-effort option.** When the user creates or reviews a grocery task, offer "Kroger pickup" as an alternative form with:
   - Shorter default duration (e.g. 20–30 min) vs. a full store trip (e.g. 60–75 min).
   - A reminder to place the order earlier in the day (or the day before) at a user-chosen lead time.
   - No judgment language. Both options are presented neutrally. Pickup is not framed as "easier because you can't handle the store"; it is framed as "shorter block".
3. **Don't stack errands.** Avoid scheduling more than one errand block per day by default. Additional errands carry forward.
4. **Avoid pre-pickup-time errands.** Don't suggest errands in the late-afternoon window that risks colliding with daycare pickup.
5. **Evenings are not for errands** by default. The planner does not auto-suggest grocery runs after pickup time.

---

## 7. Evening and family-time rules

1. After daycare pickup, the default plan is **light or empty**.
2. The planner does not auto-fill the evening with carried-forward tasks. Carry-forward goes to *tomorrow's* daytime by default.
3. Evening blocks must be explicitly added by the user. The planner may offer "add to tomorrow morning instead?" as a one-tap alternative when the user tries to drop a heavy block into the evening.
4. Family-typed blocks (dinner, bath, bedtime, family time) are first-class and protected the same way recovery blocks are: never auto-shrunk to make room for admin.
5. No notification fires for evening recovery or errand items by default. If the user has explicitly placed one there, fine; the app doesn't add its own.
6. Wind-down: no new suggestions, no planner nudges, no "you still have X to do" copy after a user-configured evening cutoff (default 19:30).

---

## 8. Privacy rules

1. **Local-only data.** All tasks, blocks, preferences, and category tags persist via SwiftData on device. No cloud sync, no iCloud mirroring, no analytics, no crash reporting that includes user text, no telemetry.
2. **Single-device, single-user.** No accounts, no sharing, no export-to-cloud feature in v1. A local-only export (e.g. share sheet to Files) is acceptable; an automatic upload is not.
3. **AI proxy boundary.**
   - The iOS app never calls OpenAI directly and never embeds an OpenAI key.
   - All AI parsing goes through the hosted Vercel proxy as described in `README.md`.
   - The request payload to the proxy must not include the `category` tag, recovery-specific metadata, or any field that labels content as recovery-related. The proxy sees only the raw text the user typed plus generic scheduling context (timezone, wake/sleep, planning style, default duration).
   - The proxy must not log raw `rawText` to durable storage. If logs exist for debugging, they must be ephemeral and contain no task content.
4. **No background uploads.** No background fetch, no silent push, no server-initiated state changes.
5. **No third-party SDKs that phone home.** No Firebase, no Sentry-with-PII, no analytics SDKs. If any SDK is added, it must be reviewed against this rule.
6. **Lock screen and previews.** Notification bodies must be safe to appear on a lock screen. They must not contain the word "recovery", "AA", "sobriety", "meeting" (in a recovery sense), or any phrasing that would out the user's context to someone glancing at the phone. Use the user-typed title only, with neutral verbs.
7. **Screen recording / screenshots.** No special handling required, but visual design must not add a recovery-identifying badge that would appear in screenshots. (See §5.)
8. **No biometric gate required**, but the app must be compatible with iOS Screen Time / app-level Face ID if the user enables it via OS settings.
9. **Logs.** No `print` or `os_log` of task titles or block contents in release builds. Debug logs are local only.

---

## 9. User-facing language rules

Allow-list (preferred verbs and framings):

- "Start", "begin", "try a small step"
- "Shrink this block", "make it 10 minutes"
- "Move to later", "move to tomorrow", "move to morning"
- "Skip without guilt", "skip for today"
- "Carry forward"
- "Minimum day" (a deliberately small plan)
- "One small step", "what should I do next"
- "Rest block", "quiet block"
- Neutral: "added", "scheduled", "done", "saved"

Deny-list (never produce, even in suggestions, error states, or empty states):

- "Streak", "in a row", "X days strong", "don't break the chain"
- "Score", "rating", "completion rate", "productivity", "efficiency"
- "Failed", "failure", "missed", "behind", "falling behind", "catching up"
- "Lazy", "should have", "you didn't"
- "Goal achieved", "crushed it", "beast mode", any hype framing
- "Recovery plan", "sobriety", "your program", "your sponsor", "check in" (in a recovery sense)
- "Are you okay?", "how are you feeling?", mood prompts of any kind
- "Important — don't skip", urgency framing on user-created blocks
- Therapist/coach voice: "I notice you…", "It sounds like…", "Let's explore…"
- Medical voice: "symptom", "trigger", "relapse", "craving"

Empty states:

- Empty inbox: "Nothing captured yet." (Not: "Great job!" / "All clear!" / "You're crushing it.")
- Empty day: "Nothing scheduled. That's fine." (Not: "Time to be productive!" / "Plan your day!")
- Skipped item: "Carried forward." (Not: "You missed this." / "Try again tomorrow.")

Notification copy:

- Body: `"<user-typed title>. <optional user-typed note>."`
- No category words. No motivational tail. No emoji unless the user typed one.

Error states:

- Network/AI failure: "Couldn't parse that. Your text is saved in Quick Capture."
- Save failure: "Couldn't save. Try once more."
- No blame, no exclamation marks, no apology theater.

---

## 10. Things the app should avoid

- Assuming daytime = productivity capacity.
- Auto-filling evenings with carried-forward tasks.
- Putting AA, meetings, or recovery activity in evening defaults.
- Defaulting Al-Anon or partner-recovery activities as recurring evening blocks.
- Stacking multiple errands in one day.
- Surfacing any recovery-identifying word in notifications, widgets, lock screen, or Siri announce text.
- Mood check-ins, "how are you today?" prompts, journaling pressure.
- Hotline UI, crisis routing, emergency contacts in the main flow.
- Streaks, counts, scores, comparisons, leaderboards, achievements, badges.
- "You missed", "you're behind", "catch up", "make-up day".
- Therapist tone, sponsor tone, coach tone, drill-sergeant tone.
- Auto-rescheduling skipped recovery blocks into the same day.
- Sending recovery-category metadata to the AI proxy.
- Any cloud sync, analytics, or third-party telemetry.
- Pushing notifications outside the user's configured wake → wind-down window.

---

## 11. Example good recommendations

- User opens app at 9:10 on a weekday with an empty schedule and an inbox of: "AA meeting", "groceries", "fold laundry", "call insurance", "walk".
  Planner suggests:
  - 09:30 AA meeting (60 min)
  - 11:15 Walk (30 min)
  - 13:30 Groceries — *or* Kroger pickup (shorter)
  - Quiet block 14:30–15:30 reserved
  - Carried forward: fold laundry, call insurance
  Evening: empty.

- User taps "I'm Overwhelmed" at 10:45.
  App hides the list, shows three small options:
  - "Start the next block (Walk, 30 min)"
  - "Shrink it to 10 minutes"
  - "Skip today, carry forward"

- User creates a task "grocery run".
  App offers: "Full store (60 min)" or "Kroger pickup (25 min, order earlier)". Neutral phrasing, both equal.

- User skips a recovery block.
  App shows: "Carried forward." Block reappears at its next scheduled occurrence, not later today.

- User tries to drop a 90-minute "deep clean kitchen" block into 20:00.
  App offers: "Move to tomorrow morning instead?" with a one-tap accept.

---

## 12. Example bad recommendations

- "You haven't been to a meeting in 3 days — let's schedule one tonight at 8pm." *(Counts, evening default, pressure.)*
- "Great job on your recovery streak! 🔥" *(Streak, hype, recovery-identifying.)*
- "Your daytime is wide open — let's fill it with 6 tasks." *(Treats daytime as empty capacity.)*
- "Add Al-Anon as a recurring Tuesday 7pm block?" *(Wrong default, evening, wrong activity.)*
- Notification on lock screen: "Time for your AA meeting." *(Outs the user.)*
- "You missed yesterday's walk. Make it up today." *(Missed/make-up framing.)*
- "How are you feeling today? Tap a mood." *(Mood check-in.)*
- Empty state: "You're crushing it! 🎉" *(Hype, productivity framing.)*
- After a skipped block: "Are you okay? Need support resources?" *(Crisis routing, therapist voice.)*
- Sending `{"rawText": "AA meeting at noon", "category": "recovery"}` to the proxy. *(Category leak.)*

---

## 13. Required settings / data fields

Settings (all local, all user-editable, all with safe defaults):

- Wake time (default 07:00)
- Wind-down / evening cutoff (default 19:30)
- Sleep time (default 22:30)
- Daycare drop-off time (optional)
- Daycare pickup time (optional)
- Weekday daytime window start / end (defaults 09:00 / 15:30)
- Default block duration (default 30 min)
- Default buffer before/after (default 15 min)
- Planning style: `minimum day` | `light` | `standard` (default `light`)
- Max blocks per day cap (default 5)
- Reserve a daily quiet block (default ON)
- Time Sensitive notifications: per-block opt-in (default OFF)
- AI mode: `Mock AI` | `OpenAI via Proxy` (default Mock until user opts in)
- AI proxy endpoint (default the hosted Vercel URL from `README.md`)
- Static external-resources line in Settings: opt-in, off by default, no dynamic content

Data model additions / confirmations:

- `Task.rawText: String` — preserved verbatim, never overwritten.
- `Task.category: TaskCategory?` where `TaskCategory ∈ {recovery, errand, family, home, admin, selfCare, other}`. **Private. On-device only. Never serialized to the AI proxy. Never rendered as a visible label.**
- `Task.userTitle: String` — what shows in UI and notifications.
- `ScheduleBlock.start, .end, .buffersBefore, .buffersAfter`
- `ScheduleBlock.timeSensitive: Bool` (default false)
- `ScheduleBlock.recurrence: Recurrence?` — simple daily / specific weekdays / weekly only.
- `PlanningPreferences` — mirrors the Settings list above.
- `ReviewEntry` — local-only, free-text, no mood scale, no recovery prompts.

---

## 14. Acceptance criteria

A build is acceptance-ready when **all** of the following hold:

1. The string search across `GentleDay/**/*.swift` for the §9 deny-list returns zero matches in any user-visible string (including localized strings, notification copy, button labels, empty states, and error messages).
2. The AI proxy request payload, captured in a network test, contains no `category` field and no recovery-identifying metadata.
3. A weekday with 6+ hours of open daytime never auto-schedules more than: 1 recovery/self-care + 1 errand + 1 admin block, and reserves ≥30 minutes as a quiet block.
4. No recovery-tagged task is ever auto-scheduled into the post-pickup evening window in any planner output.
5. Al-Anon is not present in any default suggestion list, sample data, or onboarding content.
6. Kroger pickup appears as an explicit option whenever a grocery task is created or reviewed, with a shorter default duration than a full store trip.
7. Notification body text contains only the user-typed title and optional user-typed note. No category words, no app-generated motivational tail.
8. The app contains no streak, count, score, completion-rate, mood-check-in, hotline, or crisis-routing UI.
9. "I'm Overwhelmed" shows exactly three options and hides the full list.
10. Skipping a recovery block carries it forward to its next scheduled occurrence and does not re-suggest it later the same day.
11. No third-party analytics, crash-reporting-with-PII, or cloud-sync SDK is linked into the iOS target.
12. All user data persists locally via SwiftData. No network call leaves the device except the explicit AI proxy request when the user invokes "Organize with AI".

---

## 15. Test scenarios

Each scenario lists setup → action → expected behavior. These should be implemented as unit/UI tests where feasible.

**S1 — Open daytime, do not overload.**
Setup: weekday, inbox has 8 mixed tasks, daytime window 09:00–15:30 is empty.
Action: Build My Day.
Expected: ≤3 auto-scheduled daytime blocks (recovery + errand + admin pattern), ≥30-minute quiet block reserved, remainder carried forward, evening empty.

**S2 — AA defaults to daytime.**
Setup: user creates a task titled "AA meeting", category `recovery`, no time set.
Action: ask planner to suggest a time.
Expected: suggested slot falls within 09:00–14:00 on a weekday. Not evening.

**S3 — Skipped recovery block carries forward, does not re-suggest today.**
Setup: 10:00 recovery block exists today.
Action: tap "Skip without guilt" at 10:05.
Expected: block disappears from today, reappears at its next scheduled occurrence (per recurrence), no later-today re-suggestion, copy reads "Carried forward."

**S4 — Evening drop redirects to tomorrow morning.**
Setup: user drags a 90-min admin block onto 20:00.
Action: drop.
Expected: prompt offers "Move to tomorrow morning instead?" with one-tap accept. If user confirms evening, accept it but do not auto-add others.

**S5 — Grocery offers Kroger pickup.**
Setup: user adds a task "grocery run".
Action: open the task or run Organize with AI.
Expected: two options visible — full store (longer) and Kroger pickup (shorter, with order-earlier reminder). Neutral phrasing for both.

**S6 — No category leak to proxy.**
Setup: AI mode = OpenAI via Proxy. Task `rawText = "AA meeting tomorrow at noon"`, `category = .recovery`.
Action: invoke Organize with AI.
Expected: outbound request body contains `rawText` but no `category`, no `recovery`, no tag that identifies the content as recovery-related. Verified by a network/serialization unit test.

**S7 — Lock-screen-safe notification.**
Setup: scheduled block, user-typed title "Meeting at noon", category `recovery`.
Action: fire the notification.
Expected: body reads exactly the user-typed title (+ optional user note). No "AA", "recovery", "meeting reminder", or category word added by the app.

**S8 — Overwhelmed mode collapses safely.**
Setup: 6 blocks scheduled today.
Action: tap "I'm Overwhelmed".
Expected: list is hidden; three small actions shown: start next block, shrink to 10 min, skip today. None of the three names a recovery block specifically; they reference the next chronological block neutrally.

**S9 — No streak / no count.**
Setup: 10 completed blocks across the week, 4 of them `recovery`.
Action: open Review.
Expected: no day count, no streak, no recovery-specific tally. Plain list of completed items at most.

**S10 — Al-Anon is not a default.**
Setup: fresh install, onboarding.
Action: walk through onboarding and look at any suggested templates or sample tasks.
Expected: "Al-Anon" appears nowhere. No partner-side recovery activity is suggested as a recurring default.

**S11 — Quiet block protected.**
Setup: user has reserve-daily-quiet-block = ON, daytime 09:00–15:30 open.
Action: Build My Day with a large inbox.
Expected: at least one contiguous ≥30-minute window in daytime remains unscheduled. Planner does not offer to fill it unless the user explicitly requests "fill quiet block".

**S12 — Wind-down respected.**
Setup: evening cutoff 19:30, time is 19:45.
Action: open the app.
Expected: no new suggestions, no "you still have X" copy, no planner nudges. The app is usable for manual entry but quiet by default.

**S13 — Deny-list copy audit.**
Setup: CI grep over `GentleDay/**/*.swift` and `*.strings` for the §9 deny-list.
Action: run the audit.
Expected: zero matches in user-visible strings.

**S14 — No third-party telemetry.**
Setup: built app.
Action: inspect linked frameworks and run a network capture during normal use without invoking AI.
Expected: no outbound network calls. With AI invoked: exactly one call, to the configured proxy endpoint, payload sanitized per S6.

---

## Notes for implementers

- When in doubt between "schedule it" and "leave it open", leave it open.
- When in doubt about copy, pick the more neutral, shorter version.
- When in doubt about a category-aware behavior, ask: *would this behavior be visible to someone glancing at the phone, or visible in a server log?* If yes, redesign it so the answer is no.
- This spec is the source of truth for behavior and copy. If a future request conflicts with it, surface the conflict instead of silently complying.
