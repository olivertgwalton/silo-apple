import SwiftUI

/// Full-screen video player for iPhone and iPad.
///
/// One of three files declaring `PlayerView`, selected by target membership
/// rather than `#if` — tvOS compiles `tvOS/PlayerView.swift`, macOS compiles
/// `macOS/PlayerView.swift`. They share a name, an initializer, and the pieces
/// in `PlayerVideoSurface.swift`; the rest is this platform's own, since touch
/// gestures, a focus-driven remote, and a pointer are genuinely different
/// interaction models.
struct PlayerView: View {
    let contentId: String
    let preferredFileId: Int?
    let preferredAudioTrackIndex: Int?
    let preferredSubtitleTrackIndex: Int?
    /// `true` when the caller explicitly asked to restart from zero rather
    /// than honoring the server-side resume position. Forwarded to the
    /// session bridge so both direct-play and transcode paths align.
    let startFromBeginning: Bool
    let resumePositionOverride: Double?
    /// Set when the caller wants offline playback of a completed download.
    /// Routes the prepare through `OfflinePlaybackBuilder` (stored manifest
    /// + local media file, no server session) so playback works with no
    /// network and progress queues for the next `/sync/progress` flush.
    let offlineDownloadId: String?
    /// Optional poster/backdrop URLs the presenter already has on hand.
    /// When set, the now-playing widget skips its own catalog-item fetch
    /// for artwork. Nil falls back to the prior fetch-on-prepare path.
    let posterURLHint: String?
    let backdropURLHint: String?
    let onPlaybackStarted: (() -> Void)?

    @State private var viewModel = PlayerViewModel()
    @State private var didNotifyPlaybackStarted = false
    @Environment(\.dismiss) var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var orientationCoordinator = PlayerOrientationCoordinator.shared

    init(
        contentId: String,
        preferredFileId: Int? = nil,
        preferredAudioTrackIndex: Int? = nil,
        preferredSubtitleTrackIndex: Int? = nil,
        startFromBeginning: Bool = false,
        resumePositionOverride: Double? = nil,
        offlineDownloadId: String? = nil,
        posterURLHint: String? = nil,
        backdropURLHint: String? = nil,
        onPlaybackStarted: (() -> Void)? = nil
    ) {
        self.contentId = contentId
        self.preferredFileId = preferredFileId
        self.preferredAudioTrackIndex = preferredAudioTrackIndex
        self.preferredSubtitleTrackIndex = preferredSubtitleTrackIndex
        self.startFromBeginning = startFromBeginning
        self.resumePositionOverride = resumePositionOverride
        self.offlineDownloadId = offlineDownloadId
        self.posterURLHint = posterURLHint
        self.backdropURLHint = backdropURLHint
        self.onPlaybackStarted = onPlaybackStarted
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            if let error = viewModel.error {
                PlayerErrorView(
                    message: error,
                    onRetry: { viewModel.retry() },
                    onBack: { dismissPlayer() }
                )
            } else {
                if viewModel.showNextUpScreen {
                    PlayerNextUpScreen(
                        viewModel: viewModel,
                        onBack: {
                            if !viewModel.keepWatchingCurrentEpisode() {
                                dismissPlayer()
                            }
                        },
                        miniPlayer: { PlayerVideoSurface(viewModel: viewModel) }
                    )
                    .transition(.opacity)
                } else {
                    PlayerVideoSurface(viewModel: viewModel)
                        .ignoresSafeArea()

                    if viewModel.isLoading {
                        PlayerLoadingIndicator(scale: 1.3, size: 62)
                        // The full controls overlay (and its close button)
                        // only mounts once the decoder opens the file, so a
                        // standalone close control has to cover the
                        // load/buffer phase — otherwise the only way out of a
                        // stalled start is force-quitting the app.
                        loadingCloseButton
                    } else {
                        // Invisible gestures (tap-to-toggle, double-tap skip,
                        // hold-2×, edge swipes, pinch) live in a dedicated
                        // layer under the button overlay.
                        MobilePlayerGestureLayer(
                            viewModel: viewModel,
                            onDismiss: { dismissPlayer() }
                        )
                        MobilePlayerControls(
                            viewModel: viewModel,
                            orientationCoordinator: orientationCoordinator,
                            onDismiss: { dismissPlayer() }
                        )
                    }

                    if let notice = viewModel.activeNotice ?? viewModel.suspendedNotice {
                        PlayerNoticeOverlay(notice: notice)
                    }
                }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            viewModel.handleScenePhase(newPhase)
        }
        .onChange(of: viewModel.isPlaying) { _, isPlaying in
            guard isPlaying, !didNotifyPlaybackStarted else { return }
            didNotifyPlaybackStarted = true
            onPlaybackStarted?()
        }
        .onChange(of: viewModel.remoteDismissToken) { _, newValue in
            guard newValue != nil else { return }
            dismissPlayer()
        }
        .onAppear {
            orientationCoordinator.activatePlayer()
            viewModel.applyArtworkURLHints(posterURL: posterURLHint, backdropURL: backdropURLHint)
            viewModel.loadAndPlay(
                contentId: contentId,
                preferredFileId: preferredFileId,
                preferredAudioTrackIndex: preferredAudioTrackIndex,
                preferredSubtitleTrackIndex: preferredSubtitleTrackIndex,
                startFromBeginning: startFromBeginning,
                resumePositionOverride: resumePositionOverride,
                offlineDownloadId: offlineDownloadId
            )
        }
        .onDisappear {
            viewModel.cleanup()
            orientationCoordinator.deactivatePlayer()
        }
        .continuumStatusBarHidden()
        .navigationBarHidden(true)
        .preferredColorScheme(.dark)
    }

    private func dismissPlayer() {
        viewModel.cleanup()
        dismiss()
    }

    /// Close control shown while the player is still loading/buffering, in
    /// the same spot (and glass style) as the close button in
    /// `MobilePlayerControls`' top strip so the two read as one control.
    private var loadingCloseButton: some View {
        HStack {
            Button(action: { dismissPlayer() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .accessibilityLabel("Close Player")

            Spacer()
        }
        .padding(.horizontal)
        .padding(.top)
        .transition(.opacity)
    }
}
