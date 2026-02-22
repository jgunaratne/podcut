import SwiftUI

/// Displays the transcription of a podcast episode.
struct TranscriptionView: View {
    let episode: Episode
    @State private var service = TranscriptionService()

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

                // Status / progress.
                if service.isTranscribing {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text(service.progress)
                            .font(.subheadline)
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
}
