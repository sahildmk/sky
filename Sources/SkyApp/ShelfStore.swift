import AppKit
import Observation
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

    /// Called after a newly captured screenshot lands on the shelf.
    @ObservationIgnored var onNewScreenshot: (() -> Void)?

    @ObservationIgnored private var removedPaths: Set<String>
    @ObservationIgnored private var pendingPaths: Set<String> = []
    private static let removedPathsKey = "removedPaths"

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
            let records = ScreenshotFiles.recent(in: directory, limit: Self.capacity, excludingPaths: excluded)
            await MainActor.run {
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
        withAnimation(Motion.arrive) { items = Array(updated.prefix(Self.capacity)) }
        loadThumbnail(record)
        if items.contains(where: { $0.path == record.path }) {
            onNewScreenshot?()
        }
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
