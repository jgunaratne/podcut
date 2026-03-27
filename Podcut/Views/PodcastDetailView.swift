import SwiftUI

private enum Constants {
    static let headerHeight: CGFloat = 350
}

/// Detail view for a selected podcast — shows artwork, star button, and episodes.
struct PodcastDetailView: View {
    let podcast: Podcast

    @Environment(FavoritesStore.self) private var favorites
    @Environment(AudioPlayerManager.self) private var player
    @State private var episodes: [Episode] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var headerVisible = true

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Parallax header.
                GeometryReader { geo in
                    let minY = geo.frame(in: .global).minY
                    let isScrolled = minY <= 0

                    ZStack(alignment: .bottom) {
                        artwork(minY: minY)
                        headerInfo()
                            .offset(y: isScrolled ? abs(minY) / 1.5 : 0)
                    }
                    .frame(
                        width: geo.size.width,
                        height: Constants.headerHeight + max(minY, 0)
                    )
                    .onAppear { headerVisible = true }
                    .onDisappear { headerVisible = false }
                }
                .frame(height: Constants.headerHeight)
                
                // Episodes list.
                episodesSection
            }
        }
        .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 80) }
        .navigationTitle(headerVisible ? "" : podcast.collectionName)
        .navigationBarTitleDisplayMode(.inline)
        .ignoresSafeArea(edges: .top)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
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
                    .symbolEffect(.bounce, value: favorites.isFavorite(podcast))
                }
            }
        }
        .task {
            await loadEpisodes()
        }
    }

    // MARK: - Header

    private func artwork(minY: CGFloat) -> some View {
        AsyncImage(url: URL(string: podcast.artworkUrl600)) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            default:
                Rectangle()
                    .fill(.quaternary)
                    .overlay {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .frame(height: Constants.headerHeight + max(minY, 0))
        .scaleEffect(max(1, 1 + (minY / 200)))
        .offset(y: -minY)
        .clipped()
        .overlay(
            LinearGradient(
                colors: [.black.opacity(0.6), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(
            LinearGradient(
                colors: [.black.opacity(0.4), .clear],
                startPoint: .bottom,
                endPoint: .center
            )
        )
    }

    private func headerInfo() -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                if let genre = podcast.primaryGenreName {
                    Text(genre.uppercased())
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white.opacity(0.7))
                        .tracking(1)
                }

                Text(podcast.collectionName)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    

                Text(podcast.artistName)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))
            }

            Spacer()

            Button {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                withAnimation(.spring(duration: 0.35)) {
                    favorites.toggle(podcast)
                }
            } label: {
                Image(systemName: favorites.isFavorite(podcast) ? "star.fill" : "star")
                    .font(.title2)
                    .foregroundStyle(favorites.isFavorite(podcast) ? .yellow : .white)
                    .symbolEffect(.bounce, value: favorites.isFavorite(podcast))
                    .frame(width: 44, height: 44)
                    .glassEffect(.regular, in: .circle)
            }
        }
        .padding(20)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
        .environment(\.colorScheme, .dark)
        .padding()
    }

    // MARK: - Episodes

    private var episodesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Episodes")
                .font(.headline)
                .padding(.horizontal)
                .padding(.vertical, 10)
            
            if isLoading {
                VStack(spacing: 0) {
                    ForEach(0..<5, id: \.self) { _ in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color(.systemGray5))
                                .frame(width: 44, height: 44)

                            VStack(alignment: .leading, spacing: 8) {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(.systemGray5))
                                    .frame(height: 14)
                                    .frame(maxWidth: .infinity)

                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(.systemGray6))
                                    .frame(width: 120, height: 10)
                            }

                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 14)

                        Divider().padding(.leading, 76)
                    }
                }
                .redacted(reason: .placeholder)
                .shimmer()
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
                            EpisodeRowView(episode: episode)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.vertical)
        .background(.background)
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
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }
}
