import AVFoundation
import Observation

@Observable
final class AudioManager {
    private var currentMusicPlayer: AVAudioPlayer?
    private var nextMusicPlayer: AVAudioPlayer?
    private var activeSFXPlayers: [AVAudioPlayer] = []
    private var currentVolume: Float = 1.0
    private var targetVolume: Float = 1.0
    private var currentMusicTrackName: String?

    private let gameState: GameState

    init(gameState: GameState) {
        self.gameState = gameState
        configureAudioSession()
    }

    private func configureAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Audio session error: \(error.localizedDescription)")
        }
    }

    // MARK: - Music Playback

    func playMusic(world: Int, level: Int) {
        guard gameState.musicEnabled else { return }

        let (track, folder) = musicTrack(for: world, level: level)
        loadAndPlayMusic(named: track, inSubdirectory: "audio/music/\(folder)")
    }

    func playMenuMusic() {
        guard gameState.musicEnabled else { return }
        loadAndPlayMusic(named: "menu-track", inSubdirectory: "audio/music/menu")
    }

    func playIntermissionMusic() {
        guard gameState.musicEnabled else { return }
        loadAndPlayMusic(named: "intermission-track", inSubdirectory: "audio/music/intermission")
    }

    private func musicTrack(for world: Int, level: Int) -> (name: String, folder: String) {
        let suffix = level <= 5 ? "track-a" : "track-b"
        let worldFolder = WorldLibrary.world(for: world)?.musicFolderName ?? "world1-the-block"
        return ("world\(world)-\(suffix)", worldFolder)
    }

    private func loadAndPlayMusic(named: String, inSubdirectory subdirectory: String) {
        // Don't restart if already playing this track
        if currentMusicTrackName == named, currentMusicPlayer?.isPlaying == true {
            return
        }

        guard let url = Bundle.main.url(
            forResource: named,
            withExtension: "mp3",
            subdirectory: subdirectory
        ) else {
            return
        }

        do {
            let newPlayer = try AVAudioPlayer(contentsOf: url)
            newPlayer.numberOfLoops = -1

            currentMusicTrackName = named

            if let currentPlayer = currentMusicPlayer {
                crossfadeMusic(from: currentPlayer, to: newPlayer, duration: 2.0)
                nextMusicPlayer = newPlayer
            } else {
                // First track — fade in from silence
                newPlayer.volume = 0
                newPlayer.play()
                fadeInMusic(player: newPlayer, targetVolume: currentVolume, duration: 1.5)
                currentMusicPlayer = newPlayer
            }
        } catch {
            print("Failed to load music: \(error.localizedDescription)")
        }
    }

    private func fadeInMusic(player: AVAudioPlayer, targetVolume: Float, duration: TimeInterval) {
        let fadeSteps = Int(duration * 30)
        let volumeStep = targetVolume / Float(fadeSteps)
        for i in 0..<fadeSteps {
            DispatchQueue.main.asyncAfter(deadline: .now() + (Double(i) / 30.0)) {
                player.volume = min(targetVolume, Float(i + 1) * volumeStep)
            }
        }
    }

    private func crossfadeMusic(from oldPlayer: AVAudioPlayer, to newPlayer: AVAudioPlayer, duration: TimeInterval) {
        newPlayer.play()

        let fadeSteps = Int(duration * 30)
        let volumeStep = oldPlayer.volume / Float(fadeSteps)
        let newVolumeStep = (1.0 - newPlayer.volume) / Float(fadeSteps)

        for i in 0..<fadeSteps {
            DispatchQueue.main.asyncAfter(deadline: .now() + (Double(i) / 30.0)) {
                oldPlayer.volume = max(0, oldPlayer.volume - volumeStep)
                newPlayer.volume = min(1.0, newPlayer.volume + newVolumeStep)

                if i == fadeSteps - 1 {
                    oldPlayer.stop()
                    self.currentMusicPlayer = newPlayer
                    self.nextMusicPlayer = nil
                }
            }
        }
    }

    func stopMusic() {
        currentMusicPlayer?.stop()
        nextMusicPlayer?.stop()
        currentMusicPlayer = nil
        nextMusicPlayer = nil
        currentMusicTrackName = nil
    }

    /// Fade out current music over the given duration, then stop
    func fadeOutMusic(duration: TimeInterval = 1.0, completion: (() -> Void)? = nil) {
        guard let player = currentMusicPlayer else {
            completion?()
            return
        }
        let fadeSteps = Int(duration * 30)
        let volumeStep = player.volume / Float(max(1, fadeSteps))
        for i in 0..<fadeSteps {
            DispatchQueue.main.asyncAfter(deadline: .now() + (Double(i) / 30.0)) { [weak self] in
                player.volume = max(0, player.volume - volumeStep)
                if i == fadeSteps - 1 {
                    self?.stopMusic()
                    completion?()
                }
            }
        }
    }

    // MARK: - SFX Playback

    func playSFX(_ name: String) {
        guard gameState.sfxEnabled else {
            print("[SFX] Skipped '\(name)' — SFX disabled")
            return
        }

        // Try mp3 first, then wav
        let url: URL? = Bundle.main.url(forResource: name, withExtension: "mp3", subdirectory: "audio/sfx")
            ?? Bundle.main.url(forResource: name, withExtension: "wav", subdirectory: "audio/sfx")
        guard let url else {
            print("[SFX] File not found in bundle: '\(name)' (tried .mp3 and .wav in audio/sfx)")
            return
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.play()
            activeSFXPlayers.append(player)
            // Clean up finished players
            activeSFXPlayers.removeAll { !$0.isPlaying }
        } catch {
            print("[SFX] Failed to play '\(name)': \(error.localizedDescription)")
        }
    }

    // MARK: - Volume Control

    func setMusicVolume(_ volume: Float) {
        currentVolume = volume
        currentMusicPlayer?.volume = volume
        nextMusicPlayer?.volume = volume
    }
}
