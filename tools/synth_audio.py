# Génère des sons et musiques basiques (WAV 16 bits mono) dans game/assets/audio/synth/.
# Aucune dépendance autre que numpy. Usage : python3 tools/synth_audio.py
import wave, numpy as np, os
SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "game", "assets", "audio", "synth")
rng = np.random.default_rng(7)


def t(d):
    return np.arange(int(SR * d)) / SR


def noise(d):
    return rng.standard_normal(int(SR * d))


def lp(x, k):
    """filtre passe-bas par moyenne glissante (k échantillons)"""
    k = max(1, int(k))
    return np.convolve(x, np.ones(k) / k, mode="same")


def hp(x, k):
    return x - lp(x, k)


def env(d, a=0.005, tau=0.1):
    tt = t(d)
    return np.minimum(1, tt / max(a, 1e-4)) * np.exp(-tt / tau)


def norm(x, g=0.85):
    m = np.max(np.abs(x)) or 1.0
    return x / m * g


def save(nom, x):
    x = np.clip(x, -1, 1)
    with wave.open(os.path.join(OUT, nom + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())


def loopable(x, fondu=0.4):
    n = int(SR * fondu)
    y = x.copy()
    y[:n] = x[:n] * np.linspace(0, 1, n) + x[-n:] * np.linspace(1, 0, n)
    return y[:-n]


def tir():
    d = 0.18
    return norm(lp(noise(d), 3) * env(d, 0.001, 0.03) * 2 + np.sin(2 * np.pi * 150 * t(d)) * env(d, 0.001, 0.04))


def mitrailleuse():
    x = np.zeros(int(SR * 0.7))
    for k in range(4):
        s = tir()
        i = int(k * 0.15 * SR)
        x[i:i + len(s)] += s
    return norm(x)


def canon():
    d = 1.0
    tt = t(d)
    return norm(lp(noise(d), 18) * env(d, 0.002, 0.25) * 2 + np.sin(2 * np.pi * (80 - 40 * tt) * tt) * env(d, 0.002, 0.3))


def explosion():
    d = 2.0
    return norm(lp(noise(d), 40) * env(d, 0.003, 0.55) * 2 + lp(noise(d), 120) * env(d, 0.1, 0.9))


def impact():
    d = 0.5
    tt = t(d)
    m = sum(np.sin(2 * np.pi * f * tt) * a for f, a in [(820, 1), (1310, .7), (2170, .5), (3050, .3)])
    return norm(m * env(d, 0.001, 0.12) + hp(noise(d), 4) * env(d, 0.001, 0.02))


def clic():
    d = 0.06
    return norm(np.sin(2 * np.pi * 1400 * t(d)) * env(d, 0.001, 0.012))


def atelier():
    x = np.zeros(int(SR * 1.2))
    for k, f in enumerate([700, 560, 700]):
        s = impact()[: int(SR * 0.3)] * 0.9
        i = int(k * 0.35 * SR)
        x[i:i + len(s)] += s
    return norm(x)


def radio():
    d = 0.8
    tt = t(d)
    x = hp(noise(d), 6) * 0.35 * (tt < 0.45) + np.sin(2 * np.pi * 1000 * tt) * ((tt > 0.5) & (tt < 0.62)) * 0.8
    return norm(x * np.minimum(1, (d - tt) / 0.1))


def depart_marche():
    d = 1.4
    tt = t(d)
    f = 35 + 45 * np.minimum(tt / 0.9, 1)
    ph = 2 * np.pi * np.cumsum(f) / SR
    x = (np.sign(np.sin(ph)) * 0.5 + np.sin(2 * ph)) * (0.6 + 0.4 * np.sin(2 * np.pi * 17 * tt))
    return norm(lp(x, 4) * np.minimum(1, tt / 0.1) * np.minimum(1, (d - tt) / 0.3))


def depart_convoi():
    d = 1.2
    tt = t(d)
    x = np.sin(2 * np.pi * 330 * tt) * (tt < 0.5) + np.sin(2 * np.pi * 440 * tt) * (tt >= 0.5)
    return norm(x * np.minimum(1, tt / 0.03) * np.minimum(1, (d - tt) / 0.25))


def hurlement():
    d = 3.0
    tt = t(d)
    f = 380 + 330 * np.sin(np.pi * np.minimum(tt / 2.4, 1)) * 0.9 + 6 * np.sin(2 * np.pi * 5.5 * tt)
    ph = 2 * np.pi * np.cumsum(f) / SR
    x = np.sin(ph) + 0.4 * np.sin(2 * ph) + 0.15 * np.sin(3 * ph)
    return norm(x * np.minimum(1, tt / 0.4) * np.minimum(1, (d - tt) / 0.7), 0.7)


def nuee():
    d = 2.5
    tt = t(d)
    x = lp(noise(d), 3) * (0.5 + 0.5 * np.sin(2 * np.pi * 85 * tt)) + np.sin(2 * np.pi * 55 * tt) * 0.8
    return norm(x * np.minimum(1, tt / 0.6) * np.minimum(1, (d - tt) / 0.8), 0.7)


def pompe():
    return norm(lp(noise(1.0), 5) * (0.6 + 0.4 * np.sin(2 * np.pi * 8 * t(1.0))))


def moteur(f0, dur=1.0, dur_rug=0.55):
    tt = t(dur)
    x = sum(np.sin(2 * np.pi * f0 * h * tt + h) / h for h in range(1, 7))
    x = x * (1 + dur_rug * np.sin(2 * np.pi * 7 * tt)) + lp(noise(dur), 6) * 0.35
    return norm(x, 0.6)


def vent(d=8.0, nuit=False):
    x = lp(noise(d), 40 if not nuit else 70)
    tt = t(d)
    x = x * (0.6 + 0.4 * np.sin(2 * np.pi * (1 / d) * 2 * tt))
    if nuit:
        for deb in [0.5, 2.4, 4.6, 6.2]:
            m = (tt > deb) & (tt < deb + 1.1)
            x = x + np.sin(2 * np.pi * 4300 * tt) * m * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 14 * tt))) * 0.025
    return loopable(norm(x, 0.35 if not nuit else 0.3))


