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
    }

    // MARK: - Chat Content

    private var chatContent: some View {
        VStack(spacing: 0) {
            // Messages.
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        // Welcome message.
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

            // Error.
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
                    .padding(.bottom, 4)
            }

            // Input bar.
            inputBar
        }
        .background(.background)
    }

    // MARK: - Welcome

    private var welcomeBubble: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Label("Podcast Chat", systemImage: "sparkles.fill")
                    .font(.headline)
                    .foregroundStyle(.cyan.gradient)

                Text("Ask me anything about this episode. I'll answer based on the transcript.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                // Suggestion chips.
                FlowLayout(spacing: 6) {
                    suggestionChip("What are the main topics?")
                    suggestionChip("Summarize the key takeaways")
                    suggestionChip("What was the most interesting point?")
                }
                .padding(.top, 4)
            }
            .padding(16)
            .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(.quaternary, lineWidth: 1)
            }
            Spacer()
        }
        .padding(.horizontal)
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
                .background(.cyan.opacity(0.12), in: Capsule())
                .foregroundStyle(.cyan)
        }
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
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    isUser
                        ? AnyShapeStyle(.blue.gradient)
                        : AnyShapeStyle(.quaternary),
                    in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                )
                .clipShape(bubbleShape(isUser: isUser))
                .foregroundStyle(isUser ? .white : .primary)
            
            if !isUser { Spacer(minLength: 60) }
        }
        .padding(.horizontal)
        .transition(.scale(scale: 0.9, anchor: isUser ? .bottomTrailing : .bottomLeading).combined(with: .opacity))
    }
    
    private func bubbleShape(isUser: Bool) -> some Shape {
        let corners: UIRectCorner = isUser
            ? [.topLeft, .bottomLeft, .topRight]
            : [.topRight, .bottomRight, .topLeft]
        
        return UnevenRoundedRectangle(
            cornerRadii: .init(
                topLeading: corners.contains(.topLeft) ? 20 : 6,
                bottomLeading: corners.contains(.bottomLeft) ? 20 : 6,
                bottomTrailing: corners.contains(.bottomRight) ? 20 : 6,
                topTrailing: corners.contains(.topRight) ? 20 : 6
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
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .clipShape(bubbleShape(isUser: false))
            
            Spacer()
        }
        .padding(.horizontal)
    }


    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Ask about this episode…", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...4)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.quaternary, in: Capsule())
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
        .background(.bar)
    }

    // MARK: - Send

    private func sendMessage() {
        let question = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !isLoading else { return }

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        inputText = ""
        messages.append(ChatMessage(role: "user", text: question))
        errorMessage = nil
        isLoading = true

        // Build timestamped transcript for context.
        let context: String
        if !segments.isEmpty {
            context = segments.map { "[\($0.formattedTime)] \($0.text)" }
                .joined(separator: "\n")
        } else {
            context = transcript
        }

        // Build history (last 10 messages for context window).
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
