# Backlog de développement centralisé --- v1.0

Statut : backlog de conception, pas une affirmation que les fichiers
source existent déjà. Les tâches sont à exécuter par lots. Priorité P0 =
prérequis, P1 = noyau du jeu, P2 = contenu, P3 = finition.

## Comment utiliser ce backlog

-   Chaque tâche a un ID stable (`ARCH-`, `DATA-`, `CORE-`, `SYS-`,
    `ART-`, `QA-`).
-   Une tâche ne doit traiter qu'un module principal.
-   Le développeur ou l'IA lit `AGENTS.md`, l'index, la tâche et les
    contrats nécessaires seulement.
-   Ne pas commencer une tâche dépendante si ses prérequis sont bloqués.
-   Les statuts initiaux sont `À faire`; passer à `En cours`,
    `À vérifier`, puis `Terminé` uniquement avec preuves/tests.
-   Une tâche est terminée si les critères d'acceptation sont satisfaits
    et les fichiers documentés.

## P0 --- Fondations et audit

### ARCH-001 --- Auditer le dépôt réel

**Objectif :** identifier le moteur, le langage, l'arborescence et
l'état réel des fichiers avant toute architecture imposée.\
**Périmètre :** fichiers racine, configuration du projet, scripts de
build, tests, assets.\
**Ne pas faire :** refactorer ou créer une démo.\
**Dépendances :** aucune.\
**Critères :** rapport court avec fichiers réellement présents,
commandes de test/build vérifiées, risques, proposition d'arborescence
adaptée.\
**Livrable :** `docs/audits/REPO_AUDIT.md`.\
**Statut :** En cours — audit livré, moteur à choisir.

### ARCH-002 --- Installer le guide de travail IA

**Objectif :** créer `AGENTS.md` et `CONTRIBUTING.md` à la racine.\
**Dépendances :** ARCH-001.\
**Critères :** périmètre de tâche, lecture ciblée, tests obligatoires,
règles de sauvegarde, interdiction de modifier des contrats partagés
sans validation, compte rendu standard.\
**Statut :** À vérifier — AGENTS.md existe ; CONTRIBUTING.md absent. Vérification des critères : tâche DOC-006.

### ARCH-003 --- Créer l'index et les contrats

**Objectif :** établir `docs/INDEX.md`, `docs/ARCHITECTURE.md`,
`docs/DATA_CONTRACTS.md`, `docs/DECISIONS.md`.\
**Dépendances :** ARCH-001.\
**Critères :** chaque système a un propriétaire, une documentation et
des liens vers ses tests ; les IDs persistants et unités sont
explicites.\
**Statut :** À vérifier — docs/INDEX.md, DATA_CONTRACTS.md, DECISIONS.md existent ; docs/ARCHITECTURE.md absent (ARCHITECTURE_MODULAIRE.md existe). Vérification des critères : tâche DOC-006.

### DATA-001 --- Définir les schémas de données versionnés

**Objectif :** définir les schémas de stocks, survivants, véhicules,
bâtiments, factions, expéditions et sauvegarde.\
**Dépendances :** ARCH-003.\
**Critères :** IDs stables, unités explicites, champs requis/optionnels,
valeurs par défaut, règles de migration et validation.\
**Statut :** À faire.

### QA-001 --- Installer une stratégie de test

**Objectif :** définir les tests unitaires, intégration, simulation,
sauvegarde et régression.\
**Dépendances :** ARCH-001, DATA-001.\
**Critères :** commandes réellement disponibles documentées ; tests
reproductibles avec graines fixes ; aucune affirmation de test sans
exécution.\
**Statut :** À faire.

## P1 --- Boucle de jeu principale

### CORE-001 --- Temps de simulation et événements déterministes

**Objectif :** définir le temps de jeu, la progression hors ligne
plafonnée à 12 h et l'ordre des événements.\
**Dépendances :** DATA-001.\
**Critères :** ordre quotidien documenté, graine explicite, événements
idempotents, tests de répétabilité.\
**Statut :** À faire.

