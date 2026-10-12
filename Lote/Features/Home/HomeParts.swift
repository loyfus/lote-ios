import SwiftUI

/// The gradient behind Home: night blue, top to bottom. It starts at the bar's own
/// colour, so the bar and the hero read as one ground with no seam between them.
enum Hero {
    static let gradient = LinearGradient(
        colors: [Palette.heroTop, Palette.heroBottom],
        startPoint: .top, endPoint: .bottom)

    /// A pill of 4.691 lotes, with the noun that follows the number.
    static func lots(_ count: Int) -> String {
        "\(Fmt.thousands(count)) \(count == 1 ? "lote" : "lotes")"
    }
}

/// The header every phone app has: the menu on the left, the mark in the middle and
/// the settings on the right. It is the system's navigation bar in the hero's night
/// blue with a dark colour scheme, which is what gives the status bar white content in
/// the light theme too; it does not scroll, so the menu is always one tap away.
struct HomeToolbar: ToolbarContent {
    let onOpenMenu: () -> Void
    let onOpenSettings: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button(action: onOpenMenu) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Palette.onHero)
            }
            .accessibilityLabel("Abrir menu")
        }
        ToolbarItem(placement: .principal) {
            Wordmark(color: Palette.onHero)
        }
        ToolbarItem(placement: .topBarTrailing) {
            // There is no account to sign into, so this corner is not an avatar: it is
            // the app's settings, where the theme, the device's data and "Sobre" live.
            Button(action: onOpenSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(Palette.onHero)
            }
            .accessibilityLabel("Configurações")
        }
    }
}

/// The search door: a button, not a field. Tapping it opens Explore with the keyboard.
struct SearchPill: View {
    let action: () -> Void

    private let shape = Capsule(style: .continuous)

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.md) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Palette.ink)
                Text("Buscar carro, imóvel, máquina…")
                    .typeset(.pillText)
                    .foregroundStyle(Palette.ink60)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Space.xl)
            .frame(minHeight: 54)
            .background(Palette.surface, in: shape)
            // heroControl: 3:1 against both ends of the night blue and against the
            // pill's own fill, so the pill reads as a control in both themes.
            .overlay { shape.strokeBorder(Palette.heroControl, lineWidth: 1) }
            .contentShape(shape)
        }
        .buttonStyle(PressStyle(press: .surface))
        .accessibilityLabel("Buscar lotes")
    }
}

/// The categories as frosted tiles, and Todas at the end of the row.
struct ShortcutRow: View {
    let categories: [Category]
    let onSelect: (Category) -> Void
    let onSelectAll: () -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: Space.sm) {
                ForEach(categories) { category in
                    shortcut(
                        label: Categories.style(for: category.name).label,
                        symbol: Categories.style(for: category.name).symbol,
                        action: { onSelect(category) },
                        spoken: Categories.style(for: category.name).label)
                }
                shortcut(
                    label: "Todas",
                    symbol: "square.grid.2x2",
                    action: onSelectAll,
                    spoken: "Todas as categorias")
            }
            .padding(.horizontal, Space.gutter)
        }
        .scrollIndicators(.hidden)
    }

    private func shortcut(label: String, symbol: String, action: @escaping () -> Void, spoken: String) -> some View {
        Button(action: action) {
            VStack(spacing: Space.sm) {
                Image(systemName: symbol)
                    .font(.system(size: 26))
                    .foregroundStyle(Palette.onHero80)
                    .frame(width: 64, height: 64)
                    .background(Palette.glass, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(Palette.glassLine, lineWidth: 1)
                    }
                Text(label)
                    .typeset(.shortcutLabel)
                    .foregroundStyle(Palette.onHero80)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: true, vertical: false)
            }
            // 74, or as wide as the longest word of the label needs: a word is never
            // broken in the middle, however large the reader's text.
            .frame(minWidth: 74)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(spoken)
    }
}

/// The one notice the app makes, and the only one it can take back.
struct NoticeBanner: View {
    let onOpenAbout: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Space.md) {
            // The brand's own gavel on its amber: the notice is the app saying what it is.
            BrandMark()
                .foregroundStyle(Palette.onAmber)
                .frame(width: 22, height: 22)
                .frame(width: 40, height: 40)
                .background(Palette.amber, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .accessibilityHidden(true)

            Button(action: onOpenAbout) {
                VStack(alignment: .leading, spacing: Space.xxs) {
                    Text("Como funciona")
                        .typeset(.noticeTitle)
                        .foregroundStyle(Palette.onHero)
                    Text("Reunimos lotes de leilões do Brasil. O lance é dado no site do leiloeiro.")
                        .typeset(.noticeText)
                        .foregroundStyle(Palette.onHero80)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressStyle(press: .surface))
            .accessibilityLabel("Como funciona. Abrir sobre o Lote")

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Palette.onHero80)
                    .frame(width: Palette.touch, height: Palette.touch)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressStyle())
            .accessibilityLabel("Dispensar aviso")
        }
        .padding(.leading, Space.md)
        .padding(.trailing, 6)
        .padding(.vertical, Space.md)
        .background(Palette.glass, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Palette.glassLine, lineWidth: 1)
        }
        .padding(.leading, Space.lg)
        .padding(.trailing, Space.sm + Space.sm)
    }
}

