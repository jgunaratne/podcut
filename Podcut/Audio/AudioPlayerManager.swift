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
    var errorMessage: String?
    var isLoading = false

    var playbackProgress: Double {
        guard duration > 0 else { return 0 }
        return currentTime / duration
    }

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var loadTask: Task<Void, Never>?
    private var statusObservation: NSKeyValueObservation?

    init() {
        configureAudioSession()
        setupRemoteCommandCenter()
    }

    deinit {
        removeTimeObserver()
        statusObservation?.invalidate()
    }

    // MARK: - Playback Controls

    func play(episode: Episode) {
        guard let url = episode.audioURL else {
            errorMessage = "This episode has no audio URL."
            return
        }

        // If same episode, just resume.
        if currentEpisode?.id == episode.id, player != nil {
            resume()
            return
        }

        // Cancel any in-flight load.
        loadTask?.cancel()
        removeTimeObserver()
        statusObservation?.invalidate()
        statusObservation = nil
        player?.pause()
        player = nil
        currentEpisode = episode
        isPlaying = false
        errorMessage = nil
        isLoading = true

        loadTask = Task { @MainActor in
            do {
                let localURL = try await AudioCache.shared.localURL(for: url)
                if Task.isCancelled { return }

                let playerItem = AVPlayerItem(url: localURL)
                let avPlayer = AVPlayer(playerItem: playerItem)
                self.player = avPlayer

                // Wait for readyToPlay via KVO.
                let status = await withCheckedContinuation { (continuation: CheckedContinuation<AVPlayerItem.Status, Never>) in
                    // Check if already resolved before observing.
                    if playerItem.status != .unknown {
                        continuation.resume(returning: playerItem.status)
                        return
                    }

                    var resumed = false
                    self.statusObservation = playerItem.observe(\.status, options: [.new]) { item, _ in
                        guard !resumed else { return }
                        if item.status != .unknown {
                            resumed = true
                            continuation.resume(returning: item.status)
                        }
                    }
                }

                self.statusObservation?.invalidate()
                self.statusObservation = nil
                self.isLoading = false

                guard !Task.isCancelled else { return }

                guard status == .readyToPlay else {
                    let desc = playerItem.error?.localizedDescription ?? "Unknown playback error"
                    self.errorMessage = "Can't play: \(desc)"
                    self.currentEpisode = nil
                    return
                }

                // Apply default playback rate from settings.
                let savedRate = UserDefaults.standard.float(forKey: "defaultPlaybackRate")
                let rate = savedRate > 0 ? savedRate : 1.0
                avPlayer.rate = rate

                self.isPlaying = true

                self.addTimeObserver()
                self.observeDuration(of: playerItem)
                self.updateNowPlayingInfo()
            } catch is CancellationError {
                self.isLoading = false
            } catch {
                if !Task.isCancelled {
                    self.errorMessage = error.localizedDescription
                    self.currentEpisode = nil
                    self.isPlaying = false
                    self.isLoading = false
                }
            }
        }
    }

    func pause() {
        guard player != nil else { return }
        player?.pause()
        isPlaying = false
        updateNowPlayingInfo()
    }

    func resume() {
        guard let player else {
            // No player exists — try replaying the current episode.
            if let episode = currentEpisode {
                let ep = episode
                currentEpisode = nil
                play(episode: ep)
            }
            return
        }
        player.play()
        isPlaying = true
        errorMessage = nil
        updateNowPlayingInfo()
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else if player != nil {
            resume()
        } else if let episode = currentEpisode {
            let ep = episode
            currentEpisode = nil
            play(episode: ep)
        }
    }

    func seek(to progress: Double) {
        guard duration > 0 else { return }
        let target = CMTime(
            seconds: progress * duration, preferredTimescale: 600)
        player?.seek(to: target)
        updateNowPlayingInfo()
    }

    func setRate(_ rate: Float) {
        player?.rate = rate
        if isPlaying {
            player?.play()
            player?.rate = rate
        }
        updateNowPlayingInfo()
    }

    func skipForward(_ seconds: TimeInterval = 30) {
        guard let player = player else { return }
        let target = CMTimeAdd(
            player.currentTime(),
            CMTime(seconds: seconds, preferredTimescale: 600))
        player.seek(to: target)
        updateNowPlayingInfo()
    }

    func skipBackward(_ seconds: TimeInterval = 15) {
        guard let player = player else { return }
        let target = CMTimeSubtract(
            player.currentTime(),
            CMTime(seconds: seconds, preferredTimescale: 600))
        player.seek(to: target)
        updateNowPlayingInfo()
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
            do {
                let seconds = try await item.asset.load(.duration).seconds
                self.duration = seconds
                self.updateNowPlayingInfo()
            } catch {
                print("Failed to load duration: \(error)")
                self.duration = 0
            }
        }
    }

    // MARK: - Now Playing & Lock Screen Controls

    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.resume()
            return .success
        }

        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }

        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }

        commandCenter.skipForwardCommand.preferredIntervals = [30]
        commandCenter.skipForwardCommand.addTarget { [weak self] _ in
            self?.skipForward()
            return .success
        }

        commandCenter.skipBackwardCommand.preferredIntervals = [15]
        commandCenter.skipBackwardCommand.addTarget { [weak self] _ in
            self?.skipBackward()
            return .success
        }

        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self,
                  let positionEvent = event as? MPChangePlaybackPositionCommandEvent
            else { return .commandFailed }
            let progress = positionEvent.positionTime / max(self.duration, 1)
            self.seek(to: progress)
            return .success
        }
    }

    private func updateNowPlayingInfo() {
        var info = [String: Any]()
        info[MPMediaItemPropertyTitle] = currentEpisode?.title ?? "Podcut"
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPMediaItemPropertyPlaybackDuration] = duration
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
