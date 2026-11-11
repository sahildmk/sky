import AppKit
import SkyApp
import SkyCore

// Usage: SkySnapshots [screenshot-directory] <output-directory>
// Renders the shelf and preview to PNGs. Nothing appears in front of you:
// each view is drawn in a window behind the desktop wallpaper.

let arguments = Array(CommandLine.arguments.dropFirst())
guard let outputPath = arguments.last else {
    FileHandle.standardError.write(Data("usage: SkySnapshots [screenshot-directory] <output-directory>\n".utf8))
    exit(2)
}
let directory = arguments.count >= 2
    ? URL(fileURLWithPath: arguments[0], isDirectory: true)
    : ScreenshotLocation.current()
let output = URL(fileURLWithPath: outputPath, isDirectory: true)

MainActor.assumeIsolated {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    Task { @MainActor in
        do {
            let files = try await Snapshots.render(screenshotsIn: directory, to: output)
            files.forEach { print($0.path) }
            exit(0)
        } catch {
            FileHandle.standardError.write(Data("\(error)\n".utf8))
            exit(1)
        }
    }
    app.run()
}
