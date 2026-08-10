import Foundation

/// Shared display formatting for every episode presentation — the compact
/// rail, the expanded iPad rows, and the 10-foot tvOS cards. Keeping these
/// labels in one seam prevents the layouts from drifting as metadata rules
/// evolve.
enum EpisodeFormatting {
    static func title(for episode: EpisodeListItem) -> String {
        episode.title ?? "Episode \(episode.episodeNumber)"
    }

    static func cardNumberLabel(for episode: EpisodeListItem) -> String {
        "EPISODE \(episode.episodeNumber)"
    }

    static func compactNumberLabel(for episode: EpisodeListItem) -> String {
        EpisodeCode.format(
            season: episode.seasonNumber,
            episode: episode.episodeNumber,
            style: .padded
        )
    }

    static func metadataLine(for episode: EpisodeListItem) -> String? {
        var parts: [String] = []
        if let airDate = DetailDateFormatting.abbreviatedDate(episode.airDate) {
            parts.append(airDate)
        }
        if let runtime = PlayerTimeFormatter.formatRuntime(minutes: episode.runtime) {
            parts.append(runtime)
        }
        return parts.isEmpty ? nil : parts.joined(separator: "  ·  ")
    }

    static func progressFraction(for episode: EpisodeListItem) -> Double? {
        guard let userData = episode.userData,
              let position = userData.positionSeconds,
              let duration = userData.durationSeconds,
              duration > 0,
              position > 0,
              position < duration
        else { return nil }
        return position / duration
    }

    static func accessibilityDescription(
        for episode: EpisodeListItem,
        isCurrent: Bool
    ) -> String {
        episodeRailAccessibilityLabel(
            seasonNumber: episode.seasonNumber,
            episodeNumber: episode.episodeNumber,
            title: episode.title,
            metadata: metadataLine(for: episode),
            isCurrent: isCurrent,
            isPlayed: episode.userData?.played == true
        )
    }

}
