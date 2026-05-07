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
    var preferredWindowRawValue: String?
    var isRecurring: Bool
    var recurrenceRule: String?
    var statusRawValue: String
    var createdAt: Date
    var updatedAt: Date
    var sourceRawValue: String
    var suggestedTinyStep: String
    var shrinkOptionsRawValue: String
    var aiConfidence: Double = 0
    var aiFriendlyNote: String?
    var canScheduleToday: Bool = true
    var canScheduleThisWeek: Bool = true
    var mustRespectDate: Bool = false
    var mustRespectDay: Bool = false
    var mustRespectWindow: Bool = false
    var allowFlexiblePlacement: Bool = true

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
        preferredWindow: FlexibleWindow? = nil,
        isRecurring: Bool = false,
        recurrenceRule: String? = nil,
        status: TaskStatus = .inbox,
        source: CaptureSource = .typed,
        suggestedTinyStep: String? = nil,
        shrinkOptions: [String]? = nil,
        aiConfidence: Double = 0,
        aiFriendlyNote: String? = nil,
        canScheduleToday: Bool? = nil,
        canScheduleThisWeek: Bool? = nil,
        mustRespectDate: Bool? = nil,
        mustRespectDay: Bool? = nil,
        mustRespectWindow: Bool? = nil,
        allowFlexiblePlacement: Bool? = nil,
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
        let resolvedWindow = preferredWindow ?? naturalTime.preferredWindow
        self.flexibleWindow = flexibleWindow ?? resolvedWindow?.title ?? naturalTime.flexibleWindowLabel
        self.preferredDayOfWeek = preferredDayOfWeek ?? naturalTime.preferredDayOfWeek?.calendarWeekday
        self.preferredWindowRawValue = resolvedWindow?.rawValue
        self.isRecurring = isRecurring || naturalTime.recurrenceHint != nil
        self.recurrenceRule = recurrenceRule ?? naturalTime.recurrenceHint
        self.statusRawValue = status.rawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sourceRawValue = source.rawValue
        self.suggestedTinyStep = suggestedTinyStep ?? Self.makeTinyStep(from: rawText)
        self.shrinkOptionsRawValue = (shrinkOptions ?? Self.makeShrinkOptions(from: rawText, estimatedMinutes: resolvedEstimatedMinutes))
            .joined(separator: "\n")
        self.aiConfidence = min(max(aiConfidence, 0), 1)
        self.aiFriendlyNote = aiFriendlyNote
        self.canScheduleToday = canScheduleToday ?? naturalTime.canScheduleToday
        self.canScheduleThisWeek = canScheduleThisWeek ?? naturalTime.canScheduleThisWeek
        self.mustRespectDate = mustRespectDate ?? naturalTime.mustRespectDate
        self.mustRespectDay = mustRespectDay ?? naturalTime.mustRespectDay
        self.mustRespectWindow = mustRespectWindow ?? naturalTime.mustRespectWindow
        self.allowFlexiblePlacement = allowFlexiblePlacement ?? naturalTime.allowFlexiblePlacement
    }

    var category: TaskCategory {
        get { TaskCategory.fromStorage(categoryRawValue) }
        set {
            categoryRawValue = newValue.rawValue
            touch()
        }
    }

    var priority: PriorityLevel {
        get { PriorityLevel.fromStorage(priorityRawValue) }
        set {
            priorityRawValue = newValue.rawValue
            touch()
        }
    }

    var energyLevel: EnergyLevel {
        get { EnergyLevel.fromStorage(energyLevelRawValue) }
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

    var preferredWeekday: Weekday? {
        get {
            guard let preferredDayOfWeek else { return nil }
            return Weekday(calendarWeekday: preferredDayOfWeek)
        }
        set {
            preferredDayOfWeek = newValue?.calendarWeekday
            touch()
        }
    }

    var preferredWindow: FlexibleWindow? {
        get {
            if let preferredWindowRawValue, let stored = FlexibleWindow(rawValue: preferredWindowRawValue) {
                return stored
            }
            return FlexibleWindow.fromLegacyLabel(flexibleWindow)
        }
        set {
            preferredWindowRawValue = newValue?.rawValue
            if flexibleWindow?.nilIfBlank == nil || FlexibleWindow.fromLegacyLabel(flexibleWindow) != nil {
                flexibleWindow = newValue?.title
            }
            touch()
        }
    }

    var timingSummary: String? {
        var parts: [String] = []
        if let dueDate {
            if Calendar.current.isDateInToday(dueDate) {
                parts.append("Today")
            } else if Calendar.current.isDateInTomorrow(dueDate) {
                parts.append("Tomorrow")
            } else {
                parts.append(DateFormatting.shortDate.string(from: dueDate))
            }
        } else if let preferredWeekday {
            parts.append(preferredWeekday.title)
        }

        if let preferredWindow {
            parts.append(preferredWindow.title)
        } else if let flexibleWindow = flexibleWindow?.nilIfBlank {
            parts.append(flexibleWindow)
        }

        return parts.isEmpty ? nil : parts.joined(separator: " ")
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

        let smallMinutes = min(max(estimatedMinutes / 2, 3), 10)
        return [
            "Do the first visible step, 3 min",
            "Set a \(smallMinutes)-minute timer",
            "Prepare what you need, 5 min"
        ]
    }
}

