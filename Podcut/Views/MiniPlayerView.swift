import SwiftUI

/// Mini player bar that floats above the tab bar using Liquid Glass.
struct MiniPlayerView: View {
    @Environment(AudioPlayerManager.self) private var player
    @Binding var showNowPlaying: Bool

    var body: some View {
        if let episode = player.currentEpisode {
            HStack(spacing: 12) {
                // Episode title — tap to expand.
                VStack(alignment: .leading, spacing: 2) {
                    Text(episode.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)

                    // Progress bar.
                    GeometryReader { geo in
                        Capsule()
                            .fill(.quaternary)
                            .frame(height: 3)
                            .overlay(alignment: .leading) {
                                Capsule()
                                    .fill(.tint)
                                    .frame(
                                        width: geo.size.width
                                            * player.playbackProgress,
                                        height: 3)
                            }
                    }
                    .frame(height: 3)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    showNowPlaying = true
                }

                // Controls.
                Button {
                    player.togglePlayPause()
                } label: {
                    Image(
                        systemName: player.isPlaying
                            ? "pause.fill" : "play.fill"
                    )
                    .font(.title3)
                    .frame(width: 36, height: 36)
                }

                Button {
                    player.skipForward()
                } label: {
                    Image(systemName: "forward.30")
                        .font(.subheadline)
                        .frame(width: 28, height: 28)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .glassEffect(.regular.interactive(), in: .capsule)
            .padding(.horizontal, 12)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}
