import SwiftUI

// One button, three emphases. Every variant is at least 44pt to touch, answers a
// press and has a disabled state, so no action in the app is a tappable sentence
// with a thin hit area.

/// How much a pressed thing gives. A control (button, chip, icon, tag) sinks to 96%; a
/// surface the size of a photograph or a card sinks to 98%, because the same 4% on a
/// 256pt tile reads as a lurch rather than a press.
enum Press {
    case control
    case surface

    var scale: CGFloat {
        switch self {
        case .control: return 0.96
        case .surface: return 0.98
        }
    }
}

/// The plain style drops the system's press feedback, so the surface dims and
/// settles slightly under the finger instead. Built as a ButtonStyle rather than a
/// gesture so it never competes with the tap. Going in takes 100 ms and starts under
/// the finger; letting go takes 150 ms. Under Reduce Motion only the dimming stays.
struct PressStyle: ButtonStyle {
    var press: Press = .control

    func makeBody(configuration: Configuration) -> some View {
        PressBody(label: configuration.label, isPressed: configuration.isPressed, press: press)
    }
}

private struct PressBody<Label: View>: View {
    let label: Label
    let isPressed: Bool
    let press: Press

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        label
            .opacity(isPressed ? 0.85 : 1)
            .scaleEffect(isPressed && !reduceMotion ? press.scale : 1)
            .animation(
                isPressed ? Motion.enter(Motion.pressIn) : .easeOut(duration: Motion.pressOut),
                value: isPressed)
    }
}

private struct ButtonLabel: View {
    let title: String
    let systemImage: String?

    var body: some View {
        HStack(spacing: Space.sm) {
            Text(title).typeset(.button).multilineTextAlignment(.center)
            if let systemImage {
                Image(systemName: systemImage).font(.system(size: 16, weight: .semibold))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 52)
        .padding(.horizontal, Space.xl)
    }
}

/// The one thing to do on a screen: amber with its dark label, 52 tall.
struct PrimaryButton: View {
    let title: String
    var systemImage: String?
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ButtonLabel(title: title, systemImage: systemImage)
                .foregroundStyle(Palette.onAmber)
                .background(
                    Palette.amber,
                    in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
        }
        .buttonStyle(PressStyle())
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
    }
}

/// A control with a border, for the action that is not the main one.
struct SecondaryButton: View {
    let title: String
    var systemImage: String?
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ButtonLabel(title: title, systemImage: systemImage)
                .foregroundStyle(Palette.ink)
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
                        .strokeBorder(Palette.lineControl, lineWidth: 1)
                }
                .contentShape(RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
        }
        .buttonStyle(PressStyle())
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
    }
}

/// Text in ink, no frame and no brand colour: "Ler mais", "Ver todos".
struct QuietButton: View {
    let title: String
    var systemImage: String?
    var role: TypeRole = .cardTitle
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.xxs) {
                Text(title).typeset(role)
                if let systemImage {
                    Image(systemName: systemImage).font(.footnote.weight(.semibold))
                }
            }
            .foregroundStyle(Palette.ink)
            .frame(minHeight: Palette.touch)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
    }
}

/// The round control that floats over a photograph: 42 across, on the scrim, with
/// 44pt to touch.
struct CircleIconButton: View {
    let systemImage: String
    let label: String
    var foreground: Color = .white
    var background: Color = Palette.scrim
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            CircleIcon(systemImage: systemImage, foreground: foreground, background: background)
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(label)
    }
}

/// The face of a `CircleIconButton`, for the controls that are not Buttons (a ShareLink).
struct CircleIcon: View {
    let systemImage: String
    var foreground: Color = .white
    var background: Color = Palette.scrim

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 18, weight: .medium))
            .foregroundStyle(foreground)
            .frame(width: 42, height: 42)
            .background(background, in: Circle())
            .frame(width: Palette.touch, height: Palette.touch)
            .contentShape(Circle())
    }
}
