import AppKit
import Observation
import SkyCore
import SwiftUI

/// What the preview window is showing. The controller writes it; `PreviewView` draws it.
@MainActor
@Observable
final class PreviewState {
    var record: ScreenshotRecord?
    var image: NSImage?
    var isVisible = false
    var isPointerInside = false
    var isCopied = false
    /// "3 of 9", or nil when there is only one screenshot.
    var position: String?
    /// The app a double-click opens the screenshot in, such as "Preview".
    var defaultAppName: String?
    /// Screen pixels per point on the display the preview is on.
    var backingScale: CGFloat = 2
}

enum PreviewCommand {
    case close, previous, next, copy, revealInFinder, openInDefaultApp, moveToTrash
}

/// How the preview was dismissed, which decides where keyboard focus goes next.
enum PreviewDismissal {
    /// Esc, Space, the close button, or the card clicked again: focus goes
    /// back to the shelf the preview was opened from.
    case backToShelf
    /// A click in another app, or a command that opens one (Finder, the
    /// default app): focus stays with that app.
    case elsewhere
}

/// A borderless window that can take keyboard focus without activating Sky,
/// so the app you were in stays frontmost while you look at a screenshot.
final class PreviewPanel: NSPanel {
    /// Called for each keyboard command.
    var perform: (PreviewCommand) -> Void = { _ in }

    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        // The preview animates itself; the system fade would double it up.
        animationBehavior = .none
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func keyDown(with event: NSEvent) {
        // A held key repeats only for stepping between screenshots. Repeating
        // anything else would, for example, trash one screenshot after another.
        if event.isARepeat, event.keyCode != 123, event.keyCode != 124 { return }
        let command = event.modifierFlags.contains(.command)
        switch event.keyCode {
        case 53, 49: perform(.close)            // Escape, Space
        case 123: perform(.previous)            // ←
        case 124: perform(.next)                // →
        case 36 where command: perform(.openInDefaultApp)   // ⌘Return
        case 51 where command, 117 where command: perform(.moveToTrash)   // ⌘⌫, ⌘⌦
        default: super.keyDown(with: event)
        }
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.modifierFlags.contains(.command) else { return super.performKeyEquivalent(with: event) }
        if event.isARepeat { return true }
        switch event.charactersIgnoringModifiers?.lowercased() {
        case "c": perform(.copy)
        case "w": perform(.close)
        case "o": perform(.openInDefaultApp)
        default:
            if event.keyCode == 51 || event.keyCode == 117 {
                perform(.moveToTrash)
            } else {
                return super.performKeyEquivalent(with: event)
            }
        }
        return true
    }

    override func cancelOperation(_ sender: Any?) { perform(.close) }
}

@MainActor
final class PreviewController: NSObject, NSWindowDelegate {
    /// Transparent room around the image for its shadow.
    nonisolated static let shadowInset: CGFloat = 40
    /// Space between the container's edge and the screenshot inside it.
    nonisolated static let imageInset: CGFloat = 14

    let state = PreviewState()
    private let store: ShelfStore
    private var operations: ScreenshotOperations { ScreenshotOperations(store: store) }
    private var panel: PreviewPanel?
    private var outsideClickMonitor: Any?
    private var hideTask: Task<Void, Never>?

    /// Called as the preview closes, with the screenshot it was showing and
    /// how it was dismissed.
    var onClose: ((ScreenshotRecord?, PreviewDismissal) -> Void)?

    var isOpen: Bool { state.isVisible }

    init(store: ShelfStore) {
        self.store = store
    }

    /// Opens `record`, or closes the preview if it is already showing it.
    func toggle(_ record: ScreenshotRecord) {
        if state.isVisible, state.record?.path == record.path {
            close(.backToShelf)
        } else {
            show(record)
        }
    }