### SYS-ECON-001 --- ARCHIVÉE le 06/11/2026 (voir « Tâches archivées » en fin de fichier)

### SYS-BASE-001 --- ARCHIVÉE le 06/11/2026 (voir « Tâches archivées » en fin de fichier)

### SYS-SURV-001 --- Survivants et affectations exclusives

**Objectif :** gérer besoins, moral, blessures et affectations aux
bâtiments, défenses et expéditions.\
**Dépendances :** DATA-001, SYS-ECON-001.\
**Critères :** un survivant ne peut occuper deux affectations
incompatibles ; pénuries et blessures ont des effets documentés ;
réaffectation traçable.\
**Statut :** À faire.

### SYS-VEH-001 --- Instances de véhicules et réparations

**Objectif :** séparer catalogue de véhicules et véhicules possédés en
jeu.\
**Dépendances :** DATA-001, SYS-ECON-001.\
**Critères :** IDs d'instance distincts des IDs de catalogue ; état
moteur/refroidissement/transmission/roues/suspension/carrosserie/arme ;
seuils opérationnel ≥70 %, dégradé 30--69 %, neutralisé \<30 %.\
**Statut :** À faire.

### SYS-EXP-001 --- ARCHIVÉE le 06/11/2026 (voir « Tâches archivées » en fin de fichier)

### SYS-DEF-001 --- ARCHIVÉE le 06/11/2026 (voir « Tâches archivées » en fin de fichier)

### SYS-FAC-001 --- Factions et conséquences persistantes

**Objectif :** gérer réputation, confiance, menace et peur séparément.\
**Dépendances :** DATA-001, CORE-001.\
**Critères :** actions mémorisées, conséquences différées possibles,
anti-exploitation par répétition, réactions distinctes par archétype.\
**Statut :** À faire.

### SYS-SAVE-001 --- Sauvegarde, chargement et migrations

**Objectif :** garantir reprise cohérente après fermeture et évolution
des versions.\
**Dépendances :** DATA-001, CORE-001.\
**Critères :** sauvegarde atomique, checkpoint, checksum, migration
versionnée, événements idempotents ; tests de corruption, reprise et
absence de doublons.\
**Statut :** À faire.

## P2 --- Contenu et présentation

### CONTENT-001 --- ARCHIVÉE le 06/11/2026 (voir « Tâches archivées » en fin de fichier)

### ART-001 --- Bible graphique et registre d'assets

**Objectif :** définir style, échelle, formats, noms, résolutions,
variantes et droits des textures/sprites/UI/audio.\
**Dépendances :** audit du moteur.\
**Critères :** chaque asset a un ID stable, un propriétaire de module,
un statut et un chemin ; aucune logique métier dans les fichiers
artistiques.\
**Statut :** À faire.

### UI-001 --- Cartographie des écrans et navigation

**Objectif :** lister les écrans et leurs actions sans implémenter les
règles dans l'interface.\
**Dépendances :** ARCH-003, SYS-BASE-001, SYS-EXP-001.\
**Critères :** chaque action appelle une commande métier documentée ;
états chargement/erreur/confirmation prévus.\
**Statut :** À faire.

## P3 --- Validation finale

### QA-002 --- Simulations multi-systèmes

**Objectif :** rejouer 30 jours et scénarios limites avec les systèmes
reliés.\
**Dépendances :** CORE-001, SYS-ECON-001, SYS-BASE-001, SYS-EXP-001,
SYS-DEF-001, SYS-SAVE-001.\
**Critères :** tests reproductibles pour pénurie, raid pendant
réparation, véhicule immobilisé, équipage double-affecté, reprise après
fermeture et sauvegarde rechargée.\
**Statut :** À faire.

### QA-003 --- Revue de régression et préparation de publication

**Objectif :** établir le contrôle final des fonctionnalités,
performances et compatibilité iOS.\
**Dépendances :** QA-001, QA-002.\
**Critères :** matrice de tests, appareils/cibles documentés, problèmes
bloquants résolus ou explicitement acceptés.\
**Statut :** À faire.

## Format obligatoire du compte rendu de tâche

