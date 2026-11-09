import SkyCore
import SwiftUI

struct ScreenshotCard: View {
    let record: ScreenshotRecord
    let thumbnail: NSImage?
    let isExpanded: Bool
    let isHovered: Bool
    let isCopied: Bool
    /// Shown on the top card of the collapsed deck.
    let badgeCount: Int?
    let actions: ShelfActions

    private var cornerRadius: CGFloat { isExpanded ? 12 : 10 }
    private var showsControls: Bool { isExpanded && isHovered }

    var body: some View {
        GeometryReader { proxy in
            image
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(.white.opacity(isHovered ? 0.35 : 0.18), lineWidth: 0.5)
        }
        // Remove sits top-left, where macOS puts the close button on notifications.
        .overlay(alignment: .topLeading) {
            if showsControls {
                IconButton(symbol: "xmark", label: "Remove from shelf", size: 20, standalone: true) {
                    actions.removeFromShelf(record)
                }
                .padding(6)
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .overlay(alignment: .topTrailing) {
            if showsControls {
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    Text(Self.age(of: record.createdAt, now: context.date))
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .skyGlass(in: Capsule())
                        .padding(6)
                }
                .transition(.opacity)
            } else if let badgeCount {
                Text("\(badgeCount)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .frame(minWidth: 22, minHeight: 22)
                    // Solid rather than tinted glass: the shelf is never the active
                    // window, and macOS greys out glass tint in inactive windows.
                    .background(Color(nsColor: .controlAccentColor), in: Capsule())
                    .overlay(Capsule().strokeBorder(.white.opacity(0.5), lineWidth: 1))
                    .offset(x: 8, y: -8)
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
            }
        }
        .overlay(alignment: .bottom) {
            if showsControls {
                HStack(spacing: 2) {
                    IconButton(
                        symbol: isCopied ? "checkmark" : "doc.on.doc",
                        label: isCopied ? "Copied" : "Copy"
                    ) { actions.copy(record) }
                    IconButton(symbol: "folder", label: "Show in Finder") { actions.revealInFinder(record) }
                    IconButton(symbol: "trash", label: "Move to Trash") { actions.moveToTrash(record) }
                }
                .padding(3)
                .skyGlass(in: Capsule(), interactive: true)
                .padding(.bottom, 7)
                .transition(.opacity.combined(with: .offset(y: 6)))
            }
        }
        // The shadow comes from a backing shape so the controls above don't cast one.
        .background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.black)
                .shadow(
                    color: .black.opacity(isHovered ? 0.38 : 0.26),
                    radius: isHovered ? 16 : 8,
                    y: isHovered ? 9 : 4
                )
        }
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .onTapGesture { actions.open(record) }
        .onDrag { NSItemProvider(contentsOf: record.url) ?? NSItemProvider() }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Screenshot \(record.url.deletingPathExtension().lastPathComponent)")
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var image: some View {
        if let thumbnail {
            Image(nsImage: thumbnail)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fill)
        } else {
            Rectangle().fill(.regularMaterial)
        }
    }

    static func age(of date: Date, now: Date) -> String {
        let seconds = now.timeIntervalSince(date)
        if seconds < 60 { return "Just now" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: now)
    }
}
