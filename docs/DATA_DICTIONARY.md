# Dictionnaire de données — Folie Mécanique

Créé le 2026-11-06. Complète [`DATA_CONTRACTS.md`](DATA_CONTRACTS.md) (contrats techniques) sans le remplacer. Décrit l'état **constaté** des tableaux ; aucune valeur de gameplay n'a été modifiée pour l'écrire.

## 1. Sources de vérité

| Donnée | Source de vérité | Remarque |
|---|---|---|
| Monde, personnages, factions, lieux, ressources, événements | [`docs/lore/01_BIBLE_FOUNDATION`](lore/01_BIBLE_FOUNDATION) (DEC-091) | Seules les décisions du porteur de projet la modifient |
| Tableaux historiques et de règles `data/master/*.csv` | `sources/base_maitre.xlsx`, exporté par `tools/export_xlsx.py` ([`INDEX.md`](../data/master/INDEX.md)) | Ne pas éditer les CSV à la main |
| Pièces et assemblages du prototype | `game/data/pieces.json`, `assemblages.json` | Valeurs de gameplay, lues par le jeu |
| Réglages du combat | `game/data/combat_proto.json` | Valeurs de gameplay |

**Écart corrigé le 06/11/2026** : `armes_historiques.csv` et `armes_vehicules_liaison.csv` ont été intégrés à `sources/base_maitre.xlsx` (onglets « Armes historiques » et « Armes vehicules liaison ») ; l'export reproduit ces CSV à l'identique.

**Écart restant** : aucun connu au 06/11/2026 (`contenu_depart_p0.csv` a été supprimé avec la base, DEC-107).

## 2. Identifiants

Préfixes **déjà en usage** (à ne pas renommer) :

| Préfixe | Objet | Exemple | Où |
|---|---|---|---|
| `VEH-nnn` | Véhicule historique | `VEH-096` | `base_maitre_vehicules.csv` (VEH-001 à VEH-275) |
| `ARM-nnn` | Arme historique | `ARM-006` | `armes_historiques.csv` |
| `LIA-nnn` | Liaison arme-véhicule | `LIA-009` | `armes_vehicules_liaison.csv` |
| `DEC-nnn` | Décision | `DEC-104` | `docs/DECISIONS.md` (DEC-001 à DEC-106, sans trou) |
| `CHR-`, `FAC-`, `LOC-`, `EVT-`, `RES-`, `MYS-` + `nnn` | Personnage, faction, lieu, événement, ressource, mystère | `CHR-001` | Bible du lore |
| `OQ-nnn`, `DOC-`, `DEV-`, `HIST-nnn` | Question ouverte, tâches | `OQ-006` | `OPEN_QUESTIONS.md`, `TASKS.md` |
| `vehicle_def_id`, `survivor_id`, `event_id`… | Identifiants techniques | — | `DATA_CONTRACTS.md` |

**Convention proposée pour tout nouvel identifiant** : `PRÉFIXE-nnn` (majuscules, trois chiffres, tiret), attribué dans l'ordre, **jamais réutilisé ni renuméroté**, indépendant du libellé affiché. Un objet retiré garde son identifiant, marqué « retiré » (exemple : RES-006 et RES-007, DEC-094). Les identifiants existants ne sont pas renommés.

## 3. Unités physiques

| Grandeur | Unité | Remarque |
|---|---|---|
| Masse | kg (tonnes seulement dans les textes) | Colonnes « Masse … (kg) » |
| Longueur, hauteur, garde au sol | m dans les tableaux de véhicules ; mm dans `armes_historiques.csv` | **Incohérence entre tableaux** : à unifier ou à indiquer dans l'en-tête |
| Puissance | ch | |
| Carburant, eau | litres | `DATA_CONTRACTS.md` impose un seul stock `stocks.fuel` ; **DEC-094 demande essence et gazole séparés** : contrat à mettre à jour (DEV-001) |
| Vitesse | km/h dans les tableaux historiques ; m/s dans le moteur du jeu | Conversion à documenter |
| Cadence | coups/min | |
| Condition d'un composant | % de 0 à 100 | |
| Distances de jeu | mètres | |

## 4. Valeurs inconnues et champs non applicables

Convention proposée (non appliquée aux tableaux existants, qui emploient des formules libres comme « À confirmer », « À documenter », « À vérifier ») :

| Cas | Valeur écrite |
|---|---|
| Inconnue, à rechercher | `À vérifier` |
| Documentée comme inexistante | `Aucun` |
| Sans objet pour cette ligne | `S/O` |
| Estimation | valeur précédée de `≈` et niveau C ou D |

Constat : la colonne « Statut historique » de `base_maitre_vehicules.csv` vaut « À confirmer » pour 269 véhicules sur 275.

## 5. Niveaux de confiance historiques

| Niveau | Sens |
|---|---|
| A | Source primaire ou documentation technique solide |
| B | Plusieurs sources fiables concordantes |
| C | Plausible mais insuffisamment vérifié |
| D | Inconnu ou non documenté |

Aucun niveau n'est attribué aux données existantes. `armes_historiques.csv` emploie « Moyen » : ce n'est **pas** un niveau A à D ; la colonne est à remplacer après sourçage (HIST-001). Chaque valeur de gameplay doit être séparée de la valeur historique correspondante.

## 6. Donnée historique, estimation, valeur de gameplay

- **Historique** : fait attesté par une source (masse à vide, calibre). Colonnes préfixées « historique » dans les tableaux de véhicules.
- **Estimation** : valeur déduite ou approchée (`estimations_probables_275.csv`) ; porte un niveau C ou D.
- **Gameplay** : valeur choisie pour le jeu (`Rôle gameplay`, `Poids gameplay`, `game/data/*.json`). Elle peut s'écarter de l'historique, sans le corriger.
- Une colonne ne mélange jamais deux de ces natures.

## 7. Relations entre tableaux

```
base_maitre_vehicules (VEH) ── armes_vehicules_liaison (LIA) ── armes_historiques (ARM)
        │                                                          │
        ├── chars_et_blindes_elargis (par nom de modèle, pas d'ID)  └── catalogue_armements (familles de gameplay)
        └── game/data/assemblages.json ── game/data/pieces.json ── catalogue_composants / composants_normalises
Bible : FAC ── LOC ── CHR ── EVT ── RES  (références croisées par identifiant, dans le texte)
```

**Relation faible constatée** : `chars_et_blindes_elargis.csv` et `inventaire_initial.csv` relient les véhicules par le **nom du modèle**, pas par `VEH-nnn`.

## 8. Règles d'ajout et de modification

1. Modifier la source (`base_maitre.xlsx`), puis relancer l'export ; ne pas éditer les CSV générés.
2. Ajouter un identifiant en fin de série ; ne jamais réutiliser un identifiant retiré.
3. Toute colonne a une unité dans son en-tête ou dans ce dictionnaire.
4. Toute donnée historique porte une source identifiable et un niveau A à D ; sans source, le niveau est D.
5. Une valeur de gameplay ne remplace jamais la colonne historique.
6. Toute modification de schéma suit [`DATA_CONTRACTS.md`](DATA_CONTRACTS.md) (version et migration).
7. Un contenu du monde (personnage, faction, lieu) se décide dans la Bible d'abord, les tableaux ensuite.

## 9. À vérifier

- Colonne d'identifiant absente de tableaux sans colonne d'identifiant (voir le contrôle qualité) (voir [`audits/CONTROLE_QUALITE_DOCUMENTAIRE.md`](audits/CONTROLE_QUALITE_DOCUMENTAIRE.md)).
- Unités de longueur et de vitesse entre tableaux historiques et jeu.