-   ID de tâche :
-   Résultat :
-   Fichiers créés/modifiés :
-   Fichiers volontairement non modifiés :
-   Tests exécutés (commandes et résultats réels) :
-   Critères d'acceptation : réussis/échoués/non testés
-   Contrats ou schémas modifiés :
-   Risques et régressions possibles :
-   Prochaine tâche recommandée :


## Mise à jour du 06/11/2026 — organisation par nature de travail

Cette section s'ajoute au backlog ci-dessus sans le modifier. Les tâches SYS-BASE, SYS-DEF, SYS-ECON, SYS-EXP, CONTENT-001 et les
statuts d'ARCH-002 et ARCH-003 sont signalés comme à réexaminer (OQ-018), non changés. Statuts initiaux : À faire.

### A. Décisions à prendre par le concepteur

Voir [`OPEN_QUESTIONS.md`](OPEN_QUESTIONS.md) (OQ-001 à OQ-018). Aucune tâche d'exécution ci-dessous ne les tranche.

### B. Tâches documentaires réalisables sans décision

| ID | Intitulé | Priorité | Dépendances | Fichiers | Critère d'achèvement | Statut |
|---|---|---|---|---|---|---|
| DOC-001 | Vérifier tous les liens relatifs des documents racine et `docs/` | P1 | — | `README.md`, `STATE.md`, `docs/*.md` | Script ou liste : 0 lien cassé, résultat consigné dans un audit | Fait le 06/11 (98 liens, 0 cassé ; `tools/controle_documentaire.py`) |
| DOC-002 | Créer `docs/DATA_DICTIONARY.md` (mission 4) | P1 | — | `docs/DATA_DICTIONARY.md`, `docs/DATA_CONTRACTS.md` | Document couvrant identifiants, unités, valeurs inconnues, niveaux de confiance A à D, relations | Fait le 06/11 (reste : champs obligatoires par tableau) |
| DOC-003 | Proposer l'organisation des données du monde (mission 5), sans modifier les fichiers maîtres | P1 | DOC-002 | `docs/DATA_WORLD_PROPOSAL.md` | Proposition pour 11 catégories avec fichier maître, identifiants, champs, relations | Fait le 06/11 (attend la validation du concepteur) |
| DOC-004 | Créer `docs/audits/CONTROLE_QUALITE_DOCUMENTAIRE.md` (mission 6) | P2 | DOC-001 | `docs/audits/CONTROLE_QUALITE_DOCUMENTAIRE.md` | Grille de 10 contrôles et premier rapport avec les contrôles réellement exécutés | Fait le 06/11 (contrôles 4 et 5 restent partiels) |
| DOC-005 | Lister les passages de VISION, CONVOI, GRILLE et LORE qui contredisent la Bible, ligne par ligne | P2 | OQ-017 | `docs/DOCUMENT_REGISTRY.md` | Tableau passage / décision contredite / document | À faire |

### C. Tâches techniques de développement (code : seulement après décision indiquée)

