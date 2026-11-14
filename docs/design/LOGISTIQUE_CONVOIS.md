# Logistique et convois autonomes — cahier des charges

**Projet :** Folie Mécanique  
**Statut :** conception validée dans son principe par le porteur du projet le 15/11/2026 (DEC-242 à DEC-248). **Aucun code n'existe pour ce système.** Toute valeur chiffrée est à équilibrer et n'est pas une décision.  
**Version :** 0.1  
**Références :** [`VISION.md`](VISION.md) · [`CONVOI.md`](CONVOI.md) · [`CARTE.md`](CARTE.md) · [`VILLES.md`](VILLES.md) · [`MISSIONS.md`](MISSIONS.md) · [`GRILLE.md`](GRILLE.md) · [`../DATA_CONTRACTS.md`](../DATA_CONTRACTS.md) · [`../../AGENTS.md`](../../AGENTS.md) · Bible : `docs/lore/01_BIBLE_FOUNDATION` (sections 04.1 ter, 04.5, 05, 09, 11)

> **Règle de lecture.** « Validé » = décidé par le porteur du projet. « Proposé » = proposition de conception à confirmer (voir [`../OPEN_QUESTIONS.md`](../OPEN_QUESTIONS.md), OQ-041 à OQ-046). Les paramètres sont nommés `log.*` et vivront dans un futur `game/data/logistique.json` (non créé ici).

---

## 1. Principe

Le joueur garde son **convoi principal** (le Berliet GDR, DEC-139), seul convoi qu'il pilote et voit rouler en scène. Il peut en plus, progressivement, monter un **réseau de convois autonomes** : des groupes de véhicules qu'il lance depuis un lieu, qui circulent sans lui et qu'il suit sur la carte.

C'est une **extension du convoi**, pas un retour à la gestion de base supprimée le 06/11 (DEC-099, 107, 108). Ce qui reste interdit :

- bâtiments à construire, chantiers, files de construction ;
- ressources et production de base, simulation à 30 jours, défenses de base ;
- boucle de gestion à quotas, abonnements, accélérateurs de chantier.

Ce qui est autorisé : stocker des véhicules, les réparer avec les systèmes existants, lancer des convois, les suivre, les secourir.

## 2. Vocabulaire

| Terme | Sens |
|---|---|
| Convoi principal | Le Berliet et son groupe, joué en scène (DEC-100, 139). |
| Convoi autonome | Groupe de véhicules du joueur lancé sur un itinéraire, calculé sans dessin (§8). |
| Site | Lieu où l'on peut stocker et lancer : ville alliée, camp du joueur (§3). |
| Emplacement | Place de stockage d'un site, limitée par ses infrastructures. |
| Trajet unique / circuit | Les deux modes de circulation (§6). |
| Équipe de secours | Convoi autonome de type « secours » envoyé vers un convoi en panne (§11). |

## 3. Périmètre en trois catégories

Chaque fonctionnalité porte un identifiant `LOG-*` et un **interrupteur** `log.module.<nom>` qui permet de l'activer, désactiver ou reporter après les essais (§15). Aucune décision commerciale n'est prise : ce n'est ni un DLC ni un achat supplémentaire.

### Noyau indispensable

| ID | Fonctionnalité | Détail |
|---|---|---|
| LOG-N1 | Sites de stockage dans les villes alliées | §4 |
| LOG-N2 | Récupération, stockage et réparation de véhicules | §5 (systèmes existants) |
| LOG-N3 | Création d'un convoi sur place, **trajet unique** | §7, 6 |
| LOG-N4 | Simulation stratégique : position, progression, consommation, état, arrivée | §8 |
| LOG-N5 | Carte stratégique : voir ses convois, fiche par convoi | §9 |
| LOG-N6 | Affectations exclusives, identifiants stables, sauvegarde et migration | §13 |
| LOG-N7 | Plusieurs convois par site et par zone, sans plafond arbitraire | §7 |

### Première version ou son pack de contenu

