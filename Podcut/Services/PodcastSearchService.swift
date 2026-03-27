import Foundation

/// Searches the iTunes Search API for podcasts.
struct PodcastSearchService {

    /// Search for podcasts matching the given query.
    func search(query: String) async throws -> [Podcast] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }

        var components = URLComponents(string: "https://itunes.apple.com/search")!
        components.queryItems = [
            URLQueryItem(name: "term", value: query),
            URLQueryItem(name: "media", value: "podcast"),
            URLQueryItem(name: "entity", value: "podcast"),
            URLQueryItem(name: "limit", value: "25"),
            URLQueryItem(name: "country", value: "US"),
            URLQueryItem(name: "lang", value: "en_us"),
        ]

        guard let url = components.url else { return [] }

        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(PodcastSearchResponse.self, from: data)
        return response.results
    }

    /// Fetch top podcasts from the iTunes RSS feed (US, English).
    func fetchTopPodcasts(limit: Int = 12) async throws -> [Podcast] {
        let urlString = "https://rss.marketingtools.apple.com/api/v2/us/podcasts/top/\(limit)/podcasts.json"
        guard let url = URL(string: urlString) else { return [] }

        let (data, _) = try await URLSession.shared.data(from: url)

        // Parse the Apple RSS feed format.
        let feed = try JSONDecoder().decode(AppleRSSFeed.self, from: data)
        return feed.feed.results.compactMap { entry in
            guard let id = Int(entry.id) else { return nil }
            return Podcast(
                id: id,
                collectionName: entry.name,
                artistName: entry.artistName,
                artworkUrl600: entry.artworkUrl100,
                artworkUrl100: entry.artworkUrl100
            )
        }
    }
}

// MARK: - Apple RSS Feed Models

private struct AppleRSSFeed: Decodable {
    let feed: AppleRSSFeedContent
}

private struct AppleRSSFeedContent: Decodable {
    let results: [AppleRSSEntry]
}

private struct AppleRSSEntry: Decodable {
    let id: String
    let name: String
    let artistName: String
    let artworkUrl100: String
    let url: String
}
