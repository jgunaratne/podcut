import AVFoundation
import Foundation
import Speech
import UIKit

/// A single timestamped segment of a transcription.
struct TranscriptionSegment: Codable, Identifiable, Hashable {
    var id: Double { timestamp }
    let timestamp: TimeInterval  // seconds from start
    let text: String

    /// Format the timestamp as MM:SS.
    var formattedTime: String {
        let minutes = Int(timestamp) / 60
        let seconds = Int(timestamp) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

/// Transcribes a podcast episode's audio using the iOS 26 SpeechTranscriber.
@MainActor @Observable
final class TranscriptionService {
    var transcriptionText: String = ""
    var segments: [TranscriptionSegment] = []
    var isTranscribing: Bool = false
    var progress: String = "Preparing…"
    var fractionComplete: Double = 0
    var errorMessage: String?

    /// Transcribe audio from a local file.
    /// The caller is responsible for downloading via AudioCache first.
    func transcribe(localFileURL: URL) async {
        isTranscribing = true
        transcriptionText = ""
        segments = []
        errorMessage = nil
        fractionComplete = 0
        progress = "Preparing…"

        // Keep the app alive in the background during transcription.
        // Use both UIBackgroundTask (short) and ProcessInfo extended execution (long).
        var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "Transcription") {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }

        // Request extended background execution for long transcriptions.
        let processInfo = ProcessInfo.processInfo
        processInfo.performExpiringActivity(withReason: "Podcast transcription in progress") { expired in
            if expired {
                // System is reclaiming — nothing we can do, the task will resume next launch.
            }
        }

        defer {
            if backgroundTaskID != .invalid {
                UIApplication.shared.endBackgroundTask(backgroundTaskID)
            }
        }

        do {
            progress = "Setting up transcriber…"

            // 2. Check availability and resolve locale.
            guard SpeechTranscriber.isAvailable else {
                errorMessage = "Speech transcription is not available on this device."
                isTranscribing = false
                return
            }
            let locale = await resolveLocale()
            guard let locale else {
                errorMessage = "No supported speech language found."
                isTranscribing = false
                return
            }

            let transcriber = SpeechTranscriber(locale: locale, preset: .transcription)

            // 3. Install speech model assets if needed.
            progress = "Checking speech model…"
            if let req = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
                progress = "Downloading speech model (first time only)…"
                try await req.downloadAndInstall()
            }

            // 4. Open the audio file and compute total duration.
            let audioFile = try AVAudioFile(forReading: localFileURL)
            let totalDuration = Double(audioFile.length) / audioFile.fileFormat.sampleRate

            progress = "Transcribing…"

            // 5. Create analyzer.
            //    The handler tracks two things:
            //    - fractionComplete (from range.end) → progress bar
            //    - stableTime (from range.start) → segment timestamps
            //      range.start = end of finalized audio, so it closely matches
            //      where each final result corresponds in the audio.
            var stableTime: Double = 0
            let analyzer = try await SpeechAnalyzer(
                inputAudioFile: audioFile,
                modules: [transcriber],
                finishAfterFile: true,
                volatileRangeChangedHandler: { [weak self] range, _, _ in
                    guard let self, totalDuration > 0 else { return }
                    let pct = CMTimeGetSeconds(range.end) / totalDuration
                    let stable = CMTimeGetSeconds(range.start)
                    Task { @MainActor in
                        self.fractionComplete = min(pct, 1.0)
                        self.progress = "Transcribing… \(Int(self.fractionComplete * 100))%"
                        stableTime = stable
                    }
                }
            )

            // 6. Collect results, deduplicating refined segments.
            //    The transcriber may emit updated results for the same audio region.
            //    If a new result overlaps the previous segment's timestamp (within 2s)
            //    and the previous text is a prefix of the new text, replace it.
            for try await result in transcriber.results {
                let text = String(result.text.characters)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { continue }

                let currentTimestamp = stableTime

                // Check if this is a refinement of the last segment.
                if let last = segments.last {
                    let timeDelta = abs(currentTimestamp - last.timestamp)
                    let isRefinement = timeDelta < 2.0 && (
                        text.hasPrefix(last.text) ||
                        last.text.hasPrefix(text) ||
                        text == last.text
                    )

                    if isRefinement {
                        // Replace the last segment with the longer/refined version.
                        let refined = text.count >= last.text.count ? text : last.text
                        segments[segments.count - 1] = TranscriptionSegment(
                            timestamp: last.timestamp,
                            text: refined
                        )
                        continue
                    }
                }

                let segment = TranscriptionSegment(
                    timestamp: currentTimestamp,
                    text: text
                )
                segments.append(segment)
            }

            // 7. Finalize the analyzer.
            try await analyzer.finalizeAndFinishThroughEndOfInput()

            // Rebuild clean transcript from segments.
            transcriptionText = segments.map(\.text).joined(separator: " ")

            fractionComplete = 1.0
            progress = "Done"
            isTranscribing = false

        } catch {
            errorMessage = error.localizedDescription
            isTranscribing = false
        }
    }

    // MARK: - Locale Resolution

    private func resolveLocale() async -> Locale? {
        if let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale.current) {
            return locale
        }
        if let enUS = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: "en-US")) {
            return enUS
        }
        let installed = await SpeechTranscriber.installedLocales
        return installed.first
    }
}
