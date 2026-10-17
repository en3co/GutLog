import SwiftUI
import SwiftData

@main
struct GutLogWatchApp: App {
    init() {
        WatchSync.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            WatchTodayView()
        }
        .modelContainer(GutLogStore.shared)
    }
}
