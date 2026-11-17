"""Synthesizes Ember Knight's title/menu audio: fire crackle, crickets and the
2-minute "Campfire Lullaby" music loop. All three loops are rendered circularly
(notes, reverb tails and noise wrap around the end), so they loop seamlessly.

Run:  python3 tools/make_audio.py   (needs numpy and ffmpeg with libvorbis)
"""
import os
import subprocess
import wave

import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
rng = np.random.default_rng(7)


# ---------------------------------------------------------------- helpers
def mtof(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def fft_filter(x, lo=None, hi=None, slope=4.0):
    """Circular band filter via FFT with smooth (butterworth-like) edges."""
    n = len(x)
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(n, 1 / SR)
    g = np.ones_like(f)
    if lo:
        g *= 1 / np.sqrt(1 + (lo / np.maximum(f, 1e-3)) ** (2 * slope))
    if hi:
        g *= 1 / np.sqrt(1 + (f / hi) ** (2 * slope))
    return np.fft.irfft(X * g, n)


def smooth_noise(n, cutoff_hz):
    """Circular smooth random curve, roughly in -1..1."""
    v = fft_filter(rng.standard_normal(n), hi=cutoff_hz, slope=2)
    return v / (np.abs(v).max() + 1e-9)


def add_wrap(buf, sig, start):
    """Add sig into buf (channels, n) at start, wrapping around the end."""
    n = buf.shape[-1]
    idx = (start + np.arange(sig.shape[-1])) % n
    buf[..., idx] += sig


def pan(sig, p):
    """p: -1 left .. 1 right (equal power)."""
    a = (p + 1) * np.pi / 4
    return np.stack([sig * np.cos(a), sig * np.sin(a)])


def reverb_ir(seconds, decay, seed, bright=6000):
    r = np.random.default_rng(seed)
    n = int(seconds * SR)
    t = np.arange(n) / SR
    chans = []
    for _ in range(2):
        ir = r.standard_normal(n) * np.exp(-t * 6.9 / decay)
        ir = fft_filter(ir, lo=180, hi=bright, slope=1.5)
        ir[: int(0.012 * SR)] *= np.linspace(0, 1, int(0.012 * SR))  # pre-delay softness
        chans.append(ir / np.sqrt((ir ** 2).sum()))
    return np.stack(chans)


def circ_convolve(x, ir):
    """Circular convolution per channel (tail wraps to the loop start)."""
    n = x.shape[-1]
    out = np.empty_like(x)
    for c in range(2):
        h = np.zeros(n)
        h[: ir.shape[-1]] = ir[c][:n]
        out[c] = np.fft.irfft(np.fft.rfft(x[c]) * np.fft.rfft(h), n)
    return out


def write_ogg(name, stereo, q=6):
    os.makedirs(OUT, exist_ok=True)
    wav = os.path.join(OUT, name + ".wav")
    pcm = (np.clip(stereo.T, -1, 1) * 32767).astype("<i2")
    with wave.open(wav, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    ogg = os.path.join(OUT, name + ".ogg")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis",
                    "-q:a", str(q), ogg], check=True)
    os.remove(wav)
    print(f"{name}.ogg  {stereo.shape[1] / SR:.1f}s  {os.path.getsize(ogg) // 1024} KB")


def normalize(x, peak_db=-1.0):
    return x * (10 ** (peak_db / 20) / np.abs(x).max())


