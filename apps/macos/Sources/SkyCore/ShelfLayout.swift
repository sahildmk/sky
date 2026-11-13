import CoreGraphics

/// Positions screenshot cards on the shelf, in a coordinate space whose origin
/// is the top-left of the shelf and whose y axis points down.
///
/// Cards come in sections, such as screenshots and then threads, laid out
/// side by side in order with a wider gap between sections. Collapsed, each
/// section is a deck, newest on top, with a few older cards peeking out
/// underneath, and the decks sit centred at the top. Expanded, they fan out
/// into one centred row, newest on the left; cards that would not fit are
/// hidden. Cards are numbered across sections in the order given.
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
        /// Space between sections, in both the decks and the row.
        public var sectionGap: CGFloat = 32
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

    /// A layout with a single section.
    ///
    /// - Parameter aspectRatios: width ÷ height of each card, newest first.
    public static func make(
        aspectRatios: [CGFloat],
        containerWidth: CGFloat,
        expanded: Bool,
        metrics: Metrics = .standard
    ) -> ShelfLayout {
        make(sections: [aspectRatios], containerWidth: containerWidth, expanded: expanded, metrics: metrics)
    }

    /// - Parameter sections: width ÷ height of each card in each section, newest
    ///   first. Empty sections take no space.
    public static func make(
        sections: [[CGFloat]],
        containerWidth: CGFloat,
        expanded: Bool,
        metrics: Metrics = .standard
    ) -> ShelfLayout {
        let sections = sections.filter { !$0.isEmpty }
        guard !sections.isEmpty else {
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
            ? row(sections, containerWidth: containerWidth, metrics: metrics)
            : decks(sections, containerWidth: containerWidth, metrics: metrics)
    }

    private static func decks(_ sections: [[CGFloat]], containerWidth: CGFloat, metrics m: Metrics) -> ShelfLayout {
        let height = m.collapsedHeight
        let widths = sections.map { clamp($0[0] * height, to: m.collapsedWidthRange) }
        let total = widths.reduce(0, +) + m.sectionGap * CGFloat(sections.count - 1)

        var x = (containerWidth - total) / 2
        var cards: [Card] = []
        for (aspectRatios, width) in zip(sections, widths) {
            let lastDeckIndex = min(aspectRatios.count, m.deckDepth) - 1
            cards += aspectRatios.indices.map { index -> Card in
                let depth = min(index, lastDeckIndex)
                return Card(
                    frame: CGRect(x: x, y: m.topInset + CGFloat(depth) * m.deckStep, width: width, height: height),
                    rotation: m.deckRotations.isEmpty ? 0 : m.deckRotations[depth % m.deckRotations.count],
                    scale: 1 - CGFloat(depth) * m.deckScaleStep,
                    isVisible: index <= lastDeckIndex,
                    zIndex: -Double(index)
                )
            }
            x += width + m.sectionGap
        }

        let visible = cards.filter(\.isVisible).map(\.frame)
        let bounds = visible.dropFirst().reduce(visible[0]) { $0.union($1) }
        return ShelfLayout(
            cards: cards,
            activeRect: bounds.insetBy(dx: -m.hoverPadding, dy: -m.hoverPadding),
            contentBottom: bounds.maxY
        )
    }

    private static func row(_ sections: [[CGFloat]], containerWidth: CGFloat, metrics m: Metrics) -> ShelfLayout {
        let height = m.expandedHeight
        let widths = sections.map { $0.map { clamp($0 * height, to: m.expandedWidthRange) } }
        let gaps = m.sectionGap * CGFloat(sections.count - 1)
        let available = min(containerWidth - 2 * m.sideMargin, m.maxRowWidth) - gaps

        // Each section keeps room for the sections after it, up to an equal
        // share of the row each, so a long first section can't push the
        // others off the shelf.
        let share = available / CGFloat(sections.count)
        func naturalWidth(_ widths: [CGFloat]) -> CGFloat {
            widths.reduce(0, +) + m.spacing * CGFloat(widths.count - 1)
        }
        var fits: [(count: Int, width: CGFloat)] = []
        var used: CGFloat = 0
        for (index, sectionWidths) in widths.enumerated() {
            let reserved = widths.dropFirst(index + 1).reduce(0) { $0 + min(naturalWidth($1), share) }
            let fit = fitting(sectionWidths, in: available - used - reserved, spacing: m.spacing)
            fits.append(fit)
            used += fit.width
        }

        let rowWidth = used + gaps
        var x = (containerWidth - rowWidth) / 2
        var cards: [Card] = []
        for (sectionWidths, fit) in zip(widths, fits) {
            var shown: [Card] = []
            for (index, width) in sectionWidths.enumerated() {
                if index < fit.count {
                    shown.append(Card(
                        frame: CGRect(x: x, y: m.topInset, width: width, height: height),
                        rotation: 0, scale: 1, isVisible: true, zIndex: -Double(index)
                    ))
                    x += width + m.spacing
                } else {
                    // Tucked behind the section's last visible card so it can animate in from there.
                    let anchor = shown[fit.count - 1].frame
                    shown.append(Card(
                        frame: CGRect(x: anchor.maxX - width, y: m.topInset, width: width, height: height),
                        rotation: 0, scale: 0.8, isVisible: false, zIndex: -Double(index)
                    ))
                }
            }
            cards += shown
            x += m.sectionGap - m.spacing
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

    /// How many cards fit, newest first, within `available` points, and how
    /// wide they are together. The newest card always counts as fitting.
    private static func fitting(_ widths: [CGFloat], in available: CGFloat, spacing: CGFloat) -> (count: Int, width: CGFloat) {
        var count = 0
        var total: CGFloat = 0
        for width in widths {
            let next = total + (count == 0 ? 0 : spacing) + width
            if next > available, count > 0 { break }
            total = next
            count += 1
        }
        return (count, total)
    }

    /// The region where the pointer keeps the shelf open: the active region,
    /// extended straight up by `distance` points, past the top of the shelf.
    /// Pass the distance to the top of the screen so moving from the shelf
    /// to the top edge never counts as leaving it.
    public func hoverRect(extendingUpBy distance: CGFloat) -> CGRect {
        let top = min(activeRect.minY, -max(distance, 0))
        return CGRect(x: activeRect.minX, y: top, width: activeRect.width, height: activeRect.maxY - top)
    }

    /// Indices of the cards that are drawn, in order.
    public var visibleIndices: [Int] {
        cards.indices.filter { cards[$0].isVisible }
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
