#if os(macOS)
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
    @FocusState private var isKeyboardFocused: Bool
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
                PlayerVideoSurface(viewModel: viewModel)
                    .ignoresSafeArea()

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
        // Hide the pointer along with the transport, so a playing movie is
        // nothing but picture.
        .pointerVisibility(shouldShowControls ? .visible : .hidden)
        .focusable()
        .focusEffectDisabled()
        .focused($isKeyboardFocused)
        .onKeyPress(phases: .down) { press in handleKeyPress(press) }
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
        .onAppear {
            isKeyboardFocused = true
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

    /// Transport keyboard shortcuts, matching the conventions Mac video
    /// players share. Returning `.ignored` lets anything unrecognised carry on
    /// to the responder chain — menu shortcuts still work.
    private func handleKeyPress(_ press: KeyPress) -> KeyPress.Result {
        let modifiers = press.modifiers.intersection([.command, .control, .shift, .option])

        switch press.key {
        case .space:
            viewModel.togglePlayPause()
        case .leftArrow:
            modifiers.contains(.command)
                ? viewModel.seekToAdjacentChapter(forward: false)
                : viewModel.skipBackward(15)
        case .rightArrow:
            modifiers.contains(.command)
                ? viewModel.seekToAdjacentChapter(forward: true)
                : viewModel.skipForward(15)
        case .escape:
            // Unwind one layer at a time, the way Mac apps do: close the
            // options popover, then leave fullscreen, and only close the
            // player once there is nothing left to back out of.
            if isOptionsPresented {
                isOptionsPresented = false
            } else if windowChrome?.exitFullScreenIfNeeded() != true {
                close()
            }
        default:
            return handleCharacterPress(press.characters, modifiers: modifiers)
        }
        return .handled
    }

    private func handleCharacterPress(
        _ characters: String,
        modifiers: EventModifiers
    ) -> KeyPress.Result {
        let isControlCommand = modifiers.contains(.control) && modifiers.contains(.command)

        switch characters.lowercased() {
        // ⌃⌘F is the system fullscreen shortcut; bare F is the convention
        // every Mac video player also honors.
        case "f" where isControlCommand || modifiers.isEmpty:
            windowChrome?.toggleFullScreen()
        case "a" where isControlCommand:
            viewModel.cycleAudioTrack()
        case "s" where isControlCommand:
            viewModel.cycleSubtitleTrack()
        case "g" where isControlCommand:
            viewModel.toggleSubtitles()
        case "s" where modifiers.contains(.command):
            selectedOptionsTab = .audio
            isOptionsPresented.toggle()
            viewModel.revealControls()
        case "[" where modifiers.contains(.shift) && modifiers.contains(.command):
            viewModel.setPlaybackSpeed(1.0)
        case "[" where modifiers.contains(.shift):
            viewModel.setPlaybackSpeed(nextSpeed(offset: -1))
        case "]" where modifiers.contains(.shift):
            viewModel.setPlaybackSpeed(nextSpeed(offset: 1))
        default:
            return .ignored
        }
        return .handled
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
