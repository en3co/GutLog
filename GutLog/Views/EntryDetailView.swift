import SwiftUI
import SwiftData

struct EntryDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let item: TimelineItem
    @State private var confirmDelete = false

    var body: some View {
        Group {
            switch item {
            case .meal(let meal):
                AddMealView(day: meal.timestamp, existing: meal)
            case .symptom(let symptom):
                AddSymptomView(day: symptom.timestamp, existing: symptom)
            case .stool(let stool):
                AddStoolView(day: stool.timestamp, existing: stool)
            }
        }
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                Button(role: .destructive) {
                    confirmDelete = true
                } label: {
                    Label("Delete", systemImage: "trash")
                        .frame(minHeight: 44)
                }
            }
        }
        .confirmationDialog("Delete this entry?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                delete()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func delete() {
        switch item {
        case .meal(let meal):
            let energy = meal.hkEnergyUUID
            let protein = meal.hkProteinUUID
            let carbs = meal.hkCarbsUUID
            let fat = meal.hkFatUUID
            let fibre = meal.hkFibreUUID
            let water = meal.hkWaterUUID
            context.delete(meal)
            try? context.save()
            Task {
                await HealthKitWriter.shared.deleteQuantityUUIDs([energy, protein, carbs, fat, fibre, water].compactMap { $0 })
            }
        case .symptom(let symptom):
            let uuid = symptom.hkSampleUUID
            context.delete(symptom)
            try? context.save()
            Task { await HealthKitWriter.shared.deleteQuantityUUIDs([uuid].compactMap { $0 }) }
        case .stool(let stool):
            context.delete(stool)
            try? context.save()
        }
        dismiss()
    }
}
