import Foundation

/// Manages a local cache of downloaded episode audio files.
/// Ensures the same audio file is used for both playback and transcription.
final class AudioCache: Sendable {
    static let shared = AudioCache()

    /// Directory where cached audio files are stored.
    private let cacheDir: URL = {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PodcutAudio", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    /// Configured session with reasonable timeouts.
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300 // 5 min max for large episodes
        return URLSession(configuration: config)
    }()

    /// Returns the local file URL for a cached episode, downloading if needed.
    /// - Parameter remoteURL: The episode's remote audio URL.
    /// - Returns: A local file URL pointing to the downloaded audio.
    func localURL(for remoteURL: URL) async throws -> URL {
        let filename = remoteURL.absoluteString
            .addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? UUID().uuidString
        let localURL = cacheDir.appendingPathComponent(filename)

        // Already cached — return immediately.
        if FileManager.default.fileExists(atPath: localURL.path) {
            return localURL
        }

        // Download to a temp file, then move to cache.
        let (tempURL, response) = try await session.download(from: remoteURL)

        // Validate HTTP response.
        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            try? FileManager.default.removeItem(at: tempURL)
            throw AudioCacheError.downloadFailed(statusCode: httpResponse.statusCode)
        }

        // Move to cache (overwrite if somehow exists now).
        if FileManager.default.fileExists(atPath: localURL.path) {
            try? FileManager.default.removeItem(at: localURL)
        }
        try FileManager.default.moveItem(at: tempURL, to: localURL)

        return localURL
    }

    /// Remove a cached file for a specific URL.
    func removeCached(for remoteURL: URL) {
        let filename = remoteURL.absoluteString
            .addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
        let localURL = cacheDir.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: localURL)
    }

    /// Clear the entire audio cache.
    func clearAll() {
        try? FileManager.default.removeItem(at: cacheDir)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }
}

enum AudioCacheError: LocalizedError {
    case downloadFailed(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .downloadFailed(let code):
            return "Download failed (HTTP \(code)). Check your connection and try again."
        }
    }
}
