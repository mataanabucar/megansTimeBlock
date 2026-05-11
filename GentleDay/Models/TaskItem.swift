import Foundation
import SwiftData

@Model
final class TaskItem: Identifiable {
    @Attribute(.unique) var id: UUID
    var rawText: String
    var title: String
    var notes: String
    var categoryRawValue: String
    var priorityRawValue: String
    var energyLevelRawValue: String
    var estimatedMinutes: Int
    var dueDate: Date?
    var flexibleWindow: String?
    var preferredDayOfWeek: Int?
    var isRecurring: Bool
    var recurrenceRule: String?
    var statusRawValue: String
    var createdAt: Date
    var updatedAt: Date
    var sourceRawValue: String
    var suggestedTinyStep: String
    var shrinkOptionsRawValue: String

    init(
        id: UUID = UUID(),
        rawText: String,
        title: String? = nil,
        notes: String = "",
        category: TaskCategory = .other,
        priority: PriorityLevel = .normal,
        energyLevel: EnergyLevel = .any,
        estimatedMinutes: Int = 15,
        dueDate: Date? = nil,
        flexibleWindow: String? = nil,
        preferredDayOfWeek: Int? = nil,
        isRecurring: Bool = false,
        recurrenceRule: String? = nil,
        status: TaskStatus = .inbox,
        source: CaptureSource = .typed,
        suggestedTinyStep: String? = nil,
        shrinkOptions: [String]? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        let naturalTime = NaturalTimeParser.parse(rawText, now: createdAt)
        let explicitTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedTitle = if let explicitTitle, !explicitTitle.isEmpty {
            explicitTitle
        } else if !naturalTime.cleanedTitle.isEmpty {
            naturalTime.cleanedTitle
        } else {
            Self.makeTitle(from: rawText)
        }
        let resolvedEstimatedMinutes = if let parsedMinutes = naturalTime.estimatedMinutes, estimatedMinutes == 15 {
            parsedMinutes
        } else {
            estimatedMinutes
        }

        self.id = id
        self.rawText = rawText
        self.title = String(resolvedTitle.prefix(60))
        self.notes = notes
        self.categoryRawValue = category.rawValue
        self.priorityRawValue = priority.rawValue
        self.energyLevelRawValue = energyLevel.rawValue
        self.estimatedMinutes = max(1, resolvedEstimatedMinutes)
        self.dueDate = dueDate ?? naturalTime.preferredDate
        self.flexibleWindow = flexibleWindow ?? naturalTime.flexibleWindowLabel
        self.preferredDayOfWeek = preferredDayOfWeek ?? naturalTime.preferredDayOfWeek
        self.isRecurring = isRecurring || naturalTime.recurrenceHint != nil
        self.recurrenceRule = recurrenceRule ?? naturalTime.recurrenceHint
        self.statusRawValue = status.rawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sourceRawValue = source.rawValue
        self.suggestedTinyStep = suggestedTinyStep ?? Self.makeTinyStep(from: rawText)
        self.shrinkOptionsRawValue = (shrinkOptions ?? Self.makeShrinkOptions(from: rawText, estimatedMinutes: resolvedEstimatedMinutes))
            .joined(separator: "\n")
    }

    var category: TaskCategory {
        get { TaskCategory(rawValue: categoryRawValue) ?? .other }
        set {
            categoryRawValue = newValue.rawValue
            touch()
        }
    }

    var priority: PriorityLevel {
        get { PriorityLevel(rawValue: priorityRawValue) ?? .normal }
        set {
            priorityRawValue = newValue.rawValue
            touch()
        }
    }

    var energyLevel: EnergyLevel {
        get { EnergyLevel(rawValue: energyLevelRawValue) ?? .any }
        set {
            energyLevelRawValue = newValue.rawValue
            touch()
        }
    }

    var status: TaskStatus {
        get { TaskStatus(rawValue: statusRawValue) ?? .inbox }
        set {
            statusRawValue = newValue.rawValue
            touch()
        }
    }

    var source: CaptureSource {
        get { CaptureSource(rawValue: sourceRawValue) ?? .typed }
        set {
            sourceRawValue = newValue.rawValue
            touch()
        }
    }

