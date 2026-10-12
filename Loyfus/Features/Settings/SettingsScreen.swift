import SwiftUI
import UIKit

/// The theme the reader picked: the phone's, or one of the two pinned regardless of it.
/// Stored under the same key and values as on Android (`SharedPreferences` there).
enum AppTheme: String, CaseIterable, Identifiable {
    case system, light, dark

    static let key = "settings.theme"

    var id: Self { self }

    var label: String {
        switch self {
        case .system: return "Automático"
        case .light: return "Claro"
        case .dark: return "Escuro"
        }
    }

    private var style: UIUserInterfaceStyle {
        switch self {
        case .system: return .unspecified
        case .light: return .light
        case .dark: return .dark
        }
    }

    /// Pins every window of the app to the theme. The window, not a view: a sheet and
    /// the system's bars take their appearance from it, and `.unspecified` hands the
    /// choice back to the phone, which `preferredColorScheme(nil)` does not always do.
    @MainActor
    func apply(animated: Bool) {
        let fades = animated && !UIAccessibility.isReduceMotionEnabled
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            for window in scene.windows where window.overrideUserInterfaceStyle != style {
                if fades {
                    UIView.transition(with: window, duration: Motion.collapseDuration, options: .transitionCrossDissolve) {
                        window.overrideUserInterfaceStyle = style
                    }
                } else {
                    window.overrideUserInterfaceStyle = style
                }
            }
        }
    }
}

/// The app's settings, behind the gear on Home's bar: the theme, what the app keeps on
/// the phone, and what the app is. There is no account, so there is nothing here about
/// one; every choice is stored on the device and takes effect the moment it is made.
struct SettingsScreen: View {
    @Environment(HomeModel.self) private var home
    @Environment(ExploreModel.self) private var explore
    @AppStorage(AppTheme.key) private var theme: AppTheme = .system
    @State private var showsAbout = false

    var body: some View {
        List {
            Section {
                ForEach(AppTheme.allCases) { option in
                    themeRow(option)
                }
            } header: {
                header("Aparência")
            } footer: {
                footer("No automático, o Loyfus acompanha o tema do aparelho.")
            }

            Section {
                clearSearchesRow
            } header: {
                header("Privacidade")
            } footer: {
                footer("Suas buscas e seus favoritos ficam ligados a este aparelho. Não pedimos cadastro.")
            }

            Section {
                Button { showsAbout = true } label: {
                    HStack {
                        Text("Como funciona")
                            .typeset(.body)
                            .foregroundStyle(Palette.ink)
                        Spacer(minLength: Space.md)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Palette.ink60)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowBackground(Palette.surface)
                HStack {
                    Text("Versão")
                        .typeset(.body)
                        .foregroundStyle(Palette.ink)
                    Spacer(minLength: Space.md)
                    Text("\(Bundle.main.appVersion) (\(Bundle.main.buildNumber))")
                        .typeset(.body)
                        .foregroundStyle(Palette.ink60)
                }
                .accessibilityElement(children: .combine)
                .listRowBackground(Palette.surface)
            } header: {
                header("Sobre")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Palette.paper)
        .navigationTitle("Configurações")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showsAbout) {
            AboutSheet(totalLots: home.totalLots, updatedAt: home.updatedAt)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    /// One of the three themes; the selected one carries the check, as a system list does.
    private func themeRow(_ option: AppTheme) -> some View {
        Button {
            theme = option
        } label: {
            HStack {
                Text(option.label)
                    .typeset(.body)
                    .foregroundStyle(Palette.ink)
                Spacer(minLength: Space.md)
                if theme == option {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Palette.amberText)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(Palette.surface)
        .accessibilityAddTraits(theme == option ? .isSelected : [])
    }

    /// Forgets the searches typed in Explore, through Explore, so the list it shows empties
    /// too. It says how many there are, and goes quiet at none.
    private var clearSearchesRow: some View {
        let count = explore.recents.count
        return Button {
            explore.clearRecents()
        } label: {
            VStack(alignment: .leading, spacing: Space.xxs) {
                Text("Limpar buscas recentes")
                    .typeset(.body)
                    .foregroundStyle(Palette.ink)
                Text(countText(count))
                    .typeset(.small)
                    .foregroundStyle(Palette.ink60)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, Space.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(count == 0)
        .listRowBackground(Palette.surface)
    }

    private func countText(_ count: Int) -> String {
        switch count {
        case 0: return "Nenhuma busca guardada"
        case 1: return "1 busca guardada neste aparelho"
        default: return "\(count) buscas guardadas neste aparelho"
        }
    }

    private func header(_ title: String) -> some View {
        Text(title)
            .typeset(.label)
            .foregroundStyle(Palette.ink60)
            .textCase(nil)
            .accessibilityAddTraits(.isHeader)
    }

    private func footer(_ text: String) -> some View {
        Text(text)
            .typeset(.small)
            .foregroundStyle(Palette.ink60)
    }
}
