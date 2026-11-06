# État du projet — Folie Mécanique

Mis à jour : 2026-11-06. Résumé volontairement court (≈ 60 lignes). Détails : [`docs/DECISIONS.md`](docs/DECISIONS.md), [`docs/INDEX.md`](docs/INDEX.md).

## Cap (recentrage du 06/11, DEC-091 à DEC-102)

- **Référence unique : la Bible du lore** ([`docs/lore/01_BIBLE_FOUNDATION`](docs/lore/01_BIBLE_FOUNDATION)). Les documents du jeu s'y conforment.
- **Convoi seulement** (DEC-099) : plus de gestion de base ni de ressources de base ; au plus un checkpoint ou un garage par chapitre.
- **Joueur** : chef d'un convoi indépendant, qui a déjà un camion et fait des rotations dans le no man's land (DEC-100).
- **Monde** : climat pauvre, faune rare (DEC-093, 097) ; zones séparées par un no man's land (DEC-095) ; carte de 12 ou 13 secteurs,
  France reconnaissable mais déformée (DEC-101) ; factions de la Bible (DEC-098) ; essence et gazole seulement (DEC-094).
- **Du prototype, on garde la grille** ; le reste est réexaminé face à la Bible (DEC-092).
- **Ouverture** : cinématique vidéo, idée décrite dans [`docs/scenario/OUVERTURE.md`](docs/scenario/OUVERTURE.md) (DEC-102).

## Ce qui existe

- Prototype Godot 4.3 / GDScript dans `game/`, publié sur GitHub Pages ([`game/LISEZMOI.md`](game/LISEZMOI.md)). Tests sans écran dans `game/tests/`.
- Mode convoi : combat, embuscades, poursuites et abordages, relief, carte, nuit et abri, fouille, garage, sauvegarde, sons
  ([`docs/design/CONVOI.md`](docs/design/CONVOI.md)). Une partie de ce contenu est à réexaminer (DEC-092).
- **Grille de construction** (DEC-034 à DEC-083) : châssis, essieux, roues, suspensions, moteurs, coques, tôles, greffes,
  radiateurs, remorques, plans enregistrés ([`docs/design/GRILLE.md`](docs/design/GRILLE.md)). Classe « Véhicule léger » (DEC-096).
- Gestion de base supprimée du dépôt (DEC-107). Données : véhicules (275 lignes), armes et composants dans [`data/master/`](data/master/INDEX.md) ; catalogue historique des armes,
  première passe de 15 armes (DEC-103, sources à renseigner).
- Direction artistique : [`docs/art/DIRECTION_ARTISTIQUE.md`](docs/art/DIRECTION_ARTISTIQUE.md) (DEC-085). Audio : ElevenLabs (DEC-084, 090).
- Dernier audit : [`docs/audits/AUDIT_2026-10-31.md`](docs/audits/AUDIT_2026-10-31.md).

## À vérifier sur iPhone (non vérifiable hors appareil)

Boutons atteignables, taille des cases de la grille, rechargements (DEC-056, 059), son en mode normal et silencieux (DEC-030, 041),
postes et bancs (DEC-062 à 064), interface allégée (DEC-065), construction en deux plans (DEC-067, 068), poursuites (DEC-077).

## À coder (décidé, pas encore fait)

Nouvelle ouverture (DEC-100), factions de la Bible (DEC-098), meutes rares et oiseaux (DEC-097), essence et gazole par moteur (DEC-094).

## Contradictions traitées le 06/11

- Passages périmés de VISION, CONVOI et GRILLE archivés (DEC-105) ; tâches de base archivées (DEC-106) ; modèle économique : démo + déblocage (DEC-104).
- Restent : le code du prototype garde l'ancienne ouverture et les factions 1-2-3 (DEV-002, DEV-003) ; tâches dépendantes à réviser (OQ-019).

## Décisions ouvertes

Toutes les questions, avec identifiant, sont dans [`docs/OPEN_QUESTIONS.md`](docs/OPEN_QUESTIONS.md).

## Carte du dépôt

| Chemin | Contenu |
|---|---|
| `AGENTS.md` | Règles pour développeurs et IA |
| `docs/INDEX.md` | Navigation et sources de vérité |
| `docs/DOCUMENT_REGISTRY.md` | Registre de tous les documents importants |
| `docs/lore/` | Bible du monde (réutilisable) |
| `docs/design/`, `docs/scenario/` | Choix propres à ce jeu |
| `game/` | Prototype Godot |
| `data/master/`, `data/rules/` | Tableaux et règles |
| `archive/` | Éléments en sommeil |
| `tools/` | Scripts |
