# Lots 3b, 3c, 20 et 21 — Décor « terre et herbe », éléments de décor, interface (DEC-114)

Prompts complets, à coller tels quels dans ChatGPT : un prompt = une image. Ne rien modifier.
Référence visuelle : `docs/art/reference/concept_hud_2026-11-07.png` (concept art : ambiance, pas à reproduire).

Fichiers livrés (à passer à Claude) : `lot3b_ciel`, `lot3b_lointain`, `lot3b_moyen`, `lot3b_sol`, `lot3c_elements`, `lot20_panneaux`, `lot21_icones`.
Rangement par Claude : `game/assets/decor/terre_*.png` (couches), `game/assets/decor/elem_*.png` (éléments), `game/assets/ui/` (cadres et icônes).

## Bloc de style commun (déjà inclus dans chaque prompt)

Peinture numérique semi-réaliste, niveau de détail intermédiaire, lisible sur un téléphone ; France rurale des années 1940 après un effondrement ;
esprit *Earn to Die* et *Mad Max* ; lumière du haut à gauche ; palette ocre, vert olive délavé, terre brune, rouille, acier usé, ciel gris-bleu voilé.
Aucun texte, chiffre, logo, marque, drapeau, personnage ni véhicule.

## Lot 3b — Décor « terre et herbe » (4 couches, une par image)

Ordre : ciel d'abord ; joindre `lot3b_ciel` aux trois prompts suivants (accord d'ambiance).

### Prompt 1 — lot3b_ciel

```
Génère UNE seule image : un ciel de jour pour un jeu vidéo 2D de défilement horizontal.
Format le plus panoramique possible (largeur au moins 3 fois la hauteur). Image opaque, plein cadre, sans magenta.
Contenu : ciel couvert et voilé, gris-bleu pâle, nuages fins et allongés, soleil voilé et diffus en haut à gauche, lueur chaude et pâle près du bas de l'image (l'horizon), le bas de l'image est le plus clair et le plus brumeux. Aucune terre, aucune colline, aucun oiseau, aucun avion.
Les bords gauche et droit doivent pouvoir se raccorder : pas d'élément marquant (pas de soleil net, pas de gros nuage) à moins de 10 % des bords gauche et droit.
Style : peinture numérique semi-réaliste, niveau de détail intermédiaire, ambiance post-apocalyptique mélancolique, palette gris-bleu, ocre pâle et blanc cassé, contrastes adoucis par la brume.
Aucun texte, chiffre, logo ni personnage.
Termine ta réponse par la ligne : Fichier : lot3b_ciel
```

### Prompt 2 — lot3b_lointain (joindre lot3b_ciel)

```
Génère UNE seule image : la couche « lointain » d'un décor de jeu vidéo 2D à défilement horizontal, qui s'accorde au ciel joint (même lumière, même brume, pas de ciel bleu vif).
Format le plus panoramique possible (largeur au moins 6 fois la hauteur), vue de profil, sans perspective plongeante.
Contenu : une ligne de collines et de plateaux lointains de campagne française, très estompés par la brume, bleu-gris pâle et vert-gris, contrastes très faibles, crête ondulée douce. Quelques silhouettes minuscules et à peine visibles : un clocher de village, un pylône électrique, un bosquet maigre. Le bas de l'image est plein (les collines et la brume se prolongent jusqu'au bord inférieur, sans bord net).
Tout ce qui est au-dessus de la crête est un fond uni magenta pur #FF00FF (pas de ciel). Aucune ombre portée sur le magenta.
Les bords gauche et droit doivent pouvoir se raccorder : la crête arrive à la même hauteur des deux côtés.
Style : peinture numérique semi-réaliste, niveau de détail intermédiaire, palette bleu-gris, vert olive délavé et ocre pâle.
Aucun texte, chiffre, logo, personnage ni véhicule. Aucun bâtiment détaillé.
Termine ta réponse par la ligne : Fichier : lot3b_lointain
```

### Prompt 3 — lot3b_moyen (joindre lot3b_ciel)

