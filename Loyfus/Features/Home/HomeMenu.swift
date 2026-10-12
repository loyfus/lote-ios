import SwiftUI

/// Where Home keeps whether its notice was dismissed (HomeScreen reads it through
/// AppStorage, so dismissing redraws the hero). Once dismissed it never comes back: a
/// notice that can be dismissed but returns is not dismissable, it is a nagging element
/// wearing the costume of one.
enum HomeBanner {
    static let key = "home.banner.dismissed"
}

/// The menu behind the hamburger: where the app goes, and every category by name.
///
/// The horizontal strip on the hero is a shortcut, not a list — it cuts "Movimentação"
/// in half and hides the categories that do not fit. Here the same data is a column
/// of whole words, which is what a menu is for. The sheet is the platform's (a modal
/// drawer on Android, a sheet here); the content is identical in both.
struct MenuSheet: View {
    let categories: [Category]
    let savedCount: Int
    let onSelectTab: (AppTab) -> Void
    let onSelectCategory: (Category) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    row(AppTab.home, title: "Início", symbol: "house", filled: "house.fill")
                    row(AppTab.explore, title: "Explorar", symbol: "magnifyingglass", filled: "magnifyingglass")
                    row(AppTab.saved, title: savedTitle,
                        symbol: "heart", filled: "heart.fill")
                }
                Section("Categorias") {
                    ForEach(categories) { category in
                        let style = Categories.style(for: category.name)
                        Button { dismiss(); onSelectCategory(category) } label: {
                            Label(style.label, systemImage: style.symbol)
                                .foregroundStyle(Palette.ink80)
                        }
                        .accessibilityLabel(style.label)
                    }
                }
            }
            .listStyle(.plain)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .principal) { Wordmark() } }
            .tint(Palette.amberText)
        }
        .presentationBackground(Palette.paper)
    }

    private func row(_ tab: AppTab, title: String, symbol: String, filled: String) -> some View {
        Button { dismiss(); onSelectTab(tab) } label: {
            Label(title, systemImage: symbol)
                .foregroundStyle(Palette.ink80)
        }
        .accessibilityLabel(title)
    }

    private var savedTitle: String {
        savedCount > 0 ? "Salvos (" + String(savedCount) + ")" : "Salvos"
    }
}

/// The notice's answers: what the app is, where the data comes from, what it keeps.
/// Opened by the notice on Home and by "Como funciona" in Settings.
struct AboutSheet: View {
    let totalLots: Int
    let updatedAt: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    group("Como funciona", [
                        "O Loyfus reúne lotes de leilões e vendas diretas do Brasil.",
                        "O lance, a compra e o pagamento acontecem no site do leiloeiro.",
                        "Os valores são lidos de tempos em tempos; confirme no site antes de ofertar.",
                    ])
                    group("Dados", [
                        data,
                        "Fonte: SuperBid",
                    ])
                    group("Privacidade", [
                        "Seus favoritos ficam ligados a este aparelho. Não pedimos cadastro.",
                    ])
                }
                .padding(.horizontal, Space.gutter)
                .padding(.bottom, Space.xxl)
            }
            .background(Palette.paper)
            .navigationTitle("Sobre o Loyfus")
            .navigationBarTitleDisplayMode(.inline)
            .tint(Palette.amberText)
        }
        .presentationBackground(Palette.paper)
    }

    private var data: String {
        guard let stamp = Fmt.ago(updatedAt) else { return Hero.lots(totalLots) }
        return "\(Hero.lots(totalLots)) · atualizado \(stamp)"
    }

    private func group(_ title: String, _ lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(title)
                .typeset(.cardTitle)
                .foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            ForEach(lines, id: \.self) { line in
                Text(line)
                    .typeset(.small)
                    .foregroundStyle(Palette.ink60)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

extension Bundle {
    var appVersion: String {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    var buildNumber: String {
        object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }
}
