"""Synthesize the three alarm tone WAVs used by inemuri_guard.
Mirrors the Web Audio bursts from the original web artifact:
  chime: 880 -> 660 -> 880, sine
  siren: 500->1100->500 sawtooth sweep
  bell:  three short 1200Hz triangle taps
Run: python tools/gen_tones.py
"""
import math
import struct
import wave
import os

SR = 44100
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "sfx")
os.makedirs(OUT_DIR, exist_ok=True)


def env(t, dur, attack=0.02):
    if t < attack:
        return t / attack
    release_start = dur - attack
    if t > release_start:
        return max(0.0, (dur - t) / attack)
    return 1.0


def sine(freq, t):
    return math.sin(2 * math.pi * freq * t)


def sawtooth(freq, t):
    phase = (freq * t) % 1.0
    return 2.0 * phase - 1.0


def triangle_partial(freq, t):
    # cheap triangle-ish wave via sine harmonics for a softer "bell" tap
    return 0.7 * math.sin(2 * math.pi * freq * t) + 0.3 * math.sin(2 * math.pi * freq * 3 * t) / 3


def render(events, total_dur, gain=0.5):
    n = int(SR * total_dur)
    samples = [0.0] * n
    for (start, dur, wave_fn, freq_fn, amp) in events:
        s0 = int(start * SR)
        s1 = min(n, int((start + dur) * SR))
        for i in range(s0, s1):
            t = (i - s0) / SR
            f = freq_fn(t)
            v = wave_fn(f, t) * env(t, dur) * amp
            samples[i] += v
    peak = max(1e-6, max(abs(s) for s in samples))
    scale = min(1.0, gain / peak * 1.4)
    return [max(-1.0, min(1.0, s * scale)) for s in samples]


def write_wav(path, samples):
    with wave.open(path, "w") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(SR)
        frames = b"".join(struct.pack("<h", int(s * 32767)) for s in samples)
        f.writeframes(frames)


def const(freq):
    return lambda t: freq


def sweep(f1, f2, dur):
    return lambda t: f1 + (f2 - f1) * min(1.0, t / dur)


# chime: three sine beeps
chime_events = [
    (0.00, 0.18, sine, const(880), 1.0),
    (0.22, 0.18, sine, const(660), 1.0),
    (0.44, 0.18, sine, const(880), 1.0),
]
write_wav(os.path.join(OUT_DIR, "chime.wav"), render(chime_events, 0.7))

# siren: up then down sawtooth sweep
siren_events = [
    (0.00, 0.5, sawtooth, sweep(500, 1100, 0.5), 0.8),
    (0.50, 0.5, sawtooth, sweep(1100, 500, 0.5), 0.8),
]
write_wav(os.path.join(OUT_DIR, "siren.wav"), render(siren_events, 1.05))

# bell: three sharp taps
bell_events = [
    (0.00, 0.09, triangle_partial, const(1200), 1.0),
    (0.14, 0.09, triangle_partial, const(1200), 1.0),
    (0.28, 0.09, triangle_partial, const(1200), 1.0),
]
write_wav(os.path.join(OUT_DIR, "bell.wav"), render(bell_events, 0.42))

print("wrote chime.wav, siren.wav, bell.wav to", OUT_DIR)
