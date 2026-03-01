import AVFoundation
import Observation

@Observable
final class AudioManager {
    private var currentMusicPlayer: AVAudioPlayer?
    private var nextMusicPlayer: AVAudioPlayer?
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
            try audioSession.setCategory(.ambient, mode: .default, options: [.duckOthers])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Audio session error: \(error.localizedDescription)")
        }
    }

    // MARK: - Music Playback

    func playMusic(world: Int, level: Int) {
        guard gameState.musicEnabled else { return }

        let track = musicTrack(for: world, level: level)
        loadAndPlayMusic(named: track, inSubdirectory: "audio/music")
    }

    func playMenuMusic() {
        guard gameState.musicEnabled else { return }
        loadAndPlayMusic(named: "menu-track", inSubdirectory: "audio/music/menu")
    }

    func playIntermissionMusic() {
        guard gameState.musicEnabled else { return }
        loadAndPlayMusic(named: "intermission-track", inSubdirectory: "audio/music/intermission")
    }

    private func musicTrack(for world: Int, level: Int) -> String {
        let suffix = level <= 5 ? "track-a" : "track-b"
        let worldFolder: String
        switch world {
        case 1: worldFolder = "world1-the-block"
        case 2: worldFolder = "world2-neon-yard"
        case 3: worldFolder = "world3-underground"
        case 4: worldFolder = "world4-static"
        default: worldFolder = "world1-the-block"
        }
        return "world\(world)-\(suffix)"
    }

    private func loadAndPlayMusic(named: String, inSubdirectory subdirectory: String) {
        guard let url = Bundle.main.url(
            forResource: named,
            withExtension: "mp3",
            subdirectory: subdirectory
        ) else {
            print("Music file not found: \(named) in \(subdirectory)")
            return
        }

        do {
            let newPlayer = try AVAudioPlayer(contentsOf: url)
            newPlayer.numberOfLoops = -1
            newPlayer.volume = currentVolume

            if let currentPlayer = currentMusicPlayer {
                crossfadeMusic(from: currentPlayer, to: newPlayer, duration: 2.0)
                nextMusicPlayer = newPlayer
            } else {
                newPlayer.play()
                currentMusicPlayer = newPlayer
            }
        } catch {
            print("Failed to load music: \(error.localizedDescription)")
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

        guard let url = Bundle.main.url(forResource: name, withExtension: "mp3", subdirectory: "audio/sfx") else {
            print("SFX file not found: \(name)")
            return
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.play()
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
