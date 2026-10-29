"""Écrit gabarit.json des véhicules 2 à 7 à partir des pièces dessinées (art/*.png).

Usage : python3 tools/specs_vehicules.py   puis   python3 tools/gabarits_vehicule.py docs/art/vehicules/<id>
Cotes en mètres : x depuis l'arrière, y depuis le sol, w = largeur de la pièce.
La hauteur se déduit des proportions de l'image. Valeurs de prototypage, à affiner sur plans.
"""
import json
from pathlib import Path
from PIL import Image

CELL = 0.25
SLOTS = {"caisse": "carrosserie", "cabine": "carrosserie", "plateau": "carrosserie", "panier": "carrosserie",
         "grue": "carrosserie", "chassis": "chassis", "moteur": "moteur", "transmission": "transmission",
         "roue": "roulement", "chenille": "roulement", "galet": "roulement", "helice": "transmission",
         "mitrailleuse": "armement", "suspension": "roulement"}

# véhicule : (nom, longueur, hauteur, {pièce: (x, y, w)}, [(pièce, décalage x, z), ...])
SPECS = {
    # Roues : centres calés sur les passages de roue mesurés sur chaque caisse (fraction de largeur),
    # moyeux du châssis alignés sur les centres de roue. Voir PRODUCTION.md.
    "bmw_r75": ("BMW R75 side-car", 2.35, 1.2, {
        "panier": (0.35, 0.30, 1.70), "mitrailleuse": (1.05, 0.88, 1.15), "chassis": (0.34, 0.26, 1.70),
        "transmission": (0.45, 0.28, 0.80), "moteur": (0.82, 0.41, 0.55), "roue": (0.12, 0.0, 0.66),
        "caisse": (0.10, 0.25, 2.05)},
        [("panier", 0, 0), ("roue", 0.80, 1), ("mitrailleuse", 0, 2), ("chassis", 0, 3), ("transmission", 0, 4),
         ("moteur", 0, 5), ("caisse", 0, 6), ("roue", 0, 6.2), ("roue", 1.45, 6.2)]),
    "citroen_traction": ("Citroën Traction Avant", 4.75, 1.52, {
        "chassis": (0.50, 0.19, 3.90), "transmission": (2.10, 0.22, 1.80), "moteur": (3.30, 0.30, 0.95),
        "roue": (0.66, 0.0, 0.70), "caisse": (0.30, 0.13, 4.45)},
        [("chassis", 0, 1), ("transmission", 0, 2), ("moteur", 0, 3), ("caisse", 0, 4), ("roue", 0, 4.2), ("roue", 3.07, 4.2)]),
    "citroen_t23": ("Citroën T23", 5.6, 2.4, {
        "chassis": (0.45, 0.36, 5.14), "transmission": (2.20, 0.45, 2.30), "moteur": (4.30, 0.80, 0.90),
        "roue": (0.775, 0.0, 0.95), "plateau": (0.0, 0.87, 3.30), "cabine": (3.26, 0.53, 2.30)},
        [("chassis", 0, 1), ("transmission", 0, 2), ("moteur", 0, 3), ("roue", 0, 4), ("plateau", 0, 5), ("cabine", 0, 6),
         ("roue", 3.60, 6.2)]),
    "diamond_t": ("Diamond T 969 dépanneuse", 7.42, 3.0, {
        "chassis": (0.83, 0.15, 6.67), "transmission": (4.50, 0.80, 0.80), "moteur": (5.65, 0.62, 0.95),
        "roue": (0.51, 0.0, 1.10), "caisse": (0.20, 0.22, 7.20), "grue": (0.10, 0.80, 2.60)},
        [("chassis", 0, 1), ("transmission", 0, 2), ("moteur", 0, 3), ("grue", 0, 4.5), ("caisse", 0, 5),
         ("roue", 0, 5.2), ("roue", 1.30, 5.2), ("roue", 5.11, 5.2)]),
    "dukw": ("DUKW", 9.45, 2.7, {
        "chassis": (1.64, 0.25, 6.20), "transmission": (5.00, 0.80, 0.80), "moteur": (6.30, 1.00, 1.10),
        "helice": (0.25, 0.35, 0.40), "roue": (2.27, 0.0, 1.10), "caisse": (0.0, 0.55, 9.45)},
        [("chassis", 0, 1), ("transmission", 0, 2), ("moteur", 0, 3), ("helice", 0, 4), ("roue", 0, 4),
         ("roue", 1.92, 4), ("roue", 3.78, 4), ("caisse", 0, 5)]),
    "m3_half_track": ("M3 Half-Track", 6.17, 2.26, {
        "transmission": (3.80, 0.60, 0.70), "moteur": (4.70, 0.55, 0.85), "chenille": (0.30, 0.0, 3.00),
        "galet": (0.74, 0.12, 0.32), "suspension": (0.80, 0.20, 2.00), "roue": (4.765, 0.0, 0.95), "caisse": (0.0, 0.36, 6.17),
        "mitrailleuse": (2.10, 1.72, 0.90)},
        [("transmission", 0, 1), ("moteur", 0, 2), ("chenille", 0, 3), ("galet", 0, 4), ("galet", 0.6, 4),
         ("galet", 1.2, 4), ("galet", 1.8, 4), ("suspension", 0, 4.3), ("caisse", 0, 5),
         ("roue", 0, 5.2), ("mitrailleuse", 0, 6)]),
}

