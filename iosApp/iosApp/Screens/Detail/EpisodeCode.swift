import Foundation

/// Season/episode shorthand — "S2 · E4".
///
/// Nine call sites built this string by hand and had drifted into four
/// separators between them ("S2 · E4", "S2 E4", "S02E04", "S2:E4"), so the
/// same fact read differently depending on which screen you were looking at.
/// One type owns the nil handling and the renderings; a caller picks a style
/// rather than a separator, and a new one is a case here instead of a tenth
/// hand-rolled interpolation.
enum EpisodeCode {
    enum Style {
        /// Card and row badges. The interpunct survives being overlaid on
        /// artwork where a bare space reads as two unrelated tokens.
        case badge
        /// Dense captions that already sit in a separated metadata line and
        /// don't need a second separator inside the token.
        case compact
        /// Fixed-width list rows, where zero padding keeps the numbers in a
        /// column: "S02E04".
        case padded
        /// Player titles, where the colon reads as "within".
        case player
    }

    /// `nil` when either number is missing — a half-known code is worse than
    /// none, and every caller wants to drop the segment in that case.
    static func format(season: Int?, episode: Int?, style: Style = .badge) -> String? {
        guard let season, let episode else { return nil }
        return format(season: season, episode: episode, style: style)
    }

    static func format(season: Int, episode: Int, style: Style = .badge) -> String {
        switch style {
        case .badge: "S\(season) · E\(episode)"
        case .compact: "S\(season) E\(episode)"
        case .padded: String(format: "S%02dE%02d", season, episode)
        case .player: "S\(season):E\(episode)"
        }
    }
}
