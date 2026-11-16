import Foundation
import OSLog
import SkyCore

/// Renames each new screenshot to a lowercase, hyphenated description of what
/// it shows followed by its capture date and time. The description comes from
/// the on-device model; without one the file is named `screenshot-<date-time>`.
@MainActor
final class NewScreenshotNaming {
    /// A name that takes longer than this arrives after the person has likely
    /// pasted, dragged or opened the file, so it is not applied.
    static let deadline: TimeInterval = 20

    private static let disabledKey = "nameNewScreenshotsDisabled"
    private nonisolated static let log = Logger(subsystem: "com.sahildmk.sky", category: "naming")

    private let store: ShelfStore
    private let namer = ScreenshotNamer()
    /// Files already named. A file renamed within a minute of its capture
    /// lands on the shelf again as if new, and must keep the person's name.
    private var namedFiles: Set<FileIdentity> = []

    init(store: ShelfStore) {
        self.store = store
    }

    /// The person's choice, from the menu bar. On unless they turned it off.
    static var isEnabled: Bool {
        get { !UserDefaults.standard.bool(forKey: disabledKey) }
        set { UserDefaults.standard.set(!newValue, forKey: disabledKey) }
    }

    static var isAvailable: Bool { ScreenshotNamer.isAvailable }

    /// Loads the model ahead of the first screenshot.
    func prewarm() {
        guard Self.isEnabled, Self.isAvailable else { return }
        let namer = namer
        Task.detached(priority: .utility) {
            let started = Date()
            await namer.prewarm()
            Self.log.info("Prewarmed in \(Date().timeIntervalSince(started), format: .fixed(precision: 2))s")
        }
    }

    /// Renames a screenshot that just landed on the shelf.
    func name(_ record: ScreenshotRecord) {
        guard Self.isEnabled,
              let identity = ScreenshotFiles.identity(of: record.url),
              namedFiles.insert(identity).inserted
        else { return }
        let namer = namer
        let started = Date()
        Task {
            var slug: String?
            if Self.isAvailable {
                do {
                    slug = try await namer.suggestedSlug(for: record.url)
                } catch {
                    Self.log.error("No description for \(record.url.lastPathComponent, privacy: .public): \(error, privacy: .public)")
                }
            }
            let elapsed = Date().timeIntervalSince(started)
            guard elapsed < Self.deadline else {
                Self.log.info("Skipped renaming after \(elapsed, format: .fixed(precision: 2))s")
                return
            }
            let stem = ScreenshotNaming.fileStem(slug: slug, capturedAt: record.createdAt)
            Self.log.info("Named \(stem, privacy: .public) in \(elapsed, format: .fixed(precision: 2))s")
            store.rename(record, to: stem)
        }
    }
}
