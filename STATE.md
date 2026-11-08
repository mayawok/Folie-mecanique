# État du projet — Folie Mécanique

Mis à jour : 2026-11-09. Résumé volontairement court (≈ 60 lignes). Détails : [`docs/DECISIONS.md`](docs/DECISIONS.md), [`docs/INDEX.md`](docs/INDEX.md).

## Cap (recentrage du 06/11, DEC-091 à DEC-102)

- **Référence unique : la Bible du lore** ([`docs/lore/01_BIBLE_FOUNDATION`](docs/lore/01_BIBLE_FOUNDATION)). Les documents du jeu s'y conforment.
- **Convoi seulement** (DEC-099) : plus de gestion de base ni de ressources de base ; au plus un checkpoint ou un garage par chapitre.
- **Joueur** : chef d'un convoi indépendant, qui a déjà un camion et fait des rotations dans le no man's land (DEC-100).
- **Monde** : climat pauvre, faune rare (DEC-093, 097) ; zones séparées par un no man's land (DEC-095) ; carte de 12 ou 13 secteurs,
  France reconnaissable mais déformée (DEC-101) ; factions de la Bible (DEC-098) ; essence et gazole seulement (DEC-094).
- **Du prototype, on garde la grille** ; le reste est réexaminé face à la Bible (DEC-092).
- **Priorité du prototype (07/11, DEC-110)** : le Mode créatif sert de kit de développement (toutes les pièces) pour bâtir monde, décors
  et rencontres avant tout chapitre. Jeu final : Mode créatif séparé, avec les seules pièces trouvées (DEC-111). **Kit codé le 07/11 (DEC-112, DEV-010)** : à essayer sur iPhone. Prochaine tâche : DEV-008 (affiner le décor par zone).
- **Équilibrage (07/11, DEC-113)** : ennemis en groupes, plus fragiles et moins meurtriers que le convoi, rôdeurs plus rares ; à régler en essai avec le Kit.
- **Décors et interface (07/11, DEC-114)** : zone « terre et herbe » en couches puis habillage de l'interface (concept art dans `docs/art/reference/`) ; rations et gestion retirées, panneaux repliables, rôle éclaireur. Décor terre et herbe intégré (DEC-115, DEV-011 fait) ; images d'interface rangées, à brancher : DEV-012 à 014.
- **Grille V2 (07/11, DEC-121 à DEC-125)** : véhicules trouvés = « bases » à transformer (rallonge par crans, essieux, modules, blindage) plutôt que châssis dessinés ; transformations lourdes au garage, essieu/moteur/boîte réparables en camp (long, camp à défendre) ; fiabilité sans bonus d'origine. Code fusionné, test Godot passé en CI ; **interface et dessin à faire** (DEV-016 à DEV-019). Détails : `docs/design/GRILLE.md`.
- **Berliet GDR (08/11, DEC-136 à 138)** : camion de l'expédition dessiné par l'art (2 châssis, 5 pneus avant et arrière, 5 échappements, 5 réservoirs, trappe), 6 modules arrière dessinés par le code, halte de l'équipage animée ; **véhicule principal dès le départ (DEC-139)**, dessiné par l'art dans le convoi ; pièces réglables dans le Kit (« Berliet GDR : pièces et halte »). Suite : DEV-020 (dans le convoi), DEV-021 (portières), lot 12 motos et side-cars (prompts dans `docs/art/prompts/motos_sidecars.md`).
- **Carte du monde (09/11, DEC-154)** : carte de conception dans le Kit sur la carte de France déformée : 13 villes-étapes, 22 routes, 30 lieux (pétrole, eau, mines, péages…), factions ; « Y aller » vers une ville. Détail : `docs/design/CARTE.md`.
- **Méthode de travail** : Claude fusionne lui-même dans `main` (autorisation du 07/11) ; la page web se reconstruit ensuite toute seule.
- **Ouverture** : cinématique vidéo, idée décrite dans [`docs/scenario/OUVERTURE.md`](docs/scenario/OUVERTURE.md) (DEC-102).

- **Villes standard (08/11, DEC-140 à 143)** : enceinte plate, grande porte gardée ; freinage seul devant la porte, entrée et sortie au pas sans ordre ;
  dans la ville rien n'arrive (point de reprise, ville inscrite sur la carte) ; mairie et maire, garage (réparation), atelier (grille) ; sortie au choix
  vers un secteur voisin. Dessin par le code, 30 noms de lieux-dits. Kit → « Ville devant ». Détail : [`docs/design/VILLES.md`](docs/design/VILLES.md). Suite : textures (DEV-024), quêtes (DEV-025), OQ-026.