| ID | Intitulé | Priorité | Dépendances | Fichiers | Critère d'achèvement | Statut |
|---|---|---|---|---|---|---|
| DEV-001 | Séparer le stock de carburant en essence et gazole, un type par moteur (DEC-094) | P1 | — | `game/scripts/combat/modele_base.gd`, `game/data/pieces.json` | Tests sans écran : un moteur ne consomme que son carburant ; sauvegarde migrée | À faire |
| DEV-002 | Remplacer les factions 1, 2, 3 par les factions de la Bible (DEC-098) | P1 | OQ-010 | `game/scripts/combat/monde.gd` | Tests : les secteurs portent une faction de la Bible ; plus de relation codée en dur « 1 alliée » | À faire |
| DEV-003 | Nouvelle ouverture : convoi existant avec camion, rotation dans le no man's land (DEC-100) | P1 | OQ-006, OQ-007, OQ-008 | `game/scripts/combat/modele_atelier.gd`, `game/data/combat_proto.json` | Partie démarrant sur le camion, sans l'étape caisse et moto ; test d'ouverture mis à jour | À faire |
| DEV-004 | Rendre les meutes rares et mettre en valeur l'oiseau (DEC-097) | P2 | OQ-013 | `game/scripts/combat/monde.gd` | Fréquence des meutes réglable dans les données ; test : pas de meute chaque nuit | Fait le 09/11 : oiseau rare de jour (`monde._oiseau`, `combat_proto.json` → oiseau) ; fréquences à régler (OQ-013) |
| DEV-005 | Renommer l'identifiant interne `intercepteur` avec migration (DEC-096) | P3 | — | `game/data/pieces.json`, `game/scripts/vehicules/construction_libre.gd` | Migration + test ; anciens plans chargés | À faire |
| DEV-006 | Limiter les tempêtes de sable aux zones désertiques du no man's land et les rarifier ; chien démineur très rare (DEC-109, E4, E6) | P2 | OQ-013 | `game/scripts/combat/modele_meteo.gd`, `game/scripts/combat/modele_mines.gd`, `game/data/combat_proto.json` | Tests : pas de tempête hors zone désert ; fréquences réglables dans les données | À faire |
| DEV-007 | Inverser la zone calme : zones habitées calmes, trajet entre zones = no man's land ; services des camps regroupés en checkpoint de chapitre (DEC-109, E7, E8) | P2 | OQ-010, OQ-011 | `game/scripts/combat/monde.gd`, `game/scripts/combat/combat_modele.gd` | Tests : aucune rencontre en zone ; rencontres entre zones ; un checkpoint par chapitre | À faire |
| DEV-008 | Décor par type de zone, y compris l'eau (DEC-109, E9) ; zone choisie dans le kit (DEC-110) | P1 | DEV-010 | `game/scripts/combat/vue_dessin.gd`, `game/scripts/combat/modele_terrain.gd` | Capture d'écran par type de zone ; décor cohérent avec la zone | À faire |
| DEV-009 | Carte fixe de 12 ou 13 secteurs sur une France déformée, remplaçant les secteurs aléatoires de niveau 0 à 7 (DEC-109, E10) | P2 | OQ-010, OQ-011 | `game/scripts/combat/monde.gd` | Tests : carte identique à chaque partie ; chaque secteur porte une faction de la Bible | À faire |
| DEV-010 | Panneau « Kit » du Mode créatif : choisir le type de zone et le décor, l'heure, la météo, une route calme ; faire apparaître à la demande ennemis, bâtiments, pillards, animaux, oiseau, champ de mines, marchand (DEC-110) | P1 | — | `game/scripts/combat/vue_interface.gd`, `game/scripts/combat/monde.gd`, `game/data/combat_proto.json` | Tests sans écran : chaque bouton crée l'élément voulu ; route calme = aucune rencontre automatique | Fait le 07/11 (DEC-112), à essayer sur iPhone |

### D. Problèmes historiques à vérifier

| ID | Intitulé | Priorité | Dépendances | Fichiers | Critère d'achèvement | Statut |
|---|---|---|---|---|---|---|
| HIST-001 | Sourcer les 15 armes du catalogue (une source identifiable par arme) | P1 | — | `data/master/armes_historiques.csv` | Colonne « Sources historiques » renseignée, confiance A à D attribuée | À faire |
| HIST-002 | Vérifier les 14 liaisons arme-véhicule | P1 | HIST-001 | `data/master/armes_vehicules_liaison.csv` | Chaque liaison avec source et certitude confirmée ou corrigée | À faire |
| HIST-003 | Étendre le catalogue des armes par catégorie (mitrailleuses, puis canons, puis armes individuelles) | P2 | HIST-001 | `data/master/armes_historiques.csv` | Catégorie complète avec sources | À faire |
| HIST-004 | Intégrer les CSV d'armes au processus d'export de `base_maitre.xlsx` | P2 | — | `sources/base_maitre.xlsx`, `tools/export_xlsx.py` | Les deux CSV sont produits par l'export, pas à la main | Fait le 06/11 (export reproduit les deux CSV à l'identique) |


### Tâche ajoutée le 06/11/2026