# ---------------------------------------------------------------- fire
def make_fire(seconds=32.0):
    n = int(seconds * SR)
    out = np.zeros((2, n))
    # Body: warm low roar that breathes slowly.
    roar = fft_filter(rng.standard_normal(n), lo=40, hi=320, slope=2)
    roar /= np.abs(roar).max()
    breathe = 0.65 + 0.35 * smooth_noise(n, 0.35)
    # Air: soft hiss of the flames, flickering faster.
    hiss = fft_filter(rng.standard_normal(n), lo=1800, hi=7000, slope=2)
    hiss /= np.abs(hiss).max()
    flick = 0.55 + 0.45 * smooth_noise(n, 2.5)
    bed = 0.22 * roar * breathe + 0.05 * hiss * flick
    out += np.stack([bed, np.roll(bed, int(0.011 * SR))])

    # Crackles: Poisson clicks, mostly small, a few bright pops with tiny clusters.
    def crackle(amp, decay_ms, centre):
        L = int(decay_ms * 6 / 1000 * SR) + 16
        t = np.arange(L) / SR
        s = rng.standard_normal(L) * np.exp(-t * 1000 / decay_ms)
        s[:3] *= 2.5  # sharp transient
        lo, hi = centre / 1.8, centre * 1.8
        s = fft_filter(np.pad(s, (0, 256)), lo=lo, hi=hi, slope=2)
        return amp * s / (np.abs(s).max() + 1e-9)

    t = 0.0
    while t < seconds:
        t += rng.exponential(1 / 11.0)
        big = rng.random() < 0.07
        reps = rng.integers(2, 5) if big else 1
        tt = t
        for _ in range(reps):
            amp = (rng.uniform(0.45, 0.9) if big else rng.lognormal(-1.2, 0.55))
            sig = crackle(min(amp, 0.95), rng.uniform(2, 9) if big else rng.uniform(1, 5),
                          rng.uniform(900, 2600) if big else rng.uniform(1500, 7000))
            add_wrap(out, pan(sig, rng.uniform(-0.5, 0.5)), int(tt * SR) % n)
            tt += rng.uniform(0.006, 0.05)
    # A little room so pops sit in space.
    out = 0.85 * out + 0.15 * circ_convolve(out, reverb_ir(0.8, 0.5, 11))
    # Soft-limit the loudest pops so the fire sits louder without harsh peaks.
    out = normalize(out, 0.0)
    out = np.tanh(out * 3.0) / np.tanh(3.0)
    return normalize(out, -1.5)


# ---------------------------------------------------------------- crickets
def make_crickets(seconds=24.0):
    n = int(seconds * SR)
    out = np.zeros((2, n))
    # (carrier Hz, pulses per chirp, chirp period s, level, pan, distance blur)
    voices = [(4350, 3, 0.62, 0.55, -0.6, 0.0),
              (4720, 4, 0.81, 0.30, 0.55, 0.3),
              (3980, 3, 0.97, 0.16, 0.1, 0.6)]
    for f0, pulses, period, lvl, p, far in voices:
        sig = np.zeros(n)
        pl = int(0.016 * SR)
        tt = np.arange(pl) / SR
        env = np.sin(np.pi * np.arange(pl) / pl) ** 2
        t = rng.uniform(0, period)
        # Each cricket sings in phrases and rests, like real ones.
        phrase_on = True
        next_switch = rng.uniform(4, 9)
        while t < seconds - 0.3:
            if t > next_switch:
                phrase_on = not phrase_on
                next_switch = t + (rng.uniform(5, 10) if phrase_on else rng.uniform(1.5, 4))
            if phrase_on:
                for k in range(pulses):
                    f = f0 * (1 + rng.normal(0, 0.004))
                    tone = (np.sin(2 * np.pi * f * tt) + 0.15 * np.sin(4 * np.pi * f * tt)) * env
                    s = int((t + k * 0.045) * SR)
                    sig[s:s + pl] += tone * rng.uniform(0.8, 1.0)
            t += period * rng.uniform(0.95, 1.05)
        st = pan(sig * lvl, p)
        if far:
            st = (1 - far) * st + far * 2.0 * circ_convolve(st, reverb_ir(1.2, 0.9, 21, bright=9000))
        out += st
    # Faint night-air bed so silence between chirps isn't dead.
    air = fft_filter(rng.standard_normal(n), lo=300, hi=2500)
    air = 0.02 * air / np.abs(air).max()
    out += np.stack([air, np.roll(air, 900)])
    return normalize(out, -3.0)


# ---------------------------------------------------------------- music
# 6/8 lullaby in D (with Mixolydian C natural for a medieval colour).
# Dotted-quarter = 48 bpm -> bar = 2.5 s, 48 bars = 120 s exactly.
EIGHTH = 2.5 / 6
BARS = 48

