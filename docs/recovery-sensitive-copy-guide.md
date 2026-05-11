# Gentle Day — Recovery-Sensitive UX Copy Guide

Audience: coding agents (Codex, Claude Code), designers, and human reviewers writing or reviewing any user-facing string in Gentle Day.

Companion to [`recovery-sensitive-scheduling-spec.md`](./recovery-sensitive-scheduling-spec.md) and [`privacy-and-sensitive-context-rules.md`](./privacy-and-sensitive-context-rules.md). This document is the source of truth for **voice, tone, and exact phrasing** of every string the user can see, hear, or read in a notification, widget, or share sheet.

Scope: this is a UX writing guide for a private, on-device planning app. It is not clinical guidance, not therapeutic content, and not a substitute for real support.

Guiding rule, in one line:

> The app is a quiet helper. It states facts, offers small options, and gets out of the way. It is never the loudest voice in the user's day.

---

## 1. Voice and tone principles

The app's voice is **a calm, competent, respectful adult** who knows the user is also a calm, competent, respectful adult. It is not a cheerleader, not a coach, not a counselor, not a parent, not a friend doing a bit.

Eight principles, in priority order. When two conflict, the higher one wins.

1. **Neutral over warm.** When in doubt, say less. Plain factual phrasing ("Carried forward.") beats warm phrasing ("No worries, we'll get it tomorrow!"). Warmth that the user didn't ask for reads as patronizing.
2. **Short over complete.** Prefer fragments over full sentences. Prefer one clause over two. The app interrupts the user's day; it should interrupt briefly.
3. **Practical over emotional.** Every string should help the user do or decide something. If a string only exists to make the user feel a way, cut it.
4. **Optional over directive.** Offer; do not instruct. "Move to tomorrow morning?" not "You should move this to tomorrow morning."
5. **Specific over generic.** "Walk, 30 min" beats "Your next activity." Names the user typed always win over labels the app invented.
6. **Quiet over hype.** No exclamation points except in genuine error states, and even then, sparingly. No emoji unless the user typed one. No all-caps. No "🎉", no "🔥", no "💪".
7. **Recoverable over final.** Every action implies a way back. "Skip without guilt" instead of "Skip". "Move later" instead of "Cancel". "Carried forward." instead of "Missed."
8. **Private over knowing.** The app never references the user's history, situation, category tags, or anything it has inferred. It speaks only to what the user just did or what is next.

What the voice is **not**:

- Not a therapist. No "I notice that…", "It sounds like…", "How does that make you feel?", "Let's sit with that."
- Not a doctor. No diagnostic language, no "symptom", "trigger", "relapse", "craving", "intervention", "recovery plan".
- Not a sponsor. No "your program", "check in", "one day at a time", "keep coming back", "your sober journey".
- Not an emergency service. No "Are you okay?", "Need help?", no hotline UI, no mood prompts, no crisis routing.
- Not a productivity coach. No "Crush your day", "Beast mode", "Let's go!", "You got this!", "No excuses", "Win the morning".
- Not a judgmental spouse or parent. No "You said you would…", "Don't forget — again", "Try to actually finish this one", "You always do this."

---

## 2. Words and phrases to use

These are the building blocks. Prefer them. They are deliberately short and dull, in a good way.

### Verbs for actions

- Start
- Begin a small step
- Shrink (to 10 minutes, to 15 minutes)
- Move later
- Move to tomorrow
- Move to morning
- Skip without guilt
- Skip for today
- Carry forward
- Save
- Add
- Edit
- Done

### Phrases for the planner

- "Suggested for today."
- "Reserved as quiet time."
- "Carried forward to tomorrow."
- "No blocks scheduled."
- "Light day."
- "Minimum day."
- "One small step:"
- "What should I do next?"
- "Add to tomorrow morning instead?"
- "Take this off today's plan?"
- "Pickup option: shorter block."
- "Full store option: longer block."

### Phrases for state changes

- "Saved."
- "Added."
- "Scheduled."
- "Moved."
- "Shrunk to 10 minutes."
- "Done."
- "Carried forward."
- "Skipped for today."
- "Quiet block reserved."

### Phrases for empty states

