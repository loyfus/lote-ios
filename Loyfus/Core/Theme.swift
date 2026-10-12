import SwiftUI
import UIKit

// "Pregão": a night-blue ground that carries the brand, cool neutral paper so photographs
// keep their own colour, one amber accent for "act now", pine for what is alive. No other
// hue in text. Amber comes in two strengths because a fill is not a text colour: `amber` is
// the fill and carries `onAmber`, `amberText` is dark enough to write on paper — the fill
// itself measures 1.88:1 there.
//
// Every colour is declared for both appearances: a dark theme is not an inversion, so each
// role is restated, not flipped. Contrast pairs live in ../backend/tools/ui_audit.py.
enum Palette {
    static let ink = adaptive(0x0E1726, 0xEEF2F8)
    static let ink80 = adaptive(0x2F3A4B, 0xCBD3DF)
    static let ink60 = adaptive(0x586375, 0xA3ADBC)
    static let ink40 = adaptive(0x5E6879, 0x98A2B1)
    static let paper = adaptive(0xF6F7F9, 0x0A0E15)
    static let paperDim = adaptive(0xECEEF2, 0x1E2531)
    static let surface = adaptive(0xFFFFFF, 0x131925)
    // Hairline rule. WCAG 1.4.11 exempts purely decorative separators, so this
    // stays light; anything that identifies a control uses lineControl instead.
    static let line = adaptive(0xCDD3DC, 0x333C4B)
    // Border of a control: 3.42:1 on paper, 3.66:1 on surface, 3.15:1 on the dim
    // placeholder. Solved for the 3:1 of WCAG 1.4.11, not picked by eye.
    static let lineControl = adaptive(0x7D8698, 0x6B778B)
    // The accent as a fill: the primary button, the urgent time chip, the badges.
    static let amber = adaptive(0xF5A70A, 0xF7B733)
    // Content on the fill: near-black amber in both themes, 9.2 and 9.8:1.
    static let onAmber = adaptive(0x1A1200, 0x241800)
    // The accent as ink: an urgent price or time, the heart, the last-day bar, the
    // app's tint. 5.06:1 on paper in light; in dark the fill is light enough itself.
    static let amberText = adaptive(0xB54708, 0xF7B733)
    static let amberSoft = adaptive(0xFDEFD3, 0x4A3408)
    static let amberDeep = adaptive(0x7A3D00, 0xFFE2A1)
    static let pine = adaptive(0x13705A, 0x6FCBAE)
    static let pineSoft = adaptive(0xDCEFE8, 0x103D31)
    static let slate = adaptive(0x4A5568, 0xA7B0C0)
    static let slateSoft = adaptive(0xE8EBF0, 0x2B3038)
    // The ground of every badge that sits on a photograph. Photos can be white,
    // so the badge carries its own dark ground: white text on it holds 5.3:1 even
    // over a white photo, which a gradient behind the badge never guaranteed.
    static let scrim = adaptive(0x0E1726, alpha: 0.64, 0x000000, alpha: 0.68)
    // A filled heart lives on a white disc in both themes, so it keeps the light
    // theme's amberText instead of the lighter dark-theme one.
    static let heartOn = Color(uiColor: UIColor(hex: 0xB54708))
    // The hero of Home and the bar above it: night blue in both themes, and the only
    // gradient in the app. Only onHero and onHero80 write on it.
    static let heroTop = adaptive(0x14325A, 0x112A4D)
    static let heroBottom = adaptive(0x0C1E38, 0x0A1729)
    static let onHero = Color(uiColor: UIColor(hex: 0xF3F6FA))
    static let onHero80 = Color(uiColor: UIColor(hex: 0xC9D3E1))
    // The search pill's border on the hero: 3:1 against both ends of the gradient and
    // against the pill's own fill (.tools/ui_audit.py).
    static let heroControl = adaptive(0x7D8698, 0x8C97A8)
    // Frosted panel over the hero: the shortcuts and the notice. White at 9% / 16%.
    static let glass = Color.white.opacity(0.09)
    static let glassLine = Color.white.opacity(0.16)
    static let touch: CGFloat = 44

