#!/usr/bin/env python3
"""Dev tool: synthesises every placeholder sound effect, ambience bed and music loop
into assets/audio/ (16-bit mono WAV, 22.05 kHz). Pure standard library.
Run from the project root:  python3 tools/gen_audio.py  [names...]
Music uses the Phrygian-dominant (Hijaz) scale with plucked strings (Karplus-Strong),
drones, frame drums and a breathy ney-like flute."""

import array
import math
import os
import random
import sys
import wave

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
TAU = math.pi * 2.0


# --- basic building blocks ---------------------------------------------------------

def zeros(dur):
    return [0.0] * int(dur * SR)


def mix(dst, src, offset=0.0, gain=1.0):
    o = int(offset * SR)
    n = min(len(src), len(dst) - o)
    for i in range(max(n, 0)):
        dst[o + i] += src[i] * gain
    return dst


def env_adsr(n, a, d, s, r, sustain_level=0.7):
    out = [0.0] * n
    a_n, d_n, r_n = int(a * SR), int(d * SR), int(r * SR)
    s_n = max(n - a_n - d_n - r_n, 0)
    i = 0
    for k in range(a_n):
        if i < n:
            out[i] = k / max(a_n, 1)
            i += 1
    for k in range(d_n):
        if i < n:
            out[i] = 1.0 - (1.0 - sustain_level) * k / max(d_n, 1)
            i += 1
    for _ in range(s_n):
        if i < n:
            out[i] = sustain_level
            i += 1
    for k in range(r_n):
        if i < n:
            out[i] = sustain_level * (1.0 - k / max(r_n, 1))
            i += 1
    return out


def env_exp(n, decay):
    k = math.exp(-1.0 / max(decay * SR, 1.0))
    out = [0.0] * n
    v = 1.0
    for i in range(n):
        out[i] = v
        v *= k
    return out


def apply(sig, env):
    return [s * e for s, e in zip(sig, env)]


def sine(freq, dur, amp=1.0, freq_end=None, vibrato=0.0, vib_rate=5.0, phase=0.0):
    n = int(dur * SR)
    out = [0.0] * n
    ph = phase
    for i in range(n):
        t = i / n
        f = freq if freq_end is None else freq + (freq_end - freq) * t
        if vibrato:
            f *= 1.0 + vibrato * math.sin(TAU * vib_rate * i / SR)
        ph += TAU * f / SR
        out[i] = math.sin(ph) * amp
    return out


def saw(freq, dur, amp=1.0, freq_end=None, vibrato=0.0, vib_rate=5.0):
    n = int(dur * SR)
    out = [0.0] * n
    ph = 0.0
    for i in range(n):
        t = i / n
        f = freq if freq_end is None else freq + (freq_end - freq) * t
        if vibrato:
            f *= 1.0 + vibrato * math.sin(TAU * vib_rate * i / SR)
        ph = (ph + f / SR) % 1.0
        out[i] = (ph * 2.0 - 1.0) * amp
    return out


def noise(dur, amp=1.0, seed=None):
    rng = random.Random(seed)
    return [rng.uniform(-1.0, 1.0) * amp for _ in range(int(dur * SR))]


def lowpass(sig, cutoff, cutoff_end=None):
    out = [0.0] * len(sig)
    y = 0.0
    n = len(sig)
    for i, x in enumerate(sig):
        c = cutoff if cutoff_end is None else cutoff + (cutoff_end - cutoff) * i / max(n, 1)
        a = 1.0 - math.exp(-TAU * c / SR)
        y += a * (x - y)
        out[i] = y
    return out


def highpass(sig, cutoff):
    lp = lowpass(sig, cutoff)
    return [x - l for x, l in zip(sig, lp)]


def bandpass(sig, freq, q=4.0, freq_end=None):
    """RBJ biquad band-pass (constant skirt gain)."""
    out = [0.0] * len(sig)
    x1 = x2 = y1 = y2 = 0.0
    n = len(sig)
    for i, x in enumerate(sig):
        f = freq if freq_end is None else freq + (freq_end - freq) * i / max(n, 1)
        w = TAU * min(f, SR * 0.45) / SR
        alpha = math.sin(w) / (2.0 * q)
        b0 = alpha
        a0 = 1.0 + alpha
        a1 = -2.0 * math.cos(w)
        a2 = 1.0 - alpha
        y = (b0 * x - b0 * x2 - a1 * y1 - a2 * y2) / a0
        x2, x1 = x1, x
        y2, y1 = y1, y
        out[i] = y
    return out


