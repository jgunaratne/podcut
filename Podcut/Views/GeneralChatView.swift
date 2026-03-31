import SwiftUI

/// The chat-first home screen — a general podcast assistant with inline cards.
struct GeneralChatView: View {
    @Environment(FavoritesStore.self) private var favorites
    @Environment(AudioPlayerManager.self) private var player
    @State private var assistant = ChatAssistant()
    @State private var inputText = ""
    @State private var isAnimatingDots = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            if assistant.messages.isEmpty {
                                welcomeView
                            }

                            ForEach(assistant.messages) { message in
                                messageView(message)
                                    .id(message.id)
                            }

                            if assistant.isLoading {
                                typingIndicator
                                    .id("loading")
                            }
                        }
                        .padding(.vertical, 16)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: assistant.messages.count) {
                        withAnimation {
                            if let last = assistant.messages.last {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: assistant.isLoading) {
                        if assistant.isLoading {
                            withAnimation { proxy.scrollTo("loading", anchor: .bottom) }
                        }
                    }
                }

                if let error = assistant.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                        .padding(.bottom, 4)
                }

                inputBar
            }
            .navigationTitle("Podcut")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !assistant.messages.isEmpty {
                        Button {
                            withAnimation { assistant.clearHistory() }
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.body)
                        }
                    }
                }
            }
            .navigationDestination(for: Podcast.self) { podcast in
                PodcastDetailView(podcast: podcast)
            }
        }
        .onAppear {
            assistant.favoritesStore = favorites
            assistant.playerManager = player
        }
    }

    // MARK: - Welcome

    private var welcomeView: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 60)

            // Glass icon badge
            ZStack {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.blue.gradient)
                    .symbolEffect(.pulse, options: .repeating)
            }
            .frame(width: 96, height: 96)
            .glassEffect(.regular, in: .circle)

            VStack(spacing: 8) {
                Text("Hey! 👋")
                    .font(.title.bold())

                Text("I'm your podcast assistant. Ask me anything — find shows, see what's trending, or explore your library.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // Glass suggestion chips
            FlowLayout(spacing: 8) {
                ForEach(assistant.generateSuggestions(), id: \.self) { suggestion in
                    Button {
                        inputText = suggestion
                        sendMessage()
                    } label: {
                        Text(suggestion)
                            .font(.subheadline)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                    }
                    .glassEffect(.regular, in: .capsule)
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)

            Spacer(minLength: 20)
        }
    }

    // MARK: - Message View

    @ViewBuilder
    private func messageView(_ message: AssistantMessage) -> some View {
        if message.role == "user" {
            userBubble(message.text)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                if !message.text.isEmpty {
                    assistantBubble(message.text)
                }

                if !message.podcasts.isEmpty {
                    podcastCarousel(message.podcasts)
                }

                if !message.episodes.isEmpty {
                    episodeList(message.episodes)
                }
            }
        }
    }

    // MARK: - Bubbles

    private func userBubble(_ text: String) -> some View {
        HStack {
            Spacer(minLength: 60)
            Text(text)
                .font(.body)
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.blue.gradient, in: chatBubbleShape(isUser: true))
        }
        .padding(.horizontal)
    }

    private func assistantBubble(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(.body)
                .textSelection(.enabled)
                .foregroundStyle(.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .glassEffect(.regular, in: chatBubbleShape(isUser: false))
            Spacer(minLength: 60)
        }
        .padding(.horizontal)
    }

    private func chatBubbleShape(isUser: Bool) -> some Shape {
        UnevenRoundedRectangle(
            cornerRadii: .init(
                topLeading: 20,
                bottomLeading: isUser ? 20 : 6,
                bottomTrailing: isUser ? 6 : 20,
                topTrailing: 20
            ),
            style: .continuous
        )
    }

    // MARK: - Podcast Carousel

    private func podcastCarousel(_ podcasts: [Podcast]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(podcasts) { podcast in
                    NavigationLink(value: podcast) {
                        podcastCard(podcast)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
    }

    private func podcastCard(_ podcast: Podcast) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .bottom) {
                AsyncImage(url: URL(string: podcast.artworkUrl600)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(1, contentMode: .fill)
                    default:
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(.quaternary)
                            .aspectRatio(1, contentMode: .fit)
                            .overlay {
                                Image(systemName: "waveform")
                                    .foregroundStyle(.secondary)
                            }
                    }
                }
                .frame(width: 140, height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                // Glass overlay with podcast name
                VStack(alignment: .leading, spacing: 2) {
                    Text(podcast.collectionName)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    Text(podcast.artistName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .glassEffect(.regular, in: .rect(cornerRadius: 12))
                .padding(4)
            }
            .frame(width: 140, height: 140)

            followButton(for: podcast)
        }
        .frame(width: 140)
    }

    private func followButton(for podcast: Podcast) -> some View {
        let isFollowed = favorites.isFavorite(podcast)
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            favorites.toggle(podcast)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: isFollowed ? "checkmark" : "plus")
                    .font(.caption2.bold())
                Text(isFollowed ? "Following" : "Follow")
                    .font(.caption2.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .glassEffect(isFollowed ? .regular : .regular.tint(.blue), in: .capsule)
        .buttonStyle(.plain)
        .frame(width: 140)
    }

    // MARK: - Episode List

    private func episodeList(_ episodes: [(episode: Episode, podcast: Podcast)]) -> some View {
        VStack(spacing: 8) {
            ForEach(Array(episodes.enumerated()), id: \.offset) { _, item in
                episodeCard(item.episode, podcast: item.podcast)
            }
        }
        .padding(.horizontal)
    }

    private func episodeCard(_ episode: Episode, podcast: Podcast) -> some View {
        let isPlaying = player.currentEpisode?.id == episode.id && player.isPlaying
        let isThisLoading = player.currentEpisode?.id == episode.id && player.isLoading

        return HStack(spacing: 12) {
            // Play button
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                if isPlaying {
                    player.pause()
                } else {
                    player.play(episode: episode)
                }
            } label: {
                ZStack {
                    if isThisLoading {
                        ProgressView()
                            .tint(.blue)
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.caption.bold())
                            .foregroundStyle(.blue)
                    }
                }
                .frame(width: 40, height: 40)
                .glassEffect(.regular, in: .circle)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
                Text(episode.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)

                HStack(spacing: 6) {
                    if !episode.pubDate.isEmpty {
                        Text(episode.pubDate)
                    }
                    if !episode.duration.isEmpty {
                        Text("·")
                        Text(episode.duration)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            NavigationLink(value: podcast) {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
    }

    // MARK: - Typing Indicator

    private var typingIndicator: some View {
        HStack {
            HStack(spacing: 5) {
                ForEach(0..<3) { i in
                    Circle()
                        .frame(width: 8, height: 8)
                        .foregroundStyle(.secondary)
                        .scaleEffect(isAnimatingDots ? 1 : 0.5)
                        .animation(
                            .easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(0.2 * Double(i)),
                            value: isAnimatingDots
                        )
                }
            }
            .onAppear { isAnimatingDots = true }
            .onDisappear { isAnimatingDots = false }
            .padding(16)
            .glassEffect(.regular, in: chatBubbleShape(isUser: false))

            Spacer()
        }
        .padding(.horizontal)
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Ask about podcasts…", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...4)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .glassEffect(.regular, in: .capsule)
                .onSubmit { sendMessage() }

            Button {
                sendMessage()
            } label: {
                Image(systemName: "arrow.up")
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(.blue.gradient, in: Circle())
            }
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || assistant.isLoading)
            .animation(.easeInOut, value: inputText.isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: .rect)
    }

    // MARK: - Send

    private func sendMessage() {
        let text = inputText
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        inputText = ""
        Task { await assistant.send(text) }
    }
}
