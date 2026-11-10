#!/usr/bin/env python3
"""Génère 10 véhicules 2D simples (formes, pièces, assemblages) — DEC-222.
Usage : python3 tools/gen_vehicules.py   (idempotent : réécrit les entrées listées ci-dessous)
Formes dessinées par le code (vehicule_dessin.gd) ; les vraies textures viendront plus tard."""
import json, os
R = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "game", "data")


def charger(n):
    return json.load(open(os.path.join(R, n), encoding="utf-8"))


def ecrire(n, d):
    with open(os.path.join(R, n), "w", encoding="utf-8") as f:
        json.dump(d, f, ensure_ascii=False, indent=2)
        f.write("\n")


FORMES = charger("formes_vehicules.json")
BMW = FORMES["vehicules"]["moto_bmw"]


def moto(nom, L, fiche, tank=1.0, garde_boue=False):
    s = L / 2.35
    formes = json.loads(json.dumps(BMW["formes"]))
    for o in formes:
        for k in ("pts", "ligne"):
            if k in o:
                o[k] = [[round(p[0] * s, 3), p[1]] for p in o[k]]
        if "arc" in o:
            a = o["arc"]
            o["arc"] = [round(a[0] * s, 3)] + a[1:]
    if tank != 1.0:   # réservoir plus ou moins haut
        formes[1]["pts"] = [[p[0], round(0.72 + (p[1] - 0.72) * tank, 3)] for p in formes[1]["pts"]]
    if garde_boue:
        formes.append({"arc": [round(1.9 * s, 3), 0.33, 0.47, 10, 170, 0.1], "c": "sombre", "z": 2})
    return {"nom": nom, "longueur": L, "hauteur": 1.3, "teinte": "pillards", "moteur": "moto", "course": 0.08, "fiche": fiche,
            "roues": [{"x": round(0.45 * s, 3), "r": 0.33}, {"x": round(1.9 * s, 3), "r": 0.33}], "roues_fond": [],
            "formes": formes, "armes": [], "equipage": [{"x": round(0.92 * s, 3), "y": 0.86, "role": "conducteur"}]}


def voiture(nom, L, H, pts, vitres, rx, fiche, extra=None, arme_x=2.0):
    formes = [{"pts": pts, "c": "caisse", "z": 1}]
    formes += [{"pts": v, "c": "vitre", "z": 2} for v in vitres]
    formes.append({"pts": [[L - 0.12, 0.45], [L, 0.45], [L, 0.8], [L - 0.14, 0.84]], "c": "metal", "z": 2})
    formes += [{"arc": [x, 0.34, 0.43, 10, 170, 0.07], "c": "sombre", "z": 2} for x in rx]
    formes += extra or []
    return {"nom": nom, "longueur": L, "hauteur": round(H + 0.15, 2), "teinte": "pillards", "moteur": "voiture", "course": 0.09, "fiche": fiche,
            "roues": [{"x": x, "r": 0.34} for x in rx], "formes": formes,
            "armes": [{"type": "mitrailleuse", "x": arme_x, "y": round(H + 0.02, 2), "pied": 0.12, "long": 1.0, "ep": 0.04}],
            "equipage": [{"x": round(arme_x - 0.1, 2), "y": round(H - 0.3, 2), "role": "tireur", "h": 0.4}]}


def camion(nom, L, H, cab, essieux, fiche, benne="toile"):
    """cab : x du début de la cabine. Benne à gauche, cabine puis capot à droite."""
    hb = round(H - 0.55, 2)
    formes = [
        {"pts": [[0.2, 0.62], [L - 0.15, 0.62], [L - 0.15, 0.8], [0.2, 0.8]], "c": "sombre", "z": 0},
        {"pts": [[0.0, 0.8], [cab - 0.05, 0.8], [cab - 0.05, hb], [0.0, hb]], "c": benne, "z": 1},
        {"ligne": [[0.02, 1.2], [cab - 0.07, 1.2]], "ep": 0.025, "c": "sombre", "z": 2},
        {"pts": [[cab, 0.8], [cab + 1.05, 0.8], [cab + 1.05, 1.5], [cab + 0.95, H - 0.08], [cab + 0.1, H - 0.06], [cab, H - 0.15]], "c": "caisse", "z": 1},
        {"pts": [[cab + 0.5, 1.6], [cab + 0.95, 1.6], [cab + 0.9, round(H - 0.25, 2)], [cab + 0.5, round(H - 0.25, 2)]], "c": "vitre", "z": 2},
        {"pts": [[cab + 1.05, 0.8], [L - 0.05, 0.8], [L, 1.45], [cab + 1.05, 1.55]], "c": "caisse", "z": 1},
        {"pts": [[L - 0.12, 0.85], [L, 0.85], [L, 1.45], [L - 0.1, 1.45]], "c": "metal", "z": 2},
    ]
    formes += [{"arc": [x, 0.47, 0.57, 10, 170, 0.08], "c": "caisse", "z": 1} for x in essieux]
    return {"nom": nom, "longueur": L, "hauteur": round(H + 0.1, 2), "teinte": "pillards", "moteur": "camion", "course": 0.1, "fiche": fiche,
            "roues": [{"x": x, "r": 0.45} for x in essieux], "formes": formes,
            "armes": [{"type": "mitrailleuse", "x": round(cab + 0.3, 2), "y": round(H + 0.02, 2), "pied": 0.22, "long": 1.1, "ep": 0.045}],
            "equipage": [{"x": round(cab + 0.4, 2), "y": round(H - 0.4, 2), "role": "tireur", "h": 0.4},
                         {"x": 1.4, "y": 1.15, "role": "passager", "debout": True}]}