    var shrinkOptions: [String] {
        get {
            shrinkOptionsRawValue
                .split(separator: "\n")
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        set {
            shrinkOptionsRawValue = newValue.joined(separator: "\n")
            touch()
        }
    }

    func touch() {
        updatedAt = Date()
    }

    static func makeTitle(from rawText: String) -> String {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Untitled task" }

        let separators = CharacterSet(charactersIn: ".\n,;")
        let firstPhrase = trimmed.components(separatedBy: separators).first ?? trimmed
        let title = firstPhrase.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(title.prefix(60))
    }

    static func makeTinyStep(from rawText: String) -> String {
        let title = makeTitle(from: rawText).lowercased()
        if title.contains("laundry") { return "Put clothes in the washer." }
        if title.contains("dish") { return "Put five dishes in the sink." }
        if title.contains("kitchen") { return "Clear one small counter." }
        if title.contains("bill") || title.contains("pay") { return "Open the bill or payment page." }
        if title.contains("call") { return "Find the phone number." }
        if title.contains("appointment") { return "Check the date and time." }
        if title.contains("grocery") || title.contains("groceries") { return "Choose pickup or store trip." }
        return "Do the first visible step."
    }

    static func makeShrinkOptions(from rawText: String, estimatedMinutes: Int) -> [String] {
        let title = makeTitle(from: rawText).lowercased()
        if title.contains("kitchen") {
            return [
                "Clear one counter, 5 min",
                "Load dishwasher, 10 min",
                "Take out trash, 3 min",
                "Set a 10-minute timer"
            ]
        }

        if title.contains("laundry") {
            return [
                "Start one load, 5 min",
                "Move clothes to dryer, 5 min",
                "Fold five items, 5 min",
                "Set a 10-minute timer"
            ]
        }

        if title.contains("grocery") || title.contains("groceries") {
            return [
                "Pickup option: 25 min",
                "Make a short list, 10 min",
                "Full store option: 60 min"
            ]
        }

        let smallMinutes = min(max(estimatedMinutes / 2, 3), 10)
        return [
            "Do the first visible step, 3 min",
            "Set a \(smallMinutes)-minute timer",
            "Prepare what you need, 5 min"
        ]
    }
}

/// Reasonable duration band inferred from a task's content. The scheduler
/// is allowed to use the midpoint, but knowing the band lets it shrink for
/// Light/Minimum days without picking unrealistic values.
struct DurationBand: Equatable {
    var lower: Int
    var upper: Int

    var midpoint: Int {
        max(1, (lower + upper) / 2)
    }
}

struct NaturalTimeHint: Equatable {
    var cleanedTitle: String
    var preferredDate: Date?
    var preferredDayOfWeek: Int?
    var flexibleWindowLabel: String?
    var estimatedMinutes: Int?
    var recurrenceHint: String?
    var isThisWeek: Bool

    // MARK: - New constraint hints (set defaults so existing callers compile)

    /// Absolute deadline (date + time) that the task must finish by.
    /// Source phrases: "by 6", "by six", "by 6:00 pm", "before noon".
    /// The scheduler should compute `start = deadline - duration`.
    var deadlineTime: Date? = nil

    /// Soft cap on how late this task can be scheduled, regardless of the
    /// flexible window. Used for child / family / outdoor activity context.
    /// Time-of-day component only; the scheduler combines it with the chosen
    /// day. Examples: "with child" -> 19:30, "at the park" -> 19:30.
    var windowEndCap: DateComponents? = nil

    /// Reason behind `windowEndCap`, surfaced in the scheduler's reason text.
    var windowEndCapReason: String? = nil

    /// Range range of acceptable durations (min..max). When set, the scheduler
    /// can pick from this band instead of locking to a single value.
    var durationLowerBoundMinutes: Int? = nil
    var durationUpperBoundMinutes: Int? = nil

