import AppKit
import Observation
import OSLog
import SkyCore
import SwiftUI

/// The screenshots on the shelf, newest first, and their thumbnails.
@MainActor
@Observable
final class ShelfStore {
    nonisolated static let capacity = 12
    /// A file counts as a new capture only if it was created this recently.
    /// macOS's floating thumbnail delays the save by about five seconds.
    nonisolated static let newCaptureWindow: TimeInterval = 60

    private(set) var items: [ScreenshotRecord] = []
    private(set) var thumbnails: [String: NSImage] = [:]

    /// Whether the shelf is showing. A new screenshot only drops onto the
    /// stack when it is; otherwise the shelf sliding in carries the arrival.
    @ObservationIgnored var isOnScreen: () -> Bool = { true }

    /// Called after a newly captured screenshot lands on the shelf.
    @ObservationIgnored var onNewScreenshot: ((ScreenshotRecord) -> Void)?

    /// Called after `rename` moves a screenshot, with its old and new records.
    @ObservationIgnored var onRename: ((ScreenshotRecord, ScreenshotRecord) -> Void)?

    @ObservationIgnored private var removedPaths: Set<String>
    @ObservationIgnored private var pendingPaths: Set<String> = []
    @ObservationIgnored private var draggedPaths: Set<String> = []
    private static let removedPathsKey = "removedPaths"
    private nonisolated static let log = Logger(subsystem: "com.sahildmk.sky", category: "shelf")

    init() {
        removedPaths = Set(UserDefaults.standard.stringArray(forKey: Self.removedPathsKey) ?? [])
    }

    /// A shelf holding fixed screenshots, for rendering snapshots.
    init(items: [ScreenshotRecord], thumbnails: [String: NSImage]) {
        removedPaths = []
        self.items = items
        self.thumbnails = thumbnails
    }

    /// Replaces the shelf with the newest screenshots in `directory`.
    func load(from directory: URL) {
        let excluded = removedPaths
        Task.detached(priority: .userInitiated) {
            let listed = ScreenshotFiles.recent(in: directory, limit: Self.capacity, excludingPaths: excluded)
            await MainActor.run {
                // A screenshot renamed while the folder was being read is
                // listed under a path that no longer exists.
                let records = listed.filter { FileManager.default.fileExists(atPath: $0.path) }
                self.items = records
                self.thumbnails = self.thumbnails.filter { path, _ in records.contains { $0.path == path } }
                records.forEach(self.loadThumbnail)
            }
        }
    }

    /// Handles file system changes in the screenshot directory.
    func handleChanges(at paths: [String]) {
        for rawPath in paths {
            let url = ScreenshotFiles.canonical(URL(fileURLWithPath: rawPath))
            let path = url.path
            if !FileManager.default.fileExists(atPath: path) {
                withAnimation(Motion.rearrange) { drop(path) }
                continue
            }
            guard ScreenshotFiles.isCandidate(url),
                  !items.contains(where: { $0.path == path }),
                  !removedPaths.contains(path),
                  !pendingPaths.contains(path)
            else { continue }
            pendingPaths.insert(path)
            inspect(url, attempt: 0)
        }
    }

    /// macOS can write the file a moment before it tags it as a screen
    /// capture, so an untagged new image is checked again a few times.
    private func inspect(_ url: URL, attempt: Int) {
        let retryDelays: [Double] = [0.2, 0.5, 1.0, 2.0]
        Task.detached(priority: .userInitiated) {
            let record = ScreenshotFiles.record(for: url)
            await MainActor.run {
                if let record {
                    self.pendingPaths.remove(url.path)
                    if Date().timeIntervalSince(record.createdAt) < Self.newCaptureWindow {
                        self.insert(record)
                    }
                } else if attempt < retryDelays.count, FileManager.default.fileExists(atPath: url.path) {
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(retryDelays[attempt]))
                        self.inspect(url, attempt: attempt + 1)
                    }
                } else {
                    self.pendingPaths.remove(url.path)
                }
            }
        }
    }

    private func insert(_ record: ScreenshotRecord) {
        guard !items.contains(where: { $0.path == record.path }) else { return }
        var updated = items
        updated.append(record)
        updated.sort { $0.createdAt > $1.createdAt }
        withAnimation(isOnScreen() ? Motion.arrive : nil) { items = Array(updated.prefix(Self.capacity)) }
        loadThumbnail(record)
        if items.contains(where: { $0.path == record.path }) {
            onNewScreenshot?(record)
        }
    }

    /// Records that a screenshot was dragged out of Sky. The drop reads the
    /// file at its current path, so `rename` leaves it alone from then on.
    func noteDragged(_ record: ScreenshotRecord) {
        draggedPaths.insert(record.path)
    }

    /// Renames a screenshot on the shelf to `stem`, keeping its extension and
    /// adding a number if the name is taken. Its card keeps its place.
    ///
    /// Does nothing if the screenshot is off the shelf, its file is gone, or
    /// it has been dragged somewhere.
    func rename(_ record: ScreenshotRecord, to stem: String) {
        guard let index = items.firstIndex(where: { $0.path == record.path }),
              FileManager.default.fileExists(atPath: record.path),
              !draggedPaths.contains(record.path)
        else { return }
        let destination = ScreenshotNaming.destination(
            stem: stem, pathExtension: record.url.pathExtension, in: record.url.deletingLastPathComponent()
        ) { FileManager.default.fileExists(atPath: $0.path) }
        do {
            try FileManager.default.moveItem(at: record.url, to: destination)
        } catch {
            Self.log.error("Couldn't rename \(record.url.lastPathComponent, privacy: .public): \(error, privacy: .public)")
            return
        }

        // The card moves to its new path before the file system reports the
        // rename, so that event finds it already on the shelf.
        let renamed = ScreenshotRecord(
            url: ScreenshotFiles.canonical(destination),
            createdAt: record.createdAt,
            pixelWidth: record.pixelWidth,
            pixelHeight: record.pixelHeight
        )
        let thumbnail = thumbnails.removeValue(forKey: record.path)
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            items[index] = renamed
            thumbnails[renamed.path] = thumbnail
        }
        // A thumbnail still loading under the old path is discarded when it
        // arrives, so load it again under the new one.
        if thumbnail == nil { loadThumbnail(renamed) }
        onRename?(record, renamed)
    }

    /// Takes a screenshot off the shelf without touching the file. It stays off
    /// the shelf across relaunches.
    func remove(_ record: ScreenshotRecord) {
        removedPaths.insert(record.path)
        UserDefaults.standard.set(Array(removedPaths.suffix(500)), forKey: Self.removedPathsKey)
        drop(record.path)
    }

    func removeAll() {
        items.forEach { removedPaths.insert($0.path) }
        UserDefaults.standard.set(Array(removedPaths.suffix(500)), forKey: Self.removedPathsKey)
        items = []
        thumbnails = [:]
    }

    private func drop(_ path: String) {
        items.removeAll { $0.path == path }
        thumbnails[path] = nil
    }

    private func loadThumbnail(_ record: ScreenshotRecord) {
        guard thumbnails[record.path] == nil else { return }
        let url = record.url
        Task.detached(priority: .userInitiated) {
            guard let image = ScreenshotFiles.thumbnail(for: url, maxPixelSize: 720) else { return }
            let size = NSSize(width: image.width, height: image.height)
            await MainActor.run {
                guard self.items.contains(where: { $0.path == url.path }) else { return }
                self.thumbnails[url.path] = NSImage(cgImage: image, size: size)
            }
        }
    }
}
