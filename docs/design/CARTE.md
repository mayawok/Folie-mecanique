# Carte du monde — Folie Mécanique

Statut : **carte de conception codée dans le Kit le 09/11 (DEC-154)**. Proposition de travail : villes, routes et lieux sont à
valider ou à corriger par le créateur (OQ-010, OQ-011). Code : `game/scripts/carte_monde.gd` (logique), `game/scripts/combat/carte_kit.gd`
(écran), `CombatModele.kit_aller` (voyage) ; données : `game/data/carte_monde.json` ; fond : `game/assets/carte/carte_france.jpg` ;
test : `game/tests/test_carte.gd` ; captures : `game/tests/capture_carte.gd`. Aperçu : `docs/design/carte_monde_apercu.jpg`.

## Principe

- Fond : la carte de France usée, floutée et déformée fournie par le créateur (DEC-101).
- **Kit (Mode créatif)** : tout est affiché, c'est l'outil de conception. Dans le jeu final, la carte se découvrira peu à peu
  (le joueur ne sait rien au départ, DEC-101).
- Kit → « Carte du monde » : glisser pour déplacer, pincer ou + / − pour zoomer ; toucher un lieu ouvre sa fiche ;
  **« Y aller »** conduit le convoi au lieu ; « Itinéraire depuis ma position » surligne le plus court chemin par les routes.
- Couches affichables : villes, routes, ressources, sites, factions, dangers (niveau des villes, danger de chaque route), légende.
- Repère « vous êtes ici » : le dernier lieu rejoint dans le Kit.

## Voyage depuis le Kit

| Lieu | Effet de « Y aller » |
|---|---|
| Ville-étape | la ville est posée juste devant le convoi, avec son nom, son maire et son niveau ; la zone de décor suit la ville |
| Lieu avec bâtiment (dépôt, bunker, péage, point d'eau) | la zone de décor suit le lieu ; le bâtiment apparaît devant |
| Autre lieu | la zone de décor suit le lieu, le repère se déplace |

Refusé hors Mode créatif et pendant une mission du maire.

## 13 villes-étapes (une par secteur : proposition pour OQ-011)

| Ville | Repère réel | Faction | Niveau |
|---|---|---|---|
| Kerbrume | Rennes | Réseau des Marées | 1 |
| Les Pertuis | La Rochelle | Réseau des Marées | 1 |
| Port-Estuaire | Le Havre | Réseau des Marées | 3 |
| Vieille-Capitale | Paris | Compagnies de l'Est | 5 |
| Fort-des-Puits | Brie (Seine-et-Marne) | Compagnies de l'Est | 4 |
| Les Corons | Lille | Récupérateurs | 4 |
| Rhin-Gris | Strasbourg | Compagnies de l'Est | 7 |
| Pont-de-Loire | Orléans | Récupérateurs | 2 |
| Les Chais-Noirs | Bordeaux | Raffineurs du Sud | 3 |
| Le Terminus | Clermont (Massif central) | Hautes-Terres (communautés ferroviaires) | 3 |
| Confluent | Lyon | Récupérateurs | 5 |
| Massalie | Marseille | Raffineurs du Sud | 4 |
| Hautes-Combes | Alpes | Hautes-Terres | 5 |

Le danger monte de l'ouest (Bretagne, départ conseillé à Kerbrume) vers l'est (Rhin-Gris, fin de partie).

## Routes (22)

Trois types : **route** (entre zones tenues), **piste** (no man's land, DEC-095), **voie ferrée** (rails sur la carte : on roule le long).
Chaque route a un danger de 1 à 7 et une zone de décor. Exemples : Route des grèves (Kerbrume–Les Pertuis, danger 1) ;
Route des citernes (Les Chais-Noirs–Massalie, par Lacq, danger 5) ; Traversée de l'Est (Fort-des-Puits–Rhin-Gris, danger 7).

## Lieux d'intérêt (30)

- **Ressources** : pétrole brut (Brie, Parentis, vieux puits du Rhin), raffineries (Étang, Estuaire), gaz et chimie (Lacq, zone « maudite »),
  mines (charbon, fer, Massif, carrières), eau (sources des Hautes-Terres, lac de montagne, puits artésien), dépôts de carburant
  (Normandie, Loire), épaves et arsenal (Bretagne).
- **Sites** : bunkers (vieille ligne, Alpes, Pyrénées, Nord), antenne des Veilleurs, péages des Hommes du Péage (Landes, Rhône, Nord),
  champs de bataille (Somme, front de Champagne), vallée préservée (rumeur, jamais visitée), déserts (Beauce, Landes).

Tout vient de la Bible (LOC-001 à 012, FAC-001 à 007, 04.1 bis). Ajouter ou déplacer un lieu = une entrée du JSON, sans code.

## Ouvert

- Valider villes, noms, factions et niveaux (OQ-010, OQ-011).
- Brancher la carte au jeu normal (DEV-009) : sorties des villes = routes de la carte (aujourd'hui les portes mènent encore aux secteurs
  aléatoires de `monde.gd`), position du convoi le long de la route, brouillard de découverte.
- La position du Kit n'est pas sauvegardée.
