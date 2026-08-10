import SwiftUI
import NukeUI
import Nuke

/// The app's image renderer: a `LazyImage` against the shared
/// `PosterImageCache` pipeline, so every call site gets the persistent memory
/// + disk cache and decode-time downsampling (a 1080×1620 poster is not held
/// at full resolution to draw at 260×390). A thumbhash placeholder holds the
/// space until the decode lands.
struct CachedAsyncImage: View {
    let url: String
    var thumbhash: String? = nil
    /// Decode size. `nil` measures the view and downsamples to that instead.
    var targetSize: CGSize? = nil
    var contentMode: ContentMode = .fill
    var placeholderStyle: ImagePlaceholderStyle = .surface

    @Environment(\.displayScale) private var displayScale

    var body: some View {
        GeometryReader { geometry in
            let resolvedSize = targetSize ?? geometry.size
            LazyImage(request: request(for: resolvedSize)) { state in
                if let image = state.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                } else if state.error != nil {
                    placeholder(in: geometry.size)
                        .overlay {
                            if placeholderStyle.showsErrorIcon {
                                Image(systemName: "film")
                                    .foregroundColor(.continuumOnSurface.opacity(0.3))
                            }
                        }
                } else {
                    placeholder(in: geometry.size)
                }
            }
            .priority(.normal)
            .transition(.opacity)
            .animation(.easeOut(duration: ContinuumTheme.slowDuration), value: url)
        }
    }

    // MARK: - Request construction

    private func request(for size: CGSize) -> ImageRequest? {
        guard let url = URL(string: url) else { return nil }
        // Scale by the native display scale so we ask the decoder for the
        // exact pixel dimensions we render at.
        let pixelSize = CGSize(
            width: size.width * displayScale,
            height: size.height * displayScale
        )
        return ImageRequest(
            url: url,
            processors: [
                ImageProcessors.Resize(size: pixelSize, contentMode: .aspectFill, upscale: false)
            ]
        )
    }

    private func placeholder(in size: CGSize) -> some View {
        Group {
            switch placeholderStyle {
            case .surface:
                ThumbhashImage(thumbhash: thumbhash)
            case .clear:
                Color.clear
            }
        }
        .frame(width: size.width, height: size.height)
    }
}

enum ImagePlaceholderStyle {
    case surface
    case clear

    var showsErrorIcon: Bool {
        switch self {
        case .surface:
            return true
        case .clear:
            return false
        }
    }
}