| ID | Intitulé | Priorité | Dépendances | Fichiers | Critère d'achèvement | Statut |
|---|---|---|---|---|---|---|
| DOC-006 | Vérifier les critères d'acceptation d'ARCH-002 et ARCH-003 contre les fichiers existants | P1 | — | `docs/TASKS.md`, `AGENTS.md`, `docs/INDEX.md`, `docs/DATA_CONTRACTS.md` | Pour chaque critère : présent ou absent, avec preuve ; statut passé à Terminé ou précisé | À faire |

## Tâches archivées (DEC-099, convoi seulement)

Archivées le 06/11/2026 sur décision du porteur de projet : leur objet (base, défense de base, économie de base, expéditions depuis la base) contredit le jeu de convoi. Texte repris tel quel. **Tâches dépendantes à réviser** (elles citent des tâches archivées) : SYS-SURV-001, SYS-VEH-001, UI-001, QA-002, QA-003 (voir OPEN_QUESTIONS, OQ-019).

### SYS-ECON-001 --- Stocks et transactions atomiques

**Objectif :** centraliser les stocks et toutes les dépenses/gains.\
**Dépendances :** DATA-001, CORE-001.\
**Critères :** pas de stock négatif silencieux ; opérations atomiques ;
carburant commun `stocks.fuel` en litres ; alertes à moins de 2 jours et
sous 1 jour d'autonomie.\
**Statut :** À faire.

### SYS-BASE-001 --- Bâtiments et chantiers

**Objectif :** gérer construction, niveaux, coûts, durée, effectifs,
production, consommation, entretien et énergie.\
**Dépendances :** SYS-ECON-001, CORE-001.\
**Critères :** calendrier reproductible, annulation/interruption
définie, dépenses cohérentes, tests de pénurie et de chantier
interrompu.\
**Statut :** À faire.

### SYS-EXP-001 --- Préparation et résolution des expéditions

**Objectif :** gérer équipage, véhicule, stocks, étapes tactiques,
objectif, retraite et rapport.\
**Dépendances :** CORE-001, SYS-ECON-001, SYS-SURV-001, SYS-VEH-001.\
**Critères :** phases
préparation/détection/contact/engagement/objectif/retraite-récupération/rapport
; risques visibles avant confirmation ; résultats reproductibles avec
graine.\
**Statut :** À faire.

### SYS-DEF-001 --- Portes, murs et défense de base

**Objectif :** gérer deux portes indépendantes, segments de mur,
soldats, armes fixes, munitions et véhicules extérieurs.\
**Dépendances :** SYS-SURV-001, SYS-VEH-001, SYS-ECON-001.\
**Critères :** dégâts localisés ; affectations exclusives ; angle de tir
et munitions pris en compte ; brèche locale réparable ; aucune perte
irréversible cachée.\
**Statut :** À faire.

### CONTENT-001 --- Progression des 30 premiers jours

