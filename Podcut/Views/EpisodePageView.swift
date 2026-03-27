import SwiftData
import SwiftUI

/// A swipeable page view for an episode: Detail → Transcription → Summary → Chat.
struct EpisodePageView: View {
    let episode: Episode
    @State private var currentPage = 0
    @Namespace private var tabs
    @State private var service = TranscriptionService()
    @Environment(\.modelContext) private var modelContext
    @Environment(AudioPlayerManager.self) private var player

    // Summary state.
    @State private var summaryText: String = ""
    @State private var isSummarizing = false
    @State private var summaryError: String?
    @State private var isSaved = false
    @State private var showPaywall = false

    var body: some View {
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

            // Page 4: Chat with Transcript
            PodcastChatView(
                transcript: service.transcriptionText,
                segments: service.segments
            )
            .tag(3)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .animation(.easeInOut(duration: 0.3), value: currentPage)
        .safeAreaInset(edge: .bottom) {
            // Page indicator overlays the bottom — content scrolls under it.
            // Add extra padding when mini player is visible so tabs aren't hidden behind it.
            VStack(spacing: 0) {
                pageIndicator
                if player.currentEpisode != nil {
                    Color.clear.frame(height: 64)
                }
            }
        }
        
        .navigationTitle(episode.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadSaved() }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .onChange(of: currentPage) { oldPage, newPage in
            // Gate Summary (2) and Chat (3) behind Pro.
            if (newPage == 2 || newPage == 3), !SubscriptionManager.shared.isPro {
                currentPage = oldPage
                showPaywall = true
            }
        }
        .task { await SubscriptionManager.shared.loadProducts() }
    }

    // MARK: - HTML Description Rendering

    /// Renders the episode description, detecting HTML and converting it to styled text.
    /// Handles dark mode by stripping inline color styles and applying system colors.
    @ViewBuilder
    private var renderedDescription: some View {
        if episode.description.contains("<") && episode.description.contains(">") {
            let cleaned = Self.renderHTMLDescription(episode.description)
            if let attributed = cleaned {
                Text(attributed)
                    .font(.body)
                    .tint(.blue)
            } else {
                Text(Self.stripHTML(episode.description))
                    .font(.body)
            }
        } else if !episode.description.isEmpty {
            Text(episode.description)
                .font(.body)
        }
    }

    /// Convert HTML description to AttributedString, fixing dark mode issues.
    private static func renderHTMLDescription(_ html: String) -> AttributedString? {
        // Wrap in a template that forces system-compatible colors.
        let styledHTML = """
        <html><head><style>
        body { font-family: -apple-system; font-size: 16px; color: \(UIColor.label.cssString); }
        a { color: #007AFF; }
        </style></head><body>\(html)</body></html>
        """

        guard let data = styledHTML.data(using: .utf8),
              let nsAttr = try? NSAttributedString(
                  data: data,
                  options: [
                      .documentType: NSAttributedString.DocumentType.html,
                      .characterEncoding: String.Encoding.utf8.rawValue,
                  ],
                  documentAttributes: nil
              ),
              let attributed = try? AttributedString(nsAttr)
        else { return nil }

        return attributed
    }

