import SkyCore
import SwiftUI

struct ShelfView: View {
    let store: ShelfStore
    let threads: ThreadsStore
    let state: ShelfState
    let actions: ShelfActions

    var body: some View {
        let contents = ShelfContents(store: store, threads: threads)
        let layout = contents.layout(containerWidth: state.containerWidth, expanded: state.isExpanded)

        ZStack(alignment: .topLeading) {
            if contents.isEmpty {
                EmptyShelf()
                    .frame(width: layout.activeRect.width - 32, height: layout.activeRect.height - 32)
                    .position(x: layout.activeRect.midX, y: layout.activeRect.midY)
                    .transition(.opacity)
            }

            ForEach(Array(contents.items.enumerated()), id: \.element) { index, item in
                let card = layout.cards[index]
                let isSelected = state.selected == item
                Group {
                    switch item {
                    case .screenshot(let path):
                        if let record = contents.screenshot(path) {
                            ScreenshotCard(
                                record: record,
                                thumbnail: store.thumbnails[path],
                                isExpanded: state.isExpanded,
                                isSelected: isSelected,
                                showsFocusRing: state.isKeyboardDriven && isSelected,
                                isCopied: state.copiedPath == path,
                                badgeCount: state.isExpanded ? nil : contents.deckCount(at: index),
                                actions: actions
                            )
                        }
                    case .thread(let id):
                        if let thread = contents.thread(id) {
                            ThreadCard(
                                thread: thread,
                                isExpanded: state.isExpanded,
                                isSelected: isSelected,
                                showsFocusRing: state.isKeyboardDriven && isSelected,
                                badgeCount: state.isExpanded ? nil : contents.deckCount(at: index),
                                actions: actions
                            )
                        }
                    }
                }
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
            let showsServiceStatus = threads.availability == .unavailable && threads.hasEverConnected && state.isExpanded
            if (state.isKeyboardDriven && !contents.isEmpty) || showsServiceStatus {
                HStack(spacing: 8) {
                    if state.isKeyboardDriven, !contents.isEmpty {
                        KeyHints(forThread: { if case .thread = state.selected { true } else { false } }())
                    }
                    if showsServiceStatus { ServiceStatus() }
                }
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

/// Says that threads can't be updated, when the service has stopped answering.
private struct ServiceStatus: View {
    var body: some View {
        Label("Threads paused: the Sky service isn't running", systemImage: "bolt.horizontal.circle")
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .skyGlass(in: Capsule())
    }
}

/// The keys the shelf answers to, shown while it is driven from the keyboard.
private struct KeyHints: View {
    /// A thread is selected, so the screenshot keys don't apply.
    let forThread: Bool

    private var hints: [(key: String, action: String)] {
        forThread
            ? [("← →", "Select"), ("Space", "Open"), ("esc", "Close")]
            : [("← →", "Select"), ("Space", "Open"), ("↩", "Copy and close"), ("C", "Copy"), ("⌘⌫", "Trash"), ("esc", "Close")]
    }

    var body: some View {
        HStack(spacing: 14) {
            ForEach(hints, id: \.key) { hint in
                KeyHint(key: hint.key, action: hint.action)
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

/// A key and what it does, as in "esc Close".
struct KeyHint: View {
    let key: String
    let action: String

    var body: some View {
        HStack(spacing: 5) {
            Text(key)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .padding(.horizontal, 5)
                .frame(minWidth: 18, minHeight: 16)
                .background(.primary.opacity(0.1), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            Text(action)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
}
