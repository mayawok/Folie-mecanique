# Textes du jeu (DEC-193, DEC-208)

Le jeu est publié en français et en anglais. **Aucun texte affiché ne s'écrit en dur dans le code.**

- Fichier : `game/data/textes.json`, deux blocs `fr` et `en` qui ont **exactement les mêmes clés** (vérifié par `game/tests/test_textes.gd`).
- Appel : `Textes.t("res.gazole")` ou `Textes.t("carb.perdu", [12, "diesel"])` (`%s` et `%d` pour les valeurs). Classe : `game/scripts/textes.gd`.
- Langue : celle de l'appareil si elle existe dans le fichier, sinon français. Clé absente dans une langue : texte français ; absente partout : la clé.
- Convention de clés : `domaine.sujet` (`res.` ressources, `carb.` carburants, puis `hud.`, `ville.`, `mission.`…).
- **Migration (10/11)** : fait pour les messages du journal et du HUD (combat, ville, mission, camp, terrain, atelier, mines, météo, abordage), 220 textes fr/en. Un test vérifie que fr et en ont les mêmes clés **et les mêmes valeurs à insérer**.
- **Pas encore migré** : l'éditeur de grille et l'atelier (`editeur_grille.gd`, `construction_libre.gd`), le Kit (outil de développement, français seulement), les menus principaux, les noms de pièces, véhicules, missions, quêtes, lieux, personnages et dialogues **qui vivent dans les fichiers de données** (`data/*.json`) : en anglais ils restent en français pour l'instant ; prochaine étape : une table de traduction par donnée.
- **Règle d'écriture** : jamais de bout de phrase français dans un argument (accords, « devant/derrière »…) ; chaque variante a sa propre clé.
- **Tests sans écran** : français imposé, pour que les vérifications de texte restent stables.
- Pour une nouvelle langue : copier le bloc `fr`, traduire, ajouter la langue à l'appareil de test.