def karplus(freq, dur, decay=0.996, brightness=0.5, seed=1):
    rng = random.Random(seed)
    period = max(int(SR / freq), 2)
    buf = [rng.uniform(-1.0, 1.0) for _ in range(period)]
    n = int(dur * SR)
    out = [0.0] * n
    idx = 0
    last = 0.0
    for i in range(n):
        v = buf[idx]
        out[i] = v
        nxt = buf[(idx + 1) % period]
        avg = decay * (v * (1.0 - brightness) + nxt * brightness)
        buf[idx] = avg * 0.5 + last * 0.5 if brightness < 0.5 else avg
        last = v
        idx = (idx + 1) % period
    return out


def echo(sig, delay, feedback, mix_amt):
    """Feedback delay (cheap room / canyon echo). Same length as the input."""
    d = int(delay * SR)
    wet = [0.0] * len(sig)
    for i in range(d, len(sig)):
        wet[i] = sig[i - d] + wet[i - d] * feedback
    return [s + w * mix_amt for s, w in zip(sig, wet)]


def softclip(sig, drive=1.0):
    return [math.tanh(s * drive) for s in sig]


def normalize(sig, peak=0.9):
    m = max((abs(s) for s in sig), default=0.0)
    if m < 1e-9:
        return sig
    g = peak / m
    return [s * g for s in sig]


def fade(sig, fin=0.005, fout=0.02):
    n = len(sig)
    a, b = int(fin * SR), int(fout * SR)
    for i in range(min(a, n)):
        sig[i] *= i / a
    for i in range(min(b, n)):
        sig[n - 1 - i] *= i / b
    return sig


def loop_crossfade(sig, xf=1.0):
    """Makes a seamless loop by blending the tail into the head."""
    x = int(xf * SR)
    body = sig[:len(sig) - x]
    tail = sig[len(sig) - x:]
    for i in range(x):
        t = i / x
        body[i] = body[i] * t + tail[i] * (1.0 - t)
    return body


def write(name, sig, peak=0.9):
    os.makedirs(OUT, exist_ok=True)
    sig = normalize(sig, peak)
    data = array.array("h", (int(max(-1.0, min(1.0, s)) * 32767) for s in sig))
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print("wrote %s.wav (%.2f s)" % (name, len(sig) / SR))


# --- sound effects --------------------------------------------------------------------

def whoosh(dur, f0, f1, seed, amp=1.0):
    n = noise(dur, 1.0, seed)
    b = bandpass(n, f0, 1.4, f1)
    e = env_adsr(len(b), dur * 0.35, dur * 0.2, 0.6, dur * 0.45, 0.6)
    return apply(b, [x * amp for x in e])


def thump(freq, dur, amp=1.0, drop=0.5):
    s = sine(freq, dur, 1.0, freq * drop)
    return apply(s, [x * amp for x in env_exp(len(s), dur * 0.3)])


