# Planches « pièces de la grille » — style simple et propre (DEC-057)

But : remplacer les formes géométriques de la grille par des visuels **plus jolis mais basiques**,
lisibles à petite taille sur iPhone. ChatGPT ne fait qu'une image par demande : **trois prompts**,
à coller l'un après l'autre (attendre chaque image). Échelle commune : **1 case de la grille = 40 px**
(25 cm). Claude découpe, met à l'échelle exacte et range dans `game/assets/grille/`.
Les chenilles sont décrites comme celles d'un **tracteur agricole** (ChatGPT refuse les chars).

## Prompt 1 — châssis et roulement

```
Tu es illustrateur pour un jeu mobile 2D (iPhone, paysage) dans un monde post-apocalyptique figé dans les années 1940, désertique, ambiance Mad Max. Dessine UNE planche de pièces détachées de véhicules, style simple et propre : aplats de couleur avec un léger dégradé, un trait de contour sombre régulier (3 px), une seule ombre douce, peu de détails, lisible en très petit. Palette : acier usé gris-brun, rouille, kaki olive délavé, caoutchouc noir mat. Lumière venant du haut à gauche. Vue de profil stricte, sans perspective. Fond uni transparent (ou blanc pur si impossible). Aucun texte, chiffre, logo ni marque. Pièces séparées par au moins 40 px de vide, alignées sur une grille invisible où 1 case = 40 px, chaque pièce exactement à la taille indiquée :
1. Tuile de châssis en acier riveté, carrée 40×40 px, conçue pour se répéter sans couture (bords raccord).
2. Tuile de châssis en tôle de blindage épaisse, plus sombre, kaki olive, 40×40 px, raccord sans couture.
3. Plaque de blindage boulonnée, 40×160 px (verticale).
4. Essieu léger vu de profil : moyeu rond et petite lame de ressort, 40×40 px.
5. Essieu lourd : moyeu plus gros, ressort à lames épais, 40×40 px.
6. Essieu très lourd à barre de torsion, 40×40 px.
7. Petite roue à jante pleine et pneu à crampons, diamètre 80 px.
8. Roue moyenne de camion militaire, jante à 5 trous, diamètre 120 px.
9. Grande roue de camion tout-terrain, pneu épais, diamètre 160 px.
10. Galet de roulement de tracteur agricole à chenilles, diamètre 120 px, plus un segment droit de chenille de tracteur (maillons métalliques) de 240×24 px, répétable bout à bout.
```

## Prompt 2 — moteurs, cabines, phares

```
Tu es illustrateur pour un jeu mobile 2D (iPhone, paysage) dans un monde post-apocalyptique figé dans les années 1940, désertique, ambiance Mad Max. Dessine UNE planche de pièces détachées de véhicules, style simple et propre : aplats de couleur avec un léger dégradé, un trait de contour sombre régulier (3 px), une seule ombre douce, peu de détails, lisible en très petit. Palette : acier usé gris-brun, rouille, kaki olive délavé, cuivre terni, cuir brun. Lumière venant du haut à gauche. Vue de profil stricte, sans perspective, orientée vers la droite. Fond uni transparent (ou blanc pur si impossible). Aucun texte, chiffre, logo ni marque. Pièces séparées par au moins 40 px de vide, alignées sur une grille invisible où 1 case = 40 px, chaque pièce exactement à la taille indiquée :
1. Petit moteur 4 cylindres de jeep, bloc et carburateur visibles, 160×80 px.
2. Moteur de camion 6 cylindres avec radiateur, 240×120 px.
3. Gros moteur V12 à essence de véhicule lourd, échappements, 320×160 px.
4. Poste de conduite ouvert de jeep : siège, volant, pare-brise rabattable, 200×120 px.
5. Habitacle fermé de berline des années 1940 avec vitres, 280×80 px.
6. Cabine de camion militaire en tôle avec porte et vitre, 320×160 px.
7. Caisse blindée fermée avec trappe et fente de vision, 320×160 px.
8. Benne ouverte de camion avec ridelles en bois, 360×120 px.
9. Paire de phares ronds chromés sur support, vus de profil, 40×40 px.
```

## Prompt 3 — armes

```
Tu es illustrateur pour un jeu mobile 2D (iPhone, paysage) dans un monde post-apocalyptique figé dans les années 1940, désertique, ambiance Mad Max. Dessine UNE planche d'équipements montés sur des véhicules de récupération, style simple et propre : aplats de couleur avec un léger dégradé, un trait de contour sombre régulier (3 px), une seule ombre douce, peu de détails, lisible en très petit. Palette : acier bruni, acier usé gris, kaki olive délavé, bois sombre. Lumière venant du haut à gauche. Vue de profil stricte, sans perspective, canons orientés vers la droite. Fond uni transparent (ou blanc pur si impossible). Aucun texte, chiffre, logo, marque ni personnage. Pièces séparées par au moins 40 px de vide, alignées sur une grille invisible où 1 case = 40 px, chaque pièce exactement à la taille indiquée :
1. Mitrailleuse des années 1940 sur pivot, 120×40 px.
2. Petit canon de 37 mm avec bouclier, 240×80 px.
3. Canon de 75 mm à long tube sur affût, 400×80 px.
4. Très long canon de 88 mm avec frein de bouche, 640×80 px.
5. Mortier de 81 mm sur plaque de base, tube incliné à 60°, 80×80 px.
6. Lance-flammes de véhicule : réservoir cylindrique et buse, 120×40 px.
```
