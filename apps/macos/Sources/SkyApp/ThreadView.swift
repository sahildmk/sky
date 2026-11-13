import SkyCore
import SwiftUI
import Textual

/// A thread's title, summary and messages, in a glass panel that grows with
/// its content and scrolls once it reaches the bottom of the screen.
struct ThreadView: View {
    @Bindable var state: ThreadPanelState
    let perform: (ThreadPanelCommand) -> Void
    /// Reports the height the content wants, so the window can fit it.
    let onHeightChange: (CGFloat) -> Void

    @State private var headerHeight: CGFloat = 0
    @State private var footerHeight: CGFloat = 0
    @State private var bodyHeight: CGFloat = 0

    private let radius: CGFloat = 20
    private let padding: CGFloat = 18

    /// The scrolling part is as tall as its content, up to whatever is left
    /// of the panel's maximum height once the header and footer are placed.
    private var scrollHeight: CGFloat {
        min(bodyHeight, max(state.maxHeight - headerHeight - footerHeight, 80))
    }

    var body: some View {
        ZStack(alignment: .top) {
            if let thread = state.thread {
                container(for: thread)
                    .padding(ThreadPanelController.shadowInset)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // Drops down from the card above it.
        .scaleEffect(state.isVisible ? 1 : 0.97, anchor: .top)
        .offset(y: state.isVisible ? 0 : -6)
        .opacity(state.isVisible ? 1 : 0)
    }

    private func container(for thread: SkyThread) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            header(for: thread)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { headerHeight = $0 }

            ScrollView {
                content(for: thread)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { bodyHeight = $0 }
            }
            .frame(height: scrollHeight)
            .scrollPosition($state.scrollPosition)
            .scrollBounceBehavior(.basedOnSize)
            .onScrollGeometryChange(for: CGPoint.self) { geometry in
                CGPoint(x: geometry.contentOffset.y, y: geometry.contentSize.height - geometry.containerSize.height)
            } action: { _, offsets in
                state.scrollOffset = offsets.x
                state.maxScrollOffset = offsets.y
            }

            footer(for: thread)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { footerHeight = $0 }
        }
        .frame(width: ThreadPanelController.width)
        .skyGlass(in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        .shadow(color: .black.opacity(0.22), radius: 18, y: 8)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { onHeightChange($0) }
    }

    private func header(for thread: SkyThread) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 5) {
                Text(thread.title)
                    .font(.system(size: 15, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    HStack(spacing: 6) {
                        if thread.isResolved {
                            Label("Resolved", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                        Text("Started \(ScreenshotCard.age(of: thread.createdAt, now: context.date))")
                        Text("·")
                        Text("Updated \(ScreenshotCard.age(of: thread.updatedAt, now: context.date))")
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            IconButton(symbol: "xmark", label: "Close", size: 24) { perform(.close) }
        }
        .padding([.horizontal, .top], padding)
        .padding(.bottom, 12)
    }

    private func content(for thread: SkyThread) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            if !thread.summary.isEmpty {
                StructuredText(markdown: thread.summary)
                    .font(.system(size: 13))
            }
            if let messages = state.messages {
                ForEach(messages) { message in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(message.createdAt, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute())
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.tertiary)
                        StructuredText(markdown: message.body)
                            .font(.system(size: 13))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            } else if let error = state.loadError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            } else {
                ProgressView().controlSize(.small)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, padding)
        .padding(.vertical, 4)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Markdown images can be absolute file paths, such as a screenshot.
        // Resolving them against the file system root makes them file URLs;
        // web addresses are already absolute and stay as they are.
        .textual.imageAttachmentLoader(.image(relativeTo: URL(filePath: "/")))
    }

    private func footer(for thread: SkyThread) -> some View {
        HStack(spacing: 14) {
            KeyHint(key: "esc", action: "Close")
            KeyHint(key: "↑ ↓", action: "Scroll")
            Spacer(minLength: 0)
            Button {
                perform(.toggleResolved)
            } label: {
                Label(
                    thread.isResolved ? "Reopen" : "Resolve",
                    systemImage: thread.isResolved ? "arrow.uturn.backward" : "checkmark"
                )
                .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.glass)
            .disabled(state.isUpdating)
            .help(thread.isResolved ? "Reopen  ⌘↩" : "Resolve  ⌘↩")
        }
        .padding(.horizontal, padding)
        .padding(.vertical, 12)
    }
}
