# Textes du jeu (DEC-193, DEC-208)

Le jeu est publié en français et en anglais. **Aucun texte affiché ne s'écrit en dur dans le code.**

- Fichier : `game/data/textes.json`, deux blocs `fr` et `en` qui ont **exactement les mêmes clés** (vérifié par `game/tests/test_textes.gd`).
- Appel : `Textes.t("res.gazole")` ou `Textes.t("carb.perdu", [12, "diesel"])` (`%s` et `%d` pour les valeurs). Classe : `game/scripts/textes.gd`.
- Langue : celle de l'appareil si elle existe dans le fichier, sinon français. Clé absente dans une langue : texte français ; absente partout : la clé.
- Convention de clés : `domaine.sujet` (`res.` ressources, `carb.` carburants, puis `hud.`, `ville.`, `mission.`…).
- **Migration (10/11)** : fait pour les messages du journal et du HUD (combat, ville, mission, camp, terrain, atelier, mines, météo, abordage), 220 textes fr/en. Un test vérifie que fr et en ont les mêmes clés **et les mêmes valeurs à insérer**.
- **Migration terminée le 26/11 (DEC-263)** : interface, menus, villes, éditeur de grille, atelier, transformation, défauts de construction, messages du modèle (≈ 620 textes de plus). **Reste en français, volontairement** : le Kit (outil de développement), les noms propres (villes, lieux, prénoms), les enseignes peintes des villes (MAIRIE, CAFÉ, LIBERTÉ · ÉGALITÉ · FRATERNITÉ : décor français), les lignes de débogage.
- **Données** (`data/*.json`, DEC-263) : les fichiers restent en français ; au chargement, en anglais, `Textes.traduire()` remplace les champs affichés (`nom`, `titre`, `texte`, `fiche`, `phrases`, `repliques`, `cargaison`…) par leur traduction, prise dans le bloc `donnees_en` de `textes.json` : `textes` (clé = texte français exact) et `prefixes` (noms de pièces en série : « Châssis Willys MB » → « Willys MB chassis »). Un texte absent de la table reste tel quel (noms propres). **Ajouter une donnée affichée = ajouter sa traduction dans `donnees_en.textes`.** Test : `test_langue.gd` (partie complète en anglais, journal sans phrase française).
- **Outils** (hors dépôt, refaits au besoin) : extraction des textes en dur d'un fichier et application d'une table « ligne | texte | clé | anglais ».
- **Règle d'écriture** : jamais de bout de phrase français dans un argument (accords, « devant/derrière »…) ; chaque variante a sa propre clé.
- **Tests sans écran** : français imposé, pour que les vérifications de texte restent stables.
- Pour une nouvelle langue : copier le bloc `fr`, traduire, ajouter la langue à l'appareil de test.
