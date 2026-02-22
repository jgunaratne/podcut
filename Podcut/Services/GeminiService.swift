import FirebaseAI
import Foundation

/// Calls Gemini 2.5 Flash via Firebase AI to summarize text.
struct GeminiService {
    /// Summarize the given podcast transcript using Gemini 2.5 Flash via Firebase AI.
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

        let response = try await model.generateContent(prompt)

        guard let text = response.text else {
            throw GeminiError.emptyResponse
        }

        return text
    }
}

enum GeminiError: LocalizedError {
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .emptyResponse:
            return "Gemini returned an empty response."
        }
    }
}
