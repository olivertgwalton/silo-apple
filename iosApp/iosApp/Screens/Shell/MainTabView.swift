import SwiftUI

/// The iPhone / iPad / Mac application shell: sidebar or tab bar, the
/// navigation stack, and the central route destination.
///
/// Compiled only for those platforms — Apple TV has its own shell in
/// `tvOS/Navigation/TVMainTabView.swift` and never instantiates this one, so
/// the tvOS branches this code used to carry were unreachable and are gone.

struct MainTabView: View {
    @Bindable var router: AppRouter
    @State private var selectedDestinationID: MainTabDestinationID = .app(.home)
    @State private var uiCustomization = UICustomizationPreferences.shared
    @State private var serverRegistry = ServerRegistry.shared
    /// Tagged with the server/profile that authorized the library list. A
    /// profile transition fails direct roots closed immediately, even before
    /// its cache invalidation and network refresh finish.
    @State private var librarySnapshot = MainTabLibrarySnapshot.cachedForCurrentAuthority()
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    /// Shared namespace for the poster → detail zoom transition. Injected into
    /// the environment (`\.zoomNamespace`) so both the cards and the central
    /// detail destination resolve the same identity.
    @Namespace private var zoomNamespace
    @Environment(AudioPlaybackStore.self) private var audioStore
    @Environment(\.scenePhase) private var scenePhase
    #if os(iOS)
    @Environment(SiloControlClient.self) private var siloControl
    #endif
    #if !os(macOS)
    @Environment(\.horizontalSizeClass) private var hSize
    #endif

