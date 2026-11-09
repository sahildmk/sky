import AppKit
import Testing
@testable import SkyApp

/// Which keys pressed over the shelf copy the screenshot under the pointer.
@MainActor
@Suite struct ShelfKeyTests {
    @Test func plainCCopies() {
        #expect(copies(keyDown: "c", modifiers: []))
    }

    @Test func cWithCapsLockOnCopies() {
        #expect(copies(keyDown: "C", modifiers: [.capsLock]))
    }

    @Test func commandCCopies() {
        #expect(copies(keyEquivalent: "c", modifiers: [.command]))
    }

    @Test func otherKeysDoNotCopy() {
        #expect(!copies(keyDown: "x", modifiers: []))
        #expect(!copies(keyDown: "c", modifiers: [.option]))
        #expect(!copies(keyDown: "c", modifiers: [.shift]))
        #expect(!copies(keyEquivalent: "c", modifiers: [.command, .shift]))
        #expect(!copies(keyEquivalent: "v", modifiers: [.command]))
    }

    private func copies(keyDown characters: String, modifiers: NSEvent.ModifierFlags) -> Bool {
        let (panel, copied) = makePanel()
        // keyDown passes other keys up the responder chain, which ends in a beep.
        panel.keyDown(with: event(characters, modifiers))
        return copied.value
    }

    private func copies(keyEquivalent characters: String, modifiers: NSEvent.ModifierFlags) -> Bool {
        let (panel, copied) = makePanel()
        _ = panel.performKeyEquivalent(with: event(characters, modifiers))
        return copied.value
    }

    private final class Flag { var value = false }

    private func makePanel() -> (ShelfPanel, Flag) {
        let panel = ShelfPanel()
        let copied = Flag()
        panel.onCopy = { copied.value = true }
        return (panel, copied)
    }

    private func event(_ characters: String, _ modifiers: NSEvent.ModifierFlags) -> NSEvent {
        NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: modifiers, timestamp: 0,
            windowNumber: 0, context: nil, characters: characters,
            charactersIgnoringModifiers: characters, isARepeat: false, keyCode: 8
        )!
    }
}
