import SwiftUI
import SwiftData

@main
struct GutLogApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [Meal.self, Symptom.self, Stool.self])
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "sun.max") }
            PatternsView()
                .tabItem { Label("Patterns", systemImage: "list.bullet.rectangle") }
            ExportView()
                .tabItem { Label("Export", systemImage: "square.and.arrow.up") }
        }
    }
}
