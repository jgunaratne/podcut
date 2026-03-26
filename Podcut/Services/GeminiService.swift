import FirebaseAI
import Foundation

/// Calls Gemini 2.5 Flash Lite via Firebase AI to summarize text.
struct GeminiService {
    /// Summarize the given podcast transcript using Gemini 2.5 Flash Lite via Firebase AI.
    /// Accepts timestamped segments so the summary can include timecodes.
    /// Maximum transcript characters to send to Gemini (roughly 200k tokens).
    private static let maxTranscriptLength = 500_000

    static func summarize(segments: [TranscriptionSegment]) async throws -> String {
        let model = FirebaseAI.firebaseAI(backend: .googleAI())
            .generativeModel(modelName: "gemini-2.5-flash-lite")

        // Build a timestamped transcript for the prompt.
        var timestampedTranscript = segments.map { segment in
            "[\(segment.formattedTime)] \(segment.text)"
        }.joined(separator: "\n")

        // Truncate very long transcripts to avoid exceeding context window.
        if timestampedTranscript.count > maxTranscriptLength {
            timestampedTranscript = String(timestampedTranscript.prefix(maxTranscriptLength))
                + "\n\n[Transcript truncated — episode too long for full analysis]"
        }

        let prompt = """
            You are an expert podcast analyst. Summarize the following timestamped podcast \
            transcript into a concise, well-structured summary.

            IMPORTANT FORMAT RULES:
            - Use markdown bullet points for each key point.
            - Start EVERY bullet point with a timecode in the format [MM:SS] that references \
              when that topic is discussed in the episode.
            - Choose the most relevant timecode from the transcript for each point.
            - Include the key topics discussed, main takeaways, and any notable quotes or insights.

            Example format:
            - [2:15] **Topic Name** — Brief description of the key point discussed.
            - [8:42] **Another Topic** — Description with notable quote or insight.

            TIMESTAMPED TRANSCRIPT:
            \(timestampedTranscript)
            """

        do {
            let response = try await model.generateContent(prompt)

            guard let text = response.text else {
                throw GeminiError.emptyResponse
            }

            return text
        } catch let error as GenerateContentError {
            // Surface the detailed Firebase AI error.
            throw GeminiError.firebaseAI(detail: String(describing: error))
        }
    }

    /// Fallback summarize without timestamps (for legacy data).
    static func summarize(transcript: String) async throws -> String {
        let model = FirebaseAI.firebaseAI(backend: .googleAI())
            .generativeModel(modelName: "gemini-2.5-flash-lite")

        let safeTranscript = transcript.count > maxTranscriptLength
            ? String(transcript.prefix(maxTranscriptLength)) + "\n\n[Transcript truncated]"
            : transcript

        let prompt = """
            You are an expert podcast analyst. Summarize the following podcast transcript into \
            a concise, well-structured summary. Include the key topics discussed, main takeaways, \
            and any notable quotes or insights. Use bullet points for clarity.

            TRANSCRIPT:
            \(safeTranscript)
            """

        do {
            let response = try await model.generateContent(prompt)

            guard let text = response.text else {
                throw GeminiError.emptyResponse
            }

            return text
        } catch let error as GenerateContentError {
            throw GeminiError.firebaseAI(detail: String(describing: error))
        }
    }

    /// Chat with Gemini about a podcast transcript (RAG-style).
    /// Sends the transcript as context along with the user question and chat history.
    static func chat(
        transcript: String,
        history: [(role: String, text: String)],
        question: String
    ) async throws -> String {
        let model = FirebaseAI.firebaseAI(backend: .googleAI())
            .generativeModel(modelName: "gemini-2.5-flash-lite")

        // Build conversation history as text.
        let historyText = history.map { "\($0.role): \($0.text)" }
            .joined(separator: "\n")

        let prompt = """
            You are a helpful podcast assistant. Answer the user's question based ONLY on \
            the podcast transcript provided below. If the answer isn't in the transcript, \
            say so. Be concise and reference specific parts of the transcript when relevant. \
            Use timecodes from the transcript in your answer when applicable.

            PODCAST TRANSCRIPT:
            \(transcript.count > maxTranscriptLength ? String(transcript.prefix(maxTranscriptLength)) + "\n[Truncated]" : transcript)

            \(historyText.isEmpty ? "" : "CONVERSATION HISTORY:\n\(historyText)\n")
            USER QUESTION: \(question)
            """

        do {
            let response = try await model.generateContent(prompt)
            guard let text = response.text else {
                throw GeminiError.emptyResponse
            }
            return text
        } catch let error as GenerateContentError {
            throw GeminiError.firebaseAI(detail: String(describing: error))
        }
    }
}

enum GeminiError: LocalizedError {
    case emptyResponse
    case firebaseAI(detail: String)
    case timeout
    case noConnection

    var errorDescription: String? {
        switch self {
        case .emptyResponse:
            return "AI returned an empty response. Please try again."
        case .firebaseAI(let detail):
            if detail.lowercased().contains("quota") || detail.lowercased().contains("rate") {
                return "AI service is temporarily busy. Please wait a moment and try again."
            }
            if detail.lowercased().contains("network") || detail.lowercased().contains("offline") {
                return "No internet connection. Connect to the internet and try again."
            }
            return "AI service error. Please try again later."
        case .timeout:
            return "Request timed out. The episode may be too long — try a shorter one."
        case .noConnection:
            return "No internet connection. Connect to the internet to use AI features."
        }
    }
}
