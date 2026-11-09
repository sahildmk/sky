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
    var hoveredPath: String?
    var copiedPath: String?
    var containerWidth: CGFloat = 0
}

/// A transparent strip across the top of the primary display that holds the
/// shelf. It lets clicks through everywhere except over the shelf itself, and
/// takes keyboard focus only while the pointer is over the shelf, without
/// bringing Sky to the front.
final class ShelfPanel: NSPanel {
    /// Called when C or ⌘C is pressed.
    var onCopy: () -> Void = {}

    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .statusBar
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        hidesOnDeactivate = false
        isMovable = false
        isReleasedWhenClosed = false
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func keyDown(with event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if event.charactersIgnoringModifiers?.lowercased() == "c", modifiers.subtracting(.capsLock).isEmpty {
            onCopy()
        } else {
            super.keyDown(with: event)
        }
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting(.capsLock)
        if modifiers == .command, event.charactersIgnoringModifiers?.lowercased() == "c" {
            onCopy()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}

/// Lets the first click on the shelf act immediately instead of only focusing it.
final class FirstClickHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

@MainActor
final class ShelfController {
    nonisolated static let panelHeight: CGFloat = 190
    /// How long the shelf stays up after a capture, or after the pointer leaves it.
    nonisolated static let lingerAfterCapture: TimeInterval = 6
    nonisolated static let lingerAfterHover: TimeInterval = 2.5
    nonisolated static let lingerAfterEdgeReveal: TimeInterval = 1.5
    nonisolated static let collapseDelay: TimeInterval = 0.18

    let state = ShelfState()
    private let store: ShelfStore
    private let actions: ShelfActions
    private let panel = ShelfPanel()
    private var pointerTimer: Timer?
    private var hideDeadline: Date?
    private var collapseDeadline: Date?
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
            if newValue { hideDeadline = nil } else if state.isPresented { hideDeadline = Date() + Self.lingerAfterHover }
        }
    }

    var isPresented: Bool { state.isPresented }

    init(store: ShelfStore, preview: PreviewController) {
        self.store = store
        actions = ShelfActions(store: store, state: state, preview: preview)
        panel.contentView = FirstClickHostingView(rootView: ShelfView(store: store, state: state, actions: actions))
        panel.onCopy = { [weak self] in
            MainActor.assumeIsolated { self?.copyHoveredScreenshot() }
        }
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.placePanel() }
        }
    }

    func show(lingering linger: TimeInterval = ShelfController.lingerAfterCapture) {
        placePanel()
        panel.orderFrontRegardless()
        hideDeadline = keepsVisible ? nil : Date() + linger
        if !state.isPresented {
            withAnimation(Motion.present) { state.isPresented = true }
        }
        startTrackingPointer()
    }

    func hide() {
        hideDeadline = nil
        collapseDeadline = nil
        panel.ignoresMouseEvents = true
        withAnimation(Motion.dismiss) {
            state.isPresented = false
            state.isExpanded = false
            state.hoveredPath = nil
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(Motion.dismissDuration + 0.05))
            guard !self.state.isPresented else { return }
            self.panel.orderOut(nil)
            self.stopTrackingPointer()
        }
    }

    func toggle() {
        state.isPresented ? hide() : show()
    }

    /// Copies a screenshot and shows that it was copied.
    func copy(_ record: ScreenshotRecord) {
        actions.copy(record)
    }

    private func copyHoveredScreenshot() {
        guard let path = state.hoveredPath, let record = store.items.first(where: { $0.path == path }) else {
            NSSound.beep()
            return
        }
        actions.copy(record)
    }

    // MARK: Keyboard focus

    // The shelf takes keyboard focus while the pointer is over it, so C and
    // ⌘C reach it, and gives it back as soon as the pointer leaves. The panel
    // never activates Sky, so the app you were in stays frontmost throughout.

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

        let layout = ShelfLayout.make(
            aspectRatios: store.items.map(\.aspectRatio),
            containerWidth: state.containerWidth,
            expanded: state.isExpanded
        )
        let isOver = layout.activeRect.contains(point)
        panel.ignoresMouseEvents = !isOver

        // Resting at the top edge holds the shelf open, as it does the Dock.
        if !keepsVisible, let screen = NSScreen.screens.first,
           edgeReveal.band(on: screen.frame).insetBy(dx: 0, dy: -1).contains(mouse) {
            hideDeadline = now + Self.lingerAfterEdgeReveal
        }

        if isOver {
            takeKeyboardFocus()
            collapseDeadline = nil
            if !keepsVisible { hideDeadline = now + Self.lingerAfterHover }
            if !state.isExpanded, !store.items.isEmpty {
                withAnimation(Motion.expand) { state.isExpanded = true }
            }
            let hovered = layout.cardIndex(at: point).map { store.items[$0].path }
            if hovered != state.hoveredPath {
                withAnimation(Motion.hover) { state.hoveredPath = hovered }
            }
            return
        }

        if state.hoveredPath != nil {
            withAnimation(Motion.hover) { state.hoveredPath = nil }
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
