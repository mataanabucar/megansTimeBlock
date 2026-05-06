import Foundation
import SwiftData

@Model
final class ReviewEntry: Identifiable {
    @Attribute(.unique) var id: UUID
    var date: Date
    var completedCount: Int
    var movedCount: Int
    var unfinishedCount: Int
    var note: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        completedCount: Int,
        movedCount: Int,
        unfinishedCount: Int,
        note: String = "A gentle review was saved.",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.date = date
        self.completedCount = completedCount
        self.movedCount = movedCount
        self.unfinishedCount = unfinishedCount
        self.note = note
        self.createdAt = createdAt
    }
}
