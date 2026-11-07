# Registre documentaire

Créé le 2026-11-06. Chaque chemin a été vérifié dans le dépôt (existence seulement).
« Dernière vérification » = 2026-11-06 pour l'existence du chemin ; le contenu n'a **pas** été relu en entier, sauf mention contraire.
Aucun document n'est marqué « validé » simplement parce qu'il existe : le statut « validé » est repris d'une mention du document lui-même.

Statuts : référence, validé, en cours, à revoir, obsolète, archivé. Aucun document n'est supprimé.

## 1. Vision et conception

| Chemin | Domaine | Description | Statut | Subordonné à | Dernière vérification | Contradiction connue |
|---|---|---|---|---|---|---|
| [`docs/design/VISION.md`](../docs/design/VISION.md) | Conception | Vision du jeu ; bloc de recentrage du 06/11 en tête | en cours | `docs/lore/01_BIBLE_FOUNDATION` | 2026-11-06 | Passages périmés archivés (DEC-105) ; reste à relire le reste de « Décidé » |
| [`docs/design/CONVOI.md`](../docs/design/CONVOI.md) | Conception | Mode convoi : ordres, combat, monde, architecture du code | à revoir | `docs/design/VISION.md` | 2026-11-06 | Décrit l'ouverture caisse de pièces et moto, les factions 1-2-3 et des éléments à réexaminer (DEC-092) |
| [`docs/design/ESSAIS.md`](../docs/design/ESSAIS.md) | Conception | Fiche des sessions d'essai (à remplir par le porteur de projet) | en cours | `docs/design/VISION.md` | 2026-11-06 | — |
| [`docs/scenario/OUVERTURE.md`](../docs/scenario/OUVERTURE.md) | Scénario | Idée de cinématique d'ouverture et points à trancher | en cours | `docs/design/VISION.md` | 2026-11-06 | — |
| [`docs/scenario/mission-liberation-camp-travailleurs.md`](../docs/scenario/mission-liberation-camp-travailleurs.md) | Scénario | Mission de libération d'un camp de travailleurs forcés (proposition v0.1, propre à ce jeu) | proposition | `docs/lore/01_BIBLE_FOUNDATION` | 2026-11-07 | Lieu et noms non validés (DEC-131) |
| [`docs/DECISIONS.md`](../docs/DECISIONS.md) | Conception | Journal des décisions (DEC-001 à DEC-103) | référence | — | 2026-11-06 | — |
| [`docs/OPEN_QUESTIONS.md`](../docs/OPEN_QUESTIONS.md) | Conception | Questions ouvertes à trancher par le concepteur | en cours | `docs/DECISIONS.md` | 2026-11-06 | — |

## 2. Lore et univers

| Chemin | Domaine | Description | Statut | Subordonné à | Dernière vérification | Contradiction connue |
|---|---|---|---|---|---|---|
| [`docs/lore/01_BIBLE_FOUNDATION`](../docs/lore/01_BIBLE_FOUNDATION) | Lore | Bible du lore, volume I : référence universelle du monde | référence | — | 2026-11-06 | Volume I seulement ; volumes II à VII à écrire |
| [`docs/lore/communautes-ferroviaires.md`](../docs/lore/communautes-ferroviaires.md) | Lore | Communautés ferroviaires itinérantes (proposition v0.1, complément à la Bible) | proposition | `docs/lore/01_BIBLE_FOUNDATION` | 2026-11-07 | Non canon avant validation ; FAC-008 en attente (OQ-024) |
| [`docs/design/LORE.md`](../docs/design/LORE.md) | Lore | Principe « on ne revoit jamais ceux qui s'éloignent » et rencontres du monde | à revoir | `docs/lore/01_BIBLE_FOUNDATION` | 2026-11-06 | Recouvre en partie la Bible (MYS-001) ; marchands et villes (DEC-061) à rattacher à la Bible |

## 3. Gameplay et systèmes

