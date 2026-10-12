import Foundation

enum LotKind: Equatable {
    case auction
    case directSale
}

/// How close a lot is to its end, as far as the design colours it.
enum Urgency: Equatable {
    /// No deadline at all.
    case none
    case normal
    /// Closes within 24 hours. Only an auction can be hot.
    case hot
    case ended
}

/// What a lot says about time, whichever shape it arrives in.
protocol LotTimeline {
    var modality: String? { get }
    var secondsToClose: Int { get }
    var endsAt: String? { get }
}

extension LotTimeline {
    var kind: LotKind { modality == "AFTER_MARKET" ? .directSale : .auction }

    var urgency: Urgency {
        Urgency(kind: kind, secondsToClose: secondsToClose, hasDeadline: endsAt != nil)
    }
}

extension Urgency {
    static let hotWindow = 86_400

    init(kind: LotKind, secondsToClose seconds: Int, hasDeadline: Bool) {
        if seconds <= 0 {
            self = hasDeadline ? .ended : .none
        } else if kind == .directSale {
            self = .normal
        } else {
            self = seconds <= Urgency.hotWindow ? .hot : .normal
        }
    }
}

/// Everything a tile or a row prints about a lot, worked out once when the lot is
/// loaded. The models stay exactly as the API sent them; a body that formatted a
/// price and cleaned a title on every evaluation would do it for every visible cell
/// on every scroll frame.
struct LotDisplay: Equatable {
    /// What the photo's time badge says.
    enum Chip: Equatable {
        case time(String, hot: Bool)
        case label(String)
    }

    /// What a saved row says about time.
    enum RowTime: Equatable {
        case clock(String, hot: Bool)
        case directSale
    }

    let title: String
    /// The real place of the item, when the seller wrote it into the title.
    let place: String?
    let price: String
    let priceIsRequest: Bool
    let isHot: Bool
    let caption: String?
    let chip: Chip?
    let rowTime: RowTime?
    let accessibilityLabel: String

    init(_ lot: LotSummary) {
        let tidy = TitleCache.tidy(lot.title)
        let kind = lot.kind
        let urgency = lot.urgency
        let seconds = lot.secondsToClose

        title = tidy.headline.isEmpty ? lot.title : tidy.headline
        place = Fmt.place(tidy.detail)
        price = Fmt.priceShort(lot.currentPrice)
        priceIsRequest = lot.currentPrice == nil
        isHot = urgency == .hot

        switch kind {
        case .auction: caption = Fmt.bids(lot.bidCount)
        // The photo's badge already says "Venda direta"; saying it twice is noise.
        case .directSale: caption = lot.acceptsProposal ? "Aceita proposta" : nil
        }

        switch urgency {
        case .ended:
            chip = .label("Encerrado")
            rowTime = .clock("Encerrado", hot: false)
        case .hot:
            chip = .time(Fmt.timeLeft(seconds), hot: true)
            rowTime = .clock(Fmt.timeLeft(seconds), hot: true)
        case .normal, .none:
            if kind == .directSale {
                chip = .label("Venda direta")
                rowTime = .directSale
            } else if urgency == .normal {
                chip = .time(Fmt.timeLeft(seconds), hot: false)
                rowTime = .clock(Fmt.timeLeft(seconds), hot: false)
            } else {
                chip = nil
                rowTime = nil
            }
        }

        // The badge is decorative to a screen reader, so the label carries what it
        // says: the kind of sale and the time left.
        var parts = [title, price]
        switch kind {
        case .auction:
            parts.append(Fmt.bids(lot.bidCount))
        case .directSale:
            parts.append("venda direta")
            if lot.acceptsProposal { parts.append("aceita proposta") }
        }
        switch urgency {
        case .ended: parts.append("encerrado")
        case .hot, .normal: parts.append("encerra em " + Fmt.timeLeftSpoken(seconds))
        case .none: break
        }
        accessibilityLabel = parts.joined(separator: ", ")
    }

    func heartLabel(isOn: Bool) -> String {
        isOn ? "Remover dos favoritos: \(title)" : "Favoritar \(title)"
    }
}

/// A lot together with its display values: what every list holds.
struct LotItem: Identifiable, Equatable {
    let lot: LotSummary
    let display: LotDisplay

    var id: Long { lot.id }

    init(_ lot: LotSummary) {
        self.lot = lot
        display = LotDisplay(lot)
    }

    static func == (lhs: LotItem, rhs: LotItem) -> Bool { lhs.lot == rhs.lot }
}

/// Title cleanup is a handful of regular expressions; the same lot turns up on Home,
/// in Explore and in Saved, so the result is kept by the raw title.
enum TitleCache {
    private final class Box {
        let value: TitleTidy.Result
        init(_ value: TitleTidy.Result) { self.value = value }
    }

    private static let cache: NSCache<NSString, Box> = {
        let cache = NSCache<NSString, Box>()
        cache.countLimit = 2_000
        return cache
    }()

    static func tidy(_ raw: String) -> TitleTidy.Result {
        let key = raw as NSString
        if let hit = cache.object(forKey: key) { return hit.value }
        let result = TitleTidy.tidy(raw)
        cache.setObject(Box(result), forKey: key)
        return result
    }
}
