import SwiftUI

/// The photograph, never cropped, on a blurred copy of itself. Seller banners and watermarks are
/// part of the listing and cutting them produced plates that read as broken images; fitting
/// leaves bars, filled with its own colours rather than an empty grey.
///
/// The copy is the same decoded bitmap, so it costs no download and no second decode, and it is
/// left out when the picture already fills the plate.
struct PhotoCanvas: View {
    enum Mode {
        /// The whole picture, on a blurred copy of itself.
        case fit
        /// The picture cropped to fill, for thumbnails where there is no room for bars.
        case fill
    }

    let url: String?
    var mode: Mode = .fit

    @Environment(\.displayScale) private var displayScale
    @State private var loaded: (url: String, image: UIImage)?
    @State private var failed = false

    private struct LoadKey: Hashable {
        let url: String?
        let pixel: Int
    }

    var body: some View {
        // The size the plate really has decides how much to decode, so the canvas
        // measures itself instead of being told: a grid column is only known once
        // the grid has laid out.
        GeometryReader { proxy in
            let pixel = ImagePipeline.maxPixel(for: proxy.size, scale: displayScale)
            let remote = remoteURL
            let shown = shownImage(remote: remote, pixel: pixel)
            ZStack {
                if let shown {
                    layers(shown, in: proxy.size).transition(.opacity)
                } else if remote == nil || failed {
                    NoPhoto()
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .task(id: LoadKey(url: url, pixel: pixel)) {
                await load(remote, pixel: pixel, size: proxy.size)
            }
        }
    }

    private var remoteURL: URL? {
        guard let url, !url.isEmpty else { return nil }
        return URL(string: url)
    }

    /// A bitmap already decoded at this size wins, so a cell that scrolls back draws
    /// its photo in the first frame. Otherwise whatever this view has loaded for
    /// this address, even at another size, while the right one is on its way.
    private func shownImage(remote: URL?, pixel: Int) -> UIImage? {
        guard let remote else { return nil }
        if let hit = ImagePipeline.shared.cachedImage(for: remote, maxPixel: pixel) { return hit }
        if let loaded, loaded.url == remote.absoluteString { return loaded.image }
        return nil
    }

    private func load(_ remote: URL?, pixel: Int, size: CGSize) async {
        failed = false
        guard let remote, size.width > 1, size.height > 1 else { return }
        if ImagePipeline.shared.cachedImage(for: remote, maxPixel: pixel) != nil { return }
        let image = await ImagePipeline.shared.image(for: remote, maxPixel: pixel)
        guard !Task.isCancelled else { return }
        withAnimation(.easeOut(duration: Motion.standard)) {
            if let image {
                loaded = (remote.absoluteString, image)
            } else {
                failed = true
            }
        }
    }

    @ViewBuilder
    private func layers(_ image: UIImage, in size: CGSize) -> some View {
        let imageAspect = image.size.width / max(image.size.height, 1)
        let plateAspect = size.width / max(size.height, 1)
        if mode == .fill {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size.width, height: size.height)
                .clipped()
        } else {
            fitted(image, in: size, needsAmbient: abs(imageAspect / plateAspect - 1) > 0.02)
        }
    }

    private func fitted(_ image: UIImage, in size: CGSize, needsAmbient: Bool) -> some View {
        ZStack {
            if needsAmbient {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .clipped()
                    .scaleEffect(1.3)
                    .blur(radius: 22, opaque: true)
                    .saturation(1.15)
                    .opacity(0.62)
            }
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }
}

/// A lot with no photo is normal in this catalogue, not an error: say so quietly
/// instead of leaving a blank rectangle that reads as a broken image.
private struct NoPhoto: View {
    var body: some View {
        VStack(spacing: Space.xs + 2) {
            Image(systemName: "camera").font(.title3)
            Text("Sem foto").typeset(.captionStrong)
        }
        .foregroundStyle(Palette.ink60)
    }
}

/// A photo in a box of fixed proportion, with room for badges. The plate is
/// `paperDim` until the picture arrives, so a grid never flashes white.
struct PhotoPlate<Overlay: View>: View {
    let url: String?
    /// Width over height. Nil: take whatever box the parent offers.
    var aspect: CGFloat?
    var radius: CGFloat = 0
    @ViewBuilder var overlay: () -> Overlay

    var body: some View {
        // Color.clear takes the offered size and never proposes its own, so a large
        // photo cannot inflate a grid cell: the picture lives in an overlay, laid
        // out against a box that is already fixed.
        box
            .background(Palette.paperDim)
            .overlay { PhotoCanvas(url: url).accessibilityHidden(true) }
            .overlay { overlay() }
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    @ViewBuilder
    private var box: some View {
        if let aspect {
            Color.clear.aspectRatio(aspect, contentMode: .fit)
        } else {
            Color.clear
        }
    }
}

extension PhotoPlate where Overlay == EmptyView {
    init(url: String?, aspect: CGFloat? = nil, radius: CGFloat = 0) {
        self.init(url: url, aspect: aspect, radius: radius) { EmptyView() }
    }
}