/// How fresh the catalogue is and how big it is: one line, under the hero.
struct ContextLine: View {
    let updatedAt: String?
    let totalLots: Int

    var body: some View {
        TimelineView(.everyMinute) { context in
            let fresh = (Fmt.minutesSince(updatedAt, now: context.date) ?? .max) <= 60
            HStack(spacing: 7) {
                Circle()
                    .fill(fresh ? Palette.pine : Palette.ink40)
                    .frame(width: 7, height: 7)
                    .accessibilityHidden(true)
                Text(text(now: context.date))
                    .typeset(.contextLine)
                    .foregroundStyle(Palette.ink60)
                    .lineLimit(1)
            }
            .padding(.horizontal, Space.gutter)
            .padding(.bottom, 14)
        }
    }

    private func text(now: Date) -> String {
        guard let stamp = Fmt.ago(updatedAt, now: now) else { return Hero.lots(totalLots) }
        return "\(Hero.lots(totalLots)) · atualizado \(stamp)"
    }
}

/// A number the reader can act on: what is closing, and who takes an offer.
struct StatusCard: View {
    let title: String
    let value: String
    let legend: String
    let icon: Glyph
    let accent: Color
    let onAccent: Color
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                icon.image(symbolSize: 19, drawnSize: 22)
                    .foregroundStyle(onAccent)
                    .frame(width: 40, height: 40)
                    .background(accent, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .padding(.bottom, Space.sm)
                    .accessibilityHidden(true)
                Text(title)
                    .typeset(.cardTitle)
                    .foregroundStyle(Palette.ink)
                    .padding(.bottom, Space.xxs)
                Text(value)
                    .typeset(.cardValue)
                    .foregroundStyle(Palette.ink)
                Spacer(minLength: Space.xxs)
                Text(legend)
                    .typeset(.cardLegend)
                    .foregroundStyle(Palette.ink60)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
            .padding(Space.md)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Palette.line, lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle(press: .surface))
        .accessibilityLabel(label)
    }
}

/// The two cards side by side. Without a closing window the first one is not drawn.
struct StatusCards: View {
    let closing: HomeResponse.ClosingWindow?
    let acceptsProposal: Int
    let onOpenClosing: (HomeResponse.ClosingWindow) -> Void
    let onOpenOffers: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Space.md) {
            if let closing {
                StatusCard(
                    title: "Fecham em breve",
                    value: Hero.lots(closing.count),
                    legend: legend,
                    icon: .symbol("clock"),
                    accent: Palette.amberSoft,
                    onAccent: Palette.amberDeep,
                    label: "Fecham em breve: \(Hero.lots(closing.count)) \(legend)",
                    action: { onOpenClosing(closing) })
            }
            StatusCard(
                title: "Aceitam proposta",
                value: Hero.lots(acceptsProposal),
                legend: "negocie o preço",
                icon: .handshake,
                accent: Palette.pineSoft,
                onAccent: Palette.pine,
                label: "Aceitam proposta: \(Hero.lots(acceptsProposal)). Negocie o preço",
                action: onOpenOffers)
        }
        .padding(.horizontal, Space.gutter)
    }

    private var legend: String {
        switch closing?.withinHours {
        case 24: return "nas próximas 24 h"
        case 72: return "em até 3 dias"
        default: return "em até 7 dias"
        }
    }
}

/// "Quanto você quer gastar?" and the five bands that answer it.
struct BudgetCard: View {
    let onPick: (Int?, Int?) -> Void

    private static let bands: [(title: String, min: Int?, max: Int?)] = [
        ("Até 1 mil", nil, 1_000),
        ("1 – 10 mil", 1_000, 10_000),
        ("10 – 50 mil", 10_000, 50_000),
        ("50 – 200 mil", 50_000, 200_000),
        ("Acima de 200 mil", 200_000, nil),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Text("Quanto você quer gastar?")
                .typeset(.budgetTitle)
                .foregroundStyle(Palette.ink)
            FlowLayout(spacing: Space.sm, lineSpacing: Space.sm) {
                ForEach(Self.bands, id: \.title) { band in
                    Button { onPick(band.min, band.max) } label: {
                        Text(band.title)
                            .typeset(.budgetChip)
                            .foregroundStyle(Palette.ink)
                            .padding(.horizontal, 13)
                            .frame(minHeight: 38)
                            .background(Capsule().strokeBorder(Palette.lineControl, lineWidth: 1))
                    }
                    .buttonStyle(PressStyle())
                    .accessibilityLabel("\(band.title) reais")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.lg)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Palette.line, lineWidth: 1)
        }
        .padding(.horizontal, Space.gutter)
        .padding(.top, Space.md)
    }
}
