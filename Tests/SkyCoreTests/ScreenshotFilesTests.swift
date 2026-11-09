import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import SkyCore

@Suite struct ScreenshotFilesTests {
    let directory: URL

    init() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SkyCoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    @Test func recognisesAFileMacOSMarkedAsAScreenCapture() throws {
        let url = try makeImage("Capture.png", width: 40, height: 20, markedAsScreenCapture: true)

        let record = try #require(ScreenshotFiles.record(for: url))
        #expect(record.pixelWidth == 40)
        #expect(record.pixelHeight == 20)
        #expect(record.aspectRatio == 2)
    }

    @Test func sameFileReachedThroughASymlinkHasOnePath() throws {
        let url = try makeImage("linked.png", markedAsScreenCapture: true)
        let link = directory.appendingPathComponent("link", isDirectory: true)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: directory)
        let viaLink = link.appendingPathComponent("linked.png")

        #expect(ScreenshotFiles.record(for: viaLink)?.path == ScreenshotFiles.record(for: url)?.path)
    }

    @Test func ignoresAnImageWithoutTheScreenCaptureMark() throws {
        let url = try makeImage("Photo.png", markedAsScreenCapture: false)
        #expect(ScreenshotFiles.record(for: url) == nil)
    }

    @Test func ignoresAScreenCaptureMarkSetToFalse() throws {
        let url = try makeImage("Odd.png", markedAsScreenCapture: false)
        try setScreenCaptureMark(false, on: url)
        #expect(!ScreenshotFiles.isScreenshot(url))
    }

    @Test func ignoresHiddenFilesWhileMacOSIsStillWritingThem() throws {
        let url = try makeImage(".Screenshot in progress.png", markedAsScreenCapture: true)
        #expect(!ScreenshotFiles.isScreenshot(url))
    }

    @Test func listsTheNewestScreenshotsFirstUpToTheLimit() throws {
        let now = Date()
        for (name, age) in [("a.png", 300.0), ("b.png", 100.0), ("c.png", 200.0), ("d.png", 50.0)] {
            let url = try makeImage(name, markedAsScreenCapture: true)
            try FileManager.default.setAttributes([.creationDate: now - age], ofItemAtPath: url.path)
        }
        let notAScreenshot = try makeImage("newest-photo.png", markedAsScreenCapture: false)
        try FileManager.default.setAttributes([.creationDate: now], ofItemAtPath: notAScreenshot.path)

        let names = ScreenshotFiles.recent(in: directory, limit: 3).map(\.url.lastPathComponent)
        #expect(names == ["d.png", "b.png", "c.png"])
    }

    @Test func leavesOutExcludedPaths() throws {
        let kept = try makeImage("kept.png", markedAsScreenCapture: true)
        let removed = try makeImage("removed.png", markedAsScreenCapture: true)

        let paths = ScreenshotFiles.recent(
            in: directory, limit: 10, excludingPaths: [ScreenshotFiles.canonical(removed).path]
        ).map(\.path)
        #expect(paths == [ScreenshotFiles.canonical(kept).path])
    }

    @Test func thumbnailsAreDownscaledToTheRequestedSize() throws {
        let url = try makeImage("big.png", width: 400, height: 100, markedAsScreenCapture: true)
        let thumbnail = try #require(ScreenshotFiles.thumbnail(for: url, maxPixelSize: 80))
        #expect(thumbnail.width == 80)
        #expect(thumbnail.height == 20)
    }

    // MARK: Fixtures

    private func makeImage(_ name: String, width: Int = 8, height: Int = 8, markedAsScreenCapture: Bool) throws -> URL {
        let url = directory.appendingPathComponent(name)
        let context = try #require(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(CGColor(red: 0.2, green: 0.5, blue: 0.9, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try #require(context.makeImage())
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        if markedAsScreenCapture { try setScreenCaptureMark(true, on: url) }
        return url
    }

    /// Writes the attribute the way macOS does: a binary property list holding a Boolean.
    private func setScreenCaptureMark(_ value: Bool, on url: URL) throws {
        let data = try PropertyListSerialization.data(fromPropertyList: value, format: .binary, options: 0)
        let result = data.withUnsafeBytes { buffer in
            setxattr(url.path, ScreenshotFiles.screenCaptureAttribute, buffer.baseAddress, data.count, 0, 0)
        }
        #expect(result == 0)
    }
}
