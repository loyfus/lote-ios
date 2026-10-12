import SwiftUI

// MARK: - Kicker and title

/// What kind of lot this is, in tags above its title: the category, the kind of sale
/// and, when they apply, the condition, the proposal and the sale that already happened.
struct KickerTags: View {
    let content: DetailContent

    var body: some View {
        FlowLayout(spacing: Space.sm, lineSpacing: Space.sm) {
            if let category = content.category {
                KickerTag(text: category.label, glyph: .symbol(category.symbol), style: .neutral)
            }
            KickerTag(text: content.kind == .directSale ? "Venda direta" : "Leilão", style: .neutral)
            if let sold = content.soldLabel {
                KickerTag(text: sold, style: .sold)
            }
            if let condition = content.lot.conditionLabel, !condition.isEmpty {
                KickerTag(text: condition, style: .neutral)
            }
            if content.lot.acceptsProposal {
                KickerTag(text: "Aceita proposta", glyph: .handshake, style: .positive)
            }
        }
    }
}

private struct KickerTag: View {
    enum Style { case neutral, positive, sold }

    let text: String
    var glyph: Glyph?
    let style: Style

    var body: some View {
        HStack(spacing: 5) {
            if let glyph {
                glyph.image(symbolSize: 13, drawnSize: 16)
            }
            Text(text).typeset(.metaSemibold).lineLimit(1)
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, 11)
        .frame(minHeight: 28)
        .background(background, in: RoundedRectangle(cornerRadius: Radius.tag, style: .continuous))
    }

    private var foreground: Color {
        switch style {
        case .neutral: return Palette.ink80
        case .positive: return Palette.pine
        case .sold: return Palette.amberDeep
        }
    }

    private var background: Color {
        switch style {
        case .neutral: return Palette.paperDim
        case .positive: return Palette.pineSoft
        case .sold: return Palette.amberSoft
        }
    }
}

/// The cleaned title, and under it the part of the raw one that was an address.
struct TitleBlock: View {
    let content: DetailContent

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(content.title)
                .typeset(content.title.count > 70 ? .titleLong : .title)
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.leading)
                .accessibilityAddTraits(.isHeader)
            if let detail = content.titleDetail {
                Text(detail)
                    .typeset(.small)
                    .foregroundStyle(Palette.ink60)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Decision

/// The price, and what it takes to decide: how many bid, and when it ends. Amber
/// only when the lot closes within a day, and then in the price, the time and the bar
/// together, so the urgency never reaches the reader through colour alone: there is
/// also a clock, and the words.
struct DecisionCard: View {
    let content: DetailContent
    var clock: DeadlineClock

    var body: some View {
        let urgency = clock.urgency(for: content)
        let hot = urgency == .hot
        VStack(alignment: .leading, spacing: 0) {
            Text(content.priceLabel(urgency: urgency))
                .typeset(.metaMedium)
                .foregroundStyle(Palette.ink60)
            Text(Fmt.price(content.lot.currentPrice))
                .typeset(.priceHero)
                .foregroundStyle(
                    content.lot.currentPrice == nil ? Palette.ink60 : (hot ? Palette.amberText : Palette.ink)
                )
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.top, 2)
            Text(content.factsLine)
                .typeset(.small)
                .foregroundStyle(Palette.ink60)
                .padding(.top, 4)
            if urgency != .none {
                Hairline().padding(.vertical, Space.lg)
                deadline(urgency: urgency, hot: hot)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surface, in: shape)
        .overlay { shape.strokeBorder(Palette.line, lineWidth: 1) }
        .accessibilityElement(children: .contain)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Radius.decision, style: .continuous)
    }

    @ViewBuilder
    private func deadline(urgency: Urgency, hot: Bool) -> some View {
        let ended = urgency == .ended
        HStack(spacing: 10) {
            Image(systemName: "clock")
                .font(.system(size: 20))
                .foregroundStyle(Palette.ink60)
                .accessibilityHidden(true)
            Text(timeText(ended: ended))
                .typeset(.deadline)
                .foregroundStyle(hot ? Palette.amberText : (ended ? Palette.ink60 : Palette.ink))
            Spacer(minLength: 0)
            if clock.isRunning { pauseButton }
        }
        if let end = Fmt.endLabel(content.lot.endsAt) {
            Text(end)
                .typeset(.small)
                .foregroundStyle(Palette.ink60)
                .padding(.leading, 30)
                .padding(.top, 2)
        }
        if hot {
            // The bar is the final day, not the whole auction: it exists only inside the
            // window where the fraction has a fixed denominator.
            TimeBar(fraction: Double(clock.remaining) / Double(Urgency.hotWindow))
                .padding(.top, Space.md)
                .accessibilityHidden(true)
        }
    }

    private func timeText(ended: Bool) -> String {
        if ended { return "Encerrado" }
        switch content.kind {
        case .auction: return "Encerra em " + Fmt.timeLeftLive(clock.remaining)
        case .directSale: return "Disponível por " + Fmt.timeLeft(clock.remaining)
        }
    }

    private var pauseButton: some View {
        Button {
            clock.togglePause()
        } label: {
            Image(systemName: clock.isPaused ? "play.circle" : "pause.circle")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(Palette.ink60)
                // The glyph swaps with the system's replace effect instead of a cut.
                .contentTransition(.symbolEffect(.replace))
                .animation(Motion.change, value: clock.isPaused)
                .frame(width: Palette.touch, height: Palette.touch)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        // The number changes by itself, so it can be stopped (WCAG 2.2.2). The day and
        // hour the lot ends stay on the card either way.
        .accessibilityLabel(clock.isPaused ? "Retomar contagem regressiva" : "Pausar contagem regressiva")
        .accessibilityValue(clock.isPaused ? "pausada" : "em contagem")
        .padding(.trailing, -10)
    }
}

extension DeadlineClock {
    /// Urgency as it is right now, from the clock rather than from the response.
    func urgency(for content: DetailContent) -> Urgency {
        Urgency(kind: content.kind, secondsToClose: remaining, hasDeadline: content.lot.endsAt != nil)
    }
}

private struct TimeBar: View {
    let fraction: Double

    var body: some View {
        GeometryReader { proxy in
            Capsule()
                .fill(Palette.paperDim)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(Palette.amberText)
                        .frame(width: proxy.size.width * min(1, max(0, fraction)))
                }
        }
        .frame(height: 5)
    }
}

