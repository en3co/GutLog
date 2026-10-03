import Foundation

enum SymptomKind: String, CaseIterable, Codable, Identifiable {
    case bloating
    case upperAbdominalPain
    case leftChestOrRibPain
    case nausea
    case reflux
    case wind
    case urgency
    case constipation
    case diarrhoea
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bloating: return "Bloating"
        case .upperAbdominalPain: return "Upper abdominal pain"
        case .leftChestOrRibPain: return "Left chest or rib pain"
        case .nausea: return "Nausea"
        case .reflux: return "Reflux"
        case .wind: return "Wind"
        case .urgency: return "Urgency"
        case .constipation: return "Constipation"
        case .diarrhoea: return "Diarrhoea"
        case .other: return "Other"
        }
    }

    /// Types that this app writes to HealthKit (write-only).
    var healthKitCategoryIdentifier: String? {
        switch self {
        case .bloating: return "HKCategoryTypeIdentifierBloating"
        case .upperAbdominalPain: return "HKCategoryTypeIdentifierAbdominalPain"
        case .diarrhoea: return "HKCategoryTypeIdentifierDiarrhea"
        default: return nil
        }
    }
}

enum BristolType: Int, CaseIterable, Identifiable {
    case type1 = 1, type2, type3, type4, type5, type6, type7

    var id: Int { rawValue }

    var shortLabel: String {
        switch self {
        case .type1: return "Hard lumps"
        case .type2: return "Lumpy sausage"
        case .type3: return "Cracked sausage"
        case .type4: return "Smooth sausage"
        case .type5: return "Soft blobs"
        case .type6: return "Mushy"
        case .type7: return "Watery"
        }
    }
}