struct NaturalTimeHint: Equatable {
    var cleanedTitle: String
    var preferredDate: Date?
    var preferredDayOfWeek: Weekday?
    var preferredWindow: FlexibleWindow?
    var flexibleWindowLabel: String?
    var estimatedMinutes: Int?
    var recurrenceHint: String?
    var isThisWeek: Bool
    var canScheduleToday: Bool
    var canScheduleThisWeek: Bool
    var mustRespectDate: Bool
    var mustRespectDay: Bool
    var mustRespectWindow: Bool
    var allowFlexiblePlacement: Bool
}

struct NaturalTimeParserSampleCase: Identifiable {
    let id = UUID()
    var rawText: String
    var expectedCleanedTitle: String
    var expectedPreferredDayOfWeek: Weekday?
    var expectedWindow: FlexibleWindow?
    var expectedEstimatedMinutes: Int?
}

enum NaturalTimeParser {
    static let sampleValidationCases: [NaturalTimeParserSampleCase] = [
        NaturalTimeParserSampleCase(
            rawText: "Organize pills in the morning",
            expectedCleanedTitle: "Organize pills",
            expectedPreferredDayOfWeek: nil,
            expectedWindow: .morning,
            expectedEstimatedMinutes: nil
        ),
        NaturalTimeParserSampleCase(
            rawText: "Take out the trash on Thursday evening",
            expectedCleanedTitle: "Take out the trash",
            expectedPreferredDayOfWeek: .thursday,
            expectedWindow: .evening,
            expectedEstimatedMinutes: 10
        ),
        NaturalTimeParserSampleCase(
            rawText: "Pay electric bill tomorrow",
            expectedCleanedTitle: "Pay electric bill",
            expectedPreferredDayOfWeek: nil,
            expectedWindow: nil,
            expectedEstimatedMinutes: nil
        ),
        NaturalTimeParserSampleCase(
            rawText: "Call dentist this week",
            expectedCleanedTitle: "Call dentist",
            expectedPreferredDayOfWeek: nil,
            expectedWindow: nil,
            expectedEstimatedMinutes: 10
        ),
        NaturalTimeParserSampleCase(
            rawText: "Sunday afternoon",
            expectedCleanedTitle: "Untitled task",
            expectedPreferredDayOfWeek: .sunday,
            expectedWindow: .afternoon,
            expectedEstimatedMinutes: nil
        )
    ]

