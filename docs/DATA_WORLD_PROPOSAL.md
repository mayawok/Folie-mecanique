# Proposition d'organisation des données du monde

Créée le 2026-11-06. **Proposition seulement** : aucun fichier maître n'est modifié, aucune donnée n'est inventée. La Bible du lore reste la référence ; les tableaux en dérivent. À valider par le concepteur avant toute création de fichier.

## Principe

Le texte de la Bible décide ; un tableau par catégorie le rend exploitable par le jeu. Chaque ligne d'un tableau cite l'identifiant de la Bible (`CHR-`, `FAC-`, `LOC-`, `EVT-`, `RES-`) et sépare les colonnes **historiques**, **lore** et **gameplay** ([`DATA_DICTIONARY.md`](DATA_DICTIONARY.md)).

## Catégories

| Catégorie | Fichier maître (existant ou proposé) | Identifiants | Champs indispensables | Relations | Historique à distinguer du gameplay | Manque |
|---|---|---|---|---|---|---|
| Véhicules | `base_maitre_vehicules.csv` (existe) | `VEH-nnn` | catégorie, modèle, pays, période, masses, moteur, carburant | → ARM (liaison), → faction d'usage, → pièces | Masses, moteur : historique ; rôle gameplay : jeu | Statut historique « À confirmer » pour 269 véhicules sur 275 |
| Armes | `armes_historiques.csv` (existe, 15 lignes) | `ARM-nnn` | calibre, munition, masse, mode de tir, source | ← LIA → VEH | Colonne « Compatibilité dans le jeu » séparée | Sources, niveaux A à D ; catalogue complet des catégories A à E à constituer |
| Pièces mécaniques | `game/data/pieces.json` + `composants_normalises_v1_0.csv` (existent) | `piece_id` (à normaliser en `PCE-nnn`) | famille, poids, PV, emprise, compatibilité | → VEH, → grille | Poids réels vs poids de jeu | Pas d'identifiants communs entre `catalogue_composants.csv` et `pieces.json` |
| Équipements | à créer : `equipements.csv` | `EQP-nnn` | nom, type, effet, poids, source | → VEH (greffes), → personnages | Idem | Aucun inventaire ; la grille a des greffes et des phares en données de jeu |
| Personnages | à créer : `personnages.csv` (extrait de la Bible) | `CHR-nnn` (existants) | nom, rôle, faction, lieu, niveau de révélation (le mystère est voulu) | → FAC, → LOC, → EVT | Faits de lore uniquement | 15 fiches dans la Bible, aucun tableau ; qui est visible à l'écran n'est pas décidé |
| Factions | `factions_et_diplomatie_v1_0.csv` (ancien) → à remplacer par `factions.csv` | `FAC-nnn` (existants) | nom, territoire, ressources, relation évolutive | → LOC, → CHR | Aucune relation « gentil/méchant » codée (décision du 06/11) | Correspondance avec les secteurs (OQ-010) |
| Secteurs géographiques | à créer : `secteurs.csv` | `SEC-nnn` | nom, zone, terrain (terre, cailloux, sable, eau), niveau de danger, faction | → LOC, → FAC | Carte déformée : pas de coordonnées réelles | 12 ou 13 secteurs (OQ-011) |
| Lieux | à créer : `lieux.csv` (extrait de la Bible) | `LOC-nnn` (existants) | nom, type, secteur, ressources locales | → SEC, → FAC | Lieu réel (historique) vs lieu transformé | Tableau inexistant ; 4 fiches LOC dans la Bible |
| Ressources | `carburants_compatibilite_v1_0.csv` (existe) + Bible | `RES-nnn` (existants) | nom, unité, usage, utilisable oui/non | → moteurs, → LOC | Brut non utilisable, essence et gazole seulement (DEC-094) | Le tableau liste 3 carburants ; à aligner sur DEC-094 |
| Faune | à créer : `faune.csv` | `FAU-nnn` | espèce, rareté, dangerosité, habitat | → SEC | Biologie réelle vs adaptation du monde | Rien dans la Bible ; seul DEC-097 fixe le principe de rareté |
| Événements historiques | à créer : `evenements_monde.csv` (extrait de la Bible) | `EVT-nnn` (existants) | date relative, lieu, factions, niveau de vérité | → FAC, → LOC, → CHR | Trois niveaux de vérité de la Bible | Dates cohérentes à vérifier |

## Doublons à éviter

- `evenements_et_incidents.csv`, `evenements_expedition.csv`, `scenario_test_30_jours.csv` concernent le prototype de base et d'expédition ; ils ne sont pas des événements du monde.
- Les tableaux de base (bâtiments, niveaux de base, élevage, production) ont été supprimés (DEC-107).

## Décisions à prendre par le concepteur

1. Valide-t-on les 7 fichiers à créer (équipements, personnages, secteurs, lieux, faune, événements du monde, factions) ?
2. Qui du joueur peut voir les personnages (mystère) : un champ « révélation » est-il voulu ?
