# Prototype jouable — Folie Mécanique

## Mode convoi (lancement par défaut, DEC-026)

Une Jeep et deux survivants avancent de profil dans le désert, affronte des ennemis (véhicules,
bâtiments) et récupère leur butin. Appuyer sur **Avancer** pour partir. Le convoi tire seul :
on donne des **ordres** (marche, cible, visée sur roues/armes/châssis, fouille) et, par véhicule,
cessez-le-feu, réparation, rang, abandon. **Pause** (ou Espace) : les ordres restent possibles.
Toucher un véhicule dans la scène affiche ses pièces cassées : toucher une icône envoie un mécanicien ;
un véhicule trouvé et réparé peut rejoindre le convoi. Les cartes en bas sélectionnent un véhicule. Détails : `docs/design/CONVOI.md`.
La base décrite plus bas est conservée mais n'est plus affichée : pour la rejouer, remettre
`run/main_scene="res://scenes/main.tscn"` dans `project.godot`.
Test sans écran : `godot --headless --path game -s res://tests/test_combat.gd`.

---

## Prototype de la base (en pause)

Boucle minimale : base → expédition → combat automatique → retour avec butin.
But du test : tenir 10 jours, **en temps réel** (1 jour de jeu = 1 jour réel, système 7).
La partie est sauvegardée dans le navigateur ; à chaque retour, un rapport résume l'absence.
Bouton **Test +6 h** : avance l'horloge pour tester sans attendre (retiré du jeu final).

Au lancement : **menu principal** (Continuer, Nouvelle partie, Garage, Options).
Sur la base, le bouton **II** (ou Échap) ouvre le **menu pause**. Le monde continue
d'avancer pendant la pause : le jeu est en temps réel.
Sur la base : **toucher un bâtiment** ouvre sa fiche et son arbre d'amélioration ; **toucher un véhicule** ouvre ses statistiques.
Une amélioration se construit avec les survivants affectés au poste **Chantier** ; une bulle indique le temps restant.
Les expéditions en cours s'affichent à gauche avec une barre jusqu'au retour.
Le **Garage** montre les 10 véhicules qui roulent (suspensions, chenilles) et tirent,
ainsi que les silhouettes des personnages.

## Jouer

Lien du navigateur (PC ou iPhone, en paysage) : https://mayawok.github.io/Folie-mecanique/
Il se met à jour tout seul quelques minutes après chaque envoi qui touche `game/`
(suivi dans l'onglet **Actions** du dépôt).

**Plein écran sur iPhone** : dans Safari, bouton Partager → « Sur l'écran d'accueil »,
puis lancer le jeu depuis l'icône. La barre d'adresse disparaît et le jeu va jusqu'aux bords.

Commandes de la base : glisser pour se déplacer, pincer (ou molette, boutons − / +) pour zoomer.
Sans carburant : choisir un lieu proche (6 h de route au plus), onglet **À pied**.

## Modifier l'équilibrage sans Claude

Toutes les valeurs sont dans `data/regles_proto.json` : temps et pénurie (`temps`, `penurie`), stocks de départ, production des
postes, expéditions à pied (`a_pied`), consommation, statistiques des véhicules, lieux, butin, pillards, combat.
Modifier le fichier sur GitHub (icône crayon), enregistrer : le jeu se reconstruit.

## Fichiers

| Fichier | Rôle |
|---|---|
| `scripts/jeu.gd` | Règles et état de la partie (aucun affichage) |
| `scripts/main.gd` | Interface : base, carte, convoi, rapport |
| `scripts/menus.gd` | Menu principal, menu pause, options de son |
| `scripts/garage.gd` | Vitrine des véhicules et des personnages |
| `scripts/vehicule_dessin.gd` | Véhicules dessinés par le code (roues, chenilles, suspensions, armes, équipage) |
| `scripts/personnage_dessin.gd` | Silhouettes de personnages dessinées par le code |
| `scripts/terrain.gd` | Désert qui défile (menu, garage) |
| `scripts/son.gd` | Musique, ambiances, bruitages, voix ; volumes |
| `data/formes_vehicules.json` | Formes des véhicules en mètres (modifiable sans Claude) |
| `assets/audio/` | Sons ElevenLabs, noms dans `docs/audio/ELEVENLABS.md` |
| `data/regles_proto.json` | Valeurs d'équilibrage |
| `assets/` | Images réduites, produites par `tools/export_proto.py` (ne pas modifier à la main) |
| `assets/fonts/` | Police Inter (licence SIL OFL 1.1, usage commercial autorisé) |
| `tests/test_sim.gd` | Test sans écran : `godot --headless --path game -s res://tests/test_sim.gd` |

## Hors prototype

Atelier, faune, récit, achats, notifications.
Chars (Stuart, Sherman, Tiger I), Diamond T et DUKW : visibles au Garage, pas encore dans les expéditions.
Les images de véhicules dans `assets/vehicules/` ne sont plus affichées (remplacées par le dessin du code) ;
elles restent pour l'art final.
