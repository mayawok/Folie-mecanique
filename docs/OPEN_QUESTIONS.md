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

## OQ-022 — Écarts Bible et prototype

- **Question** : pour chacun des écarts E4 à E10 (tempêtes, meutes, chien, zone calme, camps, décor, carte), garde-t-on, adapte-t-on ou supprime-t-on ?
- **Pourquoi la trancher** : DEC-092 impose un réexamen élément par élément avant tout nouveau code ; débloque DEV-004 et la nouvelle carte.
- **Documents concernés** : docs/audits/ECARTS_BIBLE_PROTOTYPE_2026-11-07.md, docs/design/CONVOI.md
- **Options connues** : garder / adapter / supprimer, avec une recommandation par écart dans l'audit
- **Statut** : résolue (DEC-109)

## OQ-023 — Grille V2 : réglages à trancher

- **Question** : taille maximale du convoi et rôle de la capacité de chargement ; bases de la V0 (une par faction ?) ; véhicules historiques à garder ou archiver face à la Bible (Tiger I, Sherman, etc.) ; l'atelier mobile peut-il aussi rallonger ?
- **Pourquoi la trancher** : borne le nombre de bases à dessiner et l'équilibrage des modules (DEC-121 à 124).
- **Documents concernés** : docs/design/GRILLE.md, game/data/bases.json, docs/lore/01_BIBLE_FOUNDATION
- **Options connues** : une base par faction ; atelier mobile limité au niveau 1 (proposition actuelle)
- **Statut** : ouverte

## OQ-024 — Communautés ferroviaires et mission du camp : validation

- **Question** : valider (ou non) les deux propositions du 07/11 ; créer ou non `FAC-008 — Communautés ferroviaires` comme entrée descriptive (non centralisée) dans la Bible ; choisir lieu et noms du camp ; vérifier les modèles de véhicules allemands avant tout catalogue.
- **Pourquoi la trancher** : sans validation, ces documents ne sont pas canon et ne doivent pas alimenter les données ni le code (DEC-131).
- **Documents concernés** : docs/lore/communautes-ferroviaires.md, docs/scenario/mission-liberation-camp-travailleurs.md, docs/lore/01_BIBLE_FOUNDATION
- **Options connues** : FAC-008 descriptive ; ou aucune entrée collective
- **Statut** : ouverte

## OQ-025 — Berliet : valeurs et modules

- **Question** : valeurs de jeu des pièces du Berliet (charge des châssis, litres des réservoirs, bonus des échappements, effets des pneus) ; les modules grue, troupes et ridelles hautes entrent-ils dans `bases.json` (nouveaux identifiants) ou restent-ils propres au Berliet ? Niveau de garage requis pour chaque amélioration.
- **Pourquoi la trancher** : sans elles, les pièces ne changent que le dessin (DEC-136).
- **Documents concernés** : game/data/berliet.json, game/data/bases.json, docs/design/GRILLE.md
- **Options connues** : valeurs provisoires actuelles ; châssis long et grue au garage de niveau 2
- **Ajout (08/11, DEC-139)** : le Berliet, véhicule principal, peut-il être détruit en combat ? Options : mêmes règles qu'aujourd'hui (fin de partie possible) ; ou jamais détruit, seulement immobilisé et à réparer.
- **Statut** : ouverte

