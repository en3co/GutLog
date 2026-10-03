import SwiftUI
import SwiftData

struct PatternsView: View {
    @Query(sort: \Meal.timestamp) private var meals: [Meal]
    @Query(sort: \Symptom.timestamp) private var symptoms: [Symptom]

    @State private var windowDays = 7

    private var cutoff: Date {
        Calendar.current.date(byAdding: .day, value: -windowDays, to: Date()) ?? Date()
    }

    private var windowSymptoms: [Symptom] {
        symptoms.filter { $0.timestamp >= cutoff }.sorted { $0.timestamp > $1.timestamp }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Window", selection: $windowDays) {
                        Text("7 days").tag(7)
                        Text("14 days").tag(14)
                    }
                    .pickerStyle(.segmented)
                }

                if windowSymptoms.isEmpty {
                    ContentUnavailableView("No symptoms in this window", systemImage: "list.bullet", description: Text("Log symptoms on Today, then return here to see nearby meals."))
                } else {
                    ForEach(windowSymptoms, id: \.id) { symptom in
                        Section {
                            mealGroup(title: "Meals in the 4 hours before", meals: meals(before: symptom.timestamp, fromHours: 0, toHours: 4))
                            mealGroup(title: "Meals 4–24 hours before", meals: meals(before: symptom.timestamp, fromHours: 4, toHours: 24))
                        } header: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(symptom.kind.title)
                                Text("\(timeString(symptom.timestamp)) · severity \(symptom.severity)/10")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .textCase(nil)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Patterns")
        }
    }

    @ViewBuilder
    private func mealGroup(title: String, meals: [Meal]) -> some View {
        if meals.isEmpty {
            Text("\(title): none")
                .foregroundStyle(.secondary)
        } else {
            ForEach(meals, id: \.id) { meal in
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(meal.name)
                        .font(.headline)
                    Text(timeString(meal.timestamp))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func meals(before date: Date, fromHours: Double, toHours: Double) -> [Meal] {
        let later = date.addingTimeInterval(-fromHours * 3600)
        let earlier = date.addingTimeInterval(-toHours * 3600)
        return meals.filter { $0.timestamp >= earlier && $0.timestamp < later }
            .sorted { $0.timestamp < $1.timestamp }
    }

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        f.timeZone = .current
        return f.string(from: date)
    }
}
