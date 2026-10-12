import Foundation
import Observation

enum AppConfig {
    // A physical device cannot use localhost: on the phone 127.0.0.1 is the
    // phone itself, so it has to reach the Mac over the LAN address below.
    static let apiBaseURL = "http://192.168.1.214:8080"
}

enum DeviceIdentity {
    private static let key = "loyfus.device.id"

    static var current: String {
        if let existing = UserDefaults.standard.string(forKey: key) { return existing }
        let generated = UUID().uuidString
        UserDefaults.standard.set(generated, forKey: key)
        return generated
    }
}

/// How far a screen's first load has got.
enum LoadPhase: Equatable {
    case loading
    case loaded
    case failed(String)
}

/// What every screen shares: the categories, and the favourites of this device. Each
/// screen owns its own lists; the heart on a tile in Explore and the row in Saved
/// have to agree, so the set of favourites lives here, above all of them.
@MainActor @Observable
final class AppStore {
    let repository: LoyfusRepository

    private(set) var categories: [Category] = []

    /// The favourites as Saved lists them, newest first.
    private(set) var favouriteItems: [LotItem] = []
    /// The same lots by id: what every heart on every screen asks.
    private(set) var favouriteIds: Set<Long> = []
    private(set) var favouritesPhase: LoadPhase = .loading

    /// Lots with a request in flight, so a double tap cannot send two.
    private var pending: Set<Long> = []

    /// A heart the server refused, after it has gone back. A heart that silently changes
    /// its mind tells the reader nothing about why; the screens say so (RefusalNotice).
    struct Refusal: Equatable {
        let id = UUID()
        /// True when saving failed, false when removing did.
        let saving: Bool

        var message: String {
            saving
                ? "Não foi possível salvar o lote. Tente de novo."
                : "Não foi possível remover o lote dos salvos. Tente de novo."
        }
    }

    private(set) var refusal: Refusal?

    /// Clears the notice, unless a newer refusal has replaced it meanwhile.
    func dismiss(_ shown: Refusal) {
        if refusal == shown { refusal = nil }
    }

    init(repository: LoyfusRepository) {
        self.repository = repository
    }

    static func live() -> AppStore {
        let base = URL(string: AppConfig.apiBaseURL)!
        return AppStore(repository: LoyfusRepository(api: LoyfusAPI(baseURL: base, deviceId: DeviceIdentity.current)))
    }

    func start() async {
        async let categories: Void = loadCategories()
        async let favourites: Void = loadFavourites()
        _ = await (categories, favourites)
    }

    func loadCategories() async {
        guard let loaded = try? await repository.categories() else { return }
        categories = loaded
    }

    func loadFavourites() async {
        // A reload that lands in the middle of a toggle would undo it on screen.
        guard pending.isEmpty else { return }
        do {
            var lots: [LotSummary] = []
            var page = 0
            while true {
                let result = try await repository.favourites(page: page)
                lots += result.items
                page += 1
                guard result.hasNext, page < 10 else { break }
            }
            guard pending.isEmpty else { return }
            favouriteItems = lots.map(LotItem.init)
            favouriteIds = Set(lots.map(\.id))
            favouritesPhase = .loaded
        } catch {
            if Self.wasCancelled(error) { return }
            // Hearts that are already on screen stay; only a first load that failed
            // has nothing to show.
            if favouritesPhase != .loaded {
                favouritesPhase = .failed(Self.message(for: error))
            }
        }
    }

    func isFavourite(_ id: Long) -> Bool { favouriteIds.contains(id) }

    /// The detail screen learns the truth from the server and tells the rest.
    func reconcile(id: Long, isFavourite: Bool) {
        guard !pending.contains(id) else { return }
        if isFavourite { favouriteIds.insert(id) } else { favouriteIds.remove(id) }
    }

    /// Sets a favourite and tells the server. The heart changes at once and changes
    /// back if the request fails: the screen never claims what is not saved.
    /// `item` is what Saved lists the lot as; without it the list is read again
    /// from the server afterwards.
    @discardableResult
    func setFavourite(_ on: Bool, id: Long, item: LotItem? = nil) async -> Bool {
        guard !pending.contains(id) else { return false }
        pending.insert(id)
        apply(on, id: id, item: item)
        do {
            if on {
                try await repository.addFavourite(id)
            } else {
                try await repository.removeFavourite(id)
            }
            pending.remove(id)
            if on, item == nil { await loadFavourites() }
            return true
        } catch {
            pending.remove(id)
            apply(!on, id: id, item: item)
            if !Self.wasCancelled(error) { refusal = Refusal(saving: on) }
            if item == nil { await loadFavourites() }
            return false
        }
    }

    private func apply(_ on: Bool, id: Long, item: LotItem?) {
        if on {
            favouriteIds.insert(id)
            if let item, !favouriteItems.contains(where: { $0.id == id }) {
                favouriteItems.insert(item, at: 0)
            }
        } else {
            favouriteIds.remove(id)
            favouriteItems.removeAll { $0.id == id }
        }
    }

    // MARK: Errors

    static func wasCancelled(_ error: Error) -> Bool {
        error is CancellationError || (error as? URLError)?.code == .cancelled
    }

    static func message(for error: Error) -> String {
        switch LoadFailure.classify(error) {
        case .notFound: return "Não encontramos o que você procurava."
        case .offline(let message): return message
        }
    }
}
