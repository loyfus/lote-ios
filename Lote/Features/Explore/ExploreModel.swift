import Foundation
import Observation

/// The filters of the sheet: what narrows the catalogue by what a lot is, when it
/// closes and what it costs, plus how the result is ordered. The category and the
/// search text are not here: they have controls of their own on the screen.
struct ExploreFilters: Equatable {
    var modality: LotModality?
    /// Hours: the lot closes within this many.
    var endsWithin: Int?
    /// Only lots that take an offer below the asking price.
    var acceptsProposal: Bool?
    var minPrice: Int?
    var maxPrice: Int?
    var sort: LotSort = .ending

    /// What the badge on the filter button counts: type, deadline and price. The
    /// order is not a filter, and the category has its chips.
    var activeCount: Int {
        (modality == nil ? 0 : 1) + (endsWithin == nil ? 0 : 1)
            + (acceptsProposal == true ? 1 : 0) + (minPrice == nil && maxPrice == nil ? 0 : 1)
    }

    var isEmpty: Bool { activeCount == 0 }

    static let deadlines: [(hours: Int?, title: String)] = [
        (nil, "Qualquer"), (24, "Em 24 h"), (72, "Em 3 dias"), (168, "Em 7 dias"),
    ]

    static func deadlineTitle(_ hours: Int) -> String {
        switch hours {
        case 24: return "Em 24 h"
        case 72: return "Em 3 dias"
        case 168: return "Em 7 dias"
        default: return "Em \(hours) h"
        }
    }
}

/// The last searches typed on this device. Local only; never sent anywhere.
struct RecentSearches {
    static let limit = 8
    private static let key = "lote.recentSearches"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var all: [String] { defaults.stringArray(forKey: Self.key) ?? [] }

    func add(_ term: String) {
        let term = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard term.count >= 2 else { return }
        var terms = all.filter { $0.caseInsensitiveCompare(term) != .orderedSame }
        terms.insert(term, at: 0)
        defaults.set(Array(terms.prefix(Self.limit)), forKey: Self.key)
    }

    func clear() {
        defaults.removeObject(forKey: Self.key)
    }
}

/// Explore's state: the query, the filters, the page loaded so far and where it
/// stands. Owned above the tabs and loading in tasks of its own, so that leaving the
/// tab and coming back finds the same search, the same filters and the same place in
/// the list, and a search in flight is not cancelled by the switch.
@MainActor @Observable
final class ExploreModel {
    private(set) var items: [LotItem] = []
    private(set) var total = 0
    private(set) var phase: LoadPhase = .loading
    private(set) var hasNext = false
    private(set) var isLoadingMore = false
    private(set) var loadMoreFailed = false
    /// How many lots the catalogue has, learned from the first unfiltered answer:
    /// "Buscar em 4.691 lotes".
    private(set) var catalogueTotal: Int?
    private(set) var recents: [String]

    var searchText = ""
    private(set) var category: String?
    private(set) var filters = ExploreFilters()

    /// Set by Home's search field: Explore takes the keyboard when it appears.
    var wantsSearchFocus = false

    private let repository: LoteRepository
    private let recentStore: RecentSearches
    private var nextPage = 0
    private var generation = 0
    /// The search text the list on screen was loaded with.
    private var queriedText = ""
    private var loadTask: Task<Void, Never>?
    private var moreTask: Task<Void, Never>?
    private var debounceTask: Task<Void, Never>?

    static let pageSize = 24
    static let debounce: Duration = .milliseconds(320)

    init(repository: LoteRepository, recents: RecentSearches = RecentSearches()) {
        self.repository = repository
        recentStore = recents
        self.recents = recents.all
    }

    // MARK: Query

    var query: LotQuery {
        LotQuery(
            search: searchText, category: category, modality: filters.modality?.rawValue,
            endsWithin: filters.endsWithin, acceptsProposal: filters.acceptsProposal,
            minPrice: filters.minPrice, maxPrice: filters.maxPrice,
            sort: filters.sort, page: 0, size: Self.pageSize)
    }

    private var isUnfiltered: Bool {
        searchText.trimmingCharacters(in: .whitespaces).isEmpty && category == nil && filters.isEmpty
    }

    var hasActiveQuery: Bool {
        !isUnfiltered || filters.sort != .ending
    }

    // MARK: Loading

    func startIfNeeded() {
        guard loadTask == nil, phase != .loaded else { return }
        reload()
    }

    /// Reads the first page again. `keepingItems` is the pull to refresh: the grid
    /// stays until the new page replaces it, where a changed query clears it first so
    /// that nothing stale sits under the new filters.
    func reload(keepingItems: Bool = false) {
        debounceTask?.cancel()
        moreTask?.cancel()
        loadTask?.cancel()
        generation += 1
        let mine = generation
        isLoadingMore = false
        loadMoreFailed = false
        queriedText = searchText
        if !keepingItems || items.isEmpty {
            items = []
            hasNext = false
            phase = .loading
        }
        loadTask = Task { await fetchFirstPage(generation: mine) }
    }

    func refresh() async {
        reload(keepingItems: true)
        await loadTask?.value
    }

