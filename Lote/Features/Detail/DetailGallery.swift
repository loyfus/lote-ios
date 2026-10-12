import SwiftUI
import UIKit

/// The photographs of a lot, edge to edge, one page each. Swipe through them; a tap
/// opens the viewer. The photo is never cropped: what the plate does not cover is
/// filled with a blurred copy of the picture itself.
struct DetailGallery: View {
    let images: [String]
    let height: CGFloat
    @Binding var index: Int
    let onOpen: () -> Void

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Palette.paperDim
            if images.isEmpty {
                PhotoCanvas(url: nil)
            } else {
                pager
                counter
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .clipped()
        .overlay(alignment: .top) { statusBarVeil }
    }

    /// The status bar draws over the photograph in the theme's own ink: dark in the
    /// light theme, light in the dark one. A veil of the paper colour fading out
    /// beneath it keeps that legible whatever the photograph is.
    private var statusBarVeil: some View {
        LinearGradient(
            colors: [Palette.paper.opacity(0.55), Palette.paper.opacity(0)],
            startPoint: .top, endPoint: .bottom
        )
        .frame(height: 90)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var pager: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(Array(images.enumerated()), id: \.offset) { position, url in
                    Button(action: onOpen) {
                        PhotoCanvas(url: url)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .containerRelativeFrame(.horizontal)
                    .frame(height: height)
                    .id(position)
                    .accessibilityLabel("Foto \(position + 1) de \(images.count)")
                    .accessibilityHint("Abre a foto em tela cheia")
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: position)
        .scrollIndicators(.hidden)
    }

    private var position: Binding<Int?> {
        Binding(get: { index }, set: { if let value = $0 { index = value } })
    }

    private var counter: some View {
        HStack(spacing: 5) {
            Image(systemName: "photo.on.rectangle").font(.system(size: 13, weight: .semibold))
            Text("\(index + 1) / \(images.count)").typeset(.chip)
        }
        .foregroundStyle(Color.white)
        .padding(.horizontal, 10)
        .frame(minHeight: 26)
        .background(Palette.scrim, in: Capsule())
        .padding(14)
        // Each page already says "Foto N de M".
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

// MARK: - Viewer

/// The photographs on black, full screen. Pinch to zoom from 1x to 4x, double tap for
/// 2.5x and back; while a photo is zoomed a drag moves it instead of turning the page.
struct PhotoViewer: View {
    let images: [String]
    let shareText: String
    @Binding var index: Int

    @Environment(\.dismiss) private var dismiss
    @State private var zoomed = false

    var body: some View {
        VStack(spacing: 0) {
            topBar
            pager
            thumbnails
        }
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .statusBarHidden()
    }

    private var topBar: some View {
        ZStack {
            Text("\(index + 1) / \(images.count)")
                .typeset(.cardTitle)
                .monospacedDigit()
                .foregroundStyle(Color.white)
                .accessibilityLabel("Foto \(index + 1) de \(images.count)")
            HStack {
                CircleIconButton(systemImage: "xmark", label: "Fechar", background: Color.white.opacity(0.14)) {
                    dismiss()
                }
                Spacer(minLength: 0)
                ShareLink(item: shareText) {
                    CircleIcon(systemImage: "square.and.arrow.up", background: Color.white.opacity(0.14))
                }
                .accessibilityLabel("Compartilhar")
            }
        }
        .padding(.horizontal, 15)
        .padding(.top, Space.xs)
    }

    private var pager: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(Array(images.enumerated()), id: \.offset) { position, url in
                    ZoomableImage(url: url, isCurrent: position == index, zoomed: $zoomed)
                        .containerRelativeFrame([.horizontal, .vertical])
                        .id(position)
                        .accessibilityLabel("Foto \(position + 1) de \(images.count)")
                        .accessibilityAddTraits(.isImage)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: scrollPosition)
        .scrollDisabled(zoomed)
        .scrollIndicators(.hidden)
        .frame(maxHeight: .infinity)
    }

    private var scrollPosition: Binding<Int?> {
        Binding(get: { index }, set: { if let value = $0 { index = value } })
    }

    /// The way to any photo that is not a swipe away: 60 x 60, the current one outlined.
    private var thumbnails: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                LazyHStack(spacing: Space.sm) {
                    ForEach(Array(images.enumerated()), id: \.offset) { position, url in
                        Button {
                            index = position
                        } label: {
                            PhotoCanvas(url: url, mode: .fill)
                                .frame(width: 60, height: 60)
                                .background(Palette.paperDim)
                                .clipShape(RoundedRectangle(cornerRadius: Radius.tag, style: .continuous))
                                .overlay {
                                    if position == index {
                                        RoundedRectangle(cornerRadius: Radius.tag, style: .continuous)
                                            .strokeBorder(Color.white, lineWidth: 2)
                                    }
                                }
                                .opacity(position == index ? 1 : 0.55)
                                .frame(width: 60, height: 60)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .id(position)
                        .accessibilityLabel("Foto \(position + 1)")
                        .accessibilityAddTraits(position == index ? .isSelected : [])
                    }
                }
            }
            .contentMargins(.horizontal, Space.lg, for: .scrollContent)
            .scrollIndicators(.hidden)
            .onChange(of: index) { _, now in
                withAnimation(.easeOut(duration: Motion.standard)) { proxy.scrollTo(now, anchor: .center) }
            }
            .onAppear { proxy.scrollTo(index, anchor: .center) }
        }
        .frame(height: 60)
        .padding(.top, Space.sm)
        .padding(.bottom, 30)
    }
}

