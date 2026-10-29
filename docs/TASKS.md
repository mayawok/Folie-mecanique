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
**Statut :** À faire.

### ARCH-003 --- Créer l'index et les contrats

**Objectif :** établir `docs/INDEX.md`, `docs/ARCHITECTURE.md`,
`docs/DATA_CONTRACTS.md`, `docs/DECISIONS.md`.\
**Dépendances :** ARCH-001.\
**Critères :** chaque système a un propriétaire, une documentation et
des liens vers ses tests ; les IDs persistants et unités sont
explicites.\
**Statut :** À faire.

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

### CONTENT-001 --- Progression des 30 premiers jours

**Objectif :** fixer état initial, bâtiments disponibles, plans,
missions et événements par paliers.\
**Dépendances :** SYS-ECON-001, SYS-BASE-001, SYS-EXP-001.\
**Critères :** table jour/période avec objectifs, coûts, récompenses,
risques et voie de récupération ; pas de blocage irréversible sans
avertissement.\
**Statut :** À faire.

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
