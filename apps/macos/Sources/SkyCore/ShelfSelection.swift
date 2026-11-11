/// Moving the keyboard selection along the shelf's row of cards.
public enum ShelfSelection {
    /// The card `offset` steps from `index`, staying within the first
    /// `visibleCount` cards. Selection stops at either end rather than
    /// wrapping, so holding an arrow key settles on the first or last card.
    /// With nothing selected yet, any move selects the first card.
    public static func moved(from index: Int?, by offset: Int, visibleCount: Int) -> Int? {
        guard visibleCount > 0 else { return nil }
        guard let index else { return 0 }
        return min(max(index + offset, 0), visibleCount - 1)
    }
}
