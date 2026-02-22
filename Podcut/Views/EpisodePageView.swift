import SwiftData
import SwiftUI

/// A swipeable page view for an episode: Detail → Transcription → Summary.
struct EpisodePageView: View {
    let episode: Episode
    @State private var currentPage = 0
    @State private var service = TranscriptionService()
    @Environment(\.modelContext) private var modelContext
    @Environment(AudioPlayerManager.self) private var player

    // Summary state.
    @State private var summaryText: String = ""
    @State private var isSummarizing = false
    @State private var summaryError: String?
    @State private var isSaved = false

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                // Page 1: Episode Details
                episodeDetailPage
                    .tag(0)

                // Page 2: Transcription
                transcriptionPage
                    .tag(1)

                // Page 3: AI Summary
                summaryPage
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.3), value: currentPage)

            // Custom page indicator.
            pageIndicator
        }
        .navigationTitle(episode.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadSaved() }
    }

    // MARK: - Page 1: Detail

    private var episodeDetailPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Episode header.
                VStack(alignment: .leading, spacing: 8) {
                    Text(episode.title)
                        .font(.title2.bold())

                    HStack(spacing: 8) {
                        if !episode.pubDate.isEmpty {
                            Label(episode.pubDate, systemImage: "calendar")
                        }
                        if !episode.duration.isEmpty {
                            Label(episode.duration, systemImage: "clock")
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                    if isSaved {
                        Label("Saved on device", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
                .padding(.horizontal)

                // Play button.
                Button {
                    player.play(episode: episode)
                } label: {
                    Label(
                        player.currentEpisode?.id == episode.id && player.isPlaying
                            ? "Pause" : "Play Episode",
                        systemImage: player.currentEpisode?.id == episode.id && player.isPlaying
                            ? "pause.circle.fill" : "play.circle.fill"
                    )
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .padding(.horizontal, 24)

                // Description.
                if !episode.description.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Description", systemImage: "doc.text")
                            .font(.headline)

                        Text(episode.description)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                }

                // Hint to swipe.
                Label("Swipe left for transcription →", systemImage: "hand.draw")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 30)
            }
            .padding(.top, 20)
        }
    }

    // MARK: - Page 2: Transcription

    private var transcriptionPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Progress bar.
                if service.isTranscribing {
                    VStack(alignment: .leading, spacing: 6) {
                        ProgressView(value: service.fractionComplete)
                            .tint(.indigo)
                            .animation(.easeInOut(duration: 0.3), value: service.fractionComplete)

                        Text(service.progress)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                }

                // Error.
                if let error = service.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.subheadline)
                        .padding(.horizontal)
                }

                // Transcription text.
                if !service.transcriptionText.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label("Transcription", systemImage: "text.quote")
                                .font(.headline)

                            Spacer()

                            Button {
                                UIPasteboard.general.string = service.transcriptionText
                            } label: {
                                Label("Copy", systemImage: "doc.on.doc")
                                    .font(.subheadline)
                            }
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.capsule)
                        }

                        Text(service.transcriptionText)
                            .font(.body)
                            .textSelection(.enabled)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal)

                } else if !service.isTranscribing && service.errorMessage == nil {
                    ContentUnavailableView(
                        "No Transcription Yet",
                        systemImage: "text.below.photo",
                        description: Text("Tap the button below to start transcribing.")
                    )
                }

                Spacer(minLength: 80)
            }
            .padding(.top, 20)
        }
        .safeAreaInset(edge: .bottom) {
            if !service.isTranscribing && service.transcriptionText.isEmpty {
                Button {
                    Task {
                        guard let url = episode.audioURL else { return }
                        await service.transcribe(audioURL: url)
                        saveToDevice()
                    }
                } label: {
                    Label("Start Transcription", systemImage: "waveform.badge.mic")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
                .disabled(episode.audioURL == nil)
            }
        }
    }

    // MARK: - Page 3: Summary

    private var summaryPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if isSummarizing {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Generating summary…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                }

                if let error = summaryError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.subheadline)
                        .padding(.horizontal)
                }

                if !summaryText.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label("AI Summary", systemImage: "sparkles")
                                .font(.headline)
                                .foregroundStyle(.indigo)

                            Spacer()

                            Button {
                                UIPasteboard.general.string = summaryText
                            } label: {
                                Label("Copy", systemImage: "doc.on.doc")
                                    .font(.subheadline)
                            }
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.capsule)
                        }

                        Group {
                            if let attributed = try? AttributedString(markdown: summaryText, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
                                Text(attributed)
                            } else {
                                Text(summaryText)
                            }
                        }
                        .font(.body)
                        .textSelection(.enabled)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            .indigo.opacity(0.08),
                            in: RoundedRectangle(cornerRadius: 14)
                        )
                    }
                    .padding(.horizontal)

                } else if !isSummarizing && summaryError == nil {
                    if service.transcriptionText.isEmpty {
                        ContentUnavailableView(
                            "Transcription Required",
                            systemImage: "text.below.photo",
                            description: Text("Transcribe the episode first, then generate a summary.")
                        )
                    } else {
                        ContentUnavailableView(
                            "No Summary Yet",
                            systemImage: "sparkles",
                            description: Text("Tap the button below to summarize this episode.")
                        )
                    }
                }

                Spacer(minLength: 80)
            }
            .padding(.top, 20)
        }
        .safeAreaInset(edge: .bottom) {
            if !service.transcriptionText.isEmpty && summaryText.isEmpty && !isSummarizing {
                Button {
                    Task { await generateSummary() }
                } label: {
                    Label("Summarize with AI", systemImage: "sparkles")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)
                .buttonBorderShape(.capsule)
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
            }
        }
    }

    // MARK: - Page Indicator

    private var pageIndicator: some View {
        HStack(spacing: 20) {
            pageTab(title: "Details", icon: "info.circle", index: 0)
            pageTab(title: "Transcript", icon: "text.quote", index: 1)
            pageTab(title: "Summary", icon: "sparkles", index: 2)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 24)
        .background(.bar)
    }

    private func pageTab(title: String, icon: String, index: Int) -> some View {
        Button {
            withAnimation { currentPage = index }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.body)
                Text(title)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .foregroundStyle(currentPage == index ? .indigo : .secondary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Generate Summary

    private func generateSummary() async {
        guard !service.transcriptionText.isEmpty else { return }

        isSummarizing = true
        summaryError = nil

        do {
            summaryText = try await GeminiService.summarize(
                transcript: service.transcriptionText)
        } catch {
            summaryError = error.localizedDescription
        }

        isSummarizing = false
        saveToDevice()
    }

    // MARK: - Persistence

    private func loadSaved() {
        guard let url = episode.audioURL,
              let record = TranscriptionStore.load(audioURL: url, context: modelContext)
        else { return }
        service.transcriptionText = record.transcription
        summaryText = record.summary ?? ""
        isSaved = true
    }

    private func saveToDevice() {
        guard let url = episode.audioURL,
              !service.transcriptionText.isEmpty
        else { return }
        TranscriptionStore.save(
            audioURL: url,
            transcription: service.transcriptionText,
            summary: summaryText.isEmpty ? nil : summaryText,
            context: modelContext
        )
        isSaved = true
    }
}