// MARK: - Zoom

/// One photograph in a scroll view that does the zooming: pinch, double tap, drag and
/// the bounce at the limits are UIKit's own, which no gesture assembled in SwiftUI
/// gets quite right.
struct ZoomableImage: UIViewRepresentable {
    let url: String
    let isCurrent: Bool
    @Binding var zoomed: Bool

    func makeUIView(context: Context) -> ZoomScrollView {
        let view = ZoomScrollView()
        let zoomed = $zoomed
        view.onZoomChange = { value in
            // Called during layout and animation; the state change waits for the turn.
            DispatchQueue.main.async { zoomed.wrappedValue = value }
        }
        return view
    }

    func updateUIView(_ view: ZoomScrollView, context: Context) {
        view.show(url: url)
        if !isCurrent { view.resetZoom() }
    }

    static func dismantleUIView(_ view: ZoomScrollView, coordinator: ()) {
        view.cancelLoading()
    }
}

final class ZoomScrollView: UIScrollView, UIScrollViewDelegate {
    static let doubleTapScale: CGFloat = 2.5
    private let imageView = UIImageView()
    private var loadedURL: String?
    private var loading: Task<Void, Never>?
    private var reportedZoomed = false

    var onZoomChange: ((Bool) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        delegate = self
        minimumZoomScale = 1
        maximumZoomScale = 4
        bouncesZoom = true
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        contentInsetAdjustmentBehavior = .never
        backgroundColor = .clear
        isAccessibilityElement = true
        accessibilityTraits = .image
        addSubview(imageView)
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        addGestureRecognizer(doubleTap)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    /// Loads the photograph at the size a screen can use of it: 2048 px is more than
    /// the catalogue's photos have, so they come through whole.
    func show(url: String) {
        guard url != loadedURL else { return }
        loadedURL = url
        loading?.cancel()
        guard let remote = URL(string: url) else { return }
        loading = Task { [weak self] in
            let image = await ImagePipeline.shared.image(for: remote, maxPixel: 2048)
            guard !Task.isCancelled, let self, let image else { return }
            self.imageView.image = image
            self.zoomScale = 1
            self.setNeedsLayout()
            UIView.transition(with: self.imageView, duration: Motion.standard, options: .transitionCrossDissolve, animations: nil)
        }
    }

    func cancelLoading() { loading?.cancel() }

    func resetZoom() {
        if zoomScale != minimumZoomScale { setZoomScale(minimumZoomScale, animated: false) }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let image = imageView.image, bounds.width > 0, bounds.height > 0 else { return }
        // The picture is laid out at its fitted size only when it is not zoomed: while
        // it is, the scroll view owns the geometry.
        if zoomScale == minimumZoomScale {
            let fit = min(bounds.width / image.size.width, bounds.height / image.size.height)
            let size = CGSize(width: image.size.width * fit, height: image.size.height * fit)
            imageView.frame = CGRect(origin: .zero, size: size)
            contentSize = size
        }
        centerContent()
    }

    /// A picture smaller than the screen sits in the middle of it, and stays there
    /// as it grows, until it is bigger than the screen and can be dragged.
    private func centerContent() {
        let vertical = max((bounds.height - contentSize.height) / 2, 0)
        let horizontal = max((bounds.width - contentSize.width) / 2, 0)
        contentInset = UIEdgeInsets(top: vertical, left: horizontal, bottom: vertical, right: horizontal)
        if zoomScale == minimumZoomScale {
            contentOffset = CGPoint(x: -horizontal, y: -vertical)
        }
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerContent()
        let isZoomed = zoomScale > minimumZoomScale + 0.01
        if isZoomed != reportedZoomed {
            reportedZoomed = isZoomed
            onZoomChange?(isZoomed)
        }
    }

    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        if zoomScale > minimumZoomScale + 0.01 {
            setZoomScale(minimumZoomScale, animated: true)
            return
        }
        let point = gesture.location(in: imageView)
        let size = CGSize(width: bounds.width / Self.doubleTapScale, height: bounds.height / Self.doubleTapScale)
        zoom(
            to: CGRect(x: point.x - size.width / 2, y: point.y - size.height / 2, width: size.width, height: size.height),
            animated: true)
    }
}
