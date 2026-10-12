import Foundation
import Observation

enum AppTab: Hashable {
    case home
    case explore
    case saved
}

/// What a tab's stack can push: a lot, from any tab, or the settings, from Home.
enum Route: Hashable {
    case lot(Long)
    case settings
}

/// Where the user is: the selected tab, and the screens pushed on each tab's own stack.
/// Each tab keeps its stack when another is selected, so leaving Explore for Saved
/// and coming back finds the lot that was open.
@MainActor @Observable
final class Router {
    var tab: AppTab = .home
    var homePath: [Route] = []
    var explorePath: [Route] = []
    var savedPath: [Route] = []

    /// UI smoke-test hook: `LOYFUS_START_SCREEN` is how the screenshots of the audit
    /// are taken. `home`, `explore`, `saved`, `settings` or `lot/<id>` lands straight there. It is
    /// read here, in the initializer, because SwiftUI may build the app's state more
    /// than once and keep only one copy: whichever it keeps must start in the right place.
    init(environment: [String: String] = ProcessInfo.processInfo.environment) {
        guard let screen = environment["LOYFUS_START_SCREEN"] else { return }
        switch screen {
        case "explore": tab = .explore
        case "saved": tab = .saved
        case "home": tab = .home
        case "settings": homePath = [.settings]
        default:
            if screen.hasPrefix("lot/"), let id = Long(screen.dropFirst(4)), id > 0 {
                homePath = [.lot(id)]
            }
        }
    }

    /// Opens a lot on the stack of the tab the user is in, so Back returns to where
    /// they were.
    func open(lot id: Long) {
        switch tab {
        case .home: homePath.append(.lot(id))
        case .explore: explorePath.append(.lot(id))
        case .saved: savedPath.append(.lot(id))
        }
    }

    /// The settings, behind the gear on Home's bar. A second tap while the push is under
    /// way does not stack a second copy.
    func openSettings() {
        guard homePath.last != .settings else { return }
        homePath.append(.settings)
    }

    func select(_ tab: AppTab) {
        self.tab = tab
    }

    /// Tapping the tab that is already selected returns it to its root, as it does
    /// in every other app.
    func popToRoot(_ tab: AppTab) {
        switch tab {
        case .home: homePath = []
        case .explore: explorePath = []
        case .saved: savedPath = []
        }
    }

    /// `loyfus://lot/<id>` opens a lot, `loyfus://explore` opens browse.
    func handle(_ url: URL) {
        switch url.host {
        case "lot":
            if let id = Long(url.lastPathComponent), id > 0 { open(lot: id) }
        case "explore":
            select(.explore)
        default:
            break
        }
    }
}
