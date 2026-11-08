# Projets pour plus tard — Folie Mécanique

Idées réfléchies avec le créateur, **ni codées ni testées** (DEC-152). Chaque fiche dit l'idée, la place dans le lore, la mécanique
proposée, ce qu'elle réutilise du prototype et les questions à trancher. On passe une fiche en tâche (`docs/TASKS.md`) seulement
quand le créateur le demande.

---

## PRJ-001 — La baie des marées (08/11)

### L'idée du créateur

Une carte où **l'eau monte et redescend** : on ne traverse que pendant certains créneaux. Au moment de partir (sortie d'une ville,
carrefour, choix du secteur), un avertissement dit si l'on n'a **pas le temps**, **juste le temps** ou **largement le temps** de passer.
L'eau monte depuis le bas de l'écran. Chaque véhicule a un **point critique** : si l'eau l'atteint, le moteur est perdu, et le convoi
meurt peu à peu. Au milieu, une **ville sur une hauteur**, protégée par des murailles et hors de l'eau.

### Place dans le lore (proposition, à valider)

- **Où** : une baie entre le Cotentin et la Bretagne, inspirée de la baie du Mont-Saint-Michel et du passage du Gois, déformée comme le
  reste de la France du jeu (DEC-101). Elle s'accorde avec le camp du nord du Cotentin déjà décidé.
- **Pourquoi l'eau est folle** : le Programme Atmosphère (EVT-002) a détraqué le climat ; dans la baie, les marées sont devenues plus
  hautes et plus rapides qu'avant la guerre, et irrégulières. Les anciennes routes de grève sont submergées deux fois par jour.
  Le mystère reste entier sur la cause exacte, comme le veut la Bible.
