import SwiftUI

/// Root view — TabView with Search and Favorites, plus a floating mini player.
struct ContentView: View {
    @Environment(AudioPlayerManager.self) private var player
    @State private var selectedTab = 0
    @State private var showNowPlaying = false

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                Tab("Search", systemImage: "magnifyingglass", value: 0) {
                    SearchView()
                }

                Tab("Favorites", systemImage: "star.fill", value: 1) {
                    FavoritesView()
                }
            }

            // Floating mini player.
            if player.currentEpisode != nil {
                MiniPlayerView(showNowPlaying: $showNowPlaying)
                    .padding(.bottom, 54)
            }
        }
        .sheet(isPresented: $showNowPlaying) {
            NowPlayingView()
                .environment(player)
        }
    }
}

#Preview {
    ContentView()
        .environment(FavoritesStore())
        .environment(AudioPlayerManager())
}