- "Nothing captured yet."
- "Nothing scheduled. That's fine."
- "Inbox is clear."
- "No blocks for today."
- "Quiet day."

### Phrases for errors

- "Couldn't save. Try once more."
- "Couldn't reach the assistant. Your text is saved."
- "Couldn't parse that. Your text is saved in Quick Capture."
- "Something didn't go through. Your changes are kept."

### Phrases for AI / parsing

- "Organize with AI"
- "Review before adding"
- "Use as typed"
- "Edit before saving"

### Phrases for the overwhelmed flow

- "Three small options."
- "Start the next block."
- "Shrink to 10 minutes."
- "Skip today, carry forward."
- "Take a quiet block."

### Neutral connectors

- "or"
- "instead"
- "for today"
- "for now"
- "later"
- "tomorrow"

---

## 3. Words and phrases to avoid

These are prohibited in any user-visible string: UI labels, button text, empty states, onboarding, notifications, widget content, Siri/Shortcuts text, error messages, share-sheet output. (Source comments and developer docs are governed by the privacy rules document, not this one.)

A regex-friendly version of this list lives in the spec (§9) and the privacy rules (§3). This file gives examples and the *why*.

### Recovery / clinical vocabulary — prohibited

`recovery`, `sobriety`, `sober`, `sobriety streak`, `sober days`, `relapse`, `craving`, `trigger` (as a clinical noun), `symptom`, `meeting` (in a recovery sense — *user-typed titles are fine*), `program`, `step` (as in twelve-step), `sponsor`, `check in` (in a recovery sense), `your journey`, `your recovery`, `Al-Anon`, `12-step`, `AA` (as an app-added label), `rehab`, `detox`, `treatment`, `clinical`, `therapy` (as an app-added label).

Why: even if the user is comfortable with the word, the app must not be the one introducing it. The app does not know who else is looking at the screen, the lock screen, or a screenshot.

### Streak / score / productivity vocabulary — prohibited

`streak`, `in a row`, `X days strong`, `don't break the chain`, `score`, `rating`, `completion rate`, `productivity`, `efficiency`, `points`, `XP`, `level`, `badge`, `achievement`, `unlocked`, `goal achieved`, `crushed it`, `beast mode`, `win the day`, `win the morning`, `no excuses`, `let's go`, `you got this`, `keep grinding`, `hustle`, `level up`.

Why: the spec bans streaks and scores outright. This vocabulary smuggles them in through copy even when the data model doesn't.

### Shame / blame vocabulary — prohibited

`failed`, `failure`, `missed`, `behind`, `falling behind`, `catching up`, `make up`, `lazy`, `should have`, `you didn't`, `you forgot`, `again`, `try harder`, `do better`, `last chance`, `one more time`.

Why: even mild blame framing reads as judgment when the user opens the app at a low moment. Carry-forward replaces all of this.

### Crisis / clinical-help vocabulary — prohibited

`Are you okay?`, `How are you feeling?`, `mood`, `feelings`, `emotional check-in`, `support resources`, `hotline`, `help line`, `crisis`, `emergency`, `urgent — call`, `talk to someone`, `reach out to your support network`.

Why: the app is not equipped to handle crisis. Surfacing the words implies a capability it doesn't have. The spec routes any external-resources line to a static, opt-in Settings row only.

### Therapist / sponsor / coach voice — prohibited

`I notice you…`, `It sounds like…`, `Let's explore…`, `Let's sit with that.`, `What's coming up for you?`, `That must be hard.`, `Take a breath.`, `Be kind to yourself.`, `One day at a time.`, `Progress, not perfection.`, `Trust the process.`, `Your future self will thank you.`

Why: this voice belongs to humans the user chooses. The app borrowing it is uncanny and intrusive.

### Cheesy motivational / hype — prohibited

`You're crushing it!`, `Great job!`, `Amazing!`, `You're on fire!`, `Way to go!`, `Keep it up!`, `🎉`, `🔥`, `💪`, `🚀`, exclamation points in routine confirmations.

Why: hype after small actions reads as fake. Hype after recovery-tagged actions reads as patronizing.

### Urgency / pressure — prohibited

`Don't forget`, `Important — don't skip`, `Last chance`, `Hurry`, `Only X minutes left`, `Now or never`, `Time-sensitive` (as app-added text — the iOS interruption level is fine), `Critical`, `Must do today`.

