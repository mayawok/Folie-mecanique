#!/usr/bin/env python3
"""Découpe et étalonne les lots 3b, 3c, 20 et 21 (décor terre et herbe, éléments, interface).
Entrée : docs/art/decor/brut/lot*.png (fond magenta #FF00FF). Sortie : game/assets/decor et game/assets/ui.
Usage : python3 tools/decor_terre.py"""
import numpy as np
from PIL import Image
import scipy.ndimage as nd
import os

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BRUT = os.path.join(RACINE, "docs/art/decor/brut")
DECOR = os.path.join(RACINE, "game/assets/decor")
UI = os.path.join(RACINE, "game/assets/ui")


def cle_magenta(im):
    """RGB -> RGBA : le magenta devient transparent, la frange est débarrassée de sa teinte rose."""
    a = np.asarray(im.convert("RGB")).astype(np.float32)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    d = np.sqrt((r - 255) ** 2 + g ** 2 + (b - 255) ** 2)
    alpha = np.clip((d - 60.0) / 110.0, 0.0, 1.0)
    exces = np.maximum(0.0, np.minimum(r, b) - g)
    frange = (alpha < 1.0) | (exces > 40)
    r2 = np.where(frange, r - exces * 0.9, r)
    b2 = np.where(frange, b - exces * 0.9, b)
    out = np.stack([r2, g, b2, alpha * 255.0], axis=-1)
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGBA")


def boucler(im, n=170):
    """Rend l'image raccordable gauche-droite par fondu enchaîné sur n colonnes (le dernier morceau disparaît)."""
    a = np.asarray(im).astype(np.float32)
    h, w = a.shape[:2]
    a[..., :3] *= a[..., 3:4] / 255.0   # prémultiplié
    t = np.linspace(0, 1, n)[None, :, None]
    mix = a[:, w - n:, :] * (1 - t) + a[:, :n, :] * t
    res = np.concatenate([mix, a[:, n:w - n, :]], axis=1)
    al = res[..., 3:4]
    rgb = np.where(al > 0.5, res[..., :3] / np.maximum(al, 1.0) * 255.0, 0)
    return Image.fromarray(np.clip(np.concatenate([rgb, al], axis=-1), 0, 255).astype(np.uint8), "RGBA")


def composants(rgba, dil, attendus, ordre):
    """Découpe les éléments séparés d'une planche. ordre : (nb de lignes, nb par ligne)."""
    al = np.asarray(rgba)[..., 3] > 40
    lab, n = nd.label(nd.binary_dilation(al, iterations=dil))
    boites = []
    for i, sl in enumerate(nd.find_objects(lab), 1):
        masque = (lab[sl] == i) & al[sl]
        if masque.sum() < 800:
            continue
        ys, xs = np.where(masque)
        boites.append((sl[0].start + ys.min(), sl[0].start + ys.max() + 1, sl[1].start + xs.min(), sl[1].start + xs.max() + 1))
    assert len(boites) == attendus, (len(boites), attendus)
    lignes, par = ordre
    boites.sort(key=lambda b: (b[0] + b[1]) / 2)
    res = []
    for k in range(lignes):
        row = sorted(boites[k * par:(k + 1) * par], key=lambda b: b[2])
        res += row
    return [rgba.crop((b[2], b[0], b[3], b[1])) for b in res]


def main():
    os.makedirs(DECOR, exist_ok=True)
    ciel = Image.open(f"{BRUT}/lot3b_ciel.png").convert("RGB")
    boucler(ciel.convert("RGBA")).convert("RGB").save(f"{DECOR}/terre_ciel.png", optimize=True)
    for nom in ["lointain", "moyen", "sol"]:
        c = cle_magenta(Image.open(f"{BRUT}/lot3b_{nom}.png"))
        c = boucler(c)
        al = np.asarray(c)[..., 3]
        haut = np.median([np.argmax(al[:, x] > 128) for x in range(0, al.shape[1], 8)]) / al.shape[0]
        c.save(f"{DECOR}/terre_{nom}.png", optimize=True)
        print(f"terre_{nom}: {c.size}, sommet médian à {haut:.3f} de la hauteur")
    noms = ["chateau_eau", "clocher", "ruine", "arbre", "arbre_mort", "poteau", "cloture", "muret", "buissons", "rocher"]
    el = composants(cle_magenta(Image.open(f"{BRUT}/lot3c_elements.png")), 6, 10, (2, 5))
    for n, e in zip(noms, el):
        e.save(f"{DECOR}/elem_{n}.png", optimize=True)
        print(f"elem_{n}: {e.size}")
    pan = composants(cle_magenta(Image.open(f"{BRUT}/lot20_panneaux.png")), 10, 3, (1, 3))
    for n, e in zip(["ui_panneau", "ui_onglet", "ui_onglet_actif"], pan):
        e.save(f"{UI}/{n}.png", optimize=True)
        print(f"{n}: {e.size}")
    ic = ["conducteur", "mitrailleur", "mecanicien", "eclaireur", "chef", "infirmier", "moteur", "roues", "blindage", "arme", "menace", "gazole"]
    icones = composants(cle_magenta(Image.open(f"{BRUT}/lot21_icones.png")), 12, 12, (3, 4))
    for n, e in zip(ic, icones):
        e.thumbnail((256, 256), Image.LANCZOS)
        e.save(f"{UI}/ic_{n}.png", optimize=True)
    print("icônes:", len(icones))


main()
