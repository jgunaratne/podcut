import SwiftUI

/// Mini player bar that floats above the tab bar.
struct MiniPlayerView: View {
    @Environment(AudioPlayerManager.self) private var player
    @Binding var showNowPlaying: Bool

    var body: some View {
        if let episode = player.currentEpisode {
            VStack(spacing: 0) {
                // Progress bar at the top of the mini player.
                GeometryReader { geo in
                    Rectangle()
                        .fill(.indigo)
                        .frame(width: max(geo.size.width * player.playbackProgress, 0))
                }
                .frame(height: 2)
                .background(Color(.systemGray5))

                HStack(spacing: 12) {
                    // Episode artwork thumbnail — tap to open Now Playing.
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showNowPlaying = true
                    } label: {
                        HStack(spacing: 10) {
                            AsyncImage(url: episode.artworkURL) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                default:
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(.quaternary)
                                        .overlay {
                                            Image(systemName: "waveform")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .symbolEffect(.variableColor.iterative, isActive: player.isPlaying)
                                        }
                                }
                            }
                            .frame(width: 42, height: 42)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(episode.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)

                                Text(player.formattedTime(player.currentTime) + " / " + player.formattedTime(player.duration))
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    Spacer(minLength: 4)

                    // Play/Pause button.
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        player.togglePlayPause()
                    } label: {
                        Image(
                            systemName: player.isPlaying
                                ? "pause.fill" : "play.fill"
                        )
                        .font(.title3.weight(.semibold))
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    // Skip forward button.
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        player.skipForward()
                    } label: {
                        Image(systemName: "forward.30")
                            .font(.subheadline)
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .foregroundStyle(.primary)
                .padding(.leading, 12)
                .padding(.trailing, 8)
                .padding(.vertical, 8)
            }
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
            .padding(.horizontal, 12)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}
