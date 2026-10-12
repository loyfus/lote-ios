import SwiftUI

/// Explore: a search, the categories, the filters and the whole catalogue as a grid
/// of tiles. The state lives in `ExploreModel`, above the tabs, so it is still there
/// when the user comes back from another tab or from a lot.
struct ExploreScreen: View {
    @Environment(AppStore.self) private var store
    @Environment(Router.self) private var router
    @Environment(ExploreModel.self) private var explore
    @Environment(\.dynamicTypeSize) private var typeSize

    @FocusState private var searchFocused: Bool
    @State private var showsFilters = false

    var body: some View {
        @Bindable var explore = explore
        GeometryReader { proxy in
            VStack(spacing: 0) {
                controls(explore: $explore.searchText)
                ZStack {
                    results(width: proxy.size.width)
                    if searchFocused && explore.searchText.isEmpty {
                        suggestions
                            .transition(.opacity)
                    }
                }
                .animation(.easeOut(duration: Motion.fast), value: searchFocused)
            }
        }
        .background(Palette.paper)
        .sheet(isPresented: $showsFilters) {
            FilterSheet(
                repository: store.repository,
                search: explore.searchText,
                category: explore.category,
                initial: explore.filters
            ) { explore.apply($0) }
        }
        .onAppear {
            explore.startIfNeeded()
            takeRequestedFocus()
        }
        .onChange(of: explore.wantsSearchFocus) { takeRequestedFocus() }
        .onChange(of: explore.searchText) { explore.searchTextChanged() }
        .onChange(of: searchFocused) { _, focused in
            if !focused { explore.rememberSearch() }
        }
    }

    /// Home's search field opens Explore with the keyboard up. The field has to be on
    /// screen before it can take focus, so the request waits for the tab to settle.
    private func takeRequestedFocus() {
        guard explore.wantsSearchFocus else { return }
        explore.wantsSearchFocus = false
        Task {
            try? await Task.sleep(for: .milliseconds(200))
            searchFocused = true
        }
    }

    // MARK: Controls

