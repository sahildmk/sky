import AppKit
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import SkyApp
@testable import SkyCore

/// Copies go to a private pasteboard, so these tests never touch the clipboard.
@MainActor
@Suite struct CopyTests {
    let directory: URL
    let pasteboard = NSPasteboard(name: NSPasteboard.Name("SkyAppTests-\(UUID().uuidString)"))
    let operations = ScreenshotOperations(store: ShelfStore(items: [], thumbnails: [:]))

    init() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SkyAppTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    @Test func copyingAPNGPutsTheImageAndTheFileOnThePasteboard() throws {
        let url = try makeImage("shot.png", type: .png)
        operations.copy(record(url), to: pasteboard)

        #expect(pasteboard.data(forType: .png) == (try Data(contentsOf: url)))
        #expect(pasteboard.string(forType: .fileURL) == url.absoluteString)
    }

    @Test func copyingAnotherFormatStillPutsAPNGOnThePasteboard() throws {
        let url = try makeImage("shot.jpg", type: .jpeg)
        operations.copy(record(url), to: pasteboard)

        let png = try #require(pasteboard.data(forType: .png))
        #expect(png.prefix(8) == Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]))
        #expect(pasteboard.string(forType: .fileURL) == url.absoluteString)
    }

    @Test func copyingReplacesWhatWasThere() throws {
        pasteboard.clearContents()
        pasteboard.setString("earlier text", forType: .string)
        operations.copy(record(try makeImage("shot.png", type: .png)), to: pasteboard)

        #expect(pasteboard.string(forType: .string) == nil)
    }

    private func record(_ url: URL) -> ScreenshotRecord {
        ScreenshotRecord(url: url, createdAt: Date(), pixelWidth: 8, pixelHeight: 8)
    }

    private func makeImage(_ name: String, type: UTType) throws -> URL {
        let url = directory.appendingPathComponent(name)
        let context = try #require(CGContext(
            data: nil, width: 8, height: 8, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(CGColor(red: 0.9, green: 0.3, blue: 0.2, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        let image = try #require(context.makeImage())
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return url
    }
}
