import CoreGraphics
import Foundation
import FoundationModels
import Vision

@Generable
private struct NameSuggestion {
    @Guide(description: "A short description of the screenshot for its file name: 2 to 6 words, no file extension, no date, and not the word 'screenshot'.")
    var name: String
}

/// Suggests a file name for a screenshot from what it shows, using the
/// on-device Apple Intelligence model. Nothing leaves the Mac.
///
/// The model is given the image and the text Vision reads from it: the image
/// says what kind of screen it is, and the text supplies the specific words
/// (a page title, a person, an amount) the model would otherwise misread.
public actor ScreenshotNamer {
    /// Characters of recognised text passed to the model, so a dense screen
    /// can't fill its context.
    static let maxTextLength = 1500

    private static let instructions = """
        You name screenshot files. Look at what the screenshot shows (the app, \
        the page, the main subject or task) and give a short, specific file name \
        a person would recognise later.
        """

    public init() {}

    /// Whether this Mac can name screenshots: Apple Intelligence is on, its
    /// model is downloaded, and the model accepts images.
    public nonisolated static var isAvailable: Bool {
        let model = SystemLanguageModel.default
        return model.isAvailable && model.capabilities.contains(.vision)
    }

    /// Loads the language model and the text recognizer, so the first
    /// screenshot is named as quickly as later ones.
    public func prewarm() async {
        LanguageModelSession(model: .default, instructions: Self.instructions).prewarm()
        if let blank = Self.blankImage() {
            _ = try? await RecognizeTextRequest().perform(on: blank)
        }
    }

    /// A lowercase, hyphenated description of the screenshot at `url`, or nil
    /// when the model gave nothing usable. Throws when the model can't run or
    /// declines the image.
    public func suggestedSlug(for url: URL) async throws -> String? {
        let text = (try? await visibleText(in: url)) ?? ""
        let session = LanguageModelSession(model: .default, instructions: Self.instructions)
        let response = try await session.respond(
            generating: NameSuggestion.self,
            options: GenerationOptions(samplingMode: .greedy)
        ) {
            if text.isEmpty {
                "Name this screenshot."
            } else {
                "Name this screenshot. Its visible text, for reference:\n\(text)"
            }
            Attachment(imageURL: url)
        }
        return ScreenshotNaming.slug(from: response.content.name)
    }

    private func visibleText(in url: URL) async throws -> String {
        let observations = try await RecognizeTextRequest().perform(on: url)
        let lines = observations.compactMap { $0.topCandidates(1).first?.string }
        return String(lines.joined(separator: "\n").prefix(Self.maxTextLength))
    }

    private static func blankImage() -> CGImage? {
        let context = CGContext(
            data: nil, width: 64, height: 16, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue
        )
        context?.setFillColor(gray: 1, alpha: 1)
        context?.fill(CGRect(x: 0, y: 0, width: 64, height: 16))
        return context?.makeImage()
    }
}