    /// Search, filters, categories and the tags of the active filters stay put while
    /// the grid scrolls under them.
    private func controls(explore text: Binding<String>) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                SearchField(
                    text: text,
                    placeholder: explore.catalogueTotal.map { "Buscar em \(Fmt.thousands($0)) lotes" }
                        ?? "Buscar carro, imóvel, máquina…",
                    isFocused: $searchFocused,
                    onSubmit: {
                        explore.submitSearch()
                        searchFocused = false
                    })
                FilterButton(count: explore.filters.activeCount) { showsFilters = true }
            }
            .padding(.horizontal, Space.gutter)
            .padding(.top, 6)

            CategoryChips(
                categories: store.categories,
                selected: explore.category,
                onSelect: { explore.select(category: $0) }
            )
            .padding(.top, 12)

            let tags = explore.activeTags
            if !tags.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: Space.sm) {
                        ForEach(tags, id: \.title) { tag in
                            RemovableTag(title: tag.title, onRemove: tag.remove)
                        }
                    }
                }
                .contentMargins(.horizontal, Space.gutter, for: .scrollContent)
                .scrollIndicators(.hidden)
                .transition(.opacity)
            }
        }
        // A tag added or removed fades in or out, and the row closes its gap instead of
        // snapping shut.
        .animation(Motion.enter(), value: explore.activeTags.map(\.title))
    }

    // MARK: Results

    private func results(width: CGFloat) -> some View {
        let columns = Measure.gridColumns(width: width, typeSize: typeSize)
        return ScrollView {
            VStack(spacing: 0) {
                switch explore.phase {
                case .loading:
                    resultsHeader(showsCount: false)
                    grid(columns: columns) {
                        ForEach(0..<6, id: \.self) { _ in TileSkeleton() }
                    }
                    .skeletonPulse()
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Carregando")
                    .transition(.opacity)
                case .failed(let message):
                    StateView(
                        symbol: "wifi.slash",
                        title: "Não foi possível carregar",
                        message: message,
                        actionTitle: "Tentar novamente",
                        action: { explore.reload() })
                    .transition(.opacity)
                case .loaded where explore.items.isEmpty:
                    emptyState
                        .transition(.opacity)
                case .loaded:
                    resultsHeader(showsCount: true)
                        .transition(.opacity)
                    grid(columns: columns) {
                        ForEach(explore.items) { item in
                            LotTile(
                                item: item,
                                variant: .grid,
                                isFavourite: store.favouriteIds.contains(item.id),
                                onOpen: { router.open(lot: item.id) },
                                onToggleFavourite: { toggle(item) }
                            )
                            .onAppear { explore.loadMoreIfNeeded(after: item) }
                        }
                    }
                    footer
                }
            }
            .padding(.bottom, Space.xxl)
            // Skeleton, results, empty and error give way to each other by fading. Keyed by
            // the state, not by every change: appending a page does not replay the grid.
            .animation(Motion.contentSwap, value: resultsState)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .refreshable { await explore.refresh() }
    }

    private func grid<Content: View>(columns: Int, @ViewBuilder content: () -> Content) -> some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: Space.md, alignment: .top), count: columns),
            spacing: Space.xl,
            content: content
        )
        .padding(.horizontal, Space.gutter)
        .padding(.top, 2)
    }

    /// What the results area is showing, for the cross-fade: the phase, whether the list
    /// is empty, and which page of results (a new search replaces the first id).
    private var resultsState: String {
        "\(explore.phase)|\(explore.items.isEmpty)|\(explore.items.first?.id ?? 0)"
    }

    private func resultsHeader(showsCount: Bool) -> some View {
        HStack(spacing: Space.md) {
            // The total rolls to its new value instead of being retyped.
            Text(showsCount ? Fmt.lots(explore.total) : " ")
                .typeset(.small)
                .foregroundStyle(Palette.ink60)
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(explore.total)))
                .animation(Motion.change, value: explore.total)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            sortMenu
        }
        .padding(.horizontal, Space.gutter)
        .padding(.top, 4)
        .padding(.bottom, 4)
    }

    private var sortMenu: some View {
        let sort = Binding<LotSort>(
            get: { explore.filters.sort },
            set: {
                var next = explore.filters
                next.sort = $0
                explore.apply(next)
            })
        return Menu {
            Picker("Ordenar por", selection: sort) {
                ForEach(LotSort.allCases) { Text($0.label).tag($0) }
            }
        } label: {
            HStack(spacing: 2) {
                Text(explore.filters.sort.label).typeset(.label)
                Image(systemName: "chevron.down")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.ink60)
            }
            .foregroundStyle(Palette.ink)
            .frame(minHeight: Palette.touch)
            .contentShape(Rectangle())
        }
        .accessibilityLabel("Ordenar por: \(explore.filters.sort.label)")
    }

    @ViewBuilder
    private var footer: some View {
        if explore.loadMoreFailed {
            SecondaryButton(title: "Tentar novamente") { explore.loadMore() }
                .frame(maxWidth: 280)
                .padding(.top, Space.xl)
        } else if explore.isLoadingMore {
            ProgressView()
                .padding(.top, Space.xl)
                .accessibilityLabel("Carregando mais lotes")
        }
    }

    private var emptyState: some View {
        let summary = ([explore.searchText.trimmingCharacters(in: .whitespaces)].filter { !$0.isEmpty }.map { "“\($0)”" }
            + explore.activeTags.map(\.title)).joined(separator: " · ")
        return StateView(
            symbol: "magnifyingglass",
            title: "Nenhum lote encontrado",
            message: summary.isEmpty
                ? "Não há lotes para mostrar agora."
                : "Nada combina com \(summary). Tente outros termos ou tire algum filtro.",
            actionTitle: explore.hasActiveQuery ? "Limpar filtros" : nil,
            action: { explore.clearAll() })
    }

    // MARK: Suggestions

    /// What the empty, focused search field offers instead of the grid: the last
    /// searches of this device, and the categories to start from.
    private var suggestions: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if !explore.recents.isEmpty {
                    HStack {
                        Text("Buscas recentes").typeset(.headline).foregroundStyle(Palette.ink)
                            .accessibilityAddTraits(.isHeader)
                        Spacer(minLength: 0)
                        QuietButton(title: "Limpar", role: .label) { explore.clearRecents() }
                    }
                    .padding(.horizontal, Space.gutter)
                    .padding(.top, Space.lg)

                    ForEach(explore.recents, id: \.self) { term in
                        Button {
                            searchFocused = false
                            explore.search(for: term)
                        } label: {
                            HStack(spacing: Space.md) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.system(size: 17))
                                    .foregroundStyle(Palette.ink60)
                                Text(term).typeset(.body).foregroundStyle(Palette.ink).lineLimit(1)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, Space.gutter)
                            .frame(minHeight: Palette.touch)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PressStyle(press: .surface))
                    }
                }

                if !store.categories.isEmpty {
                    Text("Categorias").typeset(.headline).foregroundStyle(Palette.ink)
                        .accessibilityAddTraits(.isHeader)
                        .padding(.horizontal, Space.gutter)
                        .padding(.top, explore.recents.isEmpty ? Space.lg : Space.xxl)
                        .padding(.bottom, Space.sm)
                    FlowLayout(spacing: Space.sm, lineSpacing: 0) {
                        ForEach(store.categories) { category in
                            let style = Categories.style(for: category.name)
                            Chip(title: style.label, systemImage: style.symbol, isSelected: false) {
                                searchFocused = false
                                explore.select(category: category.externalId)
                            }
                        }
                    }
                    .padding(.horizontal, Space.gutter)
                }
            }
            .padding(.bottom, Space.xxl)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Palette.paper)
    }

    private func toggle(_ item: LotItem) {
        let on = !store.favouriteIds.contains(item.id)
        Task { await store.setFavourite(on, id: item.id, item: item) }
    }
}

