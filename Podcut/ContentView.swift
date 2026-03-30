import SwiftUI

/// Root view — shows onboarding on first launch, then the main TabView.
struct ContentView: View {
    @Environment(AudioPlayerManager.self) private var player
    @State private var showNowPlaying = false
    @State private var hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")

    var body: some View {
        if hasCompletedOnboarding {
            mainView
        } else {
            OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
        }
    }

    private var mainView: some View {
        TabView {
            Tab("Chat", systemImage: "bubble.left.and.text.bubble.right.fill") {
                GeneralChatView()
            }

            Tab("Browse", systemImage: "square.grid.2x2.fill") {
                HomeView()
            }

            Tab("Search", systemImage: "magnifyingglass", role: .search) {
                SearchView()
            }

            Tab("Favorites", systemImage: "star.fill") {
                FavoritesView()
            }

            Tab("Settings", systemImage: "gearshape") {
                SettingsView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory {
            if player.currentEpisode != nil {
                MiniPlayerView(showNowPlaying: $showNowPlaying)
            }
        }
        .ignoresSafeArea(.keyboard)
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
