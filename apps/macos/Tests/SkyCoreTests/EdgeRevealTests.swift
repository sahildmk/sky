import CoreGraphics
import Foundation
import Testing
@testable import SkyCore

@Suite struct EdgeRevealTests {
    let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
    let start = Date(timeIntervalSinceReferenceDate: 1000)
    var topCentre: CGPoint { CGPoint(x: screen.midX, y: screen.maxY) }

    @Test func revealsAfterThePointerRestsAtTheTopEdge() {
        var reveal = EdgeReveal()
        #expect(reveal.update(pointer: topCentre, screen: screen, buttonHeld: false, now: start)
            == .waiting)
        #expect(reveal.update(pointer: topCentre, screen: screen, buttonHeld: false, now: start + reveal.dwell) == .reveal)
    }

    @Test func passingThroughQuicklyDoesNotReveal() {
        var reveal = EdgeReveal()
        _ = reveal.update(pointer: topCentre, screen: screen, buttonHeld: false, now: start)
        let below = CGPoint(x: screen.midX, y: screen.maxY - 40)
        #expect(reveal.update(pointer: below, screen: screen, buttonHeld: false, now: start + 0.1) == .idle)
        // Coming back starts the wait again rather than counting the earlier visit.
        #expect(reveal.update(pointer: topCentre, screen: screen, buttonHeld: false, now: start + 0.2)
            == .waiting)
    }

    @Test func ignoresTheTopEdgeAwayFromTheMiddle() {
        var reveal = EdgeReveal()
        let menus = CGPoint(x: 120, y: screen.maxY)
        let statusItems = CGPoint(x: screen.maxX - 120, y: screen.maxY)
        for point in [menus, statusItems] {
            #expect(reveal.update(pointer: point, screen: screen, buttonHeld: false, now: start) == .idle)
            #expect(reveal.update(pointer: point, screen: screen, buttonHeld: false, now: start + 5) == .idle)
        }
    }

    @Test func ignoresThePointerJustBelowTheEdge() {
        var reveal = EdgeReveal()
        let justBelow = CGPoint(x: screen.midX, y: screen.maxY - reveal.bandHeight - 1)
        #expect(reveal.update(pointer: justBelow, screen: screen, buttonHeld: false, now: start) == .idle)
    }

    @Test func doesNotRevealWhileDragging() {
        var reveal = EdgeReveal()
        #expect(reveal.update(pointer: topCentre, screen: screen, buttonHeld: true, now: start) == .idle)
        #expect(reveal.update(pointer: topCentre, screen: screen, buttonHeld: true, now: start + 1) == .idle)
        // Letting go while still at the edge starts the wait from then.
        #expect(reveal.update(pointer: topCentre, screen: screen, buttonHeld: false, now: start + 2)
            == .waiting)
    }

    @Test func revealsOncePerVisit() {
        var reveal = EdgeReveal()
        _ = reveal.update(pointer: topCentre, screen: screen, buttonHeld: false, now: start)
        #expect(reveal.update(pointer: topCentre, screen: screen, buttonHeld: false, now: start + 1) == .reveal)
        #expect(reveal.update(pointer: topCentre, screen: screen, buttonHeld: false, now: start + 2) == .idle)

        let away = CGPoint(x: screen.midX, y: screen.midY)
        _ = reveal.update(pointer: away, screen: screen, buttonHeld: false, now: start + 3)
        _ = reveal.update(pointer: topCentre, screen: screen, buttonHeld: false, now: start + 4)
        #expect(reveal.update(pointer: topCentre, screen: screen, buttonHeld: false, now: start + 5) == .reveal)
    }

    @Test func worksOnAPrimaryDisplayThatIsNotAtTheOrigin() {
        var reveal = EdgeReveal()
        let offset = CGRect(x: -1692, y: -932, width: 1692, height: 3008)
        let top = CGPoint(x: offset.midX, y: offset.maxY)
        _ = reveal.update(pointer: top, screen: offset, buttonHeld: false, now: start)
        #expect(reveal.update(pointer: top, screen: offset, buttonHeld: false, now: start + 1) == .reveal)
    }
}