Why: urgency is the user's call, not the app's. The Time Sensitive flag is per-block opt-in; the *word* in copy is not.

### Relationship / identity framing — prohibited

`partner`, `spouse`, `husband`, `wife`, `family member`, `loved one`, anything that names the user's role or relationships in app copy. (User-typed titles like "Call mom" are fine — those are the user's words.)

Why: the spec keeps the app person-agnostic. Any role label invites assumptions about who else might be reading.

---

## 4. Good reminder examples

A "reminder" here means any planner-surface text that prompts the user about a scheduled block before or at its start time. (Notification bodies are covered in §9.)

### Inside the app, a few minutes before a block

Good:

- "Walk, 30 min — starts in 5."
- "Groceries — starts at 1:30."
- "Meeting at 10 — starts in 10 min."  *(user-typed title; app adds only the time)*
- "Quiet block reserved 2:30–3:00."

Why: factual, short, the user's words, no commentary.

### When a block is overdue by a few minutes

Good:

- "Walk is on now. Start, shrink to 10, or move later."
- "Groceries is on now. Pickup option is still available."

Why: states the situation, offers options, no blame.

### When the user just completed a block

Good:

- "Done. Next: Walk at 2:30."
- "Done."

Why: confirms, points to what's next if there is a next, otherwise stops talking.

### When the user just skipped a block

Good:

- "Carried forward."
- "Carried forward to tomorrow morning."

Why: one fact. No empathy theater. No "no worries!"

---

## 5. Bad reminder examples

For each, the bad version and why it's bad. Do not ship any of these.

- "Time for your AA meeting! 🙏"
  Outs the user, adds an emoji the user didn't choose, uses hype tone.

- "Don't forget your recovery block — you've got this!"
  Urgency word, category word, coach voice.

- "You missed your last walk. Make it up today?"
  Missed/make-up framing; treats carry-forward as failure.

- "Hey! Checking in — how are you feeling about today's plan?"
  Therapist voice, mood prompt, faux-casual.

- "Important reminder: groceries. Try to actually do it this time."
  Urgency, judgment, blame.

- "Your sobriety meeting is in 10 minutes. Stay strong! 💪"
  Outs the user, hype, sponsor voice.

- "You're on a 4-day streak! Don't break the chain."
  Streak, gamification, pressure.

- "Take a deep breath. You can do this small thing."
  Coach voice, condescending.

- "Reminder from your Gentle Day partner: Walk."
  Relationship/identity framing, anthropomorphizes the app.

- "URGENT: Walk starts now!!!"
  All-caps, exclamation pile-up, urgency.

---

## 6. Good scheduling recommendation examples

A "scheduling recommendation" is any planner-surface text that proposes a time, slot, alternative, or carry-forward.

Good:

- "Suggested: Walk at 11:15, 30 min."
- "Suggested for daytime: Meeting at 10:00, 60 min."  *(user-typed title; app picked the slot)*
- "Two options for Groceries:
  - Pickup, 25 min, place order by 11
  - Full store, 60 min"
- "Add to tomorrow morning instead? Today is full."
- "Quiet block reserved 1:30–2:00. Leave it open or fill it."
- "Light day. 3 blocks scheduled. 2 carried forward."
- "Minimum day: one block, one quiet block, the rest open."
- "Move to tomorrow morning?" *(offered when dropping a heavy block into the evening)*

Why these work: each one states the proposal, gives the user a clear next move, and uses neutral words. None of them justify the proposal by referencing the category, the user's history, or a heuristic.

---

## 7. Bad scheduling recommendation examples

- "You have 6 free hours today — let's fill them up!"
  Treats daytime as empty productivity capacity; hype.

- "You should schedule your recovery block in the evening so it doesn't interfere with errands."
  Wrong default, category word, directive voice.

- "Want to add Al-Anon as a recurring Tuesday 7pm block?"
  Wrong default activity, evening default, category word.

- "Because you're in recovery, mornings are better for meetings."
  Names the user's history. Never.

- "You haven't done a meeting in 3 days. Schedule one tonight?"
  Counting, evening default, pressure, category word.

