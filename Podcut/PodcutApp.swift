import FirebaseCore
import SwiftData
import SwiftUI

@main
struct PodcutApp: App {
    @State private var favoritesStore = FavoritesStore()
    @State private var audioPlayer = AudioPlayerManager()

    init() {
        FirebaseApp.configure()
        
        // Force TabBar to always be translucent (frosted glass) and extend correctly
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithDefaultBackground()
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        
        // Force NavigationBar to always be translucent
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithDefaultBackground()
        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
        UINavigationBar.appearance().compactAppearance = navBarAppearance
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(favoritesStore)
                .environment(audioPlayer)
                .tint(.blue)
        }
        .modelContainer(for: TranscriptionRecord.self)
    }
}
