import SwiftUI

/// Detail view for a selected podcast — shows artwork, star button, and episodes.
struct PodcastDetailView: View {
    let podcast: Podcast

    @Environment(FavoritesStore.self) private var favorites
    @Environment(AudioPlayerManager.self) private var player
    @State private var episodes: [Episode] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header artwork.
                headerSection

                // Episodes list.
                episodesSection
            }
        }
        .navigationTitle(podcast.collectionName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation(.spring(duration: 0.35)) {
                        favorites.toggle(podcast)
                    }
                } label: {
                    Image(
                        systemName: favorites.isFavorite(podcast)
                            ? "star.fill" : "star"
                    )
                    .foregroundStyle(
                        favorites.isFavorite(podcast)
                            ? .yellow : .secondary
                    )
                    .symbolEffect(
                        .bounce, value: favorites.isFavorite(podcast))
                }
            }
        }
        .task {
            await loadEpisodes()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 16) {
            AsyncImage(url: URL(string: podcast.artworkUrl600)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                default:
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.quaternary)
                        .aspectRatio(1, contentMode: .fit)
                        .overlay {
                            Image(systemName: "mic.fill")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .frame(width: 220, height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.25), radius: 20, y: 10)

            VStack(spacing: 6) {
                Text(podcast.collectionName)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)

                Text(podcast.artistName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let genre = podcast.primaryGenreName {
                    Text(genre)
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial, in: Capsule())
                }
            }
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Episodes

    private var episodesSection: some View {
        LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders)
        {
            Section {
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding(40)
                        Spacer()
                    }
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
                    ForEach(episodes) { episode in
                        EpisodeRowView(episode: episode)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                player.play(episode: episode)
                            }
                        Divider()
                            .padding(.leading)
                    }
                }
            } header: {
                Text("Episodes")
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.bar)
            }
        }
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
            episodes = try await parser.parse(feedURL: feedURL)
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }
}
