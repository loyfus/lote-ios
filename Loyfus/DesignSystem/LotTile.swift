import SwiftUI

/// A lot as a vitrine shows it: the photograph first, then three lines. No frame,
/// no background, no category, no status; the photo and the space around it do the
/// separating, and only the exceptional earns a badge.
///
/// The whole tile is one button with one spoken label. The heart is a button of its
/// own beside it, not inside it: a control nested in another control cannot be
/// reached by a screen reader.
struct LotTile: View {
    enum Variant {
        /// A rail on Home: 256 wide, 3:2.
        case shelf
        /// A cell of the Explore grid: the width of its column, 4:3.
        case grid

        var aspect: CGFloat { self == .shelf ? 3.0 / 2.0 : 4.0 / 3.0 }
        var radius: CGFloat { self == .shelf ? Radius.card : Radius.control }
    }

    let item: LotItem
    let variant: Variant
    let isFavourite: Bool
    /// Keeps every tile of a rail the same height, so the rail does not change
    /// height as tiles are created while it scrolls, and prices line up across it.
    var reservesPlaceLine = false
    let onOpen: () -> Void
    let onToggleFavourite: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: onOpen) { content }
                .buttonStyle(PressStyle(press: .surface))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(item.display.accessibilityLabel)
                .accessibilityHint("Abre o lote")
                // Ignoring the children drops the button's own trait with them; the tile
                // is a button, and VoiceOver has to say so.
                .accessibilityAddTraits(.isButton)
            // 36 visible, 44 to touch, and 8 from the corner of the photograph.
            HeartButton(
                isOn: isFavourite,
                label: item.display.heartLabel(isOn: isFavourite),
                action: onToggleFavourite
            )
            .padding(.top, 4)
            .padding(.trailing, 4)
        }
        .frame(width: variant == .shelf ? 256 : nil)
    }

    /// Two lines at most. In a rail the room for both is kept even when the title
    /// needs one, so that every tile has the same height; `lineLimit(reservesSpace:)`
    /// is not used for this, because it also stops a long title at its first line.
    private func title(_ text: String) -> some View {
        ZStack(alignment: .topLeading) {
            if variant == .shelf {
                Text("A\nA").typeset(.cardTitle).hidden().accessibilityHidden(true)
            }
            Text(text)
                .typeset(.cardTitle)
                .foregroundStyle(Palette.ink)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var content: some View {
        let display = item.display
        return VStack(alignment: .leading, spacing: 0) {
            PhotoPlate(url: item.lot.primaryImageUrl, aspect: variant.aspect, radius: variant.radius) {
                if let chip = display.chip {
                    TimeChip(chip: chip)
                        .padding(10)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                }
            }
            VStack(alignment: .leading, spacing: 0) {
                title(display.title)
                if let place = display.place {
                    Text(place)
                        .typeset(.meta)
                        .foregroundStyle(Palette.ink60)
                        .lineLimit(1)
                        .padding(.top, 2)
                } else if reservesPlaceLine {
                    Text("\u{00A0}")
                        .typeset(.meta)
                        .padding(.top, 2)
                        .accessibilityHidden(true)
                }
                PriceLine(display: display)
                    .padding(.top, 6)
            }
            .padding(.top, 10)
            .padding(.horizontal, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
    }
}

/// The price, with its caption on the baseline beside it. When the two do not fit on
/// one line (a seven-figure price in a narrow column, or large text) the caption
/// moves under the price instead of squeezing it: a clipped price is worse than a
/// stacked one.
struct PriceLine: View {
    let display: LotDisplay

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: Space.sm) {
                price
                caption
            }
            VStack(alignment: .leading, spacing: 0) {
                price
                caption
            }
        }
    }

    private var price: some View {
        Text(display.price)
            .typeset(.priceTile)
            .foregroundStyle(
                display.priceIsRequest ? Palette.ink60 : (display.isHot ? Palette.amberText : Palette.ink)
            )
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }

    @ViewBuilder
    private var caption: some View {
        if let text = display.caption {
            Text(text)
                .typeset(.meta)
                .foregroundStyle(Palette.ink60)
                .lineLimit(1)
        }
    }
}

/// A saved lot: a line, not a tile. Photo 104 x 78, the title on two lines, the
/// price and the time left, and a filled heart to take it back out.
struct SavedRow: View {
    let item: LotItem
    let onOpen: () -> Void
    let onRemove: () -> Void

    var body: some View {
        let display = item.display
        HStack(spacing: 0) {
            Button(action: onOpen) {
                HStack(spacing: 14) {
                    PhotoPlate(url: item.lot.primaryImageUrl, radius: Radius.control)
                        .frame(width: 104, height: 78)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(display.title)
                            .typeset(.cardTitle)
                            .foregroundStyle(Palette.ink)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        priceAndTime(display)
                            .padding(.top, 6)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PressStyle(press: .surface))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(display.accessibilityLabel)
            .accessibilityHint("Abre o lote")
            .accessibilityAddTraits(.isButton)

            Button(action: onRemove) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 22))
                    // The disc-less heart sits on paper, so it takes the amber that can
                    // write there, not the fill (1.88:1 on paper).
                    .foregroundStyle(Palette.amberText)
                    .frame(width: Palette.touch, height: Palette.touch)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressStyle())
            .accessibilityLabel(display.heartLabel(isOn: true))
            .padding(.leading, 4)
            .padding(.trailing, -10)
        }
        .padding(.horizontal, Space.gutter)
        .padding(.vertical, Space.md)
    }

    @ViewBuilder
    private func priceAndTime(_ display: LotDisplay) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.sm) {
            Text(display.price)
                .typeset(.priceRow)
                .foregroundStyle(display.priceIsRequest ? Palette.ink60 : Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            switch display.rowTime {
            case .clock(let text, let hot)?:
                HStack(spacing: 3) {
                    Image(systemName: "clock").font(.system(size: 12, weight: .semibold))
                    Text(text).typeset(.chip)
                }
                .foregroundStyle(hot ? Palette.amberText : Palette.ink60)
                .lineLimit(1)
            case .directSale?:
                Text("Venda direta").typeset(.chip).foregroundStyle(Palette.ink60).lineLimit(1)
            case nil:
                EmptyView()
            }
        }
    }
}
