# Folie Mécanique

Jeu mobile 2D (iPhone, paysage) de **convoi** dans une France post-apocalyptique figée dans les années 1940.
Le joueur est le chef d'un convoi indépendant qui traverse un no man's land dangereux entre des zones habitées
(ouverture et départ : [`docs/scenario/OUVERTURE.md`](docs/scenario/OUVERTURE.md)). Le cœur du jeu : construire
et mener son convoi, véhicule par véhicule, pièce par pièce, sur une grille de construction.

> La [Bible du lore](docs/lore/01_BIBLE_FOUNDATION) est la référence universelle du monde (elle peut servir à d'autres jeux).
> Les documents de ce jeu doivent s'y conformer (DEC-091).

## État actuel

Prototype jouable en Godot 4.3 / GDScript (mode convoi, grille de construction, combat, sons), publié sur GitHub Pages
(voir [`game/LISEZMOI.md`](game/LISEZMOI.md)). Le 06/11/2026, le projet a été **recentré sur la Bible** : on garde la grille,
le reste du prototype est réexaminé élément par élément.

Résumé court et à jour : [`STATE.md`](STATE.md). Navigation complète : [`docs/INDEX.md`](docs/INDEX.md).

## Rubriques documentaires

| Rubrique | Où |
|---|---|
| Monde et lore | [`docs/lore/`](docs/lore/) (Bible), [`docs/design/LORE.md`](docs/design/LORE.md) |
| Vision et conception | [`docs/design/VISION.md`](docs/design/VISION.md), [`docs/design/CONVOI.md`](docs/design/CONVOI.md) |
| Grille de construction | [`docs/design/GRILLE.md`](docs/design/GRILLE.md) |
| Scénario | [`docs/scenario/`](docs/scenario/) |
| Décisions | [`docs/DECISIONS.md`](docs/DECISIONS.md) |
| Questions ouvertes | [`docs/OPEN_QUESTIONS.md`](docs/OPEN_QUESTIONS.md) |
| Tâches | [`docs/TASKS.md`](docs/TASKS.md) |
| Registre des documents | [`docs/DOCUMENT_REGISTRY.md`](docs/DOCUMENT_REGISTRY.md) |
| Audits | [`docs/audits/`](docs/audits/) |

## Tableaux de données

- Véhicules, armes, composants : [`data/master/`](data/master/) (index : [`data/master/INDEX.md`](data/master/INDEX.md)).
  Ces CSV sont **exportés** depuis `sources/base_maitre.xlsx` : ne pas les éditer à la main.
- Armes historiques (première passe) : [`armes_historiques.csv`](data/master/armes_historiques.csv),
  [`armes_vehicules_liaison.csv`](data/master/armes_vehicules_liaison.csv).
- Règles : [`data/rules/regles_canoniques.json`](data/rules/regles_canoniques.json). Contrats : [`docs/DATA_CONTRACTS.md`](docs/DATA_CONTRACTS.md).

## Direction artistique

- Brief officiel : [`docs/art/DIRECTION_ARTISTIQUE.md`](docs/art/DIRECTION_ARTISTIQUE.md) (prévaut sur [`docs/design/GRAPHISMES.md`](docs/design/GRAPHISMES.md)).
- Pipeline et registre : [`docs/art/ART_PIPELINE.md`](docs/art/ART_PIPELINE.md), [`docs/art/asset-register.csv`](docs/art/asset-register.csv).
- Audio : [`docs/audio/ELEVENLABS.md`](docs/audio/ELEVENLABS.md).

## Prochaines priorités

Voir [`docs/TASKS.md`](docs/TASKS.md) (section du 06/11/2026) et [`docs/OPEN_QUESTIONS.md`](docs/OPEN_QUESTIONS.md). En bref :
trancher les questions ouvertes de l'ouverture, réexaminer le prototype face à la Bible, coder le nouveau départ
et les factions, sourcer le catalogue des armes.

## Règles pour développeurs et IA

[`AGENTS.md`](AGENTS.md).
