import Foundation

/// A podcast returned by the iTunes Search API.
struct Podcast: Codable, Identifiable, Hashable {
    let id: Int
    let collectionName: String
    let artistName: String
    let artworkUrl600: String
    let artworkUrl100: String
    let feedUrl: String?
    let trackCount: Int?
    let primaryGenreName: String?
    let releaseDate: String?

    enum CodingKeys: String, CodingKey {
        case id = "collectionId"
        case collectionName
        case artistName
        case artworkUrl600
        case artworkUrl100
        case feedUrl
        case trackCount
        case primaryGenreName
        case releaseDate
    }
}

/// Wrapper for the iTunes Search API JSON response.
struct PodcastSearchResponse: Codable {
    let resultCount: Int
    let results: [Podcast]
}