    /// Min minute-of-day below which this task should not start (e.g.
    /// "after work" → 17:00).
    var earliestStartMinuteOfDay: Int? = nil
}

struct NaturalTimeParserSampleCase: Identifiable {
    let id = UUID()
    var rawText: String
    var expectedCleanedTitle: String
    var expectedPreferredDayOfWeek: Int?
    var expectedWindowLabel: String?
    var expectedEstimatedMinutes: Int?
}

enum NaturalTimeParser {
    static let sampleValidationCases: [NaturalTimeParserSampleCase] = [
        NaturalTimeParserSampleCase(
            rawText: "Organize pills in the morning",
            expectedCleanedTitle: "Organize pills",
            expectedPreferredDayOfWeek: nil,
            expectedWindowLabel: "Morning",
            expectedEstimatedMinutes: nil
        ),
        NaturalTimeParserSampleCase(
            rawText: "Take out the trash on Thursday evening",
            expectedCleanedTitle: "Take out the trash",
            expectedPreferredDayOfWeek: 5,
            expectedWindowLabel: "Evening",
            expectedEstimatedMinutes: 7
        ),
        NaturalTimeParserSampleCase(
            rawText: "Pay electric bill tomorrow",
            expectedCleanedTitle: "Pay electric bill",
            expectedPreferredDayOfWeek: nil,
            expectedWindowLabel: nil,
            expectedEstimatedMinutes: 7
        ),
        NaturalTimeParserSampleCase(
            rawText: "Call dentist this week",
            expectedCleanedTitle: "Call dentist",
            expectedPreferredDayOfWeek: nil,
            expectedWindowLabel: nil,
            expectedEstimatedMinutes: 12
        ),
        NaturalTimeParserSampleCase(
            rawText: "Sunday afternoon",
            expectedCleanedTitle: "Untitled task",
            expectedPreferredDayOfWeek: 1,
            expectedWindowLabel: "Afternoon",
            expectedEstimatedMinutes: nil
        ),
        // New cases that exercise the parser improvements made in Phase 2.
        NaturalTimeParserSampleCase(
            rawText: "Read a little bit before bed",
            expectedCleanedTitle: "Read a little bit",
            expectedPreferredDayOfWeek: nil,
            expectedWindowLabel: "Before bed",
            expectedEstimatedMinutes: 15
        ),
        NaturalTimeParserSampleCase(
            rawText: "Spend some personal time at the park in the early evening",
            expectedCleanedTitle: "Spend some personal time at the park",
            expectedPreferredDayOfWeek: nil,
            expectedWindowLabel: "Early evening",
            expectedEstimatedMinutes: 67
        ),
        NaturalTimeParserSampleCase(
            rawText: "Give child a bath in the afternoon",
            expectedCleanedTitle: "Give child a bath",
            expectedPreferredDayOfWeek: nil,
            expectedWindowLabel: "Afternoon",
            expectedEstimatedMinutes: 25
        ),
        NaturalTimeParserSampleCase(
            rawText: "Go grocery shopping",
            expectedCleanedTitle: "Go grocery shopping",
            expectedPreferredDayOfWeek: nil,
            expectedWindowLabel: nil,
            expectedEstimatedMinutes: 52
        ),
        NaturalTimeParserSampleCase(
            rawText: "Have dinner ready by six",
            expectedCleanedTitle: "Have dinner ready",
            expectedPreferredDayOfWeek: nil,
            expectedWindowLabel: nil,
            expectedEstimatedMinutes: 45
        ),
        NaturalTimeParserSampleCase(
            rawText: "Clean up the kitchen tonight",
            expectedCleanedTitle: "Clean up the kitchen",
            expectedPreferredDayOfWeek: nil,
            expectedWindowLabel: "Evening",
            expectedEstimatedMinutes: 22
        ),
        NaturalTimeParserSampleCase(
            rawText: "Start laundry",
            expectedCleanedTitle: "Start laundry",
            expectedPreferredDayOfWeek: nil,
            expectedWindowLabel: nil,
            expectedEstimatedMinutes: 5
        )
    ]

    static func sampleValidationFailures(now: Date = Date()) -> [String] {
        sampleValidationCases.compactMap { sample in
            let parsed = parse(sample.rawText, now: now)
            guard parsed.cleanedTitle != sample.expectedCleanedTitle
                || parsed.preferredDayOfWeek != sample.expectedPreferredDayOfWeek
                || parsed.flexibleWindowLabel != sample.expectedWindowLabel
                || parsed.estimatedMinutes != sample.expectedEstimatedMinutes else {
                return nil
            }
            return "\(sample.rawText) parsed as title=\(parsed.cleanedTitle), weekday=\(String(describing: parsed.preferredDayOfWeek)), window=\(String(describing: parsed.flexibleWindowLabel)), minutes=\(String(describing: parsed.estimatedMinutes))"
        }
    }

