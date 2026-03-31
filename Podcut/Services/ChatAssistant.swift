import FirebaseAI
import Foundation

/// A message in the general chat, which can contain text, podcast cards, or episode cards.
struct AssistantMessage: Identifiable {
    let id = UUID()
    let role: String // "user" or "assistant"
    let text: String
    var podcasts: [Podcast] = []
    var episodes: [(episode: Episode, podcast: Podcast)] = []
}

/// Orchestrates the general podcast chat using Gemini with function calling.
@MainActor @Observable
final class ChatAssistant {
    var messages: [AssistantMessage] = []
    var isLoading = false
    var errorMessage: String?

    private var chat: Chat?
    private var model: GenerativeModel?

    private let searchService = PodcastSearchService()

    // Dependencies injected from the view layer.
    var favoritesStore: FavoritesStore?
    var playerManager: AudioPlayerManager?

    init() {
        setupModel()
    }

    // MARK: - Setup

    private func setupModel() {
        let searchPodcasts = FunctionDeclaration(
            name: "searchPodcasts",
            description: "Search for podcasts by name, topic, or keyword. Use this when the user wants to discover or find podcasts.",
            parameters: [
                "query": .string(description: "Search query for podcasts"),
            ]
        )

        let getSubscriptions = FunctionDeclaration(
            name: "getSubscriptions",
            description: "Get the user's subscribed/favorited podcasts. Use when the user asks about their library or subscriptions.",
            parameters: [:]
        )

        let getLatestEpisodes = FunctionDeclaration(
            name: "getLatestEpisodes",
            description: "Get the latest episodes from a specific podcast by its feed URL. Use when the user wants to see episodes from a podcast.",
            parameters: [
                "feedUrl": .string(description: "The RSS feed URL of the podcast"),
                "podcastName": .string(description: "The podcast name for display"),
                "podcastArtwork": .string(description: "The podcast artwork URL"),
                "podcastArtist": .string(description: "The podcast artist name"),
                "podcastId": .integer(description: "The podcast iTunes ID"),
            ],
            optionalParameters: ["podcastArtwork", "podcastArtist", "podcastId"]
        )

        let getTrending = FunctionDeclaration(
            name: "getTrendingPodcasts",
            description: "Get currently trending/top podcasts. Use when the user wants recommendations or asks what's popular.",
            parameters: [:]
        )

        let tools = [Tool.functionDeclarations([
            searchPodcasts,
            getSubscriptions,
            getLatestEpisodes,
            getTrending,
        ])]

        model = FirebaseAI.firebaseAI(backend: .googleAI())
            .generativeModel(
                modelName: "gemini-2.5-flash-lite",
                generationConfig: GenerationConfig(temperature: 0.7, maxOutputTokens: 1024),
                tools: tools,
                systemInstruction: ModelContent(role: "system", parts: systemPrompt)
            )

        chat = model?.startChat()
    }

    private var systemPrompt: String {
        """
        You are Podcut's AI assistant — a friendly, concise podcast companion. You help users \
        discover podcasts, explore episodes, and get answers about podcast content.

        PERSONALITY:
        - Conversational and helpful, not robotic
        - Keep responses concise (2-3 sentences for simple queries)
        - Use emoji sparingly but naturally
        - Be enthusiastic about good podcast recommendations

        CAPABILITIES:
        - Search for podcasts by topic, name, or interest
        - Show the user's subscribed podcasts
        - Fetch latest episodes from any podcast
        - Show trending/popular podcasts
        - General podcast knowledge and recommendations

        RULES:
        - When recommending podcasts, ALWAYS use the searchPodcasts or getTrendingPodcasts \
          function to get real results — never make up podcast names
        - When the user asks about their library, use getSubscriptions
        - When showing episodes, use getLatestEpisodes with the feed URL
        - After showing results, add a brief helpful comment
        - If the user asks something unrelated to podcasts, gently redirect
        - Never fabricate podcast names, episode titles, or URLs
        """
    }

