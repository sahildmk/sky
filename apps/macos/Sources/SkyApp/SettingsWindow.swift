import AppKit
import KeyboardShortcuts
import SwiftUI

/// Sky's settings: the global shortcut, and a reference for the shelf's keys.
@MainActor
final class SettingsWindowController {
    private var window: NSWindow?

    func show() {
        let window = self.window ?? makeWindow()
        self.window = window
        // A settings window takes typing (the shortcut recorder needs it), so
        // unlike the shelf it brings Sky to the front.
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView()))
        window.title = "Sky Settings"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }
}

struct SettingsView: View {
    var body: some View {
        Form {
            Section {
                LabeledContent("Show shelf") {
                    KeyboardShortcuts.Recorder(for: .toggleShelf)
                }
            } header: {
                Text("Shortcut")
            } footer: {
                Text("Works from any app. Press it again to close the shelf.")
                    .foregroundStyle(.secondary)
            }

            Section("On the shelf") {
                KeyRow(keys: "← →", action: "Select a screenshot")
                KeyRow(keys: "Space", action: "Preview")
                KeyRow(keys: "Return", action: "Copy and close")
                KeyRow(keys: "C or ⌘C", action: "Copy")
                KeyRow(keys: "⌘⌫", action: "Move to Trash")
                KeyRow(keys: "Esc", action: "Close")
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct KeyRow: View {
    let keys: String
    let action: String

    var body: some View {
        LabeledContent(action) {
            Text(keys)
                .font(.system(.body, design: .rounded).weight(.medium))
                .foregroundStyle(.secondary)
        }
    }
}