- **Qui y vit** : le **Réseau des Marées** (FAC-003), qui « sait lire les marées ». Sa ville : un rocher fortifié au milieu de la baie,
  digues et murailles de pierre doublées de tôles, port de pêche, épaves échouées réutilisées comme remparts. Nom de travail :
  **Mont-Tombe** (l'ancien nom réel du Mont-Saint-Michel). Le Réseau n'ayant pas de capitale, la ville est tenue par quelques familles,
  pas par un maire unique : c'est une variante de ville à part.
- **Ce que le Réseau vend** : des **tables des marées**. Sans elles, l'avertissement est approximatif (un passeur « estime ») ;
  avec, il est exact. L'information devient une marchandise, dans l'esprit du maire mal renseigné (DEC-150).

### Mécanique proposée

1. **La marée** : un niveau d'eau qui suit un cycle régulier (par exemple deux marées par jour de jeu), avec une amplitude propre à la
   baie. Valeurs dans les données (période, amplitude, décalage par secteur), aucune valeur écrite dans le code.
2. **La route** : le profil du terrain compte. Les creux sont noyés les premiers, les bancs de sable les derniers. Pour chaque point bas
   de la traversée, on calcule l'heure à laquelle l'eau atteint le point critique des véhicules.
3. **L'avertissement au départ** : temps de traversée (distance ÷ vitesse du véhicule le plus lent, remorques comprises) comparé au temps
   disponible au point le plus bas.
   - **Pas le temps** : la marge est négative. Proposition : « attendre la marée basse » en ville, avec le temps accéléré comme la nuit à l'abri.
   - **Juste le temps** : la marge est inférieure à 20 % environ. Une seule panne ou une seule embuscade peut tout perdre.
   - **Largement le temps** : la marge dépasse la moitié du trajet.
   - Sans table des marées : estimation floue, avec une erreur tirée au hasard et une graine fixe pour rester reproductible.
4. **L'eau à l'écran** : une nappe qui monte du bas, remplit d'abord les creux du relief, avec vagues, écume au contact du sol, reflets
   et teinte sous l'eau. De nuit, les projecteurs de Mont-Tombe balaient la baie (on réutilise ceux des portes de ville).
5. **Le point critique de chaque véhicule** : la hauteur de l'admission d'air du moteur, en mètres au-dessus du sol, propre à chaque modèle.
   Par exemple, la Jeep réelle passe environ 50 cm d'eau ; le Berliet et le half-track un peu plus.
   - Eau sous les moyeux : rien.
   - Eau entre les moyeux et le point critique : le véhicule ralentit (résistance de l'eau).
   - Eau au-dessus du point critique : **moteur noyé**. C'est un dégât grave du moteur, qui immobilise le véhicule. Avec la règle
     actuelle « véhicule immobilisé, convoi bloqué », le convoi est piégé. Le joueur doit alors choisir d'**abandonner** le véhicule pour
     sauver les autres (on ne revoit jamais ce qu'on laisse).
   - Équipage : il grimpe sur le toit, puis s'affaiblit (froid, noyade lente). Cargaison : les vivres sont gâtés et les munitions mouillées.
6. **Ce que la baie donne à la grille** : une nouvelle greffe, le **tuba d'admission**, un conduit qui relève le point critique, très
   « Mad Max ». Elle fait aussi briller le **DUKW** amphibie, déjà au catalogue : il flotte, il peut servir de bac et remorquer.
   Le Berliet pourra recevoir un tuba en option dans sa vitrine.
7. **La tension** : des pillards qui attaquent au milieu de la traversée pour retarder le convoi jusqu'à ce que l'eau le prenne. C'est
   l'embuscade parfaite, et les deux systèmes se combinent sans règle nouvelle.

### Ce qu'on réutilise

Relief et terrain aplani (villes), ville standard (variante « insulaire » : portes qui ne s'ouvrent qu'à marée basse), pièces cassables
(moteur), abandon de véhicule, Kit (une ligne « marée » pour régler le niveau à la main et tester), sauvegarde, captures automatiques.

### Découpage quand on s'y mettra

P1 modèle (niveau d'eau, point critique par véhicule, avertissement, tests sans écran) · P2 dessin de l'eau et des véhicules noyés
· P3 Mont-Tombe et ses familles, table des marées · P4 greffe tuba, rôle du DUKW · P5 réglages en essai sur iPhone.

### À trancher (OQ-028)

- Emplacement final et nom de la ville (Mont-Tombe ?), et rôle de la baie dans l'histoire (chapitre, mission du Réseau des Marées ?).
- Rythme des marées : deux par jour de jeu, ou plus lent pour laisser le temps d'agir ?
- Un moteur noyé est-il réparable (vidange, séchage au garage) ou perdu pour de bon ?
- L'eau de mer abîme-t-elle les véhicules avec le temps (rouille) ?
- Bancs de sable où s'arrêter à mi-chemin pour attendre ?
- Le Réseau des Marées fait-il passer les véhicules un par un en bac, contre paiement ?

---

## PRJ-002 — Les trains routiers à deux moteurs (08/11)

### L'idée du créateur

Des **super camions** : de gros tracteurs à **deux moteurs**, dans l'esprit des War Rigs de Mad Max. Réfléchir à leur place dans le jeu
et à la faction qui pourrait en posséder.

### Nom d'époque

**Train routier**, un vrai terme français du début du siècle pour un tracteur qui tire plusieurs remorques. Surnom sur la route :
**mastodonte**. Le mot « War Rig » n'est pas repris.

### Qui en possède (proposition, à valider, sans faction « bonne » ni « mauvaise », comme le veut la Bible)

| Faction | Leurs trains routiers | Pourquoi |
|---|---|---|
| **Raffineurs du Sud (FAC-002)**, propriétaires principaux | Des trains de citernes qui montent le carburant raffiné vers ceux qui paient. Chaque famille peint le sien à ses couleurs ; les rivalités entre familles se voient sur la route | Leur puissance est de transformer et de **transporter** le carburant ; la Bible cite transporteurs et familles rivales |
| **Compagnies de l'Est (FAC-001)** | Peu nombreux, numérotés et inscrits aux registres (« Tracteur n° 7 »), escortés de façon militaire, chargés selon des quotas | Organisation industrielle, registres, quotas, contrôle des stocks |
| **Récupérateurs (FAC-005)** | Rares monstres bricolés qui servent d'ateliers mobiles | La Bible leur donne des véhicules blindés et des ateliers mobiles |
| Hommes du Péage (FAC-007) | Ils n'en ont pas : ils les rançonnent ou les capturent à leurs barrages | Événement possible : un train routier bloqué à un péage |

### Comment l'implanter avec ce qui existe

- **Base** : un tracteur lourd de chantier ou de transport de chars. Le Diamond T, déjà au catalogue, fera l'affaire au début. En Grille V2
  (DEC-121 à 125), c'est une base qu'on **rallonge**, à laquelle on **ajoute un essieu** et qu'on **renforce**, au garage seulement.
- **Deux moteurs** : la grille accepte déjà plusieurs moteurs, mais elle les pénalise. Proposition : une nouvelle pièce, le **coupleur**
  (boîte de transfert), qui relie les deux moteurs. Avec elle, les puissances s'additionnent, avec une petite perte, et chaque moteur
  exige son radiateur.
- **L'intérêt en jeu, la redondance** : si un moteur est détruit, le train routier continue à moitié de puissance au lieu de s'arrêter et
  de bloquer le convoi. C'est la vraie différence avec un camion ordinaire.
- **Le prix** : il consomme deux fois plus. Avec essence et gazole distincts (DEC-094), on peut même avoir un moteur de chaque.
- **Remorques** : déjà codées (DEC-080) ; le train routier en tire une ou deux (citerne, plateau, cage). Il ralentit moins qu'un camion
  ordinaire grâce à ses deux moteurs.
- **Combat** : une grosse cible avec beaucoup de postes de tir, idéale pour les abordages (DEC-077). Côté ennemi, c'est le **chef de convoi** :
  détruire ses deux moteurs l'immobilise, et ses remorques sont un gros butin.
- **Rencontres** : trains de citernes des Raffineurs à escorter (une mission du maire), à attaquer (gros butin, faction fâchée) ou à
  croiser pour commercer, comme les marchands sur châssis de char du lore du prototype.

### Pour le joueur : deux voies, à choisir

1. **Un véhicule à part**, rare, de fin de partie : base trouvée ou prise à l'ennemi, garage de haut niveau, deux moteurs et un coupleur.
2. **L'évolution du Berliet** : le Berliet reste le camion de l'expédition du début à la fin (DEC-139). Son châssis long, rallongé et
   renforcé, recevrait un second moteur derrière la cabine et deviendrait le train routier de l'expédition. Cette voie garde le lien
   affectif avec le camion de départ.

### Art

Selon la méthode DEC-138 : une image maître en pièces séparées (tracteur, second moteur avec ses échappements, coupleur, pare-buffle),
puis des remorques par découpe. En attendant, un dessin par le code, comme pour les modules du Berliet.

### À trancher (OQ-029)

- Voie 1 (véhicule à part) ou voie 2 (le Berliet devient train routier), ou les deux ?
- Les Raffineurs du Sud sont-ils bien les propriétaires principaux ?
- À quel moment de l'histoire le joueur peut-il en avoir un ?
- Le coupleur se fabrique-t-il, ou se récupère-t-il seulement sur un train routier détruit ?
