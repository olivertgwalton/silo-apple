#if os(tvOS)
import SwiftUI

/// Pre-Play playback metadata row shown under the hero actions. Version ·
/// Audio · Subtitles stay visible as squared value boxes; boxes become menus
/// only when there are multiple real choices. Edition is included only when
/// there are multiple edition groups.
/// Once an effective playable version is known, the active playback metadata
/// stays visible.
/// Uses the detail view's existing version/audio/subtitle callbacks; Edition
/// is derived from `FileVersion.editionRaw` / `editionKey` and selecting one
/// routes through `onSelectVersion`.
struct TVPlaybackSelectorRow: View {
    private enum Layout {
        static let selectorSpacing: CGFloat = 28
    }

    private enum SelectorFocus: Hashable {
        case edition
        case version
        case audio
        case subtitles

        init(_ kind: PlaybackSelectorKind) {
            switch kind {
            case .edition: self = .edition
            case .version: self = .version
            case .audio: self = .audio
            case .subtitles: self = .subtitles
            }
        }
    }

    let versions: [FileVersion]
    let currentVersion: FileVersion?
    let selectedVersionFileId: Int?
    let selectedAudioTrackIndex: Int?
    let selectedSubtitleTrackIndex: Int?
    /// Server-resolved subtitle policy for this item, used to preview what
    /// "Auto" will land on. Defaulted so callers without it keep a bare "Auto".
    var subtitleMode: String? = nil
    var subtitleSignature: SubtitleTrackSignature? = nil
    /// Profile/item "Show Forced Subtitles" preference — feeds the Auto
    /// preview's forced-track branch so the row doesn't show "Auto: Off"
    /// when playback would actually start with a forced track.
    var showForcedSubtitles: Bool = false
    let onSelectVersion: (Int?) -> Void
    let onSelectAudioTrack: (Int?) -> Void
    let onSelectSubtitleTrack: (Int?) -> Void

    @Environment(\.resetFocus) private var resetFocus
    @Namespace private var selectorFocusScope
    @FocusState private var focusedSelector: SelectorFocus?
    @State private var defaultSelectorFocus: SelectorFocus?
    @State private var preferredSubtitleLanguage: String?

    private var model: PlaybackSelectorModel {
        PlaybackSelectorModel(
            versions: versions,
            currentVersion: currentVersion,
            selectedVersionFileId: selectedVersionFileId,
            selectedAudioTrackIndex: selectedAudioTrackIndex,
            selectedSubtitleTrackIndex: selectedSubtitleTrackIndex,
            annotatesAuto: true,
            subtitleAutoContext: subtitleAutoContext
        )
    }

    var body: some View {
        if model.hasAnySelector {
            selectorRow
                // Stretch the focus section to the full action-area width even
                // though the buttons sit on the left. Entering a focus section
                // is resolved by the section's *bounds* overlapping the move
                // vector, so a full-width section sits under every top-row
                // control — including the far-right circle buttons (List /
                // Watched / More). A Down press from any of them then lands on
                // the nearest selector instead of skipping the row. Buttons
                // stay left-aligned.
                .frame(maxWidth: .infinity, alignment: .leading)
                .focusScope(selectorFocusScope)
                .focusSection()
                .modifier(SelectorDefaultFocus(focus: defaultSelectorFocus, binding: $focusedSelector))
                .onChange(of: focusedSelector) { _, newValue in
                    // The restore default (see `restoreFocus`) must only
                    // outlive the menu dismissal it serves. Once focus leaves
                    // the row — up to the action row, or into an opening menu
                    // — repoint it at the leading pill so re-entering the row
                    // lands like untouched geometry instead of jumping back
                    // to the last-modified selector. Swap the value rather
                    // than clearing it: `SelectorDefaultFocus` branches on
                    // nil, and re-identifying the row subtree would tear down
                    // an open Menu.
                    if newValue == nil, defaultSelectorFocus != nil {
                        defaultSelectorFocus = firstSelector
                    }
                }
                .task {
                    await ProfilePrefsStore.shared.hydrateIfNeeded()
                    preferredSubtitleLanguage = ProfilePrefsStore.shared.preferredSubtitleLanguage
                }
        }
    }

