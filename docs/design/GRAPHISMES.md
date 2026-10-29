# Graphismes — Folie Mécanique

Statut : validé (thème 6, DEC-020). Distingue ce qui est **décidé** de ce qui reste **ouvert**.
Complète `docs/art/ART_PIPELINE.md` (règles du registre d'assets).

## Choix du porteur de projet

- **Production : IA générative d'images** (ex. ChatGPT), retouchée et découpée à la main.
- **Rendu : semi-réaliste peint**, référence *Earn to Die*, ambiance Mad Max, technologie 1940.
- **Noms réels complets** des véhicules (Willys MB, BMW R75…).

## Contraintes imposées par les systèmes

- **Véhicules en pièces découpées** (DEC-016) : une image par emplacement (moteur,
  transmission, roulement, armement, carrosserie). Les pièces sont animées par Godot
  (rotation des roues, oscillation de la caisse), pas image par image.
- **Points d'accroche dans les données** (CSV), jamais dans l'image.
- **Cosmétiques** (DEC-012) : peinture et emblèmes en calques séparés, posés par-dessus.

## Bible de style (identique pour chaque génération)

Le défaut principal de l'IA est l'incohérence d'une image à l'autre. On la limite par
une consigne fixe, conservée dans `docs/art/prompts/` avec chaque image produite.

| Règle | Valeur |
|---|---|
| Vue | Profil strict, véhicule orienté vers la droite, sans perspective |
| Lumière | Venant du haut à gauche, ombres douces |
| Fond | Uni, couleur unique (pour le détourage) |
| Palette | Ocres, sable, rouille, kaki olive, acier usé |
| Rendu | Peinture numérique semi-réaliste, contours peu marqués |
| Format de génération | Paysage, la plus haute résolution disponible |
| Contenu interdit | Texte, logos, marques visibles, personnages reconnaissables |

## Méthode de production

1. Générer le véhicule **entier** de profil avec la consigne fixe.
2. Le **détourer** (fond retiré) dans un outil gratuit (GIMP, Photopea).
3. Le **découper** en 5 pièces selon un gabarit commun.
4. Exporter en PNG transparent, enregistrer dans le registre `asset-register.csv`.
5. Saisir les points d'accroche dans les données.

**Validation obligatoire avant toute production en série** : le Willys MB est produit
et découpé en premier, puis testé dans le prototype d'atelier. Si les pièces ne
s'emboîtent pas proprement, la méthode est revue avant les 9 autres véhicules.

Les images provisoires (formes simples, dimensions et accroches correctes) sont
produites en SVG pour que le prototype d'atelier n'attende pas l'art final.

## Règles d'économie de production

- **Nuit** : effet de lumière global dans Godot, pas d'images dessinées.
- **Dégâts** : calques génériques (impacts, rouille, fumée) posés par-dessus,
  pas une version abîmée par pièce.
- **Survivants** : silhouettes, sans visage détaillé.

## Conventions techniques

- Mode paysage. Résolution de référence 1920 × 1080, mise à l'échelle Godot
  `canvas_items`, rapport `expand` (écrans iPhone plus larges).
- Sources (image générée haute résolution + consigne) séparées des exports PNG.
- Nommage : `veh_<vehicule>_<emplacement>.png`, `bat_<batiment>_n<niveau>.png`,
  `ui_<groupe>_<nom>.png`, `fx_<effet>.png`, `bg_desert_<couche>.png`.

## Volume V1 estimé (≈ 150 images)

| Groupe | Nombre |
|---|---|
| Pièces de véhicules (10 × 5) | 50 |
| Bâtiments (≈ 8 × 3 niveaux) | 24 |
| Décor désert (parallaxe) | 4 |
| Icônes de lieux | 12 |
| Interface (ressources, actions) | ≈ 25 |
| Animaux (meute, prédateur, nuée) | 3 |
| Illustrations de récit | 6 à 8 |
| Calques de dégâts et effets | ≈ 10 |
| Emblèmes et peintures (cosmétiques de lancement) | à définir |

## Risques

- **Cohérence** entre images générées : traitée par la bible de style et le test Willys MB.
- **Droits** : les conditions d'utilisation de l'outil choisi doivent autoriser l'usage
  commercial ; à vérifier et à noter dans la colonne `source_license` du registre.
  Une image entièrement générée par IA peut ne pas être protégée par le droit d'auteur :
  d'autres pourraient la réutiliser. Risque accepté.
- **Marques** : Jeep, BMW et Citroën sont des marques actives. Les noms réels sont
  retenus ; une vérification juridique est requise **avant publication**. Aucun logo
  de marque n'apparaît dans les images.

## Ouvert

- Outil d'IA retenu et vérification de ses conditions commerciales.
- Gabarit de découpe et échelle commune des véhicules (1 case de grille = n pixels).
- Noms et apparence des espèces animales (système 6).
- Catalogue cosmétique de lancement.
- Vérification juridique des noms de véhicules.