/// Where the numbers come from, and why to check them: the price has an age, and the
/// bid is placed somewhere else.
struct SourceNote: View {
    let content: DetailContent

    var body: some View {
        // The age ticks along with the clock, so "há 12 min" does not stay for an hour.
        TimelineView(.everyMinute) { context in
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "info.circle")
                    .font(.system(size: 18))
                    .foregroundStyle(Palette.ink60)
                    .accessibilityHidden(true)
                Text(text(now: context.date))
                    .typeset(.note)
                    .foregroundStyle(Palette.ink60)
            }
        }
        .padding(.horizontal, Space.xs)
        .padding(.top, 14)
        .accessibilityElement(children: .combine)
    }

    private func text(now: Date) -> String {
        let closing = content.kind == .directSale
            ? "A compra é feita no site do vendedor; confirme o preço lá."
            : "O lance é dado no site do leiloeiro; confirme o valor atual lá."
        guard let at = Fmt.clock(content.lot.syncedAt), let ago = Fmt.ago(content.lot.syncedAt, now: now) else {
            return closing
        }
        return "Valores lidos às \(at) (\(ago)). \(closing)"
    }
}

// MARK: - Sections

/// A titled part of the detail: Bricolage heading, 26 above it and 12 below.
struct DetailSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .typeset(.section)
                .foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 26)
    }
}