def sfx():
    out = {}
    out["whoosh_light"] = fade(whoosh(0.22, 600, 2400, 1))
    out["whoosh_light_2"] = fade(whoosh(0.2, 700, 2800, 2))
    out["whoosh_heavy"] = fade(mix(whoosh(0.42, 250, 1300, 3), whoosh(0.42, 120, 500, 4), 0, 0.6))
    hf = zeros(0.3)
    mix(hf, thump(110, 0.25, 1.0, 0.45))
    mix(hf, apply(lowpass(noise(0.12, 1.0, 5), 2500), env_exp(int(0.12 * SR), 0.03)), 0, 0.8)
    out["hit_flesh"] = fade(softclip(hf, 1.5))
    hf2 = zeros(0.3)
    mix(hf2, thump(95, 0.25, 1.0, 0.5))
    mix(hf2, apply(lowpass(noise(0.12, 1.0, 6), 3200), env_exp(int(0.12 * SR), 0.025)), 0, 0.8)
    out["hit_flesh_2"] = fade(softclip(hf2, 1.5))
    hh = zeros(0.6)
    mix(hh, thump(70, 0.5, 1.0, 0.4))
    mix(hh, apply(lowpass(noise(0.3, 1.0, 7), 1800), env_exp(int(0.3 * SR), 0.06)), 0, 0.9)
    mix(hh, apply(bandpass(noise(0.2, 1.0, 8), 3500, 6), env_exp(int(0.2 * SR), 0.02)), 0, 0.5)
    out["hit_heavy"] = fade(softclip(hh, 2.0))
    hs = zeros(0.35)
    mix(hs, apply(bandpass(noise(0.3, 1.0, 9), 1500, 3), env_exp(int(0.3 * SR), 0.04)))
    mix(hs, apply(sine(1250, 0.3), env_exp(int(0.3 * SR), 0.06)), 0, 0.4)
    mix(hs, thump(140, 0.2, 0.6))
    out["hit_stone"] = fade(hs)
    # Faience cracking: sharp crack + glassy partials.
    fc = zeros(0.6)
    mix(fc, apply(highpass(noise(0.08, 1.0, 10), 2500), env_exp(int(0.08 * SR), 0.012)))
    for f, a in ((2310, 0.5), (3470, 0.35), (4890, 0.25), (1630, 0.3)):
        mix(fc, apply(sine(f, 0.55), env_exp(int(0.55 * SR), 0.12)), 0.005, a)
    mix(fc, thump(160, 0.2, 0.7))
    out["faience_crack"] = fade(fc)
    out["dodge_roll"] = fade(mix(whoosh(0.3, 300, 900, 11, 0.8), apply(lowpass(noise(0.3, 1.0, 12), 600), env_adsr(int(0.3 * SR), 0.05, 0.1, 0.5, 0.15)), 0, 0.6))
    for i in range(3):
        st = apply(lowpass(noise(0.12, 1.0, 20 + i), 700 + i * 120), env_exp(int(0.12 * SR), 0.03))
        out["step_sand_%d" % (i + 1)] = fade(st)
        ss = apply(bandpass(noise(0.09, 1.0, 30 + i), 900 + i * 150, 2), env_exp(int(0.09 * SR), 0.018))
        mix(ss, thump(120 + i * 10, 0.08, 0.5))
        out["step_stone_%d" % (i + 1)] = fade(ss)
    cr = zeros(0.6)
    for k, f in enumerate((880, 1108, 1318, 1760)):
        mix(cr, apply(sine(f, 0.4), env_exp(int(0.4 * SR), 0.1)), k * 0.06, 0.6)
    out["charge_ready"] = fade(cr)
    rc = zeros(0.6)
    mix(rc, whoosh(0.4, 500, 3000, 13, 0.8))
    mix(rc, apply(sine(440, 0.5, 1.0, 1320), env_adsr(int(0.5 * SR), 0.02, 0.1, 0.6, 0.3)), 0, 0.5)
    mix(rc, apply(sine(660, 0.5, 1.0, 1980), env_adsr(int(0.5 * SR), 0.02, 0.1, 0.6, 0.3)), 0, 0.3)
    out["ra_cast"] = fade(rc)
    ri = zeros(0.7)
    mix(ri, thump(90, 0.4, 0.9))
    mix(ri, apply(lowpass(noise(0.4, 1.0, 14), 4000, 800), env_exp(int(0.4 * SR), 0.08)), 0, 0.7)
    for k in range(6):
        mix(ri, apply(sine(2000 + k * 450, 0.25), env_exp(int(0.25 * SR), 0.05)), 0.02 + k * 0.03, 0.15)
    out["ra_impact"] = fade(softclip(ri, 1.3))
    out["ui_deny"] = fade(mix(apply(saw(110, 0.18, 0.5), env_adsr(int(0.18 * SR), 0.005, 0.05, 0.6, 0.05)), apply(saw(92, 0.18, 0.5), env_adsr(int(0.18 * SR), 0.005, 0.05, 0.6, 0.05)), 0.0, 1.0))
    ah = zeros(1.6)
    for k, f in enumerate((523, 659, 784, 1046, 1318)):
        mix(ah, apply(sine(f, 1.4, 1.0, None, 0.004, 6.0), env_adsr(int(1.4 * SR), 0.02, 0.3, 0.4, 1.0, 0.4)), k * 0.04, 0.4)
    mix(ah, apply(highpass(noise(1.0, 1.0, 15), 6000), env_adsr(int(1.0 * SR), 0.3, 0.2, 0.3, 0.5)), 0, 0.1)
    out["ankh_heal"] = fade(ah)
    out["heal_start"] = fade(apply(sine(392, 0.5, 1.0, 523), env_adsr(int(0.5 * SR), 0.2, 0.1, 0.5, 0.2)))
    for i, base in enumerate((1568, 1760, 2093)):
        kc = apply(sine(base, 0.6), env_exp(int(0.6 * SR), 0.12))
        mix(kc, apply(sine(base * 2.01, 0.6), env_exp(int(0.6 * SR), 0.06)), 0, 0.3)
        out["ka_chime_%d" % (i + 1)] = fade(kc)
    hr = zeros(1.4)
    mix(hr, thump(60, 0.25, 1.0, 0.7))
    mix(hr, thump(55, 0.25, 0.8, 0.7), 0.28)
    for k, f in enumerate((659, 880, 1108)):
        mix(hr, apply(sine(f, 0.8), env_exp(int(0.8 * SR), 0.25)), 0.55 + k * 0.08, 0.4)
    out["heart_recover"] = fade(hr)
    lu = zeros(1.4)
    for k, f in enumerate((392, 494, 587, 784, 988)):
        mix(lu, apply(sine(f, 0.7), env_exp(int(0.7 * SR), 0.2)), k * 0.09, 0.5)
        mix(lu, apply(sine(f * 2, 0.5), env_exp(int(0.5 * SR), 0.1)), k * 0.09, 0.15)
    out["level_up"] = fade(lu)
    ar = zeros(2.5)
    mix(ar, apply(saw(73.4, 2.4, 0.4), env_adsr(int(2.4 * SR), 0.6, 0.4, 0.6, 1.2)), 0, 0.5)
    ar = lowpass(ar, 500)
    for k, f in enumerate((587, 880, 1174)):
        mix(ar, apply(sine(f, 1.6), env_exp(int(1.6 * SR), 0.5)), 0.4 + k * 0.25, 0.35)
    out["altar_rest"] = fade(ar)
    ak = zeros(1.2)
    mix(ak, whoosh(0.6, 200, 1500, 16))
    mix(ak, apply(lowpass(noise(1.0, 1.0, 17), 1200), env_adsr(int(1.0 * SR), 0.05, 0.2, 0.4, 0.6)), 0.1, 0.5)
    mix(ak, apply(sine(784, 1.0), env_exp(int(1.0 * SR), 0.3)), 0.25, 0.4)
    out["altar_kindle"] = fade(ak)
    dd = zeros(3.5)
    mix(dd, apply(saw(55, 3.4, 0.5), env_adsr(int(3.4 * SR), 0.3, 0.5, 0.7, 2.0)))
    mix(dd, apply(saw(58.3, 3.4, 0.5), env_adsr(int(3.4 * SR), 0.3, 0.5, 0.7, 2.0)))
    dd = lowpass(dd, 400, 150)
    for k, t in enumerate((0.2, 0.9, 1.9)):
        mix(dd, thump(55, 0.3, 0.9 - k * 0.2, 0.7), t)
    out["death_drone"] = fade(dd)
    gl = zeros(0.5)
    mix(gl, apply(sine(3520, 0.45, 1.0, None, 0.01, 18.0), env_exp(int(0.45 * SR), 0.09)))
    mix(gl, apply(sine(5280, 0.3), env_exp(int(0.3 * SR), 0.05)), 0, 0.4)
    out["glint"] = fade(gl)
    wl = lowpass(apply(saw(98, 0.6, 1.0, 92), env_adsr(int(0.6 * SR), 0.04, 0.1, 0.7, 0.3)), 900)
    mix(wl, lowpass(apply(saw(147, 0.6, 0.6, 139), env_adsr(int(0.6 * SR), 0.04, 0.1, 0.7, 0.3)), 900))
    out["warn_low"] = fade(wl)
    pb = zeros(0.9)
    mix(pb, apply(highpass(noise(0.1, 1.0, 18), 1500), env_exp(int(0.1 * SR), 0.02)))
    for f in (523, 785, 1180):
        mix(pb, apply(sine(f, 0.8), env_exp(int(0.8 * SR), 0.2)), 0, 0.3)
    mix(pb, thump(80, 0.4, 0.9))
    out["poise_break"] = fade(softclip(pb, 1.4))
    ed = apply(lowpass(noise(1.0, 1.0, 19), 2500, 300), env_adsr(int(1.0 * SR), 0.01, 0.2, 0.5, 0.7))
    mix(ed, thump(90, 0.4, 0.6))
    out["enemy_death"] = fade(ed)
    # Mummy groan: low saw through vowel formants.
    mg_src = saw(85, 1.3, 1.0, 70, 0.02, 4.0)
    mg = zeros(1.3)
    for f, q, a in ((500, 6, 1.0), (850, 8, 0.6), (2400, 10, 0.2)):
        mix(mg, bandpass(mg_src, f, q), 0, a)
    mix(mg, apply(lowpass(noise(1.3, 1.0, 21), 800), env_adsr(int(1.3 * SR), 0.2, 0.3, 0.5, 0.6)), 0, 0.3)
    out["mummy_groan"] = fade(apply(mg, env_adsr(len(mg), 0.25, 0.3, 0.7, 0.6)))
    sc = zeros(0.5)
    rng = random.Random(22)
    t = 0.0
    while t < 0.45:
        click = apply(bandpass(noise(0.015, 1.0, rng.randint(0, 999)), rng.uniform(2500, 4500), 5), env_exp(int(0.015 * SR), 0.003))
        mix(sc, click, t, rng.uniform(0.5, 1.0))
        t += rng.uniform(0.015, 0.04)
    out["scarab_chitter"] = fade(sc)
    jg_src = saw(75, 0.9, 1.0, 95, 0.05, 23.0)
    jg = zeros(0.9)
    mix(jg, bandpass(jg_src, 400, 4))
    mix(jg, bandpass(noise(0.9, 1.0, 23), 700, 3), 0, 0.4)
    out["jackal_growl"] = fade(softclip(apply(jg, env_adsr(len(jg), 0.08, 0.2, 0.7, 0.4)), 2.0))
    out["cobra_hiss"] = fade(apply(highpass(noise(1.0, 1.0, 24), 3500), env_adsr(int(1.0 * SR), 0.15, 0.2, 0.7, 0.4)))
    sp = zeros(0.4)
    mix(sp, apply(bandpass(noise(0.25, 1.0, 25), 1800, 2, 600), env_exp(int(0.25 * SR), 0.05)))
    mix(sp, thump(200, 0.15, 0.4))
    out["spit"] = fade(sp)
    pz = zeros(1.0)
    rng2 = random.Random(26)
    for _ in range(60):
        mix(pz, apply(highpass(noise(0.01, 1.0, rng2.randint(0, 9999)), 2000), env_exp(int(0.01 * SR), 0.003)), rng2.uniform(0, 0.95), rng2.uniform(0.2, 0.7))
    mix(pz, apply(highpass(noise(1.0, 1.0, 27), 4000), env_adsr(int(1.0 * SR), 0.05, 0.2, 0.3, 0.5)), 0, 0.2)
    out["puddle_sizzle"] = fade(pz)
    # Ammit roar: layered low saws, noise and formants with tremolo.
    rd = 2.4
    src = zeros(rd)
    mix(src, saw(62, rd, 1.0, 48, 0.03, 7.0))
    mix(src, saw(93, rd, 0.6, 70, 0.025, 6.0))
    mix(src, noise(rd, 0.6, 28))
    roar = zeros(rd)
    for f, q, a in ((350, 3, 1.0), (700, 4, 0.7), (1400, 5, 0.35), (2800, 6, 0.15)):
        mix(roar, bandpass(src, f, q, f * 0.75), 0, a)
    mix(roar, apply(sine(45, rd, 1.0, 38), env_adsr(int(rd * SR), 0.2, 0.4, 0.7, 1.0)), 0, 0.6)
    trem = [0.8 + 0.2 * math.sin(TAU * 11.0 * i / SR) for i in range(len(roar))]
    roar = apply(apply(roar, trem), env_adsr(len(roar), 0.15, 0.3, 0.8, 1.0))
    out["ammit_roar"] = fade(softclip(roar, 2.2))
    sn = zeros(0.5)
    mix(sn, thump(85, 0.3, 1.0))
    mix(sn, apply(bandpass(noise(0.08, 1.0, 29), 1200, 2), env_exp(int(0.08 * SR), 0.015)), 0, 0.9)
    mix(sn, apply(bandpass(noise(0.08, 1.0, 30), 900, 2), env_exp(int(0.08 * SR), 0.015)), 0.09, 0.9)
    mix(sn, thump(70, 0.3, 0.9), 0.09)
    out["ammit_snap"] = fade(softclip(sn, 1.8))
    sw = zeros(1.6)
    mix(sw, apply(sine(70, 1.4, 1.0, 30), env_exp(int(1.4 * SR), 0.4)))
    mix(sw, apply(lowpass(noise(1.5, 1.0, 31), 900, 150), env_adsr(int(1.5 * SR), 0.01, 0.3, 0.5, 1.0)), 0, 0.8)
    out["shockwave"] = fade(softclip(sw, 1.6))
    bu = apply(lowpass(noise(2.0, 1.0, 32), 250), env_adsr(int(2.0 * SR), 0.3, 0.3, 0.8, 0.8))
    mix(bu, apply(sine(40, 2.0, 1.0, 50), env_adsr(int(2.0 * SR), 0.3, 0.3, 0.8, 0.8)), 0, 0.5)
    out["burrow"] = fade(bu)
    er = zeros(1.6)
    mix(er, apply(sine(60, 1.2, 1.0, 28), env_exp(int(1.2 * SR), 0.35)))
    mix(er, apply(lowpass(noise(1.5, 1.0, 33), 3000, 200), env_exp(int(1.5 * SR), 0.4)), 0, 0.9)
    out["erupt"] = fade(softclip(er, 2.0))
    gg = zeros(2.4)
    rng3 = random.Random(34)
    grind = lowpass(noise(2.4, 1.0, 35), 600)
    am = [0.6 + 0.4 * math.sin(TAU * 7.3 * i / SR) * math.sin(TAU * 1.7 * i / SR) for i in range(len(grind))]
    mix(gg, apply(apply(grind, am), env_adsr(len(grind), 0.2, 0.2, 0.8, 0.6)))
    for _ in range(12):
        mix(gg, thump(rng3.uniform(80, 140), 0.12, 0.3), rng3.uniform(0, 2.2))
    out["gate_grind"] = fade(gg)
    lc = zeros(0.5)
    mix(lc, thump(150, 0.15, 1.0))
    mix(lc, apply(bandpass(noise(0.05, 1.0, 36), 1800, 3), env_exp(int(0.05 * SR), 0.01)), 0, 0.8)
    mix(lc, thump(110, 0.25, 0.8), 0.12)
    out["lever_clunk"] = fade(lc)
    out["spike_click"] = fade(mix(apply(bandpass(noise(0.03, 1.0, 37), 3000, 4), env_exp(int(0.03 * SR), 0.006)), thump(300, 0.06, 0.4)))
    so = zeros(0.6)
    mix(so, apply(highpass(noise(0.4, 1.0, 38), 3000), env_exp(int(0.4 * SR), 0.08)))
    for f in (3100, 4400, 5900):
        mix(so, apply(sine(f, 0.5), env_exp(int(0.5 * SR), 0.1)), 0, 0.2)
    mix(so, thump(180, 0.15, 0.6))
    out["spikes_out"] = fade(so)
    sv = apply(bandpass(noise(2.5, 1.0, 39), 1500, 1.0, 600), env_adsr(int(2.5 * SR), 0.6, 0.3, 0.6, 1.2))
    out["sand_veil"] = fade(sv)
    rw = zeros(2.0)
    for k, f in enumerate((587, 740, 880, 1174, 1480)):
        mix(rw, apply(sine(f, 1.5, 1.0, None, 0.004), env_exp(int(1.5 * SR), 0.45)), k * 0.07, 0.4)
    mix(rw, apply(highpass(noise(1.2, 1.0, 40), 7000), env_adsr(int(1.2 * SR), 0.1, 0.3, 0.3, 0.7)), 0, 0.1)
    out["reward"] = fade(rw)
    vc = zeros(5.0)
    chords = ((293.7, 370, 440), (311.1, 392, 466.2), (293.7, 370, 440, 587.3))
    for k, ch in enumerate(chords):
        for f in ch:
            tone = mix(saw(f, 1.8, 0.4, None, 0.004), sine(f * 2, 1.8, 0.3))
            mix(vc, lowpass(apply(tone, env_adsr(len(tone), 0.08, 0.3, 0.6, 0.9)), 1800), k * 1.4, 0.35)
    mix(vc, thump(60, 0.6, 1.0), 0.0)
    mix(vc, thump(60, 0.6, 1.0), 2.8)
    out["victory"] = fade(vc)
    out["ui_click"] = fade(mix(apply(sine(1400, 0.06), env_exp(int(0.06 * SR), 0.012)), apply(highpass(noise(0.02, 1.0, 41), 3000), env_exp(int(0.02 * SR), 0.004)), 0, 0.5))
    out["ui_move"] = fade(apply(sine(900, 0.05), env_exp(int(0.05 * SR), 0.01)))
    return out


