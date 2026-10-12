import Foundation
import Observation

/// A lot as the detail screen prints it, worked out once when the lot arrives.
struct DetailContent {
    struct Fact: Identifiable, Equatable {
        let label: String
        let value: String
        var id: String { label }
    }

    let lot: LotDetail
    /// The title with the auctioneer's capitals, codes and addresses cleaned off.
    let title: String
    let titleDetail: String?
    let kind: LotKind
    let category: CategoryStyle?
    /// Every specification, the ones a buyer decides on first.
    let facts: [Fact]
    /// The first four of them, plus the commission when there is one.
    let summary: [Fact]
    /// What the lot says about how it is bought, one item per line.
    let conditions: [String]
    let shareText: String

    /// A lot sold already says so beside its type. The list endpoint names the status;
    /// the detail one sends only the code, so the name falls back to the catalogue's.
    let soldLabel: String?

    init(_ lot: LotDetail) {
        self.lot = lot
        let tidy = TitleCache.tidy(lot.title)
        title = tidy.headline.isEmpty ? lot.title : tidy.headline
        titleDetail = tidy.detail
        kind = lot.kind
        category = lot.categoryName.map(Categories.style(for:))

        facts = Fmt.specOrder(lot.specs).map { Fact(label: $0.key, value: $0.value) }
        conditions = (lot.commercialCondition ?? "")
            .split(separator: "|")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        var summary = Array(facts.prefix(4))
        if let commission = conditions.first(where: { $0.range(of: "comiss", options: [.caseInsensitive, .diacriticInsensitive]) != nil }) {
            summary.append(Fact(label: "Condições", value: commission))
        }
        self.summary = summary

        let link = lot.webUrl.flatMap { $0.isEmpty ? nil : $0 }
        let headline = title
        shareText = link.map { "\(headline) — \($0)" } ?? headline

        soldLabel = lot.status == "SOLD" ? (lot.statusLabel ?? "Arrematado") : nil
    }

    var isSold: Bool { soldLabel != nil }

    /// The label above the price.
    func priceLabel(urgency: Urgency) -> String {
        switch kind {
        case .directSale: return "Preço"
        case .auction:
            if urgency == .ended { return "Lance final" }
            return lot.bidCount > 0 ? "Lance atual" : "Lance inicial"
        }
    }

    /// "N lances · M participantes" for an auction; a direct sale has nobody to bid
    /// against, and says so.
    var factsLine: String {
        switch kind {
        case .directSale: return "Compra direta, sem disputa de lances"
        case .auction: return "\(Fmt.bids(lot.bidCount)) · \(Fmt.participants(lot.bidderCount))"
        }
    }

    /// The word on the call to action. A lot that is over, or sold, is only to be
    /// looked at.
    func callToAction(urgency: Urgency) -> String {
        guard lot.webUrl != nil else { return "Link indisponível" }
        if urgency == .ended || isSold { return "Ver no site" }
        return kind == .directSale ? "Ver oferta no site" : "Dar lance no site"
    }

    /// The line under the price in the sticky bar: "lance atual · 4d 15h", "preço".
    func stickyCaption(urgency: Urgency, remaining: Int) -> String {
        let label = priceLabel(urgency: urgency).lowercased()
        guard kind == .auction, urgency == .hot || urgency == .normal else { return label }
        return "\(label) · \(Fmt.timeLeft(remaining))"
    }
}

/// The detail screen's countdown. It is worked out from a deadline, never counted
/// down by adding up sleeps, so it stays right through a suspended app; and it can be
/// paused, because a number that changes by itself must be stoppable (WCAG 2.2.2).
/// Pausing hides nothing: the day and hour the lot ends stay on the card.
@MainActor @Observable
final class DeadlineClock {
    private(set) var remaining: Int
    private(set) var isPaused = false

    private let deadline: Date?
    private var ticking: Task<Void, Never>?

    init(secondsToClose: Int, now: Date = Date()) {
        deadline = secondsToClose > 0 ? now.addingTimeInterval(TimeInterval(secondsToClose)) : nil
        remaining = max(0, secondsToClose)
    }

    var isRunning: Bool { remaining > 0 }

    func start() {
        guard ticking == nil, !isPaused, deadline != nil else { return }
        sync()
        ticking = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, self.sync() > 0 else { return }
                // Seconds are shown only in the last ten minutes. Before that the text
                // changes once a minute, so the clock sleeps until the next change.
                let left = self.remaining
                let wait = left <= 600 ? 1 : (left % 60) + 1
                try? await Task.sleep(for: .seconds(wait))
            }
        }
    }

    func stop() {
        ticking?.cancel()
        ticking = nil
    }

    func togglePause() {
        isPaused.toggle()
        if isPaused { stop() } else { start() }
    }

    /// Reads the deadline again: when the app comes back from the background.
    @discardableResult
    func sync() -> Int {
        guard let deadline else { return remaining }
        remaining = max(0, Int(deadline.timeIntervalSinceNow.rounded(.up)))
        return remaining
    }
}
