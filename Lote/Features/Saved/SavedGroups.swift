import Foundation

/// The groups Saved lists its lots in, by how soon each one needs attention.
enum SavedGroup: CaseIterable {
    /// Closes within 24 hours.
    case today
    /// Closes within 7 days.
    case week
    /// Everything else: further away, a direct sale, or no deadline at all.
    case later
    case ended

    var title: String {
        switch self {
        case .today: return "Encerram hoje"
        case .week: return "Esta semana"
        case .later: return "Mais tarde"
        case .ended: return "Encerrados"
        }
    }

    /// The lot's group. A direct sale has no hammer coming down, so it is never
    /// "today" or "this week"; it waits in "later" until it has ended.
    static func of(_ lot: LotSummary) -> SavedGroup {
        switch lot.urgency {
        case .ended: return .ended
        case .none: return .later
        case .hot: return .today
        case .normal:
            if lot.kind == .directSale { return .later }
            return lot.secondsToClose <= 7 * 86_400 ? .week : .later
        }
    }
}

struct SavedSection: Identifiable {
    let group: SavedGroup
    let items: [LotItem]

    var id: SavedGroup { group }

    /// Groups in the order above, empty ones left out, each by deadline, soonest
    /// first. A lot without a deadline sorts after the ones that have one.
    static func make(from items: [LotItem]) -> [SavedSection] {
        let grouped = Dictionary(grouping: items) { SavedGroup.of($0.lot) }
        return SavedGroup.allCases.compactMap { group in
            guard let members = grouped[group], !members.isEmpty else { return nil }
            let sorted = members.enumerated().sorted { lhs, rhs in
                let (left, right) = (key(lhs.element.lot), key(rhs.element.lot))
                return left == right ? lhs.offset < rhs.offset : left < right
            }
            return SavedSection(group: group, items: sorted.map(\.element))
        }
    }

    private static func key(_ lot: LotSummary) -> Int {
        lot.secondsToClose > 0 ? lot.secondsToClose : .max
    }
}