/// The four facts that matter most, as a grid of label over value.
struct SummaryGrid: View {
    let facts: [DetailContent.Fact]
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        LazyVGrid(
            columns: Array(
                repeating: GridItem(.flexible(), spacing: Space.lg, alignment: .topLeading),
                count: typeSize >= .xxxLarge ? 1 : 2),
            alignment: .leading,
            spacing: 14
        ) {
            ForEach(facts) { fact in
                VStack(alignment: .leading, spacing: 1) {
                    Text(fact.label).typeset(.factLabel).foregroundStyle(Palette.ink60)
                    Text(fact.value).typeset(.factValue).foregroundStyle(Palette.ink)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

/// Text cut to a few lines, with the way to read the rest. The button appears only
/// when something is actually cut: it is measured, not guessed from the length.
struct ExpandableText: View {
    let text: String
    var role: TypeRole = .bodyDense
    var collapsedLines = 5

    @State private var expanded = false
    @State private var fullHeight: CGFloat = 0
    @State private var shownHeight: CGFloat = 0

    private struct FullHeight: PreferenceKey {
        static let defaultValue: CGFloat = 0
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
    }

    private struct ShownHeight: PreferenceKey {
        static let defaultValue: CGFloat = 0
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
    }

    private var isCut: Bool { fullHeight > shownHeight + 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(text)
                .typeset(role)
                .foregroundStyle(Palette.ink80)
                .lineLimit(expanded ? nil : collapsedLines)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(key: ShownHeight.self, value: proxy.size.height)
                    }
                )
                .background(
                    // The same text with no limit, unseen, to know how tall it would be.
                    Text(text)
                        .typeset(role)
                        .fixedSize(horizontal: false, vertical: true)
                        .hidden()
                        .background(
                            GeometryReader { proxy in
                                Color.clear.preference(key: FullHeight.self, value: proxy.size.height)
                            }
                        )
                )
            if isCut || expanded {
                QuietButton(title: expanded ? "Mostrar menos" : "Ler mais", systemImage: expanded ? "chevron.up" : "chevron.down") {
                    withAnimation(.easeOut(duration: Motion.standard)) { expanded.toggle() }
                }
            }
        }
        .onPreferenceChange(ShownHeight.self) { if !expanded { shownHeight = $0 } }
        .onPreferenceChange(FullHeight.self) { fullHeight = $0 }
    }
}

/// The technical sheet: label and value, a rule between rows, eight rows before the
/// rest is a tap away.
struct SpecsList: View {
    let facts: [DetailContent.Fact]
    static let collapsedCount = 8

    @State private var showsAll = false
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let visible = showsAll ? facts : Array(facts.prefix(Self.collapsedCount))
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(visible.enumerated()), id: \.element.id) { index, fact in
                if index > 0 { Hairline() }
                row(fact)
            }
            if facts.count > Self.collapsedCount {
                QuietButton(
                    title: showsAll ? "Mostrar menos" : "Ver todas (\(facts.count))",
                    systemImage: showsAll ? "chevron.up" : "chevron.down"
                ) {
                    withAnimation(.easeOut(duration: Motion.standard)) { showsAll.toggle() }
                }
            }
        }
    }

    @ViewBuilder
    private func row(_ fact: DetailContent.Fact) -> some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 2) {
                    Text(fact.label).typeset(.small).foregroundStyle(Palette.ink60)
                    Text(fact.value).typeset(.smallStrong).foregroundStyle(Palette.ink)
                }
            } else {
                HStack(alignment: .top, spacing: Space.lg) {
                    Text(fact.label)
                        .typeset(.small)
                        .foregroundStyle(Palette.ink60)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(fact.value)
                        .typeset(.smallStrong)
                        .foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }
}

/// How the lot is bought, one condition to a line.
struct ConditionsList: View {
    let conditions: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            ForEach(conditions, id: \.self) { condition in
                HStack(alignment: .firstTextBaseline, spacing: Space.sm) {
                    Image(systemName: "checkmark")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Palette.ink60)
                        .accessibilityHidden(true)
                    Text(condition)
                        .typeset(.bodyDense)
                        .foregroundStyle(Palette.ink80)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

// MARK: - The auction

/// Who runs the sale, and how to reach them. The place printed here is the auction's
/// address, which is not where the item is: it is labelled so.
struct AuctionCard: View {
    let content: DetailContent
    @Environment(\.openURL) private var openURL
    @Environment(\.dynamicTypeSize) private var typeSize

    private var auction: AuctionInfo? { content.lot.auction }

    var body: some View {
        if let auction {
            let rows = rows(for: auction)
            if auction.title != nil || !rows.isEmpty || auction.noticeUrl != nil {
                VStack(alignment: .leading, spacing: 0) {
                    if let title = auction.title, !title.isEmpty {
                        Text(title)
                            .typeset(.cardTitle)
                            .foregroundStyle(Palette.ink)
                            .padding(.bottom, 6)
                    }
                    ForEach(rows, id: \.label) { row in
                        AuctionRow(label: row.label, values: row.values)
                    }
                    if let notice = auction.noticeUrl.flatMap(URL.init(string:)) {
                        SecondaryButton(title: "Abrir edital (PDF)", systemImage: "doc.text") {
                            openURL(notice)
                        }
                        .padding(.top, Space.md)
                    }
                }
                .padding(Space.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.surface, in: shape)
                .overlay { shape.strokeBorder(Palette.line, lineWidth: 1) }
            }
        }
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
    }

    private struct Row {
        let label: String
        let values: [AuctionRow.Value]
    }

    private func rows(for auction: AuctionInfo) -> [Row] {
        var rows: [Row] = []
        func add(_ label: String, _ value: String?) {
            guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return }
            rows.append(Row(label: label, values: [.init(text: value, link: nil)]))
        }
        add("Leiloeiro", auction.organizer)
        add("Responsável", auction.managerName)
        if let start = Fmt.endLabel(auction.startsAt), let end = Fmt.endLabel(auction.endsAt) {
            add("Período", "\(start) → \(end)")
        }
        let lot = content.lot
        let place = [lot.city, lot.stateCode]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " - ")
        add("Local do leilão", place)

        // One row for the contact, with a tap to write and a tap to call.
        var contact: [AuctionRow.Value] = []
        if let email = auction.contactEmail, !email.isEmpty {
            contact.append(.init(text: email, link: URL(string: "mailto:\(email)")))
        }
        if let phone = auction.contactPhone, !phone.isEmpty {
            let dialable = phone.filter { $0.isNumber || $0 == "+" }
            contact.append(.init(text: phone, link: URL(string: "tel:\(dialable)")))
        }
        if !contact.isEmpty { rows.append(Row(label: "Contato", values: contact)) }
        return rows
    }
}

