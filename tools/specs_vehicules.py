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
         "mitrailleuse": "armement"}

# véhicule : (nom, longueur, hauteur, {pièce: (x, y, w)}, [(pièce, décalage x, z), ...])
SPECS = {
    "bmw_r75": ("BMW R75 side-car", 2.35, 1.2, {
        "panier": (0.30, 0.30, 1.70), "mitrailleuse": (1.05, 0.88, 1.15), "chassis": (0.25, 0.25, 1.80),
        "transmission": (0.45, 0.28, 0.80), "moteur": (0.95, 0.22, 0.55), "roue": (0.17, 0.0, 0.66),
        "caisse": (0.05, 0.28, 2.25)},
        [("panier", 0, 0), ("roue", 0.75, 1), ("mitrailleuse", 0, 2), ("chassis", 0, 3), ("transmission", 0, 4),
         ("moteur", 0, 5), ("roue", 0, 6), ("roue", 1.45, 6), ("caisse", 0, 7)]),
    "citroen_traction": ("Citroën Traction Avant", 4.45, 1.52, {
        "chassis": (0.30, 0.18, 3.90), "transmission": (1.90, 0.22, 1.80), "moteur": (3.05, 0.30, 0.95),
        "roue": (0.52, 0.0, 0.66), "caisse": (0.0, 0.15, 4.45)},
        [("chassis", 0, 1), ("transmission", 0, 2), ("moteur", 0, 3), ("roue", 0, 4), ("roue", 2.91, 4), ("caisse", 0, 5)]),
    "citroen_t23": ("Citroën T23", 5.6, 2.4, {
        "chassis": (0.10, 0.40, 5.40), "transmission": (2.10, 0.45, 2.30), "moteur": (4.40, 0.75, 0.90),
        "roue": (0.70, 0.0, 0.95), "plateau": (0.0, 0.95, 3.30), "cabine": (3.30, 0.72, 2.30)},
        [("chassis", 0, 1), ("transmission", 0, 2), ("moteur", 0, 3), ("roue", 0, 4), ("roue", 3.60, 4),
         ("plateau", 0, 5), ("cabine", 0, 6)]),
    "diamond_t": ("Diamond T 969 dépanneuse", 7.42, 3.0, {
        "chassis": (0.40, 0.20, 6.60), "transmission": (4.50, 0.80, 0.80), "moteur": (5.70, 0.90, 1.10),
        "roue": (1.05, 0.0, 1.10), "caisse": (0.20, 0.72, 7.20), "grue": (0.05, 1.20, 2.60)},
        [("chassis", 0, 1), ("transmission", 0, 2), ("moteur", 0, 3), ("roue", 0, 4), ("roue", 1.40, 4),
         ("roue", 4.95, 4), ("caisse", 0, 5), ("grue", 0, 6)]),
    "dukw": ("DUKW", 9.45, 2.7, {
        "chassis": (1.70, 0.10, 6.20), "transmission": (5.00, 0.80, 0.80), "moteur": (6.30, 1.00, 1.10),
        "helice": (0.25, 0.35, 0.40), "roue": (1.75, 0.0, 1.10), "caisse": (0.0, 0.55, 9.45)},
        [("chassis", 0, 1), ("transmission", 0, 2), ("moteur", 0, 3), ("helice", 0, 4), ("roue", 0, 4),
         ("roue", 1.25, 4), ("roue", 4.80, 4), ("caisse", 0, 5)]),
    "m3_half_track": ("M3 Half-Track", 6.17, 2.26, {
        "transmission": (3.80, 0.60, 0.70), "moteur": (4.60, 0.70, 1.00), "chenille": (0.45, 0.0, 3.00),
        "galet": (0.95, 0.06, 0.32), "roue": (4.70, 0.0, 0.95), "caisse": (0.0, 0.45, 6.17),
        "mitrailleuse": (2.10, 1.90, 0.90)},
        [("transmission", 0, 1), ("moteur", 0, 2), ("chenille", 0, 3), ("galet", 0, 4), ("galet", 0.6, 4),
         ("galet", 1.2, 4), ("galet", 1.8, 4), ("roue", 0, 4), ("caisse", 0, 5), ("mitrailleuse", 0, 6)]),
}

def main():
    root = Path("docs/art/vehicules")
    for vid, (name, L, H, pieces, inst) in SPECS.items():
        images = []
        for pid, (x, y, w) in pieces.items():
            pw, ph = Image.open(root / vid / "art" / f"{pid}.png").size
            bx, by, bw, bh = x / CELL, y / CELL, w / CELL, w * ph / pw / CELL
            rect = [[bx, by], [bx + bw, by], [bx + bw, by + bh], [bx, by + bh]]
            images.append({"id": pid, "slot": SLOTS[pid], "box": [bx, by, bw, bh], "shapes": [{"poly": rect}]})
        top = max(i["box"][1] + i["box"][3] for i in images)
        g = {"vehicle": vid, "name": name, "cell_m": CELL, "px_per_cell": 64,
             "size_cells": [L / CELL + 1, max(H / CELL, top) + 1],
             "note": "Généré par tools/specs_vehicules.py. Cotes de prototypage, à affiner sur plans.",
             "images": images,
             "instances": [{"id": f"{p}_{n}", "image": p, "dx": dx / CELL, "z": z} for n, (p, dx, z) in enumerate(inst)]}
        (root / vid / "gabarit.json").write_text(json.dumps(g, indent=1, ensure_ascii=False))

if __name__ == "__main__":
    main()
