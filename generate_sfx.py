#!/usr/bin/env python3
"""
Freefall iOS Game — Grimey Hip-Hop SFX Generator
Generates 7 bass-heavy, hard-hitting WAV sound effects.
No external dependencies: uses only wave + struct + math + random.
All files: 44100 Hz, 16-bit signed mono.
"""

import wave
import struct
import math
import random
import os

SAMPLE_RATE = 44100
MAX_AMP = 32767
OUTPUT_DIR = "/Users/jamiethomson/freefall-app/src/Freefall/Freefall/audio/sfx"


def write_wav(filename, samples):
    """Write 16-bit mono WAV at 44100 Hz."""
    filepath = os.path.join(OUTPUT_DIR, filename)
    with wave.open(filepath, "w") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(SAMPLE_RATE)
        raw = b"".join(struct.pack("<h", s) for s in samples)
        wf.writeframes(raw)
    print(f"  Written: {filepath} ({len(samples)} samples, {len(samples)/SAMPLE_RATE:.3f}s)")


def normalize(samples, target=0.90):
    """Normalize to target fraction of max amplitude."""
    peak = max(abs(s) for s in samples) if samples else 1
    if peak == 0:
        return samples
    factor = (MAX_AMP * target) / peak
    return [int(max(-MAX_AMP, min(MAX_AMP, s * factor))) for s in samples]


def soft_clip(samples, drive=2.0):
    """Soft-clip distortion: tanh-style saturation."""
    out = []
    for s in samples:
        x = (s / MAX_AMP) * drive
        # tanh approximation via math.tanh
        out.append(math.tanh(x) * MAX_AMP)
    return [int(max(-MAX_AMP, min(MAX_AMP, v))) for v in out]


def hard_clip(samples, threshold=0.7):
    """Hard-clip distortion: flatten peaks beyond threshold."""
    limit = MAX_AMP * threshold
    return [int(max(-limit, min(limit, s))) for s in samples]


def add_harmonics(samples, amount=0.3):
    """Add gritty harmonic overtones by squaring the waveform (waveshaping)."""
    out = []
    for s in samples:
        x = s / MAX_AMP
        # Waveshape: mix original with squared (adds 2nd harmonic) and cubed (3rd harmonic)
        shaped = x + amount * (x * x * (1 if x >= 0 else -1)) + (amount * 0.5) * (x * x * x)
        out.append(shaped * MAX_AMP)
    return [int(max(-MAX_AMP, min(MAX_AMP, v))) for v in out]


def envelope_linear(n_samples, attack_frac=0.01, decay_start_frac=0.3):
    """Generate an amplitude envelope: fast attack, sustain, then decay to zero."""
    env = []
    attack_end = int(n_samples * attack_frac)
    decay_start = int(n_samples * decay_start_frac)
    for i in range(n_samples):
        if i < attack_end:
            # Attack
            env.append(i / max(attack_end, 1))
        elif i < decay_start:
            # Sustain
            env.append(1.0)
        else:
            # Decay (exponential-ish)
            remaining = (n_samples - i) / max(n_samples - decay_start, 1)
            env.append(remaining ** 1.5)
    return env


def envelope_exp_decay(n_samples, attack_samples=20, decay_rate=5.0):
    """Fast attack then exponential decay."""
    env = []
    for i in range(n_samples):
        if i < attack_samples:
            env.append(i / max(attack_samples, 1))
        else:
            t = (i - attack_samples) / SAMPLE_RATE
            env.append(math.exp(-decay_rate * t))
    return env


# ---------------------------------------------------------------------------
# 1. flip.wav — Deep bass thud/punch (0.06s)
# ---------------------------------------------------------------------------
def gen_flip():
    print("Generating flip.wav ...")
    duration = 0.06
    n = int(SAMPLE_RATE * duration)
    samples = []
    attack_samples = 8  # ~0.2ms — INSTANT attack
    for i in range(n):
        t = i / SAMPLE_RATE
        progress = i / n
        # Sine sweep 60 -> 40 Hz
        freq = 60 - 20 * progress
        phase = 2 * math.pi * (60 * t - 10 * t * t / duration)
        val = math.sin(phase)
        # Add 2nd harmonic for grit
        val += 0.35 * math.sin(2 * phase)
        # Add 3rd harmonic sub-rumble
        val += 0.15 * math.sin(3 * phase)
        # Envelope: instant attack, aggressive exponential decay
        if i < attack_samples:
            env = i / attack_samples
        else:
            env = math.exp(-40 * (t - attack_samples / SAMPLE_RATE))
        samples.append(val * env * MAX_AMP)
    samples = add_harmonics(samples, amount=0.4)
    samples = normalize(samples, 0.90)
    write_wav("flip.wav", samples)


