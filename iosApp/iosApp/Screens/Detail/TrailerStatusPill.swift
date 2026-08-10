import SwiftUI

/// Feedback for the "Find Trailers" action, shown under the detail page's
/// action row.
///
/// One view, no platform branches: the type comes from the semantic scale
/// and the insets from `ContinuumTheme`. The copy comes from
/// `TrailerFetchCoordinator.statusMessage`, and the terminal outcomes
/// (cooldown / disabled / nothing found) clear themselves after a beat so a
/// dead end never becomes permanent furniture on the page. While the fetch
/// runs the pill persists, because the poll can take a while and the spinner
/// is the only sign anything is happening.
struct TrailerStatusPill: View {
    let message: String
    /// True while the request or poll is in flight — spinner instead of a
    /// glyph, and no auto-dismiss.
    let isFetching: Bool
    /// Invoked once a terminal message has been visible long enough; the
    /// owner acknowledges it on the coordinator.
    let onAutoDismiss: () -> Void

    /// Terminal copy is a full sentence rather than a one-word status, so it
    /// gets twice `RefreshStatusPill`'s floor to be read comfortably.
    private static let terminalVisibleDuration: TimeInterval = 3

    var body: some View {
        HStack(spacing: ContinuumTheme.smallPadding) {
            if isFetching {
                ProgressView()
                    .controlSize(.small)
                    .tint(.continuumOnSurface)
            } else {
                Image(systemName: "info.circle")
                    .font(.continuumCaption)
                    .foregroundColor(.continuumOnSurface)
            }

            Text(message)
                .font(.continuumCaption)
                .foregroundColor(.continuumOnSurface)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding(.horizontal, ContinuumTheme.padding)
        .padding(.vertical, ContinuumTheme.smallPadding)
        .background(Capsule().fill(.ultraThinMaterial))
        .overlay {
            Capsule().stroke(Color.white.opacity(0.16), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.28), radius: 14, y: 8)
        // Renders inside the hero's action focus section on tvOS and must
        // never become a stop on the way down from Play.
        .focusable(false)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
        // Keyed on the copy *and* the phase so the timer restarts when
        // "Finding trailers…" is replaced by its outcome.
        .task(id: dismissKey) {
            guard !isFetching else { return }
            try? await Task.sleep(for: .seconds(Self.terminalVisibleDuration))
            guard !Task.isCancelled else { return }
            onAutoDismiss()
        }
    }

    private var dismissKey: String {
        "\(isFetching)|\(message)"
    }
}
