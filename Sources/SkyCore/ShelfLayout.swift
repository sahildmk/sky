import CoreGraphics

/// Positions screenshot cards on the shelf, in a coordinate space whose origin
/// is the top-left of the shelf and whose y axis points down.
///
/// Collapsed, the cards sit in a deck centred at the top, newest on top, with
/// a few older cards peeking out underneath. Expanded, they fan out into a
/// centred row, newest on the left; cards that would not fit are hidden.
public struct ShelfLayout: Equatable, Sendable {
    public struct Card: Equatable, Sendable {
        public var frame: CGRect
        /// Degrees, clockwise.
        public var rotation: Double
        public var scale: CGFloat
        public var isVisible: Bool
        /// Higher draws on top.
        public var zIndex: Double
    }

    public struct Metrics: Equatable, Sendable {
        public var topInset: CGFloat = 12
        public var sideMargin: CGFloat = 48
        /// How far beyond the cards the pointer still counts as "on the shelf".
        public var hoverPadding: CGFloat = 16

        public var collapsedHeight: CGFloat = 84
        public var collapsedWidthRange: ClosedRange<CGFloat> = 96...150
        /// Cards drawn in the collapsed deck, including the top one.
        public var deckDepth: Int = 4
        public var deckStep: CGFloat = 9
        public var deckScaleStep: CGFloat = 0.05
        public var deckRotations: [Double] = [0, -3.5, 3, -2]

        public var expandedHeight: CGFloat = 120
        public var expandedWidthRange: ClosedRange<CGFloat> = 108...236
        public var spacing: CGFloat = 14
        /// The row never grows wider than this, however wide the display.
        public var maxRowWidth: CGFloat = 1240

        public var emptySize = CGSize(width: 300, height: 40)

        public init() {}

        public static let standard = Metrics()
    }

    public var cards: [Card]
    /// The region where the pointer expands the shelf and interacts with it.
    public var activeRect: CGRect
    /// Lowest point of any drawn card, for sliding the shelf fully out of view.
    public var contentBottom: CGFloat

    /// - Parameter aspectRatios: width ÷ height of each screenshot, newest first.
    public static func make(
        aspectRatios: [CGFloat],
        containerWidth: CGFloat,
        expanded: Bool,
        metrics: Metrics = .standard
    ) -> ShelfLayout {
        guard !aspectRatios.isEmpty else {
            let size = metrics.emptySize
            let frame = CGRect(
                x: (containerWidth - size.width) / 2, y: metrics.topInset,
                width: size.width, height: size.height
            )
            return ShelfLayout(
                cards: [],
                activeRect: frame.insetBy(dx: -metrics.hoverPadding, dy: -metrics.hoverPadding),
                contentBottom: frame.maxY
            )
        }
        return expanded
            ? row(aspectRatios, containerWidth: containerWidth, metrics: metrics)
            : deck(aspectRatios, containerWidth: containerWidth, metrics: metrics)
    }

    private static func deck(_ aspectRatios: [CGFloat], containerWidth: CGFloat, metrics m: Metrics) -> ShelfLayout {
        let height = m.collapsedHeight
        let width = clamp(aspectRatios[0] * height, to: m.collapsedWidthRange)
        let lastDeckIndex = min(aspectRatios.count, m.deckDepth) - 1

        let cards = aspectRatios.indices.map { index -> Card in
            let depth = min(index, lastDeckIndex)
            let frame = CGRect(
                x: (containerWidth - width) / 2,
                y: m.topInset + CGFloat(depth) * m.deckStep,
                width: width, height: height
            )
            return Card(
                frame: frame,
                rotation: m.deckRotations.isEmpty ? 0 : m.deckRotations[depth % m.deckRotations.count],
                scale: 1 - CGFloat(depth) * m.deckScaleStep,
                isVisible: index <= lastDeckIndex,
                zIndex: -Double(index)
            )
        }
        let visible = cards.filter(\.isVisible).map(\.frame)
        let bounds = visible.dropFirst().reduce(visible[0]) { $0.union($1) }
        return ShelfLayout(
            cards: cards,
            activeRect: bounds.insetBy(dx: -m.hoverPadding, dy: -m.hoverPadding),
            contentBottom: bounds.maxY
        )
    }

    private static func row(_ aspectRatios: [CGFloat], containerWidth: CGFloat, metrics m: Metrics) -> ShelfLayout {
        let height = m.expandedHeight
        let widths = aspectRatios.map { clamp($0 * height, to: m.expandedWidthRange) }
        let available = max(min(containerWidth - 2 * m.sideMargin, m.maxRowWidth), widths[0])

        // Newest first: keep adding cards while the row still fits.
        var fitting = 0
        var rowWidth: CGFloat = 0
        for width in widths {
            let next = rowWidth + (fitting == 0 ? 0 : m.spacing) + width
            if next > available, fitting > 0 { break }
            rowWidth = next
            fitting += 1
        }

        var x = (containerWidth - rowWidth) / 2
        var cards: [Card] = []
        for (index, width) in widths.enumerated() {
            if index < fitting {
                cards.append(Card(
                    frame: CGRect(x: x, y: m.topInset, width: width, height: height),
                    rotation: 0, scale: 1, isVisible: true, zIndex: -Double(index)
                ))
                x += width + m.spacing
            } else {
                // Tucked behind the last visible card so it can animate in from there.
                let anchor = cards[fitting - 1].frame
                cards.append(Card(
                    frame: CGRect(x: anchor.maxX - width, y: m.topInset, width: width, height: height),
                    rotation: 0, scale: 0.8, isVisible: false, zIndex: -Double(index)
                ))
            }
        }

        let bounds = CGRect(
            x: (containerWidth - rowWidth) / 2, y: m.topInset,
            width: rowWidth, height: height
        )
        return ShelfLayout(
            cards: cards,
            activeRect: bounds.insetBy(dx: -m.hoverPadding, dy: -m.hoverPadding),
            contentBottom: bounds.maxY
        )
    }

    /// The region where the pointer keeps the shelf open: the active region,
    /// extended straight up by `distance` points, past the top of the shelf.
    /// Pass the distance to the top of the screen so moving from the shelf
    /// to the top edge never counts as leaving it.
    public func hoverRect(extendingUpBy distance: CGFloat) -> CGRect {
        let top = min(activeRect.minY, -max(distance, 0))
        return CGRect(x: activeRect.minX, y: top, width: activeRect.width, height: activeRect.maxY - top)
    }

    /// Index of the visible card under `point`, preferring the one drawn on top.
    public func cardIndex(at point: CGPoint) -> Int? {
        cards.indices
            .filter { cards[$0].isVisible && cards[$0].frame.contains(point) }
            .max { cards[$0].zIndex < cards[$1].zIndex }
    }

    private static func clamp(_ value: CGFloat, to range: ClosedRange<CGFloat>) -> CGFloat {
        min(max(value, range.lowerBound), range.upperBound)
    }
}
