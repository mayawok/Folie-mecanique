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
| Dol (id `kerbrume`, DEC-238) | Mont-Dol, Dol-de-Bretagne | Réseau des Marées (capitale) | 1 |
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

Le danger monte de l'ouest (Bretagne, départ conseillé à Dol) vers l'est (Rhin-Gris, fin de partie).

## Capitales régionales (DEC-239, villes à valider : OQ-040)

Principe décidé : **une grande ville par région**, capitale et lieu majeur du scénario, sur le modèle de Dol. Tout le reste de la carte devient des **lieux mineurs** (hameaux, dépôts, péages, gares, sites). Proposition, à valider région par région :

| Région | Capitale proposée | Repère réel et raison | Alternative |
|---|---|---|---|
| Armorique | **Dol** (validé) | Mont-Dol, marais, marées | — |
| Pertuis | Brouage | Ancienne place forte au milieu des marais, que la mer a quittée : remparts, digues, marées | La Rochelle |
| Estuaire | Le Havre | Grand port détruit en 1944 : docks, grues, ruines de la Manche | Honfleur (vieux port) |
| Pays Noir | Lens | Cité minière, terrils, chevalements | Lille |
| Île-Capitale | Vieille-Capitale (Paris) | Fort-des-Puits devient lieu mineur | — |
| Marche de l'Est | Verdun | Forts, tranchées, citadelle : le front figé par excellence | Strasbourg |
| Beauce-Loire | Chartres | Cathédrale visible de 30 km au-dessus du désert de Beauce, comme Dol au-dessus des marais | Orléans |
| Landes | Bordeaux (Les Chais-Noirs) | Port, chais, raffineurs | Parentis (pétrole) |
| Hautes-Terres | Le Puy-en-Velay | Pitons volcaniques coiffés de chapelles, viaducs | Clermont |
| Confluent | Lyon (Confluent) | Rhône et Saône, usines, écluses | — |
| Provence | Marseille (Massalie) | Port, étangs salés, raffineries de l'Étang | Martigues |
| Alpes | Briançon | Ville forte la plus haute, forts de montagne, cols | Grenoble |

Une fois validées : fiche de lieu par capitale (comme `docs/lore/dol-cite-des-marees.md`), puis passage de `carte_monde.json` à 12 capitales + lieux mineurs (lot de code distinct).

## Routes (22)

Trois types : **route** (entre zones tenues), **piste** (no man's land, DEC-095), **voie ferrée** (rails sur la carte : on roule le long).
Chaque route a un danger de 1 à 7 et une zone de décor. Exemples : Route des grèves (Dol–Les Pertuis, danger 1) ;
Route des citernes (Les Chais-Noirs–Massalie, par Lacq, danger 5) ; Traversée de l'Est (Fort-des-Puits–Rhin-Gris, danger 7).

## Lieux d'intérêt (30)

- **Ressources** : pétrole brut (Brie, Parentis, vieux puits du Rhin), raffineries (Étang, Estuaire), gaz et chimie (Lacq, zone « maudite »),
  mines (charbon, fer, Massif, carrières), eau (sources des Hautes-Terres, lac de montagne, puits artésien), dépôts de carburant
  (Normandie, Loire), épaves et arsenal (Bretagne).
- **Dol (LOC-013)** : seule grande ville de Bretagne, capitale du Réseau des Marées, remplace Kerbrume (DEC-238). Fiche : `docs/lore/dol-cite-des-marees.md`. Mont-Saint-Michel : usage à définir (OQ-039).
- **Sites** : bunkers (vieille ligne, Alpes, Pyrénées, Nord), antenne des Veilleurs, péages des Hommes du Péage (Landes, Rhône, Nord),
  champs de bataille (Somme, front de Champagne), vallée préservée (rumeur, jamais visitée), déserts (Beauce, Landes).

Tout vient de la Bible (LOC-001 à 012, FAC-001 à 007, 04.1 bis). Ajouter ou déplacer un lieu = une entrée du JSON, sans code.

## Ouvert

- Valider villes, noms, factions et niveaux (OQ-010, OQ-011).
- Brancher la carte au jeu normal (DEV-009) : sorties des villes = routes de la carte (aujourd'hui les portes mènent encore aux secteurs
  aléatoires de `monde.gd`), position du convoi le long de la route, brouillard de découverte.
- La position du Kit n'est pas sauvegardée.
