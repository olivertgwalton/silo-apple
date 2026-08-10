import SwiftUI

/// Full-screen video player for Apple TV.
///
/// One of three files declaring `PlayerView`, selected by target membership
/// rather than `#if` — iOS compiles `Screens/Player/PlayerView.swift`, macOS
/// compiles `macOS/PlayerView.swift`. They share a name, an initializer, and
/// the pieces in `PlayerVideoSurface.swift`; everything else is this
/// platform's own, because the Siri Remote's focus-and-press model has nothing
/// in common with touch or a pointer.
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
    let offlineDownloadId: String?
    /// Optional poster/backdrop URLs the presenter already has on hand.
    /// When set, the now-playing widget skips its own catalog-item fetch.
    let posterURLHint: String?
    let backdropURLHint: String?
    let onPlaybackStarted: (() -> Void)?

    @State private var viewModel = PlayerViewModel()
    @State private var didNotifyPlaybackStarted = false
    @Environment(\.dismiss) var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @State private var remoteIdentityNotice: RemotePlaybackIdentityManager.ActiveIdentity?
    @State private var isTimelinePreviewVisible = false
    @State private var timelineTimeDisplayMode: TVPlayerTimeDisplayMode = .elapsedRemaining
    @State private var timelineSelectionRequest: UUID?
    @State private var timelinePreviewHideTask: Task<Void, Never>?
    @State private var timelinePreviewContactCanToggle = false

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
                        PlayerLoadingIndicator(scale: 1.7, size: 86)
                    }

                    pressCaptureLayer

                    if !viewModel.isLoading && !viewModel.isHoldSeeking {
                        TVPlayerControls(
                            viewModel: viewModel,
                            showsTimelinePreview: isTimelinePreviewVisible,
                            timeDisplayMode: timelineTimeDisplayMode,
                            timelineSelectionRequest: timelineSelectionRequest,
                            onToggleTimeDisplayMode: {
                                withAnimation(.easeOut(duration: ContinuumTheme.fastDuration)) {
                                    timelineTimeDisplayMode.toggle()
                                }
                            },
                            onDismiss: { dismissPlayer() }
                        )
                    }

                    // Speed-indicator chip shown only while a seek session is
                    // active. The overlay/scrubber is suppressed during the
                    // session (so the capture view keeps focus), so this chip
                    // is the sole source of visual feedback until Select
                    // commits or Menu cancels.
                    if viewModel.isHoldSeeking {
                        HoldSeekIndicator(
                            rate: viewModel.holdSeekRate,
                            previewTime: viewModel.scrubPreviewTime,
                            duration: viewModel.duration
                        )
                        .transition(.opacity)
                        .allowsHitTesting(false)
                    }

                    if let identity = remoteIdentityNotice {
                        RemotePlaybackIdentityNotice(identity: identity)
                            .transition(.opacity)
                    } else if let notice = viewModel.activeNotice ?? viewModel.suspendedNotice {
                        PlayerNoticeOverlay(notice: notice)
                    }
                }
            }
        }
        // Physical Play/Pause on the Siri remote always toggles playback
        // and brings the transport bar back.
        .onPlayPauseCommand {
            if viewModel.showNextUpScreen {
                viewModel.playNextEpisodeNow()
            } else {
                viewModel.togglePlayPause()
            }
        }
        // Menu button: step seek-session → HUD → overlay → dismiss.
        // Matches the Infuse / Apple TV pattern. Runs at the shell level
        // so it fires even if focus has drifted — the HUD's own
        // `onExitCommand` handles the common case where focus is inside
        // it; this fallback keeps the user from getting stuck.
        .onExitCommand {
            if viewModel.showNextUpScreen {
                if !viewModel.keepWatchingCurrentEpisode() {
                    dismissPlayer()
                }
            } else if viewModel.isHoldSeeking {
                viewModel.cancelHoldSeek()
            } else if viewModel.isBackgroundSuspended {
                dismissPlayer()
            } else if viewModel.isLoading {
                dismissPlayer()
            } else if viewModel.isHUDPresented {
                viewModel.closeHUD()
            } else if !viewModel.isPlaying {
                // While paused, Menu exits the player instead of hiding the
                // controls over a frozen frame.
                dismissPlayer()
            } else if viewModel.showControls {
                viewModel.dismissControls()
            } else {
                dismissPlayer()
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
        .onChange(of: viewModel.showControls) { _, visible in
            if visible {
                hideTimelinePreview()
            } else {
                timelineTimeDisplayMode = .elapsedRemaining
            }
        }
        .onChange(of: viewModel.remoteDismissToken) { _, newValue in
            guard newValue != nil else { return }
            dismissPlayer()
        }
        .onAppear {
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
            TVControlReceiver.shared.registerPlayer(viewModel, contentId: contentId)
            withAnimation(.easeInOut(duration: 0.2)) {
                remoteIdentityNotice = RemotePlaybackIdentityManager.shared.activeIdentity
            }
        }
        .task(id: remoteIdentityNotice?.generationID) {
            guard remoteIdentityNotice != nil else { return }
            try? await Task.sleep(for: .seconds(6))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                remoteIdentityNotice = nil
            }
        }
        .onDisappear {
            timelinePreviewHideTask?.cancel()
            timelinePreviewHideTask = nil
            viewModel.cleanup()
            TVControlReceiver.shared.unregisterPlayer(viewModel)
            // Progress/watched state for this item (and its parent
            // season/series) was mutated server-side during playback.
            // Flag the detail cache so the next visit to any of those
            // pages shows corrected userData instead of pre-play values.
            let touchedContentIds = viewModel.contentIdsNeedingDetailRefresh
            if touchedContentIds.isEmpty {
                ItemDetailCache.shared.markStaleFamily(contentId: contentId)
            } else {
                for id in touchedContentIds {
                    ItemDetailCache.shared.markStaleFamily(contentId: id)
                }
            }
        }
        .continuumStatusBarHidden()
        .preferredColorScheme(.dark)
    }

    /// Focus sink with UIKit-backed press capture. Mounted whenever the
    /// transport overlay is hidden OR a seek session is active — in both cases
    /// it's the sole target for the Siri Remote.
    ///
    /// Two modes:
    ///   • Not in seek mode: Tap Left/Right = quick skip, Tap Down = open the
    ///     player menu, Tap Up = reveal the full transport HUD, Tap Select =
    ///     pause and enter the focused timeline, Hold Left/Right = enter seek
    ///     mode.
    ///   • In seek mode: Tap Left/Right = adjust rate along the signed ladder,
    ///     Tap Select = commit + exit, Menu = cancel + exit (handled in
    ///     `onExitCommand`). Taps against Up/Down are ignored; holds are no-ops.
    @ViewBuilder
    private var pressCaptureLayer: some View {
        if !viewModel.isLoading && (!viewModel.showIntroSkip || viewModel.isHoldSeeking) &&
            (!viewModel.showControls || viewModel.isHoldSeeking) {
            TVPressCaptureView(
                onArrowTap: { direction in
                    if viewModel.isHoldSeeking {
                        switch direction {
                        case .left:  viewModel.adjustHoldSeekRate(delta: -1)
                        case .right: viewModel.adjustHoldSeekRate(delta: +1)
                        case .up, .down: break
                        }
                    } else {
                        switch direction {
                        case .left:  viewModel.skipBackward()
                        case .right: viewModel.skipForward()
                        case .down:  viewModel.openSettingsHUD()
                        case .up:    viewModel.revealControls()
                        }
                    }
                },
                onArrowHoldBegin: { direction in
                    // Only Left / Right enter seek mode. Hold on Up / Down is
                    // ignored so it can't be accidentally triggered while
                    // skipping.
                    switch direction {
                    case .left:  viewModel.beginHoldSeek(forward: false)
                    case .right: viewModel.beginHoldSeek(forward: true)
                    case .up, .down: break
                    }
                },
                onDirectionalPressBegan: {
                    timelinePreviewContactCanToggle = false
                },
                onTouchSurfaceContactBegan: {
                    handleTimelinePreviewContactBegan()
                },
                onTouchSurfaceContactEnded: {
                    handleTimelinePreviewContactEnded()
                },
                onTouchSurfaceContactCancelled: {
                    handleTimelinePreviewContactCancelled()
                },
                onSelect: {
                    if viewModel.isHoldSeeking {
                        viewModel.commitHoldSeek()
                    } else if viewModel.isPlaying {
                        timelinePreviewContactCanToggle = false
                        hideTimelinePreview(immediately: true)
                        viewModel.pauseForTimelineSelection()
                        timelineSelectionRequest = UUID()
                    } else {
                        viewModel.revealControls()
                    }
                }
            )
            .ignoresSafeArea()
        }
    }

    private func dismissPlayer() {
        viewModel.cleanup()
        dismiss()
    }

    // MARK: - Timeline preview

    private func handleTimelinePreviewContactBegan() {
        guard viewModel.isPlaying,
              !viewModel.showControls,
              !viewModel.isHUDPresented,
              !viewModel.isHoldSeeking else { return }

        timelinePreviewHideTask?.cancel()
        timelinePreviewHideTask = nil
        timelinePreviewContactCanToggle = isTimelinePreviewVisible
        withAnimation(.easeOut(duration: ContinuumTheme.fastDuration)) {
            if !isTimelinePreviewVisible {
                isTimelinePreviewVisible = true
            }
        }
    }

    private func handleTimelinePreviewContactEnded() {
        guard isTimelinePreviewVisible else { return }
        if timelinePreviewContactCanToggle {
            withAnimation(.easeOut(duration: ContinuumTheme.fastDuration)) {
                timelineTimeDisplayMode.toggle()
            }
        }
        timelinePreviewContactCanToggle = false
        scheduleTimelinePreviewHide()
    }

    private func handleTimelinePreviewContactCancelled() {
        timelinePreviewContactCanToggle = false
        scheduleTimelinePreviewHide()
    }

    private func scheduleTimelinePreviewHide() {
        guard isTimelinePreviewVisible else { return }
        timelinePreviewHideTask?.cancel()
        timelinePreviewHideTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            hideTimelinePreview()
        }
    }

    private func hideTimelinePreview(immediately: Bool = false) {
        timelinePreviewHideTask?.cancel()
        timelinePreviewHideTask = nil
        timelinePreviewContactCanToggle = false
        guard isTimelinePreviewVisible else { return }
        if immediately {
            isTimelinePreviewVisible = false
        } else {
            withAnimation(.easeOut(duration: ContinuumTheme.fastDuration)) {
                isTimelinePreviewVisible = false
            }
            // A dismissed quick preview always starts fresh in duration mode
            // on the next light touch. The immediate Select-to-HUD handoff
            // intentionally preserves the current display mode instead.
            timelineTimeDisplayMode = .elapsedRemaining
        }
    }
}
