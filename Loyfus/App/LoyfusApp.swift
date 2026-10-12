import SwiftUI
import UIKit

@main
struct LoyfusApp: App {
    @State private var store: AppStore
    @State private var router = Router()
    @State private var home: HomeModel
    @State private var explore: ExploreModel

    init() {
        let store = AppStore.live()
        _store = State(initialValue: store)
        _home = State(initialValue: HomeModel(repository: store.repository))
        _explore = State(initialValue: ExploreModel(repository: store.repository))
        Appearance.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(router)
                .environment(home)
                .environment(explore)
                .tint(Palette.amberText)
                .onOpenURL { router.handle($0) }
        }
    }
}

/// The few places where the system draws something the app has an opinion about.
enum Appearance {
    @MainActor
    static func configure() {
        // The count on the Saved tab is an amber seal with its dark label, like the
        // one on the filter button, not the system's red.
        let item = UITabBarItem.appearance()
        item.badgeColor = UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? 0xF7B733 : 0xF5A70A)
        }
        item.setBadgeTextAttributes(
            [.foregroundColor: UIColor { traits in
                UIColor(hex: traits.userInterfaceStyle == .dark ? 0x241800 : 0x1A1200)
            }],
            for: .normal)

        // The one large title in the app (Settings) is set like every other screen title,
        // in Bricolage, not in the system face; it still follows Dynamic Type.
        if let face = UIFont(name: "BricolageGrotesque-SemiBold", size: 32) {
            UINavigationBar.appearance().largeTitleTextAttributes = [
                .font: UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: face),
                .foregroundColor: UIColor(Palette.ink),
            ]
        }
    }
}
