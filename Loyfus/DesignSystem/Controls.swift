import SwiftUI

// Controls carry a border; content does not (WCAG 1.4.11 asks 3:1 of whatever
// identifies a control, and `lineControl` is solved for it). Cards and tiles have
// no frame at all: the photograph and the space around it separate them.

/// A hairline rule between the parts of a screen.
struct Hairline: View {
    var body: some View {
        Rectangle().fill(Palette.line).frame(height: 1)
    }
}

/// A choice: a pill with a border, ink-filled when selected. 40 tall to look at,
/// 44 to touch.
struct Chip: View {
    let title: String
    var systemImage: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 16))
                        .foregroundStyle(isSelected ? Palette.paper : Palette.ink60)
                }
                Text(title).typeset(.label)
            }
            .foregroundStyle(isSelected ? Palette.paper : Palette.ink)
            .padding(.horizontal, 14)
            .frame(minHeight: 40)
            // Selecting fills the pill with ink in 120 ms instead of swapping it: the eye
            // sees which chip took the choice. The border turns ink with the fill, so it
            // disappears into it rather than being removed, and nothing moves.
            .background {
                Capsule()
                    .fill(isSelected ? Palette.ink : Palette.ink.opacity(0))
                    .overlay {
                        Capsule().strokeBorder(isSelected ? Palette.ink : Palette.lineControl, lineWidth: 1)
                    }
            }
            .animation(Motion.change, value: isSelected)
            .padding(.vertical, 2)
            .contentShape(Capsule())
        }
        .buttonStyle(PressStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// An active filter, removable with a tap: 32 tall, with the touch area of a
/// control around it.
struct RemovableTag: View {
    let title: String
    let onRemove: () -> Void

    var body: some View {
        Button(action: onRemove) {
            HStack(spacing: Space.xs) {
                Text(title).typeset(.metaSemibold).foregroundStyle(Palette.ink80)
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Palette.ink60)
                    .frame(width: 20, height: 20)
            }
            .padding(.leading, 12)
            .padding(.trailing, 6)
            .frame(minHeight: 32)
            .background(Palette.paperDim, in: RoundedRectangle(cornerRadius: Radius.tag, style: .continuous))
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel("Remover filtro: \(title)")
    }
}

/// The search field: 52 tall, a border that turns to ink while it has the keyboard.
struct SearchField: View {
    @Binding var text: String
    let placeholder: String
    var isFocused: FocusState<Bool>.Binding
    let onSubmit: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18))
                .foregroundStyle(Palette.ink60)
            TextField("", text: $text, prompt: Text(placeholder).foregroundColor(Palette.ink60))
                .font(TypeRole.body.font)
                .foregroundStyle(Palette.ink)
                .focused(isFocused)
                .submitLabel(.search)
                .onSubmit(onSubmit)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityLabel("Buscar lotes")
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Palette.ink60)
                        .frame(width: Palette.touch, height: Palette.touch)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Limpar busca")
                // The field is 52 tall; the button's 44 would push its padding past it.
                .padding(.trailing, -10)
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 52)
        .background(Palette.surface, in: shape)
        .overlay { shape.strokeBorder(isFocused.wrappedValue ? Palette.ink : Palette.lineControl, lineWidth: 1) }
        .contentShape(shape)
        .onTapGesture { isFocused.wrappedValue = true }
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
    }
}

/// The search field of Home: the same drawing, but a button. A tap opens Explore
/// with the keyboard up; nothing is typed here.
struct SearchButton: View {
    let placeholder: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18))
                Text(placeholder).typeset(.body).lineLimit(1)
                Spacer(minLength: 0)
            }
            .foregroundStyle(Palette.ink60)
            .padding(.horizontal, 14)
            .frame(minHeight: 52)
            .background(Palette.surface, in: shape)
            .overlay { shape.strokeBorder(Palette.lineControl, lineWidth: 1) }
            .contentShape(shape)
        }
        .buttonStyle(PressStyle(press: .surface))
        .accessibilityLabel("Buscar lotes")
        .accessibilityHint(placeholder)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
    }
}
