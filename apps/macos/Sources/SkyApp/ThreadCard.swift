import SkyCore
import SwiftUI

/// A thread on the shelf: its title, the start of its summary, and how long
/// since it last changed.
struct ThreadCard: View {
    /// Width ÷ height. Every thread card is the same shape.
    static let aspectRatio: CGFloat = 5.0 / 3.0

    let thread: SkyThread
    let isExpanded: Bool
    /// Under the pointer, or chosen with the arrow keys.
    let isSelected: Bool
    /// Marks the selection when the shelf is driven from the keyboard.
    let showsFocusRing: Bool
    /// Shown on the top card of the collapsed deck.
    let badgeCount: Int?
    let actions: ShelfActions

    private var cornerRadius: CGFloat { isExpanded ? 12 : 10 }
    private var showsControls: Bool { isExpanded && isSelected }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(thread.title)
                .font(.system(size: isExpanded ? 12 : 11, weight: .semibold))
                .lineLimit(2)
            if isExpanded {
                Text(Self.inlineMarkdown(thread.summary))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            Spacer(minLength: 0)
            TimelineView(.periodic(from: .now, by: 30)) { context in
                Label(ScreenshotCard.age(of: thread.updatedAt, now: context.date), systemImage: "text.bubble")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .labelStyle(.titleAndIcon)
            }
        }
        .padding(isExpanded ? 11 : 9)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            Color(nsColor: .windowBackgroundColor),
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(.primary.opacity(isSelected ? 0.22 : 0.1), lineWidth: 0.5)
        }
        .overlay {
            if showsFocusRing {
                RoundedRectangle(cornerRadius: cornerRadius + 3, style: .continuous)
                    .strokeBorder(Color(nsColor: .keyboardFocusIndicatorColor), lineWidth: 3)
                    .padding(-3)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if showsControls {
                IconButton(symbol: "checkmark", label: "Resolve", size: 22, standalone: true) {
                    actions.resolve(thread)
                }
                .padding(6)
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .overlay(alignment: .topTrailing) {
            if let badgeCount, !isExpanded {
                Text("\(badgeCount)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .frame(minWidth: 22, minHeight: 22)
                    .background(Color(nsColor: .controlAccentColor), in: Capsule())
                    .overlay(Capsule().strokeBorder(.white.opacity(0.5), lineWidth: 1))
                    .offset(x: 8, y: -8)
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
            }
        }
        .shadow(
            color: .black.opacity(isSelected ? 0.38 : 0.26),
            radius: isSelected ? 16 : 8,
            y: isSelected ? 9 : 4
        )
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .onTapGesture { actions.open(thread) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Thread: \(thread.title)")
        .accessibilityAddTraits(.isButton)
    }

    /// Bold, italics, code and links in a summary; anything else shows as written.
    static func inlineMarkdown(_ text: String) -> AttributedString {
        (try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(text)
    }
}
