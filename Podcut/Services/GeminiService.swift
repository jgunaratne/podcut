import FirebaseAI
import Foundation

/// Calls Gemini 2.5 Flash Lite via Firebase AI to summarize text.
struct GeminiService {
    /// Summarize the given podcast transcript using Gemini 2.5 Flash Lite via Firebase AI.
    static func summarize(transcript: String) async throws -> String {
        let model = FirebaseAI.firebaseAI(backend: .googleAI())
            .generativeModel(modelName: "gemini-2.5-flash-lite")

        let prompt = """
            You are an expert podcast analyst. Summarize the following podcast transcript into \
            a concise, well-structured summary. Include the key topics discussed, main takeaways, \
            and any notable quotes or insights. Use bullet points for clarity.

            TRANSCRIPT:
            \(transcript)
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
}

enum GeminiError: LocalizedError {
    case emptyResponse
    case firebaseAI(detail: String)

    var errorDescription: String? {
        switch self {
        case .emptyResponse:
            return "Gemini returned an empty response."
        case .firebaseAI(let detail):
            return "Gemini error: \(detail)"
        }
    }
}
