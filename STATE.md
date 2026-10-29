# État du projet — Folie Mécanique

Mis à jour : 2026-10-29. Fichier à lire en premier (court, à garder < 60 lignes).

## Où on en est

- Phase : conception. Aucun code, aucun prototype jouable, moteur non choisi.
- Règles canoniques v1.7, base maître v1.9 (275 véhicules, 70 tables), backlog v1.0.
- Simulations 30 jours v2.0 : 3 000 parties, 3 profils (prudent, équilibré, agressif).

## Constats clés

1. **Pas de tension en début de partie** : 0 % de pénurie d'eau et de nourriture,
   0 % de brèche, quel que soit le profil. Seul le carburant crée une contrainte
   (2,9 % de pénurie en profil agressif). À corriger avant tout développement.
2. **Données véhicules incomplètes** : jusqu'à 10 champs vides par fiche
   (voir `data/master/audit_completude_vehicule.csv`).
3. **Tests limites non couverts** : raid pendant réparation, affectation exclusive,
   récupération après pénurie (voir `data/simulations/progression_30j/tests_limites.csv`).

## Décisions ouvertes

- Moteur et langage (bloque ARCH-001 à QA-001).
- Cible d'équilibrage : taux de pénurie et de brèche souhaités sur 30 jours.

## Prochaines étapes

1. Choisir le moteur.
2. Rééquilibrer l'économie de départ, relancer la simulation.
3. DATA-001 : schémas de données versionnés.
4. Compléter les fiches véhicules prioritaires (contenu de départ P0 d'abord).

## Carte du dépôt

| Chemin | Contenu |
|---|---|
| `AGENTS.md` | Règles pour développeurs et IA |
| `docs/INDEX.md` | Ordre de lecture, sources de vérité |
| `docs/TASKS.md` | Backlog par ID |
| `docs/design/` | Spécification, équilibrage, rapports (Markdown) |
| `data/rules/` | Règles canoniques (JSON) |
| `data/master/` | Tables de la base maître (CSV, un onglet par fichier) |
| `data/simulations/` | Résultats bruts des simulations |
| `sources/` | Classeur Excel d'édition (ne pas lire directement) |
| `tools/` | Scripts (export Excel → CSV) |
