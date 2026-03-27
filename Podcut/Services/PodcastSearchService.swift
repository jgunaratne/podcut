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
    /// Uses the RSS chart for ranking, then enriches with iTunes lookup for feed URLs.
    func fetchTopPodcasts(limit: Int = 12) async throws -> [Podcast] {
        let urlString = "https://rss.marketingtools.apple.com/api/v2/us/podcasts/top/\(limit)/podcasts.json"
        guard let url = URL(string: urlString) else { return [] }

        let (data, _) = try await URLSession.shared.data(from: url)
        let feed = try JSONDecoder().decode(AppleRSSFeed.self, from: data)

        // Get the IDs and look them up via iTunes to get feedUrl.
        let ids = feed.feed.results.compactMap { $0.id }
        guard !ids.isEmpty else { return [] }

        let idsString = ids.joined(separator: ",")
        var lookupComponents = URLComponents(string: "https://itunes.apple.com/lookup")!
        lookupComponents.queryItems = [
            URLQueryItem(name: "id", value: idsString),
            URLQueryItem(name: "entity", value: "podcast"),
            URLQueryItem(name: "country", value: "US"),
        ]

        guard let lookupURL = lookupComponents.url else { return [] }

        let (lookupData, _) = try await URLSession.shared.data(from: lookupURL)
        let lookupResponse = try JSONDecoder().decode(PodcastSearchResponse.self, from: lookupData)

        // Return in chart order by mapping RSS IDs to lookup results.
        let lookupMap = Dictionary(uniqueKeysWithValues: lookupResponse.results.map { ($0.id, $0) })
        return ids.compactMap { id -> Podcast? in
            guard let numericId = Int(id) else { return nil }
            return lookupMap[numericId]
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
