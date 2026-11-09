import AppKit
import Observation
import SkyCore
import SwiftUI

/// What the shelf is doing right now. The controller writes it; `ShelfView` draws it.
@MainActor
@Observable
final class ShelfState {
    var isPresented = false
    var isExpanded = false
    /// The card the pointer is on, or the one chosen with the arrow keys.
    var selectedPath: String?
    var copiedPath: String?
    /// Opened with the keyboard shortcut: the shelf keeps keyboard focus,
    /// shows its keys, and stays open until dismissed.
    var isKeyboardDriven = false
    var containerWidth: CGFloat = 0
}

/// Shows and hides the shelf, and follows the pointer and the keyboard.
///
/// The shelf is driven one of two ways. From the pointer (after a capture,
/// from the top edge, or from the menu) it expands on hover, takes keyboard
/// focus only while the pointer is over it, and hides itself a moment after
/// the pointer leaves. From the keyboard shortcut it opens expanded with the
/// newest screenshot selected, keeps keyboard focus, and stays open until
/// Esc, Return, the shortcut again, or a click in another app.
@MainActor
final class ShelfController: NSObject, NSWindowDelegate {
    nonisolated static let panelHeight: CGFloat = 190
    /// How long the shelf stays up after a capture, or after the pointer leaves it.
    nonisolated static let lingerAfterCapture: TimeInterval = 6
    nonisolated static let lingerAfterHover: TimeInterval = 2.5
    nonisolated static let lingerAfterEdgeReveal: TimeInterval = 1.5
    nonisolated static let collapseDelay: TimeInterval = 0.18

    let state = ShelfState()
    private let store: ShelfStore
    private let preview: PreviewController
    private let actions: ShelfActions
    private let panel = ShelfPanel()
    private var pointerTimer: Timer?
    private var hideDeadline: Date?
    private var collapseDeadline: Date?
    /// When the deck last started fanning out.
    private var expandedAt: Date?
    /// Where the pointer was on the previous tick, so a pointer resting on a
    /// card doesn't keep taking the selection back from the arrow keys.
    private var lastPointer: CGPoint?
    /// Where the pointer was when the shelf appeared. While it hasn't moved,
    /// the shelf doesn't take keyboard focus, so a shelf that appears under a
    /// resting pointer doesn't catch whatever is being typed.
    private var pointerWhenShown: CGPoint?
    /// Counts hides, so a slide-out that finishes late doesn't act on a newer one.
    private var hideGeneration = 0
    private var edgeReveal = EdgeReveal()
    private var edgeTimer: Timer?

    /// Whether resting the pointer at the top edge brings the shelf down.
    var revealsAtTopEdge: Bool {
        get { !UserDefaults.standard.bool(forKey: "topEdgeRevealDisabled") }
        set {
            UserDefaults.standard.set(!newValue, forKey: "topEdgeRevealDisabled")
            newValue ? startWatchingTopEdge() : stopWatchingTopEdge()
        }
    }

    var keepsVisible: Bool {
        get { UserDefaults.standard.bool(forKey: "keepsShelfVisible") }
        set {
            UserDefaults.standard.set(newValue, forKey: "keepsShelfVisible")
            if newValue {
                hideDeadline = nil
            } else if state.isPresented, !state.isKeyboardDriven {
                hideDeadline = Date() + Self.lingerAfterHover
            }
        }
    }

    var isPresented: Bool { state.isPresented }

