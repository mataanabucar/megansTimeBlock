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
        isRecurring: Bool = false,
        recurrenceRule: String? = nil,
        status: TaskStatus = .inbox,
        source: CaptureSource = .typed,
        suggestedTinyStep: String? = nil,
        shrinkOptions: [String]? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.rawText = rawText
        self.title = title ?? Self.makeTitle(from: rawText)
        self.notes = notes
        self.categoryRawValue = category.rawValue
        self.priorityRawValue = priority.rawValue
        self.energyLevelRawValue = energyLevel.rawValue
        self.estimatedMinutes = max(1, estimatedMinutes)
        self.dueDate = dueDate
        self.flexibleWindow = flexibleWindow
        self.isRecurring = isRecurring
        self.recurrenceRule = recurrenceRule
        self.statusRawValue = status.rawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sourceRawValue = source.rawValue
        self.suggestedTinyStep = suggestedTinyStep ?? Self.makeTinyStep(from: rawText)
        self.shrinkOptionsRawValue = (shrinkOptions ?? Self.makeShrinkOptions(from: rawText, estimatedMinutes: estimatedMinutes))
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
