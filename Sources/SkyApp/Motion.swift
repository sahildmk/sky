import AppKit
import SwiftUI

/// Every animation in Sky, in one place so the timing stays consistent.
///
/// Springs are critically damped (no overshoot) unless the motion is meant to
/// carry weight. Entrances and exits use a strong ease-out, never ease-in.
/// Exits are quicker than entrances. With Reduce Motion on, everything
/// becomes a short ease-out and the shelf fades instead of sliding.
@MainActor
enum Motion {
    static var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    /// The shelf sliding down from the menu bar after a capture.
    static var present: Animation { spring(response: 0.35) }

    /// The shelf leaving. Faster than it arrived.
    static var dismiss: Animation { easeOut(dismissDuration) }
    static let dismissDuration: Double = 0.22

    /// The deck fanning out under the pointer. A slight overshoot so the
    /// cards feel like they were spread by hand.
    static var expand: Animation { spring(response: 0.3, damping: 0.86) }

    /// The row gathering back into a deck.
    static var collapse: Animation { spring(response: 0.26) }

    /// Delay between successive cards as the deck fans out.
    static func fanOutDelay(forCardAt index: Int) -> Double {
        reduceMotion ? 0 : Double(min(index, 4)) * 0.025
    }

    /// A card lifting under the pointer, and controls fading in over it.
    static var hover: Animation { easeOut(0.15) }

    /// Cards closing a gap after one is removed.
    static var rearrange: Animation { spring(response: 0.3) }

    /// A new screenshot dropping onto the stack. It lands with a little weight.
    static var arrive: Animation { spring(response: 0.4, damping: 0.78) }

    /// The preview opening. Centred, so it scales from the middle.
    static var previewIn: Animation { spring(response: 0.25) }

    /// The preview closing from a click.
    static var previewOut: Animation { easeOut(previewOutDuration) }
    static let previewOutDuration: Double = 0.14

    /// A button going down under the pointer.
    static var press: Animation { easeOut(0.1) }

    /// cubic-bezier(0.23, 1, 0.32, 1): starts fast, so the response is immediate.
    private static func easeOut(_ duration: Double) -> Animation {
        .timingCurve(0.23, 1, 0.32, 1, duration: reduceMotion ? min(duration, 0.15) : duration)
    }

    private static func spring(response: Double, damping: Double = 1) -> Animation {
        reduceMotion ? easeOut(0.15) : .spring(response: response, dampingFraction: damping)
    }
}
