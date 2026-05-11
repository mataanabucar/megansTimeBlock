import Foundation

struct AIParsingContext: Codable {
    var currentDate: Date
    var timezone: String
    var locale: String
    var planningDay: ScheduleRange
    var planningStyle: PlanningStyle
    var userPreferences: AIPlanningPreferencesSnapshot
    var existingTasks: [AIParsingTaskContextSnapshot]
    var existingScheduleBlocks: [AIParsingBlockContextSnapshot]

    init(
        currentDate: Date = Date(),
        timezone: String = TimeZone.current.identifier,
        locale: String = Locale.current.identifier,
        planningDay: ScheduleRange = .today,
        planningStyle: PlanningStyle = .balancedDay,
        preferences: UserPlanningPreferences,
        existingTasks: [TaskItem],
        existingScheduleBlocks: [ScheduleBlock]
    ) {
        self.currentDate = currentDate
        self.timezone = timezone
        self.locale = locale
        self.planningDay = planningDay
        self.planningStyle = planningStyle
        self.userPreferences = AIPlanningPreferencesSnapshot(preferences: preferences)
        self.existingTasks = existingTasks.map(AIParsingTaskContextSnapshot.init(task:))
        self.existingScheduleBlocks = existingScheduleBlocks.map(AIParsingBlockContextSnapshot.init(block:))
    }
}

struct AIParsingTaskContextSnapshot: Codable, Identifiable {
    var id: UUID
    var estimatedMinutes: Int
    var dueDate: Date?
    var flexibleWindow: String?
    var status: TaskStatus
}

struct AIParsingBlockContextSnapshot: Codable, Identifiable {
    var id: UUID
    var startTime: Date
    var endTime: Date
    var flexibleWindowLabel: String
    var status: BlockStatus
}

struct AITaskParseRequest: Encodable {
    var rawText: String
    var currentDate: Date
    var timezone: String
    var locale: String
    var planningDay: ScheduleRange
    var planningStyle: PlanningStyle
    var wakeTime: Date
    var sleepTime: Date
    var preferredReminderBehavior: ReminderStyle
    var defaultTaskDuration: Int
    var existingTasks: [AIParsingTaskContextSnapshot]
    var existingScheduleBlocks: [AIParsingBlockContextSnapshot]
    var context: AIParsingContext

    init(rawText: String, context: AIParsingContext) {
        self.rawText = rawText
        self.currentDate = context.currentDate
        self.timezone = context.timezone
        self.locale = context.locale
        self.planningDay = context.planningDay
        self.planningStyle = context.planningStyle
        self.wakeTime = context.userPreferences.wakeTime
        self.sleepTime = context.userPreferences.sleepTime
        self.preferredReminderBehavior = context.userPreferences.defaultReminderStyle
        self.defaultTaskDuration = context.userPreferences.defaultTaskDuration
        self.existingTasks = context.existingTasks
        self.existingScheduleBlocks = context.existingScheduleBlocks
        self.context = context
    }
}

typealias ParseTaskRequest = AITaskParseRequest

extension AIParsingTaskContextSnapshot {
    init(task: TaskItem) {
        self.id = task.id
        self.estimatedMinutes = task.estimatedMinutes
        self.dueDate = task.dueDate
        self.flexibleWindow = task.flexibleWindow
        self.status = task.status
    }
}

extension AIParsingBlockContextSnapshot {
    init(block: ScheduleBlock) {
        self.id = block.id
        self.startTime = block.startTime
        self.endTime = block.endTime
        self.flexibleWindowLabel = block.flexibleWindowLabel
        self.status = block.status
    }
}

struct AITaskParseResponse: Decodable {
    var tasks: [AITaskCandidate]
    var warnings: [AIParseWarning]
    var friendlySummary: String
    var needsReview: Bool
}

struct AITaskCandidate: Decodable, Hashable, Identifiable {
    var rawText: String
    var title: String
    var notes: String?
    var dueDate: Date?
    var startDate: Date?
    var startTime: Date?
    var durationMinutes: Int
    /// Lower bound of the inferred duration band (e.g. 5 for "take out trash").
    /// Optional because older parser responses won't have it.
    var durationLowerMinutes: Int?
    /// Upper bound of the inferred duration band (e.g. 10 for "take out trash").
    var durationUpperMinutes: Int?
    var priority: PriorityLevel
    var category: TaskCategory
    var reminderPreference: ReminderStyle?
    var recurrence: String?
    var confidence: Double
    var clarificationNeeded: Bool
    var tinyStep: String?
    var shrinkOptions: [String]
    /// Natural-language flexible window — Morning / Afternoon / Late afternoon /
    /// Early evening / After work / Evening / Before bed. The preview renders
    /// this combined with the date (e.g. "Tomorrow evening").
    var flexibleWindow: String?
    /// Energy hint surfaced from the parser.
    var energyLevel: EnergyLevel?

