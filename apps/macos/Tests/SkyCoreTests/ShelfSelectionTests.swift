import CoreGraphics
import Testing
@testable import SkyCore

@Suite struct ShelfSelectionTests {
    @Test func arrowsMoveOneCardAtATime() {
        #expect(ShelfSelection.moved(from: 1, by: 1, visibleCount: 5) == 2)
        #expect(ShelfSelection.moved(from: 1, by: -1, visibleCount: 5) == 0)
    }

    @Test func selectionStopsAtEitherEnd() {
        #expect(ShelfSelection.moved(from: 0, by: -1, visibleCount: 5) == 0)
        #expect(ShelfSelection.moved(from: 4, by: 1, visibleCount: 5) == 4)
    }

    @Test func withNothingSelectedAnyMoveSelectsTheNewest() {
        #expect(ShelfSelection.moved(from: nil, by: 1, visibleCount: 5) == 0)
        #expect(ShelfSelection.moved(from: nil, by: -1, visibleCount: 5) == 0)
    }

    @Test func anEmptyShelfHasNothingToSelect() {
        #expect(ShelfSelection.moved(from: nil, by: 1, visibleCount: 0) == nil)
        #expect(ShelfSelection.moved(from: 2, by: 1, visibleCount: 0) == nil)
    }

    @Test func selectionNeverReachesCardsThatDidNotFit() {
        let layout = ShelfLayout.make(aspectRatios: Array(repeating: 1.6, count: 12), containerWidth: 900, expanded: true)
        #expect(layout.visibleCount > 0 && layout.visibleCount < 12)
        let last = layout.visibleCount - 1
        #expect(ShelfSelection.moved(from: last, by: 1, visibleCount: layout.visibleCount) == last)
    }
}