    func show(_ record: ScreenshotRecord) {
        hideTask?.cancel()
        let panel = self.panel ?? makePanel()
        let wasVisible = state.isVisible

        // Switching screenshots swaps the image in place; the window stays put.
        state.record = record
        state.image = store.thumbnails[record.path]
        state.isCopied = false
        state.defaultAppName = NSWorkspace.shared.urlForApplication(toOpen: record.url)
            .map { FileManager.default.displayName(atPath: $0.path).replacingOccurrences(of: ".app", with: "") }
        state.backingScale = Self.screen?.backingScaleFactor ?? 2
        updatePosition()

        if !wasVisible {
            let content = PreviewGeometry.containerFrame(in: Self.screen?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900))
            panel.setFrame(content.insetBy(dx: -Self.shadowInset, dy: -Self.shadowInset), display: true)
        }
        panel.makeKeyAndOrderFront(nil)
        if !wasVisible {
            withAnimation(Motion.previewIn) { state.isVisible = true }
            watchForOutsideClicks()
        }
        let imageArea = panel.frame.insetBy(dx: Self.shadowInset + Self.imageInset, dy: Self.shadowInset + Self.imageInset).size
        let shown = PreviewGeometry.imageSize(
            forPixelSize: CGSize(width: record.pixelWidth, height: record.pixelHeight),
            backingScale: state.backingScale,
            fittingIn: imageArea
        )
        loadFullImage(record, pixelSize: max(shown.width, shown.height) * state.backingScale)
    }

    /// Closes the preview. A close from the keyboard is instant: it happens
    /// often, and an animation would only make the key feel slow.
    func close(_ dismissal: PreviewDismissal, animated: Bool = true) {
        guard state.isVisible else { return }
        stopWatchingForOutsideClicks()
        hideTask?.cancel()
        let closing = state.record
        guard animated else {
            state.isVisible = false
            finishClosing()
            onClose?(closing, dismissal)
            return
        }
        withAnimation(Motion.previewOut) { state.isVisible = false }
        onClose?(closing, dismissal)
        hideTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(Motion.previewOutDuration + 0.03))
            guard !Task.isCancelled, !self.state.isVisible else { return }
            self.finishClosing()
        }
    }

    private func finishClosing() {
        panel?.orderOut(nil)
        state.record = nil
        state.image = nil
        state.isPointerInside = false
    }

    /// Keys pressed while the preview has focus.
    private func performFromKeyboard(_ command: PreviewCommand) {
        switch command {
        case .close: close(.backToShelf, animated: false)
        case .copy: copyCurrent(animated: false)
        default: perform(command)
        }
    }

    private func copyCurrent(animated: Bool) {
        guard let record = state.record else { return }
        operations.copy(record)
        withAnimation(animated ? Motion.symbolSwap : nil) { state.isCopied = true }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.4))
            if self.state.record?.path == record.path {
                withAnimation(Motion.hover) { self.state.isCopied = false }
            }
        }
    }

    func perform(_ command: PreviewCommand) {
        guard let record = state.record else { return }
        switch command {
        case .close:
            close(.backToShelf)
        case .previous:
            step(-1)
        case .next:
            step(1)
        case .copy:
            copyCurrent(animated: true)
        case .revealInFinder:
            operations.revealInFinder(record)
            close(.elsewhere)
        case .openInDefaultApp:
            operations.openInDefaultApp(record)
            close(.elsewhere)
        case .moveToTrash:
            let index = store.items.firstIndex { $0.path == record.path } ?? 0
            operations.moveToTrash(record) { [weak self] trashed in
                guard let self, trashed else { return }
                if self.store.items.isEmpty {
                    self.close(.backToShelf)
                } else {
                    self.show(self.store.items[min(index, self.store.items.count - 1)])
                }
            }
        }
    }

    private func step(_ offset: Int) {
        guard let record = state.record,
              store.items.count > 1,
              let index = store.items.firstIndex(where: { $0.path == record.path }),
              let next = PreviewGeometry.wrappedIndex(index, offset: offset, count: store.items.count)
        else { return }
        show(store.items[next])
    }

    private func updatePosition() {
        guard let record = state.record,
              store.items.count > 1,
              let index = store.items.firstIndex(where: { $0.path == record.path })
        else {
            state.position = nil
            return
        }
        state.position = "\(index + 1) of \(store.items.count)"
    }

    private func makePanel() -> PreviewPanel {
        let panel = PreviewPanel()
        panel.delegate = self
        panel.perform = { [weak self] command in self?.performFromKeyboard(command) }
        panel.contentView = FirstClickHostingView(rootView: PreviewView(state: state) { [weak self] command in
            self?.perform(command)
        })
        self.panel = panel
        return panel
    }

    /// The preview opens on the primary display, where the shelf is.
    private static var screen: NSScreen? { NSScreen.screens.first }

    private func loadFullImage(_ record: ScreenshotRecord, pixelSize: CGFloat) {
        let url = record.url
        let maxPixelSize = Int(pixelSize.rounded(.up))
        Task.detached(priority: .userInitiated) {
            guard let image = ScreenshotFiles.thumbnail(for: url, maxPixelSize: maxPixelSize) else { return }
            let size = NSSize(width: image.width, height: image.height)
            await MainActor.run {
                guard self.state.record?.path == url.path else { return }
                self.state.image = NSImage(cgImage: image, size: size)
            }
        }
    }

    // MARK: Closing on outside clicks

    /// A click in any other app closes the preview. Clicks on the shelf are
    /// Sky's own and never reach this monitor.
    private func watchForOutsideClicks() {
        guard outsideClickMonitor == nil else { return }
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.close(.elsewhere) }
        }
    }

    private func stopWatchingForOutsideClicks() {
        if let monitor = outsideClickMonitor {
            NSEvent.removeMonitor(monitor)
            outsideClickMonitor = nil
        }
    }

    func windowDidResignKey(_ notification: Notification) {
        // When the preview hands focus back to the shelf, it has already
        // closed, so this only acts on focus moving to another app.
        close(.elsewhere)
    }
}
