import Foundation
import Observation

/// A shelf with its lots already prepared for display.
struct ShelfContent: Identifiable {
    let id: String
    let title: String
    let subtitle: String?
    /// What "Ver todos" hands to Explore.
    let query: ShelfQuery
    let items: [LotItem]
}

/// Home's data. Owned above the tabs, and its loading runs in a task of its own: a
/// task that belongs to the view is cancelled when the user switches tabs, and Home
/// would come back half loaded.
@MainActor @Observable
final class HomeModel {
    private(set) var phase: LoadPhase = .loading
    private(set) var shelves: [ShelfContent] = []
    private(set) var updatedAt: String?
    private(set) var totalLots: Int = 0
    /// The nearest deadline window that still has auctions, or nil when none closes
    /// in a week: the card is then not drawn at all.
    private(set) var closing: HomeResponse.ClosingWindow?
    private(set) var acceptsProposal: Int = 0

    private let repository: LoyfusRepository
    private var loadTask: Task<Void, Never>?

    init(repository: LoyfusRepository) {
        self.repository = repository
    }

    /// Loads the first time the screen appears; later appearances keep what is there.
    func startIfNeeded() {
        guard loadTask == nil, phase != .loaded else { return }
        reload()
    }

    func reload() {
        loadTask?.cancel()
        if shelves.isEmpty { phase = .loading }
        loadTask = Task { await fetch() }
    }

    /// For pull to refresh, which waits for the answer. Cancelling the refresh does
    /// not cancel the load.
    func refresh() async {
        reload()
        await loadTask?.value
    }

    private func fetch() async {
        do {
            let home = try await repository.home()
            guard !Task.isCancelled else { return }
            shelves = home.shelves.map {
                ShelfContent(
                    id: $0.id, title: $0.title, subtitle: $0.subtitle, query: $0.query,
                    items: $0.items.map(LotItem.init))
            }
            updatedAt = home.updatedAt
            totalLots = home.totalLots
            closing = home.closing
            acceptsProposal = home.acceptsProposal
            phase = .loaded
        } catch {
            if AppStore.wasCancelled(error) { return }
            if shelves.isEmpty { phase = .failed(AppStore.message(for: error)) }
        }
        loadTask = nil
    }
}
