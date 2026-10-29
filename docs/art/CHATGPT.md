# Instructions pour ChatGPT — production des images

Tu produis les images du jeu Folie Mécanique (iPhone, 2D, vue de profil, années 1940
post-apocalyptiques). Claude prépare les cahiers des charges et recombine les pièces ;
toi, tu dessines **une pièce à la fois**.

## À lire, dans cet ordre

1. `docs/design/GRAPHISMES.md` : bible de style, règles, méthode (DEC-020, DEC-021).
2. Le cahier du véhicule en cours : `docs/art/vehicules/<vehicule>/CAHIER.md`
   (consigne commune, consigne par pièce, tailles, critères d'acceptation).
3. La géométrie : `docs/art/vehicules/<vehicule>/gabarit.json` (cellule = 25 cm,
   64 px par cellule, origine au sol à l'arrière, véhicule orienté vers la droite).

Véhicule en cours : **Willys MB** (`docs/art/vehicules/willys_mb/`).

## Règles impératives

- Une seule pièce par image, isolée, rien d'une autre pièce (pas de roue dans la caisse).
- Vue de profil stricte, orientée vers la droite, sans perspective.
- Lumière du haut à gauche, ombres douces, rendu peint semi-réaliste.
- Fond uni magenta pur `#FF00FF`, ou transparent si possible. Pas d'ombre au sol.
- Aucun texte, logo, marque ou personnage.
- Respecter la silhouette et les proportions du gabarit `gabarits/<piece>.png`
  (l'utilisateur le joint à la conversation si tu ne peux pas l'ouvrir).
- Rapport largeur/hauteur de l'image = celui de la taille en cellules du cahier.
- Après la caisse validée, garder exactement le même style, la même usure et la même
  lumière pour toutes les autres pièces.

## Ordre de production (Willys MB)

caisse → chassis → roue → mitrailleuse → moteur → transmission.

## Avant de dessiner chaque pièce

Rappelle en 3 lignes : la pièce, son rapport largeur/hauteur, ce qu'elle ne doit pas
contenir. Puis génère l'image.

## Livraison

Tu n'écris pas dans le dépôt. L'utilisateur télécharge l'image et la transmet à Claude,
qui la détoure, l'enregistre dans `art/<piece>.png` et vérifie l'assemblage.
