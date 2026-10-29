# Production des images — file de priorité

Géré par Claude. ChatGPT produit **le lot marqué « en cours »**, et seulement lui.
Le porteur de projet donne le feu vert et transmet les images ; Claude les découpe,
les range, met à jour `asset-register.csv` et passe le lot suivant « en cours ».

Règles générales de dessin : `docs/art/CHATGPT.md`. Bible de style : `docs/design/GRAPHISMES.md`.
Échelle commune : 1 cellule = 25 cm = 64 px (une personne de 1,75 m = 7 cellules = 448 px).

## File

| # | Lot | Images | Statut | Rangement (sous `docs/art/`) |
|---|---|---|---|---|
| 1 | Willys MB : moteur, transmission | 1 planche | validé | `vehicules/willys_mb/art/` |
| 2 | Icônes des 6 ressources | 1 planche | validé | `ui/` |
| 3 | Décor désert, 4 couches | 4 images | validé | `decor/` |
| 4 | Bâtiments A : atelier (référence de style des bâtiments) | 1 image | validé | `batiments/` |
| 5 | Bâtiments B : cuve, puits/condenseur, entrepôt, cuisine | 1 planche | validé | `batiments/` |
| 6 | Bâtiments C : infirmerie, nid de mitrailleuse, tour de guet | 1 planche | validé (croix rouge délavée en gris par Claude) | `batiments/` |
| 7 | Survivants : 6 poses | 1 planche | validé (« course » à la place de « assis ») | `personnages/` |
| 8 | Faune : meute, prédateur, nuée | 1 planche | validé | `faune/` |
| 9 | Carte : fond et 7 icônes de lieux | 2 images | validé ; fond en relief vu du dessus ; « mine » en plus ; « ville » reçue à part (cadre différent, à harmoniser) | `carte/` |
| 10 | Calques de dégâts et effets | 1 planche | validé (10 éléments) | `fx/` |
| 11 | Véhicules 2 à 10 | 1 à 2 par véhicule | 11a, 11b, 11c reçus et découpés (assemblage sur gabarit à faire) ; **11d en cours** ; 11e à 11i à faire | `vehicules/<id>/art/` |
| 12 | Icônes d'actions de l'interface | — | bloqué : écrans pas encore conçus | `ui/` |
| 13 | Illustrations de récit (6 à 8) | — | bloqué : système 8 (récit) | `recit/` |

Pourquoi cet ordre : le premier prototype est l'atelier (véhicule + ressources), puis
l'écran de base (décor, bâtiments, survivants), puis les expéditions (faune, carte,
effets). Les lots dont la conception n'est pas finie sont bloqués pour éviter de
redessiner.

## Cahiers des lots

L'ordre des pièces dans chaque liste est **l'ordre de lecture sur la planche**
(de gauche à droite, ligne par ligne) : Claude nomme les fichiers dans cet ordre.

### Lot 1 — Willys MB : moteur, transmission

Voir `docs/art/vehicules/willys_mb/CAHIER.md`. Planche : `transmission` en haut, `moteur` en dessous.

### Lot 2 — Icônes des ressources