| Chemin | Domaine | Description | Statut | Subordonné à | Dernière vérification | Contradiction connue |
|---|---|---|---|---|---|---|
| [`docs/design/CONVOI.md`](../docs/design/CONVOI.md) | Gameplay | (voir catégorie 1) règles de combat, météo, mines, abordages | à revoir | `docs/design/VISION.md` | 2026-11-06 | Passages périmés archivés le 06/11 (DEC-105) ; ouverture et carte à jour à coder |
| [`docs/TASKS.md`](../docs/TASKS.md) | Gameplay | Backlog central par identifiant | à revoir | `docs/DECISIONS.md` | 2026-11-06 | Cinq tâches de base archivées (DEC-106) ; tâches dépendantes à réviser (OQ-019) ; ARCH-002 et ARCH-003 à vérifier (DOC-006) |
| [`docs/ARCHITECTURE_MODULAIRE.md`](../docs/ARCHITECTURE_MODULAIRE.md) | Gameplay | Architecture modulaire proposée | à revoir | `docs/DATA_CONTRACTS.md` | 2026-11-06 | Écrit avant le prototype (Godot, `game/`) ; éléments de base retirés (DEC-108) |
| [`data/rules/regles_canoniques.json`](../data/rules/regles_canoniques.json) | Gameplay | Règles structurées (v1.7 d'après l'index) | à revoir | `docs/DATA_CONTRACTS.md` | 2026-11-06 | Sections de base supprimées (DEC-108) ; restent à relire economy, monetization (avant DEC-104), captivity, expeditions, factions |

## 4. Données historiques

| Chemin | Domaine | Description | Statut | Subordonné à | Dernière vérification | Contradiction connue |
|---|---|---|---|---|---|---|
| [`data/master/INDEX.md`](../data/master/INDEX.md) | Données | Index des tables exportées depuis base_maitre.xlsx | référence | `sources/base_maitre.xlsx` | 2026-11-06 | — |
| [`sources/base_maitre.xlsx`](../sources/base_maitre.xlsx) | Données | Source de vérité des tableaux CSV (ne pas ouvrir sans nécessité) | référence | — | 2026-11-06 | — |
| [`data/master/bibliographie.csv`](../data/master/bibliographie.csv) | Données historiques | Bibliographie | à revoir | `data/master/INDEX.md` | 2026-11-06 | — |

## 5. Véhicules et mécanique

| Chemin | Domaine | Description | Statut | Subordonné à | Dernière vérification | Contradiction connue |
|---|---|---|---|---|---|---|
| [`data/master/base_maitre_vehicules.csv`](../data/master/base_maitre_vehicules.csv) | Véhicules | 275 véhicules historiques | en cours | `data/master/INDEX.md` | 2026-11-06 | Beaucoup de champs « À documenter » ou « À confirmer » |
| [`data/master/chars_et_blindes_elargis.csv`](../data/master/chars_et_blindes_elargis.csv) | Véhicules | Chars et blindés élargis | en cours | `data/master/INDEX.md` | 2026-11-06 | — |
| [`data/master/catalogue_composants.csv`](../data/master/catalogue_composants.csv) | Véhicules | Catalogue de composants | à revoir | `data/master/INDEX.md` | 2026-11-06 | Antérieur à la grille libre (DEC-043) ; à rapprocher de game/data/pieces.json |
| [`docs/design/GRILLE.md`](../docs/design/GRILLE.md) | Véhicules | Grille de construction (DEC-029 à DEC-083) | en cours | `docs/design/VISION.md` | 2026-11-06 | Atelier guidé moto/side-car archivé (DEC-105) ; le code correspondant existe encore |
| [`game/data/pieces.json`](../game/data/pieces.json) | Véhicules | Catalogue de pièces du jeu (source du prototype) | en cours | `docs/design/GRILLE.md` | 2026-11-06 | À rapprocher des tableaux data/master/ |

