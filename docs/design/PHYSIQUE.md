# Physique des pneus et des suspensions — Folie Mécanique

Statut : **conception décidée (DEC-230) et codée le 11/11 (DEC-231, DEV-041)**. Code : `scripts/combat/physique_roulage.gd`, `data/surfaces.json`, `_physique` dans `combat_modele.gd`, rendu dans `vehicule_dessin.gd`, section Physique de `panneau_kit.gd`. Non exécuté en local (pas de Godot dans l'environnement) : vérifié par la CI et à essayer sur iPhone.

## Ce qui existe aujourd'hui

- Suspensions : un seul ressort visuel pour tous les véhicules (`RAIDEUR` 140, `AMORTI` 9 dans `vehicule_dessin.gd`). Le calcul de la grille connaît déjà débattement, charge par essieu, centre de gravité et assiette (`construction_libre.gd`) mais ils ne changent pas le jeu.
- Pneus : 5 types pour le Berliet dans `berliet.json`, valeurs provisoires non branchées. Roues de tailles diverses sur la grille.
- Sol : relief et bosses seulement (`terrain.gd`). Aucune surface (sable, neige, boue) n'agit sur le roulage.

## Principe

Pas de moteur physique de Godot (coût en crédits, non déterministe : il casserait le combat à graine fixe). On fait un **modèle simple, déterministe, piloté par les données** : les pièces portent leurs valeurs, le sol porte les siennes, le modèle les croise. Ajouter un pneu ou une surface = une entrée de données, pas de code.

## Décisions de cadrage (DEC-230)

- **Ampleur** : niveaux 1 (visuel par roue) et 2 (effets de jeu) ensemble, en un lot. Niveau 3 (usure et réparation des pneus et suspensions) plus tard.
- **Surfaces** : route / piste dure, terre / herbe, sable du désert, neige et boue.
- **Ressenti** : réaliste et exigeant. Un mauvais choix de pneus ou de suspension a de vrais effets, comme les défauts déjà affichés sur la grille. Garde-fou de cohérence avec DEC-113 : jamais de défaite définitive à cause du sol seul (un véhicule enlisé se dégage, il ne meurt pas).

## Modèle de jeu (niveau 2)

**Données** : `data/surfaces.json` (nouveau) : par surface, rugosité (amplitude des chocs), portance (enfoncement), résistance au roulement de base. Pneus (`pieces.json`, `berliet.json`) : largeur, rayon, adhérence par surface, résistance au roulement, risque de crevaison. Suspensions (liaisons de `pieces.json`) : course, raideur, amortissement.

**Calculs par véhicule et par surface** :

1. **Pression au sol** par roue = charge de l'essieu (déjà calculée) ÷ surface d'appui (largeur × rayon). Large et basse pression : bon sur sable et neige. Étroit : bon sur terre dure, mauvais en boue.
2. **Adhérence** = adhérence du pneu sur la surface × facteur de pression. Elle fixe l'accélération et la vitesse tenable ; sous un seuil, le véhicule s'**enlise** (arrêt du convoi comme pour une roue détruite, dégagement par un autre véhicule ou par une action de l'équipage).
3. **Chocs** = rugosité de la surface × vitesse, comparée à la course de la suspension. Suspension trop courte ou trop raide : précision de tir réduite, équipage secoué, et au-delà d'un seuil usure ou dégât des pièces roulantes. Le conducteur ralentit seul pour rester sous le seuil, sauf poursuite ou ordre de forcer l'allure (dégâts acceptés).
4. **Consommation** : la résistance au roulement (pneu × surface) s'ajoute à la consommation de carburant, contrainte déjà forte (DEC-171 à 204).
5. **Crevaison** : risque par km selon pneu, surface et surcharge ; réparable comme une pièce (lien avec les roues arrachées de DEC-080).

## Rendu (niveau 1)

- Un ressort par roue, avec les valeurs de la pièce de suspension (plus de constantes uniques).
- Le pneu s'écrase selon sa charge ; le rayon effectif change la garde au sol.
- Tangage au freinage et à l'accélération (transfert de charge selon le centre de gravité).
- Poussière, sable, neige ou boue projetés selon la surface et la vitesse (particules légères, à valider sur iPhone).

## Kit de développement

Panneau « Physique » : surface forcée, charge, pneus, suspension, lecture par roue (pression, adhérence, choc) et de l'enlisement, pour régler en essai sur iPhone.

## Tests prévus

`game/tests/test_physique.gd` (sans écran) : même graine = même résultat ; un pneu de sable plus rapide qu'un pneu de route sur sable et l'inverse sur route ; suspension courte à haute vitesse = chocs ; enlisement puis dégagement. Capture d'écran pour le rendu.

## Ouvert (OQ-037)

Quand la boue apparaît (pluie, dégel, zone fixe ?) ; zones de la carte à neige ; valeurs d'adhérence à régler en essai ; action de dégagement (plaques, treuil, remorquage par un autre véhicule).
