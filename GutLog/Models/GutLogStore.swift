import Foundation
import SwiftData

/// Local SwiftData store. The Watch copies logs through Watch Connectivity.
enum GutLogStore {
    static let shared: ModelContainer = {
        let schema = Schema([Meal.self, Symptom.self, Stool.self])
        let local = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        do {
            return try ModelContainer(for: schema, configurations: local)
        } catch {
            fatalError("Could not open the Gut Log store: \(error)")
        }
    }()
}
