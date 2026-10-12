import SwiftUI

/// Home is the door of the catalogue: a hero that says who this is and hands over to
/// search in one tap, the categories as frosted shortcuts, one notice it can take
/// back, and then a sheet that says what is true right now (how fresh the catalogue
/// is, what is closing, who takes an offer), what the reader might spend, and what
/// the server picked. It is not a feed: browsing is Explore's job, and Home's job is
/// the first screen of it.
struct HomeScreen: View {
    @Environment(AppStore.self) private var store
    @Environment(Router.self) private var router
    @Environment(HomeModel.self) private var home
    @Environment(ExploreModel.self) private var explore

    @State private var showsAbout = false
    @State private var showsMenu = false
    /// Read through AppStorage, not once: dismissing the notice has to redraw the hero.
    @AppStorage(HomeBanner.key) private var bannerDismissed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                hero
                sheet
            }
            .padding(.bottom, Space.x3 + 28)
        }
        .scrollIndicators(.hidden)
        .toolbar {
            HomeToolbar(
                onOpenMenu: { showsMenu = true },
                onOpenSettings: { router.openSettings() })
        }
        .navigationBarTitleDisplayMode(.inline)
        // The bar is the hero's own night blue in both themes. A visible bar with a
        // dark colour scheme is what turns the status bar's content white in the light
        // theme too; a hidden bar leaves it dark on the blue.
        .toolbarBackground(Palette.heroTop, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .refreshable {
            async let shelves: Void = home.refresh()
            async let categories: Void = store.loadCategories()
            _ = await (shelves, categories)
        }
        // Night blue above the middle, paper below: whatever a bounce reveals continues
        // the edge it was pulled from, the hero at the top and the sheet at the end.
        .background {
            VStack(spacing: 0) {
                Palette.heroTop
                Palette.paper
            }
            .ignoresSafeArea()
        }
        .onAppear { home.startIfNeeded() }
        .sheet(isPresented: $showsAbout) {
            AboutSheet(totalLots: home.totalLots, updatedAt: home.updatedAt)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showsMenu) {
            MenuSheet(
                categories: store.categories,
                savedCount: store.favouriteItems.count,
                onSelectTab: { tab in
                    showsMenu = false
                    router.select(tab)
                },
                onSelectCategory: { category in
                    showsMenu = false
                    explore.show(category: category.externalId)
                    router.select(.explore)
                })
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 0) {
            SearchPill {
                explore.wantsSearchFocus = true
                router.select(.explore)
            }
            .padding(.horizontal, Space.gutter)

            ShortcutRow(
                categories: store.categories,
                onSelect: { category in
                    explore.show(category: category.externalId)
                    router.select(.explore)
                },
                onSelectAll: {
                    explore.show(ShelfQuery())
                    router.select(.explore)
                })
                .padding(.top, Space.lg)

            if !bannerDismissed {
                NoticeBanner(
                    onOpenAbout: { showsAbout = true },
                    onDismiss: {
                        // The notice fades and the hero closes up behind it, so the sheet
                        // rises into the space instead of jumping. Reduce Motion: it goes.
                        withAnimation(reduceMotion ? nil : Motion.collapse) { bannerDismissed = true }
                    })
                    .padding(.top, Space.lg)
                    .transition(.opacity)
            }
        }
        .padding(.top, Space.xs)
        .padding(.bottom, 46)
        .background(Hero.gradient)
    }

    // MARK: Sheet

    @ViewBuilder
    private var sheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch home.phase {
            case .loading:
                HomeSheetSkeleton()
                    .skeletonPulse()
            case .failed(let message):
                StateView(
                    symbol: "wifi.slash",
                    title: "Não foi possível carregar",
                    message: message,
                    actionTitle: "Tentar novamente",
                    action: { home.reload() })
                .padding(.top, Space.xl)
            case .loaded:
                ContextLine(updatedAt: home.updatedAt, totalLots: home.totalLots)
                StatusCards(
                    closing: home.closing,
                    acceptsProposal: home.acceptsProposal,
                    onOpenClosing: { window in
                        explore.show(ShelfQuery(sort: "ending", modality: "LEILAO", endsWithin: window.withinHours))
                        router.select(.explore)
                    },
                    onOpenOffers: {
                        explore.show(ShelfQuery(sort: "ending", acceptsProposal: true))
                        router.select(.explore)
                    })
                BudgetCard { min, max in
                    explore.show(budgetFrom: min, to: max)
                    router.select(.explore)
                }
                savedShelf
                ForEach(home.shelves) { shelf in
                    ShelfSection(shelf: shelf)
                }
            }
        }
        .frame(maxWidth: .infinity)
        // Skeleton, error and content give way to each other by fading; a refresh that
        // keeps the phase updates the shelves in place.
        .animation(Motion.contentSwap, value: home.phase)
        // 22 from the sheet's edge to the context line, which adds no space of its own
        // above: the line sits as close to the edge as it does to the cards below it.
        .padding(.top, 22)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: Radius.sheet, bottomLeadingRadius: 0,
                bottomTrailingRadius: 0, topTrailingRadius: Radius.sheet,
                style: .continuous)
                .fill(Palette.paper))
        .offset(y: -28)
    }

    /// The lots already hearted, closing soonest first. Direct sales and lots
    /// without a deadline go last, and the finished ones are left out entirely: a
    /// rail of lots whose time has passed is a shelf of nothing.
    @ViewBuilder
    private var savedShelf: some View {
        let items = store.favouriteItems.filter { $0.display.chip != .label("Encerrado") && $0.lot.urgency != .ended }
            .sorted { left, right in
                let leftLate = left.lot.kind == .directSale || left.lot.urgency == .none
                let rightLate = right.lot.kind == .directSale || right.lot.urgency == .none
                if leftLate != rightLate { return !leftLate }
                return left.lot.secondsToClose < right.lot.secondsToClose
            }
            .prefix(10)
        if !items.isEmpty {
            ShelfSection(
                shelf: ShelfContent(
                    id: "saved", title: "Seus salvos", subtitle: nil,
                    query: ShelfQuery(), items: Array(items)),
                onOpenAll: { router.select(.saved) })
        }
    }
}

