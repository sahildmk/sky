import CoreGraphics

/// Sizes the preview window and the screenshot inside it.
///
/// The window is one fixed box in the middle of the screen, the same size for
/// every screenshot, so stepping between screenshots never resizes it.
public enum PreviewGeometry {
    public struct Container: Equatable {
        public var aspectRatio: CGFloat = 16.0 / 9.0
        /// Share of the screen's width the box takes up.
        public var widthFraction: CGFloat = 0.62
        /// Upper limits, so the box stays a comfortable size on large displays.
        public var maxWidth: CGFloat = 1440
        public var maxHeightFraction: CGFloat = 0.72
        public var minWidth: CGFloat = 480

        public init() {}

        public static let standard = Container()
    }

    /// The preview's frame: a box of the container's shape, centred in `bounds`.
    public static func containerFrame(in bounds: CGRect, container c: Container = .standard) -> CGRect {
        var width = min(max(bounds.width * c.widthFraction, c.minWidth), c.maxWidth, bounds.width)
        var height = width / c.aspectRatio
        let maxHeight = bounds.height * c.maxHeightFraction
        if height > maxHeight {
            height = maxHeight
            width = height * c.aspectRatio
        }
        return CGRect(
            x: (bounds.midX - width / 2).rounded(),
            y: (bounds.midY - height / 2).rounded(),
            width: width.rounded(),
            height: height.rounded()
        )
    }

    /// The size to draw an image at inside `available`: scaled down to fit
    /// and keep its shape, and never enlarged past one image pixel per screen
    /// pixel, so small screenshots stay sharp.
    public static func imageSize(forPixelSize pixelSize: CGSize, backingScale: CGFloat, fittingIn available: CGSize) -> CGSize {
        let scale = max(backingScale, 1)
        let native = CGSize(width: max(pixelSize.width, 1) / scale, height: max(pixelSize.height, 1) / scale)
        let fit = min(1, available.width / native.width, available.height / native.height)
        return CGSize(width: (native.width * fit).rounded(), height: (native.height * fit).rounded())
    }

    /// The index `offset` steps from `index`, wrapping around at either end.
    public static func wrappedIndex(_ index: Int, offset: Int, count: Int) -> Int? {
        guard count > 0 else { return nil }
        return ((index + offset) % count + count) % count
    }
}
