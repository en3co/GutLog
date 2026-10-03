import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ExportView: View {
    @Query(sort: \Meal.timestamp) private var meals: [Meal]
    @Query(sort: \Symptom.timestamp) private var symptoms: [Symptom]
    @Query(sort: \Stool.timestamp) private var stools: [Stool]

    @State private var day = Date()
    @State private var shareCSV: SharePayload?
    @State private var shareText: SharePayload?

    var body: some View {
        NavigationStack {
            List {
                Section("CSV") {
                    Button {
                        let csv = CSVExporter.csv(meals: meals, symptoms: symptoms, stools: stools)
                        let name = "gut-log-\(filenameDate()).csv"
                        shareCSV = SharePayload(filename: name, data: Data(csv.utf8), uti: .commaSeparatedText)
                    } label: {
                        Label("Share CSV", systemImage: "square.and.arrow.up")
                            .frame(minHeight: 44)
                    }
                }

                Section("Day summary") {
                    DatePicker("Day", selection: $day, displayedComponents: .date)
                    Button {
                        let text = CSVExporter.daySummary(date: day, meals: meals, symptoms: symptoms, stools: stools)
                        shareText = SharePayload(filename: "gut-log-day.txt", data: Data(text.utf8), uti: .plainText)
                    } label: {
                        Label("Share day’s text", systemImage: "doc.text")
                            .frame(minHeight: 44)
                    }
                }
            }
            .navigationTitle("Export")
            .sheet(item: $shareCSV) { payload in
                ActivityView(items: [payload.tempURL()])
            }
            .sheet(item: $shareText) { payload in
                ActivityView(items: [payload.tempURL()])
            }
        }
    }

    private func filenameDate() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f.string(from: Date())
    }
}

struct SharePayload: Identifiable {
    let id = UUID()
    let filename: String
    let data: Data
    let uti: UTType

    func tempURL() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? data.write(to: url, options: .atomic)
        return url
    }
}

struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
