import Foundation
import XCTest
@testable import GentleDay

final class SteadyRoutineSchedulingTests: XCTestCase {
    func testSteadyRoutinePrefersWeekdayDaytime() async throws {
        let preferences = makePreferences()
        let task = TaskItem(
            rawText: "Meeting at 10",
            title: "Meeting at 10",
            category: .steadyRoutine,
            estimatedMinutes: 15
        )

        let response = try await HeuristicScheduler().generatePlan(
            tasks: [task],
            existingScheduleBlocks: [],
            preferences: preferences,
            scheduleRange: .tomorrow,
            planningStyle: .balancedDay
        )

        let block = try XCTUnwrap(response.proposedScheduleBlocks.first)
        let hour = Calendar.current.component(.hour, from: block.startTime)
        XCTAssertGreaterThanOrEqual(hour, 9)
        XCTAssertLessThan(hour, 14)
        XCTAssertEqual(block.endTime.timeIntervalSince(block.startTime), 60 * 60, accuracy: 1)
    }

    func testOpenDayIsCappedInsteadOfFilled() async throws {
        let preferences = makePreferences()
        preferences.maxAutoScheduledBlocksPerDay = 5

        let tasks = [
            TaskItem(rawText: "Meeting at 10", title: "Meeting at 10", category: .steadyRoutine, estimatedMinutes: 15),
            TaskItem(rawText: "Grocery shopping", title: "Groceries", category: .errand, estimatedMinutes: 60),
            TaskItem(rawText: "Pay electric bill", title: "Pay electric bill", category: .bills, estimatedMinutes: 10),
            TaskItem(rawText: "Fold laundry", title: "Fold laundry", category: .cleaning, estimatedMinutes: 20),
            TaskItem(rawText: "Call insurance", title: "Call insurance", category: .lifeAdmin, estimatedMinutes: 15),
            TaskItem(rawText: "Tidy kitchen", title: "Tidy kitchen", category: .home, estimatedMinutes: 20)
        ]

        let response = try await HeuristicScheduler().generatePlan(
            tasks: tasks,
            existingScheduleBlocks: [],
            preferences: preferences,
            scheduleRange: .tomorrow,
            planningStyle: .balancedDay
        )

        XCTAssertLessThanOrEqual(response.proposedScheduleBlocks.count, 3)
        XCTAssertFalse(response.unscheduledTaskIDs.isEmpty)
    }

    func testGroceryPickupUsesShorterDuration() async throws {
        let preferences = makePreferences()
        preferences.groceryPickupDurationMinutes = 25
        let task = TaskItem(
            rawText: "Grocery shopping",
            title: "Grocery shopping",
            category: .errand,
            estimatedMinutes: 60
        )

        let response = try await HeuristicScheduler().generatePlan(
            tasks: [task],
            existingScheduleBlocks: [],
            preferences: preferences,
            scheduleRange: .tomorrow,
            planningStyle: .balancedDay
        )

        let block = try XCTUnwrap(response.proposedScheduleBlocks.first)
        XCTAssertEqual(block.endTime.timeIntervalSince(block.startTime), 25 * 60, accuracy: 1)
        XCTAssertEqual(block.aiReason, "Pickup option: shorter block.")
    }

    func testAIParsingRequestOmitsPrivateCategoryMetadata() throws {
        let preferences = makePreferences()
        let task = TaskItem(
            rawText: "Meeting at 10",
            title: "Meeting at 10",
            category: .steadyRoutine,
            estimatedMinutes: 60
        )
        let context = AIParsingContext(
            preferences: preferences,
            existingTasks: [task],
            existingScheduleBlocks: []
        )

        let data = try JSONEncoder().encode(AITaskParseRequest(rawText: "Meeting at 10", context: context))
        let json = String(decoding: data, as: UTF8.self)

        XCTAssertFalse(json.contains("\"category\""))
        XCTAssertFalse(json.contains("steadyRoutine"))
        XCTAssertFalse(json.localizedCaseInsensitiveContains("support"))
        XCTAssertTrue(json.contains("rawText"))
    }

    func testReminderContentUsesOnlyUserText() {
        let task = TaskItem(
            rawText: "Meeting at 10",
            title: "Meeting at 10",
            notes: "Bring notebook.",
            category: .steadyRoutine,
            estimatedMinutes: 60
        )
        let block = ScheduleBlock(
            taskId: task.id,
            title: task.title,
            startTime: Date().addingTimeInterval(3600),
            endTime: Date().addingTimeInterval(7200),
            flexibleWindowLabel: "Daytime",
            category: .steadyRoutine,
            reminderStyle: .gentle
        )

        let content = ReminderService.shared.makeReminderContent(for: block, task: task)

        XCTAssertEqual(content.title, "Meeting at 10")
        XCTAssertEqual(content.subtitle, "")
        XCTAssertEqual(content.body, "Meeting at 10. Bring notebook.")
        XCTAssertFalse(content.body.contains("steadyRoutine"))
        XCTAssertNil(content.userInfo["category"])
    }

    private func makePreferences() -> UserPlanningPreferences {
        UserPlanningPreferences(
            defaultWindowStart: clock(hour: 9, minute: 0),
            defaultWindowEnd: clock(hour: 20, minute: 30),
            primaryDayWindowStart: clock(hour: 9, minute: 0),
            primaryDayWindowEnd: clock(hour: 15, minute: 30),
            eveningCutoffTime: clock(hour: 19, minute: 30),
            protectedPlanningEnabled: true,
            reserveQuietBlock: true,
            quietBlockMinutes: 30,
            maxAutoScheduledBlocksPerDay: 5,
            lowEffortErrandEnabled: true,
            groceryPickupDurationMinutes: 25,
            steadyRoutineDurationMinutes: 60,
            steadyRoutineBufferMinutes: 15,
            aiMode: .mockAI
        )
    }

    private func clock(hour: Int, minute: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
    }
}
