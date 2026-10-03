import SwiftUI
import SwiftData
import UIKit

struct AddSymptomView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var day: Date
    var existing: Symptom?

    @State private var selected: Set<SymptomKind> = []
    @State private var severity: Double = 5
    @State private var notes = ""
    @State private var timestamp = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("Type") {
                    ForEach(SymptomKind.allCases) { kind in
                        Button {
                            toggle(kind)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: selected.contains(kind) ? "checkmark.circle.fill" : "circle")
                                    .font(.title2)
                                    .foregroundStyle(selected.contains(kind) ? Color.accentColor : Color.secondary)
                                Text(kind.title)
                                    .foregroundStyle(.primary)
                                Spacer(minLength: 0)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                Section("Severity") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("\(Int(severity))")
                                .font(.title.monospacedDigit().bold())
                            Text("/ 10")
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $severity, in: 0...10, step: 1)
                        Stepper("Severity", value: $severity, in: 0...10, step: 1)
                            .labelsHidden()
                    }
                    .padding(.vertical, 4)
                }
                Section {
                    DatePicker("Time", selection: $timestamp)
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                }
            }
            .navigationTitle(existing == nil ? "Add symptom" : "Edit symptom")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .bold()
                        .disabled(selected.isEmpty)
                }
            }
            .onAppear {
                if let existing {
                    selected = [existing.kind]
                    severity = Double(existing.severity)
                    notes = existing.notes
                    timestamp = existing.timestamp
                } else {
                    timestamp = defaultTime(on: day)
                }
            }
        }
    }

    private func toggle(_ kind: SymptomKind) {
        if selected.contains(kind) {
            selected.remove(kind)
        } else {
            selected.insert(kind)
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    @MainActor
    private func save() {
        Haptics.dismissKeyboard()
        let chosen = SymptomKind.allCases.filter { selected.contains($0) }
        guard !chosen.isEmpty else { return }

        var saved: [Symptom] = []
        if let existing {
            let primary = chosen.contains(existing.kind) ? existing.kind : chosen[0]
            existing.kind = primary
            existing.severity = Int(severity)
            existing.notes = notes
            existing.timestamp = timestamp
            saved.append(existing)
            for kind in chosen where kind != primary {
                let extra = Symptom(timestamp: timestamp, kind: kind, severity: Int(severity), notes: notes)
                context.insert(extra)
                saved.append(extra)
            }
        } else {
            for kind in chosen {
                let symptom = Symptom(timestamp: timestamp, kind: kind, severity: Int(severity), notes: notes)
                context.insert(symptom)
                saved.append(symptom)
            }
        }
        try? context.save()
        Haptics.save()
        Task { @MainActor in
            for symptom in saved {
                await HealthKitWriter.shared.syncSymptom(symptom)
            }
        }
        dismiss()
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