    init(store: ShelfStore, preview: PreviewController) {
        self.store = store
        self.preview = preview
        actions = ShelfActions(store: store, state: state, preview: preview)
        super.init()
        panel.delegate = self
        panel.contentView = FirstClickHostingView(rootView: ShelfView(store: store, state: state, actions: actions))
        panel.perform = { [weak self] command in
            MainActor.assumeIsolated { self?.perform(command) }
        }
        panel.accepts = { [weak self] command in
            MainActor.assumeIsolated { self?.state.isKeyboardDriven == true || command == .copy }
        }
        preview.onClose = { [weak self] record, dismissal in
            MainActor.assumeIsolated { self?.previewClosed(showing: record, dismissal) }
        }
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.placePanel() }
        }
    }

    // MARK: Showing and hiding

    /// Shows the shelf for the pointer: after a capture, from the top edge or from the menu.
    func show(lingering linger: TimeInterval = ShelfController.lingerAfterCapture) {
        placePanel()
        panel.orderFrontRegardless()
        if state.isKeyboardDriven {
            // A capture while the keyboard drives the shelf: stay expanded,
            // and keep the selection on a card that is still shown.
            withoutAnimation {
                state.isExpanded = !store.items.isEmpty
                if !isVisible(state.selectedPath) { state.selectedPath = store.items.first?.path }
            }
        } else {
            hideDeadline = keepsVisible ? nil : Date() + linger
        }
        if !state.isPresented {
            pointerWhenShown = NSEvent.mouseLocation
            withAnimation(Motion.present) { state.isPresented = true }
        }
        startTrackingPointer()
    }

    /// The keyboard shortcut: opens the shelf for the keyboard, or closes it
    /// if it is already open that way.
    func toggleFromKeyboard() {
        if state.isPresented, state.isKeyboardDriven {
            endKeyboardMode(animated: false)
        } else {
            openForKeyboard()
        }
    }

    /// Opens expanded with a card selected and keyboard focus taken. It
    /// appears at once, without sliding or fanning out: it was asked for from
    /// the keyboard, and keyboard actions shouldn't wait on animation.
    private func openForKeyboard() {
        placePanel()
        hideDeadline = nil
        collapseDeadline = nil
        expandedAt = .distantPast
        lastPointer = NSEvent.mouseLocation
        withoutAnimation {
            state.isKeyboardDriven = true
            state.isPresented = true
            state.isExpanded = !store.items.isEmpty
            if !isVisible(state.selectedPath) {
                state.selectedPath = store.items.first?.path
            }
        }
        panel.orderFrontRegardless()
        panel.makeKey()
        startTrackingPointer()
    }

    func hide(animated: Bool = true) {
        hideDeadline = nil
        collapseDeadline = nil
        panel.ignoresMouseEvents = true
        hideGeneration += 1
        guard animated else {
            withoutAnimation { resetToHidden() }
            panel.orderOut(nil)
            stopTrackingPointer()
            return
        }
        withAnimation(Motion.dismiss) { resetToHidden() }
        let generation = hideGeneration
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(Motion.dismissDuration + 0.05))
            guard generation == self.hideGeneration, !self.state.isPresented else { return }
            self.panel.orderOut(nil)
            self.stopTrackingPointer()
        }
    }

    /// Leaves keyboard mode: Esc, Return, the shortcut, or a click elsewhere.
    /// With Keep Shelf Visible on, the shelf stays and goes back to following
    /// the pointer; otherwise it hides.
    private func endKeyboardMode(animated: Bool) {
        guard keepsVisible else { return hide(animated: animated) }
        state.isKeyboardDriven = false
        hideDeadline = nil
        pointerWhenShown = NSEvent.mouseLocation
        returnKeyboardFocus()
    }

    private func resetToHidden() {
        state.isPresented = false
        state.isExpanded = false
        state.selectedPath = nil
        state.isKeyboardDriven = false
    }

    func toggle() {
        state.isPresented ? hide() : show()
    }

    /// Copies a screenshot and shows that it was copied.
    func copy(_ record: ScreenshotRecord) {
        actions.copy(record)
    }

    private func placePanel() {
        guard let screen = NSScreen.screens.first else { return }
        let frame = NSRect(
            x: screen.frame.minX,
            y: screen.visibleFrame.maxY - Self.panelHeight,
            width: screen.frame.width,
            height: Self.panelHeight
        )
        panel.setFrame(frame, display: true)
        state.containerWidth = frame.width
    }

    // MARK: Keyboard

    private var layout: ShelfLayout {
        ShelfLayout.make(
            aspectRatios: store.items.map(\.aspectRatio),
            containerWidth: state.containerWidth,
            expanded: state.isExpanded
        )
    }

    /// The cards shown on the shelf, newest first. Cards that don't fit in the
    /// row can't be selected.
    private var visibleItems: ArraySlice<ScreenshotRecord> {
        store.items.prefix(layout.visibleCount)
    }

    private func isVisible(_ path: String?) -> Bool {
        visibleItems.contains { $0.path == path }
    }

    private func perform(_ command: ShelfCommand) {
        let visible = Array(visibleItems)
        let index = visible.firstIndex { $0.path == state.selectedPath }
        let selected = index.map { visible[$0] }

        switch command {
        case .previous, .next:
            guard let next = ShelfSelection.moved(from: index, by: command == .next ? 1 : -1, visibleCount: visible.count) else {
                NSSound.beep()
                return
            }
            withoutAnimation { state.selectedPath = visible[next].path }
        case .preview:
            guard let selected else { return NSSound.beep() }
            preview.show(selected)
        case .copy:
            guard let selected else { return NSSound.beep() }
            actions.copy(selected, animated: false)
        case .copyAndClose:
            guard let selected else { return NSSound.beep() }
            ScreenshotOperations(store: store).copy(selected)
            endKeyboardMode(animated: false)
        case .moveToTrash:
            guard let selected, let index else { return NSSound.beep() }
            ScreenshotOperations(store: store).moveToTrash(selected) { [weak self] trashed in
                // Ignore the result if the shelf closed or the selection moved on meanwhile.
                guard let self, trashed, self.state.isPresented, self.state.selectedPath == selected.path else { return }
                // Select the card that took its place, or the new last one.
                let remaining = Array(self.visibleItems)
                self.state.selectedPath = remaining.isEmpty ? nil : remaining[min(index, remaining.count - 1)].path
            }
        case .close:
            endKeyboardMode(animated: false)
        }
    }

    /// The preview closed. If the keyboard drives the shelf and the preview
    /// was dismissed back to it, focus returns to the shelf with the
    /// screenshot the preview ended on selected. If it was dismissed to
    /// another app, the shelf leaves keyboard mode too, as it would for a
    /// click in that app.
    private func previewClosed(showing record: ScreenshotRecord?, _ dismissal: PreviewDismissal) {
        guard state.isPresented, state.isKeyboardDriven else { return }
        switch dismissal {
        case .backToShelf:
            if let record, isVisible(record.path) {
                state.selectedPath = record.path
            }
            panel.makeKey()
        case .elsewhere:
            endKeyboardMode(animated: true)
        }
    }

    func windowDidResignKey(_ notification: Notification) {
        guard state.isKeyboardDriven else { return }
        // Focus moves to the preview when it opens, and comes back when it closes.
        // Anywhere else means another app was clicked, which dismisses the shelf.
        Task { @MainActor in
            guard self.state.isKeyboardDriven, !self.panel.isKeyWindow, !self.preview.isOpen else { return }
            self.endKeyboardMode(animated: true)
        }
    }

    // MARK: Keyboard focus while hovered

    // While the pointer drives the shelf, it takes keyboard focus while the
    // pointer is over it, so C and ⌘C reach it, and gives it back as soon as
    // the pointer leaves. Only copying is accepted then; the other keys are
    // for keyboard mode, so typing aimed at another app can't trash or close. The panel never activates Sky, so the app you were
    // in stays frontmost throughout.

    private func takeKeyboardFocus() {
        // Leave focus alone while another Sky window, such as the preview, has it.
        guard !panel.isKeyWindow, NSApp.keyWindow == nil else { return }
        panel.makeKey()
    }

    private func returnKeyboardFocus() {
        guard panel.isKeyWindow else { return }
        // Taking the panel off screen hands focus back to the frontmost app's
        // window; putting it straight back happens before the next frame is drawn.
        panel.orderOut(nil)
        panel.orderFrontRegardless()
    }

    // MARK: Pointer tracking

    // The panel ignores the mouse except while the pointer is over the shelf,
    // so the pointer is followed by polling rather than by tracking areas,
    // which an ignoring window never receives events for.

    private func startTrackingPointer() {
        guard pointerTimer == nil else { return }
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.followPointer() }
        }
        RunLoop.main.add(timer, forMode: .common)
        pointerTimer = timer
    }

    private func stopTrackingPointer() {
        pointerTimer?.invalidate()
        pointerTimer = nil
    }

    private func followPointer() {
        guard state.isPresented else { return }
        let now = Date()
        let mouse = NSEvent.mouseLocation
        let frame = panel.frame
        let point = CGPoint(x: mouse.x - frame.minX, y: frame.maxY - mouse.y)
        let buttonHeld = NSEvent.pressedMouseButtons != 0
        let layout = self.layout
        panel.ignoresMouseEvents = !layout.activeRect.contains(point)

        if state.isKeyboardDriven {
            // The pointer only takes the selection when it moves onto a card.
            if mouse != lastPointer, let index = layout.cardIndex(at: point), store.items[index].path != state.selectedPath {
                withAnimation(Motion.hover) { state.selectedPath = store.items[index].path }
            }
            lastPointer = mouse
            return
        }

        // The strip between the shelf and the top of the screen counts as on
        // the shelf, so moving up to the top edge doesn't collapse it.
        let distanceToScreenTop = (NSScreen.screens.first?.frame.maxY ?? frame.maxY) - frame.maxY
        let isOver = layout.hoverRect(extendingUpBy: distanceToScreenTop).contains(point)

        // Resting at the top edge holds the shelf open, as it does the Dock.
        if !keepsVisible, let screen = NSScreen.screens.first,
           edgeReveal.band(on: screen.frame).insetBy(dx: 0, dy: -1).contains(mouse) {
            hideDeadline = now + Self.lingerAfterEdgeReveal
        }

        if isOver {
            if mouse != pointerWhenShown {
                pointerWhenShown = nil
                takeKeyboardFocus()
            }
            collapseDeadline = nil
            if !keepsVisible { hideDeadline = now + Self.lingerAfterHover }
            if !state.isExpanded, !store.items.isEmpty {
                withAnimation(Motion.expand) { state.isExpanded = true }
                expandedAt = now
            }
            // A card only counts as hovered once the fan-out has settled, so its
            // controls never fade in while the cards are still moving.
            let settled = expandedAt.map { now.timeIntervalSince($0) >= Motion.fanOutSettleTime } ?? true
            let hovered = settled ? layout.cardIndex(at: point).map { store.items[$0].path } : nil
            if hovered != state.selectedPath {
                withAnimation(Motion.hover) { state.selectedPath = hovered }
            }
            return
        }

        if state.selectedPath != nil {
            withAnimation(Motion.hover) { state.selectedPath = nil }
        }
        // Holding the button means a drag may be under way; keep the shelf
        // still, and keep it on screen so the drag isn't cancelled.
        guard !buttonHeld else { return }
        returnKeyboardFocus()

        if state.isExpanded {
            if let deadline = collapseDeadline {
                if now >= deadline {
                    collapseDeadline = nil
                    withAnimation(Motion.collapse) { state.isExpanded = false }
                }
            } else {
                collapseDeadline = now + Self.collapseDelay
            }
        }
        if let hideDeadline, now >= hideDeadline {
            hide()
        }
    }

    // MARK: Top edge

    // macOS does not deliver pointer movement over other apps' windows to an
    // app without the Input Monitoring permission, so the pointer position is
    // sampled instead: 12 times a second, with enough tolerance for macOS to
    // fold the wake-ups in with other work.

    func startWatchingTopEdge() {
        guard edgeTimer == nil, revealsAtTopEdge else { return }
        let timer = Timer(timeInterval: 1.0 / 12.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkTopEdge() }
        }
        timer.tolerance = 0.04
        RunLoop.main.add(timer, forMode: .common)
        edgeTimer = timer
    }

    func stopWatchingTopEdge() {
        edgeTimer?.invalidate()
        edgeTimer = nil
    }

    private func checkTopEdge() {
        guard let screen = NSScreen.screens.first else { return }
        let decision = edgeReveal.update(
            pointer: NSEvent.mouseLocation,
            screen: screen.frame,
            buttonHeld: NSEvent.pressedMouseButtons != 0,
            now: Date()
        )
        if decision == .reveal, !state.isPresented {
            show(lingering: Self.lingerAfterEdgeReveal)
        }
    }
}

/// Applies state changes with every animation suppressed, including the
/// implicit ones views attach with `.animation(_:value:)`.
@MainActor
func withoutAnimation(_ changes: () -> Void) {
    var transaction = Transaction()
    transaction.disablesAnimations = true
    withTransaction(transaction, changes)
}