    private var selectorRow: some View {
        HStack(spacing: Layout.selectorSpacing) {
            if model.isVisible(.edition) {
                editionSelector
            }
            if model.isVisible(.version) {
                versionSelector
            }
            if model.isVisible(.audio) {
                audioSelector
            }
            if model.isVisible(.subtitles) {
                subtitleSelector
            }
        }
    }

    /// Leading visible pill — where entry into the row should land once the
    /// post-menu restore default has served its purpose.
    private var firstSelector: SelectorFocus {
        SelectorFocus(model.firstKind ?? .subtitles)
    }

    // MARK: - Edition

    private var editionSelector: some View {
        TVSelectorButton(icon: "rectangle.stack", label: "Edition", value: model.value(for: .edition)) {
            if model.editions.isEmpty {
                Button("Standard") { }.disabled(true)
            } else {
                ForEach(model.editions) { edition in
                    Button {
                        selectVersion(model.bestVersion(in: edition)?.fileId, returningFocusTo: .edition)
                    } label: {
                        selectorMenuItem(
                            title: edition.label,
                            detail: "\(edition.versions.count) version\(edition.versions.count == 1 ? "" : "s")",
                            isSelected: model.currentEdition?.id == edition.id
                        )
                    }
                }
            }
        }
        .focused($focusedSelector, equals: .edition)
    }

    // MARK: - Version

    @ViewBuilder
    private var versionSelector: some View {
        let value = model.value(for: .version)
        if model.isInteractive(.version) {
            TVSelectorButton(
                icon: "tv",
                label: "Version",
                value: value
            ) {
                Button { selectVersion(nil, returningFocusTo: .version) } label: {
                    selectorMenuItem(title: "Auto", detail: "Best match for this device", isSelected: selectedVersionFileId == nil)
                }
                ForEach(model.scopedVersions) { version in
                    Button {
                        selectVersion(version.fileId, returningFocusTo: .version)
                    } label: {
                        selectorMenuItem(
                            title: DetailPlaybackFormatting.versionShortLabel(version),
                            detail: DetailPlaybackFormatting.versionDetailLabel(version),
                            isSelected: selectedVersionFileId == version.fileId
                        )
                    }
                }
            }
            .focused($focusedSelector, equals: .version)
        } else {
            TVSelectorValue(icon: "tv", label: "Version", value: value)
        }
    }

    // MARK: - Audio

    @ViewBuilder
    private var audioSelector: some View {
        let value = model.value(for: .audio)
        if model.isInteractive(.audio) {
            TVSelectorButton(
                icon: "speaker.wave.2",
                label: "Audio",
                value: value
            ) {
                Button { selectAudioTrack(nil) } label: {
                    selectorMenuItem(title: "Auto", detail: "Use the file default track", isSelected: selectedAudioTrackIndex == nil)
                }
                let options = model.audioOptions()
                if options.isEmpty {
                    Button("Unknown") { }.disabled(true)
                } else {
                    ForEach(options) { option in
                        Button { selectAudioTrack(option.ordinal) } label: {
                            selectorMenuItem(
                                title: option.title,
                                detail: option.detail,
                                isSelected: selectedAudioTrackIndex == option.ordinal
                            )
                        }
                    }
                }
            }
            .focused($focusedSelector, equals: .audio)
        } else {
            TVSelectorValue(icon: "speaker.wave.2", label: "Audio", value: value)
        }
    }

    // MARK: - Subtitles

    private var subtitleAutoContext: DetailPlaybackFormatting.SubtitleAutoContext {
        DetailPlaybackFormatting.SubtitleAutoContext(
            preferredLanguage: preferredSubtitleLanguage,
            mode: subtitleMode,
            signature: subtitleSignature,
            audioLanguage: DetailPlaybackFormatting.resolvedAudioLanguage(
                version: currentVersion,
                selectedAudioTrackIndex: selectedAudioTrackIndex
            ),
            showForced: showForcedSubtitles
        )
    }

