import UIKit

enum Haptics {
    @MainActor
    static func save() {
        let g = UINotificationFeedbackGenerator()
        g.notificationOccurred(.success)
    }

    @MainActor
    static func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
