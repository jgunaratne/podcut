import SwiftUI

/// Mini player bar that floats above the tab bar.
struct MiniPlayerView: View {
    @Environment(AudioPlayerManager.self) private var player
    @Binding var showNowPlaying: Bool

    var body: some View {
        if let episode = player.currentEpisode {
            HStack(spacing: 12) {
                // Episode artwork thumbnail — tap to open Now Playing.
                Button {
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
                                    }
                            }
                        }
                        .frame(width: 38, height: 38)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(episode.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)

                            GeometryReader { geo in
                                Capsule()
                                    .fill(.quaternary)
                                    .overlay(alignment: .leading) {
                                        Capsule()
                                            .fill(.tint)
                                            .frame(
                                                width: max(
                                                    geo.size.width
                                                        * player.playbackProgress, 0))
                                    }
                            }
                            .frame(height: 3)
                        }
                    }
                }
                .buttonStyle(.plain)

                // Play/Pause button.
                Button {
                    player.togglePlayPause()
                } label: {
                    Image(
                        systemName: player.isPlaying
                            ? "pause.fill" : "play.fill"
                    )
                    .font(.title3)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                // Skip forward button.
                Button {
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
            .padding(.leading, 10)
            .padding(.trailing, 8)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(.horizontal, 12)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}
