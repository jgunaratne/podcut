import SwiftUI

/// Search tab — find podcasts via the iTunes Search API.
struct SearchView: View {
    @Environment(AudioPlayerManager.self) private var player
    @Environment(FavoritesStore.self) private var favorites
    @State private var query = ""
    @State private var debouncedQuery = ""
    @State private var results: [Podcast] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var trendingPodcasts: [Podcast] = []

    private let service = PodcastSearchService()

    /// Popular search terms to seed discovery.
    private let discoverTopics = [
        ("cpu", "Technology"),
        ("chart.bar.fill", "Business"),
        ("theatermasks.fill", "Comedy"),
        ("flask.fill", "Science"),
        ("books.vertical.fill", "History"),
        ("figure.run", "Health & Fitness"),
        ("music.note", "Music"),
        ("fingerprint", "True Crime"),
    ]

    var body: some View {
        NavigationStack {
            Group {
                if let error = errorMessage, results.isEmpty {
                    ContentUnavailableView(
                        "Search Failed",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                } else if results.isEmpty && !isSearching && query.isEmpty {
                    // Discovery view when no search is active.
                    discoverView
                } else if results.isEmpty && !isSearching {
                    ContentUnavailableView(
                        "No Results",
                        systemImage: "magnifyingglass",
                        description: Text("Try a different search term.")
                    )
                } else {
                    List {
                        ForEach(results) { podcast in
                            NavigationLink(value: podcast) {
                                PodcastRowView(podcast: podcast)
                                    .padding(.vertical, 4)
                            }
                            .listRowSeparator(.hidden)
                        }
                        
                        // Invisible padding element to push content above the mini player
                        if player.currentEpisode != nil {
                            Color.clear.frame(height: 75)
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Search")
            .searchable(
                text: $query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Podcast name or topic"
            )
            .onSubmit(of: .search) {
                debouncedQuery = query
            }
            .task(id: query) {
                // Debounce: wait before updating debouncedQuery.
                if query.isEmpty {
                    debouncedQuery = ""
                    results = []
                    errorMessage = nil
                    return
                }
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { return }
                debouncedQuery = query
            }
            .task(id: debouncedQuery) {
                // Only perform network call when debounced query changes.
                guard !debouncedQuery.isEmpty else { return }
                await performSearch(debouncedQuery)
            }
            .task {
                // Load trending podcasts on first appear.
                if trendingPodcasts.isEmpty {
                    await loadTrending()
                }
            }
            .navigationDestination(for: Podcast.self) { podcast in
                PodcastDetailView(podcast: podcast)
            }
            .overlay {
                if isSearching {
                    ProgressView()
                        .scaleEffect(1.5)
                }
            }
        }
        // Force the background of the entire tab to extend to bottom
        .background(Color(.systemBackground).ignoresSafeArea())
    }

    // MARK: - Discover View

    private var discoverView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Browse by category.
                VStack(alignment: .leading, spacing: 12) {
                    Text("Browse")
                        .font(.title2.bold())
                        .padding(.horizontal)

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 10),
                            GridItem(.flexible(), spacing: 10),
                        ],
                        spacing: 10
                    ) {
                        ForEach(discoverTopics, id: \.1) { iconName, topic in
                            Button {
                                query = topic
                                debouncedQuery = topic
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: iconName)
                                        .font(.title3)
                                        .foregroundStyle(.blue)
                                        .frame(width: 24)
                                        
                                    Text(topic)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                    Spacer()
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 10)
                                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }

                // Trending section.
                if !trendingPodcasts.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Trending Podcasts")
                            .font(.title2.bold())
                            .padding(.horizontal)

                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 16) {
                                ForEach(trendingPodcasts) { podcast in
                                    NavigationLink(value: podcast) {
                                        VStack(alignment: .leading, spacing: 10) {
                                            AsyncImage(url: URL(string: podcast.artworkUrl600)) { phase in
                                                switch phase {
                                                case .success(let image):
                                                    image
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fill)
                                                default:
                                                    RoundedRectangle(cornerRadius: 16)
                                                        .fill(.quaternary)
                                                        .overlay {
                                                            Image(systemName: "mic.fill")
                                                                .foregroundStyle(.secondary)
                                                        }
                                                }
                                            }
                                            .frame(width: 150, height: 150)
                                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                            .shadow(color: .black.opacity(0.12), radius: 10, y: 6)

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(podcast.collectionName)
                                                    .font(.subheadline.weight(.semibold))
                                                    .lineLimit(2)
                                                    .foregroundStyle(.primary)

                                                Text(podcast.artistName)
                                                    .font(.caption)
                                                    .lineLimit(1)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        .frame(width: 150)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 20)
                        }
                    }
                }

                Spacer(minLength: player.currentEpisode != nil ? 100 : 40)
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Network

    private func performSearch(_ searchQuery: String) async {
        isSearching = true
        errorMessage = nil
        defer { isSearching = false }
        do {
            results = try await service.search(query: searchQuery)
        } catch {
            if !Task.isCancelled {
                results = []
                errorMessage = error.localizedDescription
            }
        }
    }

    private func loadTrending() async {
        // Use the iTunes top podcasts feed or a generic popular search.
        do {
            trendingPodcasts = try await service.search(query: "top podcasts 2026")
            // Keep only a reasonable number for the carousel.
            if trendingPodcasts.count > 12 {
                trendingPodcasts = Array(trendingPodcasts.prefix(12))
            }
        } catch {
            // Non-critical — just show no trending section.
        }
    }
}

/// A single row in the podcast search results list.
struct PodcastRowView: View {
    let podcast: Podcast

    var body: some View {
        HStack(spacing: 16) {
            // Use smaller artwork (100px) for list rows instead of 600px.
            AsyncImage(url: URL(string: podcast.artworkUrl100)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                default:
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.quaternary)
                        .overlay {
                            Image(systemName: "mic.fill")
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 6, y: 3)

            VStack(alignment: .leading, spacing: 4) {
                Text(podcast.collectionName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(podcast.artistName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let genre = podcast.primaryGenreName {
                    Text(genre)
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.blue.opacity(0.1), in: Capsule())
                        .foregroundStyle(.blue)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}