```
Génère UNE seule image : la couche « plan moyen » d'un décor de jeu vidéo 2D à défilement horizontal, qui s'accorde au ciel joint (même lumière, brume légère, pas de ciel bleu vif).
Format le plus panoramique possible (largeur au moins 6 fois la hauteur), vue de profil, sans perspective plongeante.
Contenu : campagne française pauvre et abandonnée, à moyenne distance : champs jaunis et friches, collines basses, haies clairsemées, quelques arbres maigres et quelques arbres morts, un muret de pierres éboulé, un pylône électrique penché, une ferme en ruine lointaine. Moins de brume que sur la couche lointaine, mais encore un peu voilé. Le bas de l'image est plein (la terre et l'herbe sèche se prolongent jusqu'au bord inférieur).
Tout ce qui est au-dessus du relief est un fond uni magenta pur #FF00FF (pas de ciel). Aucune ombre portée sur le magenta.
Les bords gauche et droit doivent pouvoir se raccorder : le relief arrive à la même hauteur des deux côtés.
Style : peinture numérique semi-réaliste, niveau de détail intermédiaire, palette vert olive délavé, terre brune, ocre, un peu de rouille.
Aucun texte, chiffre, logo, personnage ni véhicule.
Termine ta réponse par la ligne : Fichier : lot3b_moyen
```

### Prompt 4 — lot3b_sol (joindre lot3b_ciel)

```
Génère UNE seule image : la bande de sol de premier plan d'un décor de jeu vidéo 2D à défilement horizontal, qui s'accorde au ciel joint (même lumière).
Format le plus panoramique possible (largeur au moins 8 fois la hauteur), vue de profil strict.
Contenu : terre brune tassée avec un peu d'herbe sèche et de petites plantes, cailloux, ornières de roues et de chenilles, traînées de boue séchée, quelques flaques sèches. Le dessus de la bande est une ligne presque plate et horizontale (c'est la ligne de roulage des véhicules), avec seulement de très légères irrégularités et de petites touffes d'herbe. Pas de route goudronnée, pas de ligne blanche, pas de trottoir.
Tout ce qui est au-dessus de la bande est un fond uni magenta pur #FF00FF. Aucune ombre portée sur le magenta.
Les bords gauche et droit doivent pouvoir se raccorder : mêmes couleurs et même hauteur du dessus des deux côtés, sans élément marquant près des bords.
Style : peinture numérique semi-réaliste, niveau de détail intermédiaire, palette terre brune, vert olive délavé, ocre et un peu de rouille, texture crédible.
Aucun texte, chiffre, logo, personnage ni véhicule.
Termine ta réponse par la ligne : Fichier : lot3b_sol
```

## Lot 3c — Éléments de décor (une planche)

### Prompt 5 — lot3c_elements

```
Génère UNE seule image : une planche de 10 éléments de décor séparés pour un jeu vidéo 2D de défilement horizontal, France rurale des années 1940 après un effondrement.
Chaque élément est vu de PROFIL STRICT, sans perspective, comme une élévation (façade parallèle à l'écran, aucune face latérale, aucun toit vu de dessus). Le bord inférieur de chaque élément est droit et horizontal : l'élément se pose sur une ligne. Pas de sol dessiné, pas d'ombre au sol, rien autour de chaque élément.
Fond uni magenta pur #FF00FF. Les éléments sont séparés par au moins 40 px de magenta, sans aucun contact. Même échelle pour tous (les hauteurs réelles sont données). Ordre de lecture : de gauche à droite, ligne par ligne, 5 éléments par ligne, dans cet ordre exact :
1. Château d'eau rouillé sur pylône métallique à entretoises, cuve cylindrique tachée de rouille, sans inscription — hauteur 12 m.
2. Clocher d'église de village en pierre, flèche à moitié effondrée, ouvertures béantes — hauteur 14 m.
3. Pan de façade d'une maison de village à deux étages, en ruine : volets pendants, fenêtres vides, toit en partie effondré, murs fissurés — 8 m de large, 7 m de haut.
4. Arbre feuillu maigre, tronc tordu, feuillage clairsemé vert olive délavé — hauteur 6 m.
5. Arbre mort, tronc noirci et branches nues cassées — hauteur 5 m.
6. Poteau télégraphique en bois, penché, traverse avec isolateurs, fils coupés qui pendent — hauteur 5 m.
7. Clôture de piquets en bois avec rouleaux de fil barbelé rouillé, un piquet cassé — 3 m de large, 1,2 m de haut.
8. Muret de pierres sèches à moitié éboulé — 3 m de large, 1 m de haut.
9. Groupe de buissons secs et de touffes d'herbe jaunie — 2,5 m de large, 1 m de haut.
10. Rocher gris moussu avec quelques cailloux au pied — 2 m de large, 1,3 m de haut.
Style : peinture numérique semi-réaliste, niveau de détail intermédiaire, lumière du haut à gauche, ombres douces, palette ocre, vert olive délavé, terre brune, rouille, pierre grise ; tout est usé et poussiéreux.
Aucun texte, chiffre, logo, marque, drapeau, personnage ni véhicule.
Termine ta réponse par la ligne : Fichier : lot3c_elements
```

