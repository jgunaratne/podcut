import SwiftUI

/// Root view — TabView with Search, Favorites, and Settings, plus a floating mini player.
struct ContentView: View {
    @Environment(AudioPlayerManager.self) private var player
    @State private var selectedTab = 0
    @State private var showNowPlaying = false

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Search", systemImage: "magnifyingglass", value: 0) {
                SearchView()
            }

            Tab("Favorites", systemImage: "star.fill", value: 1) {
                FavoritesView()
            }

            Tab("Settings", systemImage: "gearshape", value: 2) {
                SettingsView()
            }
        }
        .overlay(alignment: .bottom) {
            if player.currentEpisode != nil {
                MiniPlayerView(showNowPlaying: $showNowPlaying)
                    // Sit just above the tab bar.
                    .padding(.bottom, 49)
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