def musique(notes_bass, accords, bpm, mesures, grave=True, perc=True):
    pas = 60.0 / bpm
    d = mesures * 4 * pas
    tt = t(d)
    x = np.zeros_like(tt)
    for m in range(mesures):
        a = accords[m % len(accords)]
        i0, i1 = int(m * 4 * pas * SR), int((m + 1) * 4 * pas * SR)
        seg = tt[i0:i1] - tt[i0]
        for f in a:
            x[i0:i1] += (np.sin(2 * np.pi * f * seg) + 0.4 * np.sin(2 * np.pi * 2 * f * seg)) * 0.12 * np.minimum(1, seg / 0.4) * np.minimum(1, (seg[-1] - seg) / 0.4)
        for b in range(8):
            fb = notes_bass[(m * 8 + b) % len(notes_bass)]
            j0 = int((m * 4 + b * 0.5) * pas * SR)
            n = int(0.45 * pas * SR)
            ss = np.arange(n) / SR
            x[j0:j0 + n] += (np.sign(np.sin(2 * np.pi * fb * ss)) * 0.5 + np.sin(2 * np.pi * fb * ss)) * 0.22 * np.exp(-ss / 0.25)[:len(x[j0:j0 + n])]
        if perc:
            for b in range(4):
                j0 = int((m * 4 + b) * pas * SR)
                n = int(0.12 * SR)
                s = lp(noise(0.12), 4 if b % 2 == 0 else 1) * np.exp(-np.arange(n) / SR / (0.05 if b % 2 == 0 else 0.02))
                x[j0:j0 + n] += s[: len(x[j0:j0 + n])] * (0.5 if b % 2 == 0 else 0.25)
    return norm(x, 0.7)


os.makedirs(OUT, exist_ok=True)
save("sfx_tir_mitrailleuse", mitrailleuse())
save("sfx_tir_canon", canon())
save("sfx_explosion", explosion())
save("sfx_impact_blindage", impact())
save("sfx_ui_clic", clic())
save("sfx_atelier", atelier())
save("sfx_radio", radio())
save("sfx_depart_marche", depart_marche())
save("sfx_depart_convoi", depart_convoi())
save("sfx_meute", hurlement())
save("sfx_nuee", nuee())
save("sfx_pompe", pompe())
for nom, f in {"moto": 92, "jeep": 58, "voiture": 51, "camion": 41, "semi_chenille": 35, "char_leger": 31, "char": 26}.items():
    save("sfx_moteur_" + nom, moteur(f))
save("amb_desert_jour", vent())
save("amb_desert_nuit", vent(nuit=True))
A, D, E, G, C = 55.0, 73.4, 82.4, 98.0, 65.4
save("mus_combat", musique([A, A, A, 65.4, A, A, E, G], [[220, 261.6, 329.6], [196, 246.9, 293.7], [220, 261.6, 329.6], [174.6, 220, 261.6]], 112, 8))
save("mus_menu", musique([D, D, 110, D], [[146.8, 174.6, 220], [130.8, 164.8, 196]], 70, 8, perc=False))
save("mus_base", musique([C, C, 98, C], [[130.8, 164.8, 196], [110, 130.8, 164.8]], 80, 8, perc=False))
print("ok", len(os.listdir(OUT)), "fichiers")