## Lot 20 — Interface : panneaux et boutons (une planche)

### Prompt 6 — lot20_panneaux

```
Génère UNE seule image : une planche de 3 éléments d'interface pour un jeu vidéo mobile 2D post-apocalyptique (années 1940, véhicules militaires). Ces images seront étirées par le moteur de jeu : les coins sont détaillés, les côtés sont simples et répétables, sans motif particulier au milieu des côtés.
Fond uni magenta pur #FF00FF autour de chaque élément ; au moins 40 px de magenta entre les éléments, sans contact. Ordre de gauche à droite, de haut en bas :
1. Cadre de panneau rectangulaire horizontal (proportion 2:1) : métal sombre vieilli et rayé, bords biseautés, rivets aux quatre coins, fine bordure intérieure en laiton terni, patine de rouille légère aux angles. Le centre est un aplat uni très sombre brun-noir (#1B1A18), totalement vide (aucun dessin, aucun texte).
2. Bouton d'onglet rectangulaire (proportion 2:1), même métal sombre, rivets aux coins, centre uni sombre vide, état « normal ».
3. Bouton d'onglet rectangulaire (proportion 2:1), identique au précédent mais état « sélectionné » : liseré jaune ocre (#E8A33D) lumineux autour du bord intérieur, centre un peu plus clair, vide.
Éclairage du haut à gauche, ombres douces, pas de perspective, vue de face.
Style : peinture numérique semi-réaliste, niveau de détail intermédiaire, sobre et lisible sur un téléphone.
Aucun texte, chiffre, logo, marque, icône ni personnage.
Termine ta réponse par la ligne : Fichier : lot20_panneaux
```

## Lot 21 — Interface : icônes (une planche)

### Prompt 7 — lot21_icones

```
Génère UNE seule image : une planche de 12 icônes d'interface pour un jeu vidéo mobile 2D post-apocalyptique (années 1940, véhicules militaires).
Fond uni magenta pur #FF00FF ; au moins 40 px de magenta entre les icônes, sans aucun contact ; même taille pour toutes (environ 256 × 256 px chacune) ; 4 icônes par ligne, 3 lignes, de gauche à droite et de haut en bas, dans cet ordre exact :
1. Conducteur : volant de véhicule ancien.
2. Mitrailleur : mitrailleuse sur affût, vue de profil.
3. Mécanicien : clé à molette croisée avec un tournevis.
4. Éclaireur : paire de jumelles militaires.
5. Chef de convoi : galons de sous-officier (trois chevrons).
6. Infirmier : sacoche de soin en toile avec une bande claire (SANS croix rouge nette).
7. Moteur : bloc moteur à quatre cylindres avec courroie.
8. Roues : roue de camion avec pneu usé.
9. Blindage : plaque d'acier boulonnée avec un impact de balle.
10. Arme : obus de canon debout.
11. Menace : deux sabres croisés stylisés, surmontés d'un petit éclair.
12. Gazole : jerrican militaire VERT olive avec une goutte.
Style : silhouette lisible, métal et toile usés, contours sombres épais, un seul éclairage du haut à gauche, couleurs sobres (acier, laiton, olive, ocre), lisible à 48 px de côté. Vue de face ou de profil, trois quarts autorisé.
Aucun texte, chiffre, logo, marque, drapeau ni personnage.
Termine ta réponse par la ligne : Fichier : lot21_icones
```
