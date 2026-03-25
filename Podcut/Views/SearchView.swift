import SwiftUI

/// Search tab — find podcasts via the iTunes Search API.
struct SearchView: View {
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
        ("🧠", "Technology"),
        ("💰", "Business"),
        ("🎭", "Comedy"),
        ("🔬", "Science"),
        ("📖", "History"),
        ("🏋️", "Health & Fitness"),
        ("🎵", "Music"),
        ("🔎", "True Crime"),
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
                    List(results) { podcast in
                        NavigationLink(value: podcast) {
                            PodcastRowView(podcast: podcast)
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
                        ForEach(discoverTopics, id: \.1) { emoji, topic in
                            Button {
                                query = topic
                                debouncedQuery = topic
                            } label: {
                                HStack(spacing: 8) {
                                    Text(emoji)
                                        .font(.title3)
                                    Text(topic)
                                        .font(.subheadline.weight(.medium))
                                        .lineLimit(1)
                                    Spacer()
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(.indigo.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                                .foregroundStyle(.primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }

                // Trending section.
                if !trendingPodcasts.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Trending")
                            .font(.title2.bold())
                            .padding(.horizontal)

                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 14) {
                                ForEach(trendingPodcasts) { podcast in
                                    NavigationLink(value: podcast) {
                                        VStack(spacing: 8) {
                                            AsyncImage(url: URL(string: podcast.artworkUrl600)) { phase in
                                                switch phase {
                                                case .success(let image):
                                                    image
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fill)
                                                default:
                                                    RoundedRectangle(cornerRadius: 14)
                                                        .fill(.quaternary)
                                                        .overlay {
                                                            Image(systemName: "mic.fill")
                                                                .foregroundStyle(.secondary)
                                                        }
                                                }
                                            }
                                            .frame(width: 140, height: 140)
                                            .clipShape(RoundedRectangle(cornerRadius: 14))
                                            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)

                                            Text(podcast.collectionName)
                                                .font(.caption.weight(.medium))
                                                .lineLimit(2)
                                                .multilineTextAlignment(.center)
                                                .foregroundStyle(.primary)

                                            Text(podcast.artistName)
                                                .font(.caption2)
                                                .lineLimit(1)
                                                .foregroundStyle(.secondary)
                                        }
                                        .frame(width: 140)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }

                Spacer(minLength: 40)
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
        HStack(spacing: 14) {
            // Use smaller artwork (100px) for list rows instead of 600px.
            AsyncImage(url: URL(string: podcast.artworkUrl100)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                default:
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.quaternary)
                        .overlay {
                            Image(systemName: "mic.fill")
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(podcast.collectionName)
                    .font(.headline)
                    .lineLimit(2)

                Text(podcast.artistName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let genre = podcast.primaryGenreName {
                    Text(genre)
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.indigo.opacity(0.1), in: Capsule())
                        .foregroundStyle(.indigo)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
