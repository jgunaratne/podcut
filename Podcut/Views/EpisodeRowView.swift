import SwiftUI

/// A row displaying an episode's info and play button.
struct EpisodeRowView: View {
    let episode: Episode
    @Environment(AudioPlayerManager.self) private var player

    private var isCurrentlyPlaying: Bool {
        player.currentEpisode?.id == episode.id
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                // Play indicator / button.
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    if isCurrentlyPlaying {
                        player.togglePlayPause()
                    } else {
                        player.play(episode: episode)
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(isCurrentlyPlaying ? Color.blue.opacity(0.15) : Color(.systemGray5))
                            .frame(width: 48, height: 48)

                        if isCurrentlyPlaying && player.isLoading {
                            ProgressView()
                                .tint(.blue)
                        } else {
                            Image(
                                systemName: isCurrentlyPlaying && player.isPlaying
                                    ? "pause.fill" : "play.fill"
                            )
                            .font(.title3)
                            .foregroundStyle(isCurrentlyPlaying ? .blue : .primary)
                            .contentTransition(.symbolEffect(.replace))
                        }
                    }
                    .symbolEffect(.pulse, isActive: isCurrentlyPlaying && player.isPlaying)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 6) {
                    Text(episode.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                        .foregroundStyle(isCurrentlyPlaying ? .blue : .primary)

                    HStack(spacing: 6) {
                        if !episode.pubDate.isEmpty {
                            Label(episode.pubDate, systemImage: "calendar")
                        }
                        if !episode.duration.isEmpty {
                            Text("·")
                            Label(episode.duration, systemImage: "clock")
                        }
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .labelStyle(.titleOnly)

                    // Progress bar for currently playing episode.
                    if isCurrentlyPlaying {
                        GeometryReader { geo in
                            Capsule()
                                .fill(Color(.systemGray5))
                                .overlay(alignment: .leading) {
                                    Capsule()
                                        .fill(.blue)
                                        .frame(width: max(geo.size.width * player.playbackProgress, 0))
                                }
                        }
                        .frame(height: 4)
                        .clipShape(Capsule())
                        .padding(.top, 4)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }

                Spacer(minLength: 4)
                
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal)
            .padding(.vertical, 14)
            .background(isCurrentlyPlaying ? Color.blue.opacity(0.04) : Color.clear)
            .animation(.easeInOut(duration: 0.2), value: isCurrentlyPlaying)
            
            Divider()
                .padding(.leading, 76)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(episode.title). \(episode.pubDate). \(episode.duration)")
        .accessibilityHint(isCurrentlyPlaying ? "Currently playing. Tap to pause." : "Tap to play.")
    }
}
