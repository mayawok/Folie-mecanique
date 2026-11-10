# Index du projet --- source d'entrée développeurs

## Ordre de lecture minimal

1.  `AGENTS.md` --- règles obligatoires pour développeurs et IA.
2.  `docs/TASKS.md` --- choisir une tâche précise par ID.
3.  `docs/ARCHITECTURE_MODULAIRE.md` --- propriétaires de modules et
    frontières.
4.  `docs/DATA_CONTRACTS.md` --- contrats partagés, unités et
    identifiants.
5.  La documentation spécifique du système touché.
6.  Les tests du module et ses dépendances directes.

Ne pas demander à chaque intervenant de relire tout le projet. L'index
et les tâches doivent diriger vers les seuls documents nécessaires.

## Navigation

| Je cherche… | Document |
|---|---|
| Où en est le projet | [`STATE.md`](../STATE.md) |
| Tous les documents, leur statut | [`DOCUMENT_REGISTRY.md`](DOCUMENT_REGISTRY.md) |
| Ce qui est décidé | [`DECISIONS.md`](DECISIONS.md) |
| Ce qui reste à trancher | [`OPEN_QUESTIONS.md`](OPEN_QUESTIONS.md) |
| Ce qu'il y a à faire | [`TASKS.md`](TASKS.md) |
| Le monde (référence universelle) | [`lore/01_BIBLE_FOUNDATION`](lore/01_BIBLE_FOUNDATION) |
| Les choix de ce jeu | [`design/VISION.md`](design/VISION.md), [`scenario/OUVERTURE.md`](scenario/OUVERTURE.md) |
| Les contrats de données | [`DATA_CONTRACTS.md`](DATA_CONTRACTS.md) |
| La direction artistique | [`art/DIRECTION_ARTISTIQUE.md`](art/DIRECTION_ARTISTIQUE.md) |

## Source de vérité

-   **Monde (référence universelle, sert à tout jeu)** : `docs/lore/01_BIBLE_FOUNDATION` ; propositions en attente de validation : `docs/lore/communautes-ferroviaires.md`
-   Registre des documents : `docs/DOCUMENT_REGISTRY.md` ; questions ouvertes : `docs/OPEN_QUESTIONS.md`
-   **Ce jeu-ci** : vision `archive/docs_design/VISION_2026-11-10.md` (archivé), scénario `docs/scenario/` (ouverture : `OUVERTURE.md` ; proposition : `mission-liberation-camp-travailleurs.md`)
-   État courant et priorités : `STATE.md` (racine)
-   Règles structurées : `data/rules/regles_canoniques.json` (v1.9, sans les sections de gestion de base)
-   Catalogue véhicules et tables de systèmes : `data/master/*.csv`
    (un fichier par onglet, voir `data/master/INDEX.md`). Édition dans
    `sources/base_maitre.xlsx` (v1.9), puis
    `python3 tools/export_xlsx.py sources/base_maitre.xlsx data/master`.
-   Mode convoi (cœur du jeu) : `docs/design/CONVOI.md`
-   Grille de construction : `docs/design/GRILLE.md`
-   Éléments en sommeil : `archive/LISEZMOI.md`
-   Backlog de développement : `docs/TASKS.md`
-   Architecture modulaire : `docs/ARCHITECTURE_MODULAIRE.md`
-   Instructions aux agents : `AGENTS.md`

Les versions sont portées par Git, pas par les noms de fichiers.

## Lecture économique

-   Ne jamais ouvrir `sources/*.xlsx` : lire le CSV de l'onglet utile.
-   Ne pas lire `archive/` sauf demande explicite.
-   Code du convoi : lire le module touché, pas les deux gros fichiers en entier.

## État

Prototype Godot 4 jouable (mode convoi). Dernier audit :
`docs/audits/AUDIT_2026-10-31.md`.