    static func parse(
        _ rawText: String,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> NaturalTimeHint {
        let lowered = rawText.lowercased()
        let preferredDayOfWeek = weekday(in: lowered)
        let preferredDate = preferredDate(in: lowered, now: now, calendar: calendar)
        let flexibleWindowLabel = flexibleWindow(in: lowered)
        let recurrenceHint = recurrenceHint(in: lowered)
        let cleanedTitle = cleanTitle(from: rawText)
        let durationBand = inferredDurationBand(from: cleanedTitle.isEmpty ? rawText : cleanedTitle)
        let estimatedMinutes = explicitEstimatedMinutes(in: lowered)
            ?? durationBand?.midpoint

        // Deadline: "by 6", "by six", "by 6:00 pm", "before noon"
        let deadlineTime = deadline(in: lowered, basedOn: preferredDate ?? now, calendar: calendar)

        // Family / outdoor / child context cap
        let (cap, capReason) = endCap(for: lowered, calendar: calendar)

        // After-work / after-dinner earliest-start floor
        let earliestStart = earliestStartMinuteOfDay(in: lowered)

        return NaturalTimeHint(
            cleanedTitle: cleanedTitle.isEmpty ? "Untitled task" : cleanedTitle,
            preferredDate: preferredDate,
            preferredDayOfWeek: preferredDayOfWeek,
            flexibleWindowLabel: flexibleWindowLabel,
            estimatedMinutes: estimatedMinutes,
            recurrenceHint: recurrenceHint,
            isThisWeek: contains(#"\bthis\s+week\b"#, in: lowered),
            deadlineTime: deadlineTime,
            windowEndCap: cap,
            windowEndCapReason: capReason,
            durationLowerBoundMinutes: durationBand?.lower,
            durationUpperBoundMinutes: durationBand?.upper,
            earliestStartMinuteOfDay: earliestStart
        )
    }

    static func normalizedWindowLabel(_ label: String?) -> String? {
        guard let label else { return nil }
        let normalized = label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "morning", "this morning":
            return "Morning"
        case "afternoon", "this afternoon":
            return "Afternoon"
        case "late afternoon":
            return "Late afternoon"
        case "early evening":
            return "Early evening"
        case "evening", "evening window", "tonight", "night", "after dinner", "this evening":
            return "Evening"
        case "after work":
            return "After work"
        case "before bed", "bedtime":
            return "Before bed"
        case "today", "tomorrow", "this week":
            return nil
        default:
            return label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : label
        }
    }

    static func weekdayName(for weekday: Int) -> String? {
        weekdays.first { $0.value == weekday }?.displayName
    }

    private static let weekdays: [(name: String, displayName: String, value: Int)] = [
        ("sunday", "Sunday", 1),
        ("monday", "Monday", 2),
        ("tuesday", "Tuesday", 3),
        ("wednesday", "Wednesday", 4),
        ("thursday", "Thursday", 5),
        ("friday", "Friday", 6),
        ("saturday", "Saturday", 7)
    ]

    private static func weekday(in text: String) -> Int? {
        weekdays.first { contains(#"\b\#($0.name)\b"#, in: text) }?.value
    }

    private static func preferredDate(in text: String, now: Date, calendar: Calendar) -> Date? {
        let today = calendar.startOfDay(for: now)
        if contains(#"\btomorrow\b"#, in: text) {
            return calendar.date(byAdding: .day, value: 1, to: today)
        }
        if contains(#"\btoday\b"#, in: text)
            || contains(#"\bthis\s+morning\b"#, in: text)
            || contains(#"\btonight\b"#, in: text) {
            return today
        }
        return nil
    }

    private static func flexibleWindow(in text: String) -> String? {
        // Most specific phrases first.
        if contains(#"\bbefore\s+bed\b|\bbedtime\b"#, in: text) { return "Before bed" }
        if contains(#"\bafter\s+(?:daycare|school|work)\b"#, in: text) {
            // "after work" gets its own window; the others are late-afternoon.
            if contains(#"\bafter\s+work\b"#, in: text) { return "After work" }
            return "Late afternoon"
        }
        if contains(#"\blate\s+afternoon\b"#, in: text) { return "Late afternoon" }
        if contains(#"\bearly\s+evening\b"#, in: text) { return "Early evening" }
        if contains(#"\bafter\s+dinner\b"#, in: text) { return "Evening" }
        if contains(#"\btonight\b"#, in: text) { return "Evening" }
        if contains(#"\bevening\b|\bnight\b"#, in: text) { return "Evening" }
        if contains(#"\bafternoon\b"#, in: text) { return "Afternoon" }
        if contains(#"\bmorning\b"#, in: text) { return "Morning" }
        return nil
    }

    private static func explicitEstimatedMinutes(in text: String) -> Int? {
        if let hours = firstInt(from: text, pattern: #"\b(\d+)\s*(?:hours?|hrs?|hr)\b"#) {
            return max(1, hours * 60)
        }
        if let minutes = firstInt(from: text, pattern: #"\b(\d+)\s*(?:minutes?|mins?|min)\b"#) {
            return max(1, minutes)
        }
        return nil
    }

    /// A duration band matched against task content. Returns lower / upper / midpoint.
    /// We bias toward realism: short tasks stay short, long tasks aren't padded.
    static func inferredDurationBand(from text: String) -> DurationBand? {
        let lowered = text.lowercased()

        // Trash / dishes / very small chores
        if contains(#"\btake\s+out\s+(?:the\s+)?trash\b|\btrash\b"#, in: lowered) {
            return DurationBand(lower: 5, upper: 10)
        }
        if contains(#"\b(?:put\s+away|stack|load)\s+(?:the\s+)?dish(es)?\b"#, in: lowered) {
            return DurationBand(lower: 5, upper: 10)
        }
        if contains(#"\bstart\s+(?:a\s+|the\s+)?laundry\b|\bthrow\s+in\s+(?:a\s+)?load\b"#, in: lowered) {
            return DurationBand(lower: 5, upper: 5)
        }
        // Calls and quick admin
        if contains(#"\b(?:call|phone|ring|text|message)\s+(?:the\s+)?(?:dentist|doctor|vet)\b"#, in: lowered) {
            return DurationBand(lower: 10, upper: 15)
        }
        if contains(#"\b(?:call|phone|ring)\b"#, in: lowered) {
            return DurationBand(lower: 5, upper: 15)
        }
        if contains(#"\bpay\s+(?:the\s+)?(?:.+?\s+)?bill\b|\bpay\s+bills?\b"#, in: lowered) {
            return DurationBand(lower: 5, upper: 10)
        }
        // Reading
        if contains(#"\bread\s+(?:a\s+)?(?:little|bit|while|book|chapter)\b|\bread\s+before\s+bed\b"#, in: lowered) {
            return DurationBand(lower: 10, upper: 20)
        }
        if contains(#"\bread\b"#, in: lowered) {
            return DurationBand(lower: 10, upper: 30)
        }
        // Bath / kids
        if contains(#"\b(?:give|do)\s+(?:.+?\s+)?(?:a\s+)?bath\b|\bbathe\b"#, in: lowered) {
            return DurationBand(lower: 20, upper: 30)
        }
        // Errands
        if contains(#"\bgrocery\s+shop|\bgo\s+grocery|\bgroceries\b|\bgrocery\s+shopping\b"#, in: lowered) {
            return DurationBand(lower: 45, upper: 60)
        }
        if contains(#"\bpick\s+up\s+(?:the\s+)?groceries|\bpick\s+up\s+kids?\b"#, in: lowered) {
            return DurationBand(lower: 30, upper: 45)
        }
        // Park / outdoor / family activities
        if contains(#"\b(?:go\s+to\s+the\s+|at\s+the\s+|spend\s+time\s+at\s+the\s+)park\b|\bplayground\b"#, in: lowered) {
            return DurationBand(lower: 45, upper: 90)
        }
        if contains(#"\b(?:walk|take\s+a\s+walk|go\s+for\s+a\s+walk)\b"#, in: lowered) {
            return DurationBand(lower: 20, upper: 45)
        }
        // Cooking / dinner. "have dinner ready" / "dinner by six" are deadline-
        // style phrases — we still want a realistic prep duration band.
        if contains(#"\b(?:prepare|prep|make|cook|have)\s+(?:.+?\s+)?dinner\b|\bdinner\s+ready\b"#, in: lowered) {
            return DurationBand(lower: 30, upper: 60)
        }
        if contains(#"\b(?:prepare|prep|make|cook)\s+(?:lunch|breakfast)\b"#, in: lowered) {
            return DurationBand(lower: 15, upper: 30)
        }
        // Cleaning
        if contains(#"\bgeneral\s+cleaning\b|\bclean(?:\s+up)?\s+(?:the\s+)?house\b"#, in: lowered) {
            return DurationBand(lower: 30, upper: 60)
        }
        if contains(#"\bclean(?:\s+up)?\s+(?:the\s+)?kitchen\b|\bkitchen\s+reset\b|\btidy\s+(?:the\s+)?kitchen\b"#, in: lowered) {
            return DurationBand(lower: 15, upper: 30)
        }
        if contains(#"\b(?:clean|tidy|organize)\b"#, in: lowered) {
            return DurationBand(lower: 15, upper: 45)
        }
        // Generic "quick" / "small"
        if contains(#"\bquick\b|\bsmall\b|\btiny\b"#, in: lowered) {
            return DurationBand(lower: 5, upper: 10)
        }
        return nil
    }

    /// Detects "by 6", "by six", "by 6:00 pm", "by noon", "before 7", "before noon".
    /// Returns an absolute Date on the day implied by `basedOn`.
    private static func deadline(in text: String, basedOn day: Date, calendar: Calendar) -> Date? {
        if contains(#"\bby\s+noon\b|\bbefore\s+noon\b"#, in: text) {
            return calendar.date(bySettingHour: 12, minute: 0, second: 0, of: day)
        }
        if contains(#"\bby\s+midnight\b"#, in: text) {
            return calendar.date(bySettingHour: 23, minute: 59, second: 0, of: day)
        }

        // Numeric: "by 6", "by 6:30", "by 6 pm", "by 6:30pm", "by 18:30"
        let numericPattern = #"\b(?:by|before)\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\b"#
        if let match = firstMatchGroups(text: text, pattern: numericPattern) {
            let hour = Int(match[1] ?? "0") ?? 0
            let minute = Int(match[2] ?? "0") ?? 0
            let meridiem = match[3]?.lowercased()
            if let resolved = resolveHour(hour: hour, minute: minute, meridiem: meridiem) {
                return calendar.date(bySettingHour: resolved.hour, minute: resolved.minute, second: 0, of: day)
            }
        }

        // Word-numeral: "by six", "by seven", "by eight" — interpret as PM if no daypart.
        let wordToHour: [String: Int] = [
            "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10, "five": 5
        ]
        for (word, hr) in wordToHour {
            if contains(#"\b(?:by|before)\s+\#(word)\b"#, in: text) {
                // A bare "by six" almost always means 6 PM in conversational planning
                // (food/dinner deadlines, pickup times, evening cutoffs).
                let pmHour = hr < 12 ? hr + 12 : hr
                return calendar.date(bySettingHour: pmHour, minute: 0, second: 0, of: day)
            }
        }
        return nil
    }

    /// Soft cap on how late a task can be scheduled. Returns hour:minute as
    /// DateComponents and a human-readable reason.
    private static func endCap(for text: String, calendar: Calendar) -> (DateComponents?, String?) {
        // Family / child context stays before the evening cutoff.
        let familyPattern = #"\b(?:kiddo|kids?|baby|toddler|child|with\s+(?:my\s+)?(?:daughter|son|kid))\b"#
        if contains(familyPattern, in: text) {
            return (DateComponents(hour: 19, minute: 30), "child / family activity stays before 7:30 PM")
        }
        // Outdoor activity defaults
        if contains(#"\b(?:park|playground|trail|hike|walk\s+the\s+dog)\b"#, in: text) {
            return (DateComponents(hour: 19, minute: 30), "outdoor activity stays before 7:30 PM")
        }
        // Errand / store hours
        if contains(#"\b(?:grocery|groceries|store|mall|errand|shopping|pharmacy|target|costco)\b"#, in: text) {
            return (DateComponents(hour: 20, minute: 0), "errands stay before 8 PM")
        }
        return (nil, nil)
    }

    /// Earliest minute-of-day a task can start, based on natural cues.
    /// "after work" → 17:00 → 17*60 = 1020. "after dinner" → 18:30 → 1110.
    private static func earliestStartMinuteOfDay(in text: String) -> Int? {
        if contains(#"\bafter\s+work\b"#, in: text) { return 17 * 60 }
        if contains(#"\bafter\s+dinner\b"#, in: text) { return 18 * 60 + 30 }
        if contains(#"\bafter\s+(?:daycare|school)\b"#, in: text) { return 16 * 60 }
        if contains(#"\bearly\s+evening\b"#, in: text) { return 16 * 60 + 30 }
        return nil
    }

    /// 12/24-hour sanity-check.
    private static func resolveHour(hour: Int, minute: Int, meridiem: String?) -> (hour: Int, minute: Int)? {
        guard (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        if let m = meridiem {
            let h12 = hour % 12
            return (m == "pm" ? h12 + 12 : h12, minute)
        }
        // No meridiem: bare 1-7 → assume PM (conversational); 8-11 → AM; 12+ → as-is
        if hour >= 12 { return (hour, minute) }
        if hour <= 7 { return (hour + 12, minute) }
        return (hour, minute)
    }

    private static func firstMatchGroups(text: String, pattern: String) -> [String?]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range) else { return nil }
        var groups: [String?] = []
        for i in 0..<match.numberOfRanges {
            if let r = Range(match.range(at: i), in: text) {
                groups.append(String(text[r]))
            } else {
                groups.append(nil)
            }
        }
        return groups
    }

    private static func recurrenceHint(in text: String) -> String? {
        if contains(#"\bevery\s+day\b|\bdaily\b"#, in: text) { return "daily" }
        if contains(#"\bevery\s+week\b|\bweekly\b"#, in: text) { return "weekly" }
        if let weekday = weekday(in: text), contains(#"\bevery\s+(sunday|monday|tuesday|wednesday|thursday|friday|saturday)\b"#, in: text) {
            return "weekly:\(NaturalTimeParser.weekdayName(for: weekday) ?? "weekday")"
        }
        return nil
    }

    private static func cleanTitle(from rawText: String) -> String {
        var cleaned = rawText
        let weekdayList = weekdays.map(\.name).joined(separator: "|")
        let cleanupPatterns = [
            #"\bfor\s+\d+\s*(?:minutes?|mins?|min|hours?|hrs?|hr)\b"#,
            #"\b\d+\s*(?:minutes?|mins?|min|hours?|hrs?|hr)\b"#,
            #"\bthis\s+week\b"#,
            #"\btomorrow\b"#,
            #"\btoday\b"#,
            #"\btonight\b"#,
            #"\bevery\s+(?:day|week|morning|night|sunday|monday|tuesday|wednesday|thursday|friday|saturday)\b"#,
            #"\bdaily\b|\bweekly\b"#,
            #"\b(?:on\s+)?(?:\#(weekdayList))(?:\s+(?:morning|afternoon|evening|night))?\b"#,
            #"\b(?:in\s+the\s+|in\s+|during\s+the\s+|during\s+)?(?:this\s+)?(?:early\s+|late\s+)?(?:morning|afternoon|evening)\b"#,
            #"\b(?:after\s+work|after\s+dinner|after\s+daycare|after\s+school|before\s+bed|bedtime)\b"#,
            #"\bnight\b"#,
            // Deadline phrases — strip from titles, scheduler reads them separately.
            #"\b(?:by|before)\s+(?:noon|midnight|\d{1,2}(?::\d{2})?\s*(?:am|pm)?|six|seven|eight|nine|ten|five)\b"#
        ]

        for pattern in cleanupPatterns {
            cleaned = cleaned.replacingOccurrences(
                of: pattern,
                with: " ",
                options: [.regularExpression, .caseInsensitive]
            )
        }

        cleaned = cleaned.replacingOccurrences(
            of: #"\b(?:on|in|during|at|by|for)\s*$"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        cleaned = cleaned.replacingOccurrences(
            of: #"\s{2,}"#,
            with: " ",
            options: .regularExpression
        )
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ".!,;:-")))

        guard !cleaned.isEmpty else { return "" }
        return cleaned.prefix(1).uppercased() + cleaned.dropFirst()
    }

    private static func contains(_ pattern: String, in text: String) -> Bool {
        text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private static func firstInt(from text: String, pattern: String) -> Int? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              match.numberOfRanges > 1,
              let swiftRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return Int(text[swiftRange])
    }
}
