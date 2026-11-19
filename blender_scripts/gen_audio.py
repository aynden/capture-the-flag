#!/usr/bin/env python3
"""Procedural SFX synthesizer for Capture the Flag (Paintball Arena)."""
import os
import math
import wave
import struct
import random

OUT_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "audio")
os.makedirs(OUT_DIR, exist_ok=True)
SR = 44100


def save_wav(filename, samples):
    path = os.path.join(OUT_DIR, filename)
    peak = max((abs(s) for s in samples), default=1.0)
    scale = 0.88 / max(peak, 1e-6)
    with wave.open(path, "w") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(SR)
        frames = bytearray()
        for s in samples:
            v = max(-1.0, min(1.0, s * scale))
            frames.extend(struct.pack("<h", int(v * 32767)))
        wf.writeframes(bytes(frames))


def gen_shoot():
    """Crisp pneumatic paintball marker THWIP-POP."""
    dur = 0.14
    n = int(SR * dur)
    rng = random.Random(42)
    out = []
    lp = 0.0
    for i in range(n):
        t = i / SR
        # Pitch-dropping pneumatic thump (420Hz -> 95Hz)
        f = 95.0 + 340.0 * math.exp(-t * 48.0)
        pop = math.sin(2 * math.pi * f * t) * math.exp(-t * 32.0) * 0.9
        # Compressed CO2 crisp air hiss
        noise = rng.uniform(-1.0, 1.0)
        lp = lp * 0.72 + noise * 0.28
        hp = noise - lp
        air = hp * math.exp(-t * 28.0) * 0.65
        # Mechanical bolt click at t=0
        click = math.sin(2 * math.pi * 1800 * t) * math.exp(-t * 140.0) * 0.45
        out.append(pop + air + click)
    save_wav("shoot.wav", out)


def gen_splat():
    """Juicy wet paintball burst."""
    dur = 0.19
    n = int(SR * dur)
    rng = random.Random(101)
    out = []
    lp1 = 0.0
    lp2 = 0.0
    for i in range(n):
        t = i / SR
        noise = rng.uniform(-1.0, 1.0)
        # Bandpass squelch sweep
        alpha = 0.08 + 0.35 * math.exp(-t * 22.0)
        lp1 += alpha * (noise - lp1)
        lp2 += (alpha * 0.5) * (lp1 - lp2)
        band = lp1 - lp2
        # Soft wet bubble pop
        bubble = math.sin(2 * math.pi * (280 + 520 * math.exp(-t * 30.0)) * t) * math.exp(-t * 26.0)
        env = math.exp(-t * 18.0) * (1.0 - math.exp(-t * 260.0))
        out.append(band * env * 2.4 + bubble * 0.45)
    save_wav("splat.wav", out)


def gen_hit_marker():
    """Snappy competitive hit confirmation tick."""
    dur = 0.065
    n = int(SR * dur)
    out = []
    for i in range(n):
        t = i / SR
        s = (
            math.sin(2 * math.pi * 1650 * t) * 0.6
            + math.sin(2 * math.pi * 2480 * t) * 0.4
        ) * math.exp(-t * 62.0)
        out.append(s)
    save_wav("hit_marker.wav", out)


def gen_eliminated():
    """Dramatic paint burst + playful tag-out chime."""
    dur = 0.42
    n = int(SR * dur)
    rng = random.Random(202)
    out = []
    lp = 0.0
    for i in range(n):
        t = i / SR
        noise = rng.uniform(-1.0, 1.0)
        lp = lp * 0.8 + noise * 0.2
        burst = lp * math.exp(-t * 14.0) * 1.1
        # Two-tone descending alert pop
        f = 520.0 if t < 0.14 else 330.0
        tone = math.sin(2 * math.pi * f * t) * math.exp(-((t % 0.14) if t < 0.28 else (t - 0.14)) * 12.0) * 0.55
        out.append(burst + tone)
    save_wav("eliminated.wav", out)


