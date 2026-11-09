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
}

enum PreviewCommand {
    case close, previous, next, copy, revealInFinder, openInDefaultApp, moveToTrash
}

/// A borderless window that can take keyboard focus without activating Sky,
/// so the app you were in stays frontmost while you look at a screenshot.
final class PreviewPanel: NSPanel {
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
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func keyDown(with event: NSEvent) {
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
    nonisolated static let screenMargin: CGFloat = 72
    nonisolated static let minimumSize = CGSize(width: 340, height: 200)

    let state = PreviewState()
    private let store: ShelfStore
    private var operations: ScreenshotOperations { ScreenshotOperations(store: store) }
    private var panel: PreviewPanel?
    private var outsideClickMonitor: Any?
    private var hideTask: Task<Void, Never>?

    init(store: ShelfStore) {
        self.store = store
    }

    /// Opens `record`, or closes the preview if it is already showing it.
    func toggle(_ record: ScreenshotRecord) {
        if state.isVisible, state.record?.path == record.path {
            close()
        } else {
            show(record)
        }
    }

    func show(_ record: ScreenshotRecord) {
        hideTask?.cancel()
        let panel = self.panel ?? makePanel()
        let wasVisible = state.isVisible

        state.record = record
        state.image = store.thumbnails[record.path]
        state.isCopied = false
        state.defaultAppName = NSWorkspace.shared.urlForApplication(toOpen: record.url)
            .map { FileManager.default.displayName(atPath: $0.path).replacingOccurrences(of: ".app", with: "") }
        updatePosition()

        let content = Self.contentFrame(for: record)
        let frame = content.insetBy(dx: -Self.shadowInset, dy: -Self.shadowInset)
        if wasVisible {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.22
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().setFrame(frame, display: true)
            }
        } else {
            panel.setFrame(frame, display: true)
        }
        panel.makeKeyAndOrderFront(nil)
        if !wasVisible {
            withAnimation(Motion.previewIn) { state.isVisible = true }
            watchForOutsideClicks()
        }
        loadFullImage(record, pixelSize: max(content.width, content.height) * Self.backingScale)
    }

    func close() {
        guard state.isVisible else { return }
        stopWatchingForOutsideClicks()
        withAnimation(Motion.previewOut) { state.isVisible = false }
        hideTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.2))
            guard !Task.isCancelled, !self.state.isVisible else { return }
            self.panel?.orderOut(nil)
            self.state.record = nil
            self.state.image = nil
            self.state.isPointerInside = false
        }
    }

    func perform(_ command: PreviewCommand) {
        guard let record = state.record else { return }
        switch command {
        case .close:
            close()
        case .previous:
            step(-1)
        case .next:
            step(1)
        case .copy:
            operations.copy(record)
            withAnimation(Motion.hover) { state.isCopied = true }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.4))
                if self.state.record?.path == record.path {
                    withAnimation(Motion.hover) { self.state.isCopied = false }
                }
            }
        case .revealInFinder:
            operations.revealInFinder(record)
            close()
        case .openInDefaultApp:
            operations.openInDefaultApp(record)
            close()
        case .moveToTrash:
            let index = store.items.firstIndex { $0.path == record.path } ?? 0
            operations.moveToTrash(record) { [weak self] trashed in
                guard let self, trashed else { return }
                if self.store.items.isEmpty {
                    self.close()
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
        panel.perform = { [weak self] command in self?.perform(command) }
        panel.contentView = FirstClickHostingView(rootView: PreviewView(state: state) { [weak self] command in
            self?.perform(command)
        })
        self.panel = panel
        return panel
    }

    private static var screen: NSScreen? { NSScreen.screens.first }
    private static var backingScale: CGFloat { screen?.backingScaleFactor ?? 2 }

    /// Where the image sits on screen, centred on the primary display.
    static func contentFrame(for record: ScreenshotRecord) -> CGRect {
        PreviewGeometry.frame(
            forPixelSize: CGSize(width: record.pixelWidth, height: record.pixelHeight),
            backingScale: backingScale,
            in: screen?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900),
            margin: screenMargin,
            minimumSize: minimumSize
        )
    }

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
            MainActor.assumeIsolated { self?.close() }
        }
    }

    private func stopWatchingForOutsideClicks() {
        if let monitor = outsideClickMonitor {
            NSEvent.removeMonitor(monitor)
            outsideClickMonitor = nil
        }
    }

    func windowDidResignKey(_ notification: Notification) {
        close()
    }
}
