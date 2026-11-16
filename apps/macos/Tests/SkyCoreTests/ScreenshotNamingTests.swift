import Foundation
import Testing
@testable import SkyCore

@Suite struct ScreenshotNamingTests {
    @Test func turnsASuggestionIntoLowercaseKebabCase() {
        #expect(ScreenshotNaming.slug(from: "Ana Owes You $35") == "ana-owes-you-35")
    }

    @Test func collapsesPunctuationAndWhitespaceIntoSingleHyphens() {
        #expect(ScreenshotNaming.slug(from: "  Q3/Q4 Plan: Draft\n\t(v2) ") == "q3-q4-plan-draft-v2")
    }

    @Test func removesAccents() {
        #expect(ScreenshotNaming.slug(from: "Café Menü Résumé") == "cafe-menu-resume")
    }

    @Test func dropsAnImageExtensionTheModelAdded() {
        #expect(ScreenshotNaming.slug(from: "Add Expense Form.png") == "add-expense-form")
        #expect(ScreenshotNaming.slug(from: "Release Notes v2.1") == "release-notes-v2-1")
    }

    @Test func givesNothingWithoutLettersOrDigits() {
        #expect(ScreenshotNaming.slug(from: "") == nil)
        #expect(ScreenshotNaming.slug(from: " ./: -- ") == nil)
    }

    @Test func shortensALongSuggestionAtAWholeWord() throws {
        let long = Array(repeating: "Dashboard", count: 20).joined(separator: " ")
        let slug = try #require(ScreenshotNaming.slug(from: long))
        #expect(slug.count <= ScreenshotNaming.maxSlugLength)
        #expect(slug.hasSuffix("dashboard"))
        #expect(!slug.hasSuffix("-"))
    }

    @Test func endsTheNameWithTheCaptureDateAndTime() throws {
        let utc = try #require(TimeZone(identifier: "UTC"))
        // 2026-11-15 21:11:41 UTC
        let capturedAt = Date(timeIntervalSince1970: 1_794_777_101)
        #expect(ScreenshotNaming.fileStem(slug: "add-expense-form", capturedAt: capturedAt, timeZone: utc)
            == "add-expense-form-2026-11-15-21-11-41")
    }

    @Test func fallsBackToScreenshotWithoutASlug() throws {
        let utc = try #require(TimeZone(identifier: "UTC"))
        let capturedAt = Date(timeIntervalSince1970: 1_794_777_101)
        #expect(ScreenshotNaming.fileStem(slug: nil, capturedAt: capturedAt, timeZone: utc)
            == "screenshot-2026-11-15-21-11-41")
    }

    @Test func usesThePlainNameWhenItIsFree() {
        let directory = URL(fileURLWithPath: "/shots", isDirectory: true)
        let url = ScreenshotNaming.destination(stem: "login-page", pathExtension: "png", in: directory) { _ in false }
        #expect(url.path == "/shots/login-page.png")
    }

    @Test func numbersTheNameWhenItIsTaken() {
        let directory = URL(fileURLWithPath: "/shots", isDirectory: true)
        let taken: Set<String> = ["/shots/login-page.png", "/shots/login-page-2.png"]
        let url = ScreenshotNaming.destination(stem: "login-page", pathExtension: "png", in: directory) {
            taken.contains($0.path)
        }
        #expect(url.path == "/shots/login-page-3.png")
    }
}
