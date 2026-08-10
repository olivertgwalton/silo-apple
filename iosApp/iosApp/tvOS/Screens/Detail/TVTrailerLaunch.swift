#if os(tvOS)
import UIKit

/// Deep-link bridge to the installed YouTube app — the only remote-trailer
/// playback path on tvOS, which has no in-app web view to fall back on (iOS
/// uses a `WKWebView` sheet, macOS the default browser; both live in
/// `TrailersSection`).
///
/// Plain (non-isolated) statics, matching `PlatformScreen` and
/// `TVFocusDebugOverlay`'s `UIApplication` accessors; every call site is a
/// view-body / `onAppear` closure on the main thread.
enum TVTrailerLaunch {
    /// Whether remote cards may be shown at all.
    ///
    /// `canOpenURL` needs `youtube` listed in the tvOS Info.plist's
    /// `LSApplicationQueriesSchemes` or it returns false regardless of what
    /// is installed. It is also always false on the simulator, which has no
    /// YouTube app — the rail then correctly degrades to local extras only.
    static func isYouTubeAppInstalled() -> Bool {
        guard let probe = URL(string: "youtube://") else { return false }
        return UIApplication.shared.canOpenURL(probe)
    }

    /// Hand a video off to the YouTube app. Only ever called for cards that
    /// exist, i.e. after ``isYouTubeAppInstalled()`` returned true.
    static func open(siteKey: String) {
        guard let url = TrailerRail.youtubeAppURL(siteKey: siteKey) else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
}
#endif
