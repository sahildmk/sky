import AppKit
import ImageIO
import ScreenCaptureKit
import SkyCore
import SwiftUI
import UniformTypeIdentifiers

/// Renders Sky's views to PNG files without anything appearing on screen, so
/// their appearance can be checked without disturbing whoever is at the Mac.
///
/// Liquid Glass only draws in a live window, so each view is shown in a
/// window placed behind the desktop wallpaper and captured from there with
/// ScreenCaptureKit. That needs the Screen Recording permission.
public enum Snapshots {
    /// Renders the shelf in each state and the preview of the newest
    /// screenshot in `directory`, writing PNGs into `output`.
    @MainActor
    public static func render(screenshotsIn directory: URL, to output: URL) async throws -> [URL] {
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
        func write<V: View>(_ name: String, size: CGSize, _ view: V) async throws {
            let url = output.appendingPathComponent("\(name).png")
            let image = try await captureHiddenWindow(showing: view, size: size)
            try writePNG(image, to: url)
            written.append(url)
        }

        try await write("shelf-collapsed", size: shelfSize, backdrop(ShelfView(store: store, state: shelf, actions: actions)))

        shelf.copiedPath = newest.path
        try await write("shelf-copied", size: shelfSize, backdrop(ShelfView(store: store, state: shelf, actions: actions)))
        shelf.copiedPath = nil

        shelf.isExpanded = true
        try await write("shelf-expanded", size: shelfSize, backdrop(ShelfView(store: store, state: shelf, actions: actions)))

        shelf.hoveredPath = newest.path
        try await write("shelf-hovered", size: shelfSize, backdrop(ShelfView(store: store, state: shelf, actions: actions)))

        // The preview, sized as it would be on a 1512 × 945 point display.
        let state = preview.state
        state.record = newest
        state.image = ScreenshotFiles.thumbnail(for: newest.url, maxPixelSize: 3000).map {
            NSImage(cgImage: $0, size: NSSize(width: $0.width, height: $0.height))
        }
        state.position = records.count > 1 ? "1 of \(records.count)" : nil
        state.defaultAppName = "Preview"
        state.isVisible = true
        state.backingScale = 2
        let content = PreviewGeometry.containerFrame(in: CGRect(x: 0, y: 0, width: 1512, height: 945))
        let previewSize = content.insetBy(dx: -PreviewController.shadowInset, dy: -PreviewController.shadowInset).size
        try await write("preview", size: previewSize, backdrop(PreviewView(state: state) { _ in }))
        state.isPointerInside = true
        try await write("preview-hovered", size: previewSize, backdrop(PreviewView(state: state) { _ in }))

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

    /// Shows `view` in a window behind the desktop wallpaper and captures it.
    @MainActor
    private static func captureHiddenWindow<V: View>(showing view: V, size: CGSize) async throws -> CGImage {
        let window = NSWindow(
            contentRect: CGRect(origin: .zero, size: size),
            styleMask: [.borderless], backing: .buffered, defer: false
        )
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) - 1)
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: view.frame(width: size.width, height: size.height))
        window.orderFrontRegardless()
        defer { window.orderOut(nil) }

        // Give SwiftUI and the window server time to draw the glass.
        try await Task.sleep(for: .milliseconds(600))

        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        guard let captured = content.windows.first(where: { $0.windowID == CGWindowID(window.windowNumber) }) else {
            throw SnapshotError.renderFailed("window \(window.windowNumber)")
        }
        let configuration = SCStreamConfiguration()
        configuration.width = Int(size.width * 2)
        configuration.height = Int(size.height * 2)
        configuration.showsCursor = false
        configuration.ignoreShadowsSingleWindow = true
        return try await SCScreenshotManager.captureImage(
            contentFilter: SCContentFilter(desktopIndependentWindow: captured),
            configuration: configuration
        )
    }

    private static func writePNG(_ image: CGImage, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
        else { throw SnapshotError.renderFailed(url.lastPathComponent) }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw SnapshotError.renderFailed(url.lastPathComponent)
        }
    }
}
