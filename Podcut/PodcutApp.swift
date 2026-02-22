import FirebaseCore
import SwiftData
import SwiftUI

@main
struct PodcutApp: App {
    @State private var favoritesStore = FavoritesStore()
    @State private var audioPlayer = AudioPlayerManager()

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(favoritesStore)
                .environment(audioPlayer)
                .tint(.purple)
        }
        .modelContainer(for: TranscriptionRecord.self)
    }
}