# --- music -------------------------------------------------------------------------

HIJAZ = [0, 1, 4, 5, 7, 8, 10]  # D Phrygian dominant intervals


def note_freq(root, degree, octave=0):
    o, d = divmod(degree, 7)
    return root * (2.0 ** ((HIJAZ[d] + 12 * (o + octave)) / 12.0))


def drum_low(dur=0.4, amp=1.0, seed=0):
    d = zeros(dur)
    mix(d, thump(70, dur, amp, 0.55))
    mix(d, apply(lowpass(noise(dur, 1.0, seed), 400), env_exp(int(dur * SR), 0.05)), 0, 0.3 * amp)
    return d


def drum_slap(dur=0.15, amp=1.0, seed=0):
    return apply(bandpass(noise(dur, 1.0, seed), 1800, 1.5), [e * amp for e in env_exp(int(dur * SR), 0.025)])


def flute(freq, dur, amp=0.4, seed=0):
    t = sine(freq, dur, 1.0, None, 0.012, 5.2)
    mix(t, sine(freq * 2.0, dur, 0.18))
    mix(t, bandpass(noise(dur, 1.0, seed), freq * 1.5, 3), 0, 0.25)
    return apply(t, [e * amp for e in env_adsr(len(t), 0.12, 0.2, 0.75, min(0.3, dur * 0.4))])


