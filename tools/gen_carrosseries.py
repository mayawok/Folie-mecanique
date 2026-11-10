#!/usr/bin/env python3
"""Intègre les carrosseries ChatGPT (planches du 10/11, fond vert) comme sprites de véhicules (DEC-225).
Étapes par image : retrait du fond vert (alpha doux + anti-vert), vitres enfermées remplies de verre sombre, passages de roues
(noir pur) rendus transparents pour laisser voir les roues du jeu, recadrage, réduction à 1024 px de large.
Puis écrit dans formes_vehicules.json un sprite posé sur le véhicule (caisse relevée : 'lr' arrière / 'lf' avant, en m),
les roues (x, r) déduites des passages de roues, les pots d'échappement et l'équipage.
Les sources sont lues dans le dossier donné en argument (nom = id du véhicule : <dossier>/<id>.png).
Usage : python3 tools/gen_carrosseries.py <dossier_sources> [--apercu /tmp/apercu.png]"""
import json, os, sys
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi

RACINE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
DATA = os.path.join(RACINE, "game", "data")
ASSETS = os.path.join(RACINE, "game", "assets", "vehicules")
LARG = 1024

# Réglages par véhicule. lr/lf : relèvement de la caisse (m) arrière/avant. pots : (x m, dy m, dir_x, dir_y) ; arme : x du tireur (m).
# roues_moto : [(x_px, y_px)] centres des roues dans l'image source, rayon en m dans 'r'.
CFG = {
    "moto_zundapp": {"lr": 0.0, "lf": 0.0, "moto": [(330, 620), (1430, 640)], "r": 0.33, "selle": (800, 290)},
    "moto_harley": {"lr": 0.0, "lf": 0.0, "moto": [(330, 640), (1370, 600)], "r": 0.33, "selle": (700, 235)},
    "moto_gnome": {"lr": 0.0, "lf": 0.0, "moto": [(310, 600), (1360, 590)], "r": 0.33, "selle": (600, 255)},
    "peugeot_202": {"lr": 0.35, "lf": 0.2, "pots": [(0.3, 0.1, -1, 0)], "arme": 1.6},
    "juvaquatre": {"lr": 0.35, "lf": 0.2, "pots": [(0.3, 0.1, -1, 0), (0.5, 0.25, -1, 0)], "arme": 1.2},
    "kubelwagen": {"lr": 0.3, "lf": 0.18, "pots": [(0.3, 0.1, -1, 0)], "arme": 1.5},
    "citroen_h": {"lr": 0.35, "lf": 0.2, "pots": [(0.4, 0.1, -1, 0)], "arme": 3.2},
    "opel_blitz": {"lr": 0.4, "lf": 0.25, "pots": [(0.4, 0.25, -1, 0)], "arme": 3.9},
    "gmc_cckw": {"lr": 0.4, "lf": 0.25, "pots": [(0.4, 0.25, -1, 0), (0.75, 0.38, -1, 0)], "arme": 4.6, "double_arche": True},
    "laffly_s15": {"lr": 0.4, "lf": 0.25, "pots": [(3.0, 0.0, -0.5, 1)], "arme": 3.3},
}


