import Foundation
import SwiftData
import WatchConnectivity

enum WatchSyncMessage: Codable {
    case meal(SyncedMeal)
    case symptom(SyncedSymptom)
    case stool(SyncedStool)
    case delete(UUID)
    case requestLibrary
    case library(WatchLibrary)
}

struct SyncedMeal: Codable, Identifiable {
    var id: UUID
    var timestamp: Date
    var name: String
    var notes: String
    var portionNote: String
    var isRepeat: Bool
    var kcal: Double?
    var proteinG: Double?
    var carbsG: Double?
    var fatG: Double?
    var fibreG: Double?
    var waterML: Double?
}

struct SyncedSymptom: Codable, Identifiable {
    var id: UUID
    var timestamp: Date
    var kindRaw: String
    var severity: Int
    var notes: String
}

struct SyncedStool: Codable, Identifiable {
    var id: UUID
    var timestamp: Date
    var bristol: Int
    var notes: String
}

struct WatchLibrary: Codable {
    var meals: [SyncedMeal]
    var symptoms: [SyncedSymptom]
    var stools: [SyncedStool]
    var deleted: [UUID]
}

/// Moves logs between the Watch and the iPhone while the phone is paired.
/// A free Personal Team cannot sign the iCloud entitlement, so this uses Watch Connectivity.
@MainActor
final class WatchSync: NSObject, WCSessionDelegate {
    static let shared = WatchSync()

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let deletedKey = "watchsync.deleted"
    private let publishedKey = "watchsync.published"

    private override init() {
        super.init()
    }

