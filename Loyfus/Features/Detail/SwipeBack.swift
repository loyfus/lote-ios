import SwiftUI
import UIKit

/// Keeps the swipe from the left edge working on a screen that has no system back
/// button.
///
/// UIKit turns the interactive pop gesture off for a pushed screen whose bar has been
/// hidden or whose back button has been replaced, and the detail screen draws its own
/// controls over the photograph. This restores it: the gesture is handed to a
/// delegate that allows it whenever there is a screen to go back to, which is the
/// only condition UIKit's own delegate was there to check.
struct SwipeBackEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Holder { Holder() }

    func updateUIViewController(_ controller: Holder, context: Context) {}

    final class Holder: UIViewController {
        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            guard let recognizer = navigationController?.interactivePopGestureRecognizer else { return }
            recognizer.delegate = PopGestureDelegate.shared
            recognizer.isEnabled = true
        }
    }
}

/// One delegate for every navigation controller: it holds no state, and a delegate
/// the recognizer holds weakly must not die with the screen that installed it.
private final class PopGestureDelegate: NSObject, UIGestureRecognizerDelegate {
    static let shared = PopGestureDelegate()

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // On the root screen the gesture has nothing to pop, and beginning anyway
        // leaves the navigation controller stuck.
        var responder: UIResponder? = gestureRecognizer.view
        while let current = responder {
            if let navigation = current as? UINavigationController {
                return navigation.viewControllers.count > 1
            }
            responder = current.next
        }
        return false
    }
}
