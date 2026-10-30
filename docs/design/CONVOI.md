# Mode convoi — Folie Mécanique

Statut : prototype jouable (DEC-026). Distingue ce qui est **décidé** de ce qui reste **ouvert**.
Code : `game/scripts/combat/` ; valeurs : `game/data/combat_proto.json` ; test : `game/tests/test_combat.gd`.

## Principe

Le cœur du jeu est le convoi visible et contrôlable qui avance de profil et combat.
La base est mise en pause (code conservé, plus affichée au lancement). Le jeu démarre
directement sur une **expédition permanente**. On part **très léger : une Jeep et deux survivants**.
Le convoi avance, rencontre des ruines à fouiller, des véhicules abandonnés à réparer et à récupérer,
et des ennemis (véhicules, bâtiments) dont on prend le butin. Le danger augmente avec la distance.

## Contrôle : ordres tactiques

Pas de visée au doigt. Le joueur donne des ordres, le convoi tire seul. **Pause active** :
les ordres restent possibles en pause ; vitesse ×1, ×2, ×3.

| Niveau | Ordres |
|---|---|
| Convoi | Marche (reculer, halte, avancer) · Cible (plus proche, véhicules, bâtiments) · Visée (libre, roues, armes, châssis) · Fouille (automatique, à l'arrêt seulement) |
| Véhicule | Feu libre / cessez-le-feu · Réparer (automatique) · Rang vers l'avant / l'arrière · Abandonner |

**Toucher un véhicule** (le sien ou un véhicule trouvé) ouvre son état : rien ne s'affiche s'il n'y a rien
de cassé ; sinon une icône par pièce abîmée (canon, chenilles ou roues, moteur, suspension, cabine,
châssis ; orange = abîmée, rouge = détruite). Toucher une icône envoie un **mécanicien** : le convoi
s'arrête, le personnage marche jusqu'à la pièce et la répare. Un véhicule trouvé, une fois en état de
rouler, propose **Rejoindre le convoi**.

## Pièces cassables et effets

Chaque véhicule a des pièces avec des points de vie. Rien n'est animé à la casse en V0 :
la pièce est signalée (pastille orange puis rouge avec croix, fumée, carte du véhicule).

| Pièce | Effet quand abîmée (< 50 %) | Effet quand détruite |
|---|---|---|
| Roues / chenilles | vitesse ×0,7 | véhicule immobilisé, **le convoi est bloqué** |
| Moteur | vitesse ×0,7 | véhicule immobilisé, convoi bloqué |
| Suspension | vitesse ×0,8, précision ×0,85 | vitesse ×0,5, précision ×0,6 |
| Canon / mitrailleuse | — | cette arme ne tire plus |
| Cabine | — | précision ×0,5, l'équipage encaisse 30 % de chaque coup |
| Châssis | — | véhicule détruit (épave) |

Équipage : tous hors de combat = véhicule neutralisé (épave récupérable, non détruite).

## Combat

Déterministe (graine). Dégâts = `dégâts × pénétration / (pénétration + blindage × coefficient de zone)`.
Les roues, chenilles et suspensions sont peu blindées ; le châssis l'est davantage.
Un canon blesse aussi le châssis (25 %). Une mitrailleuse ne tire pas sur un blindé
(blindage > 25) : elle économise ses munitions. Les fantassins en bâtiment (fusils) menacent
les véhicules ouverts (Willys, BMW, half-track) mais pas les blindés.
Bâtiments : structure + tireurs ; la mitrailleuse vise les tireurs, le canon la structure.
Munitions et carburant sont consommés ; à court, le convoi cesse le feu ou s'arrête.

## Départ, trouvailles et survivants

- Départ : Willys MB, 2 survivants. La première rencontre est toujours une ruine à fouiller et un
  véhicule abandonné (BMW) : elle montre la boucle fouiller, réparer, récupérer.
- Un véhicule ennemi **neutralisé** (équipage hors de combat) est réparable et récupérable ; un véhicule
  dont le châssis est détruit n'est que démontable.
- Un véhicule récupéré rejoint le convoi avec 1 survivant ; les ruines peuvent livrer des survivants
  (réserve si aucun siège libre).
- Pendant la fouille, des survivants marchent de leur véhicule jusqu'à la ruine ou l'épave puis reviennent.

## Butin et réparation

- Une épave ou un bâtiment neutralisé se **fouille** (convoi garé à 5 m, sans menace ; 14 m pour les réparations) :
  munitions, carburant, métal et **pièces récupérées** (avec leur état en %).
- **Réparer** (à l'arrêt) : une pièce abîmée se répare avec du métal ; une pièce détruite se
  remplace par une pièce récupérée compatible (état conservé) ou se rafistole à 25 % pour 10 métal.
- **Abandonner** un véhicule le laisse sur place, démontable comme une épave.

## Rencontres

Tirées à graine fixe par palier de 400 m : patrouilles, véhicules en barrage, fermes, hangars,
bunkers, puis half-tracks, chars Stuart et Sherman, Tiger I en barrage au palier 6.

## Balles et armes

Chaque tir crée un **projectile** (modèle) : bouche de l'arme, point d'impact précis (zone touchée, ou sol si raté),
vitesse propre à l'arme (mitrailleuse 150 m/s, obus 85 à 110 m/s). Les dégâts s'appliquent **à l'arrivée**.
La vue dessine un trait traçant (mitrailleuse), un obus avec sillage (canon), des étincelles à l'impact,
un ricochet quand la pénétration est trop faible, une gerbe de terre quand le tir est raté.
Aucune barre de vie ennemie n'est affichée : seul l'état de nos véhicules est connu.

## Embuscade

Une **alerte à droite** annonce la vague (nombre, distance, délai). Le joueur peut : **s'abriter** (l'équipage marche
jusqu'à un bâtiment en ruine proche : 2 à 3 postes de tir, fenêtres propres à chaque bâtiment), **camoufler** un
véhicule vide (5 s, les ennemis ne le visent plus), **poser des mines** (4 métal pièce, armées après 6 s, dégâts
roues et suspension). La garnison tire au fusil antichar ; sa **première salve est renforcée** (surprise). Elle
n'est visible qu'après avoir tiré ; si l'ennemi la repère, il peut la viser. Le convoi ne repart pas tant que
l'équipage n'a pas rembarqué et que les véhicules sont camouflés (« Reprendre la route »).

## Bâtiments

Maison de village, ferme, grange, église (clocher de 14 m, plafond de zoom), bunker. Style européen.

## Relief et décor

Collines jusqu'à ~15° (`Terrain.relief`) : les véhicules s'inclinent, la caméra suit la hauteur, le convoi ralentit en montée
(×0,55 mini) et accélère en descente (×1,3 maxi). Décor semé : poteaux, cactus, arbres morts, rochers, carcasses,
ville en ruine au loin, nuages, poussière des roues.

## Architecture

| Fichier | Rôle |
|---|---|
| `combat_modele.gd` | Toute la logique, sans dessin (testable sans écran) |
| `convoi_vue.gd` | Caméra, dessin, effets, cartes de véhicules, panneau d'ordres |
| `batiment_dessin.gd` | Bâtiments ennemis dessinés par le code |

Réutilise `VehiculeDessin`, `Silhouette` et `Terrain` du prototype de base.

## Constat d'équilibrage (6 graines, ordres naïfs : avancer en continu)

Le convoi tient entre 570 et 1 020 m et détruit 4 à 8 ennemis, puis tombe à court de
munitions ou de véhicules. L'objectif est qu'un joueur qui réfléchit (visée, réparation,
rang, fouille) aille nettement plus loin. À confirmer par essais humains.

## Son

Ambiance et musique démarrent au premier toucher (exigence des navigateurs). Moteur du véhicule le plus
lourd tant que le convoi roule, tirs, impacts, explosions, atelier, radio.

## Ouvert

- Lien avec la base : que fait-on du butin et des pièces ? (atelier, DEC-016)
- Temps réel et absence : combat suspendu ou résolu automatiquement hors connexion (DEC-009, DEC-022).
- Capacité de chargement par véhicule, fantassins à pied, faune, nuit.
- Remorquage d'un véhicule immobilisé, équipage blessé et soins.
- Animations de casse, art définitif.
