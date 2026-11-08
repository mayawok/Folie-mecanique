#!/usr/bin/env python3
"""Découpe les planches ChatGPT du Berliet GDR en pièces détourées (PNG transparents).

Usage : python3 tools/decouper_berliet.py <dossier_des_planches> <dossier_sortie> [reduction=0.5]
Les pièces sont enregistrées réduites (0,5 : moitié des pixels de la planche) ; berliet.json donne la même valeur dans « reduction ».
Planches attendues (noms dans PLANCHES) ; le fond clair et peu coloré relié au bord est retiré,
puis chaque planche est coupée en morceaux (composantes connexes, triées de gauche à droite, haut puis bas).
"""
import sys, os
import numpy as np
from PIL import Image
from scipy import ndimage

# planche -> liste des noms de pièces dans l'ordre de lecture (rangées de haut en bas, puis gauche à droite)
PLANCHES = {
    "cabine.png": ["cabine"],
    "chassis_long.png": ["chassis_long"],
    "chassis_court.png": ["chassis_court"],
    "roues_arriere.png": ["roue_ar_route", "roue_ar_agraire", "roue_ar_crampons", "roue_ar_chaines", "roue_ar_blindee"],
    "roues_avant.png": ["roue_av_route", "roue_av_agraire", "roue_av_crampons", "roue_av_chaines", "roue_av_blindee"],
    "echappements.png": ["echappement_1", "echappement_2", "echappement_3", "echappement_4", "echappement_5"],
    "trappe.png": ["trappe"],
    "reservoirs.png": ["reservoir_1", "reservoir_2", "reservoir_3", "reservoir_4", "reservoir_5"],
}


def detourer(im: Image.Image, interieur=None) -> Image.Image:
    """interieur : couleur RGB donnée aux trous fermés couleur de fond (vitres de la cabine) ; None = trous transparents."""
    a = np.asarray(im.convert("RGB")).astype(np.int16)
    bord = np.concatenate([a[0], a[-1], a[:, 0], a[:, -1]])
    fond = np.median(bord, axis=0)
    dist = np.abs(a - fond).max(axis=2)
    sat = a.max(axis=2) - a.min(axis=2)
    lum = a.mean(axis=2)
    # fond et ombre portée douce : peu coloré et clair
    proche = ((dist < 26) | ((sat < 12) & (lum > fond.mean() - 45)))
    lab, _ = ndimage.label(proche)
    bords = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    fond_m = np.isin(lab, list(bords))
    # trous fermés couleur de fond (entre les lames de ressort, fenêtres) : transparents, ou intérieur sombre
    trous = proche & ~fond_m
    lab2, k2 = ndimage.label(trous)
    aires = ndimage.sum(trous, lab2, range(1, k2 + 1))
    grands = np.isin(lab2, [i + 1 for i in range(k2) if aires[i] > 120])
    if interieur is not None:
        a[grands] = interieur
    else:
        fond_m = fond_m | grands
    objet = ~fond_m
    objet = ndimage.binary_opening(objet, iterations=1)
    objet = ndimage.binary_fill_holes(objet) & objet | ndimage.binary_erosion(objet, iterations=1)
    alpha = (objet * 255).astype(np.uint8)
    # bord adouci d'un pixel
    alpha = np.asarray(Image.fromarray(alpha).filter(__import__("PIL.ImageFilter", fromlist=["x"]).GaussianBlur(0.7)))
    rgba = np.dstack([a.astype(np.uint8), alpha])
    return Image.fromarray(rgba, "RGBA")


def morceaux(rgba: Image.Image, n: int, rangees: int = 1, dil: int = 6):
    al = np.asarray(rgba)[:, :, 3] > 40
    lab, k = ndimage.label(ndimage.binary_dilation(al, iterations=dil))
    objs = ndimage.find_objects(lab)
    tailles = ndimage.sum(al, lab, range(1, k + 1))
    ordre = sorted(range(k), key=lambda i: -tailles[i])[:n]
    h = rgba.height
    # lecture : rangée (haut/bas), puis x
    deux = rangees == 2
    ordre.sort(key=lambda i: (1 if deux and (objs[i][0].start + objs[i][0].stop) / 2 > h * 0.5 else 0, objs[i][1].start))
    res = []
    for idx in ordre:
        s = objs[idx]
        y0, y1, x0, x1 = s[0].start, s[0].stop, s[1].start, s[1].stop
        m = np.asarray(rgba).copy()
        m[:, :, 3] = np.where(lab == idx + 1, m[:, :, 3], 0)
        res.append(Image.fromarray(m, "RGBA").crop((x0, y0, x1, y1)))
    return res


def colonnes(rgba: Image.Image, n: int):
    """Rangée d'objets qui se touchent (roues) : coupe aux colonnes les moins remplies, près des n-1 frontières régulières."""
    al = np.asarray(rgba)[:, :, 3] > 40
    prof = al.sum(axis=0)
    xs = np.nonzero(prof)[0]
    x0, x1 = xs[0], xs[-1]
    pas = (x1 - x0) / n
    coupes = [x0]
    for i in range(1, n):
        c = int(x0 + pas * i)
        f = int(pas * 0.2)
        coupes.append(c - f + int(np.argmin(prof[c - f:c + f])))
    coupes.append(x1 + 1)
    res = []
    for a, b in zip(coupes[:-1], coupes[1:]):
        sous = rgba.crop((a, 0, b, rgba.height))
        res.append(sous.crop(sous.getbbox()))
    return res


def main(src: str, dst: str) -> None:
    os.makedirs(dst, exist_ok=True)
    for planche, noms in PLANCHES.items():
        p = os.path.join(src, planche)
        if not os.path.exists(p):
            print("absent :", planche)
            continue
        rgba = detourer(Image.open(p), (34, 32, 30) if planche == "cabine.png" else None)
        parts = colonnes(rgba, len(noms)) if planche.startswith("roues") else morceaux(rgba, len(noms), 2 if planche == "reservoirs.png" else 1)
        for nom, img in zip(noms, parts):
            if RED != 1.0:
                img = img.resize((max(1, round(img.width * RED)), max(1, round(img.height * RED))), Image.LANCZOS)
            img.save(os.path.join(dst, nom + ".png"), optimize=True)
            print(nom, img.size)


RED = 0.5

if __name__ == "__main__":
    if len(sys.argv) > 3:
        RED = float(sys.argv[3])
    main(sys.argv[1], sys.argv[2])
