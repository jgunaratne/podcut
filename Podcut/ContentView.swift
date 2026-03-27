import SwiftUI

/// Root view — shows onboarding on first launch, then the main TabView.
struct ContentView: View {
    @Environment(AudioPlayerManager.self) private var player
    @State private var selectedTab = 0
    @State private var showNowPlaying = false
    @State private var showEpisodePage = false
    @State private var episodeToShow: Episode?
    @State private var hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")

    var body: some View {
        if hasCompletedOnboarding {
            mainView
        } else {
            OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
        }
    }

    private var mainView: some View {
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
                    .padding(.bottom, 49)
            }
        }
        .sheet(isPresented: $showNowPlaying) {
            NowPlayingView(onGoToEpisode: { episode in
                episodeToShow = episode
                showNowPlaying = false
            })
            .environment(player)
        }
        .onChange(of: showNowPlaying) { _, isShowing in
            if !isShowing, episodeToShow != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    showEpisodePage = true
                }
            }
        }
        .fullScreenCover(isPresented: $showEpisodePage, onDismiss: {
            episodeToShow = nil
        }) {
            if let episode = episodeToShow {
                NavigationStack {
                    EpisodePageView(episode: episode)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button {
                                    showEpisodePage = false
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.body.weight(.medium))
                                }
                            }
                        }
                }
                .environment(player)
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(FavoritesStore())
        .environment(AudioPlayerManager())
}
