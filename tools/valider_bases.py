#!/usr/bin/env python3
"""Valide game/data/bases.json (Grille V2) : références aux pièces et aux véhicules historiques, cohérence des règles.
Usage : python3 tools/valider_bases.py   (code de sortie 0 = tout est cohérent)"""
import json
import sys
from pathlib import Path

RACINE = Path(__file__).resolve().parent.parent
D = RACINE / "game" / "data"
bases = json.loads((D / "bases.json").read_text(encoding="utf-8"))
pieces = json.loads((D / "pieces.json").read_text(encoding="utf-8"))["pieces"]
hist = json.loads((D / "assemblages.json").read_text(encoding="utf-8"))["assemblages"]
R = bases["regles"]
erreurs = []


def err(t):
    erreurs.append(t)


if int(R["cran_cases"]) < 1:
    err("cran_cases < 1")
for k in ("moteur_sous_dimensionne", "moteur_inadapte_en_plus", "plafond", "etat_mauvais_facteur"):
    if k not in R["usure"]:
        err(f"usure.{k} manquant")
seuils = [v[0] for v in R["verdicts"]]
if seuils != sorted(seuils):
    err("verdicts : seuils non croissants")
for op, v in R["operations"].items():
    if str(v["niveau"]) not in R["niveaux_lieu"]:
        err(f"operation {op} : niveau {v['niveau']} inconnu")
for z in R["blindage"]["zones"]:
    pass
if "aucun" not in R["blindage"]["niveaux"]:
    err("blindage : niveau 'aucun' manquant")
if "atelier_mobile" not in R["modules"] or "duree_camp_mult" not in R["modules"]["atelier_mobile"]:
    err("module atelier_mobile avec duree_camp_mult requis (durées en camp)")
for bid, b in bases["bases"].items():
    if b["historique"] not in hist:
        err(f"{bid} : historique {b['historique']} absent de assemblages.json")
    if b["boite"] not in R["boites"]:
        err(f"{bid} : boîte {b['boite']} inconnue")
    for m in b["modules"]:
        if m not in R["modules"]:
            err(f"{bid} : module {m} inconnu")
        elif R["modules"][m]["cases_min"] > b["plateau_cases"] + R["cran_cases"] * (b["rallonge_max"]["milieu"] + b["rallonge_max"]["arriere"]):
            err(f"{bid} : module {m} impossible même rallongé au maximum")
    for z in ("avant", "milieu", "arriere"):
        if int(b["rallonge_max"][z]) < 0:
            err(f"{bid} : rallonge_max.{z} < 0")
    for k in ("moteur", "boite", "chassis", "essieux"):
        if not 0 < b["etat_origine"][k] <= 1:
            err(f"{bid} : etat_origine.{k} hors de ]0, 1]")
    if b["essieux_max"] < 2:
        err(f"{bid} : essieux_max < 2")
    for p in hist[b["historique"]]["pieces"]:
        if p["piece"] not in pieces:
            err(f"{bid} : pièce historique {p['piece']} absente du catalogue")
for bid in bases["bases"]:
    print("base", bid, "OK" if not any(bid in e for e in erreurs) else "ERREUR")
for e in erreurs:
    print("ERREUR :", e)
print("bases.json cohérent" if not erreurs else f"{len(erreurs)} erreur(s)")
sys.exit(1 if erreurs else 0)
