import CoreGraphics
import SkyCore

/// A card on the shelf.
enum ShelfItem: Hashable {
    case screenshot(path: String)
    case thread(id: String)
}

/// Everything on the shelf, in the order it is drawn: screenshots, newest
/// first, then open threads, most recently active first.
@MainActor
struct ShelfContents {
    let screenshots: [ScreenshotRecord]
    let threads: [SkyThread]

    init(store: ShelfStore, threads: ThreadsStore) {
        screenshots = store.items
        self.threads = threads.threads
    }

    var items: [ShelfItem] {
        screenshots.map { .screenshot(path: $0.path) } + threads.map { .thread(id: $0.id) }
    }

    var isEmpty: Bool { screenshots.isEmpty && threads.isEmpty }

    func layout(containerWidth: CGFloat, expanded: Bool) -> ShelfLayout {
        ShelfLayout.make(
            sections: [screenshots.map(\.aspectRatio), threads.map { _ in ThreadCard.aspectRatio }],
            containerWidth: containerWidth,
            expanded: expanded
        )
    }

    func screenshot(_ path: String) -> ScreenshotRecord? {
        screenshots.first { $0.path == path }
    }

    func thread(_ id: String) -> SkyThread? {
        threads.first { $0.id == id }
    }

    /// The badge on the top card of a collapsed deck: how many cards that deck holds.
    func deckCount(at index: Int) -> Int? {
        if index == 0, screenshots.count > 1 { return screenshots.count }
        if index == screenshots.count, threads.count > 1 { return threads.count }
        return nil
    }
}
