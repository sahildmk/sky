import Foundation
import Testing
@testable import SkyCore

@Suite struct ScreenshotLocationTests {
    let home = URL(fileURLWithPath: "/Users/someone", isDirectory: true)
    let desktop = URL(fileURLWithPath: "/Users/someone/Desktop", isDirectory: true)

    @Test func defaultsToTheDesktopWhenNoLocationIsSet() {
        #expect(ScreenshotLocation.directory(preference: nil, home: home) { _ in true }.path == desktop.path)
        #expect(ScreenshotLocation.directory(preference: "  ", home: home) { _ in true }.path == desktop.path)
    }

    @Test func expandsAHomeRelativeLocation() {
        let resolved = ScreenshotLocation.directory(preference: "~/Pictures/Screenshots", home: home) { _ in true }
        #expect(resolved.path == "/Users/someone/Pictures/Screenshots")
    }

    @Test func usesAnAbsoluteLocationAsGiven() {
        let resolved = ScreenshotLocation.directory(preference: "/Volumes/Shots/", home: home) { _ in true }
        #expect(resolved.path == "/Volumes/Shots")
    }

    @Test func fallsBackToTheDesktopWhenTheLocationIsMissing() {
        let resolved = ScreenshotLocation.directory(preference: "/Volumes/Unplugged", home: home) { _ in false }
        #expect(resolved.path == desktop.path)
    }
}