## 6. Armes et équipements

| Chemin | Domaine | Description | Statut | Subordonné à | Dernière vérification | Contradiction connue |
|---|---|---|---|---|---|---|
| [`data/master/catalogue_armements.csv`](../data/master/catalogue_armements.csv) | Armes | Familles d'armes de gameplay | à revoir | `data/master/INDEX.md` | 2026-11-06 | Familles, pas un inventaire historique |
| [`data/master/armes_historiques.csv`](../data/master/armes_historiques.csv) | Armes | Catalogue historique, 15 armes d'exemple | en cours | `data/master/INDEX.md` | 2026-11-06 | Sources non renseignées, confiance « Moyen » ; non exporté depuis base_maitre.xlsx |
| [`data/master/armes_vehicules_liaison.csv`](../data/master/armes_vehicules_liaison.csv) | Armes | Liaison armes et véhicules | en cours | `data/master/armes_historiques.csv` | 2026-11-06 | Même remarque sur l'export |

## 7. Carte et secteurs

| Chemin | Domaine | Description | Statut | Subordonné à | Dernière vérification | Contradiction connue |
|---|---|---|---|---|---|---|
| [`docs/art/carte`](../docs/art/carte) | Carte | Images et icônes de la carte | à revoir | `docs/lore/01_BIBLE_FOUNDATION` | 2026-11-06 | Carte antérieure à DEC-101 (France déformée, sans frontières) |

## 8. Personnages et factions

| Chemin | Domaine | Description | Statut | Subordonné à | Dernière vérification | Contradiction connue |
|---|---|---|---|---|---|---|
| [`docs/lore/01_BIBLE_FOUNDATION`](../docs/lore/01_BIBLE_FOUNDATION) | Personnages et factions | Personnages CHR-xxx et factions FAC-xxx (sections 05 à 07) | référence | — | 2026-11-06 | Voir catégorie 2 |
| [`data/master/factions_et_diplomatie_v1_0.csv`](../data/master/factions_et_diplomatie_v1_0.csv) | Personnages et factions | Factions et diplomatie (ancien modèle) | à revoir | `docs/lore/01_BIBLE_FOUNDATION` | 2026-11-06 | Antérieur aux factions de la Bible (DEC-098) |

## 9. Direction artistique

| Chemin | Domaine | Description | Statut | Subordonné à | Dernière vérification | Contradiction connue |
|---|---|---|---|---|---|---|
| [`docs/art/DIRECTION_ARTISTIQUE.md`](../docs/art/DIRECTION_ARTISTIQUE.md) | Direction artistique | Brief officiel du porteur de projet | référence | — | 2026-11-06 | Parle de désert (DEC-097 : désert seulement par endroits) ; à confirmer |
| [`docs/design/GRAPHISMES.md`](../docs/design/GRAPHISMES.md) | Direction artistique | Choix graphiques du jeu | validé | `docs/art/DIRECTION_ARTISTIQUE.md` | 2026-11-06 | Le brief prévaut en cas d'écart (indiqué dans le fichier) |

## 10. Production des assets

| Chemin | Domaine | Description | Statut | Subordonné à | Dernière vérification | Contradiction connue |
|---|---|---|---|---|---|---|
| [`docs/art/ART_PIPELINE.md`](../docs/art/ART_PIPELINE.md) | Production | Pipeline et règles du registre d'assets | à revoir | `docs/art/DIRECTION_ARTISTIQUE.md` | 2026-11-06 | — |
| [`docs/art/asset-register.csv`](../docs/art/asset-register.csv) | Production | Registre des assets | en cours | `docs/art/ART_PIPELINE.md` | 2026-11-06 | — |
| [`docs/art/PRODUCTION.md`](../docs/art/PRODUCTION.md) | Production | File de priorité des images | en cours | `docs/art/ART_PIPELINE.md` | 2026-11-06 | — |
| [`docs/art/CHATGPT.md`](../docs/art/CHATGPT.md) | Production | Instructions pour ChatGPT (images) | à revoir | `docs/art/DIRECTION_ARTISTIQUE.md` | 2026-11-06 | Décrit un jeu « désert » ; à rapprocher de DEC-097 |
| [`docs/audio/ELEVENLABS.md`](../docs/audio/ELEVENLABS.md) | Production | Sons, musiques et voix | en cours | `docs/art/DIRECTION_ARTISTIQUE.md` | 2026-11-06 | — |

