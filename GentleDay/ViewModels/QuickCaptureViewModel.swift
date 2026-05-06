import Foundation
import Observation

struct QuickCaptureChip: Identifiable, Hashable {
    let id: String
    let title: String
    let category: TaskCategory?
    let minutes: Int?
    let dueDateOffset: Int?
    let flexibleWindow: String?

    init(
        title: String,
        category: TaskCategory? = nil,
        minutes: Int? = nil,
        dueDateOffset: Int? = nil,
        flexibleWindow: String? = nil
    ) {
        self.id = title
        self.title = title
        self.category = category
        self.minutes = minutes
        self.dueDateOffset = dueDateOffset
        self.flexibleWindow = flexibleWindow
    }

    static let defaults: [QuickCaptureChip] = [
        QuickCaptureChip(title: "Today", dueDateOffset: 0, flexibleWindow: "Today"),
        QuickCaptureChip(title: "Tomorrow", dueDateOffset: 1, flexibleWindow: "Tomorrow"),
        QuickCaptureChip(title: "This Week", dueDateOffset: 6, flexibleWindow: "This week"),
        QuickCaptureChip(title: "Home", category: .home),
        QuickCaptureChip(title: "Errand", category: .errand),
        QuickCaptureChip(title: "Family", category: .family),
        QuickCaptureChip(title: "Money", category: .money),
        QuickCaptureChip(title: "Appointment", category: .appointment),
        QuickCaptureChip(title: "Cleaning", category: .cleaning),
        QuickCaptureChip(title: "5 min", minutes: 5),
        QuickCaptureChip(title: "15 min", minutes: 15),
        QuickCaptureChip(title: "30 min", minutes: 30),
        QuickCaptureChip(title: "1 hour", minutes: 60)
    ]
}

@MainActor
@Observable
final class QuickCaptureViewModel {
    var rawText = ""
    var selectedChips: Set<QuickCaptureChip> = []
    var source: CaptureSource = .typed
    var voicePlaceholderMessage: String?

    var canSave: Bool {
        !rawText.trimmedForStorage.isEmpty
    }

    func toggle(_ chip: QuickCaptureChip) {
        if selectedChips.contains(chip) {
            selectedChips.remove(chip)
        } else {
            selectedChips.insert(chip)
        }
    }

    func useVoicePlaceholder() {
        source = .voicePlaceholder
        voicePlaceholderMessage = "Voice capture will be connected and tested on iPhone."
    }

    func makeTask() -> TaskItem? {
        let storedRawText = rawText.trimmedForStorage
        guard !storedRawText.isEmpty else { return nil }

        let category = selectedChips.compactMap(\.category).first ?? inferredCategory(from: storedRawText)
        let estimatedMinutes = selectedChips.compactMap(\.minutes).first ?? inferredMinutes(from: storedRawText)
        let dueDate = selectedChips.compactMap(\.dueDateOffset).min().flatMap { offset in
            Calendar.current.date(byAdding: .day, value: offset, to: Date())
        }
        let flexibleWindow = selectedChips.compactMap(\.flexibleWindow).first

        return TaskItem(
            rawText: storedRawText,
            category: category,
            priority: dueDate.map { Calendar.current.isDateInToday($0) ? .important : .normal } ?? .normal,
            energyLevel: .any,
            estimatedMinutes: estimatedMinutes,
            dueDate: dueDate,
            flexibleWindow: flexibleWindow,
            source: source
        )
    }

    func reset() {
        rawText = ""
        selectedChips = []
        source = .typed
        voicePlaceholderMessage = nil
    }

    private func inferredCategory(from text: String) -> TaskCategory {
        let lowercased = text.lowercased()
        if lowercased.contains("laundry") || lowercased.contains("kitchen") || lowercased.contains("dish") {
            return .cleaning
        }
        if lowercased.contains("bill") || lowercased.contains("pay") {
            return .bills
        }
        if lowercased.contains("doctor") || lowercased.contains("appointment") {
            return .appointment
        }
        if lowercased.contains("grocery") || lowercased.contains("store") || lowercased.contains("pick up") {
            return .errand
        }
        if lowercased.contains("dinner") || lowercased.contains("meal") {
            return .meals
        }
        return .other
    }

    private func inferredMinutes(from text: String) -> Int {
        let lowercased = text.lowercased()
        if lowercased.contains("5 min") || lowercased.contains("quick") { return 5 }
        if lowercased.contains("hour") { return 60 }
        if lowercased.contains("call") { return 10 }
        return 15
    }
}