private struct AuctionRow: View {
    struct Value {
        let text: String
        let link: URL?
    }

    let label: String
    let values: [Value]

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label).typeset(.small).foregroundStyle(Palette.ink60)
                    valueList(alignment: .leading)
                }
            } else {
                HStack(alignment: .top, spacing: Space.lg) {
                    Text(label).typeset(.small).foregroundStyle(Palette.ink60)
                    Spacer(minLength: 0)
                    valueList(alignment: .trailing)
                }
            }
        }
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func valueList(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 0) {
            ForEach(values, id: \.text) { value in
                if let link = value.link {
                    Link(destination: link) {
                        Text(value.text)
                            .typeset(.smallStrong)
                            .foregroundStyle(Palette.ink)
                            .underline()
                            .multilineTextAlignment(alignment == .leading ? .leading : .trailing)
                            .frame(minHeight: Palette.touch - 14)
                    }
                } else {
                    Text(value.text)
                        .typeset(.smallStrong)
                        .foregroundStyle(Palette.ink)
                        .multilineTextAlignment(alignment == .leading ? .leading : .trailing)
                }
            }
        }
    }
}

// MARK: - Sticky bar

/// The one action of a lot, always in reach: the price on the left, the way to the
/// auctioneer's site on the right. It rests on the paper with a rule over it, and
/// clears the home indicator.
struct StickyBar: View {
    let content: DetailContent
    var clock: DeadlineClock

    @Environment(\.openURL) private var openURL

    var body: some View {
        let urgency = clock.urgency(for: content)
        let link = content.lot.webUrl.flatMap(URL.init(string:))
        let price = Fmt.priceShort(content.lot.currentPrice)
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Space.lg) {
                priceBlock(price: price, urgency: urgency)
                cta(urgency: urgency, link: link)
            }
            VStack(alignment: .leading, spacing: Space.md) {
                priceBlock(price: price, urgency: urgency)
                cta(urgency: urgency, link: link)
            }
        }
        .padding(.horizontal, Space.gutter)
        .padding(.top, Space.md)
        .padding(.bottom, Space.sm)
        .frame(maxWidth: .infinity)
        .background(alignment: .bottom) {
            // Paper over a blur: what scrolls under the bar is not legible through it.
            Rectangle().fill(.ultraThinMaterial)
                .overlay(Palette.paper.opacity(0.94))
                .overlay(alignment: .top) { Hairline() }
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private func priceBlock(price: String, urgency: Urgency) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(price)
                .typeset(.priceSticky)
                .foregroundStyle(
                    content.lot.currentPrice == nil ? Palette.ink60 : (urgency == .hot ? Palette.amberText : Palette.ink)
                )
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(content.stickyCaption(urgency: urgency, remaining: clock.remaining))
                .typeset(.stickyCaption)
                .foregroundStyle(Palette.ink60)
                .lineLimit(1)
        }
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityElement(children: .combine)
    }

    private func cta(urgency: Urgency, link: URL?) -> some View {
        PrimaryButton(
            title: content.callToAction(urgency: urgency),
            systemImage: link == nil ? nil : "arrow.up.right.square",
            isEnabled: link != nil
        ) {
            if let link { openURL(link) }
        }
    }
}
