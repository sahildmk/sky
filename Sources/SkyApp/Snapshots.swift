import AppKit
import ImageIO
import SkyCore
import SwiftUI
import UniformTypeIdentifiers

/// Renders Sky's views to PNG files off screen, so their appearance can be
/// checked without opening windows or moving the pointer.
///
/// Frosted-glass materials need a live window to blur what is behind them,
/// so in these images they appear as flat fills.
public enum Snapshots {
    /// Renders the shelf in each state and the preview of the newest
    /// screenshot in `directory`, writing PNGs into `output`.
    @MainActor
    public static func render(screenshotsIn directory: URL, to output: URL) throws -> [URL] {
        let records = ScreenshotFiles.recent(in: directory, limit: ShelfStore.capacity)
        guard let newest = records.first else {
            throw SnapshotError.noScreenshots(directory)
        }
        let thumbnails = Dictionary(uniqueKeysWithValues: records.compactMap { record -> (String, NSImage)? in
            guard let image = ScreenshotFiles.thumbnail(for: record.url, maxPixelSize: 720) else { return nil }
            return (record.path, NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height)))
        })

        let store = ShelfStore(items: records, thumbnails: thumbnails)
        let preview = PreviewController(store: store)
        let shelf = ShelfState()
        shelf.isPresented = true
        shelf.containerWidth = 1512
        let actions = ShelfActions(store: store, state: shelf, preview: preview)
        let shelfSize = CGSize(width: shelf.containerWidth, height: ShelfController.panelHeight)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

        var written: [URL] = []
        func write<V: View>(_ name: String, size: CGSize, _ view: V) throws {
            let url = output.appendingPathComponent("\(name).png")
            try writePNG(view.frame(width: size.width, height: size.height), to: url)
            written.append(url)
        }

        try write("shelf-collapsed", size: shelfSize, backdrop(ShelfView(store: store, state: shelf, actions: actions)))

        shelf.isExpanded = true
        try write("shelf-expanded", size: shelfSize, backdrop(ShelfView(store: store, state: shelf, actions: actions)))

        shelf.hoveredPath = newest.path
        try write("shelf-hovered", size: shelfSize, backdrop(ShelfView(store: store, state: shelf, actions: actions)))

        // The preview, sized as it would be on a 1512 × 945 point display.
        let state = preview.state
        state.record = newest
        state.image = ScreenshotFiles.thumbnail(for: newest.url, maxPixelSize: 3000).map {
            NSImage(cgImage: $0, size: NSSize(width: $0.width, height: $0.height))
        }
        state.position = records.count > 1 ? "1 of \(records.count)" : nil
        state.defaultAppName = "Preview"
        state.isVisible = true
        let content = PreviewGeometry.frame(
            forPixelSize: CGSize(width: newest.pixelWidth, height: newest.pixelHeight),
            backingScale: 2,
            in: CGRect(x: 0, y: 0, width: 1512, height: 945),
            margin: PreviewController.screenMargin,
            minimumSize: PreviewController.minimumSize
        )
        let previewSize = content.insetBy(dx: -PreviewController.shadowInset, dy: -PreviewController.shadowInset).size
        try write("preview", size: previewSize, backdrop(PreviewView(state: state) { _ in }))
        state.isPointerInside = true
        try write("preview-hovered", size: previewSize, backdrop(PreviewView(state: state) { _ in }))

        return written
    }

    enum SnapshotError: Error, CustomStringConvertible {
        case noScreenshots(URL)
        case renderFailed(String)

        var description: String {
            switch self {
            case .noScreenshots(let directory): "No screenshots found in \(directory.path)"
            case .renderFailed(let name): "Could not render \(name)"
            }
        }
    }

    /// A desktop-like backdrop, so shadows and translucent edges are visible.
    private static func backdrop<V: View>(_ view: V) -> some View {
        view.background(
            LinearGradient(
                colors: [Color(red: 0.42, green: 0.55, blue: 0.75), Color(red: 0.75, green: 0.62, blue: 0.70)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
    }

    @MainActor
    private static func writePNG<V: View>(_ view: V, to url: URL) throws {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let image = renderer.cgImage,
              let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
        else { throw SnapshotError.renderFailed(url.lastPathComponent) }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw SnapshotError.renderFailed(url.lastPathComponent)
        }
    }
}
