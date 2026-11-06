# Questions ouvertes

Créé le 2026-11-06. Une entrée par question. Aucune question n'est une décision : le statut passe à « résolue » seulement quand le concepteur tranche, avec renvoi à une décision (DEC-xxx).

Identifiants stables : ne jamais les réutiliser. Statuts : ouverte, en discussion, résolue.

## OQ-001 — Économie

- **Question** : Quel modèle économique pour un jeu de convoi sans base (prix unique, démo + déblocage, cosmétiques, achats intégrés) ?
- **Pourquoi la trancher** : DEC-004, 012, 013 datent d'avant DEC-099 (convoi seulement). Conditionne la production finale et la licence audio (DEC-024).
- **Documents concernés** : docs/DECISIONS.md, docs/design/VISION.md
- **Options connues** : Prix unique ; démo + déblocage ; cosmétiques ; statu quo (gratuit + achats)
- **Statut** : résolue (DEC-104)

## OQ-002 — Progression

- **Question** : Quel est le but d'une partie et que garde-t-on entre deux parties (roguelite) ?
- **Pourquoi la trancher** : DEC-032 pose un roguelite de convoi ; le but et la persistance ne sont pas définis. Ils déterminent le garage de chapitre et les checkpoints.
- **Documents concernés** : docs/design/VISION.md, STATE.md
- **Options connues** : Aucune option consignée
- **Statut** : ouverte

## OQ-003 — Production

- **Question** : Gèle-t-on les fonctions pour un cycle d'essais (ESSAIS.md) ?
- **Pourquoi la trancher** : Sans gel, l'équilibrage ne peut pas s'appuyer sur des sessions comparables.
- **Documents concernés** : docs/design/ESSAIS.md
- **Options connues** : Oui / non
- **Statut** : ouverte

## OQ-004 — Technique

- **Question** : Passe-t-on à Godot 4.6, et quel chemin de compilation iOS sans Mac ?
- **Pourquoi la trancher** : Détermine la publication sur l'App Store ; l'export web fonctionne aujourd'hui.
- **Documents concernés** : docs/DECISIONS.md (DEC-001), game/
- **Options connues** : Export iOS dans le nuage ; rester en 4.3
- **Statut** : ouverte

## OQ-005 — Art

- **Question** : Quels contours (A, B ou C) et que fait-on des planches en « aplats » déjà produites ?
- **Pourquoi la trancher** : Cohérence visuelle de tous les assets (DEC-085).
- **Documents concernés** : docs/art/DIRECTION_ARTISTIQUE.md, docs/art/PRODUCTION.md
- **Options connues** : Contours A, B ou C
- **Statut** : ouverte

## OQ-006 — Ouverture

- **Question** : Le camion « abandonné » est-il un piège volontaire ou l'équipage s'y cache-t-il ?
- **Pourquoi la trancher** : Définit le savoir-faire du convoi dès la première scène.
- **Documents concernés** : docs/scenario/OUVERTURE.md
- **Options connues** : Piège / équipage caché
- **Statut** : ouverte

## OQ-007 — Ouverture

- **Question** : Quel est le retournement à la livraison ?
- **Pourquoi la trancher** : Lance l'histoire et justifie la fin des rotations.
- **Documents concernés** : docs/scenario/OUVERTURE.md
- **Options connues** : Ami mort ; route tenue par une faction ; document à porter ; cause servie sans le savoir
- **Statut** : ouverte

## OQ-008 — Ouverture

- **Question** : Que livre le convoi : le carburant de la cuve ou autre chose ?
- **Pourquoi la trancher** : Détermine la valeur de la scène et l'objet du retournement.
- **Documents concernés** : docs/scenario/OUVERTURE.md
- **Options connues** : Carburant ; autre cargaison avec carburant en appât
- **Statut** : ouverte

## OQ-009 — Lore

- **Question** : Les deux soldats en uniforme appartiennent-ils à une faction de la Bible ou restent-ils inconnus ?
- **Pourquoi la trancher** : Rattache l'ouverture aux factions (DEC-098) ou garde le mystère.
- **Documents concernés** : docs/scenario/OUVERTURE.md, docs/lore/01_BIBLE_FOUNDATION
- **Options connues** : Faction nommée ; inconnus
- **Statut** : ouverte

## OQ-010 — Lore

- **Question** : Quelle est la correspondance entre les 12 ou 13 secteurs et les factions et lieux de la Bible ?
- **Pourquoi la trancher** : Prérequis au codage des factions et de la carte (DEC-098, 101).
- **Documents concernés** : docs/lore/01_BIBLE_FOUNDATION, docs/design/VISION.md
- **Options connues** : Aucune option consignée
- **Statut** : ouverte

## OQ-011 — Carte

