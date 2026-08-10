import SwiftUI

/// Presents the player over everything else.
///
/// Platform-swapped by target membership, not by `#if`: the macOS build
/// excludes this file and compiles `macOS/PlayerCover.swift`, which declares
/// the same modifier. Call sites stay identical on every platform — the same
/// arrangement `PlayerView`, `AVPlayerSurface`, and `PlayerSurface` already
/// use.
///
/// iOS and tvOS get a real `fullScreenCover`. macOS has no such modifier (it
/// is absent from AppKit's SwiftUI surface entirely, not merely deprecated),
/// so that build takes over the window instead.
extension View {
    func playerCover(
        presentation: Binding<AppRouter.PlayerPresentation?>,
        onPlaybackStarted: @escaping (AppRouter.PlayerPresentation) -> Void = { _ in }
    ) -> some View {
        fullScreenCover(item: presentation) { payload in
            PlayerView(
                contentId: payload.contentId,
                preferredFileId: payload.fileId,
                preferredAudioTrackIndex: payload.audioTrackIndex,
                preferredSubtitleTrackIndex: payload.subtitleTrackIndex,
                startFromBeginning: payload.startFromBeginning,
                resumePositionOverride: payload.resumePosition,
                offlineDownloadId: payload.offlineDownloadId,
                posterURLHint: payload.posterURL,
                backdropURLHint: payload.backdropURL,
                onPlaybackStarted: { onPlaybackStarted(payload) }
            )
        }
    }
}
