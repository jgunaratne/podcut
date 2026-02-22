import SwiftUI

/// Full-screen now-playing view with Liquid Glass controls.
struct NowPlayingView: View {
    @Environment(AudioPlayerManager.self) private var player
    @Environment(\.dismiss) private var dismiss

    @State private var dragProgress: Double?

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle.
            Capsule()
                .fill(.tertiary)
                .frame(width: 36, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 24)

            Spacer()

            // Artwork placeholder.
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [
                            .purple.opacity(0.5),
                            .blue.opacity(0.4),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 280, height: 280)
                .overlay {
                    Image(systemName: "waveform")
                        .font(.system(size: 56, weight: .thin))
                        .foregroundStyle(.white.opacity(0.7))
                        .symbolEffect(
                            .variableColor.iterative,
                            isActive: player.isPlaying)
                }
                .shadow(color: .purple.opacity(0.25), radius: 24, y: 12)

            Spacer()
                .frame(height: 36)

            // Episode info.
            VStack(spacing: 6) {
                Text(player.currentEpisode?.title ?? "Not Playing")
                    .font(.title3.bold())
                    .multilineTextAlignment(.center)
                    .lineLimit(3)

                Text(player.currentEpisode?.pubDate ?? "")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 32)

            Spacer()
                .frame(height: 32)

            // Scrubber.
            VStack(spacing: 4) {
                Slider(
                    value: Binding(
                        get: { dragProgress ?? player.playbackProgress },
                        set: { newValue in
                            dragProgress = newValue
                        }
                    ),
                    in: 0...1,
                    onEditingChanged: { editing in
                        if !editing, let progress = dragProgress {
                            player.seek(to: progress)
                            dragProgress = nil
                        }
                    }
                )
                .tint(.primary)

                HStack {
                    Text(player.formattedTime(player.currentTime))
                    Spacer()
                    Text(
                        "-"
                            + player.formattedTime(
                                max(player.duration - player.currentTime, 0)))
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 32)

            Spacer()
                .frame(height: 28)

            // Playback controls.
            HStack(spacing: 44) {
                Button { player.skipBackward() } label: {
                    Image(systemName: "gobackward.15")
                        .font(.title2)
                }

                Button { player.togglePlayPause() } label: {
                    Image(
                        systemName: player.isPlaying
                            ? "pause.circle.fill" : "play.circle.fill"
                    )
                    .font(.system(size: 60))
                    .contentTransition(.symbolEffect(.replace))
                }

                Button { player.skipForward() } label: {
                    Image(systemName: "goforward.30")
                        .font(.title2)
                }
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
            .glassEffect(.regular, in: .capsule)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color.purple.opacity(0.06),
                    Color.blue.opacity(0.04),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }
}