    /// One role, two appearances. UIKit resolves it per trait, so every view that
    /// reads a palette colour follows the system appearance without a branch.
    private static func adaptive(_ light: UInt32, alpha lightAlpha: CGFloat = 1,
                                 _ dark: UInt32, alpha darkAlpha: CGFloat = 1) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(hex: dark, alpha: darkAlpha)
                : UIColor(hex: light, alpha: lightAlpha)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

// A 4pt base scale. Spacing is the main tool for hierarchy in this app.
enum Space {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let x3: CGFloat = 32
    static let x4: CGFloat = 40
    static let x5: CGFloat = 56
    static let gutter: CGFloat = 20
}

// Radii are named for the thing they round, so a new component picks a role
// instead of a number.
enum Radius {
    /// Rectangular tags and badges.
    static let tag: CGFloat = 8
    /// Controls, and the photo of a row or a grid tile.
    static let control: CGFloat = 12
    /// Search field, buttons, price-range fields.
    static let field: CGFloat = 14
    /// Shelf photos and content cards.
    static let card: CGFloat = 16
    /// The decision card of the detail screen.
    static let decision: CGFloat = 18
    /// Top corners of a sheet.
    static let sheet: CGFloat = 24
}

// Motion budget, the same numbers and curves as Android's Motion.kt. Only the necessary: a
// press answers, content arrives, a lot opens from where it was, always short enough that the
// state changes at once and the motion only shows it. With Reduce Motion on nothing moves
// through space — slides, scales, pops and the pulse are left out, not squeezed.
enum Motion {
    /// A press going in: the answer has to start under the finger.
    static let pressIn: Double = 0.10
    /// A press letting go, a touch slower, so a tap reads as one gesture.
    static let pressOut: Double = 0.15
    /// A state changing in place: chip, colour, badge, counter, icon.
    static let fast: Double = 0.12
    /// Content arriving or leaving: photo fade-in, skeleton to content, expanding blocks, rows.
    static let standard: Double = 0.2
    /// A block closing up or opening and moving what is below it.
    static let collapseDuration: Double = 0.25
    /// Sheets and large-surface movement.
    static let slow: Double = 0.3
    /// The heart's pop: 1 → 1.25 → 1.
    static let heartPop: Double = 0.22
    /// Half a breath of a loading placeholder.
    static let pulse: Double = 0.9
    /// How long a notice stays before it goes by itself.
    static let notice: Double = 4

    /// Arriving: fast at first, settling at the end (Material's emphasized decelerate,
    /// the same curve as Android).
    static func enter(_ duration: Double = standard) -> Animation {
        .timingCurve(0.05, 0.7, 0.1, 1, duration: duration)
    }

    /// Leaving: gentle at first, then gone.
    static func exit(_ duration: Double = fast) -> Animation {
        .timingCurve(0.3, 0, 0.8, 0.15, duration: duration)
    }

    /// A change in place, neither arriving nor leaving.
    static let change = Animation.easeInOut(duration: fast)

    /// A block closing up or opening: on the standard curve, not the front-loaded enter
    /// one, because a layout that moves has to be seen moving.
    static let collapse = Animation.easeInOut(duration: collapseDuration)

    /// One state of a screen giving way to the next (skeleton, content, error): the new
    /// one fades in over the old. Used with `.transition(.opacity)` on each state.
    static let contentSwap = enter()
}

/// The loading placeholder breathes: the whole group dims to 55% and back over 1.8 s. It
/// says "on its way" without a sweep for the eye to follow, and stands still under
/// Reduce Motion.
struct SkeletonPulse: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dimmed = false

    func body(content: Content) -> some View {
        content
            .opacity(dimmed ? 0.55 : 1)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: Motion.pulse).repeatForever(autoreverses: true)) {
                    dimmed = true
                }
            }
    }
}

extension View {
    /// A loading placeholder's pulse (see SkeletonPulse).
    func skeletonPulse() -> some View { modifier(SkeletonPulse()) }
}

// Reading measure and grid. Past roughly 680pt body copy stops being a column and
// starts being lines of text nobody wants to read across an iPad; the grid, which
// has no lines to read, grows columns instead.
enum Measure {
    static let maxReadingWidth: CGFloat = 680

    /// 2 columns on a phone, 1 once text is large enough that a tile's price and
    /// caption would fight for the row, 3 from 600pt and 4 from 840pt.
    static func gridColumns(width: CGFloat, typeSize: DynamicTypeSize) -> Int {
        if typeSize >= .xxxLarge { return 1 }
        if width >= 840 { return 4 }
        if width >= 600 { return 3 }
        return 2
    }
}
