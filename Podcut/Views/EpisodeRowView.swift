import SwiftUI

/// A row displaying an episode's info and play button.
struct EpisodeRowView: View {
    let episode: Episode
    @Environment(AudioPlayerManager.self) private var player

    private var isCurrentlyPlaying: Bool {
        player.currentEpisode?.id == episode.id
    }

    var body: some View {
        HStack(spacing: 12) {
            // Play indicator / button.
            Image(
                systemName: isCurrentlyPlaying && player.isPlaying
                    ? "pause.circle.fill" : "play.circle.fill"
            )
            .font(.title)
            .foregroundStyle(
                isCurrentlyPlaying
                    ? AnyShapeStyle(.tint)
                    : AnyShapeStyle(.secondary)
            )
            .symbolEffect(.pulse, isActive: isCurrentlyPlaying && player.isPlaying)

            VStack(alignment: .leading, spacing: 4) {
                Text(episode.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)

                HStack(spacing: 8) {
                    if !episode.pubDate.isEmpty {
                        Text(episode.pubDate)
                    }
                    if !episode.duration.isEmpty {
                        Text("·")
                        Text(episode.duration)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            // Transcribe button.
            if episode.audioURL != nil {
                NavigationLink {
                    EpisodePageView(episode: episode)
                } label: {
                    Image(systemName: "text.below.photo")
                        .font(.body)
                        .foregroundStyle(.indigo)
                        .frame(width: 34, height: 34)
                        .background(.indigo.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(
            isCurrentlyPlaying
                ? Color.accentColor.opacity(0.08)
                : Color.clear
        )
        .animation(.easeInOut(duration: 0.2), value: isCurrentlyPlaying)
    }
}
