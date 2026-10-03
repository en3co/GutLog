import Foundation
import SwiftData

@Model
final class Meal {
    var id: UUID
    var timestamp: Date
    var name: String
    var notes: String
    var portionNote: String
    var kcal: Double?
    var proteinG: Double?
    var carbsG: Double?
    var fatG: Double?
    var fibreG: Double?
    var waterML: Double?
    var isRepeat: Bool
    var hkEnergyUUID: UUID?
    var hkProteinUUID: UUID?
    var hkCarbsUUID: UUID?
    var hkFatUUID: UUID?
    var hkFibreUUID: UUID?
    var hkWaterUUID: UUID?

    init(
        id: UUID = UUID(),
        timestamp: Date = .now,
        name: String,
        notes: String = "",
        portionNote: String = "",
        kcal: Double? = nil,
        proteinG: Double? = nil,
        carbsG: Double? = nil,
        fatG: Double? = nil,
        fibreG: Double? = nil,
        waterML: Double? = nil,
        isRepeat: Bool = false
    ) {
        self.id = id
        self.timestamp = timestamp
        self.name = name
        self.notes = notes
        self.portionNote = portionNote
        self.kcal = kcal
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
        self.fibreG = fibreG
        self.waterML = waterML
        self.isRepeat = isRepeat
    }

    var hasNutritionForHealth: Bool {
        kcal != nil || proteinG != nil || carbsG != nil || fatG != nil || fibreG != nil || waterML != nil
    }
}
