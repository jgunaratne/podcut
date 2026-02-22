import Foundation
import SwiftUI

/// Persists starred podcasts to UserDefaults.
@Observable
final class FavoritesStore {
    private static let key = "starred_podcasts"

    var podcasts: [Podcast] = []

    init() {
        load()
    }

    func isFavorite(_ podcast: Podcast) -> Bool {
        podcasts.contains { $0.id == podcast.id }
    }

    func toggle(_ podcast: Podcast) {
        if let index = podcasts.firstIndex(where: { $0.id == podcast.id }) {
            podcasts.remove(at: index)
        } else {
            podcasts.insert(podcast, at: 0)
        }
        save()
    }

    // MARK: - Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(podcasts) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }

    private func load() {
        guard
            let data = UserDefaults.standard.data(forKey: Self.key),
            let saved = try? JSONDecoder().decode(
                [Podcast].self, from: data)
        else { return }
        podcasts = saved
    }
}
