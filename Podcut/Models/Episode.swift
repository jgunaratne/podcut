import Foundation

/// An episode parsed from a podcast RSS feed.
struct Episode: Identifiable, Hashable {
    /// Stable ID based on audio URL (or title as fallback) so the same episode
    /// is recognized across re-parses of the RSS feed.
    var id: String {
        audioURL?.absoluteString ?? title
    }
    let title: String
    let description: String
    let audioURL: URL?
    let pubDate: String
    let duration: String
    var artworkURL: URL?
}
