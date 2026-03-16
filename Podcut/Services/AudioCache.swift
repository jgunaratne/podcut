import Foundation

/// Manages a local cache of downloaded episode audio files.
/// Ensures the same MP3 is used for both playback and transcription.
@MainActor
final class AudioCache {
    static let shared = AudioCache()

    /// Directory where cached audio files are stored.
    private let cacheDir: URL = {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PodcutAudio", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    /// Returns the local file URL for a cached episode, downloading if needed.
    /// - Parameter remoteURL: The episode's remote audio URL.
    /// - Returns: A local file URL pointing to the downloaded MP3.
    func localURL(for remoteURL: URL, progress: ((String) -> Void)? = nil) async throws -> URL {
        let filename = remoteURL.absoluteString
            .addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? UUID().uuidString
        let localURL = cacheDir.appendingPathComponent(filename).appendingPathExtension("mp3")

        // Already cached — return immediately.
        if FileManager.default.fileExists(atPath: localURL.path) {
            return localURL
        }

        // Download to a temp file, then move to cache.
        progress?("Downloading audio…")
        let (tempURL, _) = try await URLSession.shared.download(from: remoteURL)
        try FileManager.default.moveItem(at: tempURL, to: localURL)

        return localURL
    }

    /// Remove a cached file for a specific URL.
    func removeCached(for remoteURL: URL) {
        let filename = remoteURL.absoluteString
            .addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
        let localURL = cacheDir.appendingPathComponent(filename).appendingPathExtension("mp3")
        try? FileManager.default.removeItem(at: localURL)
    }

    /// Clear the entire audio cache.
    func clearAll() {
        try? FileManager.default.removeItem(at: cacheDir)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }
}
