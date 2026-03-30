import SwiftUI

/// Detail view for a selected podcast — Apple Podcasts-style layout.
struct PodcastDetailView: View {
    let podcast: Podcast

    @Environment(FavoritesStore.self) private var favorites
    @Environment(AudioPlayerManager.self) private var player
    @State private var episodes: [Episode] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var podcastDescription: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                darkHeroSection
                lightContentSection
            }
        }
        .navigationTitle(podcast.collectionName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.black, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(duration: 0.35)) {
                        favorites.toggle(podcast)
                    }
                } label: {
                    Image(systemName: favorites.isFavorite(podcast) ? "star.fill" : "star")
                        .foregroundStyle(favorites.isFavorite(podcast) ? .yellow : .secondary)
                        .symbolEffect(.bounce, value: favorites.isFavorite(podcast))
                }
            }
        }
        .task(priority: .high) {
            await loadEpisodes()
        }
    }

    // MARK: - Dark Hero Section

    private var darkHeroSection: some View {
        VStack(spacing: 14) {
            // Artwork
            AsyncImage(url: URL(string: podcast.artworkUrl600)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemGray4))
                        .overlay {
                            Image(systemName: "mic")
                                .font(.system(size: 60))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                default:
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemGray6))
                }
            }
            .frame(width: 250, height: 250)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.6), radius: 24, y: 10)
            .padding(.top, 12)

            // Podcast name
            Text(podcast.collectionName)
                .font(.title2.bold())
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            // Artist name
            Text(podcast.artistName)
                .font(.subheadline)
                .foregroundStyle(Color(.systemGray))
                .multilineTextAlignment(.center)

            // Latest Episode button
            latestEpisodeButton
                .padding(.bottom, 28)
        }
        .frame(maxWidth: .infinity)
        .background(Color.black)
        .environment(\.colorScheme, .dark)
    }

    @ViewBuilder
    private var latestEpisodeButton: some View {
        if let first = episodes.first {
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                player.play(episode: first)
            } label: {
                Label("Latest Episode", systemImage: "play.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 10)
            }
            .glassEffect(.regular, in: .capsule)
        } else if isLoading {
            Label("Latest Episode", systemImage: "play.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.4))
                .padding(.horizontal, 22)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.1))
                .clipShape(Capsule())
        }
    }

    // MARK: - Light Content Section

    private var lightContentSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Description
            if let description = podcastDescription, !description.isEmpty {
                InlineExpandableDescription(text: description)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 12)
            }

            // Metadata row
            metadataRow
                .padding(.horizontal, 16)
                .padding(.bottom, 16)

            Divider()

            // Episodes header + list
            episodesSection
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
    }

    private var metadataRow: some View {
        HStack(spacing: 4) {
            Text("★ 4 (9.8K)")
            if let genre = podcast.primaryGenreName {
                Text("·")
                Text(genre)
            }
            Text("·")
            Text("Updated Weekly")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    // MARK: - Episodes Section

    private var episodesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Text("Episodes")
                    .font(.title2.bold())
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider()

            if isLoading {
                loadingSkeleton
            } else if let error = errorMessage {
                ContentUnavailableView(
                    "Unable to Load Episodes",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
                .padding()
            } else if episodes.isEmpty {
                ContentUnavailableView(
                    "No Episodes",
                    systemImage: "tray",
                    description: Text("This podcast has no episodes.")
                )
                .padding()
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(episodes) { episode in
                        NavigationLink {
                            EpisodePageView(episode: episode)
                        } label: {
                            DetailEpisodeRow(episode: episode, podcastArtworkURL: podcast.artworkUrl600)
                        }
                        .buttonStyle(.plain)

                        Divider()
                    }
                }
            }
        }
    }

    private var loadingSkeleton: some View {
        VStack(spacing: 0) {
            ForEach(0..<5, id: \.self) { _ in
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemGray5))
                            .frame(width: 50, height: 10)

                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(.systemGray5))
                            .frame(height: 14)
                            .frame(maxWidth: .infinity)

                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(.systemGray6))
                            .frame(height: 10)
                            .frame(maxWidth: .infinity)
                    }

                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                        .frame(width: 50, height: 50)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                Divider()
            }
        }
        .redacted(reason: .placeholder)
        .shimmer()
    }

    // MARK: - Loading

    private func loadEpisodes() async {
        guard let feedURLString = podcast.feedUrl,
              let feedURL = URL(string: feedURLString)
        else {
            isLoading = false
            errorMessage = "No feed URL available."
            return
        }

        do {
            let parser = RSSFeedParser()
            var parsed = try await parser.parse(feedURL: feedURL)
            let artworkURL = URL(string: podcast.artworkUrl600)
            for i in parsed.indices {
                parsed[i].artworkURL = artworkURL
            }
            episodes = parsed
            podcastDescription = parsed.first?.description
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Episode Row (Apple Podcasts style)

private struct DetailEpisodeRow: View {
    let episode: Episode
    let podcastArtworkURL: String
    @Environment(AudioPlayerManager.self) private var player

    private var isCurrentlyPlaying: Bool {
        player.currentEpisode?.id == episode.id
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(relativeDate(from: episode.pubDate))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(episode.title)
                    .font(.headline)
                    .lineLimit(2)
                    .foregroundStyle(isCurrentlyPlaying ? .blue : .primary)

                Text(episode.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            AsyncImage(url: episode.artworkURL ?? URL(string: podcastArtworkURL)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                default:
                    Color(.systemGray5)
                }
            }
            .frame(width: 50, height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(isCurrentlyPlaying ? Color.blue.opacity(0.04) : Color.clear)
        .animation(.easeInOut(duration: 0.2), value: isCurrentlyPlaying)
    }
}

// MARK: - Inline Expandable Description

private struct InlineExpandableDescription: View {
    let text: String
    @State private var isExpanded = false

    private var isLong: Bool { text.count > 120 }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(isExpanded ? nil : 3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .animation(.easeInOut(duration: 0.2), value: isExpanded)

            if isLong {
                Button(isExpanded ? "LESS" : "MORE") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.primary)
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Relative Date Helper

private func relativeDate(from pubDateString: String) -> String {
    let formats = [
        "EEE, dd MMM yyyy HH:mm:ss Z",
        "EEE, dd MMM yyyy HH:mm:ss zzz",
        "dd MMM yyyy HH:mm:ss Z",
    ]

    var parsed: Date?
    for format in formats {
        let f = DateFormatter()
        f.dateFormat = format
        f.locale = Locale(identifier: "en_US_POSIX")
        if let d = f.date(from: pubDateString) {
            parsed = d
            break
        }
    }

    guard let date = parsed else { return pubDateString }

    let seconds = Date().timeIntervalSince(date)
    switch seconds {
    case ..<3600:
        return "\(max(1, Int(seconds / 60)))m ago"
    case ..<86400:
        return "\(Int(seconds / 3600))h ago"
    case ..<604800:
        return "\(Int(seconds / 86400))d ago"
    case ..<2592000:
        return "\(Int(seconds / 604800))w ago"
    default:
        return "\(Int(seconds / 2592000))mo ago"
    }
}
