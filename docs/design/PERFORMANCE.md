# Performance sur iPhone — Folie Mécanique

Statut : **premier lot fait le 26/11 (DEC-262)**, à mesurer sur l'iPhone avec le compteur d'images.

## Méthode

- **Scène de mesure** : `game/tests/mesure_perf.gd` (Kit, trois groupes « raid » de grande taille, gore maximum, environ
  20 véhicules à l'écran, modèle avancé à la main pour que la scène soit la même d'une mesure à l'autre). Option `calques` :
  on cache un calque à la fois (décor, premier plan, véhicules, ombres, lumières, effets, ville, interface) pour voir ce qu'il coûte.
  ```
  xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 --resolution 1280x720 \
    -s res://tests/mesure_perf.gd -- terre calques
  ```
- **Ce qu'on regarde** : les **appels de dessin** par image (le premier coût du rendu « Compatibilité » sur téléphone : chaque
  appel passe par le pilote OpenGL ES) et le **temps des scripts de dessin** (`_draw`, `_process`), mesuré en instrumentant une
  copie du jeu. Le temps total mesuré sur la machine de travail comprend un rendu logiciel sans carte graphique : il ne dit rien
  de l'iPhone, seuls les appels et les temps de scripts comptent.

## Ce que le moteur regroupe (Godot 4.3, rendu Compatibilité)

- **Jamais regroupés** : chaque polygone (`draw_colored_polygon`, `draw_polygon`), chaque polyligne (`draw_polyline`), chaque
  disque de `draw_circle` (c'est un polygone) coûte **un appel à lui seul**. Le moteur retriangule aussi chaque polygone à
  chaque image.
- **Regroupés** quand ils se suivent : rectangles de même texture (`draw_texture_rect`, `draw_rect`) ; primitives à quatre
  points (`draw_line` épais, `draw_primitive`).
- Un maillage (`draw_mesh`) ou un tableau de triangles (`canvas_item_add_triangle_array`) = un appel, sans triangulation.

## Lot 1 (26/11, DEC-262)

| Changement | Où |
|---|---|
| Disques pleins dessinés en rectangles texturés (`Disque.d`, bord adouci) : gouttes, poussières, roues, têtes de rivets, halos | `disque.gd` ; 137 appels remplacés dans le décor, les véhicules, les effets, les villes, les bâtiments |
| Silhouettes (équipages, pillards) en primitives regroupables (`Pinceau`) : buste, coiffe, contours, pieds, tête | `pinceau.gd`, `personnage_dessin.gd` |
| Carrosseries dessinées par le code : les polygones qui se suivent, contours compris, forment **un maillage** construit une fois, posé avec la transformation de la caisse | `vehicule_dessin.gd` (`_maillage`) |
| Roues : toutes les jantes, puis tous les rayons ; ressorts et arcs en traits | `vehicule_dessin.gd` |
| Sol et dunes en rubans de triangles (plus de triangulation à chaque image) | `terrain.gd` (`_ruban`) |
| 30 images par seconde quand un menu est ouvert (accueil, options, pause) | `convoi_vue.gd` (`_economie_menus`) |
| **Compteur d'images** (Options) : images/s, temps d'une image, appels de dessin, nœuds, mémoire | `compteur_images.gd` |
| Réglages de l'appareil dans un seul fichier, chaque clé gardée (gore, compteur) | `reglages.gd` |

### Résultats (scène de mesure, même état)

| | Avant | Après |
|---|---|---|
| Appels de dessin, zone terre | 1 910 | **437** (−77 %) |
| Appels de dessin, zone sable | 1 708 | **446** (−74 %) |
| Scripts de dessin par image (machine de travail) | ≈ 20 ms | ≈ 13 ms |
| dont véhicules | 6,6 ms | 4,3 ms |
| dont décor | 5,1 ms | 3,1 ms |

Le reste des appels : véhicules en images (une texture par pièce), interface (textes et boutons), décor en couches.

## À mesurer sur l'iPhone (le créateur, avec le compteur d'images)

1. Images/s et temps d'une image en route calme, puis en gros combat (Kit → groupes, taille grande).
2. Chaleur et batterie après 15 minutes.
3. Si le jeu ne tient pas 60 images/s : envoyer une capture du compteur en plein combat.

## Pistes suivantes (non faites, à décider sur mesures — OQ-056)

- Résolution de rendu : l'iPhone 14 Pro Max dessine 2 796 × 1 290 pixels ; le site web est plafonné à deux fois la densité
  (≈ 1 864 × 860). Une option « Économie » rendrait le jeu à cette taille si le remplissage (brumes, halos) coûte trop.
- Décor lointain mis en cache (les plans lents ne seraient redessinés que de temps en temps).
- Effets : plafonds de gore et de débris selon la mesure.
- Véhicules en images : regrouper les pièces dans un atlas (une texture) pour un appel par véhicule.