    // MARK: - Send Message

    func send(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isLoading else { return }

        messages.append(AssistantMessage(role: "user", text: trimmed))
        isLoading = true
        errorMessage = nil

        do {
            guard let chat else { throw GeminiError.emptyResponse }

            var response = try await chat.sendMessage(trimmed)

            // Handle function calling loop (max 5 rounds to prevent infinite loops).
            var rounds = 0
            while rounds < 5 {
                let functionCalls = response.functionCalls
                guard !functionCalls.isEmpty else { break }

                var functionResponses: [FunctionResponsePart] = []
                for call in functionCalls {
                    let result = await executeTool(name: call.name, args: call.args)
                    functionResponses.append(
                        FunctionResponsePart(name: call.name, response: result)
                    )
                }

                // Send function results back to the model.
                let responseParts: [any PartsRepresentable] = functionResponses
                response = try await chat.sendMessage(
                    [ModelContent(role: "function", parts: responseParts.flatMap { $0.partsValue })]
                )
                rounds += 1
            }

            // Extract the final text response.
            let responseText = response.text ?? ""

            // Collect any podcasts/episodes gathered during tool execution.
            var msg = AssistantMessage(role: "assistant", text: responseText)
            msg.podcasts = pendingPodcasts
            msg.episodes = pendingEpisodes
            messages.append(msg)

            pendingPodcasts = []
            pendingEpisodes = []

        } catch {
            errorMessage = "Something went wrong. Try again."
        }

        isLoading = false
    }

    // MARK: - Tool Execution

    private var pendingPodcasts: [Podcast] = []
    private var pendingEpisodes: [(episode: Episode, podcast: Podcast)] = []

    private func executeTool(name: String, args: [String: Any]) async -> JSONObject {
        switch name {
        case "searchPodcasts":
            let query = args["query"] as? String ?? ""
            do {
                let results = try await searchService.search(query: query)
                let limited = Array(results.prefix(6))
                pendingPodcasts.append(contentsOf: limited)
                return [
                    "results": .array(limited.map { podcastJSON($0) }),
                    "count": .number(Double(limited.count)),
                ]
            } catch {
                return ["error": .string("Search failed: \(error.localizedDescription)")]
            }

        case "getSubscriptions":
            let subs = favoritesStore?.podcasts ?? []
            if subs.isEmpty {
                return ["results": .array([]), "message": .string("User has no subscriptions yet.")]
            }
            pendingPodcasts.append(contentsOf: subs)
            return [
                "results": .array(subs.map { podcastJSON($0) }),
                "count": .number(Double(subs.count)),
            ]

        case "getLatestEpisodes":
            let feedUrl = args["feedUrl"] as? String ?? ""
            let podcastName = args["podcastName"] as? String ?? "Podcast"
            let artwork = args["podcastArtwork"] as? String ?? ""
            let artist = args["podcastArtist"] as? String ?? ""
            let podcastId = args["podcastId"] as? Int ?? 0

            guard let url = URL(string: feedUrl) else {
                return ["error": .string("Invalid feed URL")]
            }

            let podcast = Podcast(
                id: podcastId,
                collectionName: podcastName,
                artistName: artist,
                artworkUrl600: artwork,
                artworkUrl100: artwork
            )

            do {
                let episodes = try await RSSFeedParser().parse(feedURL: url)
                let limited = Array(episodes.prefix(5))
                let withArtwork = limited.map { ep -> Episode in
                    var copy = ep
                    copy.artworkURL = URL(string: artwork)
                    return copy
                }
                pendingEpisodes.append(contentsOf: withArtwork.map { (episode: $0, podcast: podcast) })
                return [
                    "episodes": .array(withArtwork.map { episodeJSON($0) }),
                    "count": .number(Double(withArtwork.count)),
                    "podcastName": .string(podcastName),
                ]
            } catch {
                return ["error": .string("Failed to fetch episodes: \(error.localizedDescription)")]
            }

        case "getTrendingPodcasts":
            do {
                let trending = try await searchService.fetchTopPodcasts(limit: 8)
                pendingPodcasts.append(contentsOf: trending)
                return [
                    "results": .array(trending.map { podcastJSON($0) }),
                    "count": .number(Double(trending.count)),
                ]
            } catch {
                return ["error": .string("Failed to fetch trending: \(error.localizedDescription)")]
            }

        default:
            return ["error": .string("Unknown tool: \(name)")]
        }
    }

