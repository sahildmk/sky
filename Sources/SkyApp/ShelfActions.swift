import AppKit
import SkyCore
import SwiftUI
import UniformTypeIdentifiers

/// What a person can do with a screenshot, from the shelf or the preview.
@MainActor
struct ScreenshotOperations {
    let store: ShelfStore

    func openInDefaultApp(_ record: ScreenshotRecord) {
        NSWorkspace.shared.open(record.url)
    }

    func revealInFinder(_ record: ScreenshotRecord) {
        NSWorkspace.shared.activateFileViewerSelecting([record.url])
    }

    /// Puts both the image and the file on the clipboard, so pasting works in
    /// apps that want pixels (chat, docs) and apps that want a file (Finder, mail).
    func copy(_ record: ScreenshotRecord) {
        let item = NSPasteboardItem()
        if let png = Self.pngData(for: record.url) {
            item.setData(png, forType: .png)
        }
        item.setString(record.url.absoluteString, forType: .fileURL)

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([item])
    }

    /// Moves the file to the Trash and takes it off the shelf.
    func moveToTrash(_ record: ScreenshotRecord, then completion: @escaping @MainActor (Bool) -> Void = { _ in }) {
        NSWorkspace.shared.recycle([record.url]) { _, error in
            Task { @MainActor in
                if error == nil {
                    withAnimation(Motion.rearrange) { store.remove(record) }
                } else {
                    NSSound.beep()
                }
                completion(error == nil)
            }
        }
    }

    private static func pngData(for url: URL) -> Data? {
        if UTType(filenameExtension: url.pathExtension) == .png {
            return try? Data(contentsOf: url)
        }
        guard let image = NSImage(contentsOf: url),
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff)
        else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
}

/// Actions wired to the shelf's cards.
@MainActor
struct ShelfActions {
    let store: ShelfStore
    let state: ShelfState
    let preview: PreviewController

    private var operations: ScreenshotOperations { ScreenshotOperations(store: store) }

    func open(_ record: ScreenshotRecord) {
        preview.toggle(record)
    }

    func revealInFinder(_ record: ScreenshotRecord) {
        operations.revealInFinder(record)
    }

    func copy(_ record: ScreenshotRecord) {
        operations.copy(record)
        withAnimation(Motion.hover) { state.copiedPath = record.path }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.4))
            if state.copiedPath == record.path {
                withAnimation(Motion.hover) { state.copiedPath = nil }
            }
        }
    }

    func moveToTrash(_ record: ScreenshotRecord) {
        operations.moveToTrash(record)
    }

    func removeFromShelf(_ record: ScreenshotRecord) {
        withAnimation(Motion.rearrange) { store.remove(record) }
    }
}

/// Animation curves, collapsed to quick fades when Reduce Motion is on.
@MainActor
enum Motion {
    private static var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    private static func spring(_ response: Double, _ damping: Double) -> Animation {
        reduceMotion ? .easeOut(duration: 0.15) : .spring(response: response, dampingFraction: damping)
    }

    static var present: Animation { spring(0.5, 0.78) }
    static var dismiss: Animation { reduceMotion ? .easeIn(duration: 0.15) : .smooth(duration: 0.32) }
    static var expand: Animation { spring(0.42, 0.8) }
    static var collapse: Animation { spring(0.36, 0.88) }
    static var hover: Animation { spring(0.22, 0.8) }
    static var rearrange: Animation { spring(0.4, 0.82) }
    static var arrive: Animation { spring(0.55, 0.7) }
    static var previewIn: Animation { spring(0.34, 0.82) }
    static var previewOut: Animation { reduceMotion ? .easeIn(duration: 0.12) : .easeIn(duration: 0.16) }
    static var crossfade: Animation { .easeInOut(duration: reduceMotion ? 0.1 : 0.18) }
}
