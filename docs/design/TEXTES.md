# Textes du jeu (DEC-193, DEC-208)

Le jeu est publié en français et en anglais. **Aucun texte affiché ne s'écrit en dur dans le code.**

- Fichier : `game/data/textes.json`, deux blocs `fr` et `en` qui ont **exactement les mêmes clés** (vérifié par `game/tests/test_textes.gd`).
- Appel : `Textes.t("res.gazole")` ou `Textes.t("carb.perdu", [12, "diesel"])` (`%s` et `%d` pour les valeurs). Classe : `game/scripts/textes.gd`.
- Langue : celle de l'appareil si elle existe dans le fichier, sinon français. Clé absente dans une langue : texte français ; absente partout : la clé.
- Convention de clés : `domaine.sujet` (`res.` ressources, `carb.` carburants, puis `hud.`, `ville.`, `mission.`…).
- **Migration** : en cours, par lots. Déjà fait : libellés des ressources du HUD, messages de carburant. Reste : le reste du HUD, villes, missions, dialogues, journal, menus, bulles d'aide.
- Pour une nouvelle langue : copier le bloc `fr`, traduire, ajouter la langue à l'appareil de test.
