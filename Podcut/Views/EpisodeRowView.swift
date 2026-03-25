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
            ZStack {
                Circle()
                    .fill(isCurrentlyPlaying ? Color.indigo.opacity(0.15) : Color(.systemGray5))
                    .frame(width: 44, height: 44)

                Image(
                    systemName: isCurrentlyPlaying && player.isPlaying
                        ? "pause.fill" : "play.fill"
                )
                .font(.body.weight(.semibold))
                .foregroundStyle(isCurrentlyPlaying ? .indigo : .secondary)
                .contentTransition(.symbolEffect(.replace))
            }
            .symbolEffect(.pulse, isActive: isCurrentlyPlaying && player.isPlaying)

            VStack(alignment: .leading, spacing: 5) {
                Text(episode.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                    .foregroundStyle(isCurrentlyPlaying ? .indigo : .primary)

                HStack(spacing: 6) {
                    if !episode.pubDate.isEmpty {
                        Label(episode.pubDate, systemImage: "calendar")
                    }
                    if !episode.duration.isEmpty {
                        Text("·")
                        Label(episode.duration, systemImage: "clock")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .labelStyle(.titleOnly)

                // Progress bar for currently playing episode.
                if isCurrentlyPlaying {
                    GeometryReader { geo in
                        Capsule()
                            .fill(Color(.systemGray5))
                            .overlay(alignment: .leading) {
                                Capsule()
                                    .fill(.indigo)
                                    .frame(width: max(geo.size.width * player.playbackProgress, 0))
                            }
                    }
                    .frame(height: 3)
                    .clipShape(Capsule())
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            Spacer(minLength: 4)

            // Episode page button.
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
            RoundedRectangle(cornerRadius: 12)
                .fill(isCurrentlyPlaying ? Color.indigo.opacity(0.06) : Color.clear)
        )
        .animation(.easeInOut(duration: 0.2), value: isCurrentlyPlaying)
    }
}
