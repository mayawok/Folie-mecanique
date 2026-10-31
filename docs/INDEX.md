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