- "Great job staying on track! Want to add another block?"
  Hype, productivity framing.

- "Your sponsor would probably want you to do this at 9am."
  Sponsor voice. Out of scope entirely.

- "Free time detected — adding 4 self-care tasks."
  Treats open time as capacity; auto-fills without asking.

- "Reschedule failed block?"
  Failed framing.

- "Schedule a recovery check-in tonight at 8pm?"
  Category word, evening default, check-in framing.

---

## 8. Empty state examples

Empty states are where bad copy hides. Most of these strings are written once and then ignored — make sure they pass review.

### Inbox empty

Good:

- "Nothing captured yet."
- "Inbox is clear."

Bad:

- "You're all caught up! 🎉" — hype, completion framing.
- "Great job — nothing to do!" — patronizing.
- "Capture your first task to get started on your recovery journey." — category word, onboarding-coach voice.

### Today's schedule empty

Good:

- "Nothing scheduled. That's fine."
- "Quiet day."
- "No blocks for today."

Bad:

- "Time to be productive!" — productivity framing.
- "Plan your day to make the most of it!" — hype.
- "An empty day is a wasted day." — never. Just never.

### Review screen empty

Good:

- "Nothing to review yet."
- "Come back after a few days."

Bad:

- "Reflect on your progress so far!" — coach voice.
- "How are you feeling about this week?" — mood prompt.
- "0 meetings logged this week." — counting, category word.

### Search / filter empty

Good:

- "No matches."
- "Nothing here."

Bad:

- "Sorry, we couldn't find anything! Try again!" — apology theater, exclamation pile-up.

### Onboarding "no tasks yet"

Good:

- "Add one task to start. You can edit anytime."

Bad:

- "Welcome! Let's build your recovery routine together!" — category word, partner framing, hype.

---

## 9. Notification examples

Notifications are the highest-risk surface: they appear on the lock screen, can be read by anyone glancing at the phone, and can be spoken aloud by Siri Announce. Aligned with the privacy rules §4.

### Format

```
title:    <user-typed task title>
subtitle: ""           (empty by default)
body:     <user-typed task title>[. <user-typed note>]
```

The app never adds words. The category never appears. No emoji unless the user typed one.

### Good notification examples

Body strings exactly as they would appear on the lock screen:

- `Walk`
- `Walk. Put on shoes first.`
- `Meeting at 10`  *(the user titled it this; the app did not.)*
- `Groceries`
- `Groceries. Pickup at 1:30.`
- `Pick up at daycare`

### Good action button labels (registered once, used everywhere)

- `Start`
- `Snooze 5 min`
- `Snooze 15 min`
- `Shrink`
- `Move later`
- `Skip without guilt`

### Bad notification examples — do not ship

- `Time for your AA meeting.` — outs the user on the lock screen.
- `Your recovery block is starting.` — category word.
- `Don't forget — Meeting at 10!` — urgency, exclamation.
- `Walk 🚶‍♀️🔥` — app-added emoji.
- `You haven't done a walk in 2 days. Try today?` — counting, pressure.
- `Reminder from Gentle Day: how are you feeling about today?` — mood prompt, app-anthropomorphization.
- `🎉 Done with Walk! Streak: 4 days!` — hype, streak, app-added emoji.

### Notification grouping and Siri Announce

- Grouping (`threadIdentifier`) does not encode category. Use the date or a single static thread.
- Siri Announce reads only the title and body above. Because those are the user's words, anything spoken is something the user wrote — and even then, it does not include the word "meeting" unless the user typed it.

---

## 10. Error message examples

Errors are short, factual, and tell the user their work is safe. They never blame the user, never apologize theatrically, and never use the category as context.

### Network / AI failures

Good:

- `Couldn't reach the assistant. Your text is saved in Quick Capture.`
- `Couldn't parse that. Your text is saved.`
- `Couldn't connect. Try again later.`

Bad:

- `Failed to send your AA meeting to OpenAI.` — category word, "failed".
- `Oh no! Something went wrong! 😞` — hype-shaped sadness, emoji.
- `We couldn't process your recovery task. Please try again.` — category word.

### Save / persistence failures

Good:

- `Couldn't save. Try once more.`
- `Couldn't save changes. Your previous version is kept.`

