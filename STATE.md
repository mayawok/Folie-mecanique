# État du projet — Folie Mécanique

Mis à jour : 2026-11-26. Résumé court, par thème. Journal complet : [`docs/DECISIONS.md`](docs/DECISIONS.md) ; **index par thème : [`docs/DECISIONS_INDEX.md`](docs/DECISIONS_INDEX.md)** ; navigation : [`docs/INDEX.md`](docs/INDEX.md) ; questions : [`docs/OPEN_QUESTIONS.md`](docs/OPEN_QUESTIONS.md).

## Nuit du 25 au 26/11 (chantiers choisis par le créateur, DEC-260 à 264)

- **Appli iPhone native préparée (DEC-260)** : préréglage d'export iOS, icône App Store, réglages natifs, zones sûres ; **guide pas à pas [`docs/MAC_IPHONE.md`](docs/MAC_IPHONE.md)** (compte Apple gratuit). Identifiant provisoire `fr.foliemecanique.prototype` ; suites OQ-055.
- **Transmission finie (DEC-261)** : sauts réels sur des crêtes du relief, balancement et poussée des remorques, basculement des véhicules de la grille trop hauts.
- **Performance iPhone, lot 1 (DEC-262)** : ≈ 440 appels de dessin au lieu de ≈ 1 900 en gros combat, **compteur d'images** dans Options ; mesures à faire sur iPhone (OQ-056, [`docs/design/PERFORMANCE.md`](docs/design/PERFORMANCE.md)).
- **Textes fr/en terminés (DEC-263)** : tout le jeu hors Kit, données traduites au chargement.
- **Décor par région (DEC-264)** : les 12 régions ont leurs plans lointains, objets, couleurs et particules ; choix dans le Kit ; suites OQ-057.

## Cap

- **Référence unique : la Bible du lore** ([`docs/lore/01_BIBLE_FOUNDATION`](docs/lore/01_BIBLE_FOUNDATION)) ; les documents du jeu s'y conforment (DEC-091).
- **Vision actuelle** : [`docs/design/VISION.md`](docs/design/VISION.md) (15/11, DEC-242) : survie et mécanique à parité, mécanique à profondeur facultative, **réseau logistique de convois autonomes** à concevoir ([`docs/design/LOGISTIQUE_CONVOIS.md`](docs/design/LOGISTIQUE_CONVOIS.md), DEC-243 à 248 ; **conception seulement, aucun code**), direction artistique plus lisible et plus colorée (DEC-247).
- **Roguelite de convoi** : plus de gestion de base (DEC-099, partiellement remplacée par DEC-243 : stockage et convois autorisés, base toujours exclue). Le joueur est chef d'un convoi indépendant dont le camion principal est le **Berliet GDR**, du début à la fin (DEC-100, 139).
- **Profondeur visuelle (19/11, DEC-249)** : pas de vraie 3D ; parallaxe sur six plans, brume, ombres, lumières additives et premier plan flou pour les zones dessinées par le code (désert en tête). **À vérifier sur iPhone** : rendu jour, soir, nuit et fluidité.
- **Voies de profondeur (19/11, DEC-250)** : trois voies (fond, route, devant), changements de voie automatiques, abordage par le flanc, coups de flanc, couvert. **À vérifier sur iPhone** ; suites : OQ-048.
- **Formation de combat (19/11, DEC-251)** : annonce et musique de combat, escorteurs sur les flancs du Berliet, bâtiments derrière ou devant la route, phares du Berliet. **À vérifier sur iPhone** (musique de roulage `mus_base`).
- **Interface tactique sobre, lot 1 (20/11, DEC-258)** : radar des menaces, menu déployable ≡, pastilles de ressources à l'apparition, nouveau style des panneaux, feuille du bas pour Survivants et Carte. Lot 2 fait (DEC-259) : vitesse et moteur permanents, feuilles du bas partout, annonces et radar avec distances.
- **Zoom de contact, gore, annonces, pincement (20/11, DEC-257)** : la caméra cadre le point de rencontre dès qu'un ennemi est à moins de 16 m (avant du convoi + arrière de l'autre, ou toute la zone de contact côte à côte) et dézoome avant une ville ; deux doigts = zoom seulement, un doigt = défilement, retour au cadrage après 5 s ; sang, corps sur la route, membres arrachés, débris de carcasses, réglage Gore (coupé / sang / maximum, dans Options) ; annonces attaque avant/arrière, ville en vue, champ de mines. À régler sur iPhone.
- **Corps à corps et armes de fortune (20/11, DEC-255)** : 4 nouvelles armes, variantes chez les ennemis, collisions avec étincelles et débris, abordage en grappe et bagarre, blindés de fortune aux niveaux 5+. À régler en essai sur iPhone.
- **Virage armes de fortune (20/11, DEC-254)** : mitrailleuse réservée au Berliet, pistolets et fusils de chasse ailleurs, gros canons et chars cachés (Kit les garde). **À venir : corps à corps** (collisions voiture contre voiture, abordage riche, moins de tir à distance, effets).
- **Groupes d'ennemis et convoi de départ du Kit (19/11, DEC-253)** : 5 scénarios en 3 tailles, annonce colorée gauche/droite selon l'agressivité, Kit démarre avec un convoi constitué. À régler en essai sur iPhone.
- **Contournement et Berliet HS (19/11, DEC-252)** : le convoi recule puis passe par la voie d'à côté devant un barrage ou une épave ; Berliet hors service = convoi à l'arrêt, réparation sur place. Récupération des alliés abandonnés : à coder (OQ-049).
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

