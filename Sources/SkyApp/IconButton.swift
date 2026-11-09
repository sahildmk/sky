import SwiftUI

/// A round, borderless symbol button that brightens under the pointer.
struct IconButton: View {
    let symbol: String
    let label: String
    var size: CGFloat = 26
    /// Gives the button its own frosted background, for use directly over an image.
    var filled = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.46, weight: .semibold))
                .contentTransition(.symbolEffect(.replace))
                .frame(width: size, height: size)
                .background {
                    Circle().fill(.white.opacity(isHovered ? 0.22 : 0))
                }
                .background(filled ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(.clear), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(label)
        .accessibilityLabel(label)
    }
}
