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
    func copy(_ record: ScreenshotRecord, to pasteboard: NSPasteboard = .general) {
        let item = NSPasteboardItem()
        if let png = Self.pngData(for: record.url) {
            item.setData(png, forType: .png)
        }
        item.setString(record.url.absoluteString, forType: .fileURL)

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
    let threads: ThreadsStore
    let threadPanel: ThreadPanelController
    /// The shelf's window, for finding where a card is on screen.
    let shelfPanel: NSWindow

    private var operations: ScreenshotOperations { ScreenshotOperations(store: store) }

    func open(_ record: ScreenshotRecord) {
        threadPanel.close(.backToShelf, animated: false)
        preview.toggle(record)
    }

    func open(_ thread: SkyThread) {
        let contents = ShelfContents(store: store, threads: threads)
        guard let frame = ShelfController.screenFrame(
            of: .thread(id: thread.id), in: contents, containerWidth: state.containerWidth, panelFrame: shelfPanel.frame
        ) else { return }
        preview.close(.backToShelf, animated: false)
        threadPanel.toggle(thread, below: frame)
    }

    /// Resolves a thread, which takes it off the shelf.
    func resolve(_ thread: SkyThread) {
        Task { @MainActor in
            do {
                _ = try await threads.setResolved(true, threadID: thread.id)
            } catch {
                NSSound.beep()
            }
        }
    }

    func revealInFinder(_ record: ScreenshotRecord) {
        operations.revealInFinder(record)
    }

    /// Copies the screenshot and shows a tick. Pass `animated: false` for a
    /// copy made from the keyboard, so the tick appears without a transition.
    func copy(_ record: ScreenshotRecord, animated: Bool = true) {
        operations.copy(record)
        withAnimation(animated ? Motion.symbolSwap : nil) { state.copiedPath = record.path }
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
