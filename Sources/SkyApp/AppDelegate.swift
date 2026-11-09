import AppKit
import ServiceManagement
import SkyCore

/// Starts Sky as a menu bar app with no Dock icon.
public enum SkyApplication {
    @MainActor
    public static func run() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { app.run() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let store = ShelfStore()
    private lazy var preview = PreviewController(store: store)
    private lazy var shelf = ShelfController(store: store, preview: preview)
    private var watcher: DirectoryWatcher?
    private var statusItem: NSStatusItem?
    private var locationCheck: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        store.isOnScreen = { [weak self] in self?.shelf.isPresented ?? false }
        store.onNewScreenshot = { [weak self] record in
            guard let self else { return }
            // ⇧⌘3 saves one file per display; only the newest ends up on the clipboard.
            if self.copiesNewScreenshots, self.store.items.first?.path == record.path {
                self.shelf.copy(record)
            }
            self.shelf.show()
        }
        watch(ScreenshotLocation.current())
        installStatusItem()
        shelf.startWatchingTopEdge()

        // The save location can be changed at any time from the Screenshot app's Options menu.
        let timer = Timer(timeInterval: 5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.followLocationChanges() }
        }
        RunLoop.main.add(timer, forMode: .common)
        locationCheck = timer
    }

    private func watch(_ directory: URL) {
        watcher?.stop()
        let watcher = DirectoryWatcher(directory: directory) { [weak self] paths in
            MainActor.assumeIsolated { self?.store.handleChanges(at: paths) }
        }
        watcher.start()
        self.watcher = watcher
        store.load(from: directory)
    }

    private func followLocationChanges() {
        let current = ScreenshotLocation.current()
        if ScreenshotFiles.canonical(current) != watcher.map({ ScreenshotFiles.canonical($0.directory) }) {
            watch(current)
        }
    }

    // MARK: Menu bar

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "cloud", accessibilityDescription: "Sky")
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        statusItem = item
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        menu.addItem(item(shelf.isPresented ? "Hide Recent Screenshots" : "Show Recent Screenshots",
                          action: #selector(toggleShelf), key: ""))
        menu.addItem(item("Clear Shelf", action: #selector(clearShelf), key: ""))
        menu.addItem(.separator())
        menu.addItem(item("Open Screenshots Folder", action: #selector(openScreenshotsFolder), key: ""))
        menu.addItem(.separator())

        let copyNew = item("Copy New Screenshots", action: #selector(toggleCopyNew), key: "")
        copyNew.state = copiesNewScreenshots ? .on : .off
        copyNew.toolTip = "Put each new screenshot on the clipboard as soon as it's saved."
        menu.addItem(copyNew)

        let topEdge = item("Show Shelf at Top Edge", action: #selector(toggleTopEdge), key: "")
        topEdge.state = shelf.revealsAtTopEdge ? .on : .off
        topEdge.toolTip = "Rest the pointer against the middle of the top edge of your main display to bring the shelf down."
        menu.addItem(topEdge)

        let keepVisible = item("Keep Shelf Visible", action: #selector(toggleKeepVisible), key: "")
        keepVisible.state = shelf.keepsVisible ? .on : .off
        menu.addItem(keepVisible)

        let thumbnail = item("Skip macOS Floating Thumbnail", action: #selector(toggleFloatingThumbnail), key: "")
        thumbnail.state = FloatingThumbnail.isShown ? .off : .on
        thumbnail.toolTip = "macOS waits for its own preview thumbnail to disappear before saving. Skipping it puts new screenshots on the shelf straight away."
        menu.addItem(thumbnail)

        let login = item("Open at Login", action: #selector(toggleOpenAtLogin), key: "")
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)

        menu.addItem(.separator())
        menu.addItem(item("Quit Sky", action: #selector(quit), key: "q"))
    }

    private func item(_ title: String, action: Selector, key: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc private func toggleShelf() { shelf.toggle() }

    @objc private func clearShelf() {
        store.removeAll()
    }

    @objc private func openScreenshotsFolder() {
        NSWorkspace.shared.open(ScreenshotLocation.current())
    }

    /// Whether each new screenshot goes straight onto the clipboard.
    private var copiesNewScreenshots: Bool {
        get { !UserDefaults.standard.bool(forKey: "copyNewScreenshotsDisabled") }
        set { UserDefaults.standard.set(!newValue, forKey: "copyNewScreenshotsDisabled") }
    }

    @objc private func toggleCopyNew() {
        copiesNewScreenshots.toggle()
    }

    @objc private func toggleTopEdge() {
        shelf.revealsAtTopEdge.toggle()
    }

    @objc private func toggleKeepVisible() {
        shelf.keepsVisible.toggle()
        if shelf.keepsVisible { shelf.show() }
    }

    @objc private func toggleFloatingThumbnail() {
        FloatingThumbnail.isShown.toggle()
    }

    @objc private func toggleOpenAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            let alert = NSAlert(error: error)
            alert.messageText = "Sky couldn't change Open at Login"
            NSApp.activate()
            alert.runModal()
        }
    }

    @objc private func quit() { NSApp.terminate(nil) }
}

/// The "Show Floating Thumbnail" option in the Screenshot app's Options menu.
enum FloatingThumbnail {
    private static let domain = "com.apple.screencapture"
    private static let key = "show-thumbnail"

    static var isShown: Bool {
        get {
            CFPreferencesAppSynchronize(domain as CFString)
            return (CFPreferencesCopyAppValue(key as CFString, domain as CFString) as? Bool) ?? true
        }
        set {
            CFPreferencesSetAppValue(key as CFString, newValue as CFBoolean, domain as CFString)
            CFPreferencesAppSynchronize(domain as CFString)
        }
    }
}
