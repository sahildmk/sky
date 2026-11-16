import AppKit
import Observation
import SkyCore
import SwiftUI

/// What the thread panel is showing. The controller writes it; `ThreadView` draws it.
@MainActor
@Observable
final class ThreadPanelState {
    var thread: SkyThread?
    /// Nil until they have loaded.
    var messages: [SkyThread.Message]?
    var loadError: String?
    var isVisible = false
    /// A resolve or reopen is in flight.
    var isUpdating = false
    /// The tallest the panel's content may grow before it scrolls.
    var maxHeight: CGFloat = 560
    var scrollPosition = ScrollPosition(edge: .top)
    var scrollOffset: CGFloat = 0
    var maxScrollOffset: CGFloat = 0
}

enum ThreadPanelCommand {
    case close, scrollUp, scrollDown, toggleResolved
}

/// A borderless window that can take keyboard focus without activating Sky.
final class ThreadPanel: NSPanel {
    var perform: (ThreadPanelCommand) -> Void = { _ in }

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
        // The panel animates itself; the system fade would double it up.
        animationBehavior = .none
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// Esc or Space: close · ↑ ↓: scroll · ⌘Return: resolve or reopen.
    override func keyDown(with event: NSEvent) {
        // Only scrolling repeats while a key is held.
        if event.isARepeat, event.keyCode != 125, event.keyCode != 126 { return }
        switch event.keyCode {
        case 53, 49: perform(.close)                                    // Escape, Space
        case 126: perform(.scrollUp)                                    // ↑
        case 125: perform(.scrollDown)                                  // ↓
        default: super.keyDown(with: event)
        }
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.modifierFlags.contains(.command) else { return super.performKeyEquivalent(with: event) }
        if event.charactersIgnoringModifiers?.lowercased() == "w" {
            perform(.close)
            return true
        }
        if event.keyCode == 36 {   // ⌘Return
            if !event.isARepeat { perform(.toggleResolved) }
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func cancelOperation(_ sender: Any?) { perform(.close) }
}

/// Shows one thread in a panel that drops down beneath its card on the shelf.
@MainActor
final class ThreadPanelController: NSObject, NSWindowDelegate {
    nonisolated static let width: CGFloat = 460
    /// Transparent room around the content for its shadow.
    nonisolated static let shadowInset: CGFloat = 30
    /// Space between the card and the top of the panel.
    nonisolated static let gapBelowCard: CGFloat = 8
    /// How far ↑ and ↓ scroll.
    nonisolated static let scrollStep: CGFloat = 80

    let state = ThreadPanelState()
    private let threads: ThreadsStore
    private var panel: ThreadPanel?
    private var outsideClickMonitor: Any?
    private var hideTask: Task<Void, Never>?
    private var loadTask: Task<Void, Never>?
    /// Where the panel's content starts, in screen coordinates: its top edge and horizontal position.
    private var contentTop: CGFloat = 0
    private var contentMinX: CGFloat = 0
    /// The height the content last asked for. The view only reports a
    /// change, so reopening content of the same height reuses this.
    private var contentHeight: CGFloat?

    /// Called as the panel closes, with the id of the thread it was showing
    /// and how it was dismissed.
    var onClose: ((String?, PanelDismissal) -> Void)?

    var isOpen: Bool { state.isVisible }

    init(threads: ThreadsStore) {
        self.threads = threads
    }

    /// Opens `thread` below `card`, or closes the panel if it is already showing it.
    ///
    /// - Parameter card: The card's frame in screen coordinates.
    func toggle(_ thread: SkyThread, below card: CGRect) {
        if state.isVisible, state.thread?.id == thread.id {
            close(.backToShelf)
        } else {
            show(thread, below: card)
        }
    }

    func show(_ thread: SkyThread, below card: CGRect) {
        hideTask?.cancel()
        let panel = self.panel ?? makePanel()
        let wasVisible = state.isVisible

        if state.thread?.id != thread.id {
            state.messages = nil
            state.loadError = nil
            state.scrollPosition = ScrollPosition(edge: .top)
        }
        state.thread = thread
        place(below: card)
        panel.makeKeyAndOrderFront(nil)
        if !wasVisible {
            withAnimation(Motion.previewIn) { state.isVisible = true }
            watchForOutsideClicks()
        }
        load(thread.id)
    }

    /// Closes the panel. A close from the keyboard is instant.
    func close(_ dismissal: PanelDismissal, animated: Bool = true) {
        guard state.isVisible else { return }
        stopWatchingForOutsideClicks()
        hideTask?.cancel()
        loadTask?.cancel()
        let closing = state.thread?.id
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
        state.thread = nil
        state.messages = nil
        state.loadError = nil
    }

    func perform(_ command: ThreadPanelCommand, fromKeyboard: Bool = false) {
        switch command {
        case .close:
            close(.backToShelf, animated: !fromKeyboard)
        case .scrollUp:
            scroll(by: -Self.scrollStep)
        case .scrollDown:
            scroll(by: Self.scrollStep)
        case .toggleResolved:
            toggleResolved()
        }
    }

    private func scroll(by distance: CGFloat) {
        let target = min(max(state.scrollOffset + distance, 0), max(state.maxScrollOffset, 0))
        withAnimation(Motion.hover) { state.scrollPosition.scrollTo(y: target) }
    }

    private func toggleResolved() {
        guard let thread = state.thread, !state.isUpdating else { return }
        state.isUpdating = true
        Task { @MainActor in
            defer { self.state.isUpdating = false }
            do {
                let updated = try await threads.setResolved(!thread.isResolved, threadID: thread.id)
                if self.state.thread?.id == updated.id {
                    withAnimation(Motion.symbolSwap) { self.state.thread = updated }
                }
            } catch {
                NSSound.beep()
            }
        }
    }

    private func load(_ id: String) {
        loadTask?.cancel()
        loadTask = Task { @MainActor in
            do throws(SkyServiceError) {
                let detail = try await threads.detail(for: id)
                guard !Task.isCancelled, self.state.thread?.id == id else { return }
                self.state.thread = detail.thread
                self.state.messages = detail.messages
                self.state.loadError = nil
            } catch {
                guard !Task.isCancelled, self.state.thread?.id == id, self.state.messages == nil else { return }
                self.state.loadError = switch error {
                case .unreachable: "The Sky service isn't running, so this thread's messages can't be loaded."
                case .rejected(_, let message): message
                }
            }
        }
    }

    // MARK: Size and position

    /// Puts the panel's top edge just below `card`, centred under it but kept on screen.
    private func place(below card: CGRect) {
        let visible = (NSScreen.screens.first?.visibleFrame) ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let margin: CGFloat = 12
        contentTop = card.minY - Self.gapBelowCard
        contentMinX = min(max(card.midX - Self.width / 2, visible.minX + margin), visible.maxX - Self.width - margin)
        state.maxHeight = max(contentTop - visible.minY - margin, 200)
        setContentHeight(contentHeight ?? state.maxHeight)
    }

    /// Fits the panel to its content, keeping its top edge where it is.
    func setContentHeight(_ height: CGFloat) {
        contentHeight = height
        let height = min(height, state.maxHeight)
        let content = CGRect(x: contentMinX, y: contentTop - height, width: Self.width, height: height)
        panel?.setFrame(content.insetBy(dx: -Self.shadowInset, dy: -Self.shadowInset), display: true)
    }

    private func makePanel() -> ThreadPanel {
        let panel = ThreadPanel()
        panel.delegate = self
        panel.perform = { [weak self] command in self?.perform(command, fromKeyboard: true) }
        panel.contentView = FirstClickHostingView(rootView: ThreadView(
            state: state,
            perform: { [weak self] command in self?.perform(command) },
            onHeightChange: { [weak self] height in self?.setContentHeight(height) }
        ))
        self.panel = panel
        return panel
    }

    // MARK: Closing on outside clicks

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
        // Focus moving to another app, including a link opening in the browser.
        close(.elsewhere)
    }
}
