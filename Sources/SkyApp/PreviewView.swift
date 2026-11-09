import SkyCore
import SwiftUI

struct PreviewView: View {
    let state: PreviewState
    let perform: (PreviewCommand) -> Void

    private let containerRadius: CGFloat = 26
    private let imageRadius: CGFloat = 14
    private var showsControls: Bool { state.isPointerInside }

    var body: some View {
        ZStack {
            // The transparent margin around the container: clicking it closes the preview.
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { perform(.close) }

            if let record = state.record {
                container(for: record)
                    .padding(PreviewController.shadowInset)
            }
        }
        .scaleEffect(state.isVisible ? 1 : 0.96)
        .opacity(state.isVisible ? 1 : 0)
    }

    private func container(for record: ScreenshotRecord) -> some View {
        GeometryReader { proxy in
            let inset = PreviewController.imageInset
            let size = PreviewGeometry.imageSize(
                forPixelSize: CGSize(width: record.pixelWidth, height: record.pixelHeight),
                backingScale: state.backingScale,
                fittingIn: CGSize(width: proxy.size.width - 2 * inset, height: proxy.size.height - 2 * inset)
            )
            ZStack {
                if let image = state.image {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: size.width, height: size.height)
                        .clipShape(RoundedRectangle(cornerRadius: imageRadius, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: imageRadius, style: .continuous)
                                .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
                        }
                        .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
                        .onTapGesture(count: 2) { perform(.openInDefaultApp) }
                        .onDrag { NSItemProvider(contentsOf: record.url) ?? NSItemProvider() }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .skyGlass(in: RoundedRectangle(cornerRadius: containerRadius, style: .continuous))
        .overlay(alignment: .top) {
            if showsControls { header(for: record).transition(.opacity) }
        }
        .overlay(alignment: .bottom) {
            if showsControls {
                toolbar
                    .padding(.bottom, 22)
                    .transition(.opacity.combined(with: .offset(y: 8)))
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: containerRadius, style: .continuous))
        .onHover { inside in
            withAnimation(Motion.hover) { state.isPointerInside = inside }
        }
    }

    // Close sits top-left, where it is on every macOS window.
    private func header(for record: ScreenshotRecord) -> some View {
        HStack(alignment: .top) {
            IconButton(symbol: "xmark", label: "Close", size: 28, standalone: true) { perform(.close) }
            Spacer()
            TimelineView(.periodic(from: .now, by: 30)) { context in
                HStack(spacing: 6) {
                    Text(ScreenshotCard.age(of: record.createdAt, now: context.date))
                    if let position = state.position {
                        Text("·").foregroundStyle(.secondary)
                        Text(position).foregroundStyle(.secondary).monospacedDigit()
                    }
                }
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .skyGlass(in: Capsule())
            }
        }
        .padding(22)
    }

    private var toolbar: some View {
        HStack(spacing: 2) {
            IconButton(
                symbol: state.isCopied ? "checkmark" : "doc.on.doc",
                label: state.isCopied ? "Copied" : "Copy  ⌘C",
                size: 32
            ) { perform(.copy) }
            IconButton(symbol: "folder", label: "Show in Finder", size: 32) { perform(.revealInFinder) }
            IconButton(
                symbol: "arrow.up.forward.app",
                label: "Open in \(state.defaultAppName ?? "Default App")  ⌘O",
                size: 32
            ) { perform(.openInDefaultApp) }
            IconButton(symbol: "trash", label: "Move to Trash  ⌘⌫", size: 32) { perform(.moveToTrash) }
        }
        .padding(4)
        .skyGlass(in: Capsule(), interactive: true)
    }
}
