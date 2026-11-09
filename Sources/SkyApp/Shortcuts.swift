import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// Opens the shelf for the keyboard, or closes it. ⇧⌘6 by default: the
    /// next number after macOS's own ⇧⌘3, ⇧⌘4 and ⇧⌘5 screenshot shortcuts.
    static let toggleShelf = Self("toggleShelf", initial: .init(.six, modifiers: [.command, .shift]))
}
