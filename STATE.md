# État du projet — Folie Mécanique

Mis à jour : 2026-10-31 (board meeting). Fichier à lire en premier (court, à garder < 60 lignes).

## Où on en est

- **Mode convoi jouable** (DEC-026) dans `game/`, publié sur GitHub Pages (`game/LISEZMOI.md`).
  Contenu : embuscade, relief, carte 12 secteurs, camps et factions, nuit et abri, fantassins, voyageurs, fouille,
  survivants, garage (hangar/grange), demi-tour, sauvegarde auto, sons.
- Moteur : Godot 4.3 / GDScript (DEC-001). Passage à la 4.6 proposé.
- Gestion de base, temps réel et achats : **archivés** dans `archive/` (DEC-031).
- Audit du 31/10 : `docs/audits/AUDIT_2026-10-31.md`.

## Décidé, pas encore codé

- Tempête de sable (DEC-027) et champs de mines (DEC-028) : `docs/design/CONVOI.md`.
- Grille « Frankenstein » (DEC-029) : `docs/design/GRILLE.md`, étapes G1 à G4.
- Son : correctif iPhone silencieux et bus audio (DEC-030), à confirmer sur iPhone.

## Décisions ouvertes (à trancher)

1. Identité : roguelite de convoi (recommandé) ou gestion en temps réel.
2. Gel des fonctions pour un cycle d'essais (`docs/design/ESSAIS.md`).
3. But d'une partie et progression entre les parties.
4. Passage à Godot 4.6 ; chemin de compilation iOS sans Mac.

## Prochaines étapes (ordre recommandé)

1. Le porteur de projet joue 3 sessions et remplit `ESSAIS.md` ; confirme le son (iPhone non silencieux et silencieux).
2. Découper `combat_modele.gd` et `convoi_vue.gd` en modules (tests inchangés et verts).
3. Grille G1 : véhicules décrits comme châssis + pièces.
4. Coder tempête et mines.
5. Godot 4.6, puis essai d'export iOS dans le nuage.

## Carte du dépôt

| Chemin | Contenu |
|---|---|
| `AGENTS.md` | Règles pour développeurs et IA |
| `docs/INDEX.md` | Ordre de lecture, sources de vérité |
| `docs/DECISIONS.md` | Journal des décisions |
| `docs/design/` | VISION, CONVOI, GRILLE, LORE, GRAPHISMES, ESSAIS |
| `game/` | Prototype Godot (`scripts/combat/` = mode convoi), tests dans `game/tests/` |
| `data/master/` | Tables (catalogue de composants, grille) |
| `archive/` | Éléments en sommeil (base, temps réel, simulations) |
| `tools/` | Scripts (export Excel → CSV, sons synthétisés, gabarits) |
