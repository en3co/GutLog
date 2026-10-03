import Foundation
import HealthKit

/// Write-only HealthKit helper. Never requests read access.
@MainActor
final class HealthKitWriter {
    static let shared = HealthKitWriter()

    private let store: HKHealthStore?
    private var didRequestAuthorization = false

    private init() {
        if HKHealthStore.isHealthDataAvailable() {
            store = HKHealthStore()
        } else {
            store = nil
        }
    }

    var isAvailable: Bool { store != nil }

    private var writeTypes: Set<HKSampleType> {
        var types: Set<HKSampleType> = []
        let ids: [HKQuantityTypeIdentifier] = [
            .dietaryEnergyConsumed,
            .dietaryProtein,
            .dietaryCarbohydrates,
            .dietaryFatTotal,
            .dietaryFiber,
            .dietaryWater
        ]
        for id in ids {
            if let t = HKQuantityType.quantityType(forIdentifier: id) {
                types.insert(t)
            }
        }
        for id: HKCategoryTypeIdentifier in [.abdominalCramps, .bloating, .diarrhea] {
            if let t = HKCategoryType.categoryType(forIdentifier: id) {
                types.insert(t)
            }
        }
        return types
    }

    func requestWriteAccessIfNeeded() async {
        guard let store, !didRequestAuthorization else { return }
        didRequestAuthorization = true
        do {
            try await store.requestAuthorization(toShare: writeTypes, read: [])
        } catch {
            // Diary still works without HealthKit.
        }
    }

    func syncMeal(_ meal: Meal) async {
        guard meal.hasNutritionForHealth else {
            await deleteMealSamples(meal)
            return
        }
        await requestWriteAccessIfNeeded()
        guard let store else { return }
        await deleteMealSamples(meal)

        let date = meal.timestamp
        var energy: UUID?
        var protein: UUID?
        var carbs: UUID?
        var fat: UUID?
        var fibre: UUID?
        var water: UUID?

        if let kcal = meal.kcal {
            energy = await saveQuantity(store: store, id: .dietaryEnergyConsumed, unit: .kilocalorie(), value: kcal, date: date)
        }
        if let p = meal.proteinG {
            protein = await saveQuantity(store: store, id: .dietaryProtein, unit: .gram(), value: p, date: date)
        }
        if let c = meal.carbsG {
            carbs = await saveQuantity(store: store, id: .dietaryCarbohydrates, unit: .gram(), value: c, date: date)
        }
        if let f = meal.fatG {
            fat = await saveQuantity(store: store, id: .dietaryFatTotal, unit: .gram(), value: f, date: date)
        }
        if let fi = meal.fibreG {
            fibre = await saveQuantity(store: store, id: .dietaryFiber, unit: .gram(), value: fi, date: date)
        }
        if let w = meal.waterML {
            let unit = HKUnit.literUnit(with: .milli)
            water = await saveQuantity(store: store, id: .dietaryWater, unit: unit, value: w, date: date)
        }

        meal.hkEnergyUUID = energy
        meal.hkProteinUUID = protein
        meal.hkCarbsUUID = carbs
        meal.hkFatUUID = fat
        meal.hkFibreUUID = fibre
        meal.hkWaterUUID = water
    }

    func deleteQuantityUUIDs(_ ids: [UUID]) async {
        guard let store else { return }
        await deleteSamples(store: store, uuids: ids)
    }

    func deleteMealSamples(_ meal: Meal) async {
        let ids = [
            meal.hkEnergyUUID,
            meal.hkProteinUUID,
            meal.hkCarbsUUID,
            meal.hkFatUUID,
            meal.hkFibreUUID,
            meal.hkWaterUUID
        ].compactMap { $0 }
        await deleteQuantityUUIDs(ids)
        meal.hkEnergyUUID = nil
        meal.hkProteinUUID = nil
        meal.hkCarbsUUID = nil
        meal.hkFatUUID = nil
        meal.hkFibreUUID = nil
        meal.hkWaterUUID = nil
    }

    func syncSymptom(_ symptom: Symptom) async {
        guard symptom.kind.healthKitCategoryIdentifier != nil else {
            await deleteSymptomSample(symptom)
            return
        }
        await requestWriteAccessIfNeeded()
        guard let store else { return }
        await deleteSymptomSample(symptom)

        let identifier: HKCategoryTypeIdentifier
        switch symptom.kind {
        case .bloating: identifier = .bloating
        case .upperAbdominalPain: identifier = .abdominalCramps
        case .diarrhoea: identifier = .diarrhea
        default: return
        }
        guard let type = HKCategoryType.categoryType(forIdentifier: identifier) else { return }

        let value = severityValue(symptom.severity)
        let sample = HKCategorySample(
            type: type,
            value: value,
            start: symptom.timestamp,
            end: symptom.timestamp,
            metadata: [HKMetadataKeyWasUserEntered: true]
        )
        do {
            try await store.save(sample)
            symptom.hkSampleUUID = sample.uuid
        } catch {
            symptom.hkSampleUUID = nil
        }
    }

    func deleteSymptomSample(_ symptom: Symptom) async {
        guard let store, let id = symptom.hkSampleUUID else { return }
        await deleteSamples(store: store, uuids: [id])
        symptom.hkSampleUUID = nil
    }

    private func severityValue(_ severity: Int) -> Int {
        switch severity {
        case 0: return HKCategoryValueSeverity.notPresent.rawValue
        case 1...3: return HKCategoryValueSeverity.mild.rawValue
        case 4...6: return HKCategoryValueSeverity.moderate.rawValue
        default: return HKCategoryValueSeverity.severe.rawValue
        }
    }

    private func saveQuantity(
        store: HKHealthStore,
        id: HKQuantityTypeIdentifier,
        unit: HKUnit,
        value: Double,
        date: Date
    ) async -> UUID? {
        guard let type = HKQuantityType.quantityType(forIdentifier: id) else { return nil }
        let quantity = HKQuantity(unit: unit, doubleValue: value)
        let sample = HKQuantitySample(
            type: type,
            quantity: quantity,
            start: date,
            end: date,
            metadata: [HKMetadataKeyWasUserEntered: true]
        )
        do {
            try await store.save(sample)
            return sample.uuid
        } catch {
            return nil
        }
    }

    private func deleteSamples(store: HKHealthStore, uuids: [UUID]) async {
        guard !uuids.isEmpty else { return }
        let predicate = HKQuery.predicateForObjects(with: Set(uuids))
        for type in writeTypes {
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                store.deleteObjects(of: type, predicate: predicate) { _, _, _ in
                    cont.resume()
                }
            }
        }
    }
}
