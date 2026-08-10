import Foundation

/// The four pre-play choices a detail page can offer.
enum PlaybackSelectorKind: String, Identifiable, CaseIterable {
    case edition
    case version
    case audio
    case subtitles

    var id: String { rawValue }

    var title: String {
        switch self {
        case .edition: "Edition"
        case .version: "Version"
        case .audio: "Audio"
        case .subtitles: "Subtitles"
        }
    }

    var icon: String {
        switch self {
        case .edition: "rectangle.stack"
        case .version: "4k.tv"
        case .audio: "speaker.wave.2"
        case .subtitles: "captions.bubble"
        }
    }
}

/// Which pre-play selectors a detail page shows, whether each can be changed,
/// and what each currently reads.
///
/// The compact row and the Apple TV row present these very differently — a
/// list of settings rows opening a sheet, versus a horizontal strip of pill
/// menus — but they must agree exactly on *which* selectors exist and what
/// they say, or the same item offers different choices on two devices. This
/// type is that agreement; `DetailPlaybackFormatting` remains the layer below
/// it that turns a `FileVersion` into copy.
struct PlaybackSelectorModel {
    let versions: [FileVersion]
    let currentVersion: FileVersion?
    let selectedVersionFileId: Int?
    let selectedAudioTrackIndex: Int?
    let selectedSubtitleTrackIndex: Int?
    /// Annotates the Auto value with what Auto resolved to ("Auto: English").
    /// The 10-foot row has the width for it; the compact row does not.
    var annotatesAuto = false
    /// Server-resolved subtitle policy, used to preview what "Auto" will land
    /// on. Absent leaves a bare "Auto".
    var subtitleAutoContext: DetailPlaybackFormatting.SubtitleAutoContext? = nil

    var editions: [PlaybackEditions.Edition] {
        PlaybackEditions.editions(from: versions)
    }

    var currentEdition: PlaybackEditions.Edition? {
        DetailPlaybackFormatting.currentEdition(
            versions: versions,
            currentVersion: currentVersion
        )
    }

    /// Versions the version picker may offer, scoped to the current edition.
    var scopedVersions: [FileVersion] {
        DetailPlaybackFormatting.versionSelectorVersions(
            versions: versions,
            currentVersion: currentVersion
        )
    }

    /// The selectors worth showing, in presentation order.
    var kinds: [PlaybackSelectorKind] {
        PlaybackSelectorKind.allCases.filter(isVisible)
    }

    var hasAnySelector: Bool { !kinds.isEmpty }

    /// Leading visible selector — where entry into the row should land.
    var firstKind: PlaybackSelectorKind? { kinds.first }

    func isVisible(_ kind: PlaybackSelectorKind) -> Bool {
        switch kind {
        case .edition:
            editions.count > 1
        case .version:
            currentVersion != nil
        case .audio:
            DetailPlaybackFormatting.shouldShowAudioValue(version: currentVersion)
        case .subtitles:
            DetailPlaybackFormatting.shouldShowSubtitleValue(version: currentVersion)
        }
    }

    /// Whether the selector has more than one real choice behind it. A
    /// visible-but-not-interactive selector still states the active value.
    func isInteractive(_ kind: PlaybackSelectorKind) -> Bool {
        switch kind {
        case .edition:
            editions.count > 1
        case .version:
            DetailPlaybackFormatting.shouldEnableVersionSelector(
                versions: versions,
                currentVersion: currentVersion
            )
        case .audio:
            DetailPlaybackFormatting.shouldEnableAudioSelector(version: currentVersion)
        case .subtitles:
            DetailPlaybackFormatting.shouldEnableSubtitleSelector(version: currentVersion)
        }
    }

    func value(for kind: PlaybackSelectorKind) -> String {
        switch kind {
        case .edition:
            currentEdition?.label
                ?? currentVersion?.editionDisplayLabel
                ?? "Standard"
        case .version:
            versionValue
        case .audio:
            DetailPlaybackFormatting.audioValueLabel(
                version: currentVersion,
                selectedAudioTrackIndex: selectedAudioTrackIndex,
                annotateAuto: annotatesAuto
            )
        case .subtitles:
            DetailPlaybackFormatting.subtitleValueLabel(
                version: currentVersion,
                selectedSubtitleTrackIndex: selectedSubtitleTrackIndex,
                autoContext: subtitleAutoContext
            )
        }
    }

    private var versionValue: String {
        let summary = DetailPlaybackFormatting.versionShortLabel(currentVersion)
        guard annotatesAuto, selectedVersionFileId == nil else { return summary }
        return "Auto: \(summary)"
    }

    /// The version an edition selection should resolve to.
    func bestVersion(in edition: PlaybackEditions.Edition) -> FileVersion? {
        DetailVersionSelection.displayVersion(
            versions: edition.versions,
            selectedFileId: nil,
            lastFileId: nil,
            preferredQualityId: PlayerSettings.shared.preferredQuality
        )
    }

    func audioOptions() -> [DetailPlaybackFormatting.AudioOption] {
        DetailPlaybackFormatting.audioOptions(
            version: currentVersion,
            selectedAudioTrackIndex: selectedAudioTrackIndex
        )
    }

    func subtitleOptions(
        preferredLanguage: String?
    ) -> [DetailPlaybackFormatting.SubtitleOption] {
        DetailPlaybackFormatting.subtitleOptions(
            version: currentVersion,
            selectedSubtitleTrackIndex: selectedSubtitleTrackIndex,
            preferredLanguage: preferredLanguage
        )
    }
}
