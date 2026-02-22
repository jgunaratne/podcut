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
    /// JSON-encoded array of TranscriptionSegment for timestamped text.
    var segmentsJSON: Data?

    init(audioURLString: String, transcription: String, summary: String? = nil, segmentsJSON: Data? = nil) {
        self.audioURLString = audioURLString
        self.transcription = transcription
        self.summary = summary
        self.segmentsJSON = segmentsJSON
        self.savedAt = Date()
    }

    /// Decode stored segments.
    var segments: [TranscriptionSegment] {
        guard let data = segmentsJSON else { return [] }
        return (try? JSONDecoder().decode([TranscriptionSegment].self, from: data)) ?? []
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
        segments: [TranscriptionSegment] = [],
        context: ModelContext
    ) {
        let key = audioURL.absoluteString
        let descriptor = FetchDescriptor<TranscriptionRecord>(
            predicate: #Predicate { $0.audioURLString == key }
        )

        let segmentsData = segments.isEmpty ? nil : try? JSONEncoder().encode(segments)

        if let existing = try? context.fetch(descriptor).first {
            // Update existing record.
            existing.transcription = transcription
            existing.summary = summary ?? existing.summary
            existing.segmentsJSON = segmentsData ?? existing.segmentsJSON
            existing.savedAt = Date()
        } else {
            // Insert new record.
            let record = TranscriptionRecord(
                audioURLString: key,
                transcription: transcription,
                summary: summary,
                segmentsJSON: segmentsData
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
