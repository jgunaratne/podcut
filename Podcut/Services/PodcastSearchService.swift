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
        ]

        guard let url = components.url else { return [] }

        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(PodcastSearchResponse.self, from: data)
        return response.results
    }
}
