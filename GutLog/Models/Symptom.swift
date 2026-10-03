import Foundation
import SwiftData

@Model
final class Symptom {
    var id: UUID
    var timestamp: Date
    var kindRaw: String
    var severity: Int
    var notes: String
    var hkSampleUUID: UUID?

    init(
        id: UUID = UUID(),
        timestamp: Date = .now,
        kind: SymptomKind,
        severity: Int,
        notes: String = ""
    ) {
        self.id = id
        self.timestamp = timestamp
        self.kindRaw = kind.rawValue
        self.severity = min(10, max(0, severity))
        self.notes = notes
    }

    var kind: SymptomKind {
        get { SymptomKind(rawValue: kindRaw) ?? .other }
        set { kindRaw = newValue.rawValue }
    }
}
