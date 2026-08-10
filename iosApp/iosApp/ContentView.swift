import SwiftUI
#if os(tvOS)
import UIKit
#endif

struct ContentView: View {
    @State private var router = AppRouter()
    @State private var serverRegistry = ServerRegistry.shared
    @State private var audioStore = AudioPlaybackStore()
    #if os(iOS)
    @State private var siloControl = SiloControlClient()
    #endif
    @State private var debugPlayContentId: String?
    @State private var didAttemptDebugAutoPlay = false
    @State private var didStartInitialStateCheck = false
    @State private var didFinishStartupSplash = false
    @State private var pendingInitialAuthState: AppRouter.AuthState?
    #if os(iOS) || os(tvOS)
    @State private var diagnosticsModel = DiagnosticsViewModel()
    #endif
    /// Deep link URL received before the auth state was ready. Drained
    /// on the next `.authenticated` transition so Top Shelf taps during
    /// a cold launch still route to the correct screen.
    @State private var pendingDeepLink: URL?
    /// Shared with every screen that renders cards. Hydrates lazily on
    /// the first .authenticated transition so cards stay visible during
    /// the brief window between sign-in and the overlay-config fetch.
    @StateObject private var overlayPrefs = OverlayPrefsStore.shared
    /// Server-synced navigation and card presentation for this client family.
    /// The store paints its offline cache first, then reconciles whenever the
    /// authenticated server/profile boundary changes.
    @State private var uiCustomization = UICustomizationPreferences.shared
    /// Used to retry overlay hydration on foreground transitions: if the
    /// initial fetch failed transiently, `hydrateIfNeeded()` will retry
    /// because the store left `hasHydrated == false`. Idempotent when
    /// the previous hydration succeeded.
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        authContent
        // A server change is a hard data boundary even when both servers map
        // to the same auth state. Re-key the routed subtree so profile, home,
        // library, focus, and modal state cannot survive from the old server.
        .id(serverRegistry.activeServerId)
        .environment(audioStore)
        #if os(iOS)
        .environment(siloControl)
        #endif
        .environmentObject(overlayPrefs)
        .preferredColorScheme(.dark)
        #if os(tvOS) && DEBUG
        .modifier(TVFocusDebugActivationModifier())
        #endif
        #if os(iOS)
        // Hold the pairing offer until the startup splash logo finishes so a
        // quickly-discovered TV doesn't pop the card over the animation.
        .companionPairingCard(
            enabled: didFinishStartupSplash && router.authState != .loading,
            authState: router.authState
        )
        #endif
        .modifier(DebugPlayerPresentationModifier(
            contentId: debugPlayContentId,
            isPresented: debugPlayerPresentation
        ))
        #if os(iOS) || os(tvOS)
        .modifier(DiagnosticsPromptPresentationModifier(
            model: diagnosticsModel,
            isEnabled: router.authState == .authenticated
        ))
        #endif
        .onReceive(NotificationCenter.default.publisher(for: .continuumDeepLink)) { notification in
            guard let url = notification.userInfo?["url"] as? URL else { return }
            #if os(iOS)
            ApplePushDeepLinkCoordinator.shared.clearPendingDeepLink(matching: url)
            #endif
            handleDeepLink(url)
        }
        .onAppear {
            #if os(tvOS)
            ExitSentinel.shared.appDidEnterForeground()
            #endif
            #if os(iOS)
            if let url = ApplePushDeepLinkCoordinator.shared.consumePendingDeepLink() {
                handleDeepLink(url)
            }
            #endif
        }
        .onReceive(NotificationCenter.default.publisher(for: .continuumSessionExpired)) { notification in
            guard let event = notification.object as? SessionExpiryEvent,
                  event.disposition == .persistentSessionCleared else { return }
            Task { @MainActor in
                // Delivery is asynchronous. Revalidate at the destructive
                // consumer so a same-server login that replaced this epoch
                // after posting cannot be routed back to login.
                guard await TokenStore.shared.shouldConsumeSessionExpiryEvent(event) else { return }
                audioStore.dismissFullPlayer()
                Task { await audioStore.player.close() }
                #if !os(tvOS)
                DownloadManager.shared.clearForSignOut()
                #endif
                router.expiredSession()
            }
        }
        #if os(iOS) || os(tvOS)
        .onReceive(NotificationCenter.default.publisher(for: .diagnosticsPendingReportCreated)) { _ in
            guard router.authState == .authenticated else { return }
            Task { await diagnosticsModel.handleForeground() }
        }
        #endif
        #if os(tvOS)
        .onReceive(NotificationCenter.default.publisher(for: .temporaryRemoteAuthExpired)) { notification in
            guard let event = notification.object as? SessionExpiryEvent,
                  event.disposition == .temporarySessionExpired else { return }
            Task { @MainActor in
                guard await TokenStore.shared.shouldConsumeSessionExpiryEvent(event) else { return }
                TVControlReceiver.shared.temporaryAuthExpired(expected: event)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
            ExitSentinel.shared.appWillTerminate()
        }
        #endif
        .task {
            // Debug: auto-play from launch argument -debugPlay <contentId>
            if let idx = CommandLine.arguments.firstIndex(of: "-debugPlay"),
               idx + 1 < CommandLine.arguments.count {
                let contentId = CommandLine.arguments[idx + 1]
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                debugPlayContentId = contentId
            }
        }
        #if DEBUG
        .task {
            await maybeDebugAutoLogin()
        }
        #endif
        .task(id: router.authState) {
            #if os(iOS) || os(tvOS)
            if router.authState != .authenticated {
                // The initial `.loading` state is not an identity boundary.
                // Keep the previous run's persisted breadcrumbs and playback
                // sessions intact until tvOS can capture any abnormal-exit
                // leftover after restored authentication resolves. Explicit
                // profile/server switches and sign-out own their destructive
                // cleanup paths separately.
                DiagnosticsCoordinator.authenticationStateBecameUnavailable()
                diagnosticsModel.reset()
            }
            #endif
            await maybeAutoPlayForDebug()
            if router.authState == .authenticated {
                if let pending = pendingDeepLink {
                    pendingDeepLink = nil
                    handleDeepLink(pending)
                }
                #if os(tvOS)
                await ExitSentinel.shared.captureLeftoverIfNeeded()
                #endif
                #if os(iOS) || os(tvOS)
                await diagnosticsModel.handleForeground()
                #endif
                await overlayPrefs.hydrateIfNeeded()
                // Hydrate AI capabilities on a cold relaunch into a restored
                // session — `selectProfile` only refreshes on a fresh sign-in,
                // so without this the metadata-language / on-view-translate
                // features stay hidden until a profile switch. Idempotent and
                // failure-tolerant, so double-calling with `selectProfile` is safe.
                await AICapabilities.shared.refresh()
                await RequestsFeatureStore.shared.refresh()
                await uiCustomization.refresh()
                #if os(iOS)
                await ApplePushRegistrationCoordinator.shared.prepareForAuthenticatedProfile()
                #endif
                #if !os(tvOS)
                await DownloadManager.shared.onAppActive()
                #endif
            }
        }
        .task(id: serverRegistry.activeServerId) {
            // ServerRegistry publishes the destination ID while its identity
            // transition lease is still held. Wait before reading or
            // retargeting any server-scoped state so this task cannot race the
            // final token commit. A superseded SwiftUI task is cancelled while
            // queued and must perform no work for the stale destination.
            guard await HTTPClient.shared.waitForRequestDispatchOpen() else { return }
            guard !Task.isCancelled else { return }
            #if os(iOS) || os(tvOS)
            diagnosticsModel.reset()
            #endif
            // `activeServerId` changes before ServerRegistry finishes its
            // async token retarget. Complete that boundary here before any
            // server-scoped overlay request, then clear and rehydrate even
            // when the destination remains `.authenticated`.
            await TokenStore.shared.switchActiveServer(
                serverId: serverRegistry.activeServerId ?? ""
            )
            overlayPrefs.clear()
            guard !Task.isCancelled else { return }
            Task { await AuthService.shared.refreshActiveServerName() }
            if router.authState == .authenticated {
                await uiCustomization.refresh()
                await overlayPrefs.hydrateIfNeeded()
                #if os(iOS) || os(tvOS)
                await diagnosticsModel.handleForeground()
                #endif
            }
        }
        .task(id: serverRegistry.activeProfileId) {
            #if os(iOS) || os(tvOS)
            diagnosticsModel.reset()
            #endif
            if router.authState == .authenticated {
                await uiCustomization.refresh()
                #if os(iOS) || os(tvOS)
                await diagnosticsModel.handleForeground()
                #endif
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            #if os(iOS) || os(tvOS)
            DiagnosticsCoordinator.recordBreadcrumb(
                category: .lifecycle,
                tag: "Scene",
                message: "scene phase changed",
                attrs: ["state": .string(Self.diagnosticsScenePhase(newPhase))]
            )
            #endif
            #if os(iOS)
            switch newPhase {
            case .active:
                siloControl.appDidBecomeActive()
            case .background:
                siloControl.appDidEnterBackground()
                // Keep series monitoring alive while backgrounded; only
                // worth a wake when the profile can download at all.
                if DownloadManager.shared.downloadsEnabled {
                    DownloadBackgroundRefresh.schedule()
                }
            default:
                break
            }
            #endif
            #if os(tvOS)
            switch newPhase {
            case .active:
                ExitSentinel.shared.appDidEnterForeground()
            case .background:
                ExitSentinel.shared.appDidEnterBackground()
            default:
                break
            }
            #endif

            // Cover the transient-failure case Codex flagged on #41:
            // initial overlay hydration runs once in the auth-state
            // task above. If that fetch transiently failed and the
            // user never opens overlay settings, the admin kill
            // switch and baseline stay stale until app restart.
            // Foreground transitions are a natural opportunity to
            // retry — `hydrateIfNeeded()` is a no-op when the
            // previous hydration succeeded, so this costs nothing in
            // the happy path.
            guard newPhase == .active,
                  router.authState == .authenticated else { return }
            #if os(tvOS)
            Task {
                await ExitSentinel.shared.captureLeftoverIfNeeded()
                await diagnosticsModel.handleForeground()
            }
            #elseif os(iOS)
            Task { await diagnosticsModel.handleForeground() }
            #endif
            Task { await overlayPrefs.hydrateIfNeeded() }
            // Same rationale as overlay hydration above: a transiently-failed
            // capability probe (or one skipped on a cold restore) gets a
            // natural retry on foreground. `refresh()` is idempotent, so the
            // happy path costs nothing.
            Task { await AICapabilities.shared.refresh() }
            Task { await RequestsFeatureStore.shared.refresh() }
            Task { await uiCustomization.refresh() }
            #if os(iOS)
            Task {
                await ApplePushRegistrationCoordinator.shared.prepareForAuthenticatedProfile()
                await ApplePushRegistrationCoordinator.shared.registerCurrentDeviceTokenIfPossible()
            }
            #endif
            #if os(tvOS)
            NotificationCenter.default.post(name: .homeSectionsShouldRefresh, object: nil)
            #endif
            #if !os(tvOS)
            Task { await DownloadManager.shared.onAppActive() }
            #endif
        }
    }

    #if os(iOS) || os(tvOS)
    private static func diagnosticsScenePhase(_ phase: ScenePhase) -> String {
        switch phase {
        case .active:
            return "active"
        case .inactive:
            return "inactive"
        case .background:
            return "background"
        @unknown default:
            return "unknown"
        }
    }
    #endif

    @ViewBuilder
    private var authContent: some View {
        switch router.authState {
        case .loading:
            StartupSplashView {
                didFinishStartupSplash = true
                finishInitialStartupIfReady()
            }
            .task {
                guard !didStartInitialStateCheck else { return }
                didStartInitialStateCheck = true
                await checkInitialState()
            }

        case .needsServerSetup:
            #if os(tvOS)
            TVServerSetupView(router: router)
            #else
            ServerSetupView(router: router)
            #endif

        case .needsLogin:
            NavigationStack(path: $router.path) {
                loginRoot
                    .navigationDestination(for: Route.self) { route in
                        destinationView(for: route)
                    }
            }

        case .needsProfile:
            NavigationStack(path: $router.path) {
                ProfileSelectionView(router: router)
                    .navigationDestination(for: Route.self) { route in
                        profileFlowDestination(for: route)
                    }
            }
            .environment(router)

        case .authenticated:
            #if os(tvOS)
            TVMainTabView(router: router)
            #else
            MainTabView(router: router)
            #endif
        }
    }

    private var debugPlayerPresentation: Binding<Bool> {
        Binding(
            get: { debugPlayContentId != nil },
            set: { if !$0 { debugPlayContentId = nil } }
        )
    }

    /// Resolves a `continuum://` URL to a navigation action. Supported
    /// shapes:
    /// - `continuum://item/{contentId}` — push the detail screen
    /// - `continuum://play/{contentId}` — push the player (resume from
    ///   last known position)
    /// - `continuum://downloads` — select the Downloads tab (local
    ///   download notifications)
    ///
    /// If the auth state isn't ready yet, the link is queued in
    /// `pendingDeepLink` and drained on the next `.authenticated`
    /// transition.
    private func handleDeepLink(_ url: URL) {
        guard let host = url.host else { return }

        if host == "downloads" {
            guard router.authState == .authenticated else {
                pendingDeepLink = url
                return
            }
            // The tab only exists while downloads are enabled — a stale
            // download notification tapped after a profile/capability
            // change must not select a tab that never renders.
            guard DownloadManager.shared.downloadsEnabled else { return }
            // Select the tab rather than pushing the route — a push stacks
            // a duplicate Downloads screen when that tab is already showing,
            // and hides the tab context from anywhere else.
            router.popToRoot()
            router.switchTab(to: .downloads)
            return
        }

        guard !url.pathComponents.isEmpty else { return }
        let contentId = url.pathComponents
            .dropFirst()
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let contentId, !contentId.isEmpty else { return }

        guard router.authState == .authenticated else {
            pendingDeepLink = url
            return
        }

        switch host {
        case "item":
            router.navigate(to: .itemDetail(contentId: contentId))
        case "play":
            Task { await routePlayDeepLink(contentId: contentId) }
        default:
            break
        }
    }

    @MainActor
    private func routePlayDeepLink(contentId: String) async {
        do {
            let detail = try await ContinuumAPI.shared.itemDetail(contentId: contentId)
            if detail.isAudiobook {
                audioStore.play(contentId: contentId)
                return
            }
        } catch {
            // Fall through to the existing video route when the type cannot be resolved.
        }

        #if os(tvOS)
        router.navigate(
            to: .player(
                contentId: contentId,
                startFromBeginning: false,
                resumePosition: nil
            )
        )
        #else
        // iOS and macOS resolve the player through `presentedPlayer`, not the
        // navigation stack; pushing the route here would land on the empty
        // exhaustiveness arm.
        router.presentPlayer(contentId: contentId)
        #endif
    }

    @ViewBuilder
    private var loginRoot: some View {
        #if os(tvOS)
        TVLoginView(router: router)
        #else
        LoginView(router: router)
        #endif
    }

    /// Determine the initial auth state with the smallest launch-time
    /// Keychain surface possible. The registry loads synchronously in `init`;
    /// TokenStore only needs to be retargeted to that active server before the
    /// first authenticated request lazily loads the full token cache.
    private func checkInitialState() async {
        let activeServerId = ServerRegistry.shared.activeServerId
        let hasStoredAccessToken: Bool
        if let activeServerId, !activeServerId.isEmpty {
            hasStoredAccessToken = await TokenStore.shared.hasAccessTokenForActiveServer(serverId: activeServerId)
        } else {
            hasStoredAccessToken = false
        }

        let api = AuthService.shared
        let targetState: AppRouter.AuthState
        if !api.hasServer {
            targetState = .needsServerSetup
        } else if !hasStoredAccessToken {
            targetState = .needsLogin
        } else if !api.hasProfile {
            targetState = .needsProfile
        } else {
            targetState = .authenticated
        }

        StartupContentPrefetcher.prefetchForInitialRoute(targetState)
        pendingInitialAuthState = targetState
        finishInitialStartupIfReady()

        #if DEBUG
        Task.detached(priority: .background) { await Self.logTopShelfDiagnostics() }
        #endif
    }

    private func finishInitialStartupIfReady() {
        guard didFinishStartupSplash, let targetState = pendingInitialAuthState else { return }
        pendingInitialAuthState = nil
        router.authState = targetState
    }

    #if DEBUG
    /// Dumps the state the Top Shelf extension relies on, plus the last
    /// breadcrumb the extension wrote. tvOS captures main-app stdout only,
    /// so this is how we inspect the extension's view of the world
    /// post-hoc. Run off the critical launch path.
    private static func logTopShelfDiagnostics() async {
        let suite = SharedStorage.suite
        let keychain = SharedKeychain()
        let hasServerURL = suite.string(forKey: SharedStorage.serverUrlKey) != nil
        let hasProfileID = suite.string(forKey: SharedStorage.profileIdKey) != nil
        let hasAccess = keychain.get(SharedStorage.mirroredAccessTokenAccount) != nil
        let hasProfile = keychain.get(SharedStorage.mirroredProfileTokenAccount) != nil
        let lastRun = suite.string(forKey: SharedStorage.topShelfLastRunAtKey) ?? "<never>"
        let hasLastStatus = suite.string(forKey: SharedStorage.topShelfLastStatusKey) != nil
        print("[TopShelfDiag] hasServerURL=\(hasServerURL) hasProfileID=\(hasProfileID) mirroredAccess=\(hasAccess) mirroredProfile=\(hasProfile)")
        print("[TopShelfDiag] lastRunAt=\(lastRun) hasLastStatus=\(hasLastStatus)")
    }
    #endif

    private func maybeAutoPlayForDebug() async {
        guard router.authState == .authenticated else { return }
        guard !didAttemptDebugAutoPlay else { return }

        if let searchQuery = debugPlaySearchQuery {
            didAttemptDebugAutoPlay = true

            do {
                debugPlayContentId = try await resolveDebugSearchContentId(query: searchQuery)
            } catch {
                print("[DebugPlaySearch] Failed to resolve '\(searchQuery)': \(error)")
            }
            return
        }

        guard CommandLine.arguments.contains("-debugPlayFirst") else { return }
        didAttemptDebugAutoPlay = true

        do {
            let sections = try await ContinuumAPI.shared.homeSections()
            guard let contentId = sections.sections.lazy
                .compactMap({ $0.items.first?.contentId })
                .first else {
                return
            }
            debugPlayContentId = contentId
        } catch {
            print("[DebugPlayFirst] Failed to fetch home sections: \(error)")
        }
    }

    private var debugPlaySearchQuery: String? {
        guard let index = CommandLine.arguments.firstIndex(of: "-debugPlaySearch"),
              index + 1 < CommandLine.arguments.count else {
            return nil
        }
        return CommandLine.arguments[index + 1].trimmingCharacters(in: .whitespacesAndNewlines)
    }

    #if DEBUG
    private func debugLaunchArgValue(_ name: String) -> String? {
        guard let index = CommandLine.arguments.firstIndex(of: name),
              index + 1 < CommandLine.arguments.count else {
            return nil
        }
        return CommandLine.arguments[index + 1].trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Debug: sign in from launch arguments
    /// `-debugServer <url> -debugUsername <user> -debugPassword <pass>`,
    /// selecting the primary (or only) PIN-less profile. Simulator-driven
    /// end-to-end runs use this to reach `.authenticated` without UI input.
    private func maybeDebugAutoLogin() async {
        guard router.authState != .authenticated,
              let server = debugLaunchArgValue("-debugServer"),
              let username = debugLaunchArgValue("-debugUsername"),
              let password = debugLaunchArgValue("-debugPassword") else {
            return
        }
        do {
            _ = try await AuthService.shared.checkServer(url: server)
            try await AuthService.shared.login(username: username, password: password)
            let profiles = try await StartupContentPrefetcher.fetchProfiles()
            guard let profile = profiles.first(where: \.isPrimary)
                ?? (profiles.count == 1 ? profiles.first : nil) else {
                print("[DebugAutoLogin] no selectable profile")
                return
            }
            try await AuthService.shared.selectProfile(profileId: profile.id)
            StartupContentPrefetcher.prefetchAuthenticatedContent()
            await PlayerSettings.shared.refreshFromServer()
            router.resetToHome()
            print("[DebugAutoLogin] signed in and selected profile")
        } catch {
            print("[DebugAutoLogin] failed: \(error)")
        }
    }
    #endif

    private func resolveDebugSearchContentId(query: String) async throws -> String {
        let response = try await ContinuumAPI.shared.catalog(query: [
            "source": "query",
            "q": query,
            "limit": "20",
            "offset": "0",
        ])

        let normalizedQuery = query.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        let preferredItem = response.items.first { item in
            item.type == "series" &&
            item.title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current) == normalizedQuery
        } ?? response.items.first { item in
            item.title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current) == normalizedQuery
        } ?? response.items.first

        guard let preferredItem else {
            throw DebugAutoPlayError.noSearchResults(query: query)
        }

        if preferredItem.type == "series" {
            let seasons = try await ContinuumAPI.shared.seasons(seriesId: preferredItem.contentId)
            guard let firstSeason = seasons.seasons.sorted(by: { $0.seasonNumber < $1.seasonNumber }).first else {
                throw DebugAutoPlayError.noPlayableEpisode(seriesTitle: preferredItem.title)
            }

            let episodes = try await ContinuumAPI.shared.episodes(
                seriesId: preferredItem.contentId,
                seasonNumber: firstSeason.seasonNumber
            )
            guard let firstEpisode = episodes.episodes
                .sorted(by: { $0.episodeNumber < $1.episodeNumber })
                .first else {
                throw DebugAutoPlayError.noPlayableEpisode(seriesTitle: preferredItem.title)
            }

            print(
                "[DebugPlaySearch] Resolved '\(query)' to series=\(preferredItem.title) " +
                "season=\(firstSeason.seasonNumber) episode=\(firstEpisode.episodeNumber) contentId=\(firstEpisode.contentId)"
            )
            return firstEpisode.contentId
        }

        print("[DebugPlaySearch] Resolved '\(query)' to \(preferredItem.type) contentId=\(preferredItem.contentId)")
        return preferredItem.contentId
    }