CH = {  # chord -> (root midi in octave 2-3, chord tones)
    "D": (50, [62, 66, 69]), "C": (48, [60, 64, 67]), "G": (43, [55, 59, 62]),
    "Bm": (47, [59, 62, 66]), "Em": (52, [64, 67, 71]), "A": (45, [57, 61, 64]),
    "F#m": (54, [54, 57, 61]),
}
P1 = ["D", "C", "G", "D", "Bm", "G", "Em", "A"]
P2 = ["D", "C", "G", "D", "Bm", "G", "A", "D"]
P3 = ["Bm", "F#m", "G", "D", "Em", "Bm", "G", "A"]
FORM = P1 + P1 + P2 + P3 + P1 + P2  # intro, A, A', B, A, A'(fade)

_ = None
MEL_A = [[(78, 3), (81, 2), (78, 1)], [(79, 2), (76, 1), (76, 3)],
         [(74, 2), (71, 1), (74, 2), (79, 1)], [(78, 5), (_, 1)],
         [(78, 2), (83, 1), (81, 2), (78, 1)], [(79, 2), (78, 1), (76, 2), (74, 1)],
         [(76, 3), (79, 2), (76, 1)], [(76, 2), (73, 1), (69, 3)]]
MEL_A2 = MEL_A[:4] + [[(83, 3), (81, 2), (78, 1)], [(79, 2), (81, 1), (83, 2), (79, 1)],
                      [(81, 3), (76, 2), (73, 1)], [(74, 6)]]
MEL_B = [[(71, 3), (74, 2), (78, 1)], [(81, 3), (78, 2), (73, 1)],
         [(74, 2), (71, 1), (67, 3)], [(69, 5), (_, 1)],
         [(71, 2), (76, 1), (79, 2), (76, 1)], [(78, 3), (74, 3)],
         [(79, 2), (78, 1), (76, 2), (74, 1)], [(73, 3), (76, 3)]]
REST8 = [[(_, 6)]] * 8
MELODY = REST8 + MEL_A + MEL_A2 + MEL_B + MEL_A + MEL_A2
# Bell counter-line on bars 33-40 (second A), and sparkles in the intro.
BELL_BARS = {0: [86, 81], 2: [83, 79], 4: [86, 83], 6: [88, 85],
             32: [90], 33: [88], 34: [86], 35: [90], 36: [95], 37: [91], 38: [88], 39: [85]}


def pluck(freq, dur, bright=0.5, amp=1.0):
    """Karplus-Strong string (harp/lute)."""
    n = int(dur * SR)
    p = max(2, int(round(SR / freq)))
    buf = rng.uniform(-1, 1, p)
    buf = fft_filter(np.tile(buf, 4), hi=1500 + 6000 * bright)[:p]  # soften pick
    out = np.empty(n)
    k = 0.4985 + 0.0013 * bright
    pos = 0
    while pos < n:
        m = min(p, n - pos)
        out[pos:pos + m] = buf[:m]
        nb = k * (buf + np.roll(buf, -1))
        buf = nb
        pos += m
    t = np.arange(n) / SR
    out *= np.minimum(1, t / 0.003)
    out[-int(0.05 * SR):] *= np.linspace(1, 0, int(0.05 * SR))
    return amp * out / (np.abs(out).max() + 1e-9)


def recorder(midi, dur, amp=1.0):
    """Soft wooden flute: few harmonics, delayed vibrato, breath."""
    f = mtof(midi)
    n = int((dur + 0.25) * SR)
    t = np.arange(n) / SR
    vib = 1 + 0.0045 * np.sin(2 * np.pi * 5.0 * t) * np.clip((t - 0.35) / 0.5, 0, 1)
    ph = 2 * np.pi * np.cumsum(f * vib) / SR
    tone = np.sin(ph) + 0.22 * np.sin(2 * ph) + 0.08 * np.sin(3 * ph) + 0.03 * np.sin(4 * ph)
    breath = fft_filter(rng.standard_normal(n), lo=f * 0.8, hi=f * 3)
    breath *= 0.05 / (np.abs(breath).max() + 1e-9)
    env = np.minimum(1, t / 0.07) * np.clip((dur + 0.18 - t) / 0.18, 0, 1)
    env *= 1 - 0.12 * np.clip(t / max(dur, 0.1), 0, 1)  # gentle diminuendo on long notes
    return amp * (tone + breath * (1 + 2 * np.exp(-t * 20))) * env


