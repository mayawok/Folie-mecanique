# Prototype jouable — Folie Mécanique

## Mode convoi (lancement par défaut, DEC-026)

La partie commence par une caisse de pièces : glisser chaque pièce à sa place sur la grille pour assembler
une moto. On trouve ensuite de quoi en faire un side-car (bouton **Assembler**, convoi arrêté), de l'essence,
une arme, puis viennent les ennemis (véhicules, bâtiments) dont on récupère le butin. Appuyer sur **Avancer** pour partir. Le convoi tire seul :
on donne des **ordres** (marche, cible, visée sur roues/armes/châssis, fouille) et, par véhicule,
cessez-le-feu, réparation, rang, abandon. **Pause** (ou Espace) : les ordres restent possibles.
Toucher un véhicule dans la scène affiche ses pièces cassées : toucher une icône envoie un mécanicien ;
un véhicule trouvé et réparé peut rejoindre le convoi. Les cartes en bas sélectionnent un véhicule. Détails : `docs/design/CONVOI.md`.
Tests sans écran : `godot --headless --path game -s res://tests/test_combat.gd` et `res://tests/test_assemblage.gd`.

La gestion de base est archivée dans `archive/prototype_base/` (DEC-031).

## Jouer

Lien du navigateur (PC ou iPhone, en paysage) : https://mayawok.github.io/Folie-mecanique/
Il se met à jour tout seul quelques minutes après chaque envoi qui touche `game/`
(suivi dans l'onglet **Actions** du dépôt).

**Plein écran sur iPhone** : dans Safari, bouton Partager → « Sur l'écran d'accueil »,
puis lancer le jeu depuis l'icône. La barre d'adresse disparaît et le jeu va jusqu'aux bords.


## Modifier l'équilibrage sans Claude

Les valeurs du convoi sont dans `data/combat_proto.json` ; celles des véhicules dans `data/pieces.json` (une fiche par pièce : vitesse du roulement, points de vie, blindage du châssis…). Modifier le fichier sur GitHub (icône crayon), enregistrer : le jeu se reconstruit.

**Son sur iPhone** : depuis le 31/10, le son passe même en mode silencieux. S'il reste muet, vérifier le volume et toucher l'écran une fois (le navigateur n'autorise le son qu'après un premier toucher).
