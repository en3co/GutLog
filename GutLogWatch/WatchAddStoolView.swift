import SwiftUI
import SwiftData

struct WatchAddStoolView: View {
    @Environment(\.modelContext) private var context
    var onSaved: () -> Void

    @State private var bristol: BristolType = .type4
    @State private var saved = false

    var body: some View {
        List {
            Section("Bristol type") {
                ForEach(BristolType.allCases) { type in
                    Button {
                        bristol = type
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Type \(type.rawValue)")
                                Text(type.shortLabel)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            if bristol == type {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("Stool")
        .safeAreaInset(edge: .bottom) {
            Button("Save type \(bristol.rawValue)") {
                save()
            }
            .buttonStyle(.borderedProminent)
            .disabled(saved)
            .padding(.horizontal)
        }
    }

    private func save() {
        let stool = Stool(bristol: bristol.rawValue)
        context.insert(stool)
        try? context.save()
        WatchSync.shared.send(.stool(SyncedStool(stool)))
        saved = true
        onSaved()
    }
}
