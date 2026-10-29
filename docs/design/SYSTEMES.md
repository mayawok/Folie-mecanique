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
