import Foundation
import Observation

struct NextActionRecommendation: Identifiable {
    let id = UUID()
    var taskId: UUID?
    var blockId: UUID?
    var title: String
    var reason: String
    var tinyStep: String
    var minutes: Int
}

@MainActor
@Observable
final class NextActionViewModel {
    func recommendation(tasks: [TaskItem], blocks: [ScheduleBlock]) -> NextActionRecommendation? {
        if let block = nextReadyBlock(from: blocks) {
            let task = tasks.first { $0.id == block.taskId }
            return NextActionRecommendation(
                taskId: block.taskId,
                blockId: block.id,
                title: block.title,
                reason: block.aiReason.nilIfBlank ?? "This is already in your gentle plan.",
                tinyStep: task.flatMap { $0.suggestedTinyStep.nilIfBlank } ?? "Start with one small visible step.",
                minutes: min(block.durationMinutes, 10)
            )
        }

        guard let task = bestTask(from: tasks) else { return nil }
        return NextActionRecommendation(
            taskId: task.id,
            blockId: nil,
            title: task.title,
            reason: reason(for: task),
            tinyStep: task.suggestedTinyStep,
            minutes: min(task.estimatedMinutes, 10)
        )
    }

    private func nextReadyBlock(from blocks: [ScheduleBlock]) -> ScheduleBlock? {
        blocks
            .filter { [.planned, .snoozed, .moved].contains($0.status) }
            .sorted { lhs, rhs in
                if Calendar.current.isDateInToday(lhs.startTime) != Calendar.current.isDateInToday(rhs.startTime) {
                    return Calendar.current.isDateInToday(lhs.startTime)
                }
                return lhs.startTime < rhs.startTime
            }
            .first
    }

    private func bestTask(from tasks: [TaskItem]) -> TaskItem? {
        let openStatuses: Set<TaskStatus> = [.inbox, .shrunk, .snoozed, .moved]
        return tasks
            .filter { openStatuses.contains($0.status) }
            .sorted { lhs, rhs in
                let left = score(lhs)
                let right = score(rhs)
                if left != right { return left > right }
                return lhs.estimatedMinutes < rhs.estimatedMinutes
            }
            .first
    }

    private func score(_ task: TaskItem) -> Int {
        var value = 0
        if task.estimatedMinutes <= 5 { value += 40 }
        else if task.estimatedMinutes <= 15 { value += 25 }
        if task.energyLevel == .low || task.energyLevel == .any { value += 10 }
        if !task.suggestedTinyStep.isEmpty { value += 15 }
        if let dueDate = task.dueDate {
            if Calendar.current.isDateInToday(dueDate) { value += 30 }
            else if dueDate < Date() { value += 20 }
        }
        if task.priority == .mustDo { value += 25 }
        if task.priority == .high { value += 15 }
        return value
    }

    private func reason(for task: TaskItem) -> String {
        if task.estimatedMinutes <= 5 {
            return "It only takes about 5 minutes, and starting is the win."
        }
        if task.title.lowercased().contains("laundry") {
            return "It can run while you do something else."
        }
        if let dueDate = task.dueDate, Calendar.current.isDateInToday(dueDate) {
            return "It belongs to today, and one small step is enough."
        }
        return "It is a low-friction place to restart."
    }
}
