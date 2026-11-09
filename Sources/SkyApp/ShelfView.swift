import SkyCore
import SwiftUI

struct ShelfView: View {
    let store: ShelfStore
    let state: ShelfState
    let actions: ShelfActions

    var body: some View {
        let layout = ShelfLayout.make(
            aspectRatios: store.items.map(\.aspectRatio),
            containerWidth: state.containerWidth,
            expanded: state.isExpanded
        )

        ZStack(alignment: .topLeading) {
            if store.items.isEmpty {
                EmptyShelf()
                    .frame(width: layout.activeRect.width - 32, height: layout.activeRect.height - 32)
                    .position(x: layout.activeRect.midX, y: layout.activeRect.midY)
                    .transition(.opacity)
            }

            ForEach(Array(store.items.enumerated()), id: \.element.path) { index, record in
                let card = layout.cards[index]
                let isSelected = state.selectedPath == record.path
                ScreenshotCard(
                    record: record,
                    thumbnail: store.thumbnails[record.path],
                    isExpanded: state.isExpanded,
                    isSelected: isSelected,
                    showsFocusRing: state.isKeyboardDriven && isSelected,
                    isCopied: state.copiedPath == record.path,
                    badgeCount: index == 0 && !state.isExpanded && store.items.count > 1 ? store.items.count : nil,
                    actions: actions
                )
                .frame(width: card.frame.width, height: card.frame.height)
                .scaleEffect(card.scale * (isSelected ? 1.035 : 1))
                .rotationEffect(.degrees(card.rotation))
                .opacity(card.isVisible ? 1 : 0)
                .position(x: card.frame.midX, y: card.frame.midY)
                .zIndex(isSelected ? 1 : card.zIndex)
                // Cards fan out one after another, newest first, and gather back together at once.
                .animation(
                    state.isExpanded
                        ? Motion.expand.delay(Motion.fanOutDelay(forCardAt: index))
                        : Motion.collapse,
                    value: state.isExpanded
                )
                .transition(.asymmetric(
                    // Dropped onto the stack from just above it.
                    insertion: .scale(scale: 1.12).combined(with: .opacity).combined(with: .offset(y: -16)),
                    removal: .scale(scale: 0.9).combined(with: .opacity)
                ))
            }
        }
        .overlay(alignment: .topLeading) {
            if state.isKeyboardDriven, !store.items.isEmpty {
                KeyHints()
                    .fixedSize()
                    .position(x: state.containerWidth / 2, y: layout.contentBottom + 28)
            }
        }
        .frame(width: state.containerWidth, height: ShelfController.panelHeight, alignment: .topLeading)
        // Slides down from the menu bar and back up into it. With Reduce Motion it only fades.
        .offset(y: state.isPresented || Motion.reduceMotion ? 0 : -(layout.contentBottom + 40))
        .opacity(state.isPresented ? 1 : 0)
    }
}

/// The keys the shelf answers to, shown while it is driven from the keyboard.
private struct KeyHints: View {
    private let hints: [(key: String, action: String)] = [
        ("← →", "Select"),
        ("Space", "Preview"),
        ("↩", "Copy and close"),
        ("C", "Copy"),
        ("⌘⌫", "Trash"),
        ("esc", "Close"),
    ]

    var body: some View {
        HStack(spacing: 14) {
            ForEach(hints, id: \.key) { hint in
                HStack(spacing: 5) {
                    Text(hint.key)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 5)
                        .frame(minWidth: 18, minHeight: 16)
                        .background(.primary.opacity(0.1), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                    Text(hint.action)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .skyGlass(in: Capsule())
        .accessibilityElement(children: .combine)
    }
}

private struct EmptyShelf: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "camera.viewfinder")
                .foregroundStyle(.secondary)
            Text("No screenshots yet")
                .foregroundStyle(.primary)
            Text("⇧⌘3  ·  ⇧⌘4")
                .foregroundStyle(.secondary)
        }
        .font(.system(size: 12, weight: .medium))
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .skyGlass(in: Capsule())
    }
}
