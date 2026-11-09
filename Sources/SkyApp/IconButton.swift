import SwiftUI

/// A round symbol button that brightens under the pointer.
struct IconButton: View {
    let symbol: String
    let label: String
    var size: CGFloat = 26
    /// Gives the button its own glass, for use on its own directly over an
    /// image. Leave it off for buttons inside a glass toolbar.
    var standalone = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.44, weight: .semibold))
                .contentTransition(.symbolEffect(.replace))
                .frame(width: size, height: size)
                .background {
                    Circle().fill(.primary.opacity(isHovered && !standalone ? 0.12 : 0))
                }
                .contentShape(Circle())
        }
        .buttonStyle(PressableStyle())
        .modifier(StandaloneGlass(isOn: standalone))
        .onHover { isHovered = $0 }
        .help(label)
        .accessibilityLabel(label)
    }
}

/// Shrinks a button slightly the moment it is pressed, so the press registers
/// before the click completes.
private struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(Motion.press, value: configuration.isPressed)
    }
}

private struct StandaloneGlass: ViewModifier {
    let isOn: Bool

    func body(content: Content) -> some View {
        if isOn {
            content.skyGlass(in: Circle(), interactive: true)
        } else {
            content
        }
    }
}