- **Missions du maire (08/11, DEC-144 à 147)** : transport de cargaison (carburant, eau, vivres, munitions, pièces) vers la ville voisine, en une étape ;
  le maire annonce ennemis, escorte et récompense ; scènes de départ (atelier et pont roulant, rassemblement de l'escorte, tambours, « Bonne chance »),
  départ automatique, vagues sur la route, livraison = récompense. Citerne d'eau distincte de celle de carburant. Kit : toutes les missions. Suite : DEV-026, OQ-027.

- **08/11 soir (DEC-148 à 151)** : eau et vivres de retour (consommés, affichés, marché des villes) ; HUD en verre fumé (polices Oswald
  et pochoir, textes plus grands, plus d'images ChatGPT pour les boutons) ; menaces de mission tirées selon le niveau, maire mal renseigné ;
  ville pillée (événement du Kit : incendies, rescapés, poursuite du convoi des pillards).

## Ce qui existe

- Prototype Godot 4.3 / GDScript dans `game/`, publié sur GitHub Pages ([`game/LISEZMOI.md`](game/LISEZMOI.md)). Tests sans écran dans `game/tests/`.
- Mode convoi : combat, embuscades, poursuites et abordages, relief, carte, nuit et abri, fouille, garage, sauvegarde, sons
  ([`docs/design/CONVOI.md`](docs/design/CONVOI.md)). Une partie de ce contenu est à réexaminer (DEC-092).
- **Grille de construction** (DEC-034 à DEC-083) : châssis, essieux, roues, suspensions, moteurs, coques, tôles, greffes,
  radiateurs, remorques, plans enregistrés ([`docs/design/GRILLE.md`](docs/design/GRILLE.md)). Classe « Véhicule léger » (DEC-096).
- Gestion de base supprimée du dépôt (DEC-107). Données : véhicules (275 lignes), armes et composants dans [`data/master/`](data/master/INDEX.md) ; catalogue historique des armes,
  première passe de 15 armes (DEC-103, sources à renseigner).
- Direction artistique : [`docs/art/DIRECTION_ARTISTIQUE.md`](docs/art/DIRECTION_ARTISTIQUE.md) (DEC-085). Audio : ElevenLabs (DEC-084, 090).
- Dernier audit : [`docs/audits/AUDIT_2026-10-31.md`](docs/audits/AUDIT_2026-10-31.md).

## À vérifier sur iPhone (non vérifiable hors appareil)

Boutons atteignables, taille des cases de la grille, rechargements (DEC-056, 059), son en mode normal et silencieux (DEC-030, 041),
postes et bancs (DEC-062 à 064), interface allégée (DEC-065), construction en deux plans (DEC-067, 068), poursuites (DEC-077).

## À coder (décidé, pas encore fait)

Nouvelle ouverture (DEC-100), factions de la Bible (DEC-098), meutes rares et oiseaux (DEC-097), essence et gazole par moteur (DEC-094),
tempêtes en zones désertiques, zones calmes inversées, checkpoint de chapitre, décor par zone, carte fixe (DEC-109, DEV-006 à 009).

## Contradictions traitées le 06/11

- Passages périmés de VISION, CONVOI et GRILLE archivés (DEC-105) ; tâches de base archivées (DEC-106) ; modèle économique : démo + déblocage (DEC-104).
- Audit du 07/11 : 7 écarts Bible/prototype **tranchés comme recommandé** (DEC-109, OQ-022 résolue ; tâches DEV-006 à DEV-009) : [`docs/audits/ECARTS_BIBLE_PROTOTYPE_2026-11-07.md`](docs/audits/ECARTS_BIBLE_PROTOTYPE_2026-11-07.md) (OQ-022).
- Restent : le code du prototype garde l'ancienne ouverture et les factions 1-2-3 (DEV-002, DEV-003) ; tâches dépendantes à réviser (OQ-019).

## Décisions ouvertes

Toutes les questions, avec identifiant, sont dans [`docs/OPEN_QUESTIONS.md`](docs/OPEN_QUESTIONS.md).

## Carte du dépôt

| Chemin | Contenu |
|---|---|
| `AGENTS.md` | Règles pour développeurs et IA |
| `docs/INDEX.md` | Navigation et sources de vérité |
| `docs/DOCUMENT_REGISTRY.md` | Registre de tous les documents importants |
| `docs/lore/` | Bible du monde (réutilisable) |
| `docs/design/`, `docs/scenario/` | Choix propres à ce jeu |
| `game/` | Prototype Godot |
| `data/master/`, `data/rules/` | Tableaux et règles |
| `archive/` | Éléments en sommeil |
| `tools/` | Scripts |