def drone(root, dur, amp=0.3, cutoff=350):
    d = zeros(dur)
    mix(d, saw(root, dur, 1.0, None, 0.002, 0.2))
    mix(d, saw(root * 1.5, dur, 0.6, None, 0.003, 0.17))
    mix(d, saw(root * 1.003, dur, 0.8))
    lfo_cut = lowpass(d, cutoff)
    return [s * amp for s in lfo_cut]


def music_courtyard():
    bpm = 84.0
    beat = 60.0 / bpm
    bars = 24
    dur = bars * 4 * beat
    root = 146.83  # D3
    out = zeros(dur + 2.0)
    mix(out, drone(root / 2, dur + 2.0, 0.22, 300))
    rng = random.Random(51)
    pattern = [0, 2, 4, 2, 5, 4, 2, 1]
    for bar in range(bars):
        shift = [0, 0, 3, 0, 4, 3, 1, 0][bar % 8]
        for k in range(8):
            deg = pattern[k] + shift
            f = note_freq(root, deg, 0 if k % 2 == 0 else 1)
            pl = karplus(f, 1.6, 0.996, 0.5, seed=bar * 8 + k)
            mix(out, apply(pl, env_exp(len(pl), 0.6)), (bar * 4 + k * 0.5) * beat, 0.32)
        if bar % 2 == 0:
            mix(out, drum_low(0.5, 0.8, bar), bar * 4 * beat)
            mix(out, drum_slap(0.15, 0.5, bar), (bar * 4 + 1.5) * beat)
            mix(out, drum_low(0.4, 0.5, bar + 100), (bar * 4 + 2.5) * beat)
        if bar >= 8 and bar % 4 in (0, 1):
            melody = [4, 5, 4, 2, 1, 2, 0] if bar % 8 < 4 else [7, 8, 7, 5, 4, 5, 4]
            t = bar * 4 * beat
            for i, deg in enumerate(melody):
                d = beat * (1.5 if i % 3 == 0 else 0.75)
                mix(out, flute(note_freq(root, deg, 1), d * 1.1, 0.22, rng.randint(0, 999)), t)
                t += d
    return loop_crossfade(echo(out, beat * 0.75, 0.3, 0.25)[:int((dur + 1.0) * SR)], 1.0)


