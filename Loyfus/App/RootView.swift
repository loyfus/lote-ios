import SwiftUI

/// The three tabs of the app, each with a navigation stack of its own so that what
/// the user was doing in one is still there when they come back to it.
///
/// The tab bar is the system's: on iOS 26 it is the floating glass bar, before that
/// the standard one, and either way the app's identity is in what it shows, not in
/// the chrome. Explore and Saved have no navigation bar: their headers are content.
/// Home has one, in the hero's night blue, because that is what carries the brand and
/// keeps the status bar legible over it.
struct RootView: View {
    @Environment(AppStore.self) private var store
    @Environment(Router.self) private var router
    @AppStorage(AppTheme.key) private var theme: AppTheme = .system

    var body: some View {
        @Bindable var router = router
        TabView(selection: selection) {
            NavigationStack(path: $router.homePath) {
                // Home keeps its bar: it is the night-blue header of the hero (HomeToolbar).
                root(hidesBar: false) { HomeScreen() }
            }
            .tabItem { Label("Início", systemImage: "house") }
            .tag(AppTab.home)

            NavigationStack(path: $router.explorePath) {
                root { ExploreScreen() }
            }
            .tabItem { Label("Explorar", systemImage: "magnifyingglass") }
            .tag(AppTab.explore)

            NavigationStack(path: $router.savedPath) {
                root { SavedScreen() }
            }
            .tabItem { Label("Salvos", systemImage: "heart") }
            .badge(store.favouriteIds.count)
            .tag(AppTab.saved)
        }
        .tint(Palette.amberText)
        .task { await store.start() }
        // The theme picked in Settings, applied to the window rather than to this view:
        // sheets and the system's own bars follow the window, not the view that asked.
        .onChange(of: theme, initial: true) { old, new in
            new.apply(animated: old != new)
        }
    }

    /// Tapping the tab that is already selected takes it back to its first screen.
    private var selection: Binding<AppTab> {
        Binding(
            get: { router.tab },
            set: { tab in
                if tab == router.tab {
                    router.popToRoot(tab)
                } else {
                    router.select(tab)
                }
            })
    }

    private func root<Content: View>(hidesBar: Bool = true, @ViewBuilder _ content: () -> Content) -> some View {
        content()
            .modifier(RefusalNotice())
            .toolbar(hidesBar ? .hidden : .visible, for: .navigationBar)
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .lot(let id): DetailScreen(lotId: id).modifier(RefusalNotice())
                case .settings: SettingsScreen()
                }
            }
    }
}
