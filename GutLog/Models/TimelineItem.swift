import Foundation

enum TimelineItem: Identifiable {
    case meal(Meal)
    case symptom(Symptom)
    case stool(Stool)

    var id: UUID {
        switch self {
        case .meal(let m): return m.id
        case .symptom(let s): return s.id
        case .stool(let s): return s.id
        }
    }

    var timestamp: Date {
        switch self {
        case .meal(let m): return m.timestamp
        case .symptom(let s): return s.timestamp
        case .stool(let s): return s.timestamp
        }
    }
}
