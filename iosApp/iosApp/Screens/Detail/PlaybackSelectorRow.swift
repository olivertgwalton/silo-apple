#if !os(tvOS)
import SwiftUI

struct PlaybackSelectorRow: View {
    let versions: [FileVersion]
    let currentVersion: FileVersion?
    let selectedVersionFileId: Int?
    let selectedAudioTrackIndex: Int?
    let selectedSubtitleTrackIndex: Int?
    let onSelectVersion: (Int?) -> Void
    let onSelectAudioTrack: (Int?) -> Void
    let onSelectSubtitleTrack: (Int?) -> Void

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif
    @State private var activeSelector: PlaybackSelectorKind?

    private var model: PlaybackSelectorModel {
        PlaybackSelectorModel(
            versions: versions,
            currentVersion: currentVersion,
            selectedVersionFileId: selectedVersionFileId,
            selectedAudioTrackIndex: selectedAudioTrackIndex,
            selectedSubtitleTrackIndex: selectedSubtitleTrackIndex
        )
    }

    var body: some View {
        if currentVersion != nil, model.hasAnySelector {
            #if os(iOS)
            selectorCard
                .popover(
                    item: $activeSelector,
                    attachmentAnchor: .rect(.bounds),
                    arrowEdge: .top
                ) { kind in
                    selectorPresentation(for: kind)
                }
            #else
            selectorCard
                .sheet(item: $activeSelector) { kind in
                    selectorPresentation(for: kind)
                }
            #endif
        }
    }

    private func selectorPresentation(
        for kind: PlaybackSelectorKind
    ) -> PlaybackSelectorSheet {
        PlaybackSelectorSheet(
            kinds: [kind],
            versions: versions,
            currentVersion: currentVersion,
            selectedVersionFileId: selectedVersionFileId,
            selectedAudioTrackIndex: selectedAudioTrackIndex,
            selectedSubtitleTrackIndex: selectedSubtitleTrackIndex,
            usesPopoverLayout: usesPopoverLayout,
            onSelectVersion: onSelectVersion,
            onSelectAudioTrack: onSelectAudioTrack,
            onSelectSubtitleTrack: onSelectSubtitleTrack
        )
    }

    private var usesPopoverLayout: Bool {
        #if os(iOS)
        horizontalSizeClass == .regular
        #else
        false
        #endif
    }

    /// Settings-style rows: icon and label lead, value trails, chevron last.
    ///
    /// Replaced a two-column `LazyVGrid` that stranded the third selector
    /// alone in the leading column, so the common version / audio /
    /// subtitles case always read as a broken form. A horizontally
    /// scrollable chip strip was tried first and was worse: three chips need
    /// more width than a phone has, so subtitles fell off the edge entirely
    /// and the most-hunted control became the invisible one. Rows never
    /// truncate, never go ragged, and absorb a fourth edition picker by
    /// simply growing.
    private var selectorCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(model.kinds.enumerated()), id: \.element.id) { index, kind in
                if index > 0 {
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 0.5)
                        .padding(.leading, 30)
                }

                selectorButton(kind) {
                    HStack(spacing: 10) {
                        Image(systemName: kind.icon)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.55))
                            .frame(width: 20, alignment: .leading)

                        Text(kind.title)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.72))

                        Spacer(minLength: 12)

                        Text(model.value(for: kind))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        if model.isInteractive(kind) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white.opacity(0.35))
                        }
                    }
                    .frame(height: 44)
                    .contentShape(Rectangle())
                }
            }
        }
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 0.5)
                )
        )
    }
    /// Wraps a layout's row/column in a button when that selector can
    /// actually be changed, and leaves it inert when it cannot.
    @ViewBuilder
    private func selectorButton<Content: View>(
        _ kind: PlaybackSelectorKind,
        @ViewBuilder content: () -> Content
    ) -> some View {
        if model.isInteractive(kind) {
            Button { activeSelector = kind } label: { content() }
                .buttonStyle(.plain)
                .accessibilityLabel("\(kind.title), \(model.value(for: kind))")
        } else {
            content()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(kind.title), \(model.value(for: kind))")
        }
    }

}
private struct PlaybackSelectorSheet: View {
    /// One entry when opened from a single control, all of them when opened
    /// from the `.summary` row.
    let kinds: [PlaybackSelectorKind]
    let versions: [FileVersion]
    let currentVersion: FileVersion?
    let selectedVersionFileId: Int?
    let selectedAudioTrackIndex: Int?
    let selectedSubtitleTrackIndex: Int?
    let usesPopoverLayout: Bool

