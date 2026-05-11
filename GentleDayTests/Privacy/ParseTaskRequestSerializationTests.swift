import Foundation
import XCTest
@testable import GentleDay

final class ParseTaskRequestSerializationTests: XCTestCase {
    func testParseTaskRequestOmitsCategoryMetadata() throws {
        let preferences = UserPlanningPreferences()
        let task = TaskItem(
            rawText: "Meeting at noon",
            title: "Meeting at noon",
            category: .steadyRoutine,
            estimatedMinutes: 60
        )
        let context = AIParsingContext(
            currentDate: Date(timeIntervalSince1970: 0),
            timezone: "America/New_York",
            locale: "en_US",
            preferences: preferences,
            existingTasks: [task],
            existingScheduleBlocks: []
        )

        let data = try JSONEncoder.gentleAI.encode(ParseTaskRequest(rawText: task.rawText, context: context))
        let json = String(decoding: data, as: UTF8.self)

        XCTAssertFalse(json.contains("category"))
        XCTAssertFalse(json.contains("steadyRoutine"))
        XCTAssertTrue(json.contains("rawText"))
    }
}
