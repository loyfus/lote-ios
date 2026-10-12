import SwiftUI

// Bricolage Grotesque carries identity and titles, Inter Tight interface and figures. Both are
// static instances, one file per weight, shared byte-for-byte with Android: a variable file
// renders its default instance where axes cannot be pinned.
//
// A role is a size, a weight, a tracking and a line box, each size declared relative to a text
// style so the app follows the user's Dynamic Type setting (WCAG 1.4.4).
struct TypeRole {
    enum Face {
        case display, ui

        var family: String {
            switch self {
            case .display: return "Bricolage Grotesque"
            // The name must be "Inter Tight" (with the space): it is what groups
            // the four registered faces so .weight() selects a real member.
            case .ui: return "Inter Tight"
            }
        }

        /// Ascent + descent of the face, in em, read from its hhea table. SwiftUI
        /// lays a line out at this height, so a role's line box is this plus the
        /// leading computed below.
        var naturalLineHeight: CGFloat {
            switch self {
            case .display: return 1.2
            case .ui: return 1.21
            }
        }
    }

    let face: Face
    let size: CGFloat
    let weight: Font.Weight
    let textStyle: Font.TextStyle
    let tracking: CGFloat
    let lineHeight: CGFloat
    /// Figures that line up in columns and do not shimmer as a countdown ticks.
    var tabular = false

    var font: Font {
        let base = Font.custom(face.family, size: size, relativeTo: textStyle).weight(weight)
        return tabular ? base.monospacedDigit() : base
    }

    /// What has to be added to the face's own line height to reach the line box
    /// the design asks for. Zero when the face is already taller than the box.
    var extraLeading: CGFloat { max(0, lineHeight - size * face.naturalLineHeight) }

    private init(
        _ face: Face, _ size: CGFloat, _ weight: Font.Weight, _ textStyle: Font.TextStyle,
        tracking: CGFloat = 0, lineHeight: CGFloat, tabular: Bool = false
    ) {
        self.face = face
        self.size = size
        self.weight = weight
        self.textStyle = textStyle
        self.tracking = tracking
        self.lineHeight = lineHeight
        self.tabular = tabular
    }
}

// The roles of the design system, one line each: size/line box.
extension TypeRole {
    static let display = TypeRole(.display, 30, .semibold, .title, tracking: -0.6, lineHeight: 34)
    static let title = TypeRole(.display, 24, .semibold, .title2, tracking: -0.4, lineHeight: 29)
    static let titleLong = TypeRole(.display, 20, .semibold, .title3, tracking: -0.3, lineHeight: 26)
    static let headline = TypeRole(.display, 21, .semibold, .title3, tracking: -0.3, lineHeight: 26)
    static let section = TypeRole(.display, 19, .semibold, .title3, tracking: -0.2, lineHeight: 24)
    static let wordmark = TypeRole(.display, 19, .semibold, .title3, tracking: -0.2, lineHeight: 24)

    static let cardTitle = TypeRole(.ui, 15, .semibold, .subheadline, tracking: -0.1, lineHeight: 20)
    static let body = TypeRole(.ui, 16, .regular, .body, lineHeight: 24)
    static let bodyDense = TypeRole(.ui, 15, .regular, .subheadline, lineHeight: 22)
    static let small = TypeRole(.ui, 14, .regular, .subheadline, lineHeight: 20)
    static let smallStrong = TypeRole(.ui, 14, .semibold, .subheadline, lineHeight: 20)
    static let label = TypeRole(.ui, 14, .semibold, .subheadline, lineHeight: 18)
    static let caption = TypeRole(.ui, 12, .medium, .caption, lineHeight: 16)
    static let captionStrong = TypeRole(.ui, 12, .semibold, .caption, lineHeight: 16)
    static let button = TypeRole(.ui, 16, .semibold, .body, lineHeight: 20)

    static let priceTile = TypeRole(.ui, 18, .bold, .headline, tracking: -0.3, lineHeight: 22, tabular: true)
    static let priceRow = TypeRole(.ui, 17, .bold, .headline, lineHeight: 22, tabular: true)
    static let priceSticky = TypeRole(.ui, 21, .bold, .title3, tracking: -0.4, lineHeight: 25, tabular: true)
    static let priceHero = TypeRole(.ui, 34, .bold, .largeTitle, tracking: -1, lineHeight: 40, tabular: true)
}

