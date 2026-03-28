import SwiftUI

/// Mini player bar that floats above the tab bar.
struct MiniPlayerView: View {
    @Environment(AudioPlayerManager.self) private var player
    @Binding var showNowPlaying: Bool

    var body: some View {
        if let episode = player.currentEpisode {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    // Episode artwork thumbnail — tap to open Now Playing.
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showNowPlaying = true
                    } label: {
                        HStack(spacing: 12) {
                            AsyncImage(url: episode.artworkURL) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(1, contentMode: .fit)
                                default:
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(.quaternary)
                                        .overlay {
                                            Image(systemName: "waveform")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .symbolEffect(.variableColor.iterative, isActive: player.isPlaying)
                                        }
                                }
                            }
                            .frame(width: 46, height: 46)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                            VStack(alignment: .leading, spacing: 3) {
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
                    if player.isLoading {
                        ProgressView()
                            .frame(width: 44, height: 44)
                    } else {
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            player.togglePlayPause()
                        } label: {
                            Image(
                                systemName: player.isPlaying
                                    ? "pause.fill" : "play.fill"
                            )
                            .font(.title2)
                            .contentTransition(.symbolEffect(.replace))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(player.isPlaying ? "Pause" : "Play")
                    }

                    // Skip forward button.
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        player.skipForward()
                    } label: {
                        Image(systemName: "goforward.30")
                            .font(.title3)
                            .frame(width: 40, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Skip forward 30 seconds")
                    .padding(.trailing, 4)
                }
                .padding(.leading, 10)
                .padding(.vertical, 8)

                // Progress bar.
                GeometryReader { geo in
                    Rectangle()
                        .fill(Color.blue.opacity(0.15))
                        .overlay(alignment: .leading) {
                            Rectangle()
                                .fill(Color.blue)
                                .frame(width: max(geo.size.width * player.playbackProgress, 0))
                        }
                }
                .frame(height: 3)
            }
            .glassEffect(.regular, in: .rect(cornerRadius: 16))
            .padding(.horizontal, 12)
            .padding(.top, 6)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}
