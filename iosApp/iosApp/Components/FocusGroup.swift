import SwiftUI

extension View {
    /// Groups this subtree so a directional focus move resolves to it as a
    /// unit rather than to whichever child is geometrically nearest — the
    /// difference between "down enters the episode rail" and "down lands on
    /// the card that happens to sit lowest".
    ///
    /// SwiftUI spells this `focusSection()`, which is available on tvOS and
    /// macOS and explicitly unavailable on iOS — where a finger, not a
    /// direction, chooses the target and grouping means nothing. This is the
    /// single place that difference is expressed; call sites just group.
    func focusGroup() -> some View {
        #if os(iOS)
        self
        #else
        focusSection()
        #endif
    }
}