def music_tomb():
    dur = 64.0
    root = 73.42  # D2
    out = zeros(dur + 2.0)
    mix(out, drone(root, dur + 2.0, 0.3, 220))
    mix(out, apply(sine(root * 0.5, dur + 2.0, 0.4), [0.6 + 0.4 * math.sin(TAU * 0.05 * i / SR) for i in range(int((dur + 2.0) * SR))]))
    rng = random.Random(61)
    t = 1.0
    while t < dur:
        deg = rng.choice([0, 1, 4, 5, 7, 8])
        f = note_freq(root * 2, deg, rng.choice([0, 1, 1, 2]))
        pl = karplus(f, 3.0, 0.997, 0.4, seed=int(t * 10))
        mix(out, apply(pl, env_exp(len(pl), 1.2)), t, 0.25)
        t += rng.choice([1.5, 2.0, 3.0, 4.5])
    for k in range(8):
        mix(out, drum_low(1.0, 0.5, k), k * 8.0 + 0.5)
    return loop_crossfade(echo(out, 0.43, 0.45, 0.4)[:int((dur + 1.0) * SR)], 1.0)


def music_boss():
    bpm = 138.0
    beat = 60.0 / bpm
    bars = 28
    dur = bars * 4 * beat
    root = 73.42
    out = zeros(dur + 2.0)
    mix(out, drone(root, dur + 2.0, 0.25, 500))
    ost = [0, 1, 0, 4, 0, 1, 5, 4]
    for bar in range(bars):
        b0 = bar * 4 * beat
        # Frame drums: driving 3+3+2 pattern.
        for step, amp in ((0, 1.0), (1.5, 0.8), (3, 0.9)):
            mix(out, drum_low(0.35, amp, bar * 3 + int(step)), b0 + step * beat)
        for s in range(8):
            if s % 2 == 1:
                mix(out, drum_slap(0.1, 0.45, bar * 8 + s), b0 + s * 0.5 * beat)
        # Ostinato.
        lift = 4 if bar % 8 >= 6 else 0
        for k in range(8):
            f = note_freq(root * 2, ost[k] + lift, 0)
            pl = karplus(f, 0.5, 0.993, 0.6, seed=bar * 16 + k)
            mix(out, pl, b0 + k * 0.5 * beat, 0.3)
        # Brass-like stabs on strong bars.
        if bar % 4 == 0 and bar >= 4:
            for f in (note_freq(root * 2, 0, 0), note_freq(root * 2, 4, 0), note_freq(root * 2, 1, 1)):
                st = lowpass(apply(saw(f, beat * 1.8, 0.5, None, 0.004), env_adsr(int(beat * 1.8 * SR), 0.03, 0.2, 0.6, 0.4)), 1400)
                mix(out, st, b0, 0.35)
        if bar >= 12 and bar % 2 == 0:
            mel = [7, 8, 7, 5, 4, 5, 8, 7]
            for k, deg in enumerate(mel):
                mix(out, flute(note_freq(root * 4, deg, 0), beat * 0.48, 0.18, bar * 10 + k), b0 + k * 0.5 * beat)
    return loop_crossfade(softclip(out[:int((dur + 1.0) * SR)], 1.2), 1.0)


