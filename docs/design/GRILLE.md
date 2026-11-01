# Grille de construction — véhicules « Frankenstein »

Statut : **construction libre codée le 01/11 (DEC-043 à DEC-046)**, voir plus bas ; avant elle, **G1 à G4 codés** (DEC-029, DEC-034, DEC-038 à DEC-040) ; **atelier guidé codé pour la moto et le side-car** (DEC-035).
À faire : atelier guidé pour les gros véhicules, améliorer le dessin des assemblages, quelques pièces à fabriquer en plus des plaques. S'appuie sur DEC-016 (véhicules modulaires) et sur les tables
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
| G2 | Démonter un véhicule dans la grange ; stock de pièces | **Fait le 01/11** |
| G3 | Éditeur de grille au toucher (glisser, aimanter, valider) | **Fait le 01/11** |
| G4 | Dessin des véhicules assemblés ; combat avec véhicules composés | **Fait le 01/11** (première version) |

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

## G2, G3 et G4 tels que codés (01/11, DEC-038 à DEC-040)

- **G2 démontage** (`modele_atelier.gd`) : `raison_demontage`, `ordre_demonter`. Conditions : véhicule garé dans une grange ou un hangar,
  nuit ou tempête (annoncée ou active), convoi arrêté, aucune menace, pas le dernier véhicule. Durée 25 s. Résultat : toutes les pièces,
  châssis compris, en réserve avec leur état ; + métal du châssis ; survivants valides en réserve. Se reconstruit à l'identique (testé).
- **G3 éditeur libre** (`editeur_grille.gd`, règles dans `Assemblage` : `poser`, `retirer`, `piece_en`, `apercu`) : mêmes conditions que G2.
  Aimantation : roues au sol, arme dans la moitié haute, glissement vers la place libre la plus proche (6 cases en largeur, 3 en hauteur) ou
  retour au bac. Plaques de blindage fabriquées avec 4 métal chacune (non remboursées). Un véhicule neuf va en queue de convoi.
  Boutons : « Nouveau véhicule » (barre du haut), « Modifier » et « Démonter » (menu d'un véhicule garé).
- **G4 dessin** (`forme_assemblage.gd`) : historique identique = dessin d'origine ; sinon fiche fabriquée (coque, roues ou chenilles, moteur,
  cabine, tourelle et tube, mitrailleuse sur son appui, plaques, équipage), clé `asm_…`, reconstruite à la sauvegarde. Les ancrages de tir
  lisent cette fiche comme les autres. Limite : apparence volontairement simple, sans l'art définitif.
- Tests : `test_grange.gd` (51 vérifications), parcours écran `capture_grange.gd`, planche `capture_assemblages.gd`.

## Construction libre (01/11, DEC-043 à DEC-046) — la grille de référence

- **Ordre** : 1. peindre le châssis (acier ou blindage, gomme ; plaques de blindage) ; 2. essieux sous la case la plus basse
  d'une colonne (léger, lourd, de char) avec leur train (roue petite, moyenne, grande, chenille) ; 3. moteurs, cabines, armes.
- **Tout est compatible** : on peut tout poser partout où la pièce repose sur quelque chose. Construction refusée seulement
  sans châssis ou sans siège. Le reste se paie en pratique (voir DEC-043) et s'affiche en direct : sol, centre de gravité,
  charge de chaque essieu, liste des défauts.
- **À tout moment** (DEC-044), jeu en pause pendant l'édition dans le prototype. **Bac à sable** au menu principal (DEC-045).
- Code : `scripts/vehicules/construction_libre.gd` (règles, physique, dessin, conversion), `editeur_grille.gd` (écran),
  `modele_atelier.gd` (`grille_de`, `palette_grille`, `cout_grille`, `construire_grille`). Tests : `test_libre.gd`,
  parcours écran `capture_libre.gd`.
- Ouvert : édition en temps réel et risquée (après le prototype) ; vue de face ou largeur (non modélisée) ; vitesses des
  véhicules convertis à rapprocher de l'historique ; zoom de la grille sur iPhone (cases de 20 points).

## Grille pour l'iPhone (01/11 après-midi, DEC-047 à DEC-058)

- **Écran** (`editeur_grille.gd`) : nom en haut à gauche (toucher pour renommer ; vide = nom proposé), Annuler et Construire en haut
  à droite, panneau de catégories à droite (8 onglets), grille centrée entre les marges sûres, bilan en bas.
- **Châssis en rectangles** (glisser d'un coin à l'autre) ; **essieu puis roue** ; pièces **glissées** depuis leur onglet, vrai dessin
  affiché sur la grille ; une pièce posée se reprend au doigt ; lâchée hors de la grille, elle retourne au bac.
