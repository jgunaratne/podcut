import SwiftUI

/// Favourites tab — list of starred podcasts.
struct FavoritesView: View {
    @Environment(FavoritesStore.self) private var favorites

    var body: some View {
        NavigationStack {
            Group {
                if favorites.podcasts.isEmpty {
                    ContentUnavailableView(
                        "No Favorites Yet",
                        systemImage: "star",
                        description: Text(
                            "Star a podcast to see it here.")
                    )
                } else {
                    List {
                        ForEach(favorites.podcasts) { podcast in
                            NavigationLink(value: podcast) {
                                PodcastRowView(podcast: podcast)
                            }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                favorites.toggle(
                                    favorites.podcasts[index])
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Favorites")
            .navigationDestination(for: Podcast.self) { podcast in
                PodcastDetailView(podcast: podcast)
            }
        }
    }
}