# ---------------------------------------------------------------------------
# 2. death.wav — Heavy distorted bass drop + crunch (0.3s)
# ---------------------------------------------------------------------------
def gen_death():
    print("Generating death.wav ...")
    duration = 0.3
    n = int(SAMPLE_RATE * duration)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        progress = i / n
        # Pitch drop 100 -> 30 Hz (exponential curve for dramatic feel)
        freq = 100 * math.exp(-progress * math.log(100 / 30))
        # Accumulate phase properly
        phase = 2 * math.pi * (100 * t + (30 - 100) * t * progress / 2)
        val = math.sin(phase)
        # Heavy harmonics
        val += 0.5 * math.sin(2 * phase)
        val += 0.3 * math.sin(3 * phase)
        val += 0.2 * math.sin(5 * phase)
        # Noise crackle layer — increases over time
        noise = (random.random() * 2 - 1) * (0.1 + 0.5 * progress)
        val += noise
        # Envelope: fast attack, slow decay
        if i < 30:
            env = i / 30
        else:
            env = math.exp(-3.0 * t)
        samples.append(val * env * MAX_AMP)
    # Heavy distortion: hard clip then soft clip for speaker-blowout effect
    samples = hard_clip(samples, threshold=0.55)
    samples = soft_clip(samples, drive=3.0)
    samples = add_harmonics(samples, amount=0.5)
    samples = normalize(samples, 0.90)
    write_wav("death.wav", samples)


# ---------------------------------------------------------------------------
# 3. collectible.wav — Metallic ring + bass undertone (0.15s)
# ---------------------------------------------------------------------------
def gen_collectible():
    print("Generating collectible.wav ...")
    duration = 0.15
    n = int(SAMPLE_RATE * duration)
    samples = []
    bright_dur = int(0.05 * SAMPLE_RATE)
    for i in range(n):
        t = i / SAMPLE_RATE
        val = 0.0
        # Layer 1: bright metallic ring at 800Hz (first 0.05s with fast decay)
        if i < bright_dur:
            bright_env = math.exp(-30 * t)
            ring = math.sin(2 * math.pi * 800 * t)
            # Metallic: add inharmonic partials
            ring += 0.4 * math.sin(2 * math.pi * 1247 * t)  # non-integer ratio
            ring += 0.25 * math.sin(2 * math.pi * 1680 * t)
            ring += 0.15 * math.sin(2 * math.pi * 2100 * t)
            val += ring * bright_env * 0.6
        else:
            # Tail ring (quieter)
            bright_env = math.exp(-20 * t) * 0.2
            val += math.sin(2 * math.pi * 800 * t) * bright_env
        # Layer 2: deep bass at 200Hz (full duration)
        bass_env = math.exp(-8 * t)
        bass = math.sin(2 * math.pi * 200 * t)
        bass += 0.3 * math.sin(2 * math.pi * 400 * t)  # octave harmonic
        val += bass * bass_env * 0.7
        # Fast attack
        if i < 15:
            val *= i / 15
        samples.append(val * MAX_AMP)
    samples = add_harmonics(samples, amount=0.25)
    samples = normalize(samples, 0.90)
    write_wav("collectible.wav", samples)


