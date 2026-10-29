# Architecture modulaire du jeu iPhone --- v1.0

Statut : proposition d'architecture de développement. Ce document décrit
des frontières de modules et des contrats de travail ; il ne constitue
pas du code jouable.

## 1. Principe directeur

Chaque fonctionnalité doit pouvoir être développée, testée et révisée
sans qu'un développeur ou une IA ait besoin de relire tout le projet.
Une tâche doit pointer vers : - le module concerné ; - les fichiers
autorisés à modifier ; - les contrats/API à respecter ; - les fichiers
qu'il est interdit de modifier sans validation ; - les tests
d'acceptation ; - les dépendances et la documentation à mettre à jour.

Les noms de dossiers ci-dessous sont une cible d'architecture à créer
progressivement. Ne pas prétendre qu'ils existent déjà dans le dépôt
tant qu'ils n'ont pas été créés et vérifiés.

## 2. Organisation cible

``` text
/
├── README.md
├── CONTRIBUTING.md
├── AGENTS.md                      # règles communes aux assistants de codage
├── docs/
│   ├── INDEX.md                   # point d’entrée obligatoire
│   ├── VISION.md
│   ├── ARCHITECTURE.md
│   ├── DECISIONS.md               # décisions techniques et de game design
│   ├── DATA_CONTRACTS.md          # schémas partagés et règles d’identifiants
│   ├── TASKS.md                   # backlog canonique
│   ├── systems/
│   │   ├── economy.md
│   │   ├── base-building.md
│   │   ├── vehicles.md
│   │   ├── expeditions.md
│   │   ├── combat-defense.md
│   │   ├── factions.md
│   │   ├── survivors.md
│   │   └── save-load.md
│   ├── art/
│   │   ├── ART_BIBLE.md
│   │   ├── TEXTURE_PIPELINE.md
│   │   └── asset-register.csv
│   └── testing/
│       ├── TEST_STRATEGY.md
│       └── REGRESSION_MATRIX.md
├── data/
│   ├── vehicles/
│   ├── buildings/
│   ├── items/
│   ├── factions/
│   └── balance/
├── assets/
│   ├── textures/
│   ├── sprites/
│   ├── ui/
│   ├── audio/
│   ├── fonts/
│   └── source-art/                # sources éditables, si autorisées
├── src/
│   ├── core/                      # temps, événements, identifiants, RNG déterministe
│   ├── domain/                    # modèles et règles indépendantes de l’interface
│   ├── systems/
│   │   ├── economy/
│   │   ├── base-building/
│   │   ├── vehicles/
│   │   ├── expeditions/
│   │   ├── combat-defense/
│   │   ├── factions/
│   │   └── survivors/
│   ├── persistence/               # sauvegarde, migrations, checkpoints
│   ├── presentation/              # écrans, HUD, menus, navigation
│   └── platform/                  # intégration iOS, cycle de vie, permissions
└── tests/
    ├── unit/
    ├── integration/
    ├── simulation/
    └── fixtures/
```

Le moteur et le langage n'étant pas encore verrouillés dans ce document,
les extensions exactes des fichiers source seront décidées après audit
du dépôt réel. L'architecture logique doit rester applicable quel que
soit le moteur retenu.

## 3. Responsabilités des modules

  -----------------------------------------------------------------------
  Module                  Possède                 Ne doit pas posséder
  ----------------------- ----------------------- -----------------------
  core                    horloge de simulation,  règles économiques ou
                          IDs, événements, RNG    UI
                          déterministe            

  domain                  modèles partagés,       affichage et accès
                          enums, validation de    direct aux fichiers
                          base                    

  economy                 stocks, production,     déplacement de
                          consommation, coûts,    véhicules, interface
                          transactions            

  base-building           bâtiments, niveaux,     définition globale des
                          chantiers, réseau de    stocks
                          base                    

  vehicles                instances,              logique de combat
                          compatibilité, état des complète
                          composants, réparations 

  expeditions             préparation, étapes,    règles de sauvegarde
                          rencontres, résultats,  bas niveau
                          retour                  

  combat-defense          portes, murs, soldats,  économie globale hors
                          armes fixes, phases de  demandes de coûts
                          raid                    

  factions                réputation, confiance,  UI de dialogue
                          menace, peur, relations 

  survivors               attributs, blessures,   affectation de
                          affectations, moral     ressources de stock

  persistence             sérialisation,          décisions de gameplay
                          versionnage, migration, 
                          atomicité               

  presentation            écrans et commandes     calculer les règles
                          joueur                  métier elle-même

  assets/art              textures, sprites, UI,  règles de simulation
                          audio, polices et       
                          métadonnées             
  -----------------------------------------------------------------------

