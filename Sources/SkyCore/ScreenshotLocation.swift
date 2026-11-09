import Foundation

/// Where macOS saves screenshots: the `location` set in the Screenshot app's
/// Options menu, or the Desktop when none is set.
public enum ScreenshotLocation {
    static let domain = "com.apple.screencapture" as CFString

    /// Resolves the saved `location` preference to a directory. Falls back to
    /// `~/Desktop` when the preference is missing or does not name a directory.
    public static func directory(
        preference: String?,
        home: URL,
        isDirectory: (URL) -> Bool = ScreenshotLocation.isExistingDirectory
    ) -> URL {
        let desktop = home.appendingPathComponent("Desktop", isDirectory: true)
        guard let preference, !preference.trimmingCharacters(in: .whitespaces).isEmpty else {
            return desktop
        }

        let expanded: String
        if preference == "~" {
            expanded = home.path
        } else if preference.hasPrefix("~/") {
            expanded = home.appendingPathComponent(String(preference.dropFirst(2))).path
        } else {
            expanded = preference
        }

        let candidate = URL(fileURLWithPath: expanded, isDirectory: true).standardizedFileURL
        return isDirectory(candidate) ? candidate : desktop
    }

    /// The directory macOS is saving screenshots to right now.
    public static func current() -> URL {
        CFPreferencesAppSynchronize(domain)
        let preference = CFPreferencesCopyAppValue("location" as CFString, domain) as? String
        return directory(preference: preference, home: FileManager.default.homeDirectoryForCurrentUser)
    }

    public static func isExistingDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }
}
