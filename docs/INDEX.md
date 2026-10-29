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

## Source de vérité

-   État courant et priorités : `STATE.md` (racine)
-   Règles structurées : `data/rules/regles_canoniques.json` (v1.7)
-   Catalogue véhicules et tables de systèmes : `data/master/*.csv`
    (un fichier par onglet, voir `data/master/INDEX.md`). Édition dans
    `sources/base_maitre.xlsx` (v1.9), puis
    `python3 tools/export_xlsx.py sources/base_maitre.xlsx data/master`.
-   Boucle de jeu : `docs/design/BOUCLE.md`
-   Spécification intégrée : `docs/design/specification_integree.md`
-   Équilibrage et feuille de route : `docs/design/equilibrage_feuille_de_route.md`
-   Backlog de développement : `docs/TASKS.md`
-   Architecture modulaire : `docs/ARCHITECTURE_MODULAIRE.md`
-   Instructions aux agents : `AGENTS.md`

Les versions sont portées par Git, pas par les noms de fichiers.

## Lecture économique

-   Ne jamais ouvrir `sources/*.xlsx` : lire le CSV de l'onglet utile.
-   `data/simulations/` contient des sorties brutes (3 000 parties) :
    lire `synthese_3_profils.csv` ou `tests_limites.csv`, pas le détail.
-   `docs/design/rapport_*.md` sont des rapports historiques ; les
    règles en vigueur sont dans le JSON et la spécification.

## État

Dépôt de conception uniquement : aucun code ni moteur choisi. Audit
initial : `docs/audits/REPO_AUDIT.md`.