def music_title():
    dur = 48.0
    root = 146.83
    out = zeros(dur + 2.0)
    mix(out, drone(root / 2, dur + 2.0, 0.2, 260))
    seq = [0, 4, 7, 8, 7, 4, 5, 4, 1, 4, 0, 4]
    t = 0.5
    i = 0
    while t < dur - 1.0:
        f = note_freq(root, seq[i % len(seq)], 0)
        pl = karplus(f, 2.5, 0.997, 0.45, seed=i)
        mix(out, apply(pl, env_exp(len(pl), 1.0)), t, 0.3)
        t += 0.75 if i % 4 != 3 else 1.5
        i += 1
    for k in range(4):
        mel = [4, 5, 4, 2, 1, 0]
        tt = 12.0 * k + 4.0
        for j, deg in enumerate(mel):
            mix(out, flute(note_freq(root, deg, 1), 1.2, 0.18, k * 10 + j), tt + j * 1.0)
    return loop_crossfade(echo(out, 0.5, 0.35, 0.3)[:int((dur + 1.0) * SR)], 1.0)


def amb_wind():
    dur = 30.0
    n = noise(dur + 1.0, 1.0, 71)
    gust = [0.5 + 0.5 * math.sin(TAU * 0.07 * i / SR) * math.sin(TAU * 0.023 * i / SR + 1.0) for i in range(len(n))]
    w = bandpass(n, 500, 0.7, 900)
    w = apply(w, [0.35 + 0.65 * g * g for g in gust])
    hiss = apply(highpass(noise(dur + 1.0, 1.0, 72), 4000), [0.15 * g for g in gust])
    return loop_crossfade(mix(w, hiss), 1.0)


