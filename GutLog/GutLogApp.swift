import SwiftUI
import SwiftData
import UIKit

@main
struct GutLogApp: App {
    init() {
        WatchSync.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(GutLogStore.shared)
    }
}

struct RootView: View {
    @State private var todayReset = 0

    var body: some View {
        TabView {
            TodayView(todayReset: todayReset)
                .tabItem { Label("Today", systemImage: "sun.max") }
            ExportView()
                .tabItem { Label("Export", systemImage: "square.and.arrow.up") }
        }
        .background {
            TodayTabReselect {
                todayReset += 1
            }
        }
    }
}

/// Fires when the already-selected Today tab is tapped again.
/// UITabBarController does not send a selection callback for that tap, so this watches the touch itself.
private struct TodayTabReselect: UIViewControllerRepresentable {
    var onReselect: () -> Void

    func makeUIViewController(context: Context) -> Controller {
        Controller()
    }

    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.onReselect = onReselect
        controller.attachIfNeeded()
    }

    final class Controller: UIViewController, UIGestureRecognizerDelegate {
        var onReselect: () -> Void = {}
        private weak var observed: UITabBarController?

        func attachIfNeeded() {
            DispatchQueue.main.async { [weak self] in
                self?.attach()
            }
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            attach()
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            attach()
        }

        private func attach() {
            guard let tab = resolveTab() else { return }
            guard observed !== tab else { return }
            let press = UILongPressGestureRecognizer(target: self, action: #selector(tabPressed(_:)))
            press.minimumPressDuration = 0
            press.cancelsTouchesInView = false
            press.delaysTouchesBegan = false
            press.delaysTouchesEnded = false
            press.delegate = self
            tab.view.addGestureRecognizer(press)
            observed = tab
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }

        @objc private func tabPressed(_ gesture: UILongPressGestureRecognizer) {
            guard gesture.state == .began, let tab = observed, tab.selectedIndex == 0 else { return }
            let point = gesture.location(in: tab.view)
            guard isTodayTab(point, in: tab) else { return }
            onReselect()
        }

        /// True when the touch landed on the first tab-bar item. Checked at touch-down, before the bar changes selection.
        private func isTodayTab(_ point: CGPoint, in tab: UITabBarController) -> Bool {
            let bar = tab.tabBar
            let barFrame = bar.convert(bar.bounds, to: tab.view).insetBy(dx: -8, dy: -12)
            guard barFrame.contains(point) else { return false }

            let local = bar.convert(point, from: tab.view)
            let buttons = bar.subviews.filter { view in
                String(describing: type(of: view)).contains("Button") && view.bounds.width > 1
            }.sorted { $0.frame.minX < $1.frame.minX }
            if let first = buttons.first {
                return first.frame.insetBy(dx: -8, dy: -8).contains(local)
            }
            let count = max(bar.items?.count ?? 1, 1)
            return local.x < bar.bounds.width / CGFloat(count)
        }

        private func resolveTab() -> UITabBarController? {
            if let tab = tabBarController { return tab }
            var current: UIViewController? = self
            while let controller = current {
                if let tab = controller as? UITabBarController { return tab }
                current = controller.parent
            }
            return view.window?.rootViewController?.tabBarControllerInHierarchy
        }
    }
}

private extension UIViewController {
    var tabBarControllerInHierarchy: UITabBarController? {
        if let tab = self as? UITabBarController { return tab }
        for child in children {
            if let tab = child.tabBarControllerInHierarchy { return tab }
        }
        return nil
    }
}
