import SwiftUI

/// The active backend's video surface.
///
/// `AVPlayerSurface` and `PlayerSurface` each exist once per platform under
/// the same name — UIKit representables on iOS/tvOS, AppKit on macOS, swapped
/// by target membership — so this switch needs no conditional of its own.
/// AVPlayer covers HLS, the narrow native-direct allowlist, and the Dolby
/// Vision loopback fallback; PlayerCore remains the compatibility direct path.
///
/// Callers decide whether it fills the screen: apply `.ignoresSafeArea()` at
/// the call site for full-screen playback, and leave it off where the surface
/// is inset in other chrome, like the Next Up mini player.
struct PlayerVideoSurface: View {
    let viewModel: PlayerViewModel

    var body: some View {
        switch viewModel.activePlayer {
        case .none:
            Color.black
        case .avPlayer(let backend):
            AVPlayerSurface(
                backend: backend,
                videoGravity: viewModel.settings.videoGravity.avGravity
            )
        case .coreMedia(let core):
            PlayerSurface(
                player: core,
                videoGravity: viewModel.settings.videoGravity.avGravity
            )
        }
    }
}

/// Spinner shown while the decoder opens the file. Sized by the caller, since
/// the only thing that differs between platforms is how big it should be.
struct PlayerLoadingIndicator: View {
    let scale: CGFloat
    let size: CGFloat

    var body: some View {
        ProgressView()
            .progressViewStyle(.circular)
            .tint(.white)
            .scaleEffect(scale)
            .frame(width: size, height: size)
            .siloPlayerGlass(in: .rect(cornerRadius: 8))
            .shadow(color: .black.opacity(0.45), radius: 24, y: 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .allowsHitTesting(false)
            .transition(.opacity)
            .accessibilityLabel("Loading video")
    }
}

/// Terminal playback failure, with the two ways out.
struct PlayerErrorView: View {
    let message: String
    let onRetry: () -> Void
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color.continuumError)

            Text(message)
                .font(.continuumBody)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            HStack(spacing: 16) {
                Button("Retry", action: onRetry)
                    .siloPrimaryButton()
                    .frame(minWidth: 140)

                Button("Go Back", action: onBack)
                    .siloPrimaryButton()
                    .frame(minWidth: 140)
            }
        }
    }
}
