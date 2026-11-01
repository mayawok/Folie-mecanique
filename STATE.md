# État du projet — Folie Mécanique

Mis à jour : 2026-11-01 (tempête, mines, grille G2 à G4, son renforcé). Fichier à lire en premier (court, à garder < 60 lignes).

## Où on en est

- **Mode convoi jouable** (DEC-026) dans `game/`, publié sur GitHub Pages (`game/LISEZMOI.md`).
  Contenu : embuscade, relief, carte 12 secteurs, camps et factions, nuit et abri, fantassins, voyageurs, fouille,
  survivants, garage (hangar/grange), demi-tour, sauvegarde auto, sons.
- Moteur : Godot 4.3 / GDScript (DEC-001). Passage à la 4.6 proposé.
- **Identité : roguelite de convoi** (DEC-032). Gestion de base, temps réel et achats : archivés (DEC-031).
- Code découpé en couches (DEC-033, carte des fichiers dans `CONVOI.md`).
- **Grille G1 faite** (DEC-034) : véhicules = châssis + pièces, statistiques calculées (`GRILLE.md`).
- **La partie commence par la grille** (DEC-035) : moto assemblée, puis side-car, essence, arme, ennemis.
- **Codés le 01/11** : tempête de sable (DEC-036), champs de mines (DEC-037), grille G2 démontage (DEC-038), G3 éditeur libre
  (DEC-039), G4 dessin des assemblages (DEC-040). Tests : 221 vérifications sans écran + parcours écran (`game/tests/`).
- **Refonte de la grille le 01/11** (DEC-043 à 046) : châssis peint case par case, essieux, roues de trois tailles ou chenilles,
  moteurs, cabines, armes (mitrailleuse, canons, **mortier**) ; tout compatible, mauvais résultats calculés ; grille ouverte
  à tout moment (jeu en pause) ; **menu principal avec Bac à sable**.
- Audit du 31/10 : `docs/audits/AUDIT_2026-10-31.md`.

## À confirmer par le porteur de projet (rien d'autre n'est en attente de code)

- **Son iPhone** (DEC-030, renforcé par DEC-041) : non vérifiable hors appareil. Tester en mode normal puis silencieux.
- Jouer la tempête, les mines et la grange : valeurs à régler dans `combat_proto.json` (`tempete`, `mines_champs`, `demontage`).
- `game/tests/capture_convoi.gd` est un ancien parcours devenu obsolète avec l'ouverture guidée (il n'aboutit pas).

## Décisions ouvertes (à trancher)

1. Modèle économique adapté au roguelite (prix unique, démo + déblocage, cosmétiques).
2. Gel des fonctions pour un cycle d'essais (`docs/design/ESSAIS.md`).
3. But d'une partie et progression entre les parties.
4. Passage à Godot 4.6 ; chemin de compilation iOS sans Mac.

## Prochaines étapes (ordre recommandé)

1. Le porteur de projet essaie le **Bac à sable** (construire, rater, corriger) ; puis joue 3 sessions et remplit `ESSAIS.md` ; confirme le son (iPhone non silencieux et silencieux).
2. Atelier guidé pour les gros véhicules (pièces tirées de leur dessin), art définitif des assemblages.
3. Régler tempête, mines et grange d'après les essais ; trancher la nature du fléau (Sherman Crab) et le chien.
4. Godot 4.6, puis essai d'export iOS dans le nuage.

## Carte du dépôt

| Chemin | Contenu |
|---|---|
| `AGENTS.md` | Règles pour développeurs et IA |
| `docs/INDEX.md` | Ordre de lecture, sources de vérité |
| `docs/DECISIONS.md` | Journal des décisions |
| `docs/design/` | VISION, CONVOI, GRILLE, LORE, GRAPHISMES, ESSAIS |
| `game/` | Prototype Godot (`scripts/combat/` = convoi, `scripts/vehicules/` = pièces), tests dans `game/tests/` |
| `data/master/` | Tables (catalogue de composants, grille) |
| `archive/` | Éléments en sommeil (base, temps réel, simulations) |
| `tools/` | Scripts (export Excel → CSV, sons synthétisés, gabarits) |
