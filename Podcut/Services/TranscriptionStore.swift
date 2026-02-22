import Foundation
import SwiftData

/// A saved transcription record stored in SwiftData (SQLite).
@Model
final class TranscriptionRecord {
    /// The episode audio URL string used as a unique key.
    @Attribute(.unique) var audioURLString: String
    var transcription: String
    var summary: String?
    var savedAt: Date

    init(audioURLString: String, transcription: String, summary: String? = nil) {
        self.audioURLString = audioURLString
        self.transcription = transcription
        self.summary = summary
        self.savedAt = Date()
    }
}

/// Convenience API for saving/loading transcriptions via SwiftData.
struct TranscriptionStore {
    /// Save a transcription (and optional summary) for the given episode audio URL.
    @MainActor
    static func save(
        audioURL: URL,
        transcription: String,
        summary: String? = nil,
        context: ModelContext
    ) {
        let key = audioURL.absoluteString
        let descriptor = FetchDescriptor<TranscriptionRecord>(
            predicate: #Predicate { $0.audioURLString == key }
        )

        if let existing = try? context.fetch(descriptor).first {
            // Update existing record.
            existing.transcription = transcription
            existing.summary = summary ?? existing.summary
            existing.savedAt = Date()
        } else {
            // Insert new record.
            let record = TranscriptionRecord(
                audioURLString: key,
                transcription: transcription,
                summary: summary
            )
            context.insert(record)
        }

        try? context.save()
    }

    /// Load a previously saved transcription for the given episode audio URL.
    @MainActor
    static func load(audioURL: URL, context: ModelContext) -> TranscriptionRecord? {
        let key = audioURL.absoluteString
        let descriptor = FetchDescriptor<TranscriptionRecord>(
            predicate: #Predicate { $0.audioURLString == key }
        )
        return try? context.fetch(descriptor).first
    }
}
