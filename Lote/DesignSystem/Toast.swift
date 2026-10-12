import SwiftUI

/// A short message with one way to take the action back, on the inverse surface so
/// it stands apart from content in both themes: "Removido dos salvos · Desfazer".
struct UndoToast: View {
    let message: String
    let actionTitle: String
    let onAction: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Text(message + " · ")
                .typeset(.small)
                .foregroundStyle(Palette.paper)
            Button(action: onAction) {
                Text(actionTitle)
                    .typeset(.label)
                    .foregroundStyle(Palette.paper)
                    .padding(.trailing, Space.lg)
                    .frame(minHeight: Palette.touch)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressStyle())
            Spacer(minLength: 0)
        }
        .padding(.leading, Space.lg)
        .frame(minHeight: 52)
        .background(Palette.ink, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
        .padding(.horizontal, Space.gutter)
        .accessibilityElement(children: .contain)
    }
}

/// A short message on the inverse surface, with nothing to tap: a heart the server
/// refused. It slides up from the bottom (fades, under Reduce Motion), is read out by
/// VoiceOver, and goes by itself after a few seconds.
struct NoticeToast: View {
    let message: String

    var body: some View {
        Text(message)
            .typeset(.small)
            .foregroundStyle(Palette.paper)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .padding(.horizontal, Space.lg)
            .background(Palette.ink, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
            .padding(.horizontal, Space.gutter)
            .accessibilityElement(children: .combine)
    }
}

/// Shows the store's refusal, wherever the reader is: each tab's stack carries it. It is
/// a bottom safe-area inset, not an overlay: on iOS 26 the tab bar floats over the
/// content, and an overlay aligned to the bottom lands behind it.
struct RefusalNotice: ViewModifier {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if let refusal = store.refusal {
                    NoticeToast(message: refusal.message)
                        .padding(.bottom, Space.md)
                        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                        .task(id: refusal.id) {
                            try? await Task.sleep(for: .seconds(Motion.notice))
                            store.dismiss(refusal)
                        }
                }
            }
            .animation(Motion.enter(), value: store.refusal)
            .onChange(of: store.refusal) { _, refusal in
                if let refusal { AccessibilityNotification.Announcement(refusal.message).post() }
            }
    }
}