def S(poids, pv, blind, res, grille, vmax, charge, pds_roul, pv_roul, ch, conso, pv_mot, sieges, ouvert, style):
    return dict(poids=poids, pv=pv, blind=blind, res=res, grille=grille, vmax=vmax, charge=charge, pds_roul=pds_roul, pv_roul=pv_roul,
                ch=ch, conso=conso, pv_mot=pv_mot, sieges=sieges, ouvert=ouvert, style=style)


peugeot = voiture("Peugeot 202", 4.2, 1.5,
    [[0.08, 0.4], [0.05, 0.85], [0.55, 1.0], [1.0, 1.42], [2.3, 1.48], [2.7, 1.08], [3.0, 1.0], [4.0, 0.98], [4.18, 0.8], [4.15, 0.42], [3.8, 0.38], [0.4, 0.38]],
    [[[1.12, 1.04], [1.7, 1.04], [1.7, 1.38], [1.22, 1.36]], [[1.8, 1.04], [2.5, 1.04], [2.32, 1.4], [1.8, 1.4]]],
    [0.95, 3.5], "Berline française à calandre fuselée. Toit percé pour un tireur.", arme_x=1.8)
juva = voiture("Renault Juvaquatre", 3.95, 1.55,
    [[0.05, 0.42], [0.05, 1.0], [0.2, 1.5], [2.1, 1.52], [2.45, 1.05], [3.8, 0.98], [3.93, 0.8], [3.9, 0.42], [0.4, 0.38]],
    [[[0.35, 1.05], [1.0, 1.05], [1.0, 1.42], [0.4, 1.42]], [[1.1, 1.05], [2.0, 1.05], [2.0, 1.42], [1.1, 1.42]]],
    [0.95, 3.25], "Petite berline break, coffre haut. Légère et nerveuse.", arme_x=1.3)
kubel = voiture("Volkswagen Kübelwagen", 3.73, 1.45,
    [[0.08, 0.5], [0.08, 0.95], [1.1, 0.98], [1.15, 1.2], [1.3, 0.98], [3.6, 1.0], [3.7, 0.85], [3.7, 0.5]],
    [[[1.35, 1.0], [1.45, 1.0], [1.5, 1.45], [1.4, 1.45]]],
    [0.65, 3.0], "Voiturette tout-terrain légère, caisse ouverte. Équipage 2.", extra=[{"ligne": [[0.1, 0.98], [1.1, 0.98]], "ep": 0.04, "c": "sombre", "z": 2}], arme_x=0.9)
type_h = voiture("Citroën Type H", 4.28, 1.95,
    [[0.05, 0.42], [0.05, 1.9], [2.7, 1.92], [3.05, 1.55], [3.45, 1.15], [4.2, 1.05], [4.26, 0.8], [4.22, 0.42], [0.4, 0.38]],
    [[[2.75, 1.45], [3.05, 1.45], [3.0, 1.8], [2.78, 1.82]], [[3.12, 1.2], [3.4, 1.2], [3.4, 1.5], [3.12, 1.5]]],
    [0.85, 3.5], "Fourgon à tôle ondulée, cabine avancée. Transport de marchandises.",
    extra=[{"ligne": [[0.1, 0.75 + 0.3 * k], [2.65, 0.75 + 0.3 * k]], "ep": 0.02, "c": "sombre", "z": 2} for k in range(4)], arme_x=2.5)
blitz = camion("Opel Blitz 3 t", 6.0, 2.6, 3.45, [1.3, 4.9], "Camion de 3 tonnes allemand, bâche tendue. Mitrailleuse sur la cabine.")
cckw = camion("GMC CCKW 353", 6.9, 2.75, 4.0, [1.2, 2.3, 5.7], "Camion américain 6×6 de 2,5 tonnes. Le cheval de trait des armées.")
laffly = camion("Laffly S15", 5.6, 2.55, 3.15, [1.2, 4.6], "Camion militaire français à plateau ridelles.", benne="bois")

