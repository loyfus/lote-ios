import SwiftUI

/// Empty and error screens share one drawing: a quiet disc with a meaningful glyph,
/// a title that says what is missing, the way out, and, when there is a way out, the
/// button for it. The two never share a screen: a search that matched nothing and a
/// dropped connection need different words and different next steps.
struct StateView: View {
    let symbol: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: Space.lg) {
            Image(systemName: symbol)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(Palette.ink60)
                .frame(width: 64, height: 64)
                .background(Palette.paperDim, in: Circle())
                .accessibilityHidden(true)
            VStack(spacing: Space.sm) {
                Text(title)
                    .typeset(.headline)
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)
                Text(message)
                    .typeset(.small)
                    .foregroundStyle(Palette.ink60)
                    .multilineTextAlignment(.center)
            }
            if let actionTitle, let action {
                PrimaryButton(title: actionTitle, action: action)
                    .frame(maxWidth: 280)
                    .padding(.top, Space.xs)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Space.x3)
        .padding(.vertical, Space.x5)
        .accessibilityElement(children: .contain)
    }
}

// MARK: Skeletons

// Loading is drawn with the geometry of what is coming, in the placeholder colour, so
// the content fades in over it without anything moving. The group breathes
// (skeletonPulse) rather than shimmering: a sweep is motion the eye follows, a slow
// dimming only says "not yet".

/// One line of placeholder text, as wide as a fraction of its container.
struct SkeletonLine: View {
    var fraction: CGFloat = 1
    var height: CGFloat = 14

    var body: some View {
        GeometryReader { proxy in
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Palette.paperDim)
                .frame(width: proxy.size.width * fraction, height: height)
        }
        .frame(height: height)
    }
}

/// A placeholder for a tile: the photo plate and the three lines under it.
struct TileSkeleton: View {
    var variant: LotTile.Variant = .grid

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear
                .aspectRatio(variant.aspect, contentMode: .fit)
                .background(Palette.paperDim)
                .clipShape(RoundedRectangle(cornerRadius: variant.radius, style: .continuous))
            VStack(alignment: .leading, spacing: 8) {
                SkeletonLine(fraction: 0.92, height: 15)
                SkeletonLine(fraction: 0.62, height: 15)
                SkeletonLine(fraction: 0.5, height: 20).padding(.top, 2)
            }
            .padding(.top, 12)
            .padding(.horizontal, 2)
        }
        .frame(width: variant == .shelf ? 256 : nil)
        .accessibilityHidden(true)
    }
}

/// A placeholder for a saved row.
struct RowSkeleton: View {
    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                .fill(Palette.paperDim)
                .frame(width: 104, height: 78)
            VStack(alignment: .leading, spacing: 8) {
                SkeletonLine(fraction: 0.9, height: 15)
                SkeletonLine(fraction: 0.6, height: 15)
                SkeletonLine(fraction: 0.45, height: 20).padding(.top, 2)
            }
        }
        .padding(.horizontal, Space.gutter)
        .padding(.vertical, Space.md)
        .accessibilityHidden(true)
    }
}
