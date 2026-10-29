# Prototype jouable — Folie Mécanique

Boucle minimale : base → expédition → combat automatique → retour avec butin.
But du test : tenir 10 jours. Pas d'horloge réelle : « Passer la journée » avance d'un jour.

## Jouer

Lien du navigateur (PC ou iPhone, en paysage) : https://mayawok.github.io/Folie-mecanique/
Il se met à jour tout seul quelques minutes après chaque envoi qui touche `game/`
(suivi dans l'onglet **Actions** du dépôt).

## Modifier l'équilibrage sans Claude

Toutes les valeurs sont dans `data/regles_proto.json` : stocks de départ, production des
postes, consommation, statistiques des véhicules, lieux, butin, pillards, combat.
Modifier le fichier sur GitHub (icône crayon), enregistrer : le jeu se reconstruit.

## Fichiers

| Fichier | Rôle |
|---|---|
| `scripts/jeu.gd` | Règles et état de la partie (aucun affichage) |
| `scripts/main.gd` | Interface : base, carte, convoi, rapport |
| `data/regles_proto.json` | Valeurs d'équilibrage |
| `assets/` | Images réduites, produites par `tools/export_proto.py` (ne pas modifier à la main) |
| `tests/test_sim.gd` | Test sans écran : `godot --headless --path game -s res://tests/test_sim.gd` |

## Hors prototype

Atelier, sauvegarde, faune, récit, achats, horloge réelle.
Chars (Stuart, Sherman, Tiger I) : pièces provisoires, pas encore dans le jeu.
