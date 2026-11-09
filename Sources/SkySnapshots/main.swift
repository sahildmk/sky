import AppKit
import SkyApp
import SkyCore

// Usage: SkySnapshots [screenshot-directory] <output-directory>
// Renders the shelf and preview to PNGs. Nothing is shown on screen.

let arguments = Array(CommandLine.arguments.dropFirst())
guard let outputPath = arguments.last else {
    FileHandle.standardError.write(Data("usage: SkySnapshots [screenshot-directory] <output-directory>\n".utf8))
    exit(2)
}
let directory = arguments.count >= 2
    ? URL(fileURLWithPath: arguments[0], isDirectory: true)
    : ScreenshotLocation.current()

MainActor.assumeIsolated {
    _ = NSApplication.shared
    do {
        let files = try Snapshots.render(screenshotsIn: directory, to: URL(fileURLWithPath: outputPath, isDirectory: true))
        files.forEach { print($0.path) }
    } catch {
        FileHandle.standardError.write(Data("\(error)\n".utf8))
        exit(1)
    }
}