def amb_tomb():
    dur = 30.0
    out = zeros(dur + 1.0)
    mix(out, lowpass(noise(dur + 1.0, 1.0, 81), 120), 0, 0.8)
    rng = random.Random(82)
    t = 0.5
    while t < dur:
        f = rng.uniform(1800, 3200)
        drip = apply(sine(f, 0.3, 1.0, f * 0.7), env_exp(int(0.3 * SR), 0.04))
        mix(out, echo(drip, 0.18, 0.4, 0.5)[:int(0.9 * SR)], t, rng.uniform(0.1, 0.25))
        t += rng.uniform(1.5, 4.5)
    for k in range(4):
        wh = apply(bandpass(noise(2.5, 1.0, 83 + k), rng.uniform(500, 900), 4), env_adsr(int(2.5 * SR), 1.0, 0.3, 0.5, 1.0))
        mix(out, wh, 3.0 + k * 7.0, 0.15)
    return loop_crossfade(out, 1.0)


def main():
    wanted = set(sys.argv[1:])
    effects = sfx()
    for name, sig in effects.items():
        if not wanted or name.rsplit("_", 1)[0] in wanted or name in wanted:
            write(name, sig, 0.85)
    music = {"music_courtyard": music_courtyard, "music_tomb": music_tomb, "music_boss": music_boss,
             "music_title": music_title, "amb_wind": amb_wind, "amb_tomb": amb_tomb}
    for name, fn in music.items():
        if not wanted or name in wanted:
            write(name, fn(), 0.7)


if __name__ == "__main__":
    main()
