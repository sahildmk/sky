import CoreGraphics
import Foundation

/// Decides when the pointer resting against the top edge of the screen should
/// bring the shelf down, the way an auto-hiding Dock appears.
///
/// The trigger area is a band in the middle of the top edge, clear of the app
/// menus on the left and the status items on the right. The pointer has to
/// stay there for a moment, so passing through on the way to a menu does not
/// count, and nothing happens while a mouse button is held, so dragging a
/// window to the top does not count either. It fires once per visit: the
/// pointer has to leave the band before it can fire again.
///
/// Coordinates are global screen coordinates with the origin at the bottom
/// left, as `NSEvent.mouseLocation` reports them.
public struct EdgeReveal: Equatable {
    public enum Decision: Equatable {
        /// Nothing to do.
        case idle
        /// The pointer is in the band but has not stayed long enough yet.
        case waiting
        /// Bring the shelf down.
        case reveal
    }

    /// How close to the top edge the pointer must be, in points.
    public var bandHeight: CGFloat = 2
    /// Width of the band, centred on the screen, in points.
    public var bandWidth: CGFloat = 400
    /// How long the pointer must stay in the band.
    public var dwell: TimeInterval = 0.25

    private var enteredAt: Date?
    private var hasFired = false

    public init() {}

    public func band(on screen: CGRect) -> CGRect {
        CGRect(
            x: screen.midX - bandWidth / 2,
            y: screen.maxY - bandHeight,
            width: bandWidth,
            height: bandHeight
        )
    }

    public mutating func update(pointer: CGPoint, screen: CGRect, buttonHeld: Bool, now: Date) -> Decision {
        let band = band(on: screen)
        // The pointer can sit exactly on the top edge, which `contains` excludes.
        let inBand = pointer.x >= band.minX && pointer.x <= band.maxX
            && pointer.y >= band.minY && pointer.y <= band.maxY

        guard inBand else {
            enteredAt = nil
            hasFired = false
            return .idle
        }
        guard !buttonHeld else {
            enteredAt = nil
            return .idle
        }
        guard !hasFired else { return .idle }

        let entered = enteredAt ?? now
        enteredAt = entered
        if now.timeIntervalSince(entered) >= dwell {
            hasFired = true
            return .reveal
        }
        return .waiting
    }
}