def gen_dash():
    """Athletic slide/dash air whoosh."""
    dur = 0.24
    n = int(SR * dur)
    rng = random.Random(303)
    out = []
    lp = 0.0
    for i in range(n):
        t = i / SR
        noise = rng.uniform(-1.0, 1.0)
        env = math.sin(math.pi * min(1.0, t / dur)) ** 0.7
        lp = lp * (0.88 - 0.25 * env) + noise * (0.12 + 0.25 * env)
        whoosh = (noise * 0.4 + lp * 0.9) * env
        sub = math.sin(2 * math.pi * (140 + 180 * env) * t) * env * 0.35
        out.append(whoosh + sub)
    save_wav("dash.wav", out)


def gen_reload():
    """Tactile paintball pod open + pour + snap shut."""
    dur = 0.45
    n = int(SR * dur)
    rng = random.Random(404)
    out = []
    for i in range(n):
        t = i / SR
        s = 0.0
        # Click 1 at 0.02s
        if 0.02 <= t < 0.08:
            dt = t - 0.02
            s += math.sin(2 * math.pi * 1200 * dt) * math.exp(-dt * 70.0) * 0.7
        # Rattle of paintballs pouring 0.08..0.32s
        if 0.08 <= t < 0.32:
            dt = t - 0.08
            rattle = math.sin(2 * math.pi * (650 + 220 * math.sin(dt * 95.0)) * dt)
            s += (rattle * 0.35 + rng.uniform(-0.25, 0.25)) * math.sin(math.pi * dt / 0.24) * 0.5
        # Crisp snap shut at 0.34s
        if t >= 0.34:
            dt = t - 0.34
            s += (math.sin(2 * math.pi * 1700 * dt) + 0.6 * math.sin(2 * math.pi * 880 * dt)) * math.exp(-dt * 55.0) * 0.85
        out.append(s)
    save_wav("reload.wav", out)


def synth_fanfare(notes, dur, filename):
    n = int(SR * dur)
    out = [0.0] * n
    for start_t, length, freq, amp in notes:
        i0 = int(start_t * SR)
        i1 = min(n, int((start_t + length) * SR))
        for i in range(i0, i1):
            dt = (i - i0) / SR
            env = (1.0 - math.exp(-dt * 90.0)) * math.exp(-dt * (3.5 / max(length, 0.1)))
            wave_s = (
                math.sin(2 * math.pi * freq * dt) * 0.65
                + math.sin(2 * math.pi * freq * 2.0 * dt) * 0.22
                + math.sin(2 * math.pi * freq * 3.0 * dt) * 0.10
            )
            out[i] += wave_s * env * amp
    save_wav(filename, out)


if __name__ == "__main__":
    gen_shoot()
    gen_splat()
    gen_hit_marker()
    gen_eliminated()
    gen_dash()
    gen_reload()
    # Flag pickup: bright ascending triad (C5 - E5 - G5)
    synth_fanfare([
        (0.00, 0.18, 523.25, 0.7),
        (0.09, 0.20, 659.25, 0.75),
        (0.18, 0.32, 783.99, 0.9),
    ], 0.55, "flag_pickup.wav")
    # Flag return: crisp 2-note chime (G5 - C6)
    synth_fanfare([
        (0.00, 0.18, 783.99, 0.7),
        (0.10, 0.30, 1046.50, 0.85),
    ], 0.45, "flag_return.wav")
    # Flag capture: triumphant stadium chord fanfare (C5-E5-G5-C6)
    synth_fanfare([
        (0.00, 0.18, 523.25, 0.7),
        (0.10, 0.18, 659.25, 0.75),
        (0.20, 0.20, 783.99, 0.8),
        (0.32, 0.70, 1046.50, 0.95),
        (0.32, 0.70, 659.25, 0.55),
        (0.32, 0.70, 523.25, 0.50),
    ], 1.05, "flag_capture.wav")
    print(f"Generated procedural audio SFX in {OUT_DIR}")
