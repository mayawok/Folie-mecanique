#!/usr/bin/env python3
"""Aperçu du Berliet assemblé d'après game/data/berliet.json (même calage que le jeu, modules arrière non dessinés).

Usage : python3 tools/apercu_berliet.py sortie.png [chassis] [pneu_av] [pneu_ar] [echappement 0-4] [reservoir 0-4] [trappe_ouverte 0/1]
"""
import json, sys, os
from PIL import Image, ImageDraw

RAC = os.path.join(os.path.dirname(__file__), "..", "game")


def img(nom):
    return Image.open(os.path.join(RAC, "assets", "vehicules", "berliet", nom + ".png")).convert("RGBA")


RED = 1.0


def poser(fond, im, x, y, e, ox, oy):
    e = e / RED
    w, h = max(1, round(im.width * e)), max(1, round(im.height * e))
    fond.alpha_composite(im.resize((w, h), Image.LANCZOS), (round(x + ox), round(y + oy)))


def main():
    a = sys.argv[1:] + [None] * 8
    global RED
    D = json.load(open(os.path.join(RAC, "data", "berliet.json")))
    RED = D.get("reduction", 1.0)
    c = dict(D["defaut"])
    for k, v in zip(["chassis", "pneu_av", "pneu_ar", "echappement", "reservoir"], a[1:6]):
        if v is not None:
            c[k] = int(v) if k in ("echappement", "reservoir") else v
    ouverte = a[6] == "1"
    ox, oy = 700, 560
    fond = Image.new("RGBA", (2900, 1050), (205, 200, 190, 255))
    d = ImageDraw.Draw(fond)
    d.line([(0, oy + D["sol"]), (2900, oy + D["sol"])], fill=(90, 80, 60, 255), width=3)
    C = D["chassis"][c["chassis"]]
    # réservoir et échappement derrière la cabine, châssis, roues, cabine, trappe
    poser(fond, img(C["image"]), C["x"], C["y"], C["echelle"], ox, oy)
    R = D["reservoir"]; n = R["niveaux"][c["reservoir"]]; im = img(n["image"])
    poser(fond, im, R["x"], R["haut"], R["echelle"], ox, oy)
    E = D["echappement"]; n = E["niveaux"][c["echappement"]]; im = img(n["image"])
    poser(fond, im, E["droite"] - im.width * E["echelle"] / RED, E["bas"] - im.height * E["echelle"] / RED, E["echelle"], ox, oy)
    P = D["roues"]["pneus"]
    for mx, my, cote in C["moyeux"]:
        nom = P[c["pneu_av"] if cote == "av" else c["pneu_ar"]][cote]
        e = D["roues"]["echelle_" + cote]
        im = img(nom)
        poser(fond, im, mx - im.width * e / RED / 2, my - im.height * e / RED / 2, e, ox, oy)
    K = D["cabine"]
    poser(fond, img(K["image"]), K["x"], K["y"], K["echelle"], ox, oy)
    T = D["trappe"]; im = img(T["image"])
    if ouverte:
        im = im.rotate(-T["ouverture_deg"], center=(T["pivot"][0] * RED, T["pivot"][1] * RED), expand=False, resample=Image.BICUBIC)
    poser(fond, im, T["x"], T["y"], T["echelle"], ox, oy)
    A = D["ancrages"]
    for k in ("porte_avant", "porte_arriere", "moteur", "feu"):
        d.ellipse([ox + A[k] - 8, oy + D["sol"] - 8, ox + A[k] + 8, oy + D["sol"] + 8], fill=(220, 30, 30, 255))
    d.ellipse([ox + A["toit"][0] - 8, oy + A["toit"][1] - 8, ox + A["toit"][0] + 8, oy + A["toit"][1] + 8], fill=(30, 30, 220, 255))
    pl = C["plateau"]
    d.line([(ox + pl[0], oy + C["rail"]), (ox + pl[1], oy + C["rail"])], fill=(0, 160, 0, 255), width=4)
    fond.convert("RGB").save(a[0])


if __name__ == "__main__":
    main()
