# Grille de construction — véhicules « Frankenstein »

Statut : **G1 codé** (DEC-029, DEC-034) ; **atelier guidé codé pour la moto et le side-car** (DEC-035). Démontage libre (G2),
éditeur libre (G3) et dessin générique des assemblages (G4) restent à faire. S'appuie sur DEC-016 (véhicules modulaires) et sur les tables
existantes `data/master/echelle_et_grille.csv`, `catalogue_composants.csv` (29 pièces), `grille_et_chevauchements.csv`.

## Idée du porteur de projet

La nuit, à l'abri dans une **grange** (ou un hangar), on démonte les véhicules du convoi et on assemble avec leurs
pièces des véhicules nouveaux, uniques, « Frankenstein ». C'est la promesse centrale du jeu (amateurs de mécanique).

## Règles proposées

### Quand et où
- Convoi à l'arrêt, garé dans une grange ou un hangar neutralisé (garage existant), **de nuit** ou à l'abri d'une tempête.
- Le temps de nuit ×3 à l'abri laisse le temps de travailler ; chaque opération coûte du temps de jeu et un mécanicien.

### Démonter
- Un véhicule démonté devient des **pièces en stock**, chacune avec son état en % (comme la fouille), plus du métal.
- Irréversible : on ne « remonte » pas d'un clic, on reconstruit pièce par pièce.

### Construire
- Le **châssis** est la base : il fixe la taille de la grille (cellules de 25 cm) et la charge maximale.
  En V0, un châssis ne se fabrique pas : il vient d'un véhicule démonté ou d'une épave.
- Les pièces se posent sur la grille, vue de profil, et **s'aimantent** sur des points d'ancrage (règles de
  `grille_et_chevauchements.csv`) : roulement en bas sur les essieux, moteur dans le châssis, arme sur un support ou
  une tourelle, cabine et sièges, plaques de blindage en métal sur les cellules libres.
- Familles de pièces, alignées sur les pièces cassables du combat : **roulement** (roues ou chenilles), **moteur**,
  **suspension**, **arme** (mitrailleuse, canon, fléau), **cabine** (sièges), **blindage**, plus le **châssis**.

### Statistiques calculées (aucune valeur saisie à la main)
| Statistique | Calcul proposé |
|---|---|
| Poids | somme des pièces + plaques |
| Vitesse | puissance du moteur / poids, plafonnée par le roulement |
| Charge admissible | roulement + suspension ; au-delà, vitesse effondrée |
| Blindage par zone | plaques posées devant chaque pièce |
| Places d'équipage | sièges de la cabine |
| Consommation | puissance du moteur |

### Validation « ça roule ? »
Un véhicule n'est accepté que s'il a : un châssis, au moins un roulement adapté au poids, un moteur, au moins un siège.
Sinon l'éditeur indique la pièce manquante (même pastilles que l'état des véhicules).

### Apparence
Le véhicule est **dessiné par le code à partir de ses pièces** (prolongement de DEC-023). C'est le principal chantier
technique : aujourd'hui `vehicule_dessin.gd` dessine 10 types fixes depuis `formes_vehicules.json`.

## Phasage proposé

| Étape | Contenu | Quand |
|---|---|---|
| G0 | Ce document | Fait |
| G1 | Modèle de données : un véhicule = un châssis + des pièces placées ; les 10 véhicules historiques réécrits ainsi ; statistiques calculées ; tests sans écran | **Fait le 31/10** |
| G2 | Démonter un véhicule dans la grange ; stock de pièces | Après G1 |
| G3 | Éditeur de grille au toucher (glisser, aimanter, valider) | Après essais du mode convoi |
| G4 | Dessin des véhicules assemblés ; combat avec véhicules composés | Avec G3 |

G1 est le plus urgent : chaque fonction ajoutée sur des types de véhicules figés augmente le travail de reprise plus tard.

## G1 tel que codé (31/10)

| Fichier | Rôle |
|---|---|
| `game/data/pieces.json` | Catalogue : 54 pièces (châssis, roulement, suspension, moteur, cabine par véhicule, 4 armes) + règles (cellule 25 cm, 10 ch/t requis, surcharge maxi ×1,5, plaque de blindage) |
| `game/data/assemblages.json` | Les 10 véhicules historiques : châssis + pièces placées (`pos` = cellule en bas à gauche) |
| `game/scripts/vehicules/assemblage.gd` | `valider()` (« ça roule ? »), `statistiques()`, `profil(type)`, `demonter()` |
| `game/tests/test_assemblage.gd` | 31 vérifications : historiques identiques au jeu, règles de grille, Frankenstein |

- Le combat lit désormais le profil **calculé** ; les statistiques ont été retirées de `combat_proto.json` (une seule source).
  Résultats d'équilibrage strictement identiques avant et après (test de déterminisme).
- Calculs : poids = somme des pièces ; vitesse = plafond du roulement × min(1, puissance / poids ÷ 10 ch/t) × pénalité
  de surcharge (charge / poids)² ; blindage = châssis + 2 par plaque ; équipage = sièges ; conso = moteur ; métal = somme.
- Couches sans chevauchement : train (roulement), suspension, caisse (moteur, cabine), tourelle (armes). Roulement au sol,
  armes dans la moitié haute.
- Poids et puissances historiques approximatifs (Willys 1,1 t / 60 ch… Tiger 54 t / 700 ch), à affiner.
- Exemples vérifiés : Willys à moteur de Sherman (il faut déplacer la cabine ; roule à 4,8 m/s au lieu de 6,5 car surchargé) ;
  T23 armé du canon de 37 ; canon de 88 sur une Jeep refusé (trop long, trop lourd).
- Régler un véhicule : modifier sa pièce dans `pieces.json` (ex. `vitesse_max` du roulement, `pv`, `blindage` du châssis).

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

## Ouvert

- Sous-ensemble de pièces V0 parmi les 29 du catalogue (proposition : 8 à 10).
- Fabriquer des pièces simples (plaques, supports) avec du métal à l'atelier : oui ou non.
- Nombre de véhicules maximum dans le convoi, rôle de la capacité de chargement.
- Les véhicules historiques gardent-ils un bonus (fiabilité) par rapport aux assemblages ?
