import Foundation
import ImageIO

/// A screenshot file on disk, with the details the shelf needs to lay it out.
public struct ScreenshotRecord: Hashable, Sendable {
    public let url: URL
    public let createdAt: Date
    public let pixelWidth: Int
    public let pixelHeight: Int

    public init(url: URL, createdAt: Date, pixelWidth: Int, pixelHeight: Int) {
        self.url = url
        self.createdAt = createdAt
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
    }

    /// Width divided by height. Falls back to 16:10 when the size is unknown.
    public var aspectRatio: CGFloat {
        guard pixelWidth > 0, pixelHeight > 0 else { return 16.0 / 10.0 }
        return CGFloat(pixelWidth) / CGFloat(pixelHeight)
    }

    public var path: String { url.path }
}

/// Recognises screenshots by the metadata macOS writes onto them, so detection
/// works regardless of the user's language, file naming or file format.
public enum ScreenshotFiles {
    /// Extended attribute macOS sets to `true` on every screen capture it saves.
    public static let screenCaptureAttribute = "com.apple.metadata:kMDItemIsScreenCapture"

    static let imageExtensions: Set<String> = [
        "png", "jpg", "jpeg", "heic", "tif", "tiff", "gif", "bmp", "pdf",
    ]

    /// A visible file with an image extension. Says nothing about whether it is a screenshot.
    /// One spelling per file, so the same file always compares equal however
    /// its path was reached (`/var` and `/private/var`, for example).
    public static func canonical(_ url: URL) -> URL {
        url.standardizedFileURL.resolvingSymlinksInPath()
    }

    public static func isCandidate(_ url: URL) -> Bool {
        !url.lastPathComponent.hasPrefix(".")
            && imageExtensions.contains(url.pathExtension.lowercased())
    }

    public static func isScreenshot(_ url: URL) -> Bool {
        isCandidate(url) && isMarkedAsScreenCapture(url)
    }

    public static func isMarkedAsScreenCapture(_ url: URL) -> Bool {
        let path = url.path
        let size = getxattr(path, screenCaptureAttribute, nil, 0, 0, XATTR_NOFOLLOW)
        guard size > 0 else { return false }
        var data = Data(count: size)
        let read = data.withUnsafeMutableBytes { buffer in
            getxattr(path, screenCaptureAttribute, buffer.baseAddress, size, 0, XATTR_NOFOLLOW)
        }
        guard read == size,
              let value = try? PropertyListSerialization.propertyList(from: data, format: nil)
        else { return false }
        return (value as? Bool) ?? (value as? NSNumber)?.boolValue ?? false
    }

    /// Reads a screenshot's creation date and pixel size. Nil when the file is not a screenshot.
    public static func record(for url: URL) -> ScreenshotRecord? {
        let url = canonical(url)
        guard isScreenshot(url) else { return nil }
        let values = try? url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
        let createdAt = values?.creationDate ?? values?.contentModificationDate ?? Date()

        var width = 0
        var height = 0
        if let source = CGImageSourceCreateWithURL(url as CFURL, nil),
           let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] {
            width = (properties[kCGImagePropertyPixelWidth] as? Int) ?? 0
            height = (properties[kCGImagePropertyPixelHeight] as? Int) ?? 0
        }
        return ScreenshotRecord(url: url, createdAt: createdAt, pixelWidth: width, pixelHeight: height)
    }

    /// The newest screenshots directly inside `directory`, newest first.
    /// `excluded` holds canonical paths.
    public static func recent(
        in directory: URL,
        limit: Int,
        excludingPaths excluded: Set<String> = []
    ) -> [ScreenshotRecord] {
        guard limit > 0,
              let urls = try? FileManager.default.contentsOfDirectory(
                  at: directory,
                  includingPropertiesForKeys: [.creationDateKey],
                  options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
              )
        else { return [] }

        let newestFirst = urls
            .map(canonical)
            .filter { isCandidate($0) && !excluded.contains($0.path) }
            .map { url in
                (url, (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast)
            }
            .sorted { $0.1 > $1.1 }

        var records: [ScreenshotRecord] = []
        for (url, _) in newestFirst {
            guard let record = record(for: url) else { continue }
            records.append(record)
            if records.count == limit { break }
        }
        return records
    }

    /// A downscaled image for display, decoded without loading the full-resolution bitmap.
    public static func thumbnail(for url: URL, maxPixelSize: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}
