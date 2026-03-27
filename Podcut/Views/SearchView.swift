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

    /// Category topics with SF Symbols and accent colors.
    private let categories: [(icon: String, name: String, color: Color)] = [
        ("desktopcomputer", "Technology", .blue),
        ("chart.bar", "Business", .green),
        ("theatermasks", "Comedy", .orange),
        ("flask", "Science", .purple),
        ("books.vertical", "History", .brown),
        ("figure.run", "Health", .pink),
        ("music.note", "Music", .red),
        ("magnifyingglass", "True Crime", .indigo),
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
                    }
                    .listStyle(.plain)
                    .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 80) }
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
            .task(priority: .high, id: debouncedQuery) {
                guard !debouncedQuery.isEmpty else { return }
                await performSearch(debouncedQuery)
            }
            .task(priority: .high) {
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
            VStack(alignment: .leading, spacing: 28) {

                // MARK: Hero — Featured podcast (first trending)
                if let featured = trendingPodcasts.first {
                    NavigationLink(value: featured) {
                        ZStack(alignment: .bottomLeading) {
                            AsyncImage(url: URL(string: featured.artworkUrl600)) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                default:
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(.quaternary)
                                        .aspectRatio(1, contentMode: .fit)
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                            // Glass overlay with podcast info.
                            VStack(alignment: .leading, spacing: 4) {
                                Text("#1 Trending")
                                    .font(.caption.weight(.bold))
                                    .textCase(.uppercase)
                                    .foregroundStyle(.blue)

                                Text(featured.collectionName)
                                    .font(.title3.bold())
                                    .foregroundStyle(.primary)
                                    .lineLimit(2)

                                Text(featured.artistName)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .glassEffect(.regular, in: .rect(cornerRadius: 20))
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                }

                // MARK: Categories
                VStack(alignment: .leading, spacing: 14) {
                    Text("Browse")
                        .font(.title2.bold())
                        .padding(.horizontal)

                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 12) {
                            ForEach(categories, id: \.name) { category in
                                Button {
                                    query = category.name
                                    debouncedQuery = category.name
                                } label: {
                                    VStack(spacing: 8) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .fill(category.color.opacity(0.12))
                                                .frame(width: 64, height: 64)

                                            Image(systemName: category.icon)
                                                .font(.title2)
                                                .foregroundStyle(category.color)
                                        }

                                        Text(category.name)
                                            .font(.caption.weight(.medium))
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)
                                    }
                                    .frame(width: 80)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                // MARK: Trending Grid
                if trendingPodcasts.count > 1 {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("Top Charts")
                                .font(.title2.bold())
                            Spacer()
                        }
                        .padding(.horizontal)

                        // Two-column grid for the rest of trending.
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 16),
                                GridItem(.flexible(), spacing: 16),
                            ],
                            spacing: 20
                        ) {
                            ForEach(Array(trendingPodcasts.dropFirst().enumerated()), id: \.element.id) { index, podcast in
                                NavigationLink(value: podcast) {
                                    VStack(alignment: .leading, spacing: 10) {
                                        ZStack(alignment: .topLeading) {
                                            AsyncImage(url: URL(string: podcast.artworkUrl600)) { phase in
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
                                                                .foregroundStyle(.secondary)
                                                        }
                                                }
                                            }
                                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                                            // Rank badge.
                                            Text("#\(index + 2)")
                                                .font(.caption2.bold().monospacedDigit())
                                                .foregroundStyle(.white)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(.black.opacity(0.5), in: Capsule())
                                                .padding(8)
                                        }

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
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                Spacer(minLength: 20)
            }
            .padding(.top, 8)
        }
        .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 80) }
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
        do {
            trendingPodcasts = try await service.fetchTopPodcasts(limit: 12)
        } catch {
            do {
                trendingPodcasts = try await service.search(query: "popular podcasts")
                if trendingPodcasts.count > 12 {
                    trendingPodcasts = Array(trendingPodcasts.prefix(12))
                }
            } catch {
                // Non-critical.
            }
        }
    }
}

// MARK: - Podcast Row

struct PodcastRowView: View {
    let podcast: Podcast

    var body: some View {
        HStack(spacing: 16) {
            AsyncImage(url: URL(string: podcast.artworkUrl600)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(1, contentMode: .fit)
                default:
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.quaternary)
                        .overlay {
                            Image(systemName: "waveform")
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

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
