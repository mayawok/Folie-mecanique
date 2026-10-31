# Prototype jouable — Folie Mécanique

## Mode convoi (lancement par défaut, DEC-026)

Une Jeep et deux survivants avancent de profil dans le désert, affronte des ennemis (véhicules,
bâtiments) et récupère leur butin. Appuyer sur **Avancer** pour partir. Le convoi tire seul :
on donne des **ordres** (marche, cible, visée sur roues/armes/châssis, fouille) et, par véhicule,
cessez-le-feu, réparation, rang, abandon. **Pause** (ou Espace) : les ordres restent possibles.
Toucher un véhicule dans la scène affiche ses pièces cassées : toucher une icône envoie un mécanicien ;
un véhicule trouvé et réparé peut rejoindre le convoi. Les cartes en bas sélectionnent un véhicule. Détails : `docs/design/CONVOI.md`.
Test sans écran : `godot --headless --path game -s res://tests/test_combat.gd`.

La gestion de base est archivée dans `archive/prototype_base/` (DEC-031).

## Jouer

Lien du navigateur (PC ou iPhone, en paysage) : https://mayawok.github.io/Folie-mecanique/
Il se met à jour tout seul quelques minutes après chaque envoi qui touche `game/`
(suivi dans l'onglet **Actions** du dépôt).

**Plein écran sur iPhone** : dans Safari, bouton Partager → « Sur l'écran d'accueil »,
puis lancer le jeu depuis l'icône. La barre d'adresse disparaît et le jeu va jusqu'aux bords.


## Modifier l'équilibrage sans Claude

Les valeurs du convoi sont dans `data/combat_proto.json`. Modifier le fichier sur GitHub (icône crayon), enregistrer : le jeu se reconstruit.

**Son sur iPhone** : depuis le 31/10, le son passe même en mode silencieux. S'il reste muet, vérifier le volume et toucher l'écran une fois (le navigateur n'autorise le son qu'après un premier toucher).