- **Équipage** en dernier : rôle de chaque siège ; armes sans tireur signalées (« tireurs 1/2 ») et confirmées à la construction.
- **Phares** (onglet Équipement), **lance-flammes** (onglet Armes), **moteurs multiples** pénalisés, nom proposé, brouillon gardé.
- Tests : `test_libre.gd` (section « Demandes du 01/11 après-midi »), parcours écran `capture_libre.gd`.
- Ouvert : zoom à deux doigts si les cases restent petites ; visuels des pièces (planches ChatGPT) à intégrer.

## Construction « à la Mad Max » : deux plans (DEC-067 ; phase 1 codée le 01/11, DEC-068)

Constat : en un seul plan (une case = une pièce), une cabine ne peut pas passer au-dessus d'un moteur et le résultat n'a pas
l'allure d'un véhicule récupéré. Les véhicules de Fury Road ont été bâtis en deux temps : une **base qui roule**, puis une
**carrosserie de donneur** posée, découpée, soudée par-dessus (Peacemaker : coque de Valiant Charger sur châssis chenillé Ripsaw ;
Gigahorse : deux Cadillac 1959 empilées ; FDK : coccinelle découpée soudée sur un V8 ; War Rig : Tatra prolongé de l'arrière d'une berline).

- **Plan mécanique** : la grille actuelle, réduite à la mécanique (châssis, essieux, suspensions, roulement, moteurs, postes, armes).
  Il donne vitesse, puissance, charge, consommation.
- **Plan carrosserie** : posé librement par-dessus, sans case ; fixé s'il touche le châssis. Il donne poids, blindage par zone
  (ce qu'il recouvre est protégé), couvert de l'équipage. **Vue écorchée** : coque transparente pour retoucher la mécanique.
- **Coques de donneur** : chaque épave fouillée livre sa coque ; on la pose, la retourne, l'empile.
- **Phasage** : 1) deux plans + 5 coques entières (Traction, cabine de T23, caisse de camion, char sans tourelle, carlingue d'avion) ;
  2) **scie** : un ou deux traits, on garde un morceau (découpage de polygone sur l'image, sans nouveau dessin) ;
  3) **greffes** sur points d'accroche (tubes, pare-buffle, éperon, piques, bidons, drapeaux ; certaines ont un effet) et
  **base roulante** trouvée (camion, Jeep, char sans tourelle) ; la peinture de cases reste pour rallonger ou renforcer.

### Phase 1 telle que codée (DEC-068)

- Famille `coque` dans `pieces.json` : `image`, `emprise`, `poids_kg`, `pv`, `blindage`, `metal`, `couvert`, `donneurs`.
- Règles : coque par-dessus tout, sans chevaucher une autre coque, tenue par le châssis ou empilée ; arme ou pièce posable sur
  le toit d'une coque. Onglet Carrosserie : retourner, vue écorchée ; coques transparentes dans les autres onglets.
- Restent : scie (phase 2), greffes et base roulante (phase 3), donneur du nez d'avion, réglage des valeurs en essai.

### Extensibilité (exigence du porteur de projet)

D'autres moteurs, roues, châssis, suspensions, **hauteurs de suspension**, coques et greffes viendront. Règle : **ajouter un modèle
ne demande aucun code**, seulement une entrée de catalogue (`game/data/pieces.json`) et une image.
- Chaque famille a ses champs de données communs (poids, PV, image, points d'accroche) et ses champs propres : moteur (puissance,
  conso), roue (diamètre, vitesse maxi, charge), suspension (charge, débattement, **hauteur** qui relève la caisse et la garde au sol),
  coque (contour, zones de blindage, sièges couverts), greffe (point d'accroche, effet).
- Le code lit des familles génériques : pas de liste de modèles écrite en dur dans les scripts.
- Les tests vérifient que toute entrée du catalogue se pose, se dessine et se calcule (un modèle ajouté est testé d'office).

## Ouvert

- Sous-ensemble de pièces V0 parmi les 29 du catalogue (proposition : 8 à 10).
- Fabriquer d'autres pièces simples (supports) avec du métal : plaques oui (DEC-039) ; le reste à trancher.
- Nombre de véhicules maximum dans le convoi, rôle de la capacité de chargement.
- Les véhicules historiques gardent-ils un bonus (fiabilité) par rapport aux assemblages ?


## Postes, bancs et cabines (DEC-062)

Onglet **Postes** : poste de conduite (conducteur obligatoire), poste de commande (chef de char), poste d'équipier, bancs de
troupes de 4 places face à l'avant ou à l'arrière. Pièces fabriquées en métal. Onglet **Cabines** : formes décor (camion, voiture,
blindée, bricolée, pare-brise) posées au-dessus des sièges ; une cabine fermée met l'équipage à couvert. Onglet Équipage : les
postes fixes ne se changent pas.
