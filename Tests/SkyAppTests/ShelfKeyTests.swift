import AppKit
import Testing
@testable import SkyApp

/// Which keys pressed on the shelf do what.
@MainActor
@Suite struct ShelfKeyTests {
    @Test func arrowKeysMoveTheSelection() {
        #expect(command(keyCode: 123, "\u{F702}", [.numericPad, .function]) == .previous)
        #expect(command(keyCode: 124, "\u{F703}", [.numericPad, .function]) == .next)
    }

    @Test func spacePreviewsAndReturnCopiesAndCloses() {
        #expect(command(keyCode: 49, " ") == .preview)
        #expect(command(keyCode: 36, "\r") == .copyAndClose)
        #expect(command(keyCode: 76, "\u{3}", [.numericPad]) == .copyAndClose)
    }

    @Test func cAndCommandCCopy() {
        #expect(command(keyCode: 8, "c") == .copy)
        #expect(command(keyCode: 8, "c", [.command]) == .copy)
        #expect(command(keyCode: 8, "C", [.capsLock]) == .copy)
    }

    @Test func commandDeleteMovesToTheTrash() {
        #expect(command(keyCode: 51, "\u{7F}", [.command]) == .moveToTrash)
        #expect(command(keyCode: 117, "\u{F728}", [.command, .function]) == .moveToTrash)
    }

    @Test func escapeCloses() {
        #expect(command(keyCode: 53, "\u{1B}") == .close)
    }

    @Test func otherKeysAndCombinationsDoNothing() {
        #expect(command(keyCode: 7, "x") == nil)
        #expect(command(keyCode: 8, "c", [.option]) == nil)
        #expect(command(keyCode: 8, "c", [.shift]) == nil)
        #expect(command(keyCode: 8, "c", [.command, .shift]) == nil)
        #expect(command(keyCode: 9, "v", [.command]) == nil)
        #expect(command(keyCode: 51, "\u{7F}") == nil)  // Delete alone does not trash
        #expect(command(keyCode: 123, "\u{F702}", [.shift, .numericPad, .function]) == nil)
    }

    @Test func aKeyPressReachesTheShelf() {
        let panel = ShelfPanel()
        var received: [ShelfCommand] = []
        panel.perform = { received.append($0) }

        panel.keyDown(with: event(keyCode: 124, "\u{F703}", [.numericPad, .function]))
        _ = panel.performKeyEquivalent(with: event(keyCode: 8, "c", [.command]))
        // A plain key offered as a key equivalent is left for keyDown, so it isn't handled twice.
        #expect(panel.performKeyEquivalent(with: event(keyCode: 49, " ")) == false)

        #expect(received == [.next, .copy])
    }

    @Test func heldKeysRepeatOnlyForMovingTheSelection() {
        let panel = ShelfPanel()
        var received: [ShelfCommand] = []
        panel.perform = { received.append($0) }

        panel.keyDown(with: event(keyCode: 124, "\u{F703}", [.numericPad, .function], repeat: true))
        _ = panel.performKeyEquivalent(with: event(keyCode: 51, "\u{7F}", [.command], repeat: true))
        panel.keyDown(with: event(keyCode: 49, " ", repeat: true))
        panel.keyDown(with: event(keyCode: 8, "c", repeat: true))

        #expect(received == [.next])
    }

    @Test func aHoveredShelfOnlyCopies() {
        let panel = ShelfPanel()
        var received: [ShelfCommand] = []
        panel.perform = { received.append($0) }
        panel.accepts = { $0 == .copy }

        panel.keyDown(with: event(keyCode: 124, "\u{F703}", [.numericPad, .function]))
        panel.keyDown(with: event(keyCode: 49, " "))
        panel.keyDown(with: event(keyCode: 36, "\r"))
        _ = panel.performKeyEquivalent(with: event(keyCode: 51, "\u{7F}", [.command]))
        panel.keyDown(with: event(keyCode: 8, "c"))
        _ = panel.performKeyEquivalent(with: event(keyCode: 8, "c", [.command]))

        #expect(received == [.copy, .copy])
    }

    private func command(keyCode: UInt16, _ characters: String, _ modifiers: NSEvent.ModifierFlags = []) -> ShelfCommand? {
        ShelfPanel.command(for: event(keyCode: keyCode, characters, modifiers))
    }

    private func event(
        keyCode: UInt16, _ characters: String, _ modifiers: NSEvent.ModifierFlags = [], repeat isRepeat: Bool = false
    ) -> NSEvent {
        NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: modifiers, timestamp: 0,
            windowNumber: 0, context: nil, characters: characters,
            charactersIgnoringModifiers: characters, isARepeat: isRepeat, keyCode: keyCode
        )!
    }
}
