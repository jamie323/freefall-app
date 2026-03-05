import AVFoundation
import Observation

@Observable
final class AudioManager {
    private var currentMusicPlayer: AVAudioPlayer?
    private var nextMusicPlayer: AVAudioPlayer?
    private var activeSFXPlayers: [AVAudioPlayer] = []
    private var currentVolume: Float = 1.0
    private var targetVolume: Float = 1.0

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
        let worldFolder: String
        switch world {
        case 1: worldFolder = "world1-the-block"
        case 2: worldFolder = "world2-neon-yard"
        case 3: worldFolder = "world3-underground"
        case 4: worldFolder = "world4-static"
        default: worldFolder = "world1-the-block"
        }
        return ("world\(world)-\(suffix)", worldFolder)
    }

    private func loadAndPlayMusic(named: String, inSubdirectory subdirectory: String) {
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
    }

    // MARK: - SFX Playback

    func playSFX(_ name: String) {
        guard gameState.sfxEnabled else { return }

        // Try mp3 first, then wav
        let url: URL? = Bundle.main.url(forResource: name, withExtension: "mp3", subdirectory: "audio/sfx")
            ?? Bundle.main.url(forResource: name, withExtension: "wav", subdirectory: "audio/sfx")
        guard let url else {
            return
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.play()
            activeSFXPlayers.append(player)
            // Clean up finished players
            activeSFXPlayers.removeAll { !$0.isPlaying }
        } catch {
            print("Failed to play SFX: \(error.localizedDescription)")
        }
    }

    // MARK: - Volume Control

    func setMusicVolume(_ volume: Float) {
        currentVolume = volume
        currentMusicPlayer?.volume = volume
        nextMusicPlayer?.volume = volume
    }
}