    static func sampleValidationFailures(now: Date = Date()) -> [String] {
        sampleValidationCases.compactMap { sample in
            let parsed = parse(sample.rawText, now: now)
            guard parsed.cleanedTitle != sample.expectedCleanedTitle
                || parsed.preferredDayOfWeek != sample.expectedPreferredDayOfWeek
                || parsed.preferredWindow != sample.expectedWindow
                || parsed.estimatedMinutes != sample.expectedEstimatedMinutes else {
                return nil
            }
            return "\(sample.rawText) parsed as title=\(parsed.cleanedTitle), weekday=\(String(describing: parsed.preferredDayOfWeek)), window=\(String(describing: parsed.preferredWindow)), minutes=\(String(describing: parsed.estimatedMinutes))"
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
        let preferredWindow = flexibleWindow(in: lowered)
        let recurrenceHint = recurrenceHint(in: lowered)
        let cleanedTitle = cleanTitle(from: rawText)
        let estimatedMinutes = explicitEstimatedMinutes(in: lowered)
            ?? inferredEstimatedMinutes(from: cleanedTitle.isEmpty ? rawText : cleanedTitle)
        let hasRelativeWeek = contains(#"\bthis\s+week\b"#, in: lowered)
        let mustRespectDate = preferredDate != nil
        let mustRespectDay = preferredDayOfWeek != nil
        let mustRespectWindow = preferredWindow != nil
        let canScheduleThisWeek = hasRelativeWeek || preferredDate != nil || preferredDayOfWeek != nil || recurrenceHint != nil || (!mustRespectDate && !mustRespectDay)
        let canScheduleToday: Bool
        if let preferredDate {
            canScheduleToday = calendar.isDate(preferredDate, inSameDayAs: now)
        } else if let preferredDayOfWeek {
            canScheduleToday = preferredDayOfWeek.calendarWeekday == calendar.component(.weekday, from: now)
        } else {
            canScheduleToday = true
        }

        return NaturalTimeHint(
            cleanedTitle: cleanedTitle.isEmpty ? "Untitled task" : cleanedTitle,
            preferredDate: preferredDate,
            preferredDayOfWeek: preferredDayOfWeek,
            preferredWindow: preferredWindow,
            flexibleWindowLabel: preferredWindow?.title,
            estimatedMinutes: estimatedMinutes,
            recurrenceHint: recurrenceHint,
            isThisWeek: hasRelativeWeek,
            canScheduleToday: canScheduleToday,
            canScheduleThisWeek: canScheduleThisWeek,
            mustRespectDate: mustRespectDate,
            mustRespectDay: mustRespectDay,
            mustRespectWindow: mustRespectWindow,
            allowFlexiblePlacement: !(mustRespectDate || mustRespectDay || mustRespectWindow)
        )
    }

    static func normalizedWindow(_ label: String?) -> FlexibleWindow? {
        FlexibleWindow.fromLegacyLabel(label)
    }

    static func normalizedWindowLabel(_ label: String?) -> String? {
        normalizedWindow(label)?.title
    }

    static func weekdayName(for weekday: Int) -> String? {
        Weekday(calendarWeekday: weekday)?.title
    }

    private static let weekdays: [(name: String, day: Weekday)] = [
        ("sunday", .sunday),
        ("monday", .monday),
        ("tuesday", .tuesday),
        ("wednesday", .wednesday),
        ("thursday", .thursday),
        ("friday", .friday),
        ("saturday", .saturday)
    ]

    private static func weekday(in text: String) -> Weekday? {
        weekdays.first { contains(#"\b\#($0.name)\b"#, in: text) }?.day
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

    private static func flexibleWindow(in text: String) -> FlexibleWindow? {
        if contains(#"\bbefore\s+bed\b|\bbedtime\b"#, in: text) { return .beforeBed }
        if contains(#"\bafter\s+work\b"#, in: text) { return .afterWork }
        if contains(#"\bafter\s+dinner\b"#, in: text) { return .evening }
        if contains(#"\btonight\b|\bevening\b|\bnight\b"#, in: text) { return .evening }
        if contains(#"\bafternoon\b"#, in: text) { return .afternoon }
        if contains(#"\bmidday\b|\bnoon\b|\blunch\b"#, in: text) { return .midday }
        if contains(#"\bmorning\b"#, in: text) { return .morning }
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

    private static func inferredEstimatedMinutes(from text: String) -> Int? {
        let lowered = text.lowercased()
        if contains(#"\btake\s+out\s+(?:the\s+)?trash\b|\btrash\b"#, in: lowered) { return 10 }
        if contains(#"\bcall\b|\bphone\b"#, in: lowered) { return 10 }
        if contains(#"\bquick\b|\bsmall\b"#, in: lowered) { return 5 }
        return nil
    }

    private static func recurrenceHint(in text: String) -> String? {
        if contains(#"\bevery\s+day\b|\bdaily\b"#, in: text) { return "daily" }
        if contains(#"\bevery\s+week\b|\bweekly\b"#, in: text) { return "weekly" }
        if let weekday = weekday(in: text), contains(#"\bevery\s+(sunday|monday|tuesday|wednesday|thursday|friday|saturday)\b"#, in: text) {
            return "weekly:\(weekday.title)"
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
            #"\b(?:in\s+the\s+|in\s+|during\s+the\s+|during\s+)?(?:this\s+)?(?:morning|afternoon|evening)\b"#,
            #"\b(?:after\s+work|after\s+dinner|before\s+bed|bedtime)\b"#,
            #"\bnight\b"#
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
