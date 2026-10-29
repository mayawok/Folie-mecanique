# Cahier des charges — Willys MB (véhicule pilote)

Statut : **complet, validé le 2026-10-29** (pilote de la méthode, DEC-021). Moteur et transmission dessinés vers la gauche puis retournés. Géométrie : `gabarit.json`.
Cotes de prototypage (L 3,36 m, H 1,78 m pare-brise relevé), à affiner sur plans.

## Méthode

1. Claude fournit, pour chaque pièce, un gabarit (`gabarits/<piece>.png`, silhouette noire
   aux bonnes proportions) et une consigne.
2. Le porteur de projet joint le gabarit à ChatGPT avec la consigne commune + la consigne
   de la pièce. Une pièce par conversation d'image.
3. L'image obtenue est détourée (fond transparent) et enregistrée dans `art/<piece>.png`,
   la consigne exacte dans `docs/art/prompts/veh_willys_mb_<piece>.md`.
4. `python3 tools/gabarits_vehicule.py docs/art/vehicules/willys_mb` recombine le véhicule
   dans `assemblage.png` (les pièces absentes restent en silhouette colorée).

**Ordre de production** : caisse d'abord. Une fois validée, la joindre comme
**référence de style** pour toutes les pièces suivantes (même usure, même lumière).

## Pièces

Validées le 2026-10-29 : caisse (crochet et pare-chocs inclus), chassis (avec ressorts et
moyeux d'essieux, calé sur les centres de roues), roue, mitrailleuse (dessinée vers la
gauche puis retournée ; ressemble à une M2 calibre .50 plutôt qu'à une .30, à trancher
en gameplay). Les boîtes de `gabarit.json` sont ajustées aux images.

Échelle source : 64 px par cellule de 25 cm (1 m = 256 px). L'affichage en jeu reste
zoomable (`echelle_et_grille.csv`).

| Pièce | Emplacement | Taille (cellules) | Taille (px) | Profondeur | Visible en jeu |
|---|---|---|---|---|---|
| `chassis` | châssis (racine) | 13,2 × 0,65 | 845 × 42 | 1 | Partiellement, sous la caisse |
| `transmission` | transmission | 9,3 × 2,2 | 595 × 141 | 2 | Non (atelier seulement) |
| `moteur` | moteur | 3,5 × 1,5 | 224 × 96 | 3 | Non (atelier seulement) |
| `roue` | roulement | 3,0 × 3,0 | 192 × 192 | 4 | Oui, ×2, tourne |
| `caisse` | carrosserie | 13,4 × 4,35 | 858 × 278 | 5 | Oui — **validée** |
| `mitrailleuse` | armement | 4,0 × 2,7 | 256 × 173 | 6 | Oui |

« Profondeur » : ordre d'empilement, 1 = au fond. Dans l'atelier, la caisse devient
semi-transparente pour montrer moteur et transmission.

### Contraintes par pièce

- **chassis** : deux longerons d'acier riveté, traverses, ressorts à lames. **Sans
  pare-chocs ni crochet** : la caisse validée les contient déjà. Racine du véhicule : toutes les pièces s'y accrochent.
- **transmission** : boîte de vitesses et boîte de transfert, arbres de transmission
  avant et arrière, différentiels sur les essieux.
- **moteur** : 4 cylindres en ligne Go-Devil, ventilateur à l'avant, filtre à air,
  collecteurs. Doit tenir sous le capot.
- **roue** : pneu tout-terrain à crampons, jante acier ajourée. **Parfaitement ronde et
  centrée** : elle tourne autour de son centre. Une seule image pour les deux roues.
- **caisse** : baignoire ouverte, capot plat, calandre à fentes verticales, ailes avant
  plates, passages de roues découpés, pare-brise rabattable relevé (cadre seul, sans
  vitre opaque). Roue de secours et jerrican à l'arrière autorisés. **Aucune roue dessinée.**
- **mitrailleuse** : mitrailleuse légère calibre .30 sur affût pivotant à colonne, canon
  vers la droite.

## Consignes ChatGPT

### Consigne commune (à coller à chaque fois)

> Illustration de jeu vidéo 2D, peinture numérique semi-réaliste, dans l'esprit du jeu
> Earn to Die, ambiance post-apocalyptique des années 1940. Vue de profil stricte,
> orientée vers la droite, sans aucune perspective. Lumière venant du haut à gauche,
> ombres douces. Palette : kaki olive délavé, rouille, acier usé, poussière de sable.
> Fond uni magenta pur (#FF00FF), sans ombre au sol, sans texte, sans logo, sans
> personnage. Reproduis exactement la silhouette et les proportions de l'image de
> référence jointe ; la pièce remplit le cadre avec une petite marge. Dessine
> uniquement cette pièce, isolée.

Pourquoi un fond magenta : le véhicule est vert olive et sable ; un fond vert ou beige
se confondrait avec lui au détourage. Si l'outil propose un fond transparent, le préférer.

### Consigne par pièce (à ajouter après la consigne commune)

- **caisse** : « La pièce est la carrosserie d'une jeep militaire Willys MB de 1942,
  usée et rapiécée : baignoire ouverte, capot plat, calandre à fentes verticales, ailes
  avant plates, pare-brise relevé (cadre seul). Passages de roues vides : ne dessine
  aucune roue, aucun châssis, aucun moteur. »
- **chassis** : « La pièce est le châssis nu d'une jeep Willys MB : deux longerons d'acier
  rivetés vus de côté, traverses, ressorts à lames. Sans pare-chocs, sans crochet de
  remorquage, sans roues ni carrosserie. Pièce très allongée et fine. »
- **moteur** : « La pièce est un moteur essence 4 cylindres en ligne des années 1940,
  vu de côté, ventilateur à droite, encrassé et rafistolé. »
- **transmission** : « La pièce est la transmission d'une jeep 4x4 : boîte de vitesses
  et boîte de transfert au centre, arbres de transmission vers les deux essieux,
  différentiels ronds aux extrémités. »
- **roue** : « La pièce est une roue de jeep militaire vue de face latérale : pneu à
  crampons usé, jante acier. Cercle parfait, centré dans l'image. »
- **mitrailleuse** : « La pièce est une mitrailleuse légère calibre .30 des années 1940
  sur affût pivotant à colonne, canon orienté vers la droite. »

## Critères d'acceptation d'une pièce

- Silhouette superposable au gabarit (écart visible faible après redimensionnement).
- Vue de profil, orientée vers la droite, lumière du haut à gauche.
- Aucun élément d'une autre pièce (pas de roue dans la caisse, par exemple).
- Style cohérent avec la caisse validée.
