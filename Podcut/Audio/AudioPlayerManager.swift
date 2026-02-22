import AVFoundation
import Foundation
import MediaPlayer

/// Manages audio playback of podcast episodes.
@Observable
final class AudioPlayerManager {
    var currentEpisode: Episode?
    var isPlaying = false
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0

    var playbackProgress: Double {
        guard duration > 0 else { return 0 }
        return currentTime / duration
    }

    private var player: AVPlayer?
    private var timeObserver: Any?

    init() {
        configureAudioSession()
    }

    deinit {
        removeTimeObserver()
    }

    // MARK: - Playback Controls

    func play(episode: Episode) {
        guard let url = episode.audioURL else { return }

        // If same episode, just resume.
        if currentEpisode?.id == episode.id, player != nil {
            resume()
            return
        }

        removeTimeObserver()

        currentEpisode = episode
        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        player?.play()
        isPlaying = true

        addTimeObserver()
        observeDuration(of: playerItem)
    }

    func pause() {
        player?.pause()
        isPlaying = false
    }

    func resume() {
        player?.play()
        isPlaying = true
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            resume()
        }
    }

    func seek(to progress: Double) {
        guard duration > 0 else { return }
        let target = CMTime(
            seconds: progress * duration, preferredTimescale: 600)
        player?.seek(to: target)
    }

    func skipForward(_ seconds: TimeInterval = 30) {
        guard let player = player else { return }
        let target = CMTimeAdd(
            player.currentTime(),
            CMTime(seconds: seconds, preferredTimescale: 600))
        player.seek(to: target)
    }

    func skipBackward(_ seconds: TimeInterval = 15) {
        guard let player = player else { return }
        let target = CMTimeSubtract(
            player.currentTime(),
            CMTime(seconds: seconds, preferredTimescale: 600))
        player.seek(to: target)
    }

    // MARK: - Formatting

    func formattedTime(_ time: TimeInterval) -> String {
        guard !time.isNaN, !time.isInfinite else { return "--:--" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Private

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session error: \(error)")
        }
    }

    private func addTimeObserver() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player?.addPeriodicTimeObserver(
            forInterval: interval, queue: .main
        ) { [weak self] time in
            self?.currentTime = time.seconds
        }
    }

    private func removeTimeObserver() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
    }

    private func observeDuration(of item: AVPlayerItem) {
        Task { @MainActor in
            // Poll until the item is ready to play.
            while item.status != .readyToPlay {
                try? await Task.sleep(for: .milliseconds(200))
            }
            let seconds = try? await item.asset.load(.duration).seconds
            self.duration = seconds ?? 0
        }
    }
}
