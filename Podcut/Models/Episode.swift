import Foundation

/// An episode parsed from a podcast RSS feed.
struct Episode: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let description: String
    let audioURL: URL?
    let pubDate: String
    let duration: String
    var artworkURL: URL?
}
