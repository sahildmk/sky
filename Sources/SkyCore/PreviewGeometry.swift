import CoreGraphics

/// Sizes the preview window for a screenshot.
public enum PreviewGeometry {
    /// The frame to show an image in, centred in `bounds`.
    ///
    /// The image is shown at its native size (one image pixel per screen
    /// pixel) when that fits, and scaled down to fit within `bounds` inset by
    /// `margin` when it does not. It is never scaled up. The frame is at least
    /// `minimumSize`, so the controls always fit; a smaller image is centred
    /// inside it.
    public static func frame(
        forPixelSize pixelSize: CGSize,
        backingScale: CGFloat,
        in bounds: CGRect,
        margin: CGFloat,
        minimumSize: CGSize
    ) -> CGRect {
        let scale = max(backingScale, 1)
        let native = CGSize(
            width: max(pixelSize.width, 1) / scale,
            height: max(pixelSize.height, 1) / scale
        )
        let available = bounds.insetBy(dx: margin, dy: margin)
        let fit = min(1, available.width / native.width, available.height / native.height)

        let size = CGSize(
            width: min(max(native.width * fit, minimumSize.width), max(available.width, minimumSize.width)),
            height: min(max(native.height * fit, minimumSize.height), max(available.height, minimumSize.height))
        )
        return CGRect(
            x: (bounds.midX - size.width / 2).rounded(),
            y: (bounds.midY - size.height / 2).rounded(),
            width: size.width.rounded(),
            height: size.height.rounded()
        )
    }

    /// The index `offset` steps from `index`, wrapping around at either end.
    public static func wrappedIndex(_ index: Int, offset: Int, count: Int) -> Int? {
        guard count > 0 else { return nil }
        return ((index + offset) % count + count) % count
    }
}