6 icônes carrées, même taille, en une ligne : eau (jerrican d'eau ou gourde),
nourriture (boîte de conserve et pain), carburant (jerrican rouge), métal (pile de
ferraille), matériaux (planches, câbles et pièces), munitions (cartouches et caisse).
Objet seul, vue de 3/4 autorisée **pour les icônes uniquement**, lisible à 64 px :
silhouette forte, peu de détails. Taille finale 256 × 256 px.

Validé le 2026-10-29. Jerrican recoloré en rouge par Claude (dessiné kaki, se confondait
avec la gourde à petite taille). Matériaux représentés par bois, briques et ciment.

### Lot 3 — Décor désert (parallaxe)

4 images **séparées**, très larges (format le plus panoramique possible), vue de
profil, horizon à la même hauteur sur les 4. Les bords gauche et droit doivent
pouvoir se raccorder (Claude corrige le raccord).

1. `ciel` : ciel de jour poussiéreux, soleil voilé, opaque (pas de magenta).
2. `lointain` : chaîne de montagnes arides, très estompée par la brume de chaleur.
3. `moyen` : dunes et rochers, quelques carcasses lointaines (pylône, épave d'avion).
4. `sol` : bande de sol de premier plan (sable tassé, cailloux, traces de chenilles),
   le dessus plat sert de ligne de roulage.

**Ciel validé** (`decor/bg_desert_ciel.png`) après étalonnage par Claude : ChatGPT l'avait
fait bleu vif et nuageux, il a été désaturé et voilé de brume de sable. Les couches 2 à 4
doivent s'accorder à cette version : **joindre `bg_desert_ciel.png`**, lumière chaude
et poussiéreuse, contrastes adoucis par la brume de chaleur, pas de ciel bleu.

Couches 2 à 4 sur fond magenta.

**Lot validé le 2026-10-29.** Les 4 couches sont étalonnées (désaturation, brume plus
forte au loin) et raccordables. Montage de référence dans un cadre 1920 × 1080, couches
mises à 1920 px de large : ciel plein cadre, bas de `lointain` à 860 px, bas de `moyen`
à 960 px, bas de `sol` à 1080 px. Limite : 1 820 px de large, un peu flou en plein écran
sur iPhone récent ; suffisant pour le prototype, à régénérer plus large avant publication. Aucun bâtiment, aucun véhicule entier, aucun personnage.

### Lots 4 à 6 — Bâtiments (niveau 1)

Vue de profil stricte, façade face au spectateur, posés sur une ligne de sol plate
(sans sol dessiné). Construits de récupération : tôle ondulée, bois, sacs de sable,
pièces de véhicules. Les niveaux 2 et 3 viendront plus tard (amélioration du même
bâtiment). Tailles (largeur × hauteur) :

| Bâtiment | Description | Taille (m) | Cellules |
|---|---|---|---|
| `atelier` | Hangar en tôle ouvert sur le côté, palan, établi, fosse | 8 × 5 | 32 × 20 |
| `cuve` | Citerne métallique cylindrique couchée sur tréteaux, robinet | 3 × 3 | 12 × 12 |
| `puits` | Puits avec chevalet et pompe à bras, condenseur à tubes à côté | 3 × 4 | 12 × 16 |
| `entrepot` | Abri bas en tôle, caisses et fûts empilés | 6 × 4 | 24 × 16 |
| `cuisine` | Abri ouvert, fourneau et cheminée en tuyau de poêle | 5 × 3,5 | 20 × 14 |
| `infirmerie` | Tente militaire à croix effacée (pas de croix rouge nette : emblème protégé) | 5 × 3 | 20 × 12 |
| `nid_mitrailleuse` | Sacs de sable en arc, mitrailleuse sur trépied, sans servant | 3 × 2 | 12 × 8 |
| `tour_guet` | Tour en poutres et tôle, plateforme, projecteur | 3 × 7 | 12 × 28 |

Lot 4 : l'atelier seul (il fixe le style des bâtiments). **Validé** au 2ᵉ essai (le 1ᵉʳ
était en perspective 3/4) : `batiments/bat_atelier_n1.png`, désaturé par Claude, retenu à
**8 × 3,7 m** (proportions de l'image). Lots 5 et 6 : joindre `bat_atelier_n1.png` comme
référence de style des bâtiments, en plus de la caisse du Willys. Lot 5 et 6 : planches dans
l'ordre du tableau.

### Lot 7 — Survivants

6 poses d'un même type de survivant, vue de profil tournée vers la droite, 1,75 m :
debout, marche, porte une caisse, travaille avec un outil, tient un fusil, assis.
Vêtements militaires dépareillés des années 1940, foulard et lunettes de protection
qui **cachent le visage** (pas de visage détaillé). Même échelle sur toute la planche.

### Lot 8 — Faune (désert)

Animaux réels, adaptés et redoutables, **pas de mutants** (ton sérieux). Vue de
profil tournée vers la droite, posture d'attaque.

| Pièce | Animal (proposition à valider) | Taille |
|---|---|---|
| `meute` | Chien sauvage du désert, maigre et musclé (un seul individu, multiplié en jeu) | 1,2 m de long |
| `predateur` | Grand lion du désert à crinière clairsemée, cicatrices | 3 m de long |
| `nuee` | Nuée de criquets en essaim (forme de nuage) | 4 m de large |

### Lot 11 — Véhicules 2 à 10

Mêmes règles que le Willys MB (`vehicules/willys_mb/CAHIER.md`), leçons retenues :
la caisse inclut pare-chocs et accessoires extérieurs ; le châssis inclut ressorts et
essieux ; le moteur inclut le radiateur ; une seule roue (ou un seul galet) dessinée,
réutilisée ; la transmission sans les longs arbres. Tout orienté vers la droite.

Pièces : `caisse`, `chassis`, `roue` (ou `chenille` + `galet` pour les chenillés,
`tourelle` + `canon` pour les chars), `armement`, `moteur`, `transmission`.
Planche unique pour les véhicules jusqu'à 5 m ; au-delà, **2 images** : la caisse
seule, puis les autres pièces en planche. Tailles (cotes de prototypage,
`data/master/base_maitre_vehicules.csv`) :

| # | Véhicule | Longueur × hauteur | Images | Particularités |
|---|---|---|---|---|
| 11a | BMW R75 side-car | 2,35 × 1,1 m | 1 | Moto + panier séparés ; mitrailleuse MG 34 sur le panier |
| 11b | Citroën Traction Avant | ≈ 4,45 × 1,52 m (estimation) | 1 | Berline civile rafistolée, sans armement d'origine |
| 11c | Camion Citroën T23 | ≈ 5,6 × 2,4 m (estimation) | 2 | Cabine et plateau bâché séparés |
| 11d | Diamond T 969 dépanneuse | 7,42 × 3,0 m | 2 | Grue de dépannage séparée |
| 11e | DUKW | 9,45 × 2,7 m | 2 | Coque amphibie, hélice |
| 11f | M3 Half-Track | 6,17 × 2,26 m | 2 | Roues avant + chenilles arrière |
| 11g | M3 Stuart | 4,53 × 2,64 m | 1 | Tourelle et canon séparés |
| 11h | M4 Sherman | 5,89 × 2,74 m | 2 | Tourelle et canon séparés |
| 11i | Tiger I | 8,45 × 3,0 m (avec canon) | 2 | Tourelle et canon séparés ; objectif final |

Avant validation, Claude recale chaque véhicule comme le Willys (gabarit et assemblage).

**Erreur à éviter (11a et 11b refusés)** : ChatGPT a produit une vue éclatée avec des
dizaines de petites pièces, des vues de face et d'arrière et des vitres sur fond magenta.
Dessiner **uniquement** les pièces listées ci-dessus (6 à 8 pièces), une vue de profil
chacune, rien d'autre. Ces planches sont gardées en réserve (`reserve/`) : le profil
complet sert d'épave de décor (`decor/epave_*.png`), les petites pièces de butin.

### Lot 9 — Carte

1. `fond_carte` : carte militaire d'état-major usée (papier jauni, taches, plis),
   relief désertique dessiné, **sans aucun nom ni texte**, format paysage.
2. Planche de 7 icônes (style tampon ou punaise dessinée, lisibles à 64 px) :
   base, oasis, ferme abandonnée, dépôt de carburant, champ de bataille, village, ville.

### Lot 11 — État au 2026-10-29

- 11a BMW R75 : 7 pièces (`caisse` = moto sans moteur ni roues, `panier`, `chassis`,
  `roue`, `mitrailleuse`, `moteur`, `transmission`). Logo du réservoir effacé par Claude.
- 11b Traction Avant : 5 pièces conformes. La transmission inclut un arbre long (toléré).
- 11c T23 : `cabine`, `plateau`, `chassis`, `roue`, `moteur`, `transmission`.
  Pseudo-lettrage du pneu effacé par Claude.
- Reste à faire par Claude : `gabarit.json` et `assemblage.png` de chaque véhicule.

### Lot 10 — Dégâts et effets

Une planche, chaque élément isolé : 3 impacts de balles (groupes), 1 trou d'obus,
1 plaque de rouille, 1 traînée d'huile, 1 panache de fumée noire, 1 flamme,
1 nuage de poussière, 1 éclair de tir. Fond magenta, pas de véhicule dessous.