// MARK: - Shelves

private struct ShelfSection: View {
    @Environment(AppStore.self) private var store
    @Environment(Router.self) private var router
    @Environment(ExploreModel.self) private var explore

    let shelf: ShelfContent
    var onOpenAll: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .lastTextBaseline, spacing: Space.md) {
                Text(shelf.title)
                    .typeset(.headline)
                    .foregroundStyle(Palette.ink)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                QuietButton(title: "Ver todos", systemImage: "chevron.right", role: .label) {
                    if let onOpenAll {
                        onOpenAll()
                    } else {
                        explore.show(shelf.query)
                        router.select(.explore)
                    }
                }
                .accessibilityLabel("Ver todos: \(shelf.title)")
            }
            .padding(.horizontal, Space.gutter)

            if let subtitle = shelf.subtitle {
                Text(subtitle)
                    .typeset(.subtitle)
                    .foregroundStyle(Palette.ink60)
                    .padding(.horizontal, Space.gutter)
            }

            rail.padding(.top, 14)
        }
        .padding(.top, Space.xl)
    }

    private var rail: some View {
        let reservesPlace = shelf.items.contains { $0.display.place != nil }
        return ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: Space.md) {
                ForEach(shelf.items) { item in
                    LotTile(
                        item: item,
                        variant: .shelf,
                        isFavourite: store.favouriteIds.contains(item.id),
                        reservesPlaceLine: reservesPlace,
                        onOpen: { router.open(lot: item.id) },
                        onToggleFavourite: {
                            let on = !store.favouriteIds.contains(item.id)
                            Task { await store.setFavourite(on, id: item.id, item: item) }
                        })
                }
            }
            .scrollTargetLayout()
            .padding(.bottom, Space.xs)
        }
        .contentMargins(.horizontal, Space.gutter, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned)
        .scrollIndicators(.hidden)
    }
}

// MARK: - Loading

/// The shape of Home while it loads, with the geometry the real screen will have, so
/// the content fades in over it without anything moving. It breathes (skeletonPulse).
private struct HomeSheetSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SkeletonLine(fraction: 0.45, height: 14)
                .padding(.horizontal, Space.gutter)
                .padding(.bottom, 14)

            HStack(alignment: .top, spacing: Space.md) {
                ForEach(0..<2, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Palette.paperDim)
                        .frame(maxWidth: .infinity)
                        .frame(height: 132)
                }
            }
            .padding(.horizontal, Space.gutter)

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Palette.paperDim)
                .frame(height: 132)
                .padding(.horizontal, Space.gutter)
                .padding(.top, Space.md)

            SkeletonLine(fraction: 0.5, height: 22)
                .frame(width: 190)
                .padding(.horizontal, Space.gutter)
                .padding(.top, Space.xl)
            SkeletonLine(fraction: 0.7, height: 12)
                .frame(width: 240)
                .padding(.horizontal, Space.gutter)
                .padding(.top, Space.sm)

            HStack(alignment: .top, spacing: Space.md) {
                TileSkeleton(variant: .shelf)
                TileSkeleton(variant: .shelf)
            }
            .padding(.horizontal, Space.gutter)
            .padding(.top, 14)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Carregando")
    }
}