def traiter(chemin):
    a = np.array(Image.open(chemin).convert("RGB")).astype(int)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    vert = (g > 170) & (r < 120) & (b < 120)
    lab, _ = ndi.label(vert)
    ext = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    exterieur = np.isin(lab, list(ext))
    verdatre = (g > r * 1.15 + 10) & (g > b * 1.15 + 10) & ~exterieur     # vitres : fond vert vu à travers le verre, plus ou moins sali
    trous = ndi.binary_closing(verdatre, iterations=2) & ~exterieur
    noir = (a.max(axis=2) < 14) & ~exterieur
    dl, dn = ndi.label(noir)
    arches = []
    for i in range(1, dn + 1):
        m = dl == i
        ys, xs = np.where(m)
        if m.sum() > 8000 and ys.max() > a.shape[0] * 0.85 and (xs.max() - xs.min()) < a.shape[1] * 0.6:   # grands noirs du bas = passages de roues
            arches.append((m, int(xs.min()), int(xs.max()), int(ys.min()), int(ys.max())))
    dist = np.sqrt(r ** 2 + (g - 255) ** 2 + b ** 2)
    alpha = np.clip((dist - 60) / 80.0, 0, 1)
    alpha[exterieur] = 0
    rgb = a.copy()
    proche = ndi.binary_dilation(exterieur | trous, iterations=3)   # anti-vert sur les bords
    rgb[..., 1] = np.where(proche & (g > np.maximum(r, b)), np.maximum(r, b) + 4, g)
    t_dil = ndi.binary_dilation(trous, iterations=1)
    lum = (r + g + b) / 3.0
    verre = np.stack([22 + (lum - 90) * 0.18, 32 + (lum - 90) * 0.2, 31 + (lum - 90) * 0.18], axis=-1).clip(10, 90)   # verre sombre, fissures conservées
    rgb = np.where(t_dil[..., None], verre, rgb)
    alpha = np.where(t_dil, 0.88, alpha)
    for m, *_ in arches:
        alpha[ndi.binary_dilation(m, iterations=2)] = 0
    out = np.dstack([rgb, (alpha * 255)]).clip(0, 255).astype("uint8")
    im = Image.fromarray(out, "RGBA")
    ys, xs = np.where(alpha > 0.1)
    box = (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)
    return im, box, [(x0, x1, y0, y1) for _, x0, x1, y0, y1 in arches]


