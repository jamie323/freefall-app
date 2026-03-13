import AVFoundation
import Observation

@Observable
final class AudioManager {
    // All internal audio state excluded from observation —
    // @Observable tracking on these causes SwiftUI re-render churn
    // that interferes with AVAudioPlayer lifecycle.
    @ObservationIgnored private var currentMusicPlayer: AVAudioPlayer?
    @ObservationIgnored private var nextMusicPlayer: AVAudioPlayer?
    @ObservationIgnored private var activeSFXPlayers: [AVAudioPlayer] = []
    @ObservationIgnored private var currentVolume: Float = 1.0
    @ObservationIgnored private var currentMusicTrackName: String?
    @ObservationIgnored private var fadeTimer: Timer?
    @ObservationIgnored private var sfxCache: [String: URL] = [:]
    @ObservationIgnored private var scoreTickBuffer: Data?
    @ObservationIgnored private var flipThudBuffer: Data?

    @ObservationIgnored private let gameState: GameState

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
            print("[Audio] session error: \(error.localizedDescription)")
        }
    }

    /// Ensure audio session is still active — call before any playback
    private func ensureAudioSessionActive() {
        let session = AVAudioSession.sharedInstance()
        if !session.isOtherAudioPlaying || currentMusicPlayer == nil {
            do {
                try session.setActive(true, options: .notifyOthersOnDeactivation)
            } catch {
                // Non-critical
            }
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
            ensureAudioSessionActive()
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
                startFade(player: newPlayer, from: 0, to: currentVolume, duration: 1.5) { [weak self] in
                    self?.currentMusicPlayer = newPlayer
                }
                currentMusicPlayer = newPlayer
            }
        } catch {
            print("[Music] Failed to load: \(error.localizedDescription)")
        }
    }

    /// Single-timer fade — replaces the old 30× asyncAfter approach.
    /// Cancels any previous fade before starting a new one.
    private func startFade(player: AVAudioPlayer, from startVol: Float, to endVol: Float, duration: TimeInterval, completion: (() -> Void)? = nil) {
        cancelFade()
        let steps = max(1, Int(duration * 30))
        var step = 0
        player.volume = startVol
        fadeTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] timer in
            step += 1
            let progress = Float(step) / Float(steps)
            player.volume = startVol + (endVol - startVol) * min(1.0, progress)
            if step >= steps {
                timer.invalidate()
                self?.fadeTimer = nil
                completion?()
            }
        }
    }

    /// Cancel any in-progress fade immediately
    private func cancelFade() {
        fadeTimer?.invalidate()
        fadeTimer = nil
    }

    private func crossfadeMusic(from oldPlayer: AVAudioPlayer, to newPlayer: AVAudioPlayer, duration: TimeInterval) {
        cancelFade()
        let oldVolume = oldPlayer.volume
        newPlayer.volume = 0
        newPlayer.play()

        let steps = max(1, Int(duration * 30))
        var step = 0
        fadeTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] timer in
            step += 1
            let progress = Float(step) / Float(steps)
            oldPlayer.volume = oldVolume * max(0, 1.0 - progress)
            newPlayer.volume = min(1.0, progress)
            if step >= steps {
                timer.invalidate()
                self?.fadeTimer = nil
                oldPlayer.stop()
                self?.currentMusicPlayer = newPlayer
                self?.nextMusicPlayer = nil
            }
        }
    }

    func stopMusic() {
        cancelFade()
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
        let startVol = player.volume
        startFade(player: player, from: startVol, to: 0, duration: duration) { [weak self] in
            self?.stopMusic()
            completion?()
        }
    }

    // MARK: - SFX Playback (AVAudioPlayer-based, for synthesised sounds + fallback)

    /// Play a file-based SFX via AVAudioPlayer (used as fallback; prefer SKAction in GameScene)
    func playSFX(_ name: String) {
        guard gameState.sfxEnabled else { return }

        let url: URL
        if let cached = sfxCache[name] {
            url = cached
        } else {
            // Try wav first (most SFX), then mp3
            guard let found = Bundle.main.url(forResource: name, withExtension: "wav", subdirectory: "audio/sfx")
                    ?? Bundle.main.url(forResource: name, withExtension: "mp3", subdirectory: "audio/sfx") else {
                print("[SFX] File not found: '\(name)'")
                return
            }
            sfxCache[name] = found
            url = found
        }

        do {
            ensureAudioSessionActive()
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = 1.0  // Ensure max volume for SFX
            player.prepareToPlay()
            player.play()
            activeSFXPlayers.append(player)
            // Clean up finished players periodically (keep list small)
            if activeSFXPlayers.count > 8 {
                activeSFXPlayers.removeAll { !$0.isPlaying }
            }
        } catch {
            print("[SFX] Failed to play '\(name)': \(error)")
        }
    }

    /// Play a rapid score-tick sound — synthesised at runtime, no file needed
    func playScoreTick() {
        guard gameState.sfxEnabled else { return }

        // Reuse a single short tick buffer
        if scoreTickBuffer == nil {
            scoreTickBuffer = generateTickBuffer()
        }
        guard let buffer = scoreTickBuffer else { return }

        do {
            ensureAudioSessionActive()
            let player = try AVAudioPlayer(data: buffer)
            player.volume = 0.35
            player.prepareToPlay()
            player.play()
            activeSFXPlayers.append(player)
            if activeSFXPlayers.count > 12 {
                activeSFXPlayers.removeAll { !$0.isPlaying }
            }
        } catch {
            // Tick is non-critical — silent fail
        }
    }

    /// Generate a tiny click WAV in memory — 12ms sine burst at 1800 Hz
    private func generateTickBuffer() -> Data? {
        let sampleRate: Int = 44100
        let duration: Double = 0.012    // 12 ms
        let frequency: Double = 1800.0  // crisp click frequency
        let numSamples = Int(Double(sampleRate) * duration)
        let amplitude: Double = 0.6

        // Build raw 16-bit PCM samples
        var samples = [Int16]()
        samples.reserveCapacity(numSamples)
        for i in 0..<numSamples {
            let t = Double(i) / Double(sampleRate)
            let envelope = 1.0 - (t / duration)  // linear decay
            let value = sin(2.0 * .pi * frequency * t) * amplitude * envelope
            samples.append(Int16(max(-32767, min(32767, value * 32767))))
        }

        return buildWAV(samples: samples, sampleRate: sampleRate)
    }

    // MARK: - Flip Thud

    /// Play a low bass thud — synthesised at runtime for gravity flip feedback
    func playFlipThud() {
        guard gameState.sfxEnabled else { return }

        if flipThudBuffer == nil {
            flipThudBuffer = generateFlipThudBuffer()
        }
        guard let buffer = flipThudBuffer else { return }

        do {
            ensureAudioSessionActive()
            let player = try AVAudioPlayer(data: buffer)
            player.volume = 0.45
            player.prepareToPlay()
            player.play()
            activeSFXPlayers.append(player)
            if activeSFXPlayers.count > 12 {
                activeSFXPlayers.removeAll { !$0.isPlaying }
            }
        } catch {
            // Thud is non-critical — silent fail
        }
    }

    /// Generate a short bass thud WAV in memory — 50ms at 80 Hz with harmonics + exponential decay
    private func generateFlipThudBuffer() -> Data? {
        let sampleRate: Int = 44100
        let duration: Double = 0.050     // 50 ms — punchy
        let fundamental: Double = 80.0   // deep bass
        let numSamples = Int(Double(sampleRate) * duration)
        let amplitude: Double = 0.85

        var samples = [Int16]()
        samples.reserveCapacity(numSamples)
        for i in 0..<numSamples {
            let t = Double(i) / Double(sampleRate)
            let envelope = exp(-t * 35.0)  // sharp exponential decay
            // Fundamental + 2nd harmonic (body) + 3rd harmonic (click/attack)
            let wave = sin(2.0 * .pi * fundamental * t) * 0.55
                     + sin(2.0 * .pi * fundamental * 2.0 * t) * 0.30
                     + sin(2.0 * .pi * fundamental * 3.0 * t) * 0.15
            let value = wave * amplitude * envelope
            samples.append(Int16(max(-32767, min(32767, value * 32767))))
        }

        return buildWAV(samples: samples, sampleRate: sampleRate)
    }

    /// Shared WAV builder — 16-bit mono PCM
    private func buildWAV(samples: [Int16], sampleRate: Int) -> Data? {
        let dataSize = samples.count * 2
        let fileSize = 36 + dataSize
        var wav = Data()
        wav.reserveCapacity(44 + dataSize)
        wav.append(contentsOf: [0x52, 0x49, 0x46, 0x46])  // "RIFF"
        wav.append(contentsOf: withUnsafeBytes(of: UInt32(fileSize).littleEndian) { Array($0) })
        wav.append(contentsOf: [0x57, 0x41, 0x56, 0x45])  // "WAVE"
        wav.append(contentsOf: [0x66, 0x6D, 0x74, 0x20])  // "fmt "
        wav.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Array($0) })    // chunk size
        wav.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) })     // PCM
        wav.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) })     // mono
        wav.append(contentsOf: withUnsafeBytes(of: UInt32(sampleRate).littleEndian) { Array($0) })
        wav.append(contentsOf: withUnsafeBytes(of: UInt32(sampleRate * 2).littleEndian) { Array($0) })  // byte rate
        wav.append(contentsOf: withUnsafeBytes(of: UInt16(2).littleEndian) { Array($0) })     // block align
        wav.append(contentsOf: withUnsafeBytes(of: UInt16(16).littleEndian) { Array($0) })    // bits per sample
        wav.append(contentsOf: [0x64, 0x61, 0x74, 0x61])  // "data"
        wav.append(contentsOf: withUnsafeBytes(of: UInt32(dataSize).littleEndian) { Array($0) })
        for sample in samples {
            wav.append(contentsOf: withUnsafeBytes(of: sample.littleEndian) { Array($0) })
        }
        return wav
    }

    // MARK: - Volume Control

    func setMusicVolume(_ volume: Float) {
        currentVolume = volume
        currentMusicPlayer?.volume = volume
        nextMusicPlayer?.volume = volume
    }
}
