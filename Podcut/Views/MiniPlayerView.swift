import SwiftUI

/// Mini player bar that floats above the tab bar using Liquid Glass.
struct MiniPlayerView: View {
    @Environment(AudioPlayerManager.self) private var player
    @Binding var showNowPlaying: Bool

    var body: some View {
        if let episode = player.currentEpisode {
            HStack(spacing: 14) {
                // Episode info — tap to expand.
                VStack(alignment: .leading, spacing: 4) {
                    Text(episode.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)

                    // Progress bar.
                    GeometryReader { geo in
                        Capsule()
                            .fill(.quaternary)
                            .overlay(alignment: .leading) {
                                Capsule()
                                    .fill(.tint)
                                    .frame(
                                        width: max(
                                            geo.size.width * player.playbackProgress, 0))
                            }
                    }
                    .frame(height: 3)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    showNowPlaying = true
                }

                Spacer(minLength: 0)

                // Controls — pinned to the right.
                HStack(spacing: 8) {
                    Button {
                        player.togglePlayPause()
                    } label: {
                        Image(
                            systemName: player.isPlaying
                                ? "pause.fill" : "play.fill"
                        )
                        .font(.title3)
                        .contentTransition(.symbolEffect(.replace))
                    }
                    .frame(width: 40, height: 40)

                    Button {
                        player.skipForward()
                    } label: {
                        Image(systemName: "forward.30")
                            .font(.subheadline)
                    }
                    .frame(width: 32, height: 32)
                }
                .foregroundStyle(.primary)
            }
            .padding(.leading, 16)
            .padding(.trailing, 10)
            .padding(.vertical, 10)
            .glassEffect(.regular.interactive(), in: .capsule)
            .padding(.horizontal, 12)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}