    var id: String {
        [
            rawText,
            title,
            dueDate?.ISO8601Format() ?? "",
            startDate?.ISO8601Format() ?? "",
            startTime?.ISO8601Format() ?? ""
        ].joined(separator: "|")
    }

    /// Legacy single-line description. Kept for compatibility with any older
    /// callers; new UI should use `formattedScheduleText` instead.
    var whenDescription: String {
        formattedScheduleText
    }

    // MARK: - Formatting helpers used by the AI Preview card

    /// Natural phrasing combining date and window. Examples:
    /// "Tomorrow evening" — preferredDate=tomorrow + window=Evening
    /// "This afternoon" — preferredDate=today + window=Afternoon
    /// "Tomorrow" — date only
    /// "Evening" — window only
    /// "Today, around 8:00 PM" — explicit startTime
    /// "Anytime" — nothing usable
    var formattedScheduleText: String {
        let calendar = Calendar.current
        let candidateDate = dueDate ?? startDate ?? startTime
        let normalizedWindow = NaturalTimeParser.normalizedWindowLabel(flexibleWindow)

        let datePart: String? = candidateDate.flatMap { date in
            if calendar.isDateInToday(date) {
                return normalizedWindow != nil ? "This" : "Today"
            } else if calendar.isDateInTomorrow(date) {
                return "Tomorrow"
            } else {
                return DateFormatting.shortDate.string(from: date)
            }
        }
        let windowPart: String? = normalizedWindow.map { window in
            // "This morning" / "This afternoon" / "Tomorrow evening" — all lowercase suffix.
            window.lowercased()
        }

        // Explicit clock time wins when present.
        if let candidateDate, let _ = startTime {
            let timeStr = DateFormatting.shortTime.string(from: candidateDate)
            if let datePart {
                return "\(datePart), around \(timeStr)"
            }
            return "Around \(timeStr)"
        }

        switch (datePart, windowPart) {
        case let (date?, window?):
            return "\(date) \(window)"
        case let (date?, nil):
            return date
        case let (nil, window?):
            // Capitalize the first letter when window stands alone.
            return window.prefix(1).uppercased() + window.dropFirst()
        case (nil, nil):
            return "Anytime"
        }
    }

    /// "5 to 10 min" / "45 min" / "1 hr 30 min" — uses the duration band when
    /// available, falls back to the single midpoint.
    var formattedDurationText: String {
        if let lo = durationLowerMinutes, let hi = durationUpperMinutes, lo != hi {
            return "\(lo) to \(hi) min"
        }
        let m = max(1, durationMinutes)
        if m >= 60 {
            let hours = m / 60
            let rest = m % 60
            return rest == 0 ? "\(hours) hr" : "\(hours) hr \(rest) min"
        }
        return "\(m) min"
    }

    var formattedCategoryText: String {
        category.title
    }

    var formattedEnergyText: String? {
        guard let energyLevel else { return nil }
        return "\(energyLevel.title) energy".replacingOccurrences(of: " energy energy", with: " energy")
    }

    /// Subtle text for the AI Preview card. Returns:
    /// - "May need review" when clarificationNeeded
    /// - "Lower confidence" for confidence < 0.55
    /// - "Looks good" otherwise (caller may choose to hide this)
    var formattedConfidenceText: String {
        if clarificationNeeded { return "May need review" }
        if confidence < 0.55 { return "Lower confidence" }
        return "Looks good"
    }

    /// Whether to draw attention to the confidence/review state. Used to
    /// decide if a callout banner should appear.
    var needsReviewCallout: Bool {
        clarificationNeeded || confidence < 0.55
    }

    func makeTaskItem(source: CaptureSource = .typed, createdAt: Date = Date()) -> TaskItem {
        // Window label is the primary `flexibleWindow` on TaskItem so the
        // scheduler / Today view group it correctly. We do NOT stuff a clock
        // time string into that field anymore.
        let resolvedWindow = NaturalTimeParser.normalizedWindowLabel(flexibleWindow)
        return TaskItem(
            rawText: rawText,
            title: title,
            notes: notes ?? "",
            category: category,
            priority: priority,
            energyLevel: energyLevel ?? (durationMinutes <= 10 ? .low : .any),
            estimatedMinutes: max(1, durationMinutes),
            dueDate: dueDate ?? startDate ?? startTime,
            flexibleWindow: resolvedWindow,
            isRecurring: recurrence?.nilIfBlank != nil,
            recurrenceRule: recurrence,
            source: source,
            suggestedTinyStep: tinyStep,
            shrinkOptions: shrinkOptions,
            createdAt: createdAt,
            updatedAt: createdAt
        )
    }
}

struct AIParseWarning: Decodable, Hashable, Identifiable {
    var code: String
    var message: String
    var taskTitle: String?

    var id: String {
        [code, taskTitle ?? "", message].joined(separator: "|")
    }
}
