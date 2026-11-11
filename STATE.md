# État du projet — Folie Mécanique

Mis à jour : 2026-11-10. Résumé court, par thème. Journal complet : [`docs/DECISIONS.md`](docs/DECISIONS.md) ; **index par thème : [`docs/DECISIONS_INDEX.md`](docs/DECISIONS_INDEX.md)** ; navigation : [`docs/INDEX.md`](docs/INDEX.md) ; questions : [`docs/OPEN_QUESTIONS.md`](docs/OPEN_QUESTIONS.md).

## Cap

- **Référence unique : la Bible du lore** ([`docs/lore/01_BIBLE_FOUNDATION`](docs/lore/01_BIBLE_FOUNDATION)) ; les documents du jeu s'y conforment (DEC-091).
- **Roguelite de convoi** : plus de gestion de base (DEC-099). Le joueur est chef d'un convoi indépendant dont le camion principal est le **Berliet GDR**, du début à la fin (DEC-100, 139).
- **Jalon courant : finir le Kit de développement** (DEC-171) : décor complet par zone, rencontres, équilibrage en direct. La quête principale vient après.
- **Monde libre**, difficulté artificiellement trop forte hors de la région de la quête, signalée par des indices diffus (DEC-172). 12 à 13 secteurs, France déformée (DEC-101, 154, 170). **Échec** : retour au dernier checkpoint (DEC-173, 189).
- **Combat** : les véhicules agissent seuls ; le joueur réordonne les vignettes (DEC-174, 177, 186). Un seul bouton de marche (DEC-160).
- **Publication** : démo + déblocage (DEC-104), prix visé ≈ 5 € (DEC-198), français et anglais dès le début (DEC-193), iPhone 14 Pro Max et plus (DEC-196). Pas de date cible (DEC-204).

## Ce qui existe

- Prototype Godot 4.3 / GDScript dans `game/`, publié sur GitHub Pages ([`game/LISEZMOI.md`](game/LISEZMOI.md)). Tests sans écran et captures dans `game/tests/`, lancés par GitHub Actions.
- **Convoi** : combat, embuscades, poursuites, abordages, relief, carte, nuit, fouille, garage, sauvegarde, sons ([`docs/design/CONVOI.md`](docs/design/CONVOI.md)).
- **Grille** de construction et **Grille V2** (bases véhicule, transformations, camp de réparation) : [`docs/design/GRILLE.md`](docs/design/GRILLE.md).
- **Berliet GDR** : dessiné par l'art en pièces interchangeables, modules arrière, halte animée dans la vitrine du Kit, **valeurs de jeu branchées sur le combat (10/11, DEC-205)**.
- **Villes** standard et **missions du maire** (cargaison, escorte, livraison), **ville pillée**, eau et vivres : [`docs/design/VILLES.md`](docs/design/VILLES.md).
- **Carte du monde** du Kit (13 villes, 22 routes, 30 lieux, régions) : [`docs/design/CARTE.md`](docs/design/CARTE.md).
- **Interface** : HUD en verre fumé, polices OFL, paysage forcé (DEC-149, 155), icône et chargement (DEC-156).
- Données : [`data/master/`](data/master/INDEX.md) ; art : [`docs/art/DIRECTION_ARTISTIQUE.md`](docs/art/DIRECTION_ARTISTIQUE.md) ; audio : ElevenLabs.
- **Entretiens du chef programmeur** (10/11) : [`docs/design/ENTRETIEN_CHEF_PROG.md`](docs/design/ENTRETIEN_CHEF_PROG.md).

## À vérifier sur iPhone

Textes et boutons du HUD, fluidité des villes et de la ville pillée, scènes de mission, portrait couché (DEC-155), icône et chargement (DEC-156), bouton de marche.

## Prochains lots (ordre validé : DEC-206)

0. **Lot A fait (10/11)** : Kit → groupes sur mesure, région de la quête, équilibrage en direct (DEV-037).

1. **Lot B : fondations** : **fait** : essence et gazole avec capacité (DEC-207), textes fr/en pour le journal et le HUD (DEC-208, 209), découpage de `vue_interface.gd` et `construction_libre.gd` (DEC-210). **Reste, repris plus tard** : textes de l'éditeur de grille, des menus et des données ; découpage de `editeur_grille.gd`.
2. **Lot C : carte branchée au jeu** : **fait pour l'essentiel** (DEC-216) : 13 villes fixes, voyage par les routes, décor par zone, +3 niveaux hors Armorique. **Reste** : décor complet par région, tempêtes de désert, rumeurs qui annoncent le danger, voyage de plusieurs étapes d'un coup.
3. **Lot D : factions, réputation, rangs, aide** : **fait** (DEC-217). **Reste** : portières du Berliet (DEV-021), convois alliés ou ennemis sur la route, autres actes de réputation.
4. **Lot E : la route** : **fait** (DEC-218) : voyage de plusieurs étapes, convois alliés et hostiles, rumeurs, tempêtes de désert. **Reste** : décor complet par région (DEV-008), zones habitées calmes (DEV-007).
5. **Lot F : combat vivant** : **fait** (DEC-219 à 222) : béliers et harceleurs, Molotov, lances explosives, feu et explosions, couleurs de faction, 10 véhicules à noms réels, équilibrage de base. **Non vérifié sur iPhone** : fanion et teinte de faction, flammes, harcèlement par derrière, lisibilité des explosions.
6. **Lot physique : pneus et suspensions** : conception décidée le 11/11 (DEC-230, `docs/design/PHYSIQUE.md`) ; code à faire (DEV-041).
4. Gelé jusqu'à la fin du Kit : train, centrale, gazogène, caches, boss, lot motos et side-cars.

## Décisions ouvertes

OQ-025 à 037 (037 : boue, neige, dégagement) : retour au checkpoint, réputation, épaves, prix / durée / art (OQ-035), capacité du réservoir (OQ-036). Projets pour plus tard : [`docs/design/PROJETS.md`](docs/design/PROJETS.md).

## Méthode de travail

Claude fusionne lui-même dans `main` ; la page web se reconstruit seule ; gros lots espacés, tests iPhone par le créateur après chaque lot (DEC-175) ; captures automatiques dans GitHub Actions.

## Carte du dépôt

| Chemin | Contenu |
|---|---|
| `AGENTS.md` | Règles pour développeurs et IA |
| `docs/INDEX.md` | Navigation et sources de vérité |
| `docs/DECISIONS_INDEX.md` | Décisions classées par thème |
| `docs/lore/` | Bible du monde (réutilisable) |
| `docs/design/`, `docs/scenario/` | Choix propres à ce jeu |
| `game/` | Prototype Godot |
| `data/master/`, `data/rules/` | Tableaux et règles |
| `archive/` | Éléments en sommeil |
| `tools/` | Scripts |
