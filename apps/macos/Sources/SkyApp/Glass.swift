import SwiftUI

extension View {
    /// Liquid Glass behind this view.
    ///
    /// - Parameter interactive: Makes the glass respond to presses, for controls.
    func skyGlass<S: Shape>(in shape: S, interactive: Bool = false) -> some View {
        glassEffect(interactive ? Glass.regular.interactive() : Glass.regular, in: shape)
    }
}
