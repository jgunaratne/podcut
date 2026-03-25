import SwiftUI

/// Favourites tab — list of starred podcasts.
struct FavoritesView: View {
    @Environment(AudioPlayerManager.self) private var player
    @Environment(FavoritesStore.self) private var favorites
    @State private var layout: Layout = .list

    enum Layout: String, CaseIterable, Identifiable {
        case list = "List"
        case grid = "Grid"
        var id: Self { self }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if favorites.podcasts.isEmpty {
                    ContentUnavailableView(
                        "No Favorites Yet",
                        systemImage: "star.circle.fill",
                        description: Text("Tap the ") + Text(Image(systemName: "star.fill")) + Text(" on any podcast to save it here for quick access.")
                    )
                } else {
                    layoutView()
                }
            }
            .navigationTitle("Favorites")
            .navigationDestination(for: Podcast.self) { podcast in
                PodcastDetailView(podcast: podcast)
            }
            .toolbar {
                if !favorites.podcasts.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        layoutPicker()
                    }
                }
            }
        }
        .background(Color(.systemBackground).ignoresSafeArea())
    }

    @ViewBuilder
    private func layoutView() -> some View {
        switch layout {
        case .list:
            listView()
        case .grid:
            gridView()
        }
    }

    private func listView() -> some View {
        List {
            ForEach(favorites.podcasts) { podcast in
                NavigationLink(value: podcast) {
                    PodcastRowView(podcast: podcast)
                        .padding(.vertical, 4)
                }
                .listRowSeparator(.hidden)
            }
            .onDelete { indexSet in
                for index in indexSet {
                    favorites.toggle(favorites.podcasts[index])
                }
            }
            
            if player.currentEpisode != nil {
                Color.clear.frame(height: 75)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
    }

    private func gridView() -> some View {
        let columns = [GridItem(.adaptive(minimum: 160), spacing: 16)]
        
        return ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(favorites.podcasts) { podcast in
                    NavigationLink(value: podcast) {
                        PodcastGridItemView(podcast: podcast)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Remove from Favorites", systemImage: "star.slash", role: .destructive) {
                            favorites.toggle(podcast)
                        }
                    }
                }
            }
            .padding()
            
            if player.currentEpisode != nil {
                Color.clear.frame(height: 75)
            }
        }
    }

    private func layoutPicker() -> some View {
        Picker("Layout", selection: $layout.animation(.easeInOut)) {
            ForEach(Layout.allCases) { layout in
                Image(systemName: layout == .list ? "list.bullet" : "square.grid.2x2")
                    .tag(layout)
            }
        }
        .pickerStyle(.segmented)
    }
}


private struct PodcastGridItemView: View {
    let podcast: Podcast

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            AsyncImage(url: URL(string: podcast.artworkUrl600)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                default:
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.quaternary)
                        .overlay {
                            Image(systemName: "mic.fill")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.12), radius: 10, y: 5)

            VStack(alignment: .leading, spacing: 3) {
                Text(podcast.collectionName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                Text(podcast.artistName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}
