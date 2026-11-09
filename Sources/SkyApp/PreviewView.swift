import SkyCore
import SwiftUI

struct PreviewView: View {
    let state: PreviewState
    let perform: (PreviewCommand) -> Void

    private let cornerRadius: CGFloat = 14
    private var showsControls: Bool { state.isPointerInside }

    var body: some View {
        ZStack {
            // The transparent margin around the image: clicking it closes the preview.
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { perform(.close) }

            if let record = state.record {
                card(for: record)
                    .padding(PreviewController.shadowInset)
            }
        }
        .scaleEffect(state.isVisible ? 1 : 0.94)
        .opacity(state.isVisible ? 1 : 0)
    }

    private func card(for record: ScreenshotRecord) -> some View {
        ZStack {
            Rectangle().fill(.regularMaterial)
            if let image = state.image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(.white.opacity(0.16), lineWidth: 0.5)
        }
        .overlay(alignment: .top) {
            if showsControls { header(for: record).transition(.opacity) }
        }
        .overlay(alignment: .bottom) {
            if showsControls {
                toolbar
                    .padding(.bottom, 12)
                    .transition(.opacity.combined(with: .offset(y: 8)))
            }
        }
        // The shadow comes from a backing shape so the controls above don't cast one.
        .background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.black)
                .shadow(color: .black.opacity(0.45), radius: 28, y: 14)
        }
        .contentShape(Rectangle())
        .onHover { inside in
            withAnimation(Motion.hover) { state.isPointerInside = inside }
        }
        .onTapGesture(count: 2) { perform(.openInDefaultApp) }
        .onDrag { NSItemProvider(contentsOf: record.url) ?? NSItemProvider() }
    }

    private func header(for record: ScreenshotRecord) -> some View {
        HStack(alignment: .top) {
            TimelineView(.periodic(from: .now, by: 30)) { context in
                HStack(spacing: 6) {
                    Text(ScreenshotCard.age(of: record.createdAt, now: context.date))
                    if let position = state.position {
                        Text("·").foregroundStyle(.secondary)
                        Text(position).foregroundStyle(.secondary).monospacedDigit()
                    }
                }
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(.ultraThinMaterial, in: Capsule())
            }
            Spacer()
            IconButton(symbol: "xmark", label: "Close", size: 24, filled: true) { perform(.close) }
        }
        .padding(10)
    }

    private var toolbar: some View {
        HStack(spacing: 2) {
            IconButton(
                symbol: state.isCopied ? "checkmark" : "doc.on.doc",
                label: state.isCopied ? "Copied" : "Copy  ⌘C",
                size: 30
            ) { perform(.copy) }
            IconButton(symbol: "folder", label: "Show in Finder", size: 30) { perform(.revealInFinder) }
            IconButton(
                symbol: "arrow.up.forward.app",
                label: "Open in \(state.defaultAppName ?? "Default App")  ⌘O",
                size: 30
            ) { perform(.openInDefaultApp) }
            IconButton(symbol: "trash", label: "Move to Trash  ⌘⌫", size: 30) { perform(.moveToTrash) }
        }
        .padding(4)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.15), lineWidth: 0.5))
    }
}
