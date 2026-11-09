import CoreGraphics
import Testing
@testable import SkyCore

@Suite struct PreviewGeometryTests {
    let screen = CGRect(x: 0, y: 0, width: 1512, height: 945)
    let minimum = CGSize(width: 320, height: 200)
    /// Screen height less the margin on both sides.
    let availableHeight: CGFloat = 945 - 2 * 80

    @Test func fullScreenCaptureIsScaledDownToFitAndKeepsItsShape() {
        let frame = PreviewGeometry.frame(
            forPixelSize: CGSize(width: 3024, height: 1890), backingScale: 2,
            in: screen, margin: 80, minimumSize: minimum
        )
        #expect(frame.height == availableHeight)
        #expect(abs(frame.width / frame.height - 3024.0 / 1890.0) < 0.01)
        #expect(screen.insetBy(dx: 80, dy: 80).contains(frame))
    }

    @Test func smallCaptureIsShownAtNativeSizeAndCentred() {
        let frame = PreviewGeometry.frame(
            forPixelSize: CGSize(width: 1200, height: 800), backingScale: 2,
            in: screen, margin: 80, minimumSize: minimum
        )
        #expect(frame.size == CGSize(width: 600, height: 400))
        // Frames snap to whole points, so centring is exact to within half a point.
        #expect(abs(frame.midX - screen.midX) <= 0.5)
        #expect(abs(frame.midY - screen.midY) <= 0.5)
    }

    @Test func tinyCaptureStillLeavesRoomForTheControls() {
        let frame = PreviewGeometry.frame(
            forPixelSize: CGSize(width: 80, height: 40), backingScale: 2,
            in: screen, margin: 80, minimumSize: minimum
        )
        #expect(frame.size == minimum)
    }

    @Test func tallNarrowCaptureFitsTheHeight() {
        let frame = PreviewGeometry.frame(
            forPixelSize: CGSize(width: 400, height: 6000), backingScale: 2,
            in: screen, margin: 80, minimumSize: minimum
        )
        #expect(frame.height == availableHeight)
        #expect(frame.width == minimum.width)
    }

    @Test func steppingWrapsAroundBothEnds() {
        #expect(PreviewGeometry.wrappedIndex(0, offset: -1, count: 5) == 4)
        #expect(PreviewGeometry.wrappedIndex(4, offset: 1, count: 5) == 0)
        #expect(PreviewGeometry.wrappedIndex(2, offset: 1, count: 5) == 3)
        #expect(PreviewGeometry.wrappedIndex(0, offset: 1, count: 0) == nil)
    }
}
