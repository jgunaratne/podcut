import SwiftUI

/// Search tab — find podcasts via the iTunes Search API.
struct SearchView: View {
    @Environment(FavoritesStore.self) private var favorites
    @State private var query = ""
    @State private var debouncedQuery = ""
    @State private var results: [Podcast] = []
    @State private var isSearching = false
    @State private var errorMessage: String?

    private let service = PodcastSearchService()

    var body: some View {
        NavigationStack {
            Group {
                if let error = errorMessage, results.isEmpty {
                    ContentUnavailableView(
                        "Search Failed",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                } else if results.isEmpty && !isSearching {
                    ContentUnavailableView(
                        "Search Podcasts",
                        systemImage: "magnifyingglass",
                        description: Text(
                            "Find your next favorite show.")
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
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
