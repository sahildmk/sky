import SwiftUI

extension View {
    /// Liquid Glass behind this view on macOS 26 and later, and a frosted
    /// material on earlier versions.
    ///
    /// - Parameter interactive: Makes the glass respond to presses, for controls.
    @ViewBuilder
    func skyGlass<S: Shape>(in shape: S, interactive: Bool = false) -> some View {
        if #available(macOS 26, *) {
            glassEffect(interactive ? Glass.regular.interactive() : Glass.regular, in: shape)
        } else {
            background(.ultraThinMaterial, in: shape)
                .overlay(shape.stroke(.white.opacity(0.15), lineWidth: 0.5))
        }
    }
}
