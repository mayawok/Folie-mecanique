# Audit du dépôt — ARCH-001

Date : 2026-10-29. Commit audité : `8de4423`.

## Constat avant restructuration

- Contenu : `README.md` (1 ligne) et une archive zip de ~1 Mo.
- Aucun code source, script de build, test ou asset. Moteur non choisi.
- Dans l'archive : 5 fichiers Markdown dupliqués (racine et `docs/`),
  `ART_PIPELINE.md` en triple, backlog en double (`TASKS.md` et `.xlsx`
  identiques), références de versions incohérentes entre l'index (zip v2.0),
  le rapport (règles v1.4, index v1.5) et les fichiers présents (v1.7, v1.8).
- Registre d'assets vide (en-têtes seuls).

## Restructuration appliquée

- Archive extraite ; doublons supprimés ; versions retirées des noms de fichiers.
- `.docx` convertis en Markdown (`docs/design/`).
- Classeurs exportés en CSV par onglet (`data/master/`, `data/simulations/`)
  via `tools/export_xlsx.py` ; le classeur maître est conservé dans `sources/`.
- Ajout de `STATE.md` comme point d'entrée court.
- Les originaux restent récupérables dans l'historique Git (commit `8de4423`).

## Commandes vérifiées

- `python3 tools/export_xlsx.py <xlsx> <dossier>` : exécuté, 70 + 5 + 3 onglets exportés.
- Build et tests : aucun, faute de code.

## Risques

- Double source classeur / CSV : relancer l'export après chaque édition Excel.
- Sorties de simulation volumineuses (~0,6 Mo) : ne pas les lire en entier.

## Reste pour clore ARCH-001

Choix du moteur, puis arborescence `src/` et `tests/` adaptée.