## 11. Audits et historique

| Chemin | Domaine | Description | Statut | Subordonné à | Dernière vérification | Contradiction connue |
|---|---|---|---|---|---|---|
| [`docs/audits/AUDIT_2026-10-31.md`](../docs/audits/AUDIT_2026-10-31.md) | Audit | Audit de direction du 31/10/2026 | archivé | — | 2026-11-06 | Antérieur au recentrage du 06/11 |
| [`docs/audits/REPO_AUDIT.md`](../docs/audits/REPO_AUDIT.md) | Audit | Audit du dépôt ARCH-001 (29/10/2026) | archivé | — | 2026-11-06 | Antérieur au prototype |
| [`archive/LISEZMOI.md`](../archive/LISEZMOI.md) | Historique | Éléments en sommeil (base, temps réel, simulations) | archivé | `docs/DECISIONS.md` | 2026-11-06 | DEC-031 |
| [`AGENTS.md`](../AGENTS.md) | Règles | Règles pour développeurs et IA | référence | — | 2026-11-06 | — |
| [`docs/DATA_CONTRACTS.md`](../docs/DATA_CONTRACTS.md) | Données | Contrats de données et unités | à revoir | `AGENTS.md` | 2026-11-06 | Carburant et identifiants de bâtiments corrigés (DEC-108) ; nourriture et eau à relire |

## 12. Ajoutés le 06/11/2026 (missions 4 à 6)

| Chemin | Domaine | Description | Statut | Subordonné à | Dernière vérification | Contradiction connue |
|---|---|---|---|---|---|---|
| [`docs/DATA_DICTIONARY.md`](../docs/DATA_DICTIONARY.md) | Données | Dictionnaire : identifiants, unités, niveaux A à D | en cours | `docs/DATA_CONTRACTS.md` | 2026-11-06 | Contrats : stock de carburant unique (DEC-094) |
| [`docs/DATA_WORLD_PROPOSAL.md`](../docs/DATA_WORLD_PROPOSAL.md) | Données | Proposition d'organisation des données du monde | en cours | `docs/lore/01_BIBLE_FOUNDATION` | 2026-11-06 | En attente du concepteur |
| [`docs/audits/CONTROLE_QUALITE_DOCUMENTAIRE.md`](../docs/audits/CONTROLE_QUALITE_DOCUMENTAIRE.md) | Audit | Grille de contrôle et premier rapport | en cours | `docs/DATA_DICTIONARY.md` | 2026-11-06 | — |

## Remarques

- Statut « obsolète » : aucun document n'est classé ainsi tant que le concepteur n'a pas tranché (voir [`OPEN_QUESTIONS.md`](OPEN_QUESTIONS.md)).
- Non inventoriés : fichiers de `archive/`, images de `docs/art/*/`, scripts de `game/` et `tools/`, autres CSV de `data/master/` (voir [`data/master/INDEX.md`](../data/master/INDEX.md)).

- Archive ajoutée le 06/11/2026 : [`archive/docs_design/PASSAGES_ARCHIVES_2026-11-06.md`](../archive/docs_design/PASSAGES_ARCHIVES_2026-11-06.md) (statut : archivé).

- Suppression du 06/11/2026 (DEC-107) : `archive/prototype_base`, `archive/data`, 8 documents de `archive/docs_design`, 14 tableaux de base de `data/master/`. Les entrées du registre ne les citaient pas.
