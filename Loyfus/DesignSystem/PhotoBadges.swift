import SwiftUI

/// The badge on a photograph: the time left, or the one word that says what is unusual
/// ("Venda direta", "Encerrado"). Decorative to a screen reader — the tile's label says it.
///
/// It sits on the scrim so white text holds contrast over any photograph; only a lot under 24
/// hours trades the scrim for amber.
struct TimeChip: View {
    let chip: LotDisplay.Chip

    @ScaledMetric(relativeTo: .caption) private var iconSize: CGFloat = 13

    var body: some View {
        HStack(spacing: 5) {
            switch chip {
            case .time(let text, _):
                Image(systemName: "clock").font(.system(size: iconSize, weight: .semibold))
                Text(text).typeset(.chip)
            case .label(let text):
                Text(text).typeset(.chip)
            }
        }
        .lineLimit(1)
        .foregroundStyle(isHot ? Palette.onAmber : Color.white)
        .padding(.leading, hasClock ? 8 : 10)
        .padding(.trailing, 10)
        .frame(minHeight: 26)
        .background(isHot ? Palette.amber : Palette.scrim, in: Capsule())
        .accessibilityHidden(true)
    }

    private var isHot: Bool {
        if case .time(_, let hot) = chip { return hot }
        return false
    }

    private var hasClock: Bool {
        if case .time = chip { return true }
        return false
    }
}

/// The favourite toggle. 36 across on a tile, 42 on the detail's photograph, 44 to
/// touch. Off, a white outline on the scrim; on, a filled heart on a white disc, so
/// the state is never carried by colour alone: the shape changes too.
struct HeartButton: View {
    let isOn: Bool
    /// "Favoritar {título}" / "Remover dos favoritos: {título}".
    let label: String
    var diameter: CGFloat = 36
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pops = 0

    var body: some View {
        Button(action: action) {
            // The disc turns white and the heart amber in 120 ms under the pop, and the
            // symbol swaps with the system's replace effect: the shape (outlined or
            // filled) carries the state, the colour only follows it.
            ZStack {
                Circle().fill(isOn ? Color.white : Palette.scrim)
                Image(systemName: isOn ? "heart.fill" : "heart")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(isOn ? Palette.heartOn : Color.white)
                    .contentTransition(.symbolEffect(.replace))
            }
            .animation(Motion.change, value: isOn)
            .frame(width: diameter, height: diameter)
            .phaseAnimator(popScales, trigger: pops) { content, scale in
                content.scaleEffect(reduceMotion ? 1 : scale)
            } animation: { scale in
                scale > 1 ? Motion.enter(Motion.heartPop / 2) : .easeInOut(duration: Motion.heartPop / 2)
            }
            .frame(width: Palette.touch, height: Palette.touch)
            .contentShape(Circle())
        }
        .buttonStyle(PressStyle())
        .onChange(of: isOn) { _, nowOn in
            if nowOn { pops += 1 }
        }
        .sensoryFeedback(trigger: isOn) { _, nowOn in
            nowOn ? .impact(weight: .medium) : .impact(weight: .light)
        }
        .accessibilityLabel(label)
    }

    private let popScales: [CGFloat] = [1, 1.25, 1]
}