## 4. Contrats entre modules

-   Les modules métier ne modifient pas directement les structures
    internes d'un autre module. Ils passent par une API ou un événement
    défini.
-   Un stock partagé n'a qu'une seule source de vérité : `stocks.fuel`
    représente le carburant en litres. Le type de carburant est une
    propriété de compatibilité du moteur, pas un deuxième stock.
-   Les IDs persistants sont stables et ne dépendent ni du nom affiché
    ni de la position dans une liste.
-   Une instance de véhicule, un survivant, une arme ou une équipe ne
    peut être affecté à deux usages incompatibles simultanément.
-   Toute opération qui dépense ou transfère des ressources doit être
    atomique : soit tout est appliqué, soit rien ne l'est.
-   Les événements rejouables portent un identifiant unique et sont
    idempotents.
-   Les calculs de simulation doivent recevoir explicitement la graine
    aléatoire ou le générateur déterministe ; éviter le hasard global
    caché.
-   L'interface demande une action et affiche le résultat. Elle ne
    réimplémente pas les règles métier.
-   Les ressources artistiques sont référencées par identifiant logique
    et métadonnées, pas par chemins dispersés dans le code.

## 5. Règles de travail pour une IA ou un développeur

1.  Lire `AGENTS.md`, `docs/INDEX.md`, puis uniquement la tâche assignée
    et les contrats des modules touchés.
2.  Examiner les fichiers du module ciblé et ses tests directs. Ne pas
    scanner tout le dépôt sans nécessité.
3.  Avant de modifier un contrat partagé, identifier les consommateurs
    et proposer la modification dans une tâche séparée.
4.  Ne pas renommer ou supprimer un identifiant persistant sans
    migration et test de sauvegarde.
5.  Ne pas modifier les fichiers hors périmètre sans signaler le besoin
    et demander validation.
6.  Produire des changements petits, localisés et réversibles.
7.  Ajouter ou actualiser les tests du module concerné.
8.  Exécuter les tests ciblés, puis les tests de régression disponibles.
9.  Mettre à jour la documentation du module et le journal des décisions
    si le comportement change.
10. Dans le compte rendu, fournir : fichiers modifiés, comportement
    changé, tests exécutés, résultats, risques et tâches restantes.
11. Ne jamais prétendre qu'un test a été exécuté si aucun outil ne l'a
    réellement exécuté.
12. Si le dépôt ne contient pas encore l'architecture proposée, ne pas
    inventer de fichiers existants : proposer un plan d'introduction
    progressif.

## 6. Textures et ressources graphiques

Chaque ressource doit être inscrite dans `docs/art/asset-register.csv`
avec : - `asset_id` stable ; - type (`texture`, `sprite`, `ui`, `icon`,
`audio`, `font`) ; - module propriétaire ; - chemin de fichier ; -
dimensions/résolution et format ; - variantes (normal, endommagé, nuit,
etc.) ; - état (à créer, en cours, validé, obsolète) ; -
droits/licence/source ; - dépendances et écran(s) qui l'utilisent.

Le nom de fichier ne doit pas être la seule source d'information. Une
texture ne doit pas embarquer de logique de gameplay. Le code doit
demander un `asset_id` ou passer par un registre d'assets. Les règles de
compression, tailles, formats et atlas seront définies après choix du
moteur.

## 7. Critères d'acceptation de l'architecture

-   Un développeur peut localiser le module propriétaire d'une
    fonctionnalité depuis l'index.
-   Une tâche indique son périmètre, ses dépendances et ses tests.
-   Les règles métier ne sont pas dupliquées dans l'interface.
-   Une modification locale n'impose pas de lire tous les modules.
-   Les contrats partagés sont documentés et versionnés.
-   Une ressource artistique peut être remplacée sans changer la logique
    de simulation.
-   Les tests de sauvegarde vérifient migrations, atomicité et absence
    de doublons.
