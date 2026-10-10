import SwiftUI
import SwiftData
import UIKit

struct AddMealView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Meal.timestamp, order: .reverse) private var meals: [Meal]
    @FocusState private var nameFocused: Bool

    var day: Date
    var existing: Meal?
    var embedded = false

    @State private var name = ""
    @State private var notes = ""
    @State private var portionNote = ""
    @State private var timestamp = Date()
    @State private var showNutrition = false
    @State private var kcalText = ""
    @State private var proteinText = ""
    @State private var carbsText = ""
    @State private var fatText = ""
    @State private var fibreText = ""
    @State private var waterText = ""
    @State private var isRepeat = false

    private var recentNames: [String] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        var seen = Set<String>()
        var names: [String] = []
        for meal in meals where meal.timestamp >= cutoff {
            let key = meal.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else { continue }
            let lower = key.lowercased()
            if seen.insert(lower).inserted {
                names.append(key)
            }
            if names.count >= 20 { break }
        }
        return names
    }

    var body: some View {
        container {
            Form {
                Section("Meal") {
                    TextField("What did you eat?", text: $name)
                        .focused($nameFocused)
                        .textInputAutocapitalization(.sentences)
                    DatePicker("Time", selection: $timestamp)
                    TextField("Notes", text: $notes, axis: .vertical)
                    TextField("Portion (optional)", text: $portionNote)
                }

                if !recentNames.isEmpty && existing == nil {
                    Section("Repeat from last 7 days") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(recentNames, id: \.self) { item in
                                    Button(item) {
                                        applyRepeat(named: item)
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.large)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                Section {
                    DisclosureGroup("Nutrition (optional)", isExpanded: $showNutrition) {
                        numberField("Energy (kcal)", text: $kcalText)
                        numberField("Protein (g)", text: $proteinText)
                        numberField("Carbs (g)", text: $carbsText)
                        numberField("Fat (g)", text: $fatText)
                        numberField("Fibre (g)", text: $fibreText)
                        numberField("Water (ml)", text: $waterText)
                    }
                }
            }
            .navigationTitle(existing == nil ? "Add meal" : "Edit meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .bold()
                }
            }
            .onAppear {
                if let existing {
                    name = existing.name
                    notes = existing.notes
                    portionNote = existing.portionNote
                    timestamp = existing.timestamp
                    kcalText = existing.kcal.map(stringFrom) ?? ""
                    proteinText = existing.proteinG.map(stringFrom) ?? ""
                    carbsText = existing.carbsG.map(stringFrom) ?? ""
                    fatText = existing.fatG.map(stringFrom) ?? ""
                    fibreText = existing.fibreG.map(stringFrom) ?? ""
                    waterText = existing.waterML.map(stringFrom) ?? ""
                    isRepeat = existing.isRepeat
                    showNutrition = existing.hasNutritionForHealth
                } else {
                    timestamp = defaultTime(on: day)
                    nameFocused = true
                }
            }
        }
    }

    @ViewBuilder
    private func container<V: View>(@ViewBuilder content: () -> V) -> some View {
        if embedded {
            content()
        } else {
            NavigationStack { content() }
        }
    }

    private func numberField(_ title: String, text: Binding<String>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("—", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 120)
        }
        .frame(minHeight: 36)
    }

    private func applyRepeat(named: String) {
        guard let source = meals.first(where: { $0.name.caseInsensitiveCompare(named) == .orderedSame }) else {
            name = named
            isRepeat = true
            timestamp = Date()
            return
        }
        name = source.name
        notes = source.notes
        portionNote = source.portionNote
        kcalText = source.kcal.map(stringFrom) ?? ""
        proteinText = source.proteinG.map(stringFrom) ?? ""
        carbsText = source.carbsG.map(stringFrom) ?? ""
        fatText = source.fatG.map(stringFrom) ?? ""
        fibreText = source.fibreG.map(stringFrom) ?? ""
        waterText = source.waterML.map(stringFrom) ?? ""
        isRepeat = true
        timestamp = Date()
        showNutrition = source.hasNutritionForHealth
    }

    @MainActor
    private func save() {
        nameFocused = false
        Haptics.dismissKeyboard()
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let meal: Meal
        if let existing {
            meal = existing
            meal.name = trimmed
            meal.notes = notes
            meal.portionNote = portionNote
            meal.timestamp = timestamp
            meal.isRepeat = isRepeat
        } else {
            meal = Meal(
                timestamp: timestamp,
                name: trimmed,
                notes: notes,
                portionNote: portionNote,
                isRepeat: isRepeat
            )
            context.insert(meal)
        }
        meal.kcal = Double(kcalText.replacingOccurrences(of: ",", with: "."))
        meal.proteinG = Double(proteinText.replacingOccurrences(of: ",", with: "."))
        meal.carbsG = Double(carbsText.replacingOccurrences(of: ",", with: "."))
        meal.fatG = Double(fatText.replacingOccurrences(of: ",", with: "."))
        meal.fibreG = Double(fibreText.replacingOccurrences(of: ",", with: "."))
        meal.waterML = Double(waterText.replacingOccurrences(of: ",", with: "."))
        try? context.save()
        Haptics.save()
        Task { @MainActor in
            await HealthKitWriter.shared.syncMeal(meal)
        }
        dismiss()
    }

    private func stringFrom(_ value: Double) -> String {
        if value.rounded() == value { return String(Int(value)) }
        return String(value)
    }

    private func defaultTime(on day: Date) -> Date {
        let cal = Calendar.current
        if cal.isDateInToday(day) { return Date() }
        var comps = cal.dateComponents([.year, .month, .day], from: day)
        let now = cal.dateComponents([.hour, .minute], from: Date())
        comps.hour = now.hour
        comps.minute = now.minute
        return cal.date(from: comps) ?? day
    }
}
