import UIKit
import ImageIO

/// Loads, decodes and remembers photographs. A photo-first app lives or dies by what happens
/// when a cell scrolls back into view, and `AsyncImage` goes back to the network every time —
/// the shared `URLCache` caps entries at 5% of 10 MB and the catalogue's photos (~870 KB) never
/// fit under that.
///
/// So: a `URLCache` of 64 MB in memory and 256 MB on disk, an `NSCache` of bitmaps already
/// reduced to what the screen shows, and one download per photo and size however many cells
/// ask for it, cancelled when the last one goes away.
final class ImagePipeline: @unchecked Sendable {
    static let shared = ImagePipeline()

    private let session: URLSession
    private let decoded = NSCache<NSString, UIImage>()
    private let lock = NSLock()
    private var flights: [String: Flight] = [:]

    /// One request in the air and the number of views waiting on it.
    private final class Flight {
        var task: Task<UIImage?, Never>?
        var waiters = 1
    }

    init(session: URLSession = ImagePipeline.makeSession()) {
        self.session = session
        decoded.totalCostLimit = 120 * 1024 * 1024
    }

    static func makeSession() -> URLSession {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = URLCache(
            memoryCapacity: 64 * 1024 * 1024,
            diskCapacity: 256 * 1024 * 1024,
            directory: caches.appendingPathComponent("photos", isDirectory: true))
        // A photograph at a given URL never changes: the cached bytes are as good as
        // a fresh download, whatever their age.
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.httpMaximumConnectionsPerHost = 6
        configuration.timeoutIntervalForRequest = 20
        return URLSession(configuration: configuration)
    }

    // MARK: Sizes

    /// The pixel size to decode for a photo shown at `size` points. Rounded up to a
    /// multiple of 64 so that a few points of difference between two layouts reuse
    /// the same bitmap, which is never more than ~1.3x what the screen needs.
    static func maxPixel(for size: CGSize, scale: CGFloat) -> Int {
        let pixels = Int((max(size.width, size.height) * scale).rounded(.up))
        return max(64, (pixels + 63) / 64 * 64)
    }

    private static func key(_ url: URL, _ maxPixel: Int) -> String { "\(maxPixel)|\(url.absoluteString)" }

    // MARK: Loading

    /// The bitmap, if it is already decoded at this size. Synchronous: a cell that
    /// comes back on screen asks this first and draws without a placeholder.
    func cachedImage(for url: URL, maxPixel: Int) -> UIImage? {
        decoded.object(forKey: Self.key(url, maxPixel) as NSString)
    }

    /// The bitmap at this size, downloaded and decoded if need be. Returns nil when
    /// the photo cannot be had. Cancelling the calling task cancels the download once
    /// no other view is waiting for the same photo.
    func image(for url: URL, maxPixel: Int) async -> UIImage? {
        let key = Self.key(url, maxPixel)
        if let hit = decoded.object(forKey: key as NSString) { return hit }
        let flight = join(key: key, url: url, maxPixel: maxPixel)
        return await withTaskCancellationHandler {
            await flight.task?.value
        } onCancel: {
            leave(key: key, flight: flight)
        }
    }

    private func join(key: String, url: URL, maxPixel: Int) -> Flight {
        lock.lock()
        defer { lock.unlock() }
        if let existing = flights[key] {
            existing.waiters += 1
            return existing
        }
        let flight = Flight()
        flight.task = Task.detached(priority: .userInitiated) { [self, flight] in
            let image = await load(key: key, url: url, maxPixel: maxPixel)
            finish(key: key, flight: flight)
            return image
        }
        flights[key] = flight
        return flight
    }

    private func leave(key: String, flight: Flight) {
        lock.lock()
        defer { lock.unlock() }
        flight.waiters -= 1
        guard flight.waiters <= 0 else { return }
        flight.task?.cancel()
        if flights[key] === flight { flights[key] = nil }
    }

    private func finish(key: String, flight: Flight) {
        lock.lock()
        defer { lock.unlock() }
        if flights[key] === flight { flights[key] = nil }
    }

    private func load(key: String, url: URL, maxPixel: Int) async -> UIImage? {
        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
        guard let (data, response) = try? await session.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              !Task.isCancelled,
              let image = Self.downsample(data, maxPixel: maxPixel) else { return nil }
        decoded.setObject(image, forKey: key as NSString, cost: Int(image.size.width * image.size.height) * 4)
        return image
    }

    /// Decodes at most `maxPixel` on the long side straight from the compressed
    /// data. The full-size bitmap (1280 x 960 x 4 bytes, and far more for a camera
    /// original) is never built: ImageIO scales while it decodes.
    static func downsample(_ data: Data, maxPixel: Int) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(
            data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary) else { return nil }
        var target = maxPixel
        // A thumbnail request larger than the picture enlarges it; never do that.
        if let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
           let width = properties[kCGImagePropertyPixelWidth] as? Int,
           let height = properties[kCGImagePropertyPixelHeight] as? Int {
            target = min(target, max(width, height))
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            // Decode now, on this thread, instead of on first draw on the main one.
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: target,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: image)
    }
}
