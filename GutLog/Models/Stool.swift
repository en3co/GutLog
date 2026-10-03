import Foundation
import SwiftData

@Model
final class Stool {
    var id: UUID
    var timestamp: Date
    var bristol: Int
    var notes: String

    init(
        id: UUID = UUID(),
        timestamp: Date = .now,
        bristol: Int,
        notes: String = ""
    ) {
        self.id = id
        self.timestamp = timestamp
        self.bristol = min(7, max(1, bristol))
        self.notes = notes
    }

    var bristolType: BristolType {
        BristolType(rawValue: bristol) ?? .type4
    }
}
