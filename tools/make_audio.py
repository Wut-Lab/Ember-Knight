"""Synthesizes Ember Knight's title/menu audio: fire crackle, crickets and the
2-minute "Campfire Lullaby" music loop. All three loops are rendered circularly
(notes, reverb tails and noise wrap around the end), so they loop seamlessly.

Also renders the short sound effects in assets/audio/sfx/ (dice, defenses,
UI button tap...).

Run:  python3 tools/make_audio.py           (everything)
      python3 tools/make_audio.py boss      (just the boss music)
      python3 tools/make_audio.py button    (just the named sound effects)
Needs numpy and ffmpeg with libvorbis.
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


# The tense version for waves: same key, tempo, form and length, so the game can
# crossfade between the two at the same playback position. Major chords go
# minor, F# melody notes become F, a heartbeat thump pulses under every
# dotted quarter, the pad trembles and a low D drone sits underneath.
TENSE_CH = {"D": (50, [62, 65, 69]), "Bm": (46, [58, 62, 65]), "F#m": (53, [53, 57, 60])}
TENSE_NOTE = {78: 77, 66: 65, 90: 89, 83: 82}


def heartbeat(amp):
    """Lub-dub. A pitch-dropping thump (130 -> 60 Hz) with a muffled click and
    soft saturation, so the beat still reads on phone and laptop speakers,
    which can't play the deep fundamental."""
    n = int(0.5 * SR)
    t = np.arange(n) / SR

    def thump(f0, d):
        f = 60 + (f0 - 60) * np.exp(-t / 0.03)
        body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / d)
        click = fft_filter(rng.standard_normal(n), lo=120, hi=900) * np.exp(-t / 0.012)
        click *= 0.35 / (np.abs(click).max() + 1e-9)
        return np.tanh(2.2 * (body + click)) * np.minimum(1, t / 0.003)

    beat = thump(130, 0.11)
    second = np.zeros(n)
    k = int(0.17 * SR)
    second[k:] = thump(115, 0.09)[:n - k] * 0.7
    return amp * (beat + second)


def make_music(tense=False):
    n = int(BARS * 2.5 * SR)
    dry = np.zeros((2, n))
    bar_s = 2.5
    if tense:  # low D drone under the whole loop (seamless: whole cycles)
        tt = np.arange(n) / SR
        drone = 0.05 * (np.sin(2 * np.pi * 36.75 * tt) + 0.4 * np.sin(2 * np.pi * 73.5 * tt))
        drone *= 1 + 0.25 * np.sin(2 * np.pi * tt / 10.0)
        dry += np.stack([drone, drone])
    for b, ch in enumerate(FORM):
        root, tones = (TENSE_CH.get(ch) or CH[ch]) if tense else CH[ch]
        t0 = b * bar_s
        # Dynamics: soft intro, fuller middle, thinning in the last 4 bars to loop home.
        lvl = 0.8 if b < 8 else (1.0 if b < 44 else 0.85)
        # Pad.
        pad = pad_chord(tones, bar_s) * 0.22 * lvl
        if tense:  # trembling strings
            pad *= 1 + 0.35 * np.sin(2 * np.pi * 7.0 * np.arange(len(pad)) / SR)
            for beat in (0, 3):
                add_wrap(dry, pan(heartbeat(0.45 * lvl), 0.0), int((t0 + beat * EIGHTH) * SR))
        add_wrap(dry, pan(pad, 0.0), int(t0 * SR))
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
                if tense:
                    m = TENSE_NOTE.get(m, m)
                s = recorder(m, d * EIGHTH * 0.96, amp=0.14 * lvl)
                add_wrap(dry, pan(s, 0.25), int((t0 + pos * EIGHTH) * SR))
            pos += d
        # Bells.
        for k, m in enumerate(BELL_BARS.get(b, [])):
            if tense:
                m = TENSE_NOTE.get(m, m)
            add_wrap(dry, pan(bell(m, 0.09), 0.45 - 0.3 * k), int((t0 + k * 3 * EIGHTH) * SR))
    wet = circ_convolve(dry, reverb_ir(3.2, 2.6, 5, bright=5000))
    mix = 0.78 * dry + 0.55 * wet
    # Gentle warmth: roll off harsh highs.
    mix = np.stack([fft_filter(c, lo=35, hi=9000, slope=1) for c in mix])
    return normalize(mix, -1.5)


