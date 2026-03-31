import SwiftUI

/// A single chat message.
struct ChatMessage: Identifiable, Hashable {
    let id = UUID()
    let role: String   // "user" or "assistant"
    let text: String
}

/// Chat view for RAG-style Q&A with the podcast transcript.
struct PodcastChatView: View {
    let transcript: String
    let segments: [TranscriptionSegment]

    @State private var messages: [ChatMessage] = []
    @State private var inputText: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isAnimatingBouncingDots = false
    @State private var suggestions: [String] = []
    @State private var isLoadingSuggestions = false
    @State private var showSuggestions = false

    var body: some View {
        VStack(spacing: 0) {
            if transcript.isEmpty {
                ContentUnavailableView(
                    "Transcribe First",
                    systemImage: "bubble.left.and.text.bubble.right",
                    description: Text("Transcribe the episode first, then you can ask questions about anything discussed.")
                )
            } else {
                chatContent
            }
        }
        .task(priority: .high) {
            if suggestions.isEmpty && !transcript.isEmpty {
                await loadSuggestions()
            }
        }
    }

    // MARK: - Chat Content

    private var chatContent: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if messages.isEmpty {
                            welcomeBubble
                        }

                        ForEach(messages) { message in
                            messageBubble(message)
                                .id(message.id)
                        }

                        if isLoading {
                            typingIndicator()
                                .id("loading")
                        }
                    }
                    .padding(.vertical, 12)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: messages.count) {
                    if let last = messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    } else if isLoading {
                        withAnimation { proxy.scrollTo("loading", anchor: .bottom) }
                    }
                }
            }

            if showSuggestions && !suggestions.isEmpty {
                suggestionsBar
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
                    .padding(.bottom, 4)
            }

            inputBar
        }
    }

    // MARK: - Welcome

    private var welcomeBubble: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Label("Podcast Chat", systemImage: "sparkles")
                    .font(.headline)
                    .foregroundStyle(.blue.gradient)

                Text("Ask me anything about this episode.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if isLoadingSuggestions {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Analyzing transcript…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 2)
                } else if !suggestions.isEmpty {
                    FlowLayout(spacing: 6) {
                        ForEach(suggestions, id: \.self) { suggestion in
                            suggestionChip(suggestion)
                        }
                        generateMoreChip
                    }
                    .padding(.top, 4)
                }
            }
            .padding(16)
            .glassEffect(.regular, in: .rect(cornerRadius: 16))

            Spacer()
        }
        .padding(.horizontal)
    }

    // MARK: - Suggestions Bar

    private var suggestionsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button {
                        inputText = suggestion
                        sendMessage()
                        showSuggestions = false
                    } label: {
                        Text(suggestion)
                            .font(.caption)
                            .lineLimit(1)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                    }
                    .glassEffect(.regular, in: .capsule)
                    .buttonStyle(.plain)
                }

                Button {
                    Task { await loadSuggestions() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption2)
                        Text("More")
                            .font(.caption)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .glassEffect(.regular.tint(.orange), in: .capsule)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func suggestionChip(_ text: String) -> some View {
        Button {
            inputText = text
            sendMessage()
        } label: {
            Text(text)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
        }
        .glassEffect(.regular, in: .capsule)
        .buttonStyle(.plain)
    }

    private var generateMoreChip: some View {
        Button {
            Task { await loadSuggestions() }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrow.clockwise")
                    .font(.caption2)
                Text("More")
                    .font(.caption)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .glassEffect(.regular.tint(.orange), in: .capsule)
        .buttonStyle(.plain)
    }

    // MARK: - Message Bubble

    private func messageBubble(_ message: ChatMessage) -> some View {
        let isUser = message.role == "user"

        return HStack {
            if isUser { Spacer(minLength: 60) }

            Text(message.text)
                .font(.body)
                .textSelection(.enabled)
                .foregroundStyle(isUser ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .if(isUser) { view in
                    view.background(.blue.gradient, in: bubbleShape(isUser: true))
                }
                .if(!isUser) { view in
                    view.glassEffect(.regular, in: bubbleShape(isUser: false))
                }

            if !isUser { Spacer(minLength: 60) }
        }
        .padding(.horizontal)
        .transition(.scale(scale: 0.9, anchor: isUser ? .bottomTrailing : .bottomLeading).combined(with: .opacity))
    }

    private func bubbleShape(isUser: Bool) -> some Shape {
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

    private func typingIndicator() -> some View {
        HStack {
            HStack(spacing: 5) {
                ForEach(0..<3) { i in
                    Circle()
                        .frame(width: 8, height: 8)
                        .foregroundStyle(.secondary)
                        .scaleEffect(isAnimatingBouncingDots ? 1 : 0.5)
                        .animation(
                            .easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(0.2 * Double(i)),
                            value: isAnimatingBouncingDots
                        )
                }
            }
            .onAppear { isAnimatingBouncingDots = true }
            .padding(16)
            .glassEffect(.regular, in: bubbleShape(isUser: false))

            Spacer()
        }
        .padding(.horizontal)
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 10) {
            // Suggestions toggle button.
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showSuggestions.toggle()
                }
            } label: {
                Image(systemName: showSuggestions ? "lightbulb.fill" : "lightbulb")
                    .font(.title3)
                    .foregroundStyle(showSuggestions ? .blue : .secondary)
                    .frame(width: 36, height: 36)
                    .contentTransition(.symbolEffect(.replace))
            }
            .disabled(suggestions.isEmpty && !isLoadingSuggestions)

            TextField("Ask about this episode…", text: $inputText, axis: .vertical)
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
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
            .animation(.easeInOut, value: inputText.isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: .rect)
    }

    // MARK: - Send

    private func sendMessage() {
        let question = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !isLoading else { return }

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        inputText = ""
        showSuggestions = false
        messages.append(ChatMessage(role: "user", text: question))
        errorMessage = nil
        isLoading = true

        let context: String
        if !segments.isEmpty {
            context = segments.map { "[\($0.formattedTime)] \($0.text)" }
                .joined(separator: "\n")
        } else {
            context = transcript
        }

        let history = messages.suffix(10).map { (role: $0.role, text: $0.text) }

        Task {
            do {
                let answer = try await GeminiService.chat(
                    transcript: context,
                    history: history,
                    question: question
                )
                withAnimation(.spring) {
                    messages.append(ChatMessage(role: "assistant", text: answer))
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    // MARK: - Load Suggestions

    private func loadSuggestions() async {
        isLoadingSuggestions = true
        do {
            let newSuggestions = try await GeminiService.suggestQuestions(transcript: transcript)
            // Append new suggestions, avoiding duplicates
            let existing = Set(suggestions)
            let unique = newSuggestions.filter { !existing.contains($0) }
            suggestions.append(contentsOf: unique)
        } catch {
            // Fall back to generic suggestions only if empty
            if suggestions.isEmpty {
                suggestions = [
                    "What are the main topics?",
                    "What were the key takeaways?",
                    "Who was mentioned in this episode?",
                ]
            }
        }
        isLoadingSuggestions = false
    }
}

// MARK: - Conditional View Modifier

private extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Flow Layout for suggestion chips

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews)
        -> (positions: [CGPoint], size: CGSize)
    {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (positions, CGSize(width: maxWidth, height: y + rowHeight))
    }
}
