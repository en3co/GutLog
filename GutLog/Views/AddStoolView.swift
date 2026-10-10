import SwiftUI
import SwiftData
import UIKit

struct AddStoolView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var day: Date
    var existing: Stool?
    var embedded = false

    @State private var bristol: BristolType = .type4
    @State private var notes = ""
    @State private var timestamp = Date()

    var body: some View {
        container {
            Form {
                Section("Bristol type") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                        ForEach(BristolType.allCases) { type in
                            Button {
                                bristol = type
                            } label: {
                                VStack(spacing: 6) {
                                    Text("\(type.rawValue)")
                                        .font(.title2.bold())
                                    Text(type.shortLabel)
                                        .font(.caption)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                        .minimumScaleFactor(0.8)
                                }
                                .frame(maxWidth: .infinity, minHeight: 72)
                                .padding(6)
                                .background(bristol == type ? Color.accentColor : Color.secondary.opacity(0.15))
                                .foregroundStyle(bristol == type ? Color.white : Color.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Bristol \(type.rawValue), \(type.shortLabel)")
                        }
                    }
                    .padding(.vertical, 4)
                }
                Section {
                    DatePicker("Time", selection: $timestamp)
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                }
            }
            .navigationTitle(existing == nil ? "Add stool" : "Edit stool")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .bold()
                }
            }
            .onAppear {
                if let existing {
                    bristol = existing.bristolType
                    notes = existing.notes
                    timestamp = existing.timestamp
                } else {
                    timestamp = defaultTime(on: day)
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

    @MainActor
    private func save() {
        Haptics.dismissKeyboard()
        let stool: Stool
        if let existing {
            stool = existing
            stool.bristol = bristol.rawValue
            stool.notes = notes
            stool.timestamp = timestamp
        } else {
            stool = Stool(timestamp: timestamp, bristol: bristol.rawValue, notes: notes)
            context.insert(stool)
        }
        try? context.save()
        Haptics.save()
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
