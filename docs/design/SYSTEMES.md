# Systèmes V1 — Folie Mécanique

Statut : en revue (thème 5). Un système à la fois, dans le périmètre V1 (DEC-013).
Chaque système précise : entrées, sorties, règles, valeurs de départ, liens.

Ordre de revue : 1 ressources et stockage · 2 travailleurs et bâtiments ·
3 véhicules · 4 carte et expéditions · 5 combat automatique · 6 faune (événements) ·
7 temps, absence et pénurie · 8 récit.

## 1. Ressources et stockage — validé (DEC-014)

### Ressources V1 (6)

| ID | Ressource | Regroupe | Unité |
|---|---|---|---|
| `water_l` | Eau | — | L |
| `food` | Nourriture | — | ration |
| `fuel_l` | Carburant | essence + diesel (stock unique) | L |
| `metal` | Métal | ferraille, métal | unité |
| `materials` | Matériaux | bois, électronique, pièces | unité |
| `ammo` | Munitions | petit et gros calibre | unité |

Médicaments supprimés en V1 : l'infirmerie fonctionne avec travailleurs et nourriture.

### Règles

- Consommation par survivant et par jour : 5 L d'eau, 1 ration.
- Calcul **heure par heure** (production et consommation). Le rattrapage hors ligne
  rejoue les heures manquées dans un ordre déterministe.
- Stock global par ressource, plafonné par la capacité de stockage (cuves, entrepôt).
- Alertes : moins de 2 jours d'autonomie = avertissement ; moins de 1 jour = critique.

### Départ

- Population : **2 survivants**.
- Autonomie : **3 à 4 jours** d'eau et de nourriture (35 L, 7 rations).
- Carburant : 80 L.

La première expédition devient une nécessité : c'est la boucle rareté → expédition → retour.

### Ouvert

- Stocks de départ en métal, matériaux et munitions.
- Croissance de la population (recrutement) : système 2.
- Capacités de stockage par bâtiment : système 2.

## 2. Travailleurs et bâtiments — validé (DEC-015)

Avec 2 survivants au départ, faire grandir la communauté est un objectif central.

### Règles

- **Recrutement** : de nouveaux survivants se trouvent en expédition, aux points d'intérêt.
  Pas de naissances en V1.
- **Bâtiments autonomes** (sans travailleur) : cuves, entrepôt, défenses automatiques.
- **Bâtiments à travailleur** : atelier, puits/condenseur, cuisine, infirmerie.
- **Un survivant = un poste à la fois**, réaffectable à chaque connexion.
- **Un survivant en expédition ne travaille pas à la base** : dilemme sortir / produire.

### Ouvert

- Production par travailleur et par heure, par bâtiment.
- Niveaux et coûts des bâtiments (tables `niveaux_et_couts_batiments.csv`).
- Capacités de stockage par niveau de cuve et d'entrepôt.
- Fréquence et coût du recrutement (nourriture supplémentaire, risque).

## 3. Véhicules — validé (DEC-016)

Cœur du jeu : mécanique et customisation. Les composants restent modulaires
(tables `catalogue_composants.csv`, `grille_et_chevauchements.csv`).

### Règles

- **5 types d'emplacement** : moteur, transmission, roulement (roues/chenilles),
  armement, carrosserie/blindage. Chaque composant se récupère, se stocke et se remonte
  séparément.
- **Épave** = véhicule avec composants manquants ou abîmés.
  - Réparable si le châssis est présent et s'il manque **au plus 2 composants**
    (valeur à tester) ; les manquants se remplacent par des composants compatibles du stock.
  - Sinon : démontage seulement (composants intacts + métal). Irréversible.
- **Atelier** : modèles uniques construits sur grille aimantée 2D, vue de profil.
- **Les 10 véhicules historiques** s'obtiennent en réparant leurs épaves ;
  le Tiger I est l'objectif final.
- **Gros composants** (moteur, transmission, canon) : **récupération uniquement** en V1.
  Métal et matériaux servent au châssis, à la carrosserie et aux réparations.
- **Remorquage** des épaves lourdes : dépanneuse Diamond T obligatoire.

### Risque technique

L'éditeur d'atelier est la partie la plus difficile à programmer : premier prototype Godot.

### Ouvert

- Sous-ensemble de composants V1 parmi les 29 du catalogue.
- Règles de compatibilité simplifiées (poids, puissance, emplacement).
- Coûts et durées d'atelier.

## 4. Carte et expéditions — validé (DEC-017)

Déjà décidés (VISION, BOUCLE) : ordres permanents, départ programmé, événements de trajet,
rapport, réservation des vivres et du carburant.

### Règles

- **Carte en graphe** : la base, 10 à 12 points d'intérêt, des routes avec distance
  et terrain. Un itinéraire = une suite de routes.
- **Trois cercles** : proche (1–3 h, peu de risque et de butin), moyen (4–8 h),
  lointain (12 h et plus, riche et dangereux).
- **Types de lieux** : oasis/puits (eau), ferme abandonnée (nourriture), dépôt (carburant),
  champ de bataille (épaves, composants), village (survivants), ville (mixte, défendue).
- **Épuisement** : un lieu fouillé s'appauvrit puis se reconstitue lentement.
- **Briefing** : carburant aller-retour + marge de 25 %, risque (faible / modéré / élevé /
  critique) avec raisons, alerte si carburant insuffisant.
- **Capacité de chargement** par véhicule : limite le butin rapporté.

### Ouvert

- Liste et placement des 10 à 12 points d'intérêt.
- Vitesse de reconstitution des lieux.
- Consommation de carburant par véhicule et par terrain.
