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

    // MARK: - HTML Description Rendering

    /// Renders the episode description, detecting HTML and converting it to styled text.
    @ViewBuilder
    private var renderedDescription: some View {
        if episode.description.contains("<") && episode.description.contains(">"),
           let data = episode.description.data(using: .utf8),
           let nsAttr = try? NSAttributedString(
               data: data,
               options: [
                   .documentType: NSAttributedString.DocumentType.html,
                   .characterEncoding: String.Encoding.utf8.rawValue,
               ],
               documentAttributes: nil
           ),
           let attributed = try? AttributedString(nsAttr)
        {
            Text(attributed)
                .font(.body)
        } else {
            Text(episode.description)
                .font(.body)
        }
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

                        renderedDescription
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

                // Transcription with timecodes.
                if !service.segments.isEmpty {
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

                        // Timestamped segments.
                        VStack(spacing: 0) {
                            ForEach(service.segments) { segment in
                                HStack(alignment: .top, spacing: 12) {
                                    // Tappable timecode.
                                    Button {
                                        seekAndPlay(seconds: segment.timestamp)
                                    } label: {
                                        Text(segment.formattedTime)
                                            .font(.caption.monospacedDigit())
                                            .foregroundStyle(.indigo)
                                    }
                                    .buttonStyle(.plain)
                                    .frame(width: 44, alignment: .trailing)

                                    Text(segment.text)
                                        .font(.body)
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)

                                if segment.id != service.segments.last?.id {
                                    Divider().padding(.leading, 56)
                                }
                            }
                        }
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal)

                } else if !service.transcriptionText.isEmpty {
                    // Fallback for legacy data without segments.
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Transcription", systemImage: "text.quote")
                            .font(.headline)

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

                        // Render summary with tappable timecodes.
                        summaryWithTimecodes
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
        HStack(spacing: 0) {
            pageTab(title: "Details", icon: "info.circle", index: 0)
            pageTab(title: "Transcript", icon: "text.quote", index: 1)
            pageTab(title: "Summary", icon: "sparkles", index: 2)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(.bar)
    }

    private func pageTab(title: String, icon: String, index: Int) -> some View {
        let isSelected = currentPage == index
        return Button {
            withAnimation(.easeInOut(duration: 0.25)) { currentPage = index }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: isSelected ? icon + ".fill" : icon)
                    .font(.body.weight(isSelected ? .semibold : .regular))
                    .contentTransition(.symbolEffect(.replace))
                Text(title)
                    .font(.caption2.weight(isSelected ? .medium : .regular))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .foregroundStyle(isSelected ? .indigo : .secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    // MARK: - Generate Summary

    private func generateSummary() async {
        guard !service.transcriptionText.isEmpty else { return }

        isSummarizing = true
        summaryError = nil

        do {
            if !service.segments.isEmpty {
                summaryText = try await GeminiService.summarize(
                    segments: service.segments)
            } else {
                summaryText = try await GeminiService.summarize(
                    transcript: service.transcriptionText)
            }
        } catch {
            summaryError = error.localizedDescription
        }

        isSummarizing = false
        saveToDevice()
    }

    // MARK: - Tappable Summary with Timecodes

    /// Renders the summary markdown with [MM:SS] timecodes as tappable buttons.
    @ViewBuilder
    private var summaryWithTimecodes: some View {
        let lines = summaryText.components(separatedBy: "\n")
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                if line.trimmingCharacters(in: .whitespaces).isEmpty {
                    Spacer().frame(height: 4)
                } else {
                    summaryLine(line)
                }
            }
        }
        .font(.body)
    }

    /// Renders a single summary line, replacing [MM:SS] patterns with tappable buttons.
    @ViewBuilder
    private func summaryLine(_ line: String) -> some View {
        let parts = parseTimecodes(in: line)
        let flow = parts.reduce(Text("")) { result, part in
            switch part {
            case .text(let str):
                // Render as markdown inline.
                if let attr = try? AttributedString(
                    markdown: str,
                    options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
                ) {
                    return result + Text(attr)
                } else {
                    return result + Text(str)
                }
            case .timecode(let display, _):
                return result + Text(display).foregroundColor(.indigo).underline()
            }
        }

        // Check if the line has any timecodes to make tappable.
        let timecodes = parts.compactMap { part -> (String, TimeInterval)? in
            if case .timecode(let display, let seconds) = part {
                return (display, seconds)
            }
            return nil
        }

        if let first = timecodes.first {
            // Make the whole line tappable to the first timecode.
            HStack(alignment: .top, spacing: 0) {
                Button {
                    seekAndPlay(seconds: first.1)
                } label: {
                    flow.multilineTextAlignment(.leading)
                }
                .buttonStyle(.plain)
            }
        } else {
            flow.textSelection(.enabled)
        }
    }

    // MARK: - Timecode Parsing

    private enum SummaryPart {
        case text(String)
        case timecode(display: String, seconds: TimeInterval)
    }

    /// Parse [MM:SS] or [H:MM:SS] patterns from a string.
    private func parseTimecodes(in text: String) -> [SummaryPart] {
        var parts: [SummaryPart] = []
        let pattern = #"\[(\d{1,2}:\d{2}(?::\d{2})?)\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return [.text(text)]
        }

        let nsText = text as NSString
        var lastEnd = 0

        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        for match in matches {
            let matchRange = match.range
            if matchRange.location > lastEnd {
                let prefix = nsText.substring(with: NSRange(location: lastEnd, length: matchRange.location - lastEnd))
                parts.append(.text(prefix))
            }

            let timeString = nsText.substring(with: match.range(at: 1))
            let display = nsText.substring(with: matchRange)
            let seconds = parseTimeToSeconds(timeString)
            parts.append(.timecode(display: display, seconds: seconds))

            lastEnd = matchRange.location + matchRange.length
        }

        if lastEnd < nsText.length {
            parts.append(.text(nsText.substring(from: lastEnd)))
        }

        return parts.isEmpty ? [.text(text)] : parts
    }

    /// Convert "MM:SS" or "H:MM:SS" to seconds.
    private func parseTimeToSeconds(_ time: String) -> TimeInterval {
        let components = time.split(separator: ":").compactMap { Int($0) }
        switch components.count {
        case 2:
            return TimeInterval(components[0] * 60 + components[1])
        case 3:
            return TimeInterval(components[0] * 3600 + components[1] * 60 + components[2])
        default:
            return 0
        }
    }

    // MARK: - Audio Seek

    private func seekAndPlay(seconds: TimeInterval) {
        guard player.duration > 0 else {
            // If not playing, start the episode first.
            if let url = episode.audioURL {
                player.play(episode: episode)
                // Delay the seek slightly to allow the player to load.
                Task {
                    try? await Task.sleep(for: .milliseconds(500))
                    player.seek(to: seconds / max(player.duration, 1))
                }
            }
            return
        }
        player.seek(to: seconds / player.duration)
    }

    // MARK: - Persistence

    private func loadSaved() {
        guard let url = episode.audioURL,
              let record = TranscriptionStore.load(audioURL: url, context: modelContext)
        else { return }
        service.transcriptionText = record.transcription
        service.segments = record.segments
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
            segments: service.segments,
            context: modelContext
        )
        isSaved = true
    }
}