# ---------------------------------------------------------------------------
# 4. level-start.wav — Rising bass swell (0.25s)
# ---------------------------------------------------------------------------
def gen_level_start():
    print("Generating level-start.wav ...")
    duration = 0.25
    n = int(SAMPLE_RATE * duration)
    samples = []
    # Accumulate phase for clean sweep
    phase = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        progress = i / n
        # Sweep 40 -> 120 Hz
        freq = 40 + 80 * progress
        phase += 2 * math.pi * freq / SAMPLE_RATE
        val = math.sin(phase)
        # Harmonics for grit
        val += 0.35 * math.sin(2 * phase)
        val += 0.2 * math.sin(3 * phase)
        # Increasing amplitude envelope (swell up, slight decay at end)
        if progress < 0.85:
            env = progress / 0.85
            # Accelerating ramp for more dramatic swell
            env = env ** 0.6
        else:
            tail = (progress - 0.85) / 0.15
            env = 1.0 - tail * 0.3  # slight decay
        # Sub-bass rumble layer
        val += 0.2 * math.sin(phase * 0.5) * env
        samples.append(val * env * MAX_AMP)
    samples = soft_clip(samples, drive=1.5)
    samples = add_harmonics(samples, amount=0.3)
    samples = normalize(samples, 0.90)
    write_wav("level-start.wav", samples)


# ---------------------------------------------------------------------------
# 5. level-complete.wav — EXPLOSIVE bass bomb (0.7s)
# ---------------------------------------------------------------------------
def gen_level_complete():
    print("Generating level-complete.wav ...")
    duration = 0.7
    n = int(SAMPLE_RATE * duration)
    samples_a = []  # deep boom
    samples_b = []  # metallic crash (noise)
    samples_c = []  # rising victory sweep

    # (a) Deep boom at 50Hz for 0.3s
    boom_n = int(0.3 * SAMPLE_RATE)
    for i in range(n):
        t = i / SAMPLE_RATE
        if i < boom_n:
            env = math.exp(-4.0 * t)
            if i < 20:
                env *= i / 20
            val = math.sin(2 * math.pi * 50 * t)
            val += 0.5 * math.sin(2 * math.pi * 100 * t)
            val += 0.3 * math.sin(2 * math.pi * 150 * t)
            val += 0.15 * math.sin(2 * math.pi * 25 * t)  # sub
            samples_a.append(val * env * MAX_AMP)
        else:
            # Fading rumble tail
            tail_t = (i - boom_n) / SAMPLE_RATE
            env = math.exp(-8.0 * tail_t) * 0.3
            val = math.sin(2 * math.pi * 50 * t) * env
            samples_a.append(val * MAX_AMP)

    # (b) Metallic crash — white noise burst with fast decay
    for i in range(n):
        t = i / SAMPLE_RATE
        # Noise burst with very fast decay
        if i < 15:
            env = i / 15
        else:
            env = math.exp(-12.0 * t)
        noise = random.random() * 2 - 1
        # "Filter" by mixing with low-frequency modulation
        mod = math.sin(2 * math.pi * 300 * t) * 0.3 + 0.7
        val = noise * env * mod
        # Add some metallic ring to the crash
        val += 0.2 * math.sin(2 * math.pi * 1500 * t) * env
        val += 0.15 * math.sin(2 * math.pi * 2300 * t) * env * 0.5
        samples_b.append(val * MAX_AMP)

    # (c) Rising victory sweep 100 -> 400 Hz
    phase_c = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        progress = i / n
        freq = 100 + 300 * (progress ** 1.5)  # accelerating sweep
        phase_c += 2 * math.pi * freq / SAMPLE_RATE
        val = math.sin(phase_c)
        val += 0.3 * math.sin(2 * phase_c)
        val += 0.15 * math.sin(3 * phase_c)
        # Envelope: fade in then sustain then fade
        if progress < 0.1:
            env = progress / 0.1
        elif progress < 0.8:
            env = 0.6 + 0.4 * ((progress - 0.1) / 0.7)
        else:
            env = 1.0 - ((progress - 0.8) / 0.2) * 0.6
        samples_c.append(val * env * MAX_AMP * 0.6)

    # Mix all three layers
    mixed = []
    for i in range(n):
        val = samples_a[i] * 1.0 + samples_b[i] * 0.6 + samples_c[i] * 0.7
        mixed.append(val)

    # Heavy processing for EXPLOSIVE feel
    mixed = hard_clip(mixed, threshold=0.65)
    mixed = soft_clip(mixed, drive=2.5)
    mixed = add_harmonics(mixed, amount=0.4)
    mixed = normalize(mixed, 0.95)  # Loudest of all SFX
    write_wav("level-complete.wav", mixed)