def bell(midi, amp=1.0):
    f = mtof(midi)
    n = int(3.0 * SR)
    t = np.arange(n) / SR
    s = (np.sin(2 * np.pi * f * t) * np.exp(-t * 1.6)
         + 0.35 * np.sin(2 * np.pi * f * 2.76 * t) * np.exp(-t * 4)
         + 0.12 * np.sin(2 * np.pi * f * 5.40 * t) * np.exp(-t * 9))
    return amp * s * np.minimum(1, t / 0.002)


def pad_chord(tones, dur):
    n = int((dur + 1.6) * SR)
    t = np.arange(n) / SR
    s = np.zeros(n)
    for m in tones:
        for det in (-0.07, 0.07):
            f = mtof(m - 12) * 2 ** (det / 12)
            for h in range(1, 7):
                s += np.sin(2 * np.pi * f * h * t + rng.uniform(0, 6.28)) / h ** 1.6
    swell = 1 + 0.15 * np.sin(2 * np.pi * t / dur)
    env = np.clip(t / 0.9, 0, 1) * np.clip((dur + 1.5 - t) / 1.5, 0, 1)
    return s * env * swell / (len(tones) * 6)


def make_music():
    n = int(BARS * 2.5 * SR)
    dry = np.zeros((2, n))
    bar_s = 2.5
    for b, ch in enumerate(FORM):
        root, tones = CH[ch]
        t0 = b * bar_s
        # Dynamics: soft intro, fuller middle, thinning in the last 4 bars to loop home.
        lvl = 0.8 if b < 8 else (1.0 if b < 44 else 0.85)
        # Pad.
        add_wrap(dry, pan(pad_chord(tones, bar_s) * 0.22 * lvl, 0.0), int(t0 * SR))
        # Bass pluck + soft sub on the downbeat.
        bass = pluck(mtof(root), 3.2, bright=0.2, amp=0.42 * lvl)
        tt = np.arange(int(2.6 * SR)) / SR
        sub = 0.12 * lvl * np.sin(2 * np.pi * mtof(root) * tt) * np.exp(-tt * 0.9) * np.minimum(1, tt / 0.02)
        add_wrap(dry, pan(bass, -0.1), int(t0 * SR))
        add_wrap(dry, pan(sub, 0.0), int(t0 * SR))
        # Harp arpeggio: root, 5th, octave, 3rd(high), octave, 5th.
        r = tones[0]
        third = tones[1]
        fifth = tones[2]
        arp = [r, fifth, r + 12, third + 12, r + 12, fifth]
        for k, m in enumerate(arp):
            human = rng.normal(0, 0.008)
            acc = 1.0 if k in (0, 3) else 0.72
            s = pluck(mtof(m), 2.6, bright=0.55, amp=0.3 * acc * lvl)
            add_wrap(dry, pan(s, -0.35 + 0.1 * (k % 3)), int((t0 + k * EIGHTH + human) * SR))
        # Melody.
        pos = 0
        for m, d in MELODY[b]:
            if m is not None:
                s = recorder(m, d * EIGHTH * 0.96, amp=0.14 * lvl)
                add_wrap(dry, pan(s, 0.25), int((t0 + pos * EIGHTH) * SR))
            pos += d
        # Bells.
        for k, m in enumerate(BELL_BARS.get(b, [])):
            add_wrap(dry, pan(bell(m, 0.09), 0.45 - 0.3 * k), int((t0 + k * 3 * EIGHTH) * SR))
    wet = circ_convolve(dry, reverb_ir(3.2, 2.6, 5, bright=5000))
    mix = 0.78 * dry + 0.55 * wet
    # Gentle warmth: roll off harsh highs.
    mix = np.stack([fft_filter(c, lo=35, hi=9000, slope=1) for c in mix])
    return normalize(mix, -1.5)


if __name__ == "__main__":
    write_ogg("fire_crackle", make_fire())
    write_ogg("crickets", make_crickets(), q=5)
    write_ogg("campfire_lullaby", make_music())