    // MARK: - JSON Helpers

    private func podcastJSON(_ p: Podcast) -> JSONValue {
        .object([
            "id": .number(Double(p.id)),
            "name": .string(p.collectionName),
            "artist": .string(p.artistName),
            "artwork": .string(p.artworkUrl600),
            "genre": .string(p.primaryGenreName ?? ""),
            "feedUrl": .string(p.feedUrl ?? ""),
        ])
    }

    private func episodeJSON(_ e: Episode) -> JSONValue {
        .object([
            "title": .string(e.title),
            "pubDate": .string(e.pubDate),
            "duration": .string(e.duration),
            "hasAudio": .bool(e.audioURL != nil),
        ])
    }

    // MARK: - Smart Suggestions

    func loadSmartSuggestions() async -> [String] {
        let fallback = generateSuggestions()

        do {
            // Fetch context: trending podcasts + subscriptions.
            async let trendingTask = searchService.fetchTopPodcasts(limit: 6)
            let trending = (try? await trendingTask) ?? []
            let subs = favoritesStore?.podcasts ?? []

            let trendingNames = trending.map { "\($0.collectionName) (\($0.primaryGenreName ?? "Podcast"))" }.joined(separator: ", ")
            let subNames = subs.prefix(6).map { "\($0.collectionName) (\($0.primaryGenreName ?? "Podcast"))" }.joined(separator: ", ")

            var contextParts: [String] = []
            if !trendingNames.isEmpty { contextParts.append("Trending podcasts: \(trendingNames)") }
            if !subNames.isEmpty { contextParts.append("User's subscriptions: \(subNames)") }

            guard !contextParts.isEmpty else { return fallback }

            let prompt = """
            \(contextParts.joined(separator: ". ")).

            Generate 4-5 specific, engaging suggestion prompts a user might tap in a podcast assistant app. \
            Make them specific to the real podcast names and topics above. \
            Return ONLY a JSON array of strings, nothing else. Example: ["prompt one","prompt two"]
            """

            let oneShot = FirebaseAI.firebaseAI(backend: .googleAI())
                .generativeModel(
                    modelName: "gemini-2.5-flash-lite",
                    generationConfig: GenerationConfig(temperature: 0.9, maxOutputTokens: 256)
                )

            let response = try await oneShot.generateContent(prompt)
            guard let raw = response.text else { return fallback }

            // Strip any markdown fences before parsing.
            let cleaned = raw
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard let data = cleaned.data(using: .utf8),
                  let parsed = try? JSONDecoder().decode([String].self, from: data),
                  !parsed.isEmpty
            else { return fallback }

            return parsed
        } catch {
            return fallback
        }
    }

    // MARK: - Suggestions

    func generateSuggestions() -> [String] {
        let hasSubs = !(favoritesStore?.podcasts.isEmpty ?? true)

        if hasSubs {
            return [
                "What's new from my podcasts?",
                "Find me something about AI",
                "What's trending right now?",
                "Recommend a comedy podcast",
            ]
        } else {
            return [
                "What's trending right now?",
                "Find podcasts about technology",
                "Recommend a true crime podcast",
                "What are the best comedy podcasts?",
            ]
        }
    }

    /// Reset the conversation.
    func clearHistory() {
        messages = []
        chat = model?.startChat()
        pendingPodcasts = []
        pendingEpisodes = []
    }
}