    @ViewBuilder
    private var subtitleSelector: some View {
        let value = model.value(for: .subtitles)
        if model.isInteractive(.subtitles) {
            TVSelectorButton(
                icon: "captions.bubble",
                label: "Subtitles",
                value: value
            ) {
                Button { selectSubtitleTrack(nil) } label: {
                    selectorMenuItem(title: "Auto", detail: "Use your subtitle preferences", isSelected: selectedSubtitleTrackIndex == nil)
                }
                Button { selectSubtitleTrack(-1) } label: {
                    selectorMenuItem(title: "Off", detail: "Start without subtitles", isSelected: selectedSubtitleTrackIndex == -1)
                }
                ForEach(model.subtitleOptions(preferredLanguage: preferredSubtitleLanguage)) { option in
                    if option.isSelectable, let selectionIndex = option.selectionIndex {
                        Button { selectSubtitleTrack(selectionIndex) } label: {
                            selectorMenuItem(title: option.title, detail: option.detail, isSelected: option.isSelected)
                        }
                    } else {
                        Button {
                        } label: {
                            selectorMenuItem(title: option.title, detail: option.detail, isSelected: false)
                        }
                        .disabled(true)
                    }
                }
            }
            .focused($focusedSelector, equals: .subtitles)
        } else {
            TVSelectorValue(icon: "captions.bubble", label: "Subtitles", value: value)
        }
    }

    private func selectVersion(_ fileId: Int?, returningFocusTo focus: SelectorFocus) {
        onSelectVersion(fileId)
        restoreFocus(to: focus)
    }

    private func selectAudioTrack(_ index: Int?) {
        onSelectAudioTrack(index)
        restoreFocus(to: .audio)
    }

    private func selectSubtitleTrack(_ index: Int?) {
        onSelectSubtitleTrack(index)
        restoreFocus(to: .subtitles)
    }

    private func restoreFocus(to focus: SelectorFocus) {
        defaultSelectorFocus = focus
        focusedSelector = focus
        Task { @MainActor in
            await Task.yield()
            resetFocus(in: selectorFocusScope)
            focusedSelector = focus
        }
    }

    private struct SelectorDefaultFocus: ViewModifier {
        let focus: SelectorFocus?
        let binding: FocusState<SelectorFocus?>.Binding

        @ViewBuilder
        func body(content: Content) -> some View {
            if let focus {
                content.defaultFocus(binding, focus, priority: .userInitiated)
            } else {
                content
            }
        }
    }

    // MARK: - Shared menu item

    @ViewBuilder
    private func selectorMenuItem(title: String, detail: String, isSelected: Bool) -> some View {
        if isSelected {
            Label(detail.isEmpty ? title : "\(title) — \(detail)", systemImage: "checkmark")
        } else {
            Text(detail.isEmpty ? title : "\(title) — \(detail)")
        }
    }
}

/// One squared selector button: `[icon] LABEL  value  ⌄`, opening a `Menu`.
/// Matches the secondary squared button look (translucent fill + hairline).
private struct TVSelectorButton<MenuContent: View>: View {
    let icon: String
    let label: String
    let value: String
    @ViewBuilder let menu: () -> MenuContent

    var body: some View {
        Menu {
            menu()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 22, weight: .semibold))
                Text(label.uppercased())
                    .font(.system(size: 18, weight: .bold))
                    .tracking(1.0)
                    .opacity(0.6)
                Text(value).font(.system(size: 22, weight: .semibold)).lineLimit(1)
                Image(systemName: "chevron.down").font(.system(size: 15, weight: .bold)).opacity(0.6)
            }
        }
        .menuStyle(.button)
        .buttonStyle(DetailPillButtonStyle(kind: .secondary))
    }
}

/// Single-choice version of the selector pill. Still focusable so the box can
/// be highlighted ("hovered") on tvOS even when there is only one option;
/// pressing Select is a no-op since there is nothing to choose. Shares the
/// interactive pill's styling and focus treatment so the row reads uniformly.
private struct TVSelectorValue: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        Button { } label: {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 22, weight: .semibold))
                Text(label.uppercased())
                    .font(.system(size: 18, weight: .bold))
                    .tracking(1.0)
                    .opacity(0.6)
                Text(value).font(.system(size: 22, weight: .semibold)).lineLimit(1)
            }
        }
        .buttonStyle(DetailPillButtonStyle(kind: .secondary))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label), \(value)")
    }
}
#endif