# ---------------------------------------------------------------------------
# 6. close-call.wav — Quick bass zap (0.08s)
# ---------------------------------------------------------------------------
def gen_close_call():
    print("Generating close-call.wav ...")
    duration = 0.08
    n = int(SAMPLE_RATE * duration)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        progress = i / n
        # 80Hz pulse
        val = math.sin(2 * math.pi * 80 * t)
        # Harmonics for buzz/electricity feel
        val += 0.4 * math.sin(2 * math.pi * 160 * t)
        val += 0.25 * math.sin(2 * math.pi * 240 * t)
        val += 0.15 * math.sin(2 * math.pi * 320 * t)
        # Tiny bit of noise for electrical crackle
        val += 0.1 * (random.random() * 2 - 1)
        # Sharp envelope: instant attack, hold, then sharp cutoff
        if i < 10:
            env = i / 10
        elif progress > 0.75:
            # Sharp cutoff — NOT gradual
            cutoff_progress = (progress - 0.75) / 0.25
            env = (1.0 - cutoff_progress) ** 3
        else:
            env = 1.0
        samples.append(val * env * MAX_AMP)
    samples = soft_clip(samples, drive=2.0)
    samples = add_harmonics(samples, amount=0.35)
    samples = normalize(samples, 0.90)
    write_wav("close-call.wav", samples)


# ---------------------------------------------------------------------------
# 7. all-collected.wav — Deep resonant cascade (0.35s)
# ---------------------------------------------------------------------------
def gen_all_collected():
    print("Generating all-collected.wav ...")
    duration = 0.35
    n = int(SAMPLE_RATE * duration)
    # Three tones: 200Hz, 150Hz, 100Hz — each ~0.1s, last one sustains
    tone_dur = int(0.1 * SAMPLE_RATE)
    freqs = [200, 150, 100]
    samples = []
    phase = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        # Determine which tone segment we're in
        if i < tone_dur:
            seg = 0
            seg_progress = i / tone_dur
        elif i < 2 * tone_dur:
            seg = 1
            seg_progress = (i - tone_dur) / tone_dur
        else:
            seg = 2
            seg_progress = (i - 2 * tone_dur) / (n - 2 * tone_dur)

        freq = freqs[seg]
        phase += 2 * math.pi * freq / SAMPLE_RATE
        val = math.sin(phase)
        # Rich harmonics
        val += 0.4 * math.sin(2 * phase)
        val += 0.2 * math.sin(3 * phase)
        val += 0.15 * math.sin(4 * phase)
        # Sub-bass
        val += 0.25 * math.sin(phase * 0.5)

        # Envelope per segment
        seg_start = seg * tone_dur
        seg_local = i - seg_start
        # Fast attack at start of each tone
        if seg_local < 15:
            env = seg_local / 15
        elif seg == 2:
            # Final tone sustains then fades
            if seg_progress > 0.6:
                env = 1.0 - ((seg_progress - 0.6) / 0.4) * 0.7
            else:
                env = 1.0
        else:
            # First two tones decay into next
            local_progress = seg_local / tone_dur
            if local_progress > 0.7:
                env = 1.0 - ((local_progress - 0.7) / 0.3) * 0.4
            else:
                env = 1.0

        # Overall increasing richness — each successive tone slightly louder
        env *= (0.8 + 0.1 * seg)
        samples.append(val * env * MAX_AMP)

    samples = soft_clip(samples, drive=1.8)
    samples = add_harmonics(samples, amount=0.3)
    samples = normalize(samples, 0.90)
    write_wav("all-collected.wav", samples)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
if __name__ == "__main__":
    print(f"Generating grimey SFX to: {OUTPUT_DIR}\n")
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    gen_flip()
    gen_death()
    gen_collectible()
    gen_level_start()
    gen_level_complete()
    gen_close_call()
    gen_all_collected()
    print("\nAll 7 SFX generated successfully.")
