import AVFoundation
import Foundation
import Speech

/// Transcribes a podcast episode's audio using the iOS 26 SpeechTranscriber.
@Observable
final class TranscriptionService {
    var transcriptionText: String = ""
    var isTranscribing: Bool = false
    var progress: String = "Preparing…"
    var fractionComplete: Double = 0
    var errorMessage: String?

    /// Transcribe the audio at the given URL.
    /// Downloads the audio to a temp file, then runs SpeechAnalyzer with SpeechTranscriber.
    func transcribe(audioURL: URL) async {
        isTranscribing = true
        transcriptionText = ""
        errorMessage = nil
        fractionComplete = 0
        progress = "Downloading audio…"

        do {
            // 1. Download the audio to a temporary file.
            let (localURL, _) = try await URLSession.shared.download(from: audioURL)
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("mp3")
            try FileManager.default.moveItem(at: localURL, to: tempURL)
            defer { try? FileManager.default.removeItem(at: tempURL) }

            progress = "Setting up transcriber…"

            // 2. Check availability and resolve locale.
            guard SpeechTranscriber.isAvailable else {
                errorMessage = "Speech transcription is not available on this device."
                isTranscribing = false
                return
            }

            let locale = await resolveLocale()
            guard let locale else {
                errorMessage = "No supported speech language is available. Install a language in Settings → General → Keyboard → Dictation Languages."
                isTranscribing = false
                return
            }

            let transcriber = SpeechTranscriber(locale: locale, preset: .transcription)

            // 3. Install assets if needed.
            if let installationRequest = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
                progress = "Downloading speech model…"
                try await installationRequest.downloadAndInstall()
            }

            // 4. Open the audio file and compute duration.
            let audioFile = try AVAudioFile(forReading: tempURL)
            let totalDuration = Double(audioFile.length) / audioFile.fileFormat.sampleRate

            progress = "Transcribing…"

            // 5. Create analyzer with progress tracking.
            let analyzer = try await SpeechAnalyzer(
                inputAudioFile: audioFile,
                modules: [transcriber],
                finishAfterFile: true,
                volatileRangeChangedHandler: { [weak self] range, _, _ in
                    guard let self, totalDuration > 0 else { return }
                    let processedSeconds = CMTimeGetSeconds(range.end)
                    Task { @MainActor in
                        self.fractionComplete = min(processedSeconds / totalDuration, 1.0)
                    }
                }
            )

            // 6. Collect results as they stream in.
            for try await result in transcriber.results {
                let text = String(result.text.characters)
                transcriptionText += text + " "
                let pct = Int(fractionComplete * 100)
                progress = "Transcribing… \(pct)%"
            }

            // 7. Finalize.
            try await analyzer.finalizeAndFinishThroughEndOfInput()

            fractionComplete = 1.0
            progress = "Done"
            isTranscribing = false

        } catch {
            errorMessage = error.localizedDescription
            isTranscribing = false
        }
    }

    /// Try the device locale, then en-US, then any installed locale.
    private func resolveLocale() async -> Locale? {
        // Try current device locale.
        if let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale.current) {
            return locale
        }
        // Fall back to English (US).
        if let enUS = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: "en-US")) {
            return enUS
        }
        // Fall back to any installed locale.
        let installed = SpeechTranscriber.installedLocales
        return installed.first
    }
}