- **Question** : 12 ou 13 secteurs, et quelles zones sont des villes, des lieux ou du no man's land ?
- **Pourquoi la trancher** : DEC-101 laisse le nombre ouvert.
- **Documents concernés** : docs/design/VISION.md
- **Options connues** : 12 ; 13
- **Statut** : ouverte

## OQ-012 — Gameplay

- **Question** : Que fait-on, face à la Bible, de : champs de mines, fléau (Sherman Crab), chien, voyageurs, camps ?
- **Pourquoi la trancher** : DEC-092 demande un réexamen élément par élément. Compatibles a priori avec la Bible, non tranchés.
- **Documents concernés** : docs/design/CONVOI.md
- **Options connues** : Garder / adapter / supprimer, par élément
- **Statut** : ouverte

## OQ-013 — Gameplay

- **Question** : Fréquence des meutes, des tempêtes de sable et rareté des oiseaux (valeurs).
- **Pourquoi la trancher** : DEC-097 fixe le principe, pas les valeurs.
- **Documents concernés** : docs/design/CONVOI.md, game/data/combat_proto.json
- **Options connues** : Réglage par essais
- **Statut** : ouverte

## OQ-014 — Véhicules

- **Question** : Quels modèles de voitures pour chaque longueur de châssis et comment les trouve-t-on en jeu ?
- **Pourquoi la trancher** : Complète DEC-083 ; hors mode créatif la plateforme ne change pas.
- **Documents concernés** : docs/design/GRILLE.md
- **Options connues** : Aucune option consignée
- **Statut** : ouverte

## OQ-015 — Direction créative

- **Question** : Quels principes de George Miller reprend-on précisément (immersion, vocabulaire inventé, rien expliquer, etc.) ?
- **Pourquoi la trancher** : DEC-101 le mentionne sans le préciser.
- **Documents concernés** : docs/design/VISION.md
- **Options connues** : Aucune option consignée par le concepteur
- **Statut** : ouverte

## OQ-016 — Droits

- **Question** : Comment traite-t-on les noms de marques en production (supprimer, remplacer, par véhicule) ?
- **Pourquoi la trancher** : DEC-096 reporte la décision à la version de production ; risque juridique.
- **Documents concernés** : docs/DECISIONS.md, data/master/base_maitre_vehicules.csv
- **Options connues** : Marques non nommées ; noms modifiés
- **Statut** : ouverte

## OQ-017 — Documents

- **Question** : Que fait-on des documents contredisant la Bible (VISION, CONVOI, GRILLE, TASKS, LORE) : mise à jour, archivage ?
- **Pourquoi la trancher** : Ils sont signalés dans le registre, non modifiés.
- **Documents concernés** : docs/DOCUMENT_REGISTRY.md
- **Options connues** : Mettre à jour ; archiver ; garder avec mention
- **Statut** : résolue (DEC-105)

## OQ-018 — Tâches

- **Question** : Les tâches SYS-BASE, SYS-DEF, SYS-ECON, SYS-EXP et CONTENT-001 sont-elles archivées au vu de DEC-099 ?
- **Pourquoi la trancher** : Leur objet (base, défense, économie de base) contredit « convoi seulement ».
- **Documents concernés** : docs/TASKS.md
- **Options connues** : Archiver ; adapter au convoi
- **Statut** : résolue (DEC-106)

## OQ-019 — Tâches

- **Question** : que deviennent les tâches SYS-SURV-001, SYS-VEH-001, UI-001, QA-002 et QA-003, qui dépendent de tâches archivées (stocks, base, expéditions) ?
- **Pourquoi la trancher** : leurs dépendances pointent vers des tâches archivées (DEC-106).
- **Documents concernés** : docs/TASKS.md
- **Options connues** : les adapter au convoi ; les réécrire en nouvelles tâches
- **Statut** : ouverte

## OQ-020 — Économie

- **Question** : quels chapitres ou quelle durée la démo contient-elle, et à quel prix le jeu complet est-il débloqué (DEC-104) ?
- **Pourquoi la trancher** : fixe le périmètre du premier jalon et la structure en chapitres.
- **Documents concernés** : docs/design/VISION.md
- **Options connues** : aucune consignée
- **Statut** : ouverte

## OQ-021 — Données

- **Question** : pour `contenu_depart_p0`, quelle version fait foi : l'onglet du classeur `base_maitre.xlsx` (15 lignes) ou le CSV (14 lignes) ?
- **Pourquoi la trancher** : le CSV a été modifié hors du processus d'export ; un prochain export écraserait ces changements. Le contenu décrit en outre un départ de base (eau, nourriture, bâtiments) qui contredit DEC-099 et DEC-100.
- **Documents concernés** : data/master/contenu_depart_p0.csv, sources/base_maitre.xlsx
- **Options connues** : garder le classeur ; reporter les changements du CSV dans le classeur ; archiver l'onglet (départ de base)
- **Statut** : résolue (DEC-107, tableau supprimé)
