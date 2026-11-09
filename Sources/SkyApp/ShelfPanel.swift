import AppKit
import SwiftUI

/// What a key pressed while the shelf has keyboard focus asks for.
enum ShelfCommand: Equatable {
    case previous, next, preview, copy, copyAndClose, moveToTrash, close
}

/// A transparent strip across the top of the primary display that holds the
/// shelf. It lets clicks through everywhere except over the shelf itself, and
/// can take keyboard focus without bringing Sky to the front.
final class ShelfPanel: NSPanel {
    var perform: (ShelfCommand) -> Void = { _ in }
    /// Which commands the shelf takes right now. Hovered, it only copies;
    /// opened from the keyboard, it takes them all.
    var accepts: (ShelfCommand) -> Bool = { _ in true }

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
        // Sky animates the shelf itself. The system fade would play on top of
        // that, and handing keyboard focus back (ordering the panel out and
        // straight in) interrupts it, leaving the shelf washed out.
        animationBehavior = .none
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// The command a key press maps to, if any.
    ///
    /// ← →: select · Space: preview · Return: copy and close · C or ⌘C: copy ·
    /// ⌘⌫: move to the Trash · Esc: close.
    static func command(for event: NSEvent) -> ShelfCommand? {
        // Arrow keys carry the numeric-pad and function flags; neither matters here.
        let modifiers = event.modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .subtracting([.capsLock, .numericPad, .function])

        switch (event.keyCode, modifiers) {
        case (123, []): return .previous           // ←
        case (124, []): return .next               // →
        case (49, []): return .preview             // Space
        case (36, []), (76, []): return .copyAndClose   // Return, keypad Enter
        case (53, []): return .close               // Esc
        case (51, .command), (117, .command): return .moveToTrash   // ⌘⌫, ⌘⌦
        default: break
        }
        // Matched by character rather than key code, so C works on any keyboard layout.
        if event.charactersIgnoringModifiers?.lowercased() == "c", modifiers == [] || modifiers == .command {
            return .copy
        }
        return nil
    }

    /// The command to carry out for a key press. A held key repeats only for
    /// moving the selection: repeating anything else would, for example,
    /// trash one screenshot after another.
    private func acceptedCommand(for event: NSEvent) -> ShelfCommand? {
        guard let command = Self.command(for: event), accepts(command) else { return nil }
        if event.isARepeat, command != .previous, command != .next { return nil }
        return command
    }

    override func keyDown(with event: NSEvent) {
        if let command = acceptedCommand(for: event) {
            perform(command)
        } else if event.isARepeat, Self.command(for: event) != nil {
            // A held key the shelf does handle, just not repeatedly: ignore it quietly.
        } else {
            super.keyDown(with: event)
        }
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // Plain keys arrive through keyDown; only ⌘ combinations are handled here.
        guard event.modifierFlags.contains(.command), Self.command(for: event) != nil else {
            return super.performKeyEquivalent(with: event)
        }
        if let command = acceptedCommand(for: event) {
            perform(command)
            return true
        }
        return event.isARepeat || super.performKeyEquivalent(with: event)
    }
}

/// Lets the first click on the shelf act immediately instead of only focusing it.
final class FirstClickHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