Bad:

- `Save failed!! Your work might be lost!!!` — alarm tone, false uncertainty.
- `Hmm, that didn't work. Want to retry?` — faux-casual.

### Permission denied (notifications, speech, etc.)

Good:

- `Notifications are off. Turn them on in iOS Settings to receive reminders.`
- `Microphone is off. Turn it on in iOS Settings to use voice capture.`

Bad:

- `You denied permissions. The app cannot work without them.` — accusatory.
- `Please please enable notifications so we can keep you on track!` — coach voice.

### Validation errors

Good:

- `Pick a start time that's before the end time.`
- `Duration must be at least 5 minutes.`

Bad:

- `Invalid input!` — vague, alarm.
- `You entered something wrong.` — accusatory.

### Background / unexpected state

Good:

- `Something didn't go through. Your changes are kept.`

Bad:

- `Unknown error.` — useless.
- `Oops! Try again!` — exclamation, hype-sad.

---

## 11. Acceptance criteria for user-facing copy

A build is acceptance-ready for copy when **all** of the following hold. These complement the spec's §14 and the privacy rules' §8.

1. **Deny-list audit.** A repo-wide grep over `GentleDay/**/*.swift`, `*.strings`, `*.stringsdict`, `*.xcstrings`, and asset catalog text returns zero matches for any §3 banned token in user-visible strings.
2. **No app-added emoji.** A grep for emoji code points in user-visible strings returns zero matches. (User-typed task titles are exempt and live in user data, not source.)
3. **No app-added exclamation points** in routine state-change confirmations, empty states, or scheduling recommendations. (`!` is allowed only in genuine validation errors and only sparingly.)
4. **Notification audit.** A unit test builds `UNMutableNotificationContent` for representative blocks (including recovery-tagged) and asserts: `title` equals the user-typed title, `subtitle` is empty, `body` equals the user-typed title (optionally followed by `. ` and the user-typed note), and no field contains any §3 token added by the app.
5. **Action button audit.** The registered `UNNotificationCategory` action titles are exactly the six in §9 ("Start", "Snooze 5 min", "Snooze 15 min", "Shrink", "Move later", "Skip without guilt"). No category-specific actions exist.
6. **Empty state audit.** Every empty state in the app (inbox, today, review, search, onboarding) returns text that appears verbatim in §8's "Good" lists or is reviewed against this guide. A snapshot test covers each empty state.
7. **Error message audit.** Every error path returns text that matches §10's "Good" patterns. A unit test asserts no error message contains a §3 token or the words "failed", "missed", "behind", "lazy", "should", "must".
8. **Onboarding audit.** Onboarding screens contain no category words, no relationship/identity framing, no coach voice, and no hype. Sample/seed tasks are neutral (see privacy rules §3).
9. **Localization audit.** When localized strings are added, each translation is reviewed against this guide. Translators are given §3 as a deny-list. Localized keys themselves are neutral (privacy rules §2).
10. **Voice review.** A human reviewer reads every user-visible string in one sitting and confirms it sounds like the §1 voice: calm, short, practical, not therapist/coach/sponsor/parent/spouse. CI cannot fully enforce this; it is a manual gate before release.
11. **Lock-screen review.** A reviewer triggers every notification path on a real device with the screen locked, photographs the lock screen, and confirms no notification reveals category context. (Manual.)
12. **Read-aloud review.** A reviewer enables Siri Announce Notifications and confirms that every notification, spoken aloud, would be safe to hear in a shared room. (Manual.)

---

## Notes for implementers

- When writing a new string, draft it, then cut it in half, then check it against §3.
- If a string feels warm, it is probably too warm. Re-read principle §1.1.
- If a string explains *why* the app is suggesting something, delete the explanation. The app does not justify itself to the user.
- If a string would embarrass the user when read aloud by Siri on the way to the school pickup line, rewrite it.
- This guide and the spec are the source of truth for copy. If a future request conflicts with them, surface the conflict rather than silently complying.
- Cross-references: spec §9 (language rules), §15 S7 (lock-screen-safe notifications); privacy rules §1.B (visible surfaces), §3 (unsafe naming), §4 (notification rules), §8 (acceptance criteria).
