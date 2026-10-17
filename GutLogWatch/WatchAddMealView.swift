import SwiftUI
import SwiftData

struct WatchAddMealView: View {
    @Environment(\.modelContext) private var context
    var onSaved: () -> Void
    @Query(sort: \Meal.timestamp, order: .reverse) private var meals: [Meal]

    @State private var name = ""
    @State private var saved = false

    private var recentNames: [String] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -14, to: .now) ?? .now
        var seen = Set<String>()
        var names: [String] = []
        for meal in meals where meal.timestamp >= cutoff {
            let trimmed = meal.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if seen.insert(trimmed.lowercased()).inserted {
                names.append(trimmed)
            }
            if names.count == 8 { break }
        }
        return names
    }

    var body: some View {
        List {
            if !recentNames.isEmpty {
                Section("Recent") {
                    ForEach(recentNames, id: \.self) { item in
                        Button(item) {
                            save(name: item, isRepeat: true)
                        }
                        .disabled(saved)
                    }
                }
            }
            Section("New") {
                TextField("Meal name", text: $name)
                Button("Save") {
                    save(name: name, isRepeat: false)
                }
                .disabled(saved || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .navigationTitle("Meal")
    }

    private func save(name: String, isRepeat: Bool) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let meal = Meal(name: trimmed, isRepeat: isRepeat)
        context.insert(meal)
        try? context.save()
        WatchSync.shared.send(.meal(SyncedMeal(meal)))
        saved = true
        onSaved()
    }
}