# ---------------------------------------------------------------- sound effects
def _env(n, attack, decay):
    t = np.arange(n) / SR
    return np.minimum(1, t / max(attack, 1e-4)) * np.exp(-t / decay)


def _noise(n, lo=None, hi=None):
    return fft_filter(rng.standard_normal(n), lo=lo, hi=hi)


def _tone(f0, f1, dur, decay):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = np.geomspace(f0, f1, n)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * _env(n, 0.002, decay)


def _place(out, sig, at):
    s = int(at * SR)
    out[s:s + len(sig)] += sig[:max(0, len(out) - s)]


def sfx_dice_roll():
    out = np.zeros(int(0.6 * SR))
    t = 0.0
    amp = 1.0
    for k in range(7):
        n = int(0.05 * SR)
        click = _noise(n, 1800, 6000) * _env(n, 0.0005, 0.008)
        knock = _tone(420 * rng.uniform(0.85, 1.2), 300, 0.05, 0.02) * 0.6
        _place(out, amp * (click / np.abs(click).max() + knock), t)
        t += rng.uniform(0.045, 0.09)
        amp *= 0.8
    return out


def sfx_place():
    out = np.zeros(int(0.45 * SR))
    _place(out, _tone(190, 110, 0.3, 0.07), 0)
    n = int(0.02 * SR)
    _place(out, 0.4 * _noise(n, 800, 4000) * _env(n, 0.0005, 0.004) * 8, 0)
    _place(out, 0.18 * _tone(1760, 1760, 0.4, 0.12), 0.03)
    _place(out, 0.12 * _tone(2637, 2637, 0.4, 0.1), 0.07)
    return out