    func start() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        #if os(iOS)
        NotificationCenter.default.addObserver(
            forName: ModelContext.didSave,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                WatchSync.shared.publish()
            }
        }
        #endif
    }

    func send(_ message: WatchSyncMessage) {
        guard WCSession.isSupported() else { return }
        guard let data = try? encoder.encode(message) else { return }
        WCSession.default.transferUserInfo(["event": data])
    }

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            #if os(iOS)
            self.publish()
            #else
            if let context = session.receivedApplicationContext["library"] as? Data {
                self.applyLibrary(context)
            }
            self.send(.requestLibrary)
            #endif
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let data = userInfo["event"] as? Data else { return }
        Task { @MainActor in
            self.apply(data)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let data = applicationContext["library"] as? Data else { return }
        Task { @MainActor in
            self.applyLibrary(data)
        }
    }

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
    #endif

    private func apply(_ data: Data) {
        guard let message = try? decoder.decode(WatchSyncMessage.self, from: data) else { return }
        let context = GutLogStore.shared.mainContext
        switch message {
        case .meal(let meal):
            upsert(meal, in: context)
        case .symptom(let symptom):
            upsert(symptom, in: context)
        case .stool(let stool):
            upsert(stool, in: context)
        case .delete(let id):
            delete(id, in: context)
            rememberDeleted(id)
        case .requestLibrary:
            #if os(iOS)
            publish()
            #endif
            return
        case .library(let library):
            apply(library, in: context)
        }
        try? context.save()
        #if os(iOS)
        publish()
        #endif
    }

    private func applyLibrary(_ data: Data) {
        guard let library = try? decoder.decode(WatchLibrary.self, from: data) else { return }
        apply(library, in: GutLogStore.shared.mainContext)
    }

    private func apply(_ library: WatchLibrary, in context: ModelContext) {
        for meal in library.meals { upsert(meal, in: context, updateExisting: true) }
        for symptom in library.symptoms { upsert(symptom, in: context, updateExisting: true) }
        for stool in library.stools { upsert(stool, in: context, updateExisting: true) }
        let present = Set(library.meals.map(\.id) + library.symptoms.map(\.id) + library.stools.map(\.id))
        for id in library.deleted where !present.contains(id) {
            delete(id, in: context)
        }
        try? context.save()
    }

    #if os(iOS)
    func publish() {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated else { return }
        let context = GutLogStore.shared.mainContext
        let cutoff = Calendar.current.date(byAdding: .day, value: -21, to: .now) ?? .now
        let meals = (try? context.fetch(FetchDescriptor<Meal>())) ?? []
        let symptoms = (try? context.fetch(FetchDescriptor<Symptom>())) ?? []
        let stools = (try? context.fetch(FetchDescriptor<Stool>())) ?? []

        let current = Set(meals.map(\.id) + symptoms.map(\.id) + stools.map(\.id))
        let previous = Set(UserDefaults.standard.stringArray(forKey: publishedKey)?.compactMap(UUID.init) ?? [])
        var deleted = Set(UserDefaults.standard.stringArray(forKey: deletedKey)?.compactMap(UUID.init) ?? [])
        deleted.formUnion(previous.subtracting(current))
        deleted.subtract(current)
        let tombstones = Array(deleted)
        UserDefaults.standard.set(tombstones.map(\.uuidString), forKey: deletedKey)
        UserDefaults.standard.set(current.map(\.uuidString), forKey: publishedKey)

        let library = WatchLibrary(
            meals: meals.filter { $0.timestamp >= cutoff }.map(SyncedMeal.init),
            symptoms: symptoms.filter { $0.timestamp >= cutoff }.map(SyncedSymptom.init),
            stools: stools.filter { $0.timestamp >= cutoff }.map(SyncedStool.init),
            deleted: tombstones
        )
        guard let data = try? encoder.encode(library) else { return }
        try? WCSession.default.updateApplicationContext(["library": data])
        // Queues until the Watch app is reachable, including after it is installed later.
        send(.library(library))
    }
    #endif

    private func rememberDeleted(_ id: UUID) {
        var deleted = UserDefaults.standard.stringArray(forKey: deletedKey) ?? []
        if !deleted.contains(id.uuidString) {
            deleted.append(id.uuidString)
        }
        UserDefaults.standard.set(deleted, forKey: deletedKey)
    }

    private func upsert(_ meal: SyncedMeal, in context: ModelContext, updateExisting: Bool = false) {
        if let existing = existingMeal(meal.id, in: context) {
            guard updateExisting else { return }
            existing.timestamp = meal.timestamp
            existing.name = meal.name
            existing.notes = meal.notes
            existing.portionNote = meal.portionNote
            existing.isRepeat = meal.isRepeat
            existing.kcal = meal.kcal
            existing.proteinG = meal.proteinG
            existing.carbsG = meal.carbsG
            existing.fatG = meal.fatG
            existing.fibreG = meal.fibreG
            existing.waterML = meal.waterML
            return
        }
        context.insert(Meal(
            id: meal.id,
            timestamp: meal.timestamp,
            name: meal.name,
            notes: meal.notes,
            portionNote: meal.portionNote,
            kcal: meal.kcal,
            proteinG: meal.proteinG,
            carbsG: meal.carbsG,
            fatG: meal.fatG,
            fibreG: meal.fibreG,
            waterML: meal.waterML,
            isRepeat: meal.isRepeat
        ))
    }

    private func upsert(_ symptom: SyncedSymptom, in context: ModelContext, updateExisting: Bool = false) {
        if let existing = existingSymptom(symptom.id, in: context) {
            guard updateExisting else { return }
            existing.timestamp = symptom.timestamp
            existing.kindRaw = symptom.kindRaw
            existing.severity = min(10, max(0, symptom.severity))
            existing.notes = symptom.notes
            return
        }
        let kind = SymptomKind(rawValue: symptom.kindRaw) ?? .other
        let model = Symptom(
            id: symptom.id,
            timestamp: symptom.timestamp,
            kind: kind,
            severity: symptom.severity,
            notes: symptom.notes
        )
        context.insert(model)
        #if os(iOS)
        Task { await HealthKitWriter.shared.syncSymptom(model) }
        #endif
    }

    private func upsert(_ stool: SyncedStool, in context: ModelContext, updateExisting: Bool = false) {
        if let existing = existingStool(stool.id, in: context) {
            guard updateExisting else { return }
            existing.timestamp = stool.timestamp
            existing.bristol = min(7, max(1, stool.bristol))
            existing.notes = stool.notes
            return
        }
        context.insert(Stool(
            id: stool.id,
            timestamp: stool.timestamp,
            bristol: stool.bristol,
            notes: stool.notes
        ))
    }

    private func delete(_ id: UUID, in context: ModelContext) {
        if let meal = existingMeal(id, in: context) {
            #if os(iOS)
            let ids = [
                meal.hkEnergyUUID, meal.hkProteinUUID, meal.hkCarbsUUID,
                meal.hkFatUUID, meal.hkFibreUUID, meal.hkWaterUUID
            ].compactMap { $0 }
            Task { await HealthKitWriter.shared.deleteQuantityUUIDs(ids) }
            #endif
            context.delete(meal)
        }
        if let symptom = existingSymptom(id, in: context) {
            #if os(iOS)
            let sample = symptom.hkSampleUUID
            Task { await HealthKitWriter.shared.deleteQuantityUUIDs([sample].compactMap { $0 }) }
            #endif
            context.delete(symptom)
        }
        if let stool = existingStool(id, in: context) {
            context.delete(stool)
        }
    }

    private func existingMeal(_ id: UUID, in context: ModelContext) -> Meal? {
        let target = id
        var descriptor = FetchDescriptor<Meal>(predicate: #Predicate { $0.id == target })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private func existingSymptom(_ id: UUID, in context: ModelContext) -> Symptom? {
        let target = id
        var descriptor = FetchDescriptor<Symptom>(predicate: #Predicate { $0.id == target })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private func existingStool(_ id: UUID, in context: ModelContext) -> Stool? {
        let target = id
        var descriptor = FetchDescriptor<Stool>(predicate: #Predicate { $0.id == target })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }
}

extension SyncedMeal {
    init(_ meal: Meal) {
        id = meal.id
        timestamp = meal.timestamp
        name = meal.name
        notes = meal.notes
        portionNote = meal.portionNote
        isRepeat = meal.isRepeat
        kcal = meal.kcal
        proteinG = meal.proteinG
        carbsG = meal.carbsG
        fatG = meal.fatG
        fibreG = meal.fibreG
        waterML = meal.waterML
    }
}

extension SyncedSymptom {
    init(_ symptom: Symptom) {
        id = symptom.id
        timestamp = symptom.timestamp
        kindRaw = symptom.kindRaw
        severity = symptom.severity
        notes = symptom.notes
    }
}

extension SyncedStool {
    init(_ stool: Stool) {
        id = stool.id
        timestamp = stool.timestamp
        bristol = stool.bristol
        notes = stool.notes
    }
}