**Objectif :** fixer état initial, bâtiments disponibles, plans,
missions et événements par paliers.\
**Dépendances :** SYS-ECON-001, SYS-BASE-001, SYS-EXP-001.\
**Critères :** table jour/période avec objectifs, coûts, récompenses,
risques et voie de récupération ; pas de blocage irréversible sans
avertissement.\
**Statut :** À faire.
| DEV-011 | Décor en couches : charger `terre_ciel/lointain/moyen/sol` et `elem_*` (parallaxe, teinte nuit et tempête), repli sur le décor dessiné si les images manquent (DEC-114) | P1 | lots 3b et 3c livrés | `game/scripts/terrain.gd` | Capture d'écran de la zone terre ; le jeu démarre sans les images | Fait (capture 1920×1080 vérifiée, test_kit OK ; iPhone non vérifié ; repli sans images non testé) |
| DEV-012 | Habillage de l'interface, étape 1 : cadre, barre du haut (progression du trajet, secteur, heure, menace), onglets (DEC-114) | P1 | lot 20 | `game/scripts/combat/vue_interface.gd` | Capture d'écran iPhone large ; boutons atteignables | Partiel : boutons et pastilles en métal rouillé (vue_base.gd), version sur l'accueil ; reste cadre d'écran et barre de progression du trajet |
| DEV-013 | Habillage de l'interface, étape 2 : panneaux du bas repliables (équipage, convoi, état, ressources, mini-carte), sans rations ni gestion (DEC-114) | P1 | DEV-012, lot 21 | `game/scripts/combat/vue_interface.gd` | Panneaux repliés par défaut sauf état et ressources ; captures | À faire |
| DEV-014 | Rôle « Éclaireur » : s'ajoute aux rôles d'équipage ; effet proposé : les rencontres sont annoncées plus tôt (distance d'alerte × 1,5), valeur dans `equipage_roles` (DEC-114) | P2 | — | `game/data/combat_proto.json`, `game/scripts/vehicules/construction_libre.gd` | Test : un éclaireur à bord allonge la distance d'alerte | À faire |
| DEV-015 | `test_base_vehicule.gd` exécuté par GitHub Actions et fusionné dans `main` (DEC-125) ; reste à corriger `test_editeur.gd` (erreur `ppm` nul, antérieure) | P2 | — | `game/scripts/vehicules/base_vehicule.gd`, `fiabilite_vehicule.gd`, `camp_reparation.gd`, `game/tests/test_base_vehicule.gd` | Test : « TOUT OK » (fait) ; `test_editeur` vert | Fait (test_editeur : à faire) |
| DEV-016 | Écran de transformation à 4 onglets (Base, Structure, Plateau, Blindage et options), poignée de rallonge par crans, vignettes grisées avec la raison (DEC-121) | P1 | DEV-015 | `game/scripts/vehicules/editeur_grille.gd` | Capture d'écran iPhone : rallonger d'un cran, changer un essieu | Écran autonome fait (DEC-128) ; reste : branchement dans la partie |
| DEV-017 | Dessin de la rallonge (tronçon central de la coque répété, marque `etire`) et des modules de plateau ; images dérivées de l'existant, méthode de `tools/carrosseries.py` (DEC-124) | P1 | DEV-015 | `game/scripts/vehicules/construction_libre.gd` (forme), `forme_assemblage.gd` | Capture : T23 rallongé garde sa silhouette | Fait pour le T23 (DEC-127) ; autres bases à habiller |
| DEV-018 | Brancher le camp de réparation au monde : alerte et attaques à droite (`attaques_dues`), arrêt du convoi, véhicule immobilisé, bouton Interrompre (DEC-122) | P1 | DEV-015 | `game/scripts/combat/monde.gd`, `vue_interface.gd` | Test : un camp de 240 s avec une attaque dure plus de 240 s | Modèle (DEC-129) et interface (DEC-130) faits ; reste : essieu distinct de la roue sur les véhicules d'origine, bouton Interrompre vérifié en jeu réel |
| DEV-019 | Combat et pannes (FAIT : masse, blindage, réservoir et places de troupes lus par `ConstructionLibre.analyser`, DEC-126 ; RESTE : pannes en route et réserve de pièces de rechange) : ajouter `BaseVehicule.poids_supplementaire` et les effets de module/blindage au profil de combat ; pannes en route par `FiabiliteVehicule.tirer_pannes` ; réserve de pièces de rechange (DEC-123) | P1 | DEV-015 | `game/scripts/combat/modele_base.gd`, `modele_tir.gd` | Test : la masse d'un camion blindé compte dans sa vitesse | Pannes en route faites le 09/11 (`modele_camp._pannes`, option `pannes`) ; reste : pièces de rechange dédiées |
| DEV-020 | Berliet GDR dans le convoi : remplacer la forme provisoire (copie du T23) par `BerlietDessin` avec la configuration du joueur ; halte du convoi = `Bivouac` (bouton d'arrêt, réparations visibles) (DEC-136, 137) | P1 | — | `game/scripts/vehicule_dessin.gd`, `game/scripts/combat/vue_dessin.gd` | Capture du convoi à l'arrêt et en route | À faire |
| DEV-021 | Portières et capot du Berliet animés par découpe de la cabine (intérieur sombre derrière, portière qui pivote), sans nouvelle image (DEC-138) | P2 | — | `tools/decouper_berliet.py`, `game/scripts/vehicules/berliet_dessin.gd` | Capture : portière ouverte pendant la descente | À faire |
| DEV-022 | Brancher les valeurs du Berliet (charge du châssis, litres de gazole, bonus d'échappement, adhérence des pneus) sur le combat et les garages (niveau 2 pour le châssis long et la grue) | P2 | OQ-025 | `game/data/berliet.json`, `modele_base.gd` | Test : réservoir 5 = 560 L de gazole | À faire |
| DEV-023 | Lot 12 (motos, side-cars) : découper les planches et poser la nacelle devant ou derrière la moto selon le sens (DEC-138) | P2 | images du lot 12 | `tools/`, `game/assets/vehicules/` | Capture des deux sens | En attente des images |
| DEV-024 | Villes : textures propres à chaque ville (fond, mairie, porte) à la place du dessin par code (DEC-143) | P2 | OQ-026 | `game/scripts/combat/ville_dessin.gd`, `game/assets/` | Capture d'une ville texturée | À faire |
| DEV-025 | Villes : quêtes du maire et des habitants (bulles), marché, recrutement (DEC-143) | P2 | OQ-026 | `modele_ville.gd`, `vue_interface.gd` | Test : une quête acceptée à la mairie | À faire |
| DEV-026 | Missions : autres types (escorte de voyageurs, épave à ramener), escortes et vagues selon le niveau du secteur, voix du maire (DEC-144) | P2 | OQ-027 | `game/data/missions.json`, `modele_mission.gd` | Test : mission de niveau 4 plus dure | À faire |
| DEV-027 | Dépôt en ville contre reçu (perte 10 % au retrait ailleurs) et caches dans la nature (DEC-157) | P1 | — | `modele_ville.gd`, `villes.json` | Test : déposer 100, retirer 90 ailleurs ; cache pillable | À faire |
| DEV-028 | Pièce gazogène dans la grille, moteurs essence seulement (DEC-158) | P2 | DEV-001 | `pieces.json`, `construction_libre.gd` | Test : refusé sur moteur gazole ; consomme du charbon ou du bois | À faire |
| DEV-029 | Centrale électrique au secteur des Corons : décor, lumières, arcs, véhicules à batterie (DEC-159) | P2 | DEV-008 | `carte_monde.json`, `vue_dessin.gd` | Capture de la centrale de nuit | À faire |
| DEV-030 | Bouton de marche unique (toucher, glisser) ; suppression du menu Ordres du convoi (DEC-160) | P1 | — | `vue_interface.gd` | Test tactile ; capture | À faire |
| DEV-031 | Halte dans la nature : camp progressif, surveillance et réparation, embuscade, éclaireurs, cache (DEC-161) | P1 | DEV-030 | `modele_camp.gd`, `vue_interface.gd` | Tests du modèle ; capture du camp | À faire |
| DEV-032 | Phares sur tous les véhicules, visibilité de nuit (DEC-162) | P1 | — | `vue_dessin.gd` | Capture de nuit | Fait le 09/11 |
| DEV-033 | Voies ferrées, gares et train à quai (voyage rapide payé) (DEC-163) | P2 | DEV-009 | `monde.gd`, `terrain.gd` | Test : embarquer et arriver à destination | À faire |
| DEV-034 | Projecteurs de la ville sur le convoi la nuit et dialogue en bulles (DEC-164) | P2 | — | `ville_dessin.gd` | Capture de nuit | À faire |
| DEV-035 | Escorte : pilotes aux fenêtres, armes sorties, sans hommes en blanc ; équipage visible du Berliet (DEC-165) | P2 | — | `mission_dessin.gd`, `berliet_dessin.gd` | Captures | À faire |
| DEV-036 | Repaire de boss : entrée en flammes, cinématique monte-charge et trône (même méthode que les scènes de mission), arène et combat de boss (DEC-166) | P2 | OQ-031 | `modele_ville.gd` (variante), `mission_dessin.gd` | Captures de la cinématique ; test : l'arène se termine par la victoire ou la défaite | À faire |
