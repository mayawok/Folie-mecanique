# Contrôle qualité documentaire

Créé le 2026-11-06. Procédure répétable + premier rapport. Script de contrôle (lecture seule, hors code du jeu) : [`tools/controle_documentaire.py`](../../tools/controle_documentaire.py). Commande : `python3 -I tools/controle_documentaire.py` depuis la racine.

## Grille de contrôle et résultats du 2026-11-06

« Exécuté » = lancé réellement ce jour-là. « Non exécuté » = procédure décrite mais pas lancée.

| # | Contrôle | Méthode | Résultat | Gravité | Fichier concerné | Action corrective |
|---|---|---|---|---|---|---|
| 1 | Liens internes et chemins | Script : liens relatifs de 46 fichiers `.md` (hors `game/addons`, `archive/prototype`) | **Exécuté** : 98 liens, 0 cassé | — | — | Relancer à chaque lot de documents |
| 2 | Identifiants dupliqués | Script : première colonne « ID… » des 72 CSV ; ID de la Bible | **Exécuté** : `fortifications_couts.csv` répète GATE-L, GATE-R, WALL (clé probable ID + niveau, à confirmer). Bible : `CHR-001` déclaré deux fois (fiche de base et fiche détaillée) | Faible | `data/master/fortifications_couts.csv`, `docs/lore/01_BIBLE_FOUNDATION` | Documenter la clé composite ; garder une seule déclaration d'identifiant par fiche (demande au concepteur : la Bible ne se modifie pas sans lui) |
| 3 | Entrées sans identifiant | Script : colonnes dont le nom commence par « ID » | **Exécuté** : 45 tableaux sur 72 n'ont aucune colonne ID (par exemple `chars_et_blindes_elargis.csv`, 135 lignes) | Moyenne | `data/master/*.csv` | Proposer des identifiants sans renommer l'existant ([`DATA_DICTIONARY.md`](../DATA_DICTIONARY.md)) |
| 4 | Champs obligatoires manquants | Non défini : les champs obligatoires ne sont pas listés dans [`DATA_CONTRACTS.md`](../DATA_CONTRACTS.md) | **Non exécuté** | — | `docs/DATA_CONTRACTS.md` | Lister les champs obligatoires par tableau (DOC-002) |
| 5 | Unités incohérentes | Revue manuelle des en-têtes | **Partiel** : longueurs en m (véhicules) et en mm (armes) ; vitesses en km/h et m/s | Faible | `base_maitre_vehicules.csv`, `armes_historiques.csv`, `game/data/` | Unités dans les en-têtes ou le dictionnaire |
| 6 | Données historiques sans source | Script : « Sources historiques » de `armes_historiques.csv` | **Exécuté** : 15 armes sur 15 « À sourcer ». Colonne « Statut historique » : « À confirmer » pour 269 véhicules sur 275 | Élevée | `armes_historiques.csv`, `base_maitre_vehicules.csv` | HIST-001, HIST-002 |
| 7 | Références vers des documents absents | Script (liens) + recherche manuelle | **Exécuté** pour les liens : 0. Manuel : `TASKS.md` cite `CONTRIBUTING.md` et `docs/ARCHITECTURE.md`, absents (ARCH-002, ARCH-003) | Moyenne | `docs/TASKS.md` | DOC-006 |
| 8 | Contradictions décisions / documents | Lecture ciblée | **Partiel** : `DATA_CONTRACTS.md` impose un seul stock `stocks.fuel` alors que DEC-094 sépare essence et gazole ; il parle aussi de bâtiments et de nourriture (base, DEC-099). `docs/art/CHATGPT.md` et les cartes décrivent encore un désert pur (DEC-097) | Moyenne | `docs/DATA_CONTRACTS.md`, `docs/art/CHATGPT.md` | Questions au concepteur ; DEV-001 |
| 9 | Documents obsolètes présentés comme références | Registre ([`DOCUMENT_REGISTRY.md`](../DOCUMENT_REGISTRY.md)) | **Exécuté** : voir colonne « Contradiction » du registre ; aucun statut « obsolète » tant que le concepteur n'a pas tranché | Moyenne | `docs/DOCUMENT_REGISTRY.md` | OQ-017 résolue pour VISION, CONVOI, GRILLE ; reste le reste des documents |
| 10 | Tableaux hors source de vérité | Réexport de `base_maitre.xlsx` vers un dossier temporaire, puis comparaison aux CSV | **Exécuté** : 71 CSV sur 72 identiques à l'export (après intégration des deux fichiers d'armes dans le classeur). **Écart** : `contenu_depart_p0.csv` (15 lignes dans le classeur, 14 dans le CSV) | Moyenne | `data/master/contenu_depart_p0.csv`, `sources/base_maitre.xlsx` | OQ-021 |
| 11 | Suite de décisions | Script : DEC-001 à DEC-106 | **Exécuté** : 106 décisions, aucun doublon, aucun trou | — | `docs/DECISIONS.md` | — |

## Contrôles restant à faire

- Champs obligatoires (4) et unités (5) sur tous les tableaux.
- Relecture des 38 documents du registre au-delà de l'existence du fichier.

## Problèmes détectés (synthèse)

1. Sources absentes pour toutes les armes (15/15) et statut historique « À confirmer » pour 269 véhicules sur 275.
2. 45 tableaux sans identifiant.
3. `contenu_depart_p0.csv` ne correspond plus au classeur (les fichiers d'armes ont été intégrés au classeur le 06/11).
4. `DATA_CONTRACTS.md` en désaccord avec DEC-094 et DEC-099.
5. Une clé répétée dans `fortifications_couts.csv` et `CHR-001` déclaré deux fois dans la Bible.

## Procédure de reprise

Lancer le script, comparer au tableau ci-dessus, noter la date et les écarts dans une nouvelle ligne de rapport ; ne marquer « exécuté » que ce qui a réellement été lancé.
