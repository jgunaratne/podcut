import SwiftUI

// MARK: - Data Model

/// Pairs a favorited podcast with its latest episode for the Up Next section.
struct UpNextItem: Identifiable {
    let id: Int  // podcast.id
    let podcast: Podcast
    let episode: Episode
}

// MARK: - HomeView

struct HomeView: View {
    @Environment(FavoritesStore.self) private var favorites
    @Environment(AudioPlayerManager.self) private var player

    @State private var upNextItems: [UpNextItem] = []
    @State private var suggestedPodcasts: [Podcast] = []
    @State private var isLoadingUpNext = false

    private let service = PodcastSearchService()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    upNextSection
                    youMightLikeSection
                    Spacer(minLength: 20)
                }
                .padding(.top, 8)
            }
            .navigationTitle("Home")
            .navigationDestination(for: Podcast.self) { podcast in
                PodcastDetailView(podcast: podcast)
            }
        }
        .task {
            await loadUpNext()
        }
        .task {
            if suggestedPodcasts.isEmpty {
                await loadSuggestions()
            }
        }
    }

    // MARK: - Up Next Section

    @ViewBuilder
    private var upNextSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Up Next")
                .font(.title2.bold())
                .padding(.horizontal)

            if favorites.podcasts.isEmpty {
                Text("Follow podcasts to see new episodes here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
            } else if isLoadingUpNext && upNextItems.isEmpty {
                // Skeleton placeholders
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
                        ForEach(0..<min(3, favorites.podcasts.count), id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(.quaternary)
                                .frame(width: 280, height: 200)
                        }
                    }
                    .padding(.horizontal)
                }
            } else if !upNextItems.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
                        ForEach(upNextItems) { item in
                            UpNextCard(item: item)
                        }
                    }
                    .padding(.horizontal)
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
            }
        }
    }

    // MARK: - You Might Like Section

    private var youMightLikeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("You Might Like")
                    .font(.title2.bold())
                Text("Based on your listening.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            if suggestedPodcasts.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
                        ForEach(suggestedPodcasts) { podcast in
                            NavigationLink(value: podcast) {
                                SuggestedPodcastTile(podcast: podcast)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    // MARK: - Data Loading

    private func loadUpNext() async {
        let favs = favorites.podcasts
        guard !favs.isEmpty else { return }
        isLoadingUpNext = true
        defer { isLoadingUpNext = false }

        var items: [UpNextItem] = []
        await withTaskGroup(of: UpNextItem?.self) { group in
            for podcast in favs {
                group.addTask {
                    guard let feedURLString = podcast.feedUrl,
                          let feedURL = URL(string: feedURLString) else { return nil }
                    do {
                        let episodes = try await RSSFeedParser().parse(feedURL: feedURL)
                        guard let first = episodes.first else { return nil }
                        return UpNextItem(id: podcast.id, podcast: podcast, episode: first)
                    } catch {
                        return nil
                    }
                }
            }
            for await item in group {
                if let item { items.append(item) }
            }
        }

        // Restore original favorites order.
        let order = favs.enumerated().reduce(into: [Int: Int]()) { dict, pair in
            dict[pair.element.id] = pair.offset
        }
        upNextItems = items.sorted { (order[$0.id] ?? 0) < (order[$1.id] ?? 0) }
    }

    private func loadSuggestions() async {
        do {
            suggestedPodcasts = try await service.fetchTopPodcasts(limit: 12)
        } catch {
            // Non-critical — leave empty.
        }
    }
}

// MARK: - Up Next Card

struct UpNextCard: View {
    let item: UpNextItem
    @Environment(AudioPlayerManager.self) private var player

    var body: some View {
        NavigationLink(value: item.podcast) {
            ZStack(alignment: .bottomLeading) {
                // Background artwork
                AsyncImage(url: URL(string: item.podcast.artworkUrl600)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    default:
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .overlay {
                                Image(systemName: "waveform")
                                    .font(.largeTitle)
                                    .foregroundStyle(.secondary)
                            }
                    }
                }
                .frame(width: 280, height: 200)
                .clipped()

                // Gradient overlay + content
                VStack(alignment: .leading, spacing: 5) {
                    Text(relativeLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.75))

                    Text(item.episode.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    let cleanDesc = cleanDescription(item.episode.description)
                    if !cleanDesc.isEmpty {
                        Text(cleanDesc)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.65))
                            .lineLimit(2)
                    }

                    // Play / pause button — fires independently from the NavigationLink.
                    let isActive = player.currentEpisode?.id == item.episode.id && player.isPlaying
                    Button {
                        if isActive {
                            player.pause()
                        } else {
                            player.play(episode: item.episode)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: isActive ? "pause.fill" : "play.fill")
                                .font(.caption.weight(.bold))
                            let dur = formattedDuration(item.episode.duration)
                            if !dur.isEmpty {
                                Text(dur)
                                    .font(.caption.weight(.semibold))
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.white.opacity(0.22), in: Capsule())
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }
                .padding(14)
                .frame(width: 280, alignment: .leading)
                .background {
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.80)],
                        startPoint: UnitPoint(x: 0.5, y: 0.1),
                        endPoint: .bottom
                    )
                }
            }
            .frame(width: 280, height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    /// Relative date label derived from the episode's already-formatted pubDate string.
    private var relativeLabel: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "en_US")

        if let date = formatter.date(from: item.episode.pubDate) {
            let interval = Date().timeIntervalSince(date)
            if interval < 3600 {
                let m = max(1, Int(interval / 60))
                return "New · \(m)m ago"
            } else if interval < 86400 {
                let h = Int(interval / 3600)
                return "New · \(h)h ago"
            } else if interval < 7 * 86400 {
                let d = Int(interval / 86400)
                return "New · \(d)d ago"
            } else if interval < 30 * 86400 {
                let w = Int(interval / (7 * 86400))
                return "New · \(w)w ago"
            }
        }
        return "Followed"
    }

    /// Converts HH:MM:SS / MM:SS / raw-seconds duration strings to a short "Xm" label.
    private func formattedDuration(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        let parts = trimmed.split(separator: ":").compactMap { Int($0) }
        switch parts.count {
        case 3:  // HH:MM:SS
            let totalMin = parts[0] * 60 + parts[1]
            return "\(totalMin)m"
        case 2:  // MM:SS
            return parts[0] > 0 ? "\(parts[0])m" : ""
        case 1:  // total seconds as "MM:SS" fallback or plain number
            let min = parts[0] / 60
            return min > 0 ? "\(min)m" : ""
        default:
            if let secs = Int(trimmed) {
                let min = secs / 60
                return min > 0 ? "\(min)m" : ""
            }
            return ""
        }
    }

    /// Strips HTML tags and decodes common entities for plain-text display.
    private func cleanDescription(_ html: String) -> String {
        html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Suggested Podcast Tile

struct SuggestedPodcastTile: View {
    let podcast: Podcast

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AsyncImage(url: URL(string: podcast.artworkUrl600)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(1, contentMode: .fit)
                default:
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.quaternary)
                        .aspectRatio(1, contentMode: .fit)
                        .overlay {
                            Image(systemName: "waveform")
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .frame(width: 120, height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .black.opacity(0.12), radius: 5, x: 0, y: 2)

            Text(podcast.collectionName)
                .font(.caption.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .frame(width: 120, alignment: .leading)
        }
        .frame(width: 120)
    }
}
