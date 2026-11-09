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
/// shelf. It never takes focus, and lets clicks through everywhere except
/// over the shelf itself.
final class ShelfPanel: NSPanel {
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

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
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
    nonisolated static let collapseDelay: TimeInterval = 0.18

    let state = ShelfState()
    private let store: ShelfStore
    private let panel = ShelfPanel()
    private var pointerTimer: Timer?
    private var hideDeadline: Date?
    private var collapseDeadline: Date?

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
        let actions = ShelfActions(store: store, state: state, preview: preview)
        panel.contentView = FirstClickHostingView(rootView: ShelfView(store: store, state: state, actions: actions))
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

        if isOver {
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
        // Holding the button means a drag may be under way; keep the shelf still.
        guard !buttonHeld else { return }

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
}
