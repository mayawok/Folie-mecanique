# Grille de construction — véhicules « Frankenstein »

Statut : **conception** (DEC-029). Rien n'est codé. S'appuie sur DEC-016 (véhicules modulaires) et sur les tables
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
| G1 | Modèle de données : un véhicule = un châssis + des pièces placées ; les 10 véhicules historiques réécrits ainsi ; statistiques calculées ; tests sans écran | Juste après le découpage du code (voir audit) |
| G2 | Démonter un véhicule dans la grange ; stock de pièces | Après G1 |
| G3 | Éditeur de grille au toucher (glisser, aimanter, valider) | Après essais du mode convoi |
| G4 | Dessin des véhicules assemblés ; combat avec véhicules composés | Avec G3 |

G1 est le plus urgent : chaque fonction ajoutée sur des types de véhicules figés augmente le travail de reprise plus tard.

## Ouvert

- Sous-ensemble de pièces V0 parmi les 29 du catalogue (proposition : 8 à 10).
- Fabriquer des pièces simples (plaques, supports) avec du métal à l'atelier : oui ou non.
- Nombre de véhicules maximum dans le convoi, rôle de la capacité de chargement.
- Les véhicules historiques gardent-ils un bonus (fiabilité) par rapport aux assemblages ?
