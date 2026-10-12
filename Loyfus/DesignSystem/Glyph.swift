import SwiftUI

/// An icon: a symbol from SF Symbols, or one the app draws itself where SF Symbols has
/// nothing that says the same thing as Android's Material icon. A drawn glyph is a
/// template vector in the asset catalog, so it takes the foreground style like a symbol.
enum Glyph {
    case symbol(String)
    case drawn(String)

    /// "Aceita proposta". SF Symbols has no handshake, and a raised hand or two speech
    /// bubbles read as a different icon from Android's; this is Material's own path.
    static let handshake = Glyph.drawn("Handshake")

    /// The glyph at its place's size. A symbol is set by the point size of its font; a
    /// drawn glyph fills a box, the same box in points as Android's in dp, because the
    /// vector carries the Material margin inside its 24-unit square.
    @ViewBuilder
    func image(symbolSize: CGFloat, drawnSize: CGFloat, weight: Font.Weight = .semibold) -> some View {
        switch self {
        case .symbol(let name):
            Image(systemName: name)
                .font(.system(size: symbolSize, weight: weight))
        case .drawn(let name):
            Image(name)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: drawnSize, height: drawnSize)
        }
    }
}