1. **Lot B : fondations** : **fait** : essence et gazole avec capacité (DEC-207), textes fr/en pour le journal et le HUD (DEC-208, 209), découpage de `vue_interface.gd` et `construction_libre.gd` (DEC-210). **Textes terminés le 26/11 (DEC-263)** : éditeur de grille, menus, données. **Reste** : découpage de `editeur_grille.gd`.
2. **Lot C : carte branchée au jeu** : **fait pour l'essentiel** (DEC-216) : 13 villes fixes, voyage par les routes, décor par zone, +3 niveaux hors Armorique. **Reste** : tempêtes de désert, rumeurs qui annoncent le danger, voyage de plusieurs étapes d'un coup (décor par région fait le 26/11, DEC-264).
3. **Lot D : factions, réputation, rangs, aide** : **fait** (DEC-217). **Reste** : portières du Berliet (DEV-021), convois alliés ou ennemis sur la route, autres actes de réputation.
4. **Lot E : la route** : **fait** (DEC-218) : voyage de plusieurs étapes, convois alliés et hostiles, rumeurs, tempêtes de désert. **Décor par région fait le 26/11 (DEC-264)**. **Reste** : zones habitées calmes (DEV-007).
5. **Lot F : combat vivant** : **fait** (DEC-219 à 222) : béliers et harceleurs, Molotov, lances explosives, feu et explosions, couleurs de faction, 10 véhicules à noms réels, équilibrage de base. **Non vérifié sur iPhone** : fanion et teinte de faction, flammes, harcèlement par derrière, lisibilité des explosions.
6. **Lot physique : pneus et suspensions** : **codé le 11/11 (DEC-230, 231, `docs/design/PHYSIQUE.md`), à essayer sur iPhone** : surfaces, enlisement, chocs, crevaisons, rendu par roue, section « Physique » du Kit (DEV-041).
7. **Lot transmission** : **fait** (DEC-232 à 234) ; **limites levées le 25/11 (DEC-261)** : sauts réels sur les crêtes, balancement des remorques, basculement. À essayer sur iPhone.
4. Gelé jusqu'à la fin du Kit : train, centrale, gazogène, caches, boss, lot motos et side-cars.

## Décisions ouvertes

OQ-025 à 037 (037 : boue, neige, dégagement) ; **OQ-041 à 047 : logistique, villes alliées, pannes, temps, personnel, direction artistique** : retour au checkpoint, réputation, épaves, prix / durée / art (OQ-035), capacité du réservoir (OQ-036). Projets pour plus tard : [`docs/design/PROJETS.md`](docs/design/PROJETS.md).

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
