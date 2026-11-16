import Foundation

/// Builds the file names Sky gives new screenshots: a lowercase, hyphenated
/// description followed by the capture date and time, such as
/// `add-expense-form-2026-11-15-21-11-41.png`.
public enum ScreenshotNaming {
    /// Longest description kept, in characters, before the date and time.
    public static let maxSlugLength = 60

    /// The description used when there is no suggestion.
    public static let fallbackSlug = "screenshot"

    private static let imageExtensions: Set<String> = [
        "png", "jpg", "jpeg", "heic", "tif", "tiff", "gif", "bmp", "pdf",
    ]

    /// The suggestion in lowercase kebab case, or nil when it has no letters
    /// or digits.
    ///
    /// An image extension the suggestion ends with is dropped, accents are
    /// removed, and every run of anything other than a letter or digit becomes
    /// one hyphen. A long result is cut at the last whole word that fits.
    public static func slug(from suggestion: String) -> String? {
        var text = suggestion.trimmingCharacters(in: .whitespacesAndNewlines)
        if imageExtensions.contains((text as NSString).pathExtension.lowercased()) {
            text = (text as NSString).deletingPathExtension
        }
        let words = text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }

        var slug = ""
        for word in words {
            let next = slug.isEmpty ? word : "\(slug)-\(word)"
            if next.count > maxSlugLength {
                if slug.isEmpty { slug = String(word.prefix(maxSlugLength)) }
                break
            }
            slug = next
        }
        return slug.isEmpty ? nil : slug
    }

    /// The file name, without extension, for a screenshot captured at
    /// `capturedAt`: the slug, or `screenshot` without one, then the date and
    /// time in `timeZone`.
    public static func fileStem(slug: String?, capturedAt: Date, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        return "\(slug ?? fallbackSlug)-\(formatter.string(from: capturedAt))"
    }

    /// Where a file named `stem` with `pathExtension` goes in `directory`: the
    /// plain name if it is free, otherwise `stem-2`, `stem-3` and so on.
    public static func destination(
        stem: String,
        pathExtension: String,
        in directory: URL,
        isTaken: (URL) -> Bool
    ) -> URL {
        var number = 1
        while true {
            let name = number == 1 ? stem : "\(stem)-\(number)"
            let url = directory.appendingPathComponent(name).appendingPathExtension(pathExtension)
            if !isTaken(url) { return url }
            number += 1
        }
    }
}