// Sizes that the component specs (§5, §6) fix on their own: a tile's place line
// and caption at 13, a badge at 12.5, the decision card's deadline at 18. They
// reuse the two faces and the same text styles, so Dynamic Type treats them like
// the roles above.
extension TypeRole {
    /// Place line and price caption of a tile; card labels.
    static let meta = TypeRole(.ui, 13, .regular, .footnote, lineHeight: 18)
    static let metaMedium = TypeRole(.ui, 13, .medium, .footnote, lineHeight: 18)
    /// Kicker tags and removable filter tags.
    static let metaSemibold = TypeRole(.ui, 13, .semibold, .footnote, lineHeight: 18)
    /// Shelf subtitle.
    static let subtitle = TypeRole(.ui, 13.5, .regular, .footnote, lineHeight: 18)
    /// The note about where the values were read.
    static let note = TypeRole(.ui, 13.5, .regular, .footnote, lineHeight: 19)
    /// Time chip, photo counter.
    static let chip = TypeRole(.ui, 12.5, .semibold, .caption, lineHeight: 16, tabular: true)
    /// Caption under the sticky bar's price.
    static let stickyCaption = TypeRole(.ui, 12.5, .regular, .caption, lineHeight: 16, tabular: true)
    /// Deadline of the decision card.
    static let deadline = TypeRole(.ui, 18, .semibold, .headline, lineHeight: 24, tabular: true)
    /// Label and value of the summary grid.
    static let factLabel = TypeRole(.ui, 12.5, .medium, .caption, lineHeight: 16)
    static let factValue = TypeRole(.ui, 16, .semibold, .body, lineHeight: 22)
    /// Label under a category icon.
    static let categoryLabel = TypeRole(.ui, 12, .medium, .caption, lineHeight: 15)
    /// Count on a filter button or tab.
    static let badge = TypeRole(.ui, 12, .bold, .caption, lineHeight: 16, tabular: true)
    // Home's own sizes (§6 "Inicial"): the search pill, the shortcut labels, the
    // notice, the status cards and the budget card.
    /// Placeholder of the search door on the hero.
    static let pillText = TypeRole(.ui, 17, .regular, .body, lineHeight: 22)
    /// Label under a shortcut tile on the hero.
    static let shortcutLabel = TypeRole(.ui, 12.5, .medium, .caption2, lineHeight: 15)
    /// Title of the notice on the hero.
    static let noticeTitle = TypeRole(.display, 16, .semibold, .headline, lineHeight: 21)
    static let noticeText = TypeRole(.ui, 14, .regular, .subheadline, lineHeight: 19)
    /// The context line under the hero.
    static let contextLine = TypeRole(.ui, 12.5, .medium, .caption, lineHeight: 16, tabular: true)
    /// Value of a status card: a count, so the figures line up.
    static let cardValue = TypeRole(.ui, 21, .bold, .title3, tracking: -0.4, lineHeight: 26, tabular: true)
    static let cardLegend = TypeRole(.ui, 13, .regular, .footnote, lineHeight: 17)
    /// Title of the budget card.
    static let budgetTitle = TypeRole(.display, 18, .semibold, .headline, lineHeight: 23)
    /// Its price bands.
    static let budgetChip = TypeRole(.ui, 13.5, .semibold, .footnote, lineHeight: 18)
}

/// Gives a line box its half-leading above and below, the way the design's
/// line-heights do. `lineSpacing` alone only separates lines, so a single line
/// would come out shorter than the box the spacing around it was measured for.
private struct TypesetModifier: ViewModifier {
    @ScaledMetric private var leading: CGFloat

    init(_ role: TypeRole) {
        _leading = ScaledMetric(wrappedValue: role.extraLeading, relativeTo: role.textStyle)
    }

    func body(content: Content) -> some View {
        content
            .lineSpacing(leading)
            .padding(.vertical, leading / 2)
    }
}

extension Text {
    /// Face, size, weight, tracking and line box of a role, in one call.
    func typeset(_ role: TypeRole) -> some View {
        font(role.font)
            .tracking(role.tracking)
            .modifier(TypesetModifier(role))
    }
}
