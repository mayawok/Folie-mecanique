# Passages archivés le 06/11/2026

Passages retirés de `docs/design/` car ils contredisent la Bible du lore et DEC-091 à DEC-102 (décision du porteur de projet : archiver).
Texte repris tel quel. Le code correspondant du prototype n'est pas modifié (voir tâches DEV-002, DEV-003).

## VISION : biomes, joueur, rythme, modèle économique
Source : `docs/design/VISION.md`. Raison : désert pur et chef de communauté contredits par DEC-093, 097, 100 ; rythme de base par DEC-099 ; modèle économique remplacé (DEC-104)

- **Joueur** : chef de communauté.
- **Biomes** : zones désertiques très arides, zones enneigées. Peu de végétation et de vie :
  la rareté est la difficulté centrale.
- **Rythme** : jeu à temps longs. Une session courte (≈ 5 min) sert à lancer des
  expéditions simples, des démantèlements d'épaves, la construction de véhicules,
  réaffecter les travailleurs, vérifier les ressources, lancer des améliorations de cuves.
- **Modèle économique** : gratuit avec achats intégrés, sans publicité.

## VISION : Expéditions (base, siège, défense de base)
Source : `docs/design/VISION.md`. Raison : dépend d'une base (DEC-099)

## Expéditions (décidé)

- **Carte stratégique** : la base, les villes, les points d'intérêt. Le joueur choisit la
  destination et l'itinéraire.
- **Ordres permanents**, définis au départ et modifiables en route. Exemple : s'arrêter
  dès que des ressources sont récupérables (plus long, plus de butin) ou aller droit au but.
- **Trajet** : événements aléatoires légers (pillards, pannes) qui ralentissent le convoi
  ou peuvent détruire des véhicules.
- **Prise de contrôle** possible aux points d'intérêt, pas dans les zones désertiques.
- **Vue de combat** de profil, en temps réel : ordre des véhicules visible et modifiable
  (chars devant, camions derrière, camions envoyés ravitailler), cessez-le-feu, motos en
  éclaireur, ensemble complet d'ordres tactiques.
- **Joueur absent à un point d'intérêt** : le convoi applique l'ordre prévu à l'avance
  et le joueur reçoit une notification décrivant la situation.
- **Attente / siège** : option pour que le convoi attende devant une cible (ex. grande ville).
  Il consomme ses ressources pendant l'attente, peut se fortifier et doit se protéger
  des animaux sauvages.
- **Défense de la base** : même vue ; la plupart des défenses sont automatiques.
- **Première version** : peut être uniquement tactique (sans prise de contrôle), mais
  l'architecture doit prévoir la vue contrôlée dès le départ.

## VISION : renvoi à ACHATS.md
Source : `docs/design/VISION.md`. Raison : ACHATS.md est archivé (DEC-031) ; modèle remplacé (DEC-104)

- ~~Nature des achats intégrés~~ : décidé, voir `ACHATS.md`.

## CONVOI : ouverture guidée et ancien départ
Source : `docs/design/CONVOI.md`. Raison : remplacés par le nouveau départ (DEC-100)

- **Ouverture guidée (DEC-035)** : une caisse de pièces au bord de la route. L'atelier sur grille s'ouvre :
  le joueur glisse cadre, roues, fourche, moteur et selle à leur place → **moto BMW R75**, un pilote, 4 L d'essence,
  pas d'arme. Puis, dans l'ordre, sans aucun ennemi : **grange** (attelage, panier, roue de side-car + un survivant)
  → le convoi s'arrête, bouton « Assembler » → **side-car** au bord de la route ; **maison** (20 L d'essence) ;
  **bunker** (mitrailleuse, 80 munitions, métal) → « Assembler » monte l'arme. Les ennemis et les rôdeurs de nuit
  n'arrivent qu'une fois une arme trouvée. Données : bloc `ouverture` de `combat_proto.json`.
- Ancien départ (Willys MB, 2 survivants, ruine + BMW) : conservé pour les tests (`CombatModele.new(graine)`).

## CONVOI : carte à factions 1 à 3
Source : `docs/design/CONVOI.md`. Raison : factions de la Bible (DEC-098) et carte déformée (DEC-101)

- **Carte** : 12 secteurs aléatoires (nom, faction 1 à 3, niveau 0 à 7) sur l'image de carte. Le joueur touche un secteur puis
  « Partir » : une **zone calme** sans rencontre (250 m + 900 m par unité de distance) assure la continuité en 2D, puis le niveau
  des rencontres suit le secteur. Relations (provisoires) : faction 1 alliée, 2 neutre, 3 hostile.

## GRILLE : atelier guidé de la moto et du side-car
Source : `docs/design/GRILLE.md`. Raison : ouverture remplacée par DEC-100

## Atelier guidé : la moto et le side-car (DEC-035, 31/10)

Demande du porteur de projet : **tout commence par la grille**. Le joueur part d'une caisse de pièces et assemble
lui-même son premier véhicule ; la liberté viendra plus tard avec les gros véhicules.

- **Pièces découpées dans le dessin** de la BMW R75 : cadre (avec réservoir et garde-boue), roue arrière, roue avant,
  fourche et guidon, moteur, selle ; puis attelage, panier et roue du panier ; mitrailleuse. Une pièce posée à sa place
  se dessine exactement comme sur la route.
- **Peu de liberté** : chaque pièce n'a qu'un emplacement, dessiné en pointillés avec un fantôme ; le cadre se pose
  d'abord ; le panier et sa roue demandent l'attelage (`requiert`). Lâchée ailleurs, la pièce revient dans le bac.
- **Trois apparences** selon les pièces montées : moto seule (8,5 m/s, 1 place), side-car (7,5 m/s, 2 places),
  side-car armé (statistiques identiques à l'ancienne BMW R75). Règles `apparences` de `pieces.json`.
- **Couches** : le panier, sa roue et l'attelage ont leurs propres couches (ils passent derrière la moto en profil).
- **Au bord de la route** : bouton « Assembler » quand le convoi est arrêté, sans ennemi proche, et qu'une
  amélioration est possible avec la réserve de pièces (`atelier_possible()`).
- Code : `scripts/combat/modele_atelier.gd` (logique), `scripts/vehicules/atelier_grille.gd` (écran).
  Tests : `test_ouverture.gd` (21 vérifications), `capture_atelier.gd` (parcours joué à l'écran, captures).

**Pour les gros véhicules (prochaine étape)** : même méthode, pièce par pièce depuis leur dessin ; plus de liberté
(plusieurs emplacements possibles, pièces de rechange d'un autre véhicule), puis la grange la nuit (G2).
