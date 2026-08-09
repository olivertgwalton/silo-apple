#if os(macOS)
import AppKit
import SwiftUI

struct PlayerView: View {
    let contentId: String
    let preferredFileId: Int?
    let preferredAudioTrackIndex: Int?
    let preferredSubtitleTrackIndex: Int?
    let startFromBeginning: Bool
    let resumePositionOverride: Double?
    /// Set when the caller wants offline playback of a completed download.
    /// Routes the prepare through `OfflinePlaybackBuilder` (stored manifest
    /// + local media file, no server session) so playback works with no
    /// network.
    let offlineDownloadId: String?
    /// Poster/backdrop URLs the presenting screen already had loaded, so the
    /// now-playing widget skips a catalog fetch it doesn't need.
    let posterURLHint: String?
    let backdropURLHint: String?
    /// Supplied when the player is presented as a full-window cover, which
    /// owns the presentation state and cannot be torn down by `dismiss()`.
    /// Nil falls back to the environment dismissal (the debug sheet).
    let onClose: (() -> Void)?
    /// Fired once playback actually begins, so a presenter can install the
    /// destination it wants behind the player. Matches the shared signature.
    let onPlaybackStarted: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    /// Present when the player is covering the browsing window, absent when
    /// it is hosted some other way (e.g. the debug launch-argument sheet).
    @Environment(MacPlayerChrome.self) private var windowChrome: MacPlayerChrome?
    @State private var viewModel = PlayerViewModel()
    @State private var isOptionsPresented = false
    @State private var selectedOptionsTab: MacPlayerOptionsPanel.Tab = .audio
    @State private var lastHoverLocation: CGPoint?
    @State private var didNotifyPlaybackStarted = false

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
        onClose: (() -> Void)? = nil,
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
        self.onClose = onClose
        self.onPlaybackStarted = onPlaybackStarted
    }

    private func close() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let error = viewModel.error {
                errorView(error)
            } else {
                playerSurface

                // Sits above the video surface (an AppKit view, which would
                // otherwise win the hit test) and below the controls, so
                // double-click-to-fullscreen works on the picture without
                // stealing clicks from the transport buttons.
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        windowChrome?.toggleFullScreen()
                    }

                if viewModel.isLoading, viewModel.avPlayerBackend == nil {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.5)
                }

                if shouldShowControls {
                    MacPlayerControls(
                        viewModel: viewModel,
                        isOptionsPresented: $isOptionsPresented,
                        selectedOptionsTab: $selectedOptionsTab,
                        isFullScreen: windowChrome?.isFullScreen ?? false,
                        onToggleFullScreen: { windowChrome?.toggleFullScreen() },
                        onDismiss: { close() }
                    )
                    .transition(.opacity)
                }

                if isOptionsPresented {
                    MacPlayerOptionsPanel(
                        viewModel: viewModel,
                        selectedTab: $selectedOptionsTab,
                        onDismiss: { isOptionsPresented = false }
                    )
                    .padding(.trailing, 24)
                    .padding(.bottom, 116)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }

                if let notice = viewModel.activeNotice ?? viewModel.suspendedNotice {
                    PlayerNoticeOverlay(notice: notice)
                        .padding(.top, 72)
                }

                MacPlayerCommandCapture { command in
                    handleCommand(command)
                }
                .frame(width: 0, height: 0)
            }
        }
        // `onHover` alone only fires crossing the boundary, so once the
        // controls auto-hid with the pointer already inside, nothing brought
        // them back. Continuous hover reports every move; the view model
        // extends its auto-hide deadline rather than respawning a task, so
        // calling it at pointer-sample rate is cheap.
        .onContinuousHover { phase in
            guard case .active(let location) = phase, location != lastHoverLocation else { return }
            lastHoverLocation = location
            viewModel.revealControls()
        }
        // Hiding the toolbar is the SwiftUI half of clearing the title bar;
        // `MacPlayerChrome` handles the height it still reserves.
        .toolbarVisibility(.hidden, for: .windowToolbar)
        .onChange(of: shouldShowControls, initial: true) { _, visible in
            windowChrome?.setChromeVisible(visible)
        }
        .onChange(of: scenePhase) { _, newPhase in
            viewModel.handleScenePhase(newPhase)
        }
        .onChange(of: viewModel.hasTrackSelectionOptions) { _, hasOptions in
            if !hasOptions {
                isOptionsPresented = false
            }
        }
        .onChange(of: viewModel.isPlaying) { _, isPlaying in
            guard isPlaying, !didNotifyPlaybackStarted else { return }
            didNotifyPlaybackStarted = true
            onPlaybackStarted?()
        }
        .onChange(of: viewModel.remoteDismissToken) { _, newValue in
            guard newValue != nil else { return }
            close()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didEnterFullScreenNotification)) { _ in
            windowChrome?.refreshFullScreenState()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didExitFullScreenNotification)) { _ in
            windowChrome?.refreshFullScreenState()
        }
        .onAppear {
            viewModel.applyArtworkURLHints(
                posterURL: posterURLHint,
                backdropURL: backdropURLHint
            )
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
        }
        .preferredColorScheme(.dark)
        .animation(.easeOut(duration: 0.16), value: shouldShowControls)
        .animation(.easeOut(duration: 0.16), value: isOptionsPresented)
    }

    private var shouldShowControls: Bool {
        viewModel.showControls
            || !viewModel.isPlaying
            || viewModel.isLoading
            || viewModel.isBuffering
            || isOptionsPresented
    }

    @ViewBuilder
    private var playerSurface: some View {
        switch viewModel.activePlayer {
        case .none:
            Color.black.ignoresSafeArea()
        case .avPlayer(let backend):
            AVPlayerSurface(backend: backend)
                .ignoresSafeArea()
        case .coreMedia(let core):
            PlayerSurface(player: core)
                .ignoresSafeArea()
        }
    }

    private func handleCommand(_ command: MacPlayerCommand) {
        switch command {
        case .playPause:
            viewModel.togglePlayPause()
        case .skipBackward:
            viewModel.skipBackward(15)
        case .skipForward:
            viewModel.skipForward(15)
        case .previousChapter:
            viewModel.seekToAdjacentChapter(forward: false)
        case .nextChapter:
            viewModel.seekToAdjacentChapter(forward: true)
        case .cycleAudio:
            viewModel.cycleAudioTrack()
        case .cycleSubtitle:
            viewModel.cycleSubtitleTrack()
        case .toggleSubtitle:
            viewModel.toggleSubtitles()
        case .options:
            selectedOptionsTab = .audio
            isOptionsPresented.toggle()
            viewModel.revealControls()
        case .escape:
            // Unwind one layer at a time, the way Mac apps do: close the
            // options popover, then leave fullscreen, and only close the
            // window once there is nothing left to back out of.
            if isOptionsPresented {
                isOptionsPresented = false
            } else if windowChrome?.exitFullScreenIfNeeded() == true {
                break
            } else {
                close()
            }
        case .toggleFullScreen:
            windowChrome?.toggleFullScreen()
        case .speedDown:
            viewModel.setPlaybackSpeed(nextSpeed(offset: -1))
        case .speedUp:
            viewModel.setPlaybackSpeed(nextSpeed(offset: 1))
        case .normalSpeed:
            viewModel.setPlaybackSpeed(1.0)
        }
    }

    private func nextSpeed(offset: Int) -> Double {
        let speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
        let current = viewModel.settings.playbackSpeed
        let index = speeds.enumerated().min { lhs, rhs in
            abs(lhs.element - current) < abs(rhs.element - current)
        }?.offset ?? 2
        return speeds[max(0, min(speeds.count - 1, index + offset))]
    }

    @ViewBuilder
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color.continuumError)

            Text(error)
                .font(.continuumBody)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 520)

            HStack(spacing: 12) {
                Button("Retry") {
                    viewModel.retry()
                }
                .buttonStyle(.borderedProminent)

                Button("Close") {
                    close()
                }
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
#endif
