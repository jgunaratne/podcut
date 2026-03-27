import SwiftUI

/// Full-screen now-playing view with playback controls.
struct NowPlayingView: View {
    @Environment(AudioPlayerManager.self) private var player
    @Environment(\.dismiss) private var dismiss

    @State private var dragProgress: Double?
    @State private var playbackRate: Float = 1.0
    @State private var showEpisodePage = false

    private let availableRates: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Drag handle.
                Capsule()
                    .fill(.tertiary)
                    .frame(width: 36, height: 5)
                    .padding(.top, 10)
                    .padding(.bottom, 24)

                Spacer()

                // Artwork.
                AsyncImage(url: player.currentEpisode?.artworkURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(1, contentMode: .fit)
                    default:
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.quaternary)
                            .aspectRatio(1, contentMode: .fit)
                            .overlay {
                                Image(systemName: "waveform")
                                    .font(.system(size: 56, weight: .thin))
                                    .foregroundStyle(.secondary)
                                    .symbolEffect(
                                        .variableColor.iterative,
                                        isActive: player.isPlaying)
                            }
                    }
                }
                .frame(maxWidth: 300)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .scaleEffect(player.isPlaying ? 1.0 : 0.92)
                .animation(.spring(duration: 0.5), value: player.isPlaying)

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
                    .tint(.blue)

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
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        player.skipBackward()
                    } label: {
                        Image(systemName: "gobackward.15")
                            .font(.title2)
                    }
                    .accessibilityLabel("Skip back 15 seconds")

                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        player.togglePlayPause()
                    } label: {
                        Image(
                            systemName: player.isPlaying
                                ? "pause.circle.fill" : "play.circle.fill"
                        )
                        .font(.system(size: 60))
                        .contentTransition(.symbolEffect(.replace))
                    }
                    .accessibilityLabel(player.isPlaying ? "Pause" : "Play")

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        player.skipForward()
                    } label: {
                        Image(systemName: "goforward.30")
                            .font(.title2)
                    }
                    .accessibilityLabel("Skip forward 30 seconds")
                }
                .foregroundStyle(.primary)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .glassEffect(.regular, in: .capsule)

                Spacer()
                    .frame(height: 20)

                // Bottom actions row.
                HStack(spacing: 24) {
                    // Playback speed.
                    Menu {
                        ForEach(availableRates, id: \.self) { rate in
                            Button {
                                playbackRate = rate
                                player.setRate(rate)
                            } label: {
                                HStack {
                                    Text(rateLabel(rate))
                                    if rate == playbackRate {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Text(rateLabel(playbackRate))
                            .font(.subheadline.weight(.medium).monospacedDigit())
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .glassEffect(.regular, in: .capsule)
                    }

                    // Transcript & Chat — navigates within this sheet.
                    if player.currentEpisode != nil {
                        Button {
                            showEpisodePage = true
                        } label: {
                            Label("Transcript", systemImage: "doc.text")
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .glassEffect(.regular, in: .capsule)
                        }
                    }
                }

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .background(Color(.systemBackground).ignoresSafeArea())
            .navigationDestination(isPresented: $showEpisodePage) {
                if let episode = player.currentEpisode {
                    EpisodePageView(episode: episode, inlineWithMiniPlayer: false)
                }
            }
        }
    }

    private func rateLabel(_ rate: Float) -> String {
        if rate == 1.0 { return "1×" }
        if rate == 0.5 { return "0.5×" }
        if rate == 0.75 { return "0.75×" }
        if rate == 1.25 { return "1.25×" }
        if rate == 1.5 { return "1.5×" }
        if rate == 2.0 { return "2×" }
        return "\(rate)×"
    }
}
