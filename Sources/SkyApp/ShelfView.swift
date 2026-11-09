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
                let isHovered = state.hoveredPath == record.path
                ScreenshotCard(
                    record: record,
                    thumbnail: store.thumbnails[record.path],
                    isExpanded: state.isExpanded,
                    isHovered: isHovered,
                    isCopied: state.copiedPath == record.path,
                    badgeCount: index == 0 && !state.isExpanded && store.items.count > 1 ? store.items.count : nil,
                    actions: actions
                )
                .frame(width: card.frame.width, height: card.frame.height)
                .scaleEffect(card.scale * (isHovered ? 1.035 : 1))
                .rotationEffect(.degrees(card.rotation))
                .opacity(card.isVisible ? 1 : 0)
                .position(x: card.frame.midX, y: card.frame.midY)
                .zIndex(isHovered ? 1 : card.zIndex)
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
        .frame(width: state.containerWidth, height: ShelfController.panelHeight, alignment: .topLeading)
        // Slides down from the menu bar and back up into it. With Reduce Motion it only fades.
        .offset(y: state.isPresented || Motion.reduceMotion ? 0 : -(layout.contentBottom + 40))
        .opacity(state.isPresented ? 1 : 0)
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