    /// Wide enough for a two-line option row without wrapping its detail,
    /// tall enough for a full audio-track list before it scrolls.
    private static let popoverSize = CGSize(width: 440, height: 480)
    let onSelectVersion: (Int?) -> Void
    let onSelectAudioTrack: (Int?) -> Void
    let onSelectSubtitleTrack: (Int?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var preferredSubtitleLanguage: String?

    private var model: PlaybackSelectorModel {
        PlaybackSelectorModel(
            versions: versions,
            currentVersion: currentVersion,
            selectedVersionFileId: selectedVersionFileId,
            selectedAudioTrackIndex: selectedAudioTrackIndex,
            selectedSubtitleTrackIndex: selectedSubtitleTrackIndex
        )
    }

    var body: some View {
        NavigationStack {
            List {
                optionContent
            }
            #if os(macOS)
            .listStyle(.inset)
            #else
            .listStyle(.insetGrouped)
            #endif
            .scrollContentBackground(.hidden)
            .background(Color.continuumBackground.ignoresSafeArea())
            .task {
                await ProfilePrefsStore.shared.hydrateIfNeeded()
                preferredSubtitleLanguage = ProfilePrefsStore.shared.preferredSubtitleLanguage
            }
            .navigationTitle(sheetTitle)
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(macOS)
                ToolbarItem {
                    Button("Done") { dismiss() }
                        .tint(.continuumOnSurface)
                }
                #else
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .tint(.continuumOnSurface)
                }
                #endif
            }
        }
        #if os(iOS)
        // Regular-width iPad anchors this as a popover instead of forcing a
        // phone detent into the split-view detail column. A popover sizes to
        // its content, and a `List` has no natural bound, so the anchored
        // presentation is the one case that needs an explicit size.
        .frame(
            width: usesPopoverLayout ? Self.popoverSize.width : nil,
            height: usesPopoverLayout ? Self.popoverSize.height : nil
        )
        .presentationCompactAdaptation(.sheet)
        #endif
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationSizing(.form)
    }

    @ViewBuilder
    private var optionContent: some View {
        ForEach(kinds) { kind in
            switch kind {
            case .edition:
                editionOptions
            case .version:
                versionOptions
            case .audio:
                audioOptions
            case .subtitles:
                subtitleOptions
            }
        }
    }

    private var sheetTitle: String {
        kinds.count == 1 ? (kinds.first?.title ?? "Playback") : "Playback"
    }

    /// Section headers only earn their space when the sheet holds more than
    /// one selector; a single-selector sheet already says so in its title.
    @ViewBuilder
    private func sectionHeader(_ kind: PlaybackSelectorKind) -> some View {
        if kinds.count > 1 {
            Text(kind.title)
        }
    }

    @ViewBuilder
    private var editionOptions: some View {
        Section {
            if model.editions.isEmpty {
                optionButton(title: "Standard", detail: nil, isSelected: true, isEnabled: false) {}
            } else {
                ForEach(model.editions) { edition in
                    optionButton(
                        title: edition.label,
                        detail: "\(edition.versions.count) version\(edition.versions.count == 1 ? "" : "s")",
                        isSelected: model.currentEdition?.id == edition.id
                    ) {
                        onSelectVersion(model.bestVersion(in: edition)?.fileId)
                        dismiss()
                    }
                }
            }
        } header: {
            sectionHeader(.edition)
        }
    }

    @ViewBuilder
    private var versionOptions: some View {
        Section {
            optionButton(
                title: "Auto",
                detail: "Best match for this device",
                isSelected: selectedVersionFileId == nil
            ) {
                onSelectVersion(nil)
                dismiss()
            }
            ForEach(model.scopedVersions) { version in
                optionButton(
                    title: DetailPlaybackFormatting.versionPrimaryText(version),
                    detail: DetailPlaybackFormatting.versionSecondaryText(version),
                    isSelected: selectedVersionFileId == version.fileId
                ) {
                    onSelectVersion(version.fileId)
                    dismiss()
                }
            }
        } header: {
            sectionHeader(.version)
        }
    }


    @ViewBuilder
    private var audioOptions: some View {
        Section {
            optionButton(
                title: "Auto",
                detail: "Use the file default track",
                isSelected: selectedAudioTrackIndex == nil
            ) {
                onSelectAudioTrack(nil)
                dismiss()
            }
            let options = DetailPlaybackFormatting.audioOptions(
                version: currentVersion,
                selectedAudioTrackIndex: selectedAudioTrackIndex
            )
            if options.isEmpty {
                optionButton(title: "Unknown", detail: "No audio metadata", isSelected: false, isEnabled: false) {}
            } else {
                ForEach(options) { option in
                    optionButton(
                        title: option.title,
                        detail: option.detail,
                        isSelected: selectedAudioTrackIndex == option.ordinal
                    ) {
                        onSelectAudioTrack(option.ordinal)
                        dismiss()
                    }
                }
            }
        } header: {
            sectionHeader(.audio)
        }
    }

    @ViewBuilder
    private var subtitleOptions: some View {
        Section {
            optionButton(
                title: "Auto",
                detail: "Use your subtitle preferences",
                isSelected: selectedSubtitleTrackIndex == nil
            ) {
                onSelectSubtitleTrack(nil)
                dismiss()
            }
            optionButton(
                title: "Off",
                detail: "Start without subtitles",
                isSelected: selectedSubtitleTrackIndex == -1
            ) {
                onSelectSubtitleTrack(-1)
                dismiss()
            }
            ForEach(DetailPlaybackFormatting.subtitleOptions(
                version: currentVersion,
                selectedSubtitleTrackIndex: selectedSubtitleTrackIndex,
                preferredLanguage: preferredSubtitleLanguage
            )) { option in
                optionButton(
                    title: option.title,
                    detail: option.detail,
                    isSelected: option.isSelected,
                    isEnabled: option.isSelectable
                ) {
                    if let selectionIndex = option.selectionIndex {
                        onSelectSubtitleTrack(selectionIndex)
                        dismiss()
                    }
                }
            }
        } header: {
            sectionHeader(.subtitles)
        }
    }

    private func optionButton(
        title: String,
        detail: String?,
        isSelected: Bool,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.continuumHeadline)
                        .foregroundColor(.continuumOnSurface)
                        .lineLimit(2)
                    if let detail, !detail.isEmpty {
                        Text(detail)
                            .font(.continuumCaption)
                            .foregroundColor(.continuumSecondaryText)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 8)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.continuumOnSurface)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.56)
        .listRowBackground(Color.continuumSurfaceVariant)
    }
}
#endif
