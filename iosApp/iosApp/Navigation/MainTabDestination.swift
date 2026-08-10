import SwiftUI

/// Navigation model shared by every Apple shell: the destinations a client can
/// route to, the capability gate that hides ones the active profile cannot
/// open, and the server/profile authority that scopes a library list.
///
/// The views that render these live per platform — `Screens/Shell/MainTabView`
/// on iPhone/iPad/Mac, `tvOS/Navigation/TVMainTabView` on Apple TV — but the
/// model itself is common, and shared screens depend on it.

// MARK: - Zoom transition namespace

/// Carries the `@Namespace.ID` used by the iOS 26 poster → detail zoom
/// transition. Published by `MainTabView` so card components (the
/// `.matchedTransitionSource` sources) and the central
/// `navigationDestination` (the `.navigationTransition(.zoom)` destination)
/// can share one namespace without routing it through `Route`/`router.path`.
/// `nil` when unset (e.g. tvOS / macOS) so callers fall back to a plain push.
struct ZoomNamespaceEnvironmentKey: EnvironmentKey {
    static let defaultValue: Namespace.ID? = nil
}

extension EnvironmentValues {
    var zoomNamespace: Namespace.ID? {
        get { self[ZoomNamespaceEnvironmentKey.self] }
        set { self[ZoomNamespaceEnvironmentKey.self] = newValue }
    }
}

// MARK: - Main Tab View

enum MainTabDestinationID: Hashable {
    case app(AppTab)
    case libraryCategory(PrimaryMenuBuiltin)
    case library(Int)
}

struct MainTabDestination: Identifiable, Equatable {
    let id: MainTabDestinationID
    let title: String
    let icon: String
    let selectedIcon: String

    static func app(_ tab: AppTab) -> MainTabDestination {
        .init(id: .app(tab), title: tab.rawValue, icon: tab.icon, selectedIcon: tab.selectedIcon)
    }

    static func library(id: Int, label: String) -> MainTabDestination {
        .init(
            id: .library(id),
            title: label,
            icon: "rectangle.stack",
            selectedIcon: "rectangle.stack.fill"
        )
    }

    static func libraryCategory(_ category: PrimaryMenuBuiltin) -> MainTabDestination {
        let icon: String
        switch category {
        case .movies: icon = "film.stack"
        case .series: icon = "tv"
        case .audiobooks: icon = "book.closed"
        default: icon = "rectangle.stack"
        }
        return .init(
            id: .libraryCategory(category),
            title: category.title,
            icon: icon,
            selectedIcon: icon
        )
    }
}

/// Projects the cross-client menu into roots this Apple shell can navigate
/// without discarding destination identity. Sections and collections remain
/// stored in the synced document, but stay hidden until this shell has a
/// destination-specific root for them.
func projectedMainTabDestinations(
    primaryMenu: PrimaryMenuPreference?,
    availableLibraries: [Library] = []
) -> [MainTabDestination] {
    guard let primaryMenu else {
        return AppTab.visibleCases.map(MainTabDestination.app)
    }

    var destinations: [MainTabDestination] = []
    for item in primaryMenu.items {
        guard mainTabSupportsDestination(item, availableLibraries: availableLibraries) else {
            continue
        }
        let destination: MainTabDestination?
        switch item {
        case .builtin(.home): destination = .app(.home)
        case .builtin(.movies): destination = .libraryCategory(.movies)
        case .builtin(.series): destination = .libraryCategory(.series)
        case .builtin(.audiobooks): destination = .libraryCategory(.audiobooks)
        case .builtin(.music): destination = nil
        case .builtin(.forYou): destination = .app(.recommendations)
        case .builtin(.calendar): destination = .app(.calendar)
        case .library(let libraryId, let label):
            destination = .library(id: libraryId, label: label)
        case .section, .collection:
            destination = nil
        }
        if let destination,
           !destinations.contains(where: { $0.id == destination.id }) {
            destinations.append(destination)
        }
    }
    if !destinations.contains(where: { $0.id == .app(.home) }) {
        destinations.insert(.app(.home), at: 0)
    }
    return destinations
}

/// Runtime/editor capability gate for the non-tvOS Apple main shell. The
/// synced document remains untouched; roots that the active profile cannot
/// currently open simply stay out of the rendered navigation and editor.
func mainTabSupportsDestination(
    _ item: PrimaryMenuItem,
    availableLibraries: [Library]
) -> Bool {
    switch item {
    case .builtin(.movies):
        return availableLibraries.contains {
            libraryMatchesPrimaryMenuCategory($0, category: .movies)
        }
    case .builtin(.series):
        return availableLibraries.contains {
            libraryMatchesPrimaryMenuCategory($0, category: .series)
        }
    case .builtin(.audiobooks):
        return availableLibraries.contains {
            libraryMatchesPrimaryMenuCategory($0, category: .audiobooks)
        }
    case .builtin(.music):
        return false
    case .builtin(.home), .builtin(.forYou), .builtin(.calendar):
        return true
    case .library(let libraryId, _):
        return availableLibraries.contains { $0.id == libraryId }
    case .section, .collection:
        return false
    }
}

func resolvedVisibleMainTabDestination(
    _ requestedDestination: MainTabDestinationID,
    visibleDestinations: [MainTabDestination]
) -> MainTabDestinationID {
    visibleDestinations.contains { $0.id == requestedDestination }
        ? requestedDestination
        : .app(.home)
}

func resolvedRequestedMainTabDestination(
    _ requestedTab: AppTab,
    visibleDestinations: [MainTabDestination]
) -> MainTabDestinationID {
    if requestedTab == .libraries,
       !visibleDestinations.contains(where: { $0.id == .app(.libraries) }),
       let authoredLibraryRoot = visibleDestinations.first(where: {
           switch $0.id {
           case .libraryCategory, .library:
               return true
           case .app:
               return false
           }
       }) {
        return authoredLibraryRoot.id
    }
    return resolvedVisibleMainTabDestination(
        .app(requestedTab),
        visibleDestinations: visibleDestinations
    )
}

struct MainTabLibraryAuthority: Hashable {
    let serverId: String
    let profileId: String

    init?(serverId: String?, profileId: String?) {
        guard let serverId, !serverId.isEmpty,
              let profileId, !profileId.isEmpty else { return nil }
        self.serverId = serverId
        self.profileId = profileId
    }
}

struct MainTabLibrarySnapshot: Equatable {
    let authority: MainTabLibraryAuthority?
    let libraries: [Library]

    func availableLibraries(
        for currentAuthority: MainTabLibraryAuthority?
    ) -> [Library] {
        guard let currentAuthority, authority == currentAuthority else { return [] }
        return libraries
    }

    @MainActor
    static func cachedForCurrentAuthority() -> Self {
        let registry = ServerRegistry.shared
        let authority = MainTabLibraryAuthority(
            serverId: registry.activeServerId,
            profileId: registry.activeProfileId
        )
        let libraries = ResponseCache.shared.get(
            CacheKey.userLibraries,
            as: LibrariesResponse.self
        )?.libraries ?? []
        return .init(authority: authority, libraries: libraries)
    }
}
