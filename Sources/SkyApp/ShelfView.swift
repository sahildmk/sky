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
                // Cards fan out one after another, newest first.
                .animation(
                    (state.isExpanded ? Motion.expand : Motion.collapse)
                        .delay(state.isExpanded ? Double(min(index, 8)) * 0.018 : 0),
                    value: state.isExpanded
                )
                .transition(.asymmetric(
                    insertion: .scale(scale: 1.25).combined(with: .opacity).combined(with: .offset(y: -24)),
                    removal: .scale(scale: 0.7).combined(with: .opacity)
                ))
            }
        }
        .animation(Motion.arrive, value: store.items.map(\.path))
        .frame(width: state.containerWidth, height: ShelfController.panelHeight, alignment: .topLeading)
        .offset(y: state.isPresented ? 0 : -(layout.contentBottom + 40))
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
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
    }
}
