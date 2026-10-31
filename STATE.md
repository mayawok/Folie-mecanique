# État du projet — Folie Mécanique

Mis à jour : 2026-10-31 (ouverture moto → side-car sur la grille). Fichier à lire en premier (court, à garder < 60 lignes).

## Où on en est

- **Mode convoi jouable** (DEC-026) dans `game/`, publié sur GitHub Pages (`game/LISEZMOI.md`).
  Contenu : embuscade, relief, carte 12 secteurs, camps et factions, nuit et abri, fantassins, voyageurs, fouille,
  survivants, garage (hangar/grange), demi-tour, sauvegarde auto, sons.
- Moteur : Godot 4.3 / GDScript (DEC-001). Passage à la 4.6 proposé.
- **Identité : roguelite de convoi** (DEC-032). Gestion de base, temps réel et achats : archivés (DEC-031).
- Code découpé en couches (DEC-033, carte des fichiers dans `CONVOI.md`).
- **Grille G1 faite** (DEC-034) : véhicules = châssis + pièces, statistiques calculées (`GRILLE.md`).
- **La partie commence par la grille** (DEC-035) : moto assemblée, puis side-car, essence, arme, ennemis.
- Audit du 31/10 : `docs/audits/AUDIT_2026-10-31.md`.

## Décidé, pas encore codé

- Tempête de sable (DEC-027) et champs de mines (DEC-028) : `docs/design/CONVOI.md`.
- Grille : G2 démontage dans la grange, G3 éditeur au toucher, G4 dessin des assemblages (`GRILLE.md`).
- Son : correctif iPhone silencieux et bus audio (DEC-030), à confirmer sur iPhone.

## Décisions ouvertes (à trancher)

1. Modèle économique adapté au roguelite (prix unique, démo + déblocage, cosmétiques).
2. Gel des fonctions pour un cycle d'essais (`docs/design/ESSAIS.md`).
3. But d'une partie et progression entre les parties.
4. Passage à Godot 4.6 ; chemin de compilation iOS sans Mac.

## Prochaines étapes (ordre recommandé)

1. Le porteur de projet joue 3 sessions et remplit `ESSAIS.md` ; confirme le son (iPhone non silencieux et silencieux).
2. Atelier pour les gros véhicules (pièces tirées de leur dessin, plus de liberté), puis G2 (grange la nuit).
3. Coder tempête (`modele_meteo.gd`) et mines.
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
