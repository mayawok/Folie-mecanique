# État du projet — Folie Mécanique

Mis à jour : 2026-10-29 (DEC-014). Fichier à lire en premier (court, à garder < 60 lignes).

## Où on en est

- Phase : conception, revue complète avant tout développement (DEC-002).
- Moteur : Godot 4 / GDScript (DEC-001, voir `docs/DECISIONS.md`).
- Règles canoniques v1.8, base maître v1.9 (275 véhicules, 70 tables), backlog v1.0.
- Simulations 30 jours v2.0 : 3 000 parties, 3 profils (prudent, équilibré, agressif).

## Constats clés

1. **Pas de tension en début de partie** : 0 % de pénurie d'eau et de nourriture,
   0 % de brèche, quel que soit le profil. Seul le carburant crée une contrainte
   (2,9 % de pénurie en profil agressif). À corriger avant tout développement.
2. **Données véhicules incomplètes** : jusqu'à 10 champs vides par fiche
   (voir `data/master/audit_completude_vehicule.csv`).
3. **Tests limites non couverts** : raid pendant réparation, affectation exclusive,
   récupération après pénurie (voir `data/simulations/progression_30j/tests_limites.csv`).

## Périmètre V1 (DEC-013)

Désert seul, faune en événements, solo hors ligne sans serveur, sièges en V1.1.

## Décisions ouvertes

- Cible d'équilibrage : taux de pénurie et de brèche souhaités sur 30 jours.

## Prochaines étapes

1. Revue de conception thème par thème. Thème 1 (vision) : `docs/design/VISION.md`.
   Thème 2 (boucle) : `docs/design/BOUCLE.md` (reste ouvert : jour/nuit, planchers, seuils).
   Thème 3 (achats) : `docs/design/ACHATS.md`, garde-fou dans `regles_canoniques.json` (v1.7).
   Thème 4 (périmètre V1) : `docs/design/PERIMETRE_V1.md` (DEC-013).
   Thème 5 (systèmes) : `docs/design/SYSTEMES.md` — systèmes 1 ressources (DEC-014) et 2 travailleurs (DEC-015) validés.
   **Prochain : système 3, véhicules**, puis 4 à 8 ; ensuite thème 6 (graphismes, partir de `docs/art/ART_PIPELINE.md`).
2. Rééquilibrer l'économie de départ, relancer la simulation (désert seul, rattrapage hors ligne) avec jour/nuit,
   planchers d'absence, profils « joueur absent » et « abonné » (voir `BOUCLE.md`).
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
