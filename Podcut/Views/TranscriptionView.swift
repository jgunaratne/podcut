import SwiftUI

/// Displays the transcription of a podcast episode.
struct TranscriptionView: View {
    let episode: Episode
    @State private var service = TranscriptionService()

    // Summary state.
    @State private var summaryText: String = ""
    @State private var isSummarizing = false
    @State private var summaryError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header.
                VStack(alignment: .leading, spacing: 6) {
                    Text(episode.title)
                        .font(.title3.bold())

                    if !episode.pubDate.isEmpty {
                        Text(episode.pubDate)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)

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

                            // Copy button.
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

                    // Summary section.
                    summarySection

                } else if !service.isTranscribing && service.errorMessage == nil {
                    ContentUnavailableView(
                        "No Transcription Yet",
                        systemImage: "text.below.photo",
                        description: Text("Tap the button below to start transcribing.")
                    )
                }

                Spacer(minLength: 80)
            }
            .padding(.top)
        }
        .navigationTitle("Transcription")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if !service.isTranscribing && service.transcriptionText.isEmpty {
                Button {
                    Task {
                        guard let url = episode.audioURL else { return }
                        await service.transcribe(audioURL: url)
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

    // MARK: - Summary Section

    @ViewBuilder
    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("AI Summary", systemImage: "sparkles")
                    .font(.headline)
                    .foregroundStyle(.indigo)

                Spacer()

                if summaryText.isEmpty && !isSummarizing {
                    Button {
                        Task { await generateSummary() }
                    } label: {
                        Label("Summarize", systemImage: "sparkles")
                            .font(.subheadline)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.indigo)
                    .buttonBorderShape(.capsule)
                }
            }

            if isSummarizing {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Generating summary…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if let error = summaryError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            if !summaryText.isEmpty {
                Text(summaryText)
                    .font(.body)
                    .textSelection(.enabled)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        .indigo.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 14)
                    )

                // Copy summary.
                Button {
                    UIPasteboard.general.string = summaryText
                } label: {
                    Label("Copy Summary", systemImage: "doc.on.doc")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
            }
        }
        .padding(.horizontal)
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
    }
}