| ID | Fonctionnalité | Détail |
|---|---|---|
| LOG-P1 | **Circuit permanent** multi-étapes (A → B → C → D → A) | §6 |
| LOG-P2 | **Camps du joueur** comme sites de stockage et de lancement | §4.3 |
| LOG-P3 | **Croisement** physique avec ses propres convois | §10 |
| LOG-P4 | **Pannes** (ralentissement, immobilisation) et information du joueur | §11 |
| LOG-P5 | **Intervention personnelle** du convoi principal | §11.2 |
| LOG-P6 | **Équipe de secours** envoyée depuis un site | §11.3 |
| LOG-P7 | **Cargaison simple** : chargement, déchargement, échange via l'économie existante | §12 |

### Expérimental (activable, désactivable, reportable)

| ID | Fonctionnalité |
|---|---|
| LOG-X1 | Interactions étendues à la rencontre (transfert de ressources, échange d'équipage) |
| LOG-X2 | Incidents liés à la réputation, aux factions et à la difficulté forcée (DEC-172) |
| LOG-X3 | Contraintes de marée sur les horaires (Dol et la baie, DEC-238, 239) |
| LOG-X4 | Consommation d'eau et de vivres des équipages autonomes |
| LOG-X5 | Épaves laissées sur la route par un convoi perdu, récupérables |
| LOG-X6 | Utilisation des voies ferrées par les convois (gelé : DEC-163, 206) |

## 4. Stockage des véhicules (LOG-N1, LOG-P2)

### 4.1 Où

- **Villes alliées** (noyau). Le seuil de réputation qui rend une ville « alliée » n'est pas fixé : OQ-043. La réputation a déjà cinq paliers (DEC-217).
- **Camps du joueur** (première version, LOG-P2). Définition à valider : OQ-042. Le camp actuel est une halte temporaire (DEC-161) ; un camp du joueur serait un lieu **persistant** posé sur la carte, avec stockage, **sans** bâtiments ni production ni défense (DEC-099 reste respecté).
- Autres infrastructures autorisées par le jeu : liste à fixer, par exemple dépôt de carburant ou port tenu par une faction amie (OQ-042).

### 4.2 Quoi

Un site stocke des **véhicules** dans quatre états :

| État | Définition |
|---|---|
| Opérationnel | Peut rejoindre un convoi (§5.3). |
| Endommagé | Roule peut-être, mais des pièces sont abîmées. |
| Épave | Récupérée (DEC-181, 188), non roulante. |
| En attente de réparation | Confié à un mécanicien du site (§5.2). |

Un véhicule stocké reste une **instance** (`vehicle_instance_id`) avec ses pièces, son état en pourcentage et son historique (DATA_CONTRACTS, séparation définition / instance).

### 4.3 Capacité

Chaque site a un nombre d'**emplacements** dépendant de ses infrastructures. Les valeurs sont paramétrables : `log.site.emplacements.<type_de_site>` et `log.site.emplacements.epaves`. Valeurs : à équilibrer. Un emplacement n'est occupé que par un véhicule à la fois ; stocker échoue sans effet partiel s'il n'y a plus de place (transaction atomique).

## 5. Récupération et réparation (LOG-N2)

### 5.1 Parcours d'un véhicule

```
Trouvé (fonctionnel | endommagé | épave)
  → ramené dans une ville ou un camp (le convoi principal le remorque ou le conduit)
  → stocké dans un emplacement
  → confié à un mécanicien (réparation)
  → opérationnel → disponible pour un convoi
```

### 5.2 Un seul système de réparation

On **réutilise** l'existant, sans créer de second système :

| Besoin | Système existant |
|---|---|
| Réparer une pièce, remplacer une pièce détruite, rafistoler | règles de `CONVOI.md` (« Butin et réparation ») : métal, pièce compatible récupérée, rafistolage à 25 % |
| Remise en état en ville | garage et mécanicien (`VILLES.md`) : coût en métal par point de vie manquant |
| Réparation longue, immobilisation, interruption | `camp_reparation.gd` (DEC-122, 125) |
| Fiabilité et usure | DEC-123 |
| Récupération légère ou lourde d'une épave | DEC-181, 188 |

La réparation d'un véhicule **stocké** applique les mêmes règles, avec un **temps** (horloge de jeu) et des **ressources** prélevées de façon atomique. Les durées et coûts ne sont pas fixés ici : `log.reparation.*`.

### 5.3 Conditions pour rejoindre un convoi

Un véhicule rejoint un convoi seulement s'il est **opérationnel** : moteur, transmission, roues ou chenilles, châssis et carburant utilisables. Le contrôle réutilise le profil du véhicule déjà calculé par la grille.

## 6. Modes de circulation (LOG-N3, LOG-P1)

| Mode | Comportement |
|---|---|
| **Trajet unique** (noyau) | Le convoi parcourt son itinéraire une fois et s'arrête à destination, où il devient inactif et ses véhicules sont stockés. |
| **Circuit permanent** (V1) | Itinéraire A → B → C → D → A, recommencé automatiquement ; le joueur le suit sur la carte. |

Commandes essentielles (proposées, en réponse à l'exigence « interrompre ou modifier ») :

- **Suspendre** : le convoi s'arrête à la prochaine étape sûre ; **Reprendre**.
- **Modifier le circuit** : l'itinéraire modifié prend effet à la prochaine étape.
- **Dissoudre à l'arrivée** : le convoi se range dans le site d'arrivée.

Étapes et chemin : par les routes de `carte_monde.json` (nœuds `lieux`, arêtes `routes`). L'itinéraire d'un convoi utilise le même calcul de plus court chemin que le joueur (`CarteMonde.chemin`). Une étape est un **lieu** de la carte où le joueur possède un site.

## 7. Création d'un convoi (LOG-N3, LOG-N7)

**Condition impérative : le joueur est physiquement présent** sur le site pour créer et lancer le convoi.

Déroulé (iPhone, trois écrans au plus) :

1. **Véhicules** : liste des véhicules opérationnels du site.
2. **Équipes** : personnes disponibles pour conduire et accompagner (§13.2).
3. **Itinéraire et mode** : destination ou circuit, trajet unique ou permanent ; cargaison éventuelle (LOG-P7).

Puis **Lancer**. Rien n'est appliqué tant que le joueur n'a pas confirmé ; la confirmation réserve en une seule opération véhicules, personnes, cargaison et carburant (transaction atomique). Une même instance ou un même survivant ne peut pas être affecté à deux usages incompatibles (§13).

Plusieurs convois par site et par zone : **pas de plafond arbitraire**. Les limites naissent des emplacements, des véhicules disponibles, des personnes disponibles et du carburant. Deux paramètres facultatifs, **désactivés par défaut** : `log.convois.max_total` et `log.convois.max_par_site`.

## 8. Simulation stratégique (LOG-N4)

### 8.1 Principe

Aucun convoi autonome n'est simulé graphiquement en permanence. L'état d'un convoi est un petit enregistrement mis à jour par pas :

| Champ | Rôle |
|---|---|
| `convoi_id` | identifiant persistant stable |
| `etat` | `preparation`, `en_route`, `ralenti`, `immobilise`, `en_attente_secours`, `suspendu`, `arrive`, `perdu` |
| `itineraire` | liste de `lieu_id` + mode (trajet unique / circuit) + index d'étape |
| `position` | `route` (paire `a`,`b` de la carte), sens, progression en distance de jeu |
| `vehicules` | liste de `vehicle_instance_id` |
| `equipage` | personnes affectées (§13.2) |
| `carburant` | par véhicule, en litres, essence et gazole séparés (DEC-094) |
| `incidents` | liste d'incidents avec `event_id` |
| `graine` | graine propre au convoi pour les tirages |

### 8.2 Temps

- L'**horloge** est celle du monde de jeu (`monde.heure`, `monde.jour`), pas le temps réel. Les convois progressent **pendant que le joueur joue** (route, ville, menus, carte).
- Progression par pas fixe `log.pas_strategique` (heures de jeu). À chaque pas, un convoi avance de `vitesse_commerciale × durée`, consomme, puis subit éventuellement un tirage d'incident.
- **Pas de progression hors ligne** tant que non validé (OQ-045).
- Le temps de trajet d'un convoi utilise les **mêmes distances et la même horloge** que le trajet du joueur, de façon qu'un croisement soit cohérent (§10). La conversion entre les distances de la carte (km) et les distances de scène (m) **n'a pas été vérifiée** dans le code ; c'est un prérequis (LOG-T1).

### 8.3 Déterminisme et idempotence

- Chaque tirage utilise `graine` et un compteur de pas : même sauvegarde, même résultat.
- Tout événement porte un `event_id` dérivé de `(convoi_id, pas)` ; le rejouer ne double pas ses effets (DATA_CONTRACTS, Événements).
- Rattrapage : si plusieurs pas se sont écoulés (long séjour en ville, nuit accélérée ×3), le moteur **rejoue les pas dans l'ordre** ; il ne saute jamais un pas.

### 8.4 Consommation

Carburant selon le profil de chaque véhicule (réservoirs DEC-207, deux stocks). Panne sèche = immobilisation (DEC-190, contrainte forte). Eau et vivres des équipages : expérimental (LOG-X4), valeur par défaut : non consommés.

### 8.5 Incidents

Un tirage par pas peut produire une panne. Probabilité : `log.incident.proba_base`, modulée par le **danger de la route** (`carte_monde.json`, 1 à 7), l'état et la fiabilité des véhicules (DEC-123), et en option la nuit, la réputation, la difficulté forcée (LOG-X2). Aucun chiffre n'est fixé.

## 9. Carte stratégique (LOG-N5)

La carte du Kit (`carte_kit.gd`) sert de base. Pour chaque convoi du joueur, afficher au minimum :

- **position** (icône sur la route, interpolée entre les deux lieux) ;
- **destination ou étape suivante** ;
- **itinéraire** (surligné) ;
- **progression** (pourcentage de l'étape et du circuit) ;
- **état général** (couleur et pictogramme) ;
- **incidents** (pastille).

Toucher un convoi ouvre sa **fiche** : véhicules, équipage, carburant, cargaison, incident, boutons d'action (suspendre, modifier, intervenir, envoyer du secours). Les sites du joueur apparaissent comme un calque distinct. Les positions restent **cohérentes avec les routes existantes** : on n'affiche jamais un convoi hors d'une route ou d'un lieu.

Le calque n'ajoute **rien** à `carte_monde.json` : positions et sites sont dans la sauvegarde.

## 10. Croisement avec ses propres convois (LOG-P3)

Le joueur peut croiser ses convois **à l'aller et au retour**. Le croisement n'est jamais tiré au hasard : il **découle de la simulation** (§8).

Règle : le convoi principal circule sur la route R de t0 à t1. Un convoi autonome est sur R dans le même intervalle.

- **Sens opposés** : rencontre si leurs positions s'inversent entre deux pas.
- **Même sens** : dépassement ou rattrapage si l'écart tombe sous `log.croisement.distance_m`.

À la rencontre, le convoi autonome est **instancié en scène** à partir de son enregistrement (mêmes véhicules, même état), au lieu d'un convoi générique. Le joueur peut alors :

- voir son état et le saluer (noyau de LOG-P3) ;
- appliquer les interactions prévues : voir la fiche, donner un ordre (suspendre, modifier) ;
- transférer des ressources ou des personnes (expérimental, LOG-X1).

**Compatibilité avec DEC-218.** Les convois alliés et hostiles tirés au hasard (14 % des rencontres) restent. Ils ne sont **jamais** un substitut d'un convoi du joueur : si un convoi du joueur est sur la route, c'est lui qui apparaît, sinon rien n'est inventé à sa place.

## 11. Pannes et interventions (LOG-P4 à LOG-P6)

### 11.1 Effets

| Gravité | Effet |
|---|---|
| Légère | convoi **ralenti** (`log.incident.facteur_ralenti`) |
| Grave | convoi **immobilisé** |
| Fatale | convoi **perdu** (voir risque §16 et OQ-044) |

Le joueur reçoit une **notification** et l'incident apparaît sur la carte. Un convoi immobilisé reste exposé (probabilité d'attaque à fixer) tant qu'il n'est pas secouru.

### 11.2 Option 1 — intervenir personnellement

Le joueur fait route avec son convoi principal vers la position du convoi immobilisé (voyage existant, DEC-218). À l'arrivée, on applique les règles de réparation existantes (halte de réparation, DEC-122, 161).

### 11.3 Option 2 — envoyer du secours

Depuis un site approprié, le joueur affecte une **équipe** (mécaniciens, pièces de rechange, ressources). L'équipe est modélisée comme un **convoi autonome de type secours** à trajet unique vers la position du convoi en panne : **pas de second moteur de simulation**. À son arrivée, un tirage déterministe détermine :

- réparé ;
- rafistolé (règle existante à 25 %) ;
- échec (nouvel envoi possible).

Entrent en compte : mécaniciens disponibles, pièces de rechange, ressources, distance, temps d'intervention. Pas de simulation détaillée du dépannage : la décision du joueur est stratégique (y aller ou envoyer quelqu'un).

### 11.4 Lisibilité

Chaque panne a un état visible sur la carte, un texte court (« Le convoi de Dol est immobilisé : essieu cassé ») et une conséquence compréhensible (« Secours en route, arrivée dans 6 h »).

## 12. Cargaison et échanges (LOG-P7)

Règle d'or : **simple**. À chaque étape, deux gestes : **déposer** et **prendre** la cargaison, plus l'échange **via le marché existant** de la ville (prix et réputation DEC-217). Pas de prix négociés ni de comptabilité par étape. Les types de cargaison reprennent ceux des missions du maire (`missions.json`).

Deux points à valider avant de coder : la **source** de la cargaison (stock déposé sur le site ou achat au marché) et l'existence de **stocks de ressources** dans les sites (OQ-042). Tant que ce n'est pas tranché, LOG-P7 reste désactivé.

Rappel : les **missions du maire** restent jouées par le convoi principal ; les convois autonomes ne les remplacent pas.

## 13. Données, identifiants et sauvegardes (LOG-N6)

### 13.1 Nouveaux identifiants persistants

`convoi_id`, `site_id`, `emplacement_id`, `circuit_id`, `incident_id`, `event_id`. Ils sont indépendants des libellés (DATA_CONTRACTS, Identifiants).

### 13.2 Écarts avec le code actuel (risque principal)

| Contrat | État réel (audit du 15/11) | Conséquence |
|---|---|---|
| `vehicle_instance_id` stable | les véhicules ont un `uid` **entier de session** (`_uid`) ; sa stabilité dans les sauvegardes **n'est pas vérifiée** | prérequis LOG-T2 : un identifiant stable et sauvegardé |
| `survivor_id` stable | les équipages sont des tableaux de points de vie et de noms **par véhicule** ; la réserve est un **compteur** (`reserve_survivants`) | affecter des personnes à un convoi autonome exige des identifiants ; DEC-180 (quelques personnages nommés, le reste générique par rôle) est la voie : **personnes nommées par ID, autres par compteurs de rôle** (LOG-T3, OQ-046) |
| Route identifiable | les routes de `carte_monde.json` n'ont **pas** d'identifiant, seulement `a` et `b` | LOG-T4 : identifier une route par la paire de lieux triée |
| Lieux stables | la carte va passer à 12 capitales avec lieux mineurs (DEC-240) | un convoi sur une route supprimée est replacé sur son lieu le plus proche à la migration ; l'identifiant `kerbrume` est déjà conservé (DEC-238) |

### 13.3 Affectations exclusives

Une table unique `affectations` associe chaque `vehicle_instance_id` et chaque personne à **un** usage : `principal`, `convoi:<id>`, `site:<id>:<emplacement>`, `reparation:<id>`. Toute transition libère l'ancienne affectation et réserve la nouvelle **dans la même opération**.

### 13.4 Sauvegarde

- Nouveau bloc `logistique` avec sa propre `version` (1) dans la sauvegarde existante ; le bloc `monde.carte` vaut déjà 2.
- **Migration** : une ancienne sauvegarde reçoit un bloc `logistique` vide (aucun site, aucun convoi). Rien ne casse.
- Test de migration obligatoire sur copie (DATA_CONTRACTS, Versionnage).
- Désactiver un module (§15) ne détruit pas ses données : elles sont ignorées et conservées.

## 14. Interface iPhone

- Trois écrans de création au plus, une action par écran, gros textes (DEC-208 et feedback du créateur).
- La carte est le tableau de bord : un toucher sur un convoi ouvre sa fiche, un second sur une action.
- Notifications d'incident courtes, sans fenêtre bloquante pendant le combat.
- Aucun écran de gestion tabulaire, aucune file de construction.

## 15. Modularité

| Module (`log.module.*`) | Dépend de | Désactivé : effet |
|---|---|---|
| `stockage` | — | plus de sites ; tout le reste s'éteint |
| `convois` | `stockage` | plus de lancement |
| `carte` | `convois` | convois invisibles sur la carte (simulation continue) |
| `circuit` | `convois` | trajet unique seulement |
| `camps` | `stockage` | villes alliées seulement |
| `croisement` | `convois`, `carte` | pas de rencontre en scène |
| `pannes` | `convois` | aucun incident |
| `secours` | `pannes`, `convois` | intervention personnelle seulement |
| `cargaison` | `convois` | convois sans chargement |

Chaque module expose une interface étroite (liste, création, état, événements) et ne lit pas les structures internes des autres. Retirer un module doit se faire en coupant son interrupteur puis en supprimant son dossier, sans reconstruire les autres.

## 16. Risques

1. **Identifiants** des véhicules et des personnes (§13.2) : le plus gros risque technique.
2. **Horloge** : si elle est figée dans certains états (ville, atelier, Kit), les convois s'arrêtent ; à vérifier.
3. **Cohérence des distances** carte / scène (§8.2).
4. **Perte d'un convoi** : le lore dit que « les convois qui disparaissent ne sont jamais retrouvés » (Bible, section sur la rumeur) et le jeu retient « on ne revoit jamais ceux qui s'éloignent » (`LORE.md`). Proposition : ce principe vaut pour ce qui est **perdu ou abandonné**, pas pour un réseau organisé et suivi par le joueur ; un convoi perdu n'est jamais retrouvé, ce qui rend le risque réel. **À valider** (OQ-044). La Bible n'est pas modifiée.
5. **Dérive vers la gestion de base** : garder les sites sans bâtiments ni production.
6. **Équilibrage** : tous les paramètres sont ouverts.

## 17. Questions ouvertes

Voir [`../OPEN_QUESTIONS.md`](../OPEN_QUESTIONS.md) : OQ-041 (paramètres), OQ-042 (sites, camps, ressources, cargaison), OQ-043 (villes alliées), OQ-044 (pannes, pertes, principe lore), OQ-045 (temps, hors ligne), OQ-046 (personnel), OQ-047 (direction artistique).

## 18. Tâches

Conception et développement : [`../TASKS.md`](../TASKS.md), identifiants `DOC-007`, `DOC-008` et `DEV-044` à `DEV-052`. Prérequis techniques : LOG-T1 (distances), LOG-T2 (id véhicules), LOG-T3 (id personnes), LOG-T4 (id routes).
