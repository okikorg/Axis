import AppKit
import Foundation

// MARK: - Cached Image

struct CachedImage {
    let image: NSImage
    let displaySize: NSSize
}

// MARK: - Inline Image Cache

final class InlineImageCache {
    static let shared = InlineImageCache()

    private let cache = NSCache<NSString, CachedImageWrapper>()
    private let queue = DispatchQueue(label: "com.axis.imagecache", attributes: .concurrent)
    private let maxDisplayHeight: CGFloat = 400

    private init() {
        cache.countLimit = 100
    }

    func image(for path: String, baseURL: URL?, maxWidth: CGFloat) -> CachedImage? {
        let resolved = resolvePath(path, baseURL: baseURL)
        let key = "\(resolved.path):\(Int(maxWidth))" as NSString

        // Check cache first
        if let wrapper = cache.object(forKey: key) {
            return wrapper.value
        }

        // Skip remote URLs
        guard resolved.isFileURL else { return nil }

        // Decode percent-encoded paths
        let filePath = resolved.path
        guard FileManager.default.fileExists(atPath: filePath),
              let nsImage = NSImage(contentsOfFile: filePath) else {
            return nil
        }

        let originalSize = nsImage.size
        guard originalSize.width > 0, originalSize.height > 0 else { return nil }

        // Scale to fit maxWidth, preserving aspect ratio, capped at maxDisplayHeight
        var displayWidth = min(originalSize.width, maxWidth)
        var displayHeight = displayWidth * (originalSize.height / originalSize.width)

        if displayHeight > maxDisplayHeight {
            displayHeight = maxDisplayHeight
            displayWidth = displayHeight * (originalSize.width / originalSize.height)
        }

        let displaySize = NSSize(width: displayWidth, height: displayHeight)
        let cached = CachedImage(image: nsImage, displaySize: displaySize)

        cache.setObject(CachedImageWrapper(cached), forKey: key)
        return cached
    }

    func invalidateAll() {
        cache.removeAllObjects()
    }

    // MARK: - Path Resolution

    private func resolvePath(_ path: String, baseURL: URL?) -> URL {
        // Decode URL-encoded characters
        let decoded = path.removingPercentEncoding ?? path

        // Absolute path
        if decoded.hasPrefix("/") {
            return URL(fileURLWithPath: decoded)
        }

        // Relative path: resolve from the directory containing the markdown file
        if let base = baseURL {
            let dir = base.deletingLastPathComponent()
            return dir.appendingPathComponent(decoded).standardized
        }

        return URL(fileURLWithPath: decoded)
    }
}

// MARK: - NSCache Wrapper

private class CachedImageWrapper: NSObject {
    let value: CachedImage
    init(_ value: CachedImage) {
        self.value = value
    }
}
