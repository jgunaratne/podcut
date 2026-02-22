import SwiftUI

@main
struct PodcutApp: App {
    @State private var favoritesStore = FavoritesStore()
    @State private var audioPlayer = AudioPlayerManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(favoritesStore)
                .environment(audioPlayer)
                .tint(.purple)
        }
    }
}
