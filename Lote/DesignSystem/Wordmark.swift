import SwiftUI

/// The logotype: the gavel in amber and LOTE in Bricolage. The only text in the app set
/// in capitals. The amber is the brand here, not a call to act: it is the one place the
/// accent stands for the name instead of for "now".
struct Wordmark: View {
    var color: Color = Palette.ink

    var body: some View {
        HStack(spacing: 7) {
            BrandMark()
                .foregroundStyle(Palette.amber)
                .frame(width: 20, height: 20)
            Text("LOTE")
                .typeset(.wordmark)
                .foregroundStyle(color)
        }
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Lote")
        .accessibilityAddTraits(.isHeader)
    }
}

/// The brand's gavel over its block, the same geometry as the app icon
/// (docs/design-v3/make_icon.py). A template image: it takes the foreground style.
struct BrandMark: View {
    var body: some View {
        Image("BrandMark")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .accessibilityHidden(true)
    }
}