    private func fetchFirstPage(generation mine: Int) async {
        do {
            let page = try await repository.lots(query)
            guard mine == generation else { return }
            items = page.items.map(LotItem.init)
            total = page.totalElements
            hasNext = page.hasNext
            nextPage = 1
            if isUnfiltered { catalogueTotal = page.totalElements }
            phase = .loaded
        } catch {
            guard mine == generation, !AppStore.wasCancelled(error) else { return }
            // A refresh that failed keeps the list the user is looking at.
            if items.isEmpty { phase = .failed(AppStore.message(for: error)) }
        }
        loadTask = nil
    }

    /// Called as a tile appears: near the end of what is loaded, read the next page.
    func loadMoreIfNeeded(after item: LotItem) {
        guard hasNext, !isLoadingMore, phase == .loaded,
              items.suffix(6).contains(where: { $0.id == item.id }) else { return }
        loadMore()
    }

    func loadMore() {
        guard hasNext, !isLoadingMore else { return }
        isLoadingMore = true
        loadMoreFailed = false
        let mine = generation
        var next = query
        next.page = nextPage
        moreTask = Task {
            do {
                let page = try await repository.lots(next)
                guard mine == generation else { return }
                // The catalogue moves between two requests, and a lot that slid
                // across the page boundary must not appear twice.
                let known = Set(items.map(\.id))
                items += page.items.filter { !known.contains($0.id) }.map(LotItem.init)
                total = page.totalElements
                hasNext = page.hasNext
                nextPage += 1
            } catch {
                guard mine == generation, !AppStore.wasCancelled(error) else { return }
                loadMoreFailed = true
            }
            if mine == generation { isLoadingMore = false }
        }
    }

    // MARK: Search

    /// Called as the text changes: the search runs once the typing pauses.
    func searchTextChanged() {
        debounceTask?.cancel()
        // The model itself sets the text when a shelf or a recent term opens Explore,
        // and has loaded for it already.
        guard searchText != queriedText else { return }
        debounceTask = Task {
            try? await Task.sleep(for: Self.debounce)
            guard !Task.isCancelled else { return }
            reload()
        }
    }

    /// Return on the keyboard: search now, and remember the term.
    func submitSearch() {
        rememberSearch()
        reload()
    }

    /// Keeps what was typed for the recent list. The keyboard's search key is not the
    /// only way to be done with a search: opening a lot from the results is another.
    func rememberSearch() {
        recentStore.add(searchText)
        recents = recentStore.all
    }

    /// A term from the recent list.
    func search(for term: String) {
        searchText = term
        submitSearch()
    }

    func clearRecents() {
        recentStore.clear()
        recents = []
    }

    // MARK: Filters

    func select(category: String?) {
        guard category != self.category else { return }
        self.category = category
        reload()
    }

    func apply(_ filters: ExploreFilters) {
        guard filters != self.filters else { return }
        self.filters = filters
        reload()
    }

    func removeModality() { var next = filters; next.modality = nil; apply(next) }
    func removeDeadline() { var next = filters; next.endsWithin = nil; apply(next) }
    func removeOffer() { var next = filters; next.acceptsProposal = nil; apply(next) }
    func removePrice() { var next = filters; next.minPrice = nil; next.maxPrice = nil; apply(next) }

    /// Back to the whole catalogue, in the default order.
    func clearAll() {
        searchText = ""
        category = nil
        filters = ExploreFilters()
        reload()
    }

    /// "Ver todos" on a shelf, or a category on Home: Explore opens on exactly that
    /// and nothing else, never on the intersection of it with a stale search.
    func show(_ shelf: ShelfQuery) {
        searchText = ""
        category = shelf.category
        filters = ExploreFilters(
            modality: shelf.modality.flatMap(LotModality.init(rawValue:)),
            endsWithin: shelf.endsWithin,
            acceptsProposal: shelf.acceptsProposal,
            sort: LotSort(rawValue: shelf.sort) ?? .ending)
        reload()
    }

    func show(category: String) {
        show(ShelfQuery(category: category))
    }

    /// Home's budget bands: the same filters, opened with a price already set.
    func show(budgetFrom min: Int?, to max: Int?) {
        searchText = ""
        category = nil
        filters = ExploreFilters(minPrice: min, maxPrice: max, sort: .ending)
        reload()
    }

    /// How the screen describes the filters that are on, in the order of the tags.
    var activeTags: [(title: String, remove: () -> Void)] {
        var tags: [(String, () -> Void)] = []
        if let modality = filters.modality { tags.append((modality.label, { [self] in removeModality() })) }
        if let hours = filters.endsWithin {
            tags.append((ExploreFilters.deadlineTitle(hours), { [self] in removeDeadline() }))
        }
        if filters.acceptsProposal == true {
            tags.append(("Aceita proposta", { [self] in removeOffer() }))
        }
        if let range = Fmt.priceRange(min: filters.minPrice, max: filters.maxPrice) {
            tags.append((range, { [self] in removePrice() }))
        }
        return tags
    }
}

extension ShelfQuery {
    init(category: String) {
        self.init()
        self.category = category
    }
}