def main():
    src = sys.argv[1]
    apercu = sys.argv[sys.argv.index("--apercu") + 1] if "--apercu" in sys.argv else ""
    formes = json.load(open(os.path.join(DATA, "formes_vehicules.json"), encoding="utf-8"))
    vues = []
    for vid, cfg in CFG.items():
        chemin = os.path.join(src, vid + ".png")
        im, box, arches = traiter(chemin)
        Wp, Hp = box[2] - box[0], box[3] - box[1]
        F = formes["vehicules"][vid]
        L = float(F["longueur"])
        s = L / Wp                                   # mètres par pixel de l'image source
        k = LARG / Wp
        crop = im.crop(box).resize((LARG, int(round(Hp * k))), Image.LANCZOS)
        os.makedirs(os.path.join(ASSETS, vid), exist_ok=True)
        crop.save(os.path.join(ASSETS, vid, "carrosserie.png"), optimize=True)
        lr, lf = cfg["lr"], cfg["lf"]
        lift = lambda x: lr + (lf - lr) * min(max(x / L, 0.0), 1.0)
        Hm = Hp * s
        roues = []
        if "moto" in cfg:
            for (px, py) in cfg["moto"]:
                roues.append({"x": round((px - box[0]) * s, 3), "r": cfg["r"]})
            y_sol_px = max(py for _, py in cfg["moto"]) + cfg["r"] / s       # le bas des roues = sol
            lr = lf = round((y_sol_px - box[3]) * s, 3)                       # la caisse est posée plus haut que le sol
            lr = lf = max(lr, 0.0)
        else:
            larges = []
            for (x0, x1, y0, y1) in arches:
                if not (y1 > box[3] - Hp * 0.08):
                    continue
                larges.append((x0, x1, y0, y1))
            larges.sort()
            for (x0, x1, y0, y1) in larges:
                n = 2 if (cfg.get("double_arche") and (x1 - x0) * s > 1.7) else 1
                for j in range(n):
                    xa = x0 + (x1 - x0) * j / n
                    xb = x0 + (x1 - x0) * (j + 1) / n
                    cx = ((xa + xb) / 2 - box[0]) * s
                    w = (xb - xa) * s
                    h_arche = (box[3] - y0) * s
                    r_ = min(w / 2 * 1.08, (lift(cx) + h_arche) * 0.5 * 1.02)
                    roues.append({"x": round(cx, 3), "r": round(r_, 3)})
        # contour supérieur (pour poser arme et tireur sur le toit)
        al = np.array(crop)[..., 3]
        def haut(xm):
            col = int(min(max(xm / L, 0.0), 0.999) * LARG)
            ys = np.where(al[:, col] > 40)[0]
            return (al.shape[0] - ys.min()) / k * s if len(ys) else Hm
        sprite = {"sprite": "vehicules/%s/carrosserie" % vid, "r": [0.0, 0.0, round(L, 3), round(Hm, 3)], "lr": round(lr, 3), "lf": round(lf, 3), "z": 1}
        F["formes"] = [sprite]
        F["roues"] = roues
        F["roues_fond"] = F.get("roues_fond", [])
        F["hauteur"] = round(Hm + max(lr, lf) + 0.1, 2)
        F["sprite"] = True
        F["pots"] = []
        for (x, dy, fx, fy) in cfg.get("pots", []):
            y = round(lift(x) + 0.1 + dy, 3)
            if fy == 0:
                F["formes"].append({"ligne": [[round(x + 0.9, 3), y], [x, y]], "ep": 0.09, "c": "metal", "z": 2})
                F["formes"].append({"pts": [[x + 0.02, y - 0.08], [x - 0.1, y - 0.14], [x - 0.1, y + 0.14], [x + 0.02, y + 0.08]], "c": "sombre", "z": 2})
                F["pots"].append({"x": round(x - 0.1, 3), "y": y, "dx": fx, "dy": fy})
            else:   # pot vertical derrière la cabine
                F["formes"].append({"ligne": [[x, y + 0.1], [x, y + 1.3]], "ep": 0.09, "c": "metal", "z": 2})
                F["formes"].append({"pts": [[x - 0.08, y + 1.3], [x + 0.08, y + 1.3], [x + 0.14, y + 1.42], [x - 0.14, y + 1.42]], "c": "sombre", "z": 2})
                F["pots"].append({"x": x, "y": round(y + 1.4, 3), "dx": fx, "dy": fy})
        if "moto" in cfg:
            xs_, ys_ = cfg["selle"]
            F["equipage"] = [{"x": round((xs_ - box[0]) * s, 3), "y": round((box[3] - ys_) * s + lr - 0.12, 3), "role": "conducteur"}]
        else:
            xa = cfg["arme"]
            yt = round(haut(xa) + lift(xa), 3)
            F["armes"] = [{"type": "mitrailleuse", "x": xa, "y": round(yt + 0.02, 3), "pied": 0.12, "long": 1.0, "ep": 0.04}]
            F["equipage"] = [{"x": round(xa - 0.1, 2), "y": round(yt - 0.3, 3), "role": "tireur", "h": 0.4}]
        print(vid, "L=%.2f H=%.2f roues=%s lr=%.2f" % (L, Hm, roues, lr))
        vues.append((vid, crop, roues, lr, lf, s, k))
    with open(os.path.join(DATA, "formes_vehicules.json"), "w", encoding="utf-8") as f:
        json.dump(formes, f, ensure_ascii=False, indent=2)
        f.write("\n")
    if apercu:   # planche de contrôle : un véhicule par case, sprite sur le sol, roues en cercles rouges
        e = 100.0
        planche = Image.new("RGB", (2400, 1520), (110, 106, 90))
        d = ImageDraw.Draw(planche)
        for n, (vid, crop, roues, lr, lf, s, k) in enumerate(vues):
            ox, sol = (n % 3) * 800 + 20, (n // 3) * 380 + 340
            w = int(crop.width / k * s * e); h = int(crop.height / k * s * e)
            sp = crop.resize((w, h))
            planche.paste(sp, (ox, int(sol - h - max(lr, lf) * e)), sp)
            for ro in roues:
                cx = ox + ro["x"] * e; cy = sol - ro["r"] * e
                d.ellipse([cx - ro["r"] * e, cy - ro["r"] * e, cx + ro["r"] * e, cy + ro["r"] * e], outline=(255, 60, 60), width=3)
            d.line([ox, sol, ox + w, sol], fill=(0, 0, 0))
        planche.save(apercu)


main()
