import CoreGraphics
import Testing
@testable import SkyCore

@Suite struct PreviewGeometryTests {
    let laptop = CGRect(x: 0, y: 0, width: 1512, height: 945)
    let container = PreviewGeometry.Container.standard

    @Test func containerIsSixteenByNineAndCentred() {
        let frame = PreviewGeometry.containerFrame(in: laptop)
        #expect(abs(frame.width / frame.height - 16.0 / 9.0) < 0.01)
        #expect(abs(frame.midX - laptop.midX) <= 0.5)
        #expect(abs(frame.midY - laptop.midY) <= 0.5)
        #expect(laptop.contains(frame))
    }

    @Test func containerTakesAPortionOfTheScreenNotAllOfIt() {
        let frame = PreviewGeometry.containerFrame(in: laptop)
        #expect(abs(frame.width - (laptop.width * container.widthFraction).rounded()) <= 1)
        #expect(frame.height < laptop.height)
    }

    @Test func containerStaysAComfortableSizeOnLargeDisplays() {
        let studio = CGRect(x: 0, y: 0, width: 3008, height: 1662)
        let frame = PreviewGeometry.containerFrame(in: studio)
        #expect(frame.width == container.maxWidth)
    }

    @Test func containerShrinksToFitShortScreens() {
        let ultrawide = CGRect(x: 0, y: 0, width: 3440, height: 700)
        let frame = PreviewGeometry.containerFrame(in: ultrawide)
        #expect(frame.height <= (ultrawide.height * container.maxHeightFraction).rounded())
        #expect(abs(frame.width / frame.height - 16.0 / 9.0) < 0.01)
    }

    @Test func largeScreenshotIsScaledDownAndKeepsItsShape() {
        let size = PreviewGeometry.imageSize(
            forPixelSize: CGSize(width: 6016, height: 3384), backingScale: 2,
            fittingIn: CGSize(width: 900, height: 500)
        )
        #expect(size.width <= 900 && size.height <= 500)
        #expect(size.width == 900 || size.height == 500)
        #expect(abs(size.width / size.height - 6016.0 / 3384.0) < 0.01)
    }

    @Test func tallScreenshotFitsTheHeight() {
        let size = PreviewGeometry.imageSize(
            forPixelSize: CGSize(width: 800, height: 6000), backingScale: 2,
            fittingIn: CGSize(width: 900, height: 500)
        )
        #expect(size.height == 500)
        #expect(size.width < 100)
    }

    @Test func smallScreenshotIsNotEnlarged() {
        let size = PreviewGeometry.imageSize(
            forPixelSize: CGSize(width: 400, height: 200), backingScale: 2,
            fittingIn: CGSize(width: 900, height: 500)
        )
        #expect(size == CGSize(width: 200, height: 100))
    }

    @Test func steppingWrapsAroundBothEnds() {
        #expect(PreviewGeometry.wrappedIndex(0, offset: -1, count: 5) == 4)
        #expect(PreviewGeometry.wrappedIndex(4, offset: 1, count: 5) == 0)
        #expect(PreviewGeometry.wrappedIndex(2, offset: 1, count: 5) == 3)
        #expect(PreviewGeometry.wrappedIndex(0, offset: 1, count: 0) == nil)
    }
}