// MARK: - Pieces

/// The filter button: a bordered square the height of the search field, with the
/// number of filters that are on.
private struct FilterButton: View {
    let count: Int
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 20))
                .foregroundStyle(Palette.ink)
                .frame(width: 52, height: 52)
                .background(
                    Palette.surface, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
                        .strokeBorder(Palette.lineControl, lineWidth: 1)
                }
                .overlay(alignment: .topTrailing) {
                    // The badge grows in when a filter is first set, shrinks out when the
                    // last one goes, and its number rolls in between.
                    if count > 0 {
                        Text("\(count)")
                            .typeset(.badge)
                            .foregroundStyle(Palette.onAmber)
                            .contentTransition(.numericText(value: Double(count)))
                            .padding(.horizontal, 5)
                            .frame(minWidth: 20, minHeight: 20)
                            .background(Palette.amber, in: Capsule())
                            .offset(x: 6, y: -6)
                            .accessibilityHidden(true)
                            .transition(reduceMotion ? .opacity : .scale(scale: 0.6).combined(with: .opacity))
                    }
                }
                .animation(Motion.change, value: count)
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel("Filtros")
        .accessibilityValue(count == 0 ? "" : "\(count) ativos")
    }
}

/// "Todas" and one chip per category, with the selected one kept in view: a category
/// chosen on Home may be far to the right of the row.
private struct CategoryChips: View {
    let categories: [Category]
    let selected: String?
    let onSelect: (String?) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: Space.sm) {
                    Chip(title: "Todas", isSelected: selected == nil) { onSelect(nil) }
                        .id("all")
                    ForEach(categories) { category in
                        let style = Categories.style(for: category.name)
                        Chip(title: style.label, systemImage: style.symbol, isSelected: selected == category.externalId) {
                            onSelect(category.externalId)
                        }
                        .id(category.externalId)
                    }
                }
            }
            .contentMargins(.horizontal, Space.gutter, for: .scrollContent)
            .scrollIndicators(.hidden)
            .onChange(of: selected) { _, now in
                withAnimation(.easeOut(duration: Motion.standard)) {
                    proxy.scrollTo(now ?? "all", anchor: .center)
                }
            }
            .onAppear {
                if let selected { proxy.scrollTo(selected, anchor: .center) }
            }
        }
    }
}
