import CoreGraphics
import Testing
@testable import SkyCore

@Suite struct ShelfLayoutTests {
    let width: CGFloat = 1600
    let metrics = ShelfLayout.Metrics.standard

    @Test func collapsedDeckIsCentredWithOlderCardsPeekingBelow() {
        let layout = ShelfLayout.make(aspectRatios: [1.6, 1.6, 1.6, 1.6, 1.6, 1.6], containerWidth: width, expanded: false)

        let visible = layout.cards.filter(\.isVisible)
        #expect(visible.count == metrics.deckDepth)
        for card in layout.cards {
            #expect(abs(card.frame.midX - width / 2) < 0.001)
        }
        // Each card in the deck sits lower and smaller than the one in front of it.
        for (front, back) in zip(visible, visible.dropFirst()) {
            #expect(back.frame.minY > front.frame.minY)
            #expect(back.scale < front.scale)
            #expect(back.zIndex < front.zIndex)
        }
    }

    @Test func expandedRowIsCentredAndCardsDoNotOverlap() {
        let layout = ShelfLayout.make(aspectRatios: [1.6, 0.5, 3.0, 1.0], containerWidth: width, expanded: true)

        let frames = layout.cards.map(\.frame)
        #expect(layout.cards.allSatisfy { $0.isVisible })
        for (left, right) in zip(frames, frames.dropFirst()) {
            #expect(right.minX - left.maxX == metrics.spacing)
        }
        let rowMid = (frames.first!.minX + frames.last!.maxX) / 2
        #expect(abs(rowMid - width / 2) < 0.001)
    }

    @Test func extremeAspectRatiosAreClampedToReadableSizes() {
        let layout = ShelfLayout.make(aspectRatios: [0.1, 20], containerWidth: width, expanded: true)
        #expect(layout.cards[0].frame.width == metrics.expandedWidthRange.lowerBound)
        #expect(layout.cards[1].frame.width == metrics.expandedWidthRange.upperBound)
    }

    @Test func expandedRowHidesTheOldestCardsThatDoNotFit() {
        let narrow: CGFloat = 700
        let layout = ShelfLayout.make(aspectRatios: Array(repeating: 1.6, count: 12), containerWidth: narrow, expanded: true)

        let visibleCount = layout.cards.prefix { $0.isVisible }.count
        #expect(visibleCount > 0 && visibleCount < 12)
        #expect(layout.cards.dropFirst(visibleCount).allSatisfy { !$0.isVisible })
        let lastVisible = layout.cards[visibleCount - 1].frame
        #expect(lastVisible.maxX <= narrow - metrics.sideMargin)
    }

    @Test func expandedRowStaysCompactOnWideDisplays() {
        let layout = ShelfLayout.make(aspectRatios: Array(repeating: 1.6, count: 12), containerWidth: 3008, expanded: true)

        let visible = layout.cards.filter(\.isVisible).map(\.frame)
        let rowWidth = visible.last!.maxX - visible.first!.minX
        #expect(rowWidth <= metrics.maxRowWidth)
        #expect(visible.count < 12)
    }

    @Test func activeRectCoversEveryVisibleCard() {
        for expanded in [false, true] {
            let layout = ShelfLayout.make(aspectRatios: [1.6, 1.2, 2.0, 0.8, 1.6], containerWidth: width, expanded: expanded)
            for card in layout.cards where card.isVisible {
                #expect(layout.activeRect.contains(card.frame))
            }
        }
    }

    @Test func pointerFindsTheCardDrawnOnTop() {
        let collapsed = ShelfLayout.make(aspectRatios: [1.6, 1.6, 1.6], containerWidth: width, expanded: false)
        let centre = CGPoint(x: collapsed.cards[0].frame.midX, y: collapsed.cards[0].frame.midY)
        #expect(collapsed.cardIndex(at: centre) == 0)

        let expanded = ShelfLayout.make(aspectRatios: [1.6, 1.6, 1.6], containerWidth: width, expanded: true)
        let third = expanded.cards[2].frame
        #expect(expanded.cardIndex(at: CGPoint(x: third.midX, y: third.midY)) == 2)
        #expect(expanded.cardIndex(at: CGPoint(x: 1, y: 1)) == nil)
    }

    @Test func hoverRegionReachesUpToTheTopOfTheScreen() {
        let layout = ShelfLayout.make(aspectRatios: [1.6, 1.6], containerWidth: width, expanded: true)
        let menuBar: CGFloat = 30
        let hover = layout.hoverRect(extendingUpBy: menuBar)

        // Straight above the shelf, in the menu bar, still counts as on the shelf.
        #expect(hover.contains(CGPoint(x: layout.activeRect.midX, y: -menuBar + 0.5)))
        #expect(hover.contains(layout.activeRect))
        // Above the shelf but off to the side does not.
        #expect(!hover.contains(CGPoint(x: layout.activeRect.minX - 1, y: -10)))
        // Nor does anywhere below the shelf.
        #expect(!hover.contains(CGPoint(x: layout.activeRect.midX, y: layout.activeRect.maxY + 1)))
    }

    @Test func emptyShelfStillHasSomewhereToPoint() {
        let layout = ShelfLayout.make(aspectRatios: [], containerWidth: width, expanded: true)
        #expect(layout.cards.isEmpty)
        #expect(abs(layout.activeRect.midX - width / 2) < 0.001)
        #expect(layout.activeRect.width > metrics.emptySize.width)
    }
}