## OQ-026 — Villes (08/11)
Textures propres à chaque ville ; quêtes, marché et recrutement ; la route entre deux secteurs (aujourd'hui « zone calme ») doit-elle devenir le no man's land dangereux (DEC-095) ? décor de la route selon la sortie choisie ; villes hostiles possibles ? Voir `docs/design/VILLES.md`.

## OQ-027 — Missions du maire (08/11)
Eau et vivres : tranché le 08/11 (DEC-148, consommés et affichés). L'escorte reste dans la ville d'arrivée : faut-il pouvoir la garder ? Cargaison abîmée par les tirs (citerne percée) ? Combien de missions en expédition, et une seule à la fois ?

## OQ-028 — Baie des marées (PRJ-001, 08/11, pour plus tard)
Emplacement et nom de la ville (Mont-Tombe ?) ; rythme des marées ; moteur noyé réparable ou perdu ; rouille par l'eau de mer ; bancs de sable pour attendre ; bac payant du Réseau des Marées. Voir `docs/design/PROJETS.md`.

## OQ-029 — Trains routiers à deux moteurs (PRJ-002, 08/11, pour plus tard)
Véhicule à part ou évolution du Berliet ; Raffineurs du Sud comme propriétaires principaux ; moment de l'histoire ; coupleur fabriqué ou seulement récupéré. Voir `docs/design/PROJETS.md`.

## OQ-030 — Char à voile et côte bretonne (PRJ-003, PRJ-004, 08/11, pour plus tard)
Vent visible, rôle du char à voile, voile sur d'autres véhicules ; nombre de bateaux dans le décor, bateau encore flottant, part bretonne de la carte. Voir `docs/design/PROJETS.md`.

## OQ-031 — Repaire de boss (DEC-166, 09/11)

Quelle faction tient le repaire ? Proposition : les Hommes du Péage ou une famille des Raffineurs du Sud.

## OQ-032 — Le Berliet dans la grille 2D (09/11, à poser au créateur à la prochaine discussion)

Le Berliet est déjà ouvrable dans la grille (atelier de ville, bac à sable), mais dessiné en formes simplifiées, et sa vitrine de modules est à part.
Que veut dire « intégrer le Berliet dans la grille 2D » : 1) le voir avec son vrai dessin dans la grille ; 2) le modifier librement pièce par pièce ;
3) fusionner sa vitrine de modules dans la grille ? Autre question en suspens : remettre un bouton de demi-tour (retiré avec le menu d'ordres, DEC-160) ?

## OQ-033 — Suites de l'entretien du 10/11 (à poser au créateur)

1. Ordres tactiques seulement (DEC-174) alors que le menu d'ordres a été supprimé (DEC-160) : quels ordres le joueur donne-t-il, et par quelle interface ?
2. Difficulté forcée (DEC-172) : tant que la quête principale n'existe pas, quelle région sert de repère dans le Kit ?
3. Retour au dernier checkpoint (DEC-173) : que garde-t-on (équipement, véhicules, ressources) et que perd-on (cargaison, mission) ?
4. Le Kit exclut le branchement de la carte (DEV-009) mais celui-ci est la priorité n°2 de code : ordre exact ?
5. `claude/VISION.md` est ancien : le réaligner sur la Bible et DEC-091 à 102 ?

## OQ-034 — Suites de l'entretien 2 (10/11)

1. Glisser depuis l'image du véhicule : quels gestes (vers l'avant/l'arrière du convoi, vers une cible, vers l'extérieur pour éclaireur) ?
2. Retour au checkpoint (DEC-173) : ce qui est gardé ou perdu reste à définir.
3. Réputation (DEC-184) : quelles paires de factions sont rivales, quels paliers (accueil, prix, missions, hostilité) ?
4. Épaves (DEC-181) : quel coût en ressources, et quelle probabilité de récupération ?

## OQ-035 — Suites de l'entretien 3 (10/11)

1. **Cohérence prix / durée / art** : plus de 30 heures de jeu pour environ 5 € demande beaucoup d'art et de contenu ; faut-il viser une durée plus courte pour la première version, ou un prix plus haut ?
2. **Traduction (DEC-193)** : français et anglais dès le début ; qui relit l'anglais ?
3. **Noms de véhicules (DEC-197)** : liste des marques encore actives à déguiser ; vérification juridique avant publication.
4. **Jalon de déblocage du Mode créatif (DEC-203)** : après quel chapitre ?
5. Restent de OQ-034 : retour au checkpoint (ce qu'on garde), paires de factions rivales et paliers de réputation, coût et probabilité des épaves.

## OQ-036 — Capacité du réservoir (10/11) — RÉSOLUE par DEC-207 (réservoir + citerne + bidons)

Le carburant est un stock unique du convoi. Le réservoir du Berliet (120 à 560 L) n'en limite pas encore le montant, car des récompenses de 150 à 300 L seraient perdues (missions, Baron). DEC-190 veut un carburant contraignant. Choix : plafonner au réservoir + citerne du module ; ou laisser le surplus dans des jerrycans qui se vident en premier.
