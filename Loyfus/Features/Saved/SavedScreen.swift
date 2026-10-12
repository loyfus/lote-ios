import SwiftUI
import UIKit

/// Saved: the lots hearted on this device, grouped by how soon each needs attention.
struct SavedScreen: View {
    @Environment(AppStore.self) private var store
    @Environment(Router.self) private var router

    /// The lot just taken out, kept for five seconds in case it was a slip.
    private struct Removal: Equatable {
        let item: LotItem
        let token = UUID()
    }

    @State private var removal: Removal?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                header
                content
            }
            .padding(.bottom, Space.x5)
        }
        .scrollIndicators(.hidden)
        .refreshable { await store.loadFavourites() }
        .background(Palette.paper)
        // A bottom safe-area inset rather than an overlay: on iOS 26 the tab bar floats
        // over the content, and an overlay aligned to the bottom lands behind it.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let removal {
                UndoToast(message: "Removido dos salvos", actionTitle: "Desfazer") { undo(removal) }
                    .padding(.bottom, Space.md)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: Motion.standard), value: removal)
        .animation(.easeOut(duration: Motion.standard), value: store.favouriteItems.map(\.id))
        .animation(Motion.contentSwap, value: store.favouritesPhase)
        .task { await store.loadFavourites() }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text("Salvos")
                .typeset(.display)
                .foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            if !store.favouriteItems.isEmpty {
                // The number rolls when a lot is added or removed.
                Text(count)
                    .typeset(.small)
                    .foregroundStyle(Palette.ink60)
                    .contentTransition(.numericText(value: Double(store.favouriteItems.count)))
            }
        }
        .padding(.top, 6)
        .padding(.bottom, Space.sm)
        .padding(.horizontal, Space.gutter)
    }

    private var count: String {
        let n = store.favouriteItems.count
        return n == 1 ? "1 lote neste aparelho" : "\(Fmt.thousands(n)) lotes neste aparelho"
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        if store.favouriteItems.isEmpty {
            switch store.favouritesPhase {
            case .loading:
                VStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { _ in RowSkeleton() }
                }
                .skeletonPulse()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Carregando")
            case .failed(let message):
                StateView(
                    symbol: "wifi.slash",
                    title: "Não foi possível carregar",
                    message: message,
                    actionTitle: "Tentar novamente",
                    action: { Task { await store.loadFavourites() } })
            case .loaded:
                StateView(
                    symbol: "heart",
                    title: "Nada guardado ainda",
                    message: "Toque no coração de um lote para acompanhar o prazo por aqui.",
                    actionTitle: "Explorar lotes",
                    action: { router.select(.explore) })
            }
        } else {
            ForEach(SavedSection.make(from: store.favouriteItems)) { section in
                sectionHeader(section)
                ForEach(Array(section.items.enumerated()), id: \.element.id) { index, item in
                    if index > 0 {
                        Hairline()
                            .padding(.leading, Space.gutter + 104 + 14)
                            .padding(.trailing, Space.gutter)
                    }
                    SavedRow(
                        item: item,
                        onOpen: { router.open(lot: item.id) },
                        onRemove: { remove(item) }
                    )
                    // An ended lot stays on the list, but quieter.
                    .opacity(section.group == .ended ? 0.6 : 1)
                }
            }
        }
    }

    private func sectionHeader(_ section: SavedSection) -> some View {
        HStack(spacing: Space.sm) {
            Circle()
                .fill(section.group == .today ? Palette.amberText : Palette.lineControl)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)
            Text(section.group.title)
                .typeset(.label)
                .foregroundStyle(Palette.ink)
            Spacer(minLength: 0)
            Text("\(section.items.count)")
                .typeset(.metaMedium)
                .foregroundStyle(Palette.ink60)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
        .padding(.horizontal, Space.gutter)
        .padding(.top, 22)
        .padding(.bottom, 10)
    }

    // MARK: Removing

    private func remove(_ item: LotItem) {
        let removal = Removal(item: item)
        self.removal = removal
        UIAccessibility.post(notification: .announcement, argument: "Removido dos salvos")
        Task { await store.setFavourite(false, id: item.id, item: item) }
        Task {
            try? await Task.sleep(for: .seconds(5))
            if self.removal?.token == removal.token { self.removal = nil }
        }
    }

    /// Taking it back asks the server again: the lot is saved a second time.
    private func undo(_ removal: Removal) {
        self.removal = nil
        Task { await store.setFavourite(true, id: removal.item.id, item: removal.item) }
    }
}