    var body: some View {
        Group {
            if prefersSidebarLayout {
                sidebarLayout
            } else {
                tabLayout
            }
        }
        .tint(.continuumOnSurface)
        .task(id: currentLibraryAuthority) {
            await loadVisibleLibraries(for: currentLibraryAuthority)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            let authority = currentLibraryAuthority
            Task { await loadVisibleLibraries(for: authority) }
        }
        // Mirror Android's offline start-destination: launching with no
        // network but playable local downloads lands on Downloads instead of
        // a Home screen that can't load anything.
        .task {
            await ConnectionMonitor.shared.waitForInitialPath()
            guard !ConnectionMonitor.shared.isDeviceOnline else { return }
            // The auth-state task hydrates DownloadManager via onAppActive()
            // only after several awaited network refreshes, which is too late
            // for this check on an offline cold launch. Loading the scope
            // here is disk-only and idempotent — onAppActive() will skip the
            // reload when it eventually runs.
            _ = await DownloadManager.shared.activateScopeIfNeeded()
            guard DownloadManager.shared.downloadsEnabled,
                  DownloadManager.shared.records.contains(where: { $0.isPlayableOffline }),
                  // Don't clobber a tab the user (or a deep link) already
                  // selected while this task was waiting.
                  selectedDestinationID == .app(.home), router.requestedTab == nil
            else { return }
            selectedDestinationID = .app(.downloads)
        }
        #if os(iOS)
        // Cold-launch path for silent remote-control resume: scenePhase may
        // already be .active when the authenticated UI first appears, so the
        // scenePhase onChange alone would miss it. Idempotent — the controller
        // guards against duplicate probes.
        .task { siloControl.attemptAutoResumeIfIdle() }
        #endif
        .onChange(of: router.requestedTab) { _, tab in
            guard let tab else { return }
            selectedDestinationID = resolvedRequestedMainTabDestination(
                tab,
                visibleDestinations: visibleDestinations
            )
            router.requestedTab = nil
        }
        .onChange(of: uiCustomization.primaryMenu) { _, _ in
            selectedDestinationID = resolvedVisibleMainTabDestination(
                selectedDestinationID,
                visibleDestinations: visibleDestinations
            )
        }
        .onChange(of: librarySnapshot) { _, _ in
            selectedDestinationID = resolvedVisibleMainTabDestination(
                selectedDestinationID,
                visibleDestinations: visibleDestinations
            )
        }
        // One call on every platform. `playerCover` resolves to a
        // `fullScreenCover` on iOS/tvOS and to a window takeover on macOS,
        // swapped by target membership rather than a conditional here.
        .playerCover(presentation: $router.presentedPlayer)
        #if !os(macOS)
        .fullScreenCover(isPresented: Binding(
            get: { audioStore.isShowingFullPlayer },
            set: { if !$0 { audioStore.dismissFullPlayer() } }
        )) {
            AudioFullPlayerView()
        }
        #if os(iOS)
        .sheet(isPresented: Binding(
            get: { siloControl.isShowingRemoteControl },
            set: { if !$0 { siloControl.hideRemoteControl() } }
        )) {
            SiloControlRemoteView(controller: siloControl)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        #endif
        #endif
        // Outside the presentation modifiers so presented covers (audio
        // player, video player) inherit the router — ErrorView requires
        // it and traps when it's absent.
        .environment(router)
    }

    private var prefersSidebarLayout: Bool {
        #if os(macOS)
        true
        #else
        hSize == .regular
        #endif
    }

    /// Visible tabs, plus a Downloads tab when the server advertises the
    /// downloads capability for this profile. Reading
    /// `DownloadManager.shared.downloadsEnabled` here registers the tab bar
    /// as an observer, so the tab appears as soon as capability loads.
    private var visibleDestinations: [MainTabDestination] {
        var destinations = projectedMainTabDestinations(
            primaryMenu: uiCustomization.primaryMenu,
            availableLibraries: librarySnapshot.availableLibraries(
                for: currentLibraryAuthority
            )
        )
        if DownloadManager.shared.downloadsEnabled,
           !destinations.contains(where: { $0.id == .app(.downloads) }) {
            destinations.append(.app(.downloads))
        }
        return destinations
    }

    private var currentLibraryAuthority: MainTabLibraryAuthority? {
        MainTabLibraryAuthority(
            serverId: serverRegistry.activeServerId,
            profileId: serverRegistry.activeProfileId
        )
    }

    private func loadVisibleLibraries(for authority: MainTabLibraryAuthority?) async {
        let retainedLibraries = librarySnapshot.authority == authority
            ? librarySnapshot.libraries
            : []
        librarySnapshot = .init(authority: authority, libraries: retainedLibraries)
        guard let authority else { return }
        do {
            let response = try await StartupContentPrefetcher.fetchUserLibraries()
            guard !Task.isCancelled, currentLibraryAuthority == authority else { return }
            librarySnapshot = .init(authority: authority, libraries: response.libraries)
        } catch {
            // Keep the active-profile cache, or fail closed with no direct
            // library roots when there is no safe offline routing metadata.
        }
    }

    private var selectedDestination: MainTabDestination {
        visibleDestinations.first(where: { $0.id == selectedDestinationID })
            ?? .app(.home)
    }

    /// iPhone + iPad compact width: bottom tab bar, single navigation stack.
    private var tabLayout: some View {
        NavigationStack(path: $router.path) {
            TabView(selection: $selectedDestinationID) {
                ForEach(visibleDestinations) { destination in
                    Tab(
                        destination.title,
                        systemImage: selectedDestinationID == destination.id
                            ? destination.selectedIcon
                            : destination.icon,
                        value: destination.id
                    ) {
                        destinationContent(for: destination)
                    }
                }
            }
            .navigationDestination(for: Route.self) { route in
                routeContent(for: route)
            }
            #if os(iOS)
            .tabBarMinimizeBehavior(.onScrollDown)
            .modifier(NowPlayingShelfAttachment())
            #endif
        }
        .environment(\.zoomNamespace, zoomNamespace)
    }

    /// iPad regular width: sidebar list + detail pane.
    /// Selection drives both the highlighted row and the detail content.
    ///
    /// The sidebar's collapse affordance is `NavigationSplitView`'s own
    /// toolbar toggle. The app used to hand a custom toggle closure down
    /// through the environment so each custom header could draw its own
    /// button; that produced two toggles side by side on macOS, and the
    /// native one is better placed on both platforms.
    ///
    /// Video playback never lands in the detail pane:
    /// `router.presentedPlayer` drives a `fullScreenCover` on iPadOS and a
    /// dedicated `MacPlayerWindow` on macOS.
    private var sidebarLayout: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(selection: Binding<MainTabDestinationID?>(
                get: { selectedDestinationID },
                set: { if let value = $0 { selectSidebarDestination(value) } }
            )) {
                ForEach(visibleDestinations) { destination in
                    Label(
                        destination.title,
                        systemImage: selectedDestinationID == destination.id
                            ? destination.selectedIcon
                            : destination.icon
                    )
                    .tag(destination.id)
                }
            }
            .navigationTitle("Silo")
            .navigationSplitViewColumnWidth(min: 240, ideal: 260, max: 280)
        } detail: {
            NavigationStack(path: $router.path) {
                destinationContent(for: selectedDestination)
                    .id(selectedDestination.id)
                    .navigationDestination(for: Route.self) { route in
                        routeContent(for: route)
                    }
            }
        }
        .environment(\.zoomNamespace, zoomNamespace)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            NowPlayingShelf(style: .card)
        }
    }

    /// Sidebar rows are root destinations, even when the same row is already
    /// selected beneath a pushed screen. Clear the detail stack first so, for
    /// example, tapping Home while Search is open actually returns to Home.
    private func selectSidebarDestination(_ destinationID: MainTabDestinationID) {
        router.popToRoot()
        selectedDestinationID = destinationID
    }


    @ViewBuilder
    private func destinationContent(for destination: MainTabDestination) -> some View {
        switch destination.id {
        case .app(let tab):
            tabContent(for: tab)
        case .libraryCategory(let category):
            LibrariesTabView(
                category: category,
                libraryAuthority: currentLibraryAuthority,
                onLibrariesLoaded: acceptLoadedLibraries
            )
        case .library(let libraryId):
            LibrariesTabView(
                fixedLibraryId: libraryId,
                libraryAuthority: currentLibraryAuthority,
                onLibrariesLoaded: acceptLoadedLibraries
            )
        }
    }

    private func acceptLoadedLibraries(
        authority: MainTabLibraryAuthority?,
        libraries: [Library]
    ) {
        guard let authority, authority == currentLibraryAuthority else { return }
        librarySnapshot = .init(authority: authority, libraries: libraries)
    }

    @ViewBuilder
    private func tabContent(for tab: AppTab) -> some View {
        switch tab {
        case .home:
            HomeView()

        case .libraries:
            LibrariesTabView(
                libraryAuthority: currentLibraryAuthority,
                onLibrariesLoaded: acceptLoadedLibraries
            )

        case .search:
            SearchView()

        case .recommendations:
            RecommendationsView()

        case .calendar:
            CalendarView()

        case .downloads:
            DownloadsView()

        case .settings:
            SettingsView()

        case .switchProfile, .switchServer:
            // tvOS-only sidebar shortcuts; filtered out of iOS visibleCases.
            EmptyView()
        }
    }

    @ViewBuilder
    private func routeContent(for route: Route) -> some View {
        switch route {
        case .library(let libraryId, let title):
            LibraryDetailView(libraryId: libraryId, initialTitle: title)
        case .libraryCollection(let libraryId, let collectionId, let title, let kind):
            LibraryCollectionDetailView(
                libraryId: libraryId,
                collectionId: collectionId,
                title: title,
                kind: kind
            )
        case .itemDetail(let contentId):
            ItemDetailView(contentId: contentId)
                #if os(iOS)
                // Destination half of the iOS 26 poster → detail zoom. Keys off
                // the unique per-card source id the tapped card recorded in
                // `pendingZoomSourceID` (falling back to `contentId`), so the
                // zoom animates from the exact card even when the same item is
                // visible in two rows. SwiftUI falls back to a normal push when
                // no matching source is on screen.
                .navigationTransition(.zoom(sourceID: router.pendingZoomSourceID ?? contentId, in: zoomNamespace))
                #endif
        case .personDetail(let personId):
            PersonDetailView(personId: personId)
        case .player:
            // The player is never pushed: iOS/iPadOS present it as a
            // full-screen cover and macOS opens a dedicated window (both via
            // `router.presentedPlayer`), so video is never boxed into the
            // detail pane. These arms exist only so exhaustiveness holds.
            EmptyView()
        case .playerWithFile:
            EmptyView()
        case .favorites:
            FavoritesView()
        case .watchlist:
            WatchlistView()
        case .history:
            HistoryView()
        case .collections:
            CollectionsView()
        case .collectionDetail(let id):
            CollectionDetailView(collectionId: id)
        case .browse(let libraryId):
            BrowseView(libraryId: libraryId)
        case .requestsHub:
            RequestsHubView()
        case .requestDetail(let mediaType, let tmdbId):
            RequestDetailView(mediaType: mediaType, tmdbId: tmdbId)
        case .myRequests:
            MyRequestsView()
        case .admin:
            AdminDashboardView()
        case .search:
            SearchView()
        case .settings:
            SettingsView()
        case .recommendations:
            RecommendationsView()
        case .serverList:
            ServerListView()
        case .downloads:
            DownloadsView()
        case .offlinePlayer:
            EmptyView()
        case .offlineSeriesBrowse(let seriesId):
            OfflineSeriesBrowseView(seriesId: seriesId)
        case .offlineDownloadDetail(let downloadId):
            OfflineDownloadDetailView(downloadId: downloadId)
        default:
            EmptyStateView(icon: "questionmark.circle", title: "Unknown", subtitle: nil)
                .continuumBackground()
        }
    }
}
