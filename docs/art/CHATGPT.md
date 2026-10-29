# Instructions pour ChatGPT — production des images

Tu produis les images du jeu Folie Mécanique (iPhone, 2D, mode paysage, années 1940
post-apocalyptiques, désert). Claude gère le plan de production, découpe tes planches et
range les images. Le porteur de projet te donne le feu vert.

## À chaque feu vert

1. Lis `docs/art/PRODUCTION.md` et prends **le lot nommé par l'utilisateur** ; s'il n'en
   nomme aucun, le lot marqué « en cours ».
2. Lis son cahier (dans `PRODUCTION.md`, ou le fichier qu'il indique).
3. Annonce en une ligne par image ou pièce : nom, proportions, ce qu'elle ne doit pas
   contenir. Puis génère.
4. Ne passe jamais au lot suivant de toi-même : attends le feu vert de l'utilisateur.

## Style (toutes les images)

- Peinture numérique semi-réaliste, dans l'esprit d'*Earn to Die*, ambiance Mad Max,
  technologie des années 1940. Ton sérieux.
- Lumière du haut à gauche, ombres douces, palette : ocre, sable, rouille, kaki olive
  délavé, acier usé. Tout est usé, poussiéreux, rafistolé.
- Référence de style : `docs/art/vehicules/willys_mb/art/caisse.png` (validée).
  L'utilisateur la joint si tu ne peux pas l'ouvrir.
- Aucun texte, chiffre, logo, marque, drapeau ou croix rouge nette.

## Cadrage

- **Vue de profil stricte, sans perspective**, sujets orientés vers la droite.
  Seule exception : les icônes d'interface et de carte (3/4 autorisé).
- **Bâtiments : élévation de façade orthographique**, comme un dessin d'architecte :
  façade parallèle à l'écran, **aucune face latérale ni toit vu de dessus**, aucune
  dalle ni sol, bord inférieur droit et horizontal (le bâtiment se pose sur une ligne).
  Rien autour (pas de lampadaire, château d'eau, caisses ou véhicules en dehors du
  bâtiment) : les éléments décoratifs seront des images séparées.
- Fond uni magenta pur `#FF00FF`, ou transparent si possible. Pas d'ombre au sol,
  pas de sol dessiné (sauf couche `sol` du décor).
- Respecter les proportions données en mètres ou en cellules
  (1 cellule = 25 cm = 64 px).

## Planche (plusieurs éléments sur une image)

- Une seule vue par élément, aucune vue en plus.
- Éléments **séparés par au moins 40 px de magenta**, sans aucun contact.
- **Ordre de lecture = ordre de la liste du cahier** (gauche à droite, ligne par ligne) :
  Claude nomme les fichiers dans cet ordre.
- Tous les éléments d'une planche à la même échelle.

## Livraison

Tu n'écris pas dans le dépôt. L'utilisateur télécharge l'image et la transmet à Claude.