    /// Strip HTML tags as a fallback for unparseable content.
    private static func stripHTML(_ html: String) -> String {
        html.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
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
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    if player.currentEpisode?.id == episode.id {
                        player.togglePlayPause()
                    } else {
                        player.play(episode: episode)
                    }
                } label: {
                    if player.currentEpisode?.id == episode.id && player.isLoading {
                        HStack(spacing: 8) {
                            ProgressView()
                                .tint(.white)
                            Text("Loading…")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    } else {
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
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .disabled(player.currentEpisode?.id == episode.id && player.isLoading)
                .padding(.horizontal, 24)

                // Playback error.
                if let error = player.errorMessage,
                   player.currentEpisode == nil || player.currentEpisode?.id == episode.id {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle")
                        Text(error)
                    }
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 24)
                }

                // Description.
                if !episode.description.isEmpty {
                    ExpandableDescription(episode: episode) {
                        renderedDescription
                    }
                    .padding(.horizontal)
                }

                // Hint to swipe.
                HStack(spacing: 6) {
                    Image(systemName: "hand.draw")
                    Text("Swipe left for transcription")
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                }
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
                            .tint(.blue)
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
                        HStack(spacing: 16) {
                            Text("Transcription")
                                .font(.headline)

                            Spacer()

                            Button {
                                Task {
                                    guard let url = episode.audioURL else { return }
                                    service.transcriptionText = ""
                                    service.segments = []
                                    summaryText = ""
                                    AudioCache.shared.removeCached(for: url)
                                    do {
                                        let localFile = try await AudioCache.shared.localURL(for: url)
                                        await service.transcribe(localFileURL: localFile)
                                        saveToDevice()
                                    } catch {
                                        service.errorMessage = "Failed to download audio: \(error.localizedDescription)"
                                    }
                                }
                            } label: {
                                Image(systemName: "arrow.clockwise")
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                            }
                            .disabled(service.isTranscribing)

                            Button {
                                UIPasteboard.general.string = service.transcriptionText
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        // Timestamped segments.
                        VStack(spacing: 0) {
                            ForEach(service.segments) { segment in
                                HStack(alignment: .top, spacing: 14) {
                                    // Tappable timecode.
                                    Button {
                                        seekAndPlay(seconds: segment.timestamp)
                                    } label: {
                                        Text(segment.formattedTime)
                                            .font(.caption.monospacedDigit().weight(.semibold))
                                            .foregroundStyle(.blue)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 3)
                                            .background(Color.blue.opacity(0.12), in: Capsule())
                                    }
                                    .buttonStyle(.plain)
                                    .frame(width: 54, alignment: .leading)
                                    .padding(.top, 2)

                                    Text(segment.text)
                                        .font(.body)
                                        .lineSpacing(4)
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .foregroundStyle(.primary.opacity(0.9))
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 14)

                                if segment.id != service.segments.last?.id {
                                    Divider().padding(.leading, 82)
                                }
                            }
                        }
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        
                    }
                    .padding(.horizontal)

                } else if !service.transcriptionText.isEmpty {
                    // Fallback for legacy data without segments.
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Transcription")
                            .font(.headline)

                        Text(service.transcriptionText)
                            .font(.body)
                            .textSelection(.enabled)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
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
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    Task {
                        guard let url = episode.audioURL else { return }
                        do {
                            let localFile = try await AudioCache.shared.localURL(for: url)
                            await service.transcribe(localFileURL: localFile)
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                            saveToDevice()
                        } catch {
                            service.errorMessage = "Failed to download audio: \(error.localizedDescription)"
                        }
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
                        HStack(spacing: 16) {
                            Text("AI Summary")
                                .font(.headline)

                            Spacer()

                            Button {
                                summaryText = ""
                                Task { await generateSummary() }
                            } label: {
                                Image(systemName: "arrow.clockwise")
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                            }
                            .disabled(isSummarizing)

                            Button {
                                UIPasteboard.general.string = summaryText
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                            }

                            ShareLink(
                                item: "\(episode.title)\n\n\(summaryText)\n\n— Summarized with Podcut",
                                subject: Text(episode.title),
                                message: Text("Check out this podcast summary")
                            ) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        // Render summary with tappable timecodes.
                        summaryWithTimecodes
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                Color(.secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
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
                .tint(.blue)
                .buttonBorderShape(.capsule)
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
            }
        }
    }

    // MARK: - Page Indicator

    private var pageIndicator: some View {
        HStack(spacing: 0) {
            pageTab(icon: "info.circle", selectedIcon: "info.circle.fill", index: 0)
            pageTab(icon: "doc.text", selectedIcon: "doc.text.fill", index: 1)
            pageTab(icon: "wand.and.stars", selectedIcon: "wand.and.stars.inverse", index: 2)
            pageTab(icon: "bubble.left.and.text.bubble.right", selectedIcon: "bubble.left.and.text.bubble.right.fill", index: 3)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
    }

    private func pageTab(icon: String, selectedIcon: String, index: Int) -> some View {
        let isSelected = currentPage == index
        let isProFeature = index > 1
        
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                currentPage = index
            }
        } label: {
            VStack(spacing: 3) {
                ZStack {
                    if isSelected {
                        Capsule()
                            .fill(.blue)
                            .frame(width: 60, height: 32)
                            .matchedGeometryEffect(id: "selectedTab", in: tabs)
                    }
                    
                    Image(systemName: isSelected ? selectedIcon : icon)
                        .font(.title3.weight(isSelected ? .bold : .regular))
                        .symbolRenderingMode(isProFeature ? .multicolor : .monochrome)
                }
                .frame(height: 32)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .foregroundStyle(isSelected ? .white : .secondary)
        }
        .buttonStyle(.plain)
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
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                if line.trimmingCharacters(in: .whitespaces).isEmpty {
                    Spacer().frame(height: 2)
                } else {
                    summaryLine(line)
                        .lineSpacing(4)
                }
            }
        }
        .font(.body)
        .foregroundStyle(.primary.opacity(0.9))
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
                return result + Text(display).foregroundColor(.blue).underline()
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
        // If a different episode (or none) is playing, start this episode first.
        if player.currentEpisode?.id != episode.id {
            player.play(episode: episode)
            Task {
                // Wait for the player to load and report a valid duration.
                for _ in 0..<40 {  // Up to 4 seconds
                    try? await Task.sleep(for: .milliseconds(100))
                    if player.duration > 0 { break }
                }
                guard player.duration > 0 else { return }
                player.seek(to: seconds / player.duration)
            }
            return
        }
        guard player.duration > 0 else { return }
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
