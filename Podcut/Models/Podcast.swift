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

    /// Manual initializer for creating Podcast from non-iTunes sources.
    init(id: Int, collectionName: String, artistName: String, artworkUrl600: String, artworkUrl100: String, feedUrl: String? = nil, trackCount: Int? = nil, primaryGenreName: String? = nil, releaseDate: String? = nil) {
        self.id = id
        self.collectionName = collectionName
        self.artistName = artistName
        self.artworkUrl600 = artworkUrl600
        self.artworkUrl100 = artworkUrl100
        self.feedUrl = feedUrl
        self.trackCount = trackCount
        self.primaryGenreName = primaryGenreName
        self.releaseDate = releaseDate
    }

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
