"""Musique de départ en mission (DEC-145) : tambours de guerre en boucle, synthétisés (aucun crédit ElevenLabs).
Sortie : game/assets/audio/mus_tambours.wav (mono, 22 050 Hz, 16 bits, 16 s en boucle à 120 BPM).
Usage : python3 tools/synth_tambours.py"""
import numpy as np, wave, os

SR = 22050
BPM = 120
BEAT = 60 / BPM
BARS = 8
N = int(SR * BEAT * 4 * BARS)
rng = np.random.default_rng(7)
out = np.zeros(N)


def env(n, decay):
    t = np.arange(n) / SR
    return np.exp(-t / decay)


def gros_tambour(gain=1.0):
    n = int(SR * 0.9)
    t = np.arange(n) / SR
    f = 45 + 55 * np.exp(-t / 0.06)
    phase = 2 * np.pi * np.cumsum(f) / SR
    s = np.sin(phase) * env(n, 0.38) + 0.35 * np.sin(phase * 1.5) * env(n, 0.15)
    s += 0.25 * rng.standard_normal(n) * env(n, 0.012)
    return np.tanh(1.8 * s) * gain


def tom(f0=130, gain=0.6):
    n = int(SR * 0.45)
    t = np.arange(n) / SR
    f = f0 * (0.7 + 0.3 * np.exp(-t / 0.05))
    s = np.sin(2 * np.pi * np.cumsum(f) / SR) * env(n, 0.18)
    s += 0.2 * rng.standard_normal(n) * env(n, 0.01)
    return np.tanh(1.5 * s) * gain


def caisse(gain=0.45):
    n = int(SR * 0.3)
    b = rng.standard_normal(n)
    b = b - np.concatenate([[0], b[:-1]]) * 0.6   # un peu plus brillant
    s = b * env(n, 0.08) + 0.5 * np.sin(2 * np.pi * 190 * np.arange(n) / SR) * env(n, 0.05)
    return s * gain


def poser(s, temps):
    i = int(temps * SR) % N
    k = min(len(s), N - i)
    out[i:i + k] += s[:k]
    if k < len(s):
        out[:len(s) - k] += s[k:]


GT, CC = gros_tambour(), caisse()
for bar in range(BARS):
    b0 = bar * 4 * BEAT
    for q in [0, 1.5, 2, 3.5] if bar % 2 else [0, 0.75, 2, 2.75]:
        poser(GT, b0 + q * BEAT)
    for q in [1, 3]:
        poser(CC, b0 + q * BEAT)
    if bar % 2 == 1:   # roulement de toms à la fin des mesures paires
        for i, f in enumerate([180, 160, 140, 120, 110, 95, 85, 75]):
            poser(tom(f, 0.45 + 0.04 * i), b0 + 3 * BEAT + i * BEAT / 8)
    else:
        for q in [0.5, 2.5]:
            poser(tom(110, 0.4), b0 + q * BEAT)
# bourdon grave saturé (quinte), qui monte en intensité sur la boucle
t = np.arange(N) / SR
monte = 0.55 + 0.45 * (0.5 - 0.5 * np.cos(2 * np.pi * t / (N / SR)))
saw = lambda f: 2 * ((t * f) % 1.0) - 1
drone = (saw(55) + 0.6 * saw(82.5) + 0.3 * saw(110.3)) * (0.75 + 0.25 * np.sin(2 * np.pi * t * 2))
k = int(SR / 600)   # passe-bas grossier (moyenne glissante)
drone = np.convolve(drone, np.ones(k) / k, mode="same")
out += 0.16 * np.tanh(2.2 * drone) * monte
out = np.tanh(1.2 * out)
out /= np.max(np.abs(out)) / 0.92
dest = os.path.join(os.path.dirname(__file__), "..", "game", "assets", "audio", "mus_tambours.wav")
with wave.open(dest, "wb") as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes((out * 32767).astype(np.int16).tobytes())
print("écrit", os.path.normpath(dest), f"{N / SR:.1f} s")
