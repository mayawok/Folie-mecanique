# Vision actuelle — Folie Mécanique

**Statut :** vision de conception **en vigueur** depuis le 15/11/2026 (DEC-242 à DEC-248). Elle remplace comme référence courante la vision du 10/11, archivée dans [`../../archive/docs_design/VISION_2026-11-10.md`](../../archive/docs_design/VISION_2026-11-10.md) (document historique, conservé).  
**Version :** 2.0  
**Hiérarchie :** la Bible du lore (`docs/lore/01_BIBLE_FOUNDATION`) décrit le monde et reste la référence universelle (DEC-091) ; ce document décrit **ce jeu-ci**. En cas de conflit, la décision la plus récente l'emporte (voir [`../DECISIONS_INDEX.md`](../DECISIONS_INDEX.md)).

> **Références historiques.** Les décisions DEC-001 à DEC-179 citent « `docs/design/VISION.md` » : elles désignent la vision d'origine, aujourd'hui archivée (DEC-179). Ce fichier-ci est la vision actuelle.

## 1. Positionnement

Folie Mécanique est un jeu où **la survie et la mécanique pèsent autant l'une que l'autre**. On peut l'apprécier sans être passionné de mécanique automobile.

Activités principales :

- explorer un monde post-apocalyptique ;
- survivre ;
- récupérer des ressources ;
- découvrir des véhicules ;
- construire et réparer des véhicules ;
- développer des relations avec les villes et les factions ;
- organiser des expéditions ;
- développer peu à peu un **réseau logistique**.

## 2. Ce qui ne change pas

- **Le convoi principal est le cœur de l'aventure** : le joueur est chef d'un convoi indépendant, dont le camion est le Berliet GDR, du début à la fin (DEC-100, 139).
- **Monde** : France déformée figée dans les années 1940, zones calmes séparées par un no man's land dangereux (Bible 04.1 ter) ; une capitale par région (DEC-240) et des lieux mineurs.
- **Combat** : les véhicules agissent seuls, le joueur réordonne les vignettes (DEC-186).
- **Carburant** : essence et gazole, contrainte forte (DEC-094, 190).
- **Ressources rares et tendues** partout (DEC-097, 238).
- **Réputation par faction** (DEC-184, 217), monde libre à difficulté forcée hors région de quête (DEC-172).
- **Modèle économique** : démo + déblocage (DEC-104). Aucune décision commerciale nouvelle n'est prise ici (le réseau logistique n'est pas décidé comme DLC).
- **Cible** : iPhone 14 Pro Max et plus, paysage (DEC-196). Jalon courant : finir le Kit (DEC-171).

## 3. Mécanique à profondeur facultative (DEC-242)

**Un seul système mécanique**, dont la profondeur dépend du niveau d'interaction choisi. On ne crée pas deux systèmes.

| Niveau | Le joueur fait | Exemples |
|---|---|---|
| Accessible | choisit des améliorations prédéfinies, compare, installe | puissance, autonomie, capacité, résistance ; équipements compatibles |
| Intermédiaire | choisit et adapte | motorisations, transmissions, pneumatiques, compromis puissance / consommation / fiabilité, adaptation au terrain |
| Expert | maîtrise l'architecture | compatibilité des pièces, répartition des masses, motricité, rapports de transmission, optimisation |

Fondations existantes : grille et Grille V2 (`GRILLE.md`), physique (`PHYSIQUE.md`), transmission (`TRANSMISSION.md`). Le niveau accessible et le niveau intermédiaire ne sont pas encore conçus comme parcours : tâche DOC-007 (`../TASKS.md`).

## 4. Logistique et convois autonomes (DEC-243 à DEC-246, 248)

Le joueur peut stocker des véhicules, les réparer, lancer des convois autonomes en trajet unique ou en circuit, les suivre sur la carte, les croiser sur la route et les secourir en cas de panne. Cahier des charges : [`LOGISTIQUE_CONVOIS.md`](LOGISTIQUE_CONVOIS.md).

Garde-fous :

- ce n'est **pas** un retour de la gestion de base supprimée (DEC-099, 107, 108) : pas de bâtiments à construire, pas de production, pas de défenses ;
- simple sur iPhone ;
- calculé sous forme de simulation stratégique, sans dessiner les convois en permanence ;
- modulaire : on peut retirer une fonctionnalité après les essais (§ 7).

## 5. Direction artistique (DEC-247)

Évolution : **peinture stylisée semi-réaliste**, formes simplifiées, détails sélectionnés, meilleure lisibilité sur mobile, couleurs naturelles plus présentes, ambiance moins systématiquement grise et poussiéreuse. Le jeu ne devient pas un dessin animé. Les assets déjà produits restent valides ; transition progressive. Détail : [`../art/DIRECTION_ARTISTIQUE.md`](../art/DIRECTION_ARTISTIQUE.md), section 1 bis.

## 6. Ton

Post-apocalyptique et mélancolique, mais avec des lieux chaleureux, des villages vivants, des ateliers éclairés et des moments de vie quotidienne. Sérieux, avec beaucoup d'action.

## 7. Périmètre et méthode

- Le système logistique est organisé en **noyau**, **première version ou pack de contenu**, **expérimental** (voir son § 3), chacun avec un interrupteur.
- Gros lots espacés, tests sur iPhone après chaque lot (DEC-175).
- Rien n'est codé tant que le Kit n'est pas fini (DEC-171, 206) sauf décision contraire.
- Les valeurs non validées (nombre de convois, capacités, durées de panne, coûts, probabilités, vitesses, quantités) sont **ouvertes** : OQ-041.

## 8. Décisions remplacées ou complétées

| Décision | Sort |
|---|---|
| DEC-099 (convoi seulement) | **partiellement remplacée** par DEC-243 : la limite « au plus un checkpoint ou un garage par chapitre » est levée pour le stockage et le lancement de convois ; la gestion de base reste exclue |
| DEC-100 (chef d'un convoi indépendant) | **conservée** pour le convoi principal, **complétée** par DEC-243 |
| DEC-107, 108 (nettoyage de la base) | **conservées** comme historique ; rien n'est restauré |
| DEC-179 (vision archivée) | **complétée** : une vision actuelle existe (ce document) |
| DEC-104 (démo + déblocage) | inchangée |

## 9. Questions ouvertes

OQ-041 à OQ-047 dans [`../OPEN_QUESTIONS.md`](../OPEN_QUESTIONS.md).
