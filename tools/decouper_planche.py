"""Détoure une planche ChatGPT (fond magenta) et la découpe en pièces séparées.

Usage : python3 tools/decouper_planche.py planche.png dossier_sortie
Les pièces doivent être séparées par du fond (aucun contact). Découpe récursive par
bandes vides horizontales puis verticales. Sortie : piece_01.png, piece_02.png…
(de gauche à droite, de haut en bas), fond transparent, rognées au contenu.
"""
import sys
from pathlib import Path
import numpy as np
from PIL import Image

def detourer(path):
    a = np.array(Image.open(path).convert("RGBA")).astype(float)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    key = np.clip(((np.minimum(r, b) - g) - 30) / 60, 0, 1)   # 1 = fond magenta
    spill = np.clip(np.minimum(r, b) - g, 0, None) * key
    a[..., 0] -= spill * 0.8; a[..., 2] -= spill * 0.8; a[..., 3] = (1 - key) * 255
    return np.clip(a, 0, 255).astype("uint8")

def bandes(mask, axis, min_gap=8):
    filled = mask.any(axis=axis); out, start, gap = [], None, 0
    for i, v in enumerate(filled):
        if v:
            if start is None: start = i
            gap = 0
        elif start is not None:
            gap += 1
            if gap >= min_gap: out.append((start, i - gap + 1)); start = None
    if start is not None: out.append((start, len(filled)))
    return out

def decouper(mask, x0, y0, sens=0):
    rows = bandes(mask, 1) if sens == 0 else [(0, mask.shape[0])]
    cols = bandes(mask, 0) if sens == 1 else [(0, mask.shape[1])]
    parts = [(r, c) for r in rows for c in cols]
    if len(parts) == 1:
        if sens == 0: return decouper(mask, x0, y0, 1)
        (r0, r1), (c0, c1) = parts[0]; return [(x0 + c0, y0 + r0, x0 + c1, y0 + r1)]
    res = []
    for (r0, r1), (c0, c1) in parts:
        res += decouper(mask[r0:r1, c0:c1], x0 + c0, y0 + r0, 1 - sens)
    return res

def main(src, dst):
    a = detourer(src); mask = a[..., 3] > 128; dst = Path(dst); dst.mkdir(parents=True, exist_ok=True)
    boites = [b for b in decouper(mask, 0, 0) if (b[2] - b[0]) * (b[3] - b[1]) > 2000]
    for n, (x0, y0, x1, y1) in enumerate(sorted(boites, key=lambda b: (b[1] // 200, b[0])), 1):
        sub = mask[y0:y1, x0:x1]; ys = np.where(sub.sum(1) > 3)[0]; xs = np.where(sub.sum(0) > 3)[0]
        y0, y1, x0, x1 = y0 + ys[0], y0 + ys[-1] + 1, x0 + xs[0], x0 + xs[-1] + 1  # rognage (bruit de bord ignoré)
        Image.fromarray(a[y0:y1, x0:x1]).save(dst / f"piece_{n:02d}.png"); print(n, (x0, y0, x1, y1))

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])


def vrac(src, dst, min_area=1500, fusion=6):
    """Planche en désordre : une pièce par composante connexe (petits écarts fusionnés)."""
    from scipy import ndimage
    a = detourer(src); mask = a[..., 3] > 128
    lab, n = ndimage.label(ndimage.binary_dilation(mask, iterations=fusion))
    dst = Path(dst); dst.mkdir(parents=True, exist_ok=True); k = 0
    objs = [(i + 1, sl) for i, sl in enumerate(ndimage.find_objects(lab))]
    for lid, sl in sorted(objs, key=lambda o: (o[1][0].start // 150, o[1][1].start)):
        sub = a[sl].copy(); sub[..., 3] = np.where(mask[sl] & (lab[sl] == lid), sub[..., 3], 0)
        if (sub[..., 3] > 128).sum() < min_area: continue
        k += 1; Image.fromarray(sub).save(dst / f"piece_{k:03d}.png")
    return k
