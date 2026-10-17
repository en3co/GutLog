import SwiftUI
import SwiftData

struct WatchAddSymptomView: View {
    var onSelect: (SymptomKind) -> Void

    var body: some View {
        List(SymptomKind.allCases) { kind in
            Button(kind.title) {
                onSelect(kind)
            }
        }
        .navigationTitle("Symptom")
    }
}

struct WatchSymptomSeverityView: View {
    @Environment(\.modelContext) private var context

    let kind: SymptomKind
    var onSaved: () -> Void

    @State private var severity = 5.0
    @State private var saved = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("\(Int(severity))")
                    .font(.largeTitle.monospacedDigit().bold())
                    .frame(maxWidth: .infinity)
                Text("of 10")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Slider(value: $severity, in: 0...10, step: 1) {
                    Text("Severity")
                }
                .modifier(CrownSeverity(severity: $severity))
                Button("Save") {
                    save()
                }
                .buttonStyle(.borderedProminent)
                .disabled(saved)
            }
            .padding(.vertical, 4)
        }
        .navigationTitle(kind.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func save() {
        let symptom = Symptom(kind: kind, severity: Int(severity))
        context.insert(symptom)
        try? context.save()
        WatchSync.shared.send(.symptom(SyncedSymptom(symptom)))
        saved = true
        onSaved()
    }
}

private struct CrownSeverity: ViewModifier {
    @Binding var severity: Double

    func body(content: Content) -> some View {
        content.digitalCrownRotation(
            $severity,
            from: 0,
            through: 10,
            by: 1,
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
    }
}
