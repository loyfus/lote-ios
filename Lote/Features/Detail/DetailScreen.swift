import SwiftUI

/// A lot, from its photographs to the button that takes the buyer to the auctioneer.
///
/// The system's bars are hidden: the photograph runs under the status bar, with
/// controls floating on it, and once it has scrolled away a bar of the screen's own
/// takes its place. The action the whole screen exists for lives in a bar at the foot.
struct DetailScreen: View {
    let lotId: Long

    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    private enum Phase {
        case loading
        case loaded(DetailContent)
        case notFound
        case failed(String)
    }

    @State private var phase: Phase = .loading

    /// Which of its faces the lot shows, for the cross-fade between them.
    private var phaseKey: Int {
        switch phase {
        case .loading: return 0
        case .loaded: return 1
        case .notFound: return 2
        case .failed: return 3
        }
    }
    @State private var clock = DeadlineClock(secondsToClose: -1)
    @State private var photoIndex = 0
    @State private var showsViewer = false
    @State private var showsTopBar = false

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                Palette.paper.ignoresSafeArea()
                switch phase {
                case .loading:
                    DetailSkeleton(galleryHeight: galleryHeight(in: proxy))
                        .skeletonPulse()
                        .ignoresSafeArea(.container, edges: .top)
                case .loaded(let content):
                    scroll(content, in: proxy)
                case .notFound:
                    failure(
                        symbol: "magnifyingglass",
                        title: "Lote não encontrado",
                        message: "Este lote pode ter sido removido da fonte desde a última atualização.",
                        actionTitle: "Voltar", in: proxy
                    ) { dismiss() }
                case .failed(let message):
                    failure(
                        symbol: "wifi.slash",
                        title: "Não foi possível carregar",
                        message: message,
                        actionTitle: "Tentar novamente", in: proxy
                    ) { Task { await load() } }
                }
                chrome(in: proxy)
            }
            // The skeleton has the lot's geometry, so the lot fades in over it without
            // anything moving. Keyed by the phase: a favourite or a fresh read does not
            // fade the screen.
            .animation(Motion.contentSwap, value: phaseKey)
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .background(SwipeBackEnabler())
        .fullScreenCover(isPresented: $showsViewer) {
            if case .loaded(let content) = phase {
                PhotoViewer(images: content.lot.images, shareText: content.shareText, index: $photoIndex)
            }
        }
        .task(id: lotId) { await load() }
        .onAppear { clock.start() }
        .onDisappear { clock.stop() }
        .onChange(of: scenePhase) { _, now in
            if now == .active { clock.sync() }
        }
    }

    // MARK: Loading

    private func load() async {
        do {
            let lot = try await store.repository.lot(lotId)
            guard !Task.isCancelled else { return }
            clock.stop()
            clock = DeadlineClock(secondsToClose: lot.secondsToClose)
            phase = .loaded(DetailContent(lot))
            store.reconcile(id: lot.id, isFavourite: lot.isFavourite)
            clock.start()
        } catch {
            if AppStore.wasCancelled(error) { return }
            switch LoadFailure.classify(error) {
            case .notFound: phase = .notFound
            case .offline(let message): phase = .failed(message)
            }
        }
    }

    // MARK: Layout

    /// The photograph's share of the screen: four fifths of the width, but never more
    /// than 42% of the window, between 200 and 360. In landscape a fixed plate would
    /// swallow the whole screen.
    private func galleryHeight(in proxy: GeometryProxy) -> CGFloat {
        let window = proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom
        return min(max(min(proxy.size.width * 0.8, window * 0.42), 200), 360)
    }

    private func scroll(_ content: DetailContent, in proxy: GeometryProxy) -> some View {
        let lot = content.lot
        let barThreshold = proxy.safeAreaInsets.top + 44
        return ScrollView {
            VStack(spacing: 0) {
                DetailGallery(
                    images: lot.images,
                    height: galleryHeight(in: proxy),
                    index: $photoIndex,
                    onOpen: { showsViewer = true }
                )
                .background(
                    // Where the photograph ends tells when its place is to be taken by
                    // the bar. The state changes only when it crosses the bar, not on
                    // every frame of the scroll.
                    GeometryReader { geometry in
                        Color.clear.onChange(of: geometry.frame(in: .global).maxY, initial: true) { _, bottom in
                            let collapsed = bottom < barThreshold
                            if collapsed != showsTopBar { showsTopBar = collapsed }
                        }
                    }
                )

                VStack(alignment: .leading, spacing: 0) {
                    KickerTags(content: content)
                    TitleBlock(content: content).padding(.top, Space.md)
                    DecisionCard(content: content, clock: clock).padding(.top, 18)
                    SourceNote(content: content)

                    if !content.summary.isEmpty {
                        DetailSection(title: "Resumo") { SummaryGrid(facts: content.summary) }
                    }
                    if let description = lot.description, !description.isEmpty {
                        DetailSection(title: "Descrição") { ExpandableText(text: description) }
                    }
                    if !content.facts.isEmpty {
                        DetailSection(title: "Ficha técnica") { SpecsList(facts: content.facts) }
                    }
                    if !content.conditions.isEmpty {
                        DetailSection(title: "Condições de compra") { ConditionsList(conditions: content.conditions) }
                    }
                    if lot.auction != nil {
                        DetailSection(title: "Sobre o leilão") { AuctionCard(content: content) }
                    }
                }
                .padding(.horizontal, Space.gutter)
                .padding(.top, Space.lg)
                .padding(.bottom, Space.xxl)
                .frame(maxWidth: Measure.maxReadingWidth)
                .frame(maxWidth: .infinity)
            }
        }
        .ignoresSafeArea(.container, edges: .top)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            StickyBar(content: content, clock: clock)
        }
        .scrollIndicators(.hidden)
    }

    private func failure(
        symbol: String, title: String, message: String, actionTitle: String, in proxy: GeometryProxy,
        action: @escaping () -> Void
    ) -> some View {
        ScrollView {
            StateView(symbol: symbol, title: title, message: message, actionTitle: actionTitle, action: action)
                .padding(.top, proxy.safeAreaInsets.top + 60)
        }
    }

    // MARK: Controls over the photograph

    private var content: DetailContent? {
        if case .loaded(let content) = phase { return content }
        return nil
    }

    /// Back, share and favourite float over the photograph; once it has scrolled away
    /// a bar of paper takes their place, with the title.
    @ViewBuilder
    private func chrome(in proxy: GeometryProxy) -> some View {
        let insets = proxy.safeAreaInsets
        ZStack(alignment: .top) {
            if let content, showsTopBar {
                topBar(content, insets: insets)
                    .transition(.opacity)
            } else {
                floatingButtons(content, insets: insets)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.15), value: showsTopBar)
        // The reader's insets are the screen's, so the controls are measured from the
        // top of the screen, not from the top of the safe area.
        .ignoresSafeArea(.container, edges: .top)
    }

    private func floatingButtons(_ content: DetailContent?, insets: EdgeInsets) -> some View {
        HStack(spacing: Space.sm - 2) {
            CircleIconButton(systemImage: "chevron.left", label: "Voltar") { dismiss() }
            Spacer(minLength: 0)
            if let content {
                ShareLink(item: content.shareText) {
                    CircleIcon(systemImage: "square.and.arrow.up")
                }
                .accessibilityLabel("Compartilhar")
                heart(content, diameter: 42)
            }
        }
        .padding(.horizontal, 15)
        .padding(.leading, insets.leading)
        .padding(.trailing, insets.trailing)
        .padding(.top, insets.top)
    }

    private func topBar(_ content: DetailContent, insets: EdgeInsets) -> some View {
        let isFavourite = store.favouriteIds.contains(lotId)
        return VStack(spacing: 0) {
            HStack(spacing: Space.sm) {
                CircleIconButton(
                    systemImage: "chevron.left", label: "Voltar",
                    foreground: Palette.ink, background: .clear
                ) { dismiss() }
                Text(content.title)
                    .typeset(.cardTitle)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                CircleIconButton(
                    systemImage: isFavourite ? "heart.fill" : "heart",
                    label: heartLabel(content, isOn: isFavourite),
                    foreground: isFavourite ? Palette.amberText : Palette.ink,
                    background: .clear
                ) { toggleFavourite(isOn: isFavourite) }
            }
            .padding(.horizontal, 15)
            .padding(.leading, insets.leading)
            .padding(.trailing, insets.trailing)
            .frame(height: 44)
            .padding(.top, insets.top)
            .padding(.bottom, Space.xxs)
            Hairline()
        }
        .background(Palette.paper.ignoresSafeArea(edges: .top))
    }

    private func heart(_ content: DetailContent, diameter: CGFloat) -> some View {
        let isFavourite = store.favouriteIds.contains(lotId)
        return HeartButton(
            isOn: isFavourite,
            label: heartLabel(content, isOn: isFavourite),
            diameter: diameter
        ) { toggleFavourite(isOn: isFavourite) }
    }

    private func heartLabel(_ content: DetailContent, isOn: Bool) -> String {
        isOn ? "Remover dos favoritos: \(content.title)" : "Favoritar \(content.title)"
    }

    private func toggleFavourite(isOn: Bool) {
        Task { await store.setFavourite(!isOn, id: lotId) }
    }
}

// MARK: - Loading

/// The detail while it loads: a plate for the photograph and the shapes of what
/// follows. It stands still on purpose.
private struct DetailSkeleton: View {
    let galleryHeight: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Palette.paperDim.frame(height: galleryHeight)
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: Space.sm) {
                    RoundedRectangle(cornerRadius: Radius.tag, style: .continuous)
                        .fill(Palette.paperDim).frame(width: 120, height: 28)
                    RoundedRectangle(cornerRadius: Radius.tag, style: .continuous)
                        .fill(Palette.paperDim).frame(width: 64, height: 28)
                }
                VStack(alignment: .leading, spacing: 10) {
                    SkeletonLine(fraction: 0.95, height: 24)
                    SkeletonLine(fraction: 0.6, height: 24)
                }
                .padding(.top, Space.md)
                RoundedRectangle(cornerRadius: Radius.decision, style: .continuous)
                    .fill(Palette.paperDim)
                    .frame(height: 150)
                    .padding(.top, 18)
            }
            .padding(.horizontal, Space.gutter)
            .padding(.top, Space.lg)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Carregando")
    }
}