# id : (forme, stats, arme jetée par les ennemis ou None)
V = {
    "moto_zundapp": (moto("Zündapp KS 750", 2.4, "Moto lourde de la Wehrmacht. Un pilote."),
                     S(400, 38, 1, 9, [10, 6], 8.0, 260, 24, 10, 26, 1.0, 30, 1, True, "ouverte"), "molotov"),
    "moto_harley": (moto("Harley-Davidson WLA", 2.25, "Moto de liaison américaine, réservoir large, garde-boue enveloppant.", tank=1.25, garde_boue=True),
                    S(236, 34, 1, 9, [10, 6], 8.5, 240, 22, 9, 23, 0.9, 28, 1, True, "ouverte"), "molotov"),
    "moto_gnome": (moto("Gnome & Rhône AX2", 2.2, "Moto légère française, rapide mais fragile.", tank=0.8),
                   S(170, 28, 0, 7, [9, 6], 9.0, 200, 18, 8, 18, 0.7, 24, 1, True, "ouverte"), "lance_explosive"),
    "peugeot_202": (peugeot, S(700, 62, 3, 13, [18, 7], 6.2, 1100, 85, 38, 40, 1.3, 32, 2, False, "voiture"), None),
    "juvaquatre": (juva, S(780, 58, 3, 12, [17, 7], 6.0, 1000, 82, 36, 36, 1.2, 30, 2, False, "voiture"), "molotov"),
    "kubelwagen": (kubel, S(715, 52, 2, 12, [14, 7], 6.4, 1000, 80, 34, 25, 1.0, 28, 2, True, "ouverte"), "lance_explosive"),
    "citroen_h": (type_h, S(1100, 75, 4, 18, [20, 9], 5.2, 1500, 110, 42, 46, 1.9, 38, 2, False, "camion"), None),
    "opel_blitz": (blitz, S(3200, 105, 5, 30, [24, 10], 5.0, 3000, 220, 52, 75, 2.6, 46, 2, False, "camion"), None),
    "gmc_cckw": (cckw, S(4500, 120, 5, 35, [27, 10], 5.2, 4000, 290, 58, 90, 3.2, 52, 2, False, "camion"), None),
    "laffly_s15": (laffly, S(3600, 100, 4, 28, [23, 10], 4.8, 3200, 230, 52, 70, 2.8, 45, 2, False, "camion"), None),
}

pieces = charger("pieces.json")
ass = charger("assemblages.json")
for vid, (forme, st, jet) in V.items():
    FORMES["vehicules"][vid] = forme
    nom = forme["nom"]
    P = pieces["pieces"]
    P["chassis_" + vid] = {"famille": "chassis", "nom": "Châssis " + nom, "grille": st["grille"], "poids_kg": st["poids"], "pv": st["pv"],
                           "blindage": st["blind"], "reservoir": st["res"], "metal": 3}
    P["roulement_" + vid] = {"famille": "roulement", "nom": "Roues " + nom, "type": "roues", "vitesse_max": st["vmax"], "charge_kg": st["charge"],
                             "poids_kg": st["pds_roul"], "pv": st["pv_roul"], "emprise": [st["grille"][0] - 1, 3], "metal": 2}
    P["suspension_" + vid] = {"famille": "suspension", "nom": "Suspension " + nom, "poids_kg": 55, "pv": 25, "emprise": [st["grille"][0] // 2, 1], "metal": 1}
    P["moteur_" + vid] = {"famille": "moteur", "nom": "Moteur " + nom, "puissance_ch": st["ch"], "conso": st["conso"], "poids_kg": 120, "pv": st["pv_mot"],
                          "emprise": [5, 2], "metal": 2}
    if st["sieges"] == 1:   # moto : selle
        P["cabine_" + vid] = {"famille": "cabine", "nom": "Selle " + nom, "sieges": 1, "ouvert": True, "poids_kg": 8, "pv": 8, "emprise": [2, 1], "metal": 0, "style": st["style"]}
    else:
        P["cabine_" + vid] = {"famille": "cabine", "nom": "Cabine " + nom, "sieges": 2, "ouvert": st["ouvert"], "poids_kg": 110, "pv": 28, "emprise": [7, 2],
                              "metal": 1, "style": st["style"]}
    g = st["grille"]
    pieces_a = [{"piece": "roulement_" + vid, "pos": [0, 0]}, {"piece": "suspension_" + vid, "pos": [g[0] // 3, 2]},
                {"piece": "moteur_" + vid, "pos": [g[0] - 6, 4]}, {"piece": "cabine_" + vid, "pos": [g[0] // 3 + 1, 4]}]
    if st["sieges"] == 2:
        pieces_a.append({"piece": "arme_mitrailleuse", "pos": [g[0] // 3 + 2, g[1] - 1]})
    ass["assemblages"][vid] = {"nom": nom, "chassis": "chassis_" + vid, "plaques": 0, "pieces": pieces_a}

ecrire("formes_vehicules.json", FORMES)
ecrire("pieces.json", pieces)
ecrire("assemblages.json", ass)
print("jets :", {k: v[2] for k, v in V.items() if v[2]})