def sfx_bolt():
    n = int(0.22 * SR)
    t = np.arange(n) / SR
    w = np.zeros(n)
    noise = rng.standard_normal(n)
    # Sweep a band upward by filtering short overlapping chunks.
    seg = 512
    for i in range(0, n, seg // 2):
        f = 1200 + 3500 * (i / n)
        chunk = fft_filter(noise[i:i + seg], lo=f * 0.7, hi=f * 1.4) if len(noise[i:i + seg]) > 32 else 0
        w[i:i + seg] += chunk * np.hanning(len(noise[i:i + seg]))
    env = np.sin(np.pi * np.clip(t / 0.22, 0, 1)) ** 1.5
    return w * env


def sfx_flare():
    n = int(0.55 * SR)
    body = _noise(n, 60, 900) * _env(n, 0.01, 0.14)
    body /= np.abs(body).max()
    return body + 0.5 * _tone(110, 70, 0.55, 0.12) + 0.15 * _noise(n, 2000, 7000) * _env(n, 0.002, 0.05) / 3


def sfx_pop():
    out = np.zeros(int(0.5 * SR))
    _place(out, _tone(950, 280, 0.16, 0.06), 0)
    n = int(0.25 * SR)
    air = _noise(n, 2500, 9000) * _env(n, 0.003, 0.05)
    _place(out, 0.4 * air / np.abs(air).max(), 0)
    _place(out, 0.2 * _tone(2349, 2349, 0.35, 0.09), 0.05)
    return out


def sfx_hurt():
    n = int(0.6 * SR)
    thump = _tone(80, 45, 0.6, 0.16)
    hiss = _noise(n, 300, 3000) * _env(n, 0.005, 0.18)
    hiss /= np.abs(hiss).max()
    return np.tanh(1.6 * (thump + 0.45 * hiss))


def sfx_tap():
    out = np.zeros(int(0.12 * SR))
    _place(out, _tone(1300, 1100, 0.1, 0.018), 0)
    return out


def sfx_button():
    """Standard UI button tap: a soft wooden "tok" with a tiny bright tick on top."""
    out = np.zeros(int(0.16 * SR))
    n = int(0.012 * SR)
    tick = _noise(n, 2500, 7000) * _env(n, 0.0003, 0.0025)
    _place(out, 0.35 * tick / np.abs(tick).max(), 0)
    _place(out, _tone(720, 560, 0.12, 0.022), 0)          # wooden body
    _place(out, 0.45 * _tone(360, 300, 0.14, 0.035), 0)   # warmth underneath
    _place(out, 0.08 * _tone(1440, 1400, 0.1, 0.02), 0.004)
    return out


def sfx_chime():
    out = np.zeros(int(2.2 * SR))
    for k, m in enumerate([74, 78, 81, 86]):
        _place(out, bell(m, 0.6), k * 0.11)
    return out


def sfx_wave():
    n = int(1.4 * SR)
    t = np.arange(n) / SR
    s = np.zeros(n)
    for m, a in [(50, 1.0), (57, 0.7), (62, 0.4)]:
        f = mtof(m)
        for h in range(1, 6):
            s += a * np.sin(2 * np.pi * f * h * t) / h ** 1.3
    env = np.clip(t / 0.35, 0, 1) * np.clip((1.4 - t) / 0.7, 0, 1)
    return s * env


def sfx_charge_hum():
    """Charged Wisp spawns: a buzzy electric hum that swells in, wavers and fades,
    with a few faint crackle ticks on top."""
    dur = 1.2
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = 98 * (1 + 0.04 * t / dur) * (1 + 0.006 * np.sin(2 * np.pi * 7 * t))
    ph = 2 * np.pi * np.cumsum(f) / SR
    buzz = sum(np.sin(h * ph) / h ** 0.9 for h in range(1, 14))   # bright, saw-like
    buzz = fft_filter(buzz, lo=70, hi=2400)
    buzz *= 1 + 0.25 * np.sin(2 * np.pi * 13 * t)                   # electric flutter
    env = np.clip(t / 0.35, 0, 1) ** 1.5 * np.clip((dur - t) / 0.45, 0, 1)
    out = np.tanh(1.8 * buzz / np.abs(buzz).max()) * env
    for k in range(6):
        m = int(0.015 * SR)
        tick = _noise(m, 2500, 8000) * _env(m, 0.0003, 0.003)
        _place(out, 0.25 * tick / np.abs(tick).max(), rng.uniform(0.25, 0.95))
    return out


def sfx_zap():
    """Charged Wisp attacks: a sharp crackling snap with a falling buzz."""
    dur = 0.38
    n = int(dur * SR)
    t = np.arange(n) / SR
    crackle = _noise(n, 1500, 9000)
    gate = (rng.random(n // 220 + 1) < 0.55).repeat(220)[:n]          # stuttering arc
    crackle = crackle / np.abs(crackle).max() * gate * _env(n, 0.001, 0.09)
    f = np.geomspace(1400, 220, n)
    ph = 2 * np.pi * np.cumsum(f) / SR
    buzz = sum(np.sin(h * ph) / h for h in range(1, 8)) * _env(n, 0.002, 0.12)
    snap = _noise(int(0.01 * SR), 800, 6000) * _env(int(0.01 * SR), 0.0002, 0.002)
    out = 0.7 * crackle + 0.5 * buzz / np.abs(buzz).max()
    _place(out, 0.8 * snap / np.abs(snap).max(), 0)
    return np.tanh(2.0 * out)


def sfx_wind():
    """Before a boss: a gust of wind blowing by (~1.3s) while the music drops out.
    Noise through a band that sweeps up and back down, swelling in and out."""
    dur = 1.3
    n = int(dur * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    seg = int(0.05 * SR)
    raw = rng.standard_normal(n + seg)
    for k in range(0, n, seg // 2):   # overlapping windows, each with its own band
        x = k / n
        centre = 350 + 1500 * np.sin(np.pi * x) ** 1.5
        w = fft_filter(raw[k:k + seg], lo=centre * 0.55, hi=centre * 1.6, slope=2)
        win = np.hanning(len(w))
        out[k:k + len(w)] += (w * win)[:max(0, n - k)]
    gust = np.sin(np.pi * np.clip(t / dur, 0, 1)) ** 1.4
    gust *= 1 + 0.25 * np.sin(2 * np.pi * 3.1 * t) * np.sin(np.pi * t / dur)   # a flutter mid-gust
    low = fft_filter(rng.standard_normal(n), lo=60, hi=260) * 0.5
    return (out / np.abs(out).max() + low / np.abs(low).max() * 0.3) * gust


def sfx_dark_arrive():
    """Carl, the Dark Wisp appears: a deep falling drone, a whispery swell and a
    low boom."""
    dur = 2.2
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = 82 * np.exp(-t * 0.18)
    ph = 2 * np.pi * np.cumsum(f) / SR
    drone = sum(np.sin(h * ph) / h ** 1.2 for h in range(1, 9))
    drone = np.tanh(1.6 * drone / np.abs(drone).max())
    drone *= np.clip(t / 0.5, 0, 1) * np.clip((dur - t) / 0.9, 0, 1)
    whisper = _noise(n, 400, 2200)
    whisper *= (np.clip(t / 0.9, 0, 1) ** 2) * np.exp(-np.clip(t - 0.9, 0, None) * 6)
    whisper /= np.abs(whisper).max()
    boom = _tone(90, 38, 1.3, 0.45)
    out = 0.75 * drone + 0.35 * whisper
    _place(out, 0.9 * boom, 0.85)
    return np.tanh(1.3 * out)


def sfx_helio_arrive():
    """Helio, the Midnight Sun appears: a blazing major chord swelling up through
    a roaring, crackling flare, and a low angry rumble under it."""
    dur = 2.0
    n = int(dur * SR)
    t = np.arange(n) / SR
    env = np.clip(t / 0.9, 0, 1) ** 1.5 * np.clip((dur - t) / 0.7, 0, 1)
    chord = sum(np.sin(2 * np.pi * f * (1 + 0.004 * np.sin(2 * np.pi * 5 * t)) * t) / (i + 1) ** 0.6
                for i, f in enumerate([220, 277.2, 329.6, 440, 554.4]))
    chord = np.tanh(1.4 * chord / np.abs(chord).max()) * env
    roar = _noise(n, 300, 3000) * env
    roar /= np.abs(roar).max()
    crackle = (np.random.rand(n) < 0.004) * np.random.randn(n) * env
    rumble = np.sin(2 * np.pi * 55 * t + 2 * np.sin(2 * np.pi * 7 * t)) * env
    out = 0.5 * chord + 0.3 * roar + 0.5 * crackle + 0.35 * rumble
    return np.tanh(1.2 * out)


def sfx_thief_arrive():
    """The Lantern Thief appears: a sly rising whistle and a rattling lantern."""
    dur = 1.0
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = np.geomspace(700, 1500, n) * (1 + 0.02 * np.sin(2 * np.pi * 9 * t))
    whistle = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.clip(t / 0.08, 0, 1) * np.clip((0.55 - t) / 0.2, 0, 1)
    out = 0.45 * whistle
    for k in range(9):   # tinny lantern rattle
        m = int(0.12 * SR)
        tt = np.arange(m) / SR
        fr = rng.uniform(2600, 4200)
        ping = (np.sin(2 * np.pi * fr * tt) + 0.5 * np.sin(2 * np.pi * fr * 2.7 * tt)) * np.exp(-tt * 45)
        _place(out, 0.3 * ping, 0.35 + k * 0.06 + rng.uniform(0, 0.02))
    return out


def sfx_dash():
    """The Lantern Thief dashes: a quick rising-then-falling whoosh."""
    dur = 0.45
    n = int(dur * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    seg = int(0.03 * SR)
    raw = rng.standard_normal(n + seg)
    for k in range(0, n, seg // 2):
        x = k / n
        centre = 600 + 3200 * np.sin(np.pi * min(1.0, x * 1.4)) ** 2
        w = fft_filter(raw[k:k + seg], lo=centre * 0.6, hi=centre * 1.5, slope=2) * np.hanning(seg)
        out[k:k + seg] += w[:max(0, n - k)]
    return out / np.abs(out).max() * np.sin(np.pi * t / dur) ** 0.8


def sfx_snuff():
    """A defense is snuffed out: a breathy puff, like blowing out a candle, and a
    tiny falling sizzle."""
    dur = 0.35
    n = int(dur * SR)
    puff = _noise(n, 150, 1400) * _env(n, 0.01, 0.07)
    sizzle = _noise(n, 3000, 9000) * _env(n, 0.03, 0.12) * 0.4
    tone = _tone(520, 240, dur, 0.1) * 0.25
    out = puff / np.abs(puff).max() + sizzle / np.abs(sizzle).max() * 0.35 + tone
    return out


def sfx_ember_pickup():
    """Ember Drop picked up: a soft warm whoosh rising into a bright little sparkle."""
    out = np.zeros(int(0.5 * SR))
    n = int(0.22 * SR)
    t = np.arange(n) / SR
    whoosh = _noise(n, 400, 2500) * np.sin(np.pi * t / 0.22) ** 2
    _place(out, 0.5 * whoosh / np.abs(whoosh).max(), 0)
    _place(out, 0.6 * _tone(392, 784, 0.25, 0.12), 0.02)      # warm rise
    _place(out, 0.3 * bell(84, 0.6)[:int(0.4 * SR)], 0.12)    # sparkle on top
    return out


def sfx_vine():
    """Forest Friend's touch: a soft woody marimba chime, two notes, with a leafy rustle."""
    out = np.zeros(int(0.9 * SR))
    for at, m, amp in ((0.0, 88, 1.0), (0.07, 83, 0.7)):   # E6 then B5
        f = mtof(m)
        bar = _tone(f, f, 0.8, 0.22) + 0.35 * _tone(f * 3.93, f * 3.93, 0.8, 0.04) + 0.12 * _tone(f * 0.5, f * 0.5, 0.8, 0.12)
        _place(out, amp * bar, at)
    n = int(0.25 * SR)
    _place(out, 0.25 * _noise(n, 2500, 9000) * _env(n, 0.03, 0.06) * 6, 0.0)
    return out


def sfx_hound():
    """Hella scares a Wisp off: a gruff two-part "rr-ruff!" bark, then a whoosh as it's flung back."""
    out = np.zeros(int(0.75 * SR))
    for at, f0, f1, dur, amp in ((0.0, 300, 250, 0.07, 0.45), (0.09, 470, 230, 0.16, 1.0)):
        n = int(dur * SR)
        t = np.arange(n) / SR
        f = np.geomspace(f0, f1, n) * (1 + 0.03 * rng.standard_normal(n).cumsum() / np.sqrt(n))
        ph = 2 * np.pi * np.cumsum(f) / SR
        saw = sum(np.sin(k * ph) / k for k in range(1, 14))          # buzzy throat
        env = np.minimum(1, t / 0.008) * np.exp(-t / (dur * 0.45))
        voice = fft_filter(saw * env, 350, 2400, slope=2)              # mouth formant
        breath = _noise(n, 500, 3500) * env * 0.35
        sig = voice / np.abs(voice).max() + breath
        _place(out, amp * sig, at)
    n = int(0.4 * SR)
    t = np.arange(n) / SR
    whoosh = _noise(n, 300, 1800) * np.sin(np.pi * t / 0.4) ** 2
    _place(out, 0.3 * whoosh / np.abs(whoosh).max(), 0.26)
    return out


def sfx_lamp():
    """Leopold's Lit Lamp volley: a soft breath of flame and a glassy ping, with a little shimmer."""
    out = np.zeros(int(1.1 * SR))
    n = int(0.3 * SR)
    t = np.arange(n) / SR
    fwump = _noise(n, 80, 700) * np.sin(np.pi * np.minimum(1, t / 0.3)) ** 2
    _place(out, 0.45 * fwump / np.abs(fwump).max(), 0)
    _place(out, 0.35 * _tone(180, 120, 0.3, 0.1), 0)
    f = mtof(91)                                                        # G6 glass
    glass = _tone(f, f, 1.0, 0.35) + 0.4 * _tone(f * 2.76, f * 2.76, 1.0, 0.12) + 0.2 * _tone(f * 5.4, f * 5.4, 1.0, 0.05)
    _place(out, 0.55 * glass, 0.06)
    for k, m in enumerate((98, 103, 100)):
        _place(out, 0.12 * bell(m, 0.5)[:int(0.5 * SR)], 0.12 + k * 0.05)
    return out


def sfx_bell_toll():
    """A Bellringer drifts in: two slow tolls of a small, old bronze bell
    (church-bell partials: hum, prime, minor third, fifth, nominal), with a
    hollow stone-chapel tail."""
    dur = 2.6
    out = np.zeros(int(dur * SR))
    partials = ((0.5, 0.55, 1.1), (1.0, 1.0, 1.9), (1.19, 0.45, 2.6), (1.5, 0.3, 3.2),
                (2.0, 0.4, 3.8), (2.66, 0.18, 6.0), (3.01, 0.12, 8.0))
    for at, midi, amp in ((0.0, 74, 1.0), (0.62, 74, 0.7)):
        f = mtof(midi)
        n = int(2.0 * SR)
        t = np.arange(n) / SR
        sig = np.zeros(n)
        for ratio, a, dec in partials:
            beat = 1 + 0.004 * np.sin(2 * np.pi * (1.3 + ratio) * t)   # slow warble of an old bell
            sig += a * np.sin(2 * np.pi * f * ratio * np.cumsum(beat) / SR) * np.exp(-t * dec)
        clank = _noise(int(0.03 * SR), lo=2500) * _env(int(0.03 * SR), 0.0005, 0.006)
        sig[:len(clank)] += 0.35 * clank
        _place(out, amp * sig * np.minimum(1, t / 0.0015), at)
    ir = reverb_ir(1.6, 2.2, 7, bright=3500)[0]
    m = len(out) + len(ir)
    wet = np.fft.irfft(np.fft.rfft(out, m) * np.fft.rfft(ir, m), m)[:len(out)]   # linear, no wrap
    return 0.75 * out + 0.35 * wet / (np.max(np.abs(wet)) + 1e-9) * np.max(np.abs(out))


def write_sfx(only=None):
    global OUT
    base = OUT
    OUT = os.path.join(base, "sfx")
    for name, fn in [("dice_roll", sfx_dice_roll), ("place", sfx_place), ("bolt", sfx_bolt),
                     ("flare", sfx_flare), ("pop", sfx_pop), ("hurt", sfx_hurt), ("tap", sfx_tap),
                     ("chime", sfx_chime), ("wave", sfx_wave), ("button", sfx_button),
                     ("charge_hum", sfx_charge_hum), ("zap", sfx_zap), ("wind", sfx_wind),
                     ("dark_arrive", sfx_dark_arrive), ("thief_arrive", sfx_thief_arrive), ("helio_arrive", sfx_helio_arrive),
                     ("dash", sfx_dash), ("snuff", sfx_snuff), ("ember_pickup", sfx_ember_pickup), ("vine", sfx_vine),
                     ("hound", sfx_hound), ("lamp", sfx_lamp), ("bell_toll", sfx_bell_toll)]:
        if only and name not in only:
            continue
        mono = fn()
        mono[-int(0.01 * SR):] *= np.linspace(1, 0, int(0.01 * SR))
        write_ogg(name, normalize(np.stack([mono, mono]), -1.0), q=4)
    OUT = base


# ---------------------------------------------------------------- boss music
# The boss version: the Night Watch harmony and melody, 1.6x faster (bar = 1.5625 s),
# with a driving harp ostinato on every eighth, a heavy heartbeat on every beat,
# war-drum hits, a louder drone and trembling strings. 16 bars = 25 s loop.
BOSS_FORM = P1 + P3
BOSS_MELODY = MEL_A + MEL_B


def war_drum(amp):
    n = int(0.6 * SR)
    t = np.arange(n) / SR
    f = 55 + 90 * np.exp(-t / 0.02)
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.18)
    skin = fft_filter(rng.standard_normal(n), lo=150, hi=1800) * np.exp(-t / 0.03)
    skin *= 0.5 / (np.abs(skin).max() + 1e-9)
    return amp * np.tanh(2.5 * (body + skin)) * np.minimum(1, t / 0.002)


def make_boss_music():
    bar_s = 2.5 / 1.6
    e8 = bar_s / 6
    n = int(len(BOSS_FORM) * bar_s * SR)
    dry = np.zeros((2, n))
    tt = np.arange(n) / SR
    drone = 0.09 * (np.sin(2 * np.pi * 36.75 * tt) + 0.5 * np.sin(2 * np.pi * 73.5 * tt))
    drone *= 1 + 0.3 * np.sin(2 * np.pi * tt / (bar_s * 2))
    dry += np.stack([drone, drone])
    for b, ch in enumerate(BOSS_FORM):
        root, tones = TENSE_CH.get(ch) or CH[ch]
        t0 = b * bar_s
        pad = pad_chord(tones, bar_s) * 0.2
        pad *= 1 + 0.45 * np.sin(2 * np.pi * 9.0 * np.arange(len(pad)) / SR)
        add_wrap(dry, pan(pad, 0.0), int(t0 * SR))
        for beat in (0, 3):   # heavy heartbeat, doubled with a sub thump
            add_wrap(dry, pan(heartbeat(0.85), 0.0), int((t0 + beat * e8) * SR))
        for k, a in ((0, 0.8), (2, 0.35), (3, 0.6), (5, 0.4)):
            add_wrap(dry, pan(war_drum(a), -0.2 + 0.4 * (k % 2)), int((t0 + k * e8) * SR))
        bass = pluck(mtof(root), 1.8, bright=0.35, amp=0.5)
        add_wrap(dry, pan(bass, -0.1), int(t0 * SR))
        r, third, fifth = tones
        arp = [r, fifth, r + 12, third + 12, r + 12, fifth]
        for k, m in enumerate(arp):
            s = pluck(mtof(m), 1.4, bright=0.75, amp=0.32 * (1.0 if k in (0, 3) else 0.8))
            add_wrap(dry, pan(s, -0.35 + 0.1 * (k % 3)), int((t0 + k * e8 + rng.normal(0, 0.004)) * SR))
        pos = 0
        for m, d in BOSS_MELODY[b]:
            if m is not None:
                s = recorder(TENSE_NOTE.get(m, m), d * e8 * 0.94, amp=0.2)
                add_wrap(dry, pan(s, 0.25), int((t0 + pos * e8) * SR))
                s2 = recorder(TENSE_NOTE.get(m, m) - 12, d * e8 * 0.94, amp=0.08)   # darker double
                add_wrap(dry, pan(s2, -0.2), int((t0 + pos * e8) * SR))
            pos += d
    wet = circ_convolve(dry, reverb_ir(2.0, 2.0, 11, bright=4500))
    mix = 0.85 * dry + 0.4 * wet
    mix = np.stack([fft_filter(c, lo=30, hi=10000, slope=1) for c in mix])
    return normalize(np.tanh(1.2 * mix / np.abs(mix).max()), -1.0)


if __name__ == "__main__":
    import sys
    if sys.argv[1:] == ["tension"]:
        write_ogg("campfire_tension", make_music(tense=True))
        sys.exit()
    if sys.argv[1:] == ["boss"]:
        write_ogg("boss_theme", make_boss_music())
        sys.exit()
    if len(sys.argv) > 1:  # e.g. `make_audio.py button` rebuilds just that effect
        write_sfx(sys.argv[1:])
        sys.exit()
    write_ogg("fire_crackle", make_fire())
    write_ogg("crickets", make_crickets(), q=5)
    write_ogg("campfire_lullaby", make_music())
    write_ogg("campfire_tension", make_music(tense=True))
    write_ogg("boss_theme", make_boss_music())
    write_sfx()