# Passages de roue : la caisse est redessinée devant les roues, percée d'un disque
# un peu plus petit que la roue (le bord de l'aile recouvre le pneu).
PASSAGES = {"bmw_r75": "caisse", "citroen_traction": "caisse", "citroen_t23": "cabine",
            "diamond_t": "caisse", "m3_half_track": "caisse"}
RAYON = 0.96

# Garde au sol ajoutée : tout le véhicule monte, sauf roues, chenille et galets (débattement visible).
LEVE = {"bmw_r75": 0.04, "citroen_traction": 0.07, "citroen_t23": 0.10, "diamond_t": 0.12,
        "dukw": 0.08, "m3_half_track": 0.05}

def main():
    root = Path("docs/art/vehicules")
    for vid, (name, L, H, pieces, inst) in SPECS.items():
        images = []
        for pid, (x, y, w) in pieces.items():
            pw, ph = Image.open(root / vid / "art" / f"{pid}.png").size
            if SLOTS[pid] != "roulement": y += LEVE.get(vid, 0)
            bx, by, bw, bh = x / CELL, y / CELL, w / CELL, w * ph / pw / CELL
            rect = [[bx, by], [bx + bw, by], [bx + bw, by + bh], [bx, by + bh]]
            images.append({"id": pid, "slot": SLOTS[pid], "box": [bx, by, bw, bh], "shapes": [{"poly": rect}]})
        top = max(i["box"][1] + i["box"][3] for i in images)
        bw = {i["id"]: i["box"][0] + i["box"][2] for i in images}
        right = max(bw[p] + dx / CELL for p, dx, z in inst)
        g = {"vehicle": vid, "name": name, "cell_m": CELL, "px_per_cell": 64,
             "size_cells": [max(L / CELL, right) + 1, max(H / CELL, top) + 1],
             "note": "Généré par tools/specs_vehicules.py. Cotes de prototypage, à affiner sur plans.",
             "images": images,
             "instances": [{"id": f"{p}_{n}", "image": p, "dx": dx / CELL, "z": z} for n, (p, dx, z) in enumerate(inst)]}
        cible = PASSAGES.get(vid)
        if cible:
            box = {i["id"]: i["box"] for i in images}; cx0, cy0, cw, ch = box[cible]; zc = next(z for p, dx, z in inst if p == cible)
            trous = []
            for p, dx, z in inst:
                if p == "roue" and z > zc:
                    x, y, w, h = box["roue"]; c = (x + dx / CELL + w / 2, y + h / 2)
                    if cx0 < c[0] < cx0 + cw and c[1] + h / 2 > cy0:
                        trous.append([c[0], c[1], w / 2 * RAYON])
            g["instances"].append({"id": f"{cible}_avant", "image": cible, "dx": 0, "z": max(z for p, dx, z in inst if p == "roue") + 0.1, "trous": trous})
        (root / vid / "gabarit.json").write_text(json.dumps(g, indent=1, ensure_ascii=False))

if __name__ == "__main__":
    main()