    @ViewBuilder
    private func destinationView(for route: Route) -> some View {
        switch route {
        case .serverNeedsSetup:
            #if os(tvOS)
            EmptyStateView(icon: "gearshape.2", title: "Finish setup in your browser", subtitle: nil)
                .continuumBackground()
            #else
            ServerNeedsSetupView(router: router)
            #endif
        case .signup:
            #if os(tvOS)
            EmptyStateView(icon: "person.badge.plus", title: "Sign up from a phone or the web", subtitle: nil)
                .continuumBackground()
            #else
            SignupView(router: router)
            #endif
        case .login:
            loginRoot
        case .serverSetup:
            #if os(tvOS)
            TVServerSetupView(router: router)
            #else
            ServerSetupView(router: router)
            #endif
        default:
            // Routes handled inside the authenticated tab view
            EmptyStateView(
                icon: "hammer.fill",
                title: "Coming Soon",
                subtitle: "This screen is under construction."
            )
            .continuumBackground()
        }
    }

    /// Destinations reachable from the profile-selection stack. The
    /// "Change Server" chip pushes `.serverList`; from there the user
    /// can swap active servers or dive into `.serverSetup` to add a
    /// new one. Auth-flow routes are included so an "Add Server" tap
    /// on tvOS — which stays inside this stack rather than flipping
    /// `authState` — still lands on a real view.
    @ViewBuilder
    private func profileFlowDestination(for route: Route) -> some View {
        switch route {
        case .serverList:
            ServerListView()
        case .serverSetup:
            #if os(tvOS)
            TVServerSetupView(router: router)
            #else
            ServerSetupView(router: router)
            #endif
        case .login:
            #if os(tvOS)
            TVLoginView(router: router)
            #else
            LoginView(router: router)
            #endif
        case .serverNeedsSetup:
            #if os(tvOS)
            EmptyStateView(icon: "gearshape.2", title: "Finish setup in your browser", subtitle: nil)
                .continuumBackground()
            #else
            ServerNeedsSetupView(router: router)
            #endif
        case .signup:
            #if os(tvOS)
            EmptyStateView(icon: "person.badge.plus", title: "Sign up from a phone or the web", subtitle: nil)
                .continuumBackground()
            #else
            SignupView(router: router)
            #endif
        default:
            EmptyStateView(icon: "questionmark.circle", title: "Unknown", subtitle: nil)
                .continuumBackground()
        }
    }
}

private struct DebugPlayerPresentationModifier: ViewModifier {
    let contentId: String?
    @Binding var isPresented: Bool

    func body(content: Content) -> some View {
        #if os(macOS)
        content.sheet(isPresented: $isPresented) {
            // Debug-only launch-argument path. A macOS sheet sizes to its
            // content and video reports none, so give it a window-shaped frame.
            player.frame(minWidth: 960, minHeight: 540)
        }
        #else
        content.fullScreenCover(isPresented: $isPresented) {
            player
        }
        #endif
    }

    @ViewBuilder
    private var player: some View {
        if let contentId {
            PlayerView(contentId: contentId)
        }
    }
}

private enum DebugAutoPlayError: LocalizedError {
    case noPlayableEpisode(seriesTitle: String)
    case noSearchResults(query: String)

    var errorDescription: String? {
        switch self {
        case .noPlayableEpisode(let seriesTitle):
            return "No playable episode found for \(seriesTitle)"
        case .noSearchResults(let query):
            return "No search results found for \(query)"
        }
    }
}
