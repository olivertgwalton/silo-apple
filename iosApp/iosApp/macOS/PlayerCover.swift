#if os(macOS)
import AppKit
import SwiftUI

/// Presents the player over everything else.
///
/// Platform-swapped by target membership, not by `#if`: iOS and tvOS compile
/// `Screens/Player/PlayerCover.swift`, which declares the same modifier over a
/// real `fullScreenCover`. macOS has no such modifier — it is absent from
/// AppKit's SwiftUI surface entirely — so the player takes over the browsing
/// window instead, the way Infuse does, rather than opening a second window or
/// sitting in the split view's detail pane beside a sidebar.
extension View {
    func playerCover(
        presentation: Binding<AppRouter.PlayerPresentation?>,
        onPlaybackStarted: @escaping (AppRouter.PlayerPresentation) -> Void = { _ in }
    ) -> some View {
        modifier(PlayerCoverModifier(presentation: presentation, onPlaybackStarted: onPlaybackStarted))
    }
}

private struct PlayerCoverModifier: ViewModifier {
    @Binding var presentation: AppRouter.PlayerPresentation?
    let onPlaybackStarted: (AppRouter.PlayerPresentation) -> Void

    @State private var chrome = MacPlayerChrome()

    func body(content: Content) -> some View {
        ZStack {
            content

            if let presentation {
                PlayerView(
                    contentId: presentation.contentId,
                    preferredFileId: presentation.fileId,
                    preferredAudioTrackIndex: presentation.audioTrackIndex,
                    preferredSubtitleTrackIndex: presentation.subtitleTrackIndex,
                    startFromBeginning: presentation.startFromBeginning,
                    resumePositionOverride: presentation.resumePosition,
                    offlineDownloadId: presentation.offlineDownloadId,
                    posterURLHint: presentation.posterURL,
                    backdropURLHint: presentation.backdropURL,
                    onClose: { self.presentation = nil },
                    onPlaybackStarted: { onPlaybackStarted(presentation) }
                )
                // Re-key per presentation so starting a second item tears the
                // previous player down instead of reusing its view model.
                .id(presentation.id)
                .environment(chrome)
                .ignoresSafeArea()
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .background(MacWindowAccessor(chrome: chrome))
        .onChange(of: presentation != nil, initial: true) { _, isPresented in
            chrome.setPlayerCoverActive(isPresented)
        }
        .animation(.easeInOut(duration: 0.2), value: presentation?.id)
    }
}

/// The narrow set of window behaviors SwiftUI has no vocabulary for: the title
/// bar that would otherwise stripe the top of the video, native fullscreen,
/// and the traffic lights floating over the picture.
///
/// Everything expressible in SwiftUI — hover, taps, toolbar visibility — stays
/// in `PlayerView` where it belongs.
@MainActor
@Observable
final class MacPlayerChrome {
    private(set) var isFullScreen = false

    deinit {
        let center = NotificationCenter.default
        for observer in fullScreenObservers {
            center.removeObserver(observer)
        }
    }

    @ObservationIgnored private weak var window: NSWindow?
    @ObservationIgnored private var restoreState: RestoreState?
    @ObservationIgnored private var isCoverActive = false
    @ObservationIgnored private var fullScreenObservers: [NSObjectProtocol] = []

    /// The window chrome as it was before the player took over, so browsing
    /// gets its title bar back exactly as it left it.
    private struct RestoreState {
        let styleMask: NSWindow.StyleMask
        let titleVisibility: NSWindow.TitleVisibility
        let titlebarAppearsTransparent: Bool
        let backgroundColor: NSColor
    }

    func attach(to window: NSWindow?) {
        guard let window, window !== self.window else { return }
        self.window = window
        observeFullScreen(of: window)
        refreshFullScreenState()
        // A cover that went up before the window was reachable (deep-link
        // straight into playback) still needs its chrome applied.
        if isCoverActive {
            applyPlayerChrome()
        }
    }

    /// Toggles native macOS fullscreen — the same transition the green button
    /// and ⌃⌘F perform, so all three paths agree. Because the player covers
    /// the whole window, this genuinely fills the display instead of
    /// fullscreening a sidebar alongside the video.
    func toggleFullScreen() {
        window?.toggleFullScreen(nil)
    }

    /// Leaves fullscreen if the window is in it. Returns whether it did, so
    /// Escape can fall through to closing the player when it wasn't.
    @discardableResult
    func exitFullScreenIfNeeded() -> Bool {
        guard isFullScreen else { return false }
        window?.toggleFullScreen(nil)
        return true
    }

    private func refreshFullScreenState() {
        isFullScreen = window?.styleMask.contains(.fullScreen) ?? false
    }

    private func observeFullScreen(of window: NSWindow) {
        let center = NotificationCenter.default
        for observer in fullScreenObservers {
            center.removeObserver(observer)
        }
        fullScreenObservers = [
            NSWindow.didEnterFullScreenNotification,
            NSWindow.didExitFullScreenNotification
        ].map { name in
            center.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refreshFullScreenState() }
            }
        }
    }

    /// Strips the window down to bare picture while the player is up, and puts
    /// it back afterwards.
    func setPlayerCoverActive(_ isActive: Bool) {
        guard isCoverActive != isActive else { return }
        isCoverActive = isActive
        if isActive {
            applyPlayerChrome()
        } else {
            restoreBrowsingChrome()
        }
    }

    /// Follows the transport controls: the traffic lights fade out with them.
    /// The pointer is handled in the view via `.pointerVisibility`.
    func setChromeVisible(_ visible: Bool) {
        guard let window else { return }
        for type in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            window.standardWindowButton(type)?.animator().alphaValue = visible ? 1 : 0
        }
    }

    private func applyPlayerChrome() {
        guard let window, restoreState == nil else { return }
        restoreState = RestoreState(
            styleMask: window.styleMask,
            titleVisibility: window.titleVisibility,
            titlebarAppearsTransparent: window.titlebarAppearsTransparent,
            backgroundColor: window.backgroundColor
        )
        // SwiftUI hides the toolbar itself (see `PlayerView`), but a hidden
        // toolbar still reserves the title bar's height. Full-size content
        // view is what actually gets the picture edge to edge.
        window.styleMask.insert(.fullSizeContentView)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.backgroundColor = .black
    }

    private func restoreBrowsingChrome() {
        guard let window, let state = restoreState else {
            restoreState = nil
            return
        }
        restoreState = nil
        window.styleMask = state.styleMask
        window.titleVisibility = state.titleVisibility
        window.titlebarAppearsTransparent = state.titlebarAppearsTransparent
        window.backgroundColor = state.backgroundColor
        setChromeVisible(true)
    }
}

/// Bridges the hosting `NSWindow` to `MacPlayerChrome`. Zero-sized and
/// invisible; it exists only to reach `view.window`.
private struct MacWindowAccessor: NSViewRepresentable {
    let chrome: MacPlayerChrome

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async { [weak view] in
            chrome.attach(to: view?.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { [weak nsView] in
            chrome.attach(to: nsView?.window)
        }
    }
}
#endif
