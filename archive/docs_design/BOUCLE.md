# Boucle de jeu — Folie Mécanique

Statut : en revue (thème 2). Distingue ce qui est **décidé** de ce qui reste **ouvert**.

## Décidé

### Temps

- **1 jour de jeu = 1 jour réel.** Le monde avance en continu, joueur connecté ou non.
- **2 à 3 connexions par jour** visées, de quelques minutes chacune.

### Journée type

| Moment | Rôle |
|---|---|
| Matin | Rapport de nuit : attaques, retours d'expédition, état des stocks. Planification de la journée. |
| Midi (facultatif) | Réaffectation des travailleurs, relance des chantiers terminés. |
| Soir | Préparation de la nuit : expéditions programmées, défenses. |

### Session courte (≈ 5 min)

Récolter → décider → lancer → partir. Récupérer les retours et le butin, lire les stocks
et les jours d'autonomie restants, réaffecter, lancer constructions, améliorations de cuves,
démantèlements et expéditions. Chaque action dure en temps réel.

### Départ programmé des expéditions

- Le convoi est composé et chargé, puis mis **en attente** avec une heure de départ
  (ex. le soir, pour voyager de nuit).
- Carburant et vivres sont **réservés dès la préparation**.
- Annulation possible avec restitution intégrale tant que le convoi n'est pas parti.

### Absence du joueur

- La consommation **continue** en l'absence du joueur.
- Elle **ralentit puis s'arrête à des planchers** : un joueur absent un à trois jours
  retrouve une communauté affaiblie, jamais anéantie.
- Principe : **rien d'irréversible ne doit exiger le joueur pendant son sommeil**.
  La nuit, les ordres permanents s'appliquent ; le rapport du matin raconte la suite.

### Pénurie : conséquences graduées

1. Baisse de **productivité** des travailleurs.
2. **Maladies** : travailleurs indisponibles temporairement.
3. **Agitation** : certains travailleurs se révoltent ou tentent de fuir.
   Le joueur décide du sort des révoltés (dont l'exécution) ; les fuyards peuvent
   être perdus.
4. Pas de défaite sèche liée à la pénurie.

Ces étapes s'appuient sur le moral existant (`morale`, `morale_delta` dans
`data/rules/regles_canoniques.json`).

### Boucle longue (≈ 1 mois)

Progression vers le Tiger I : déblocage des véhicules un par un, paliers de base
(cuves, ateliers, défenses), extension de la carte vers des villes plus riches et mieux
défendues, puis les sièges. Le danger augmente avec la progression pour que la rareté
ne disparaisse jamais.

## Ouvert

- **Jour / nuit** (proposition, à valider) :

  | | Jour | Nuit |
  |---|---|---|
  | Désert | Chaleur, surconsommation d'eau | Consommation normale |
  | Neige | Normal | Froid, surconsommation de carburant |
  | Pillards | Fréquents | Rares |
  | Faune | Moins active | Plus active et dangereuse |
  | Base | Défendue par les travailleurs | Défenses automatiques seules |

- **Valeurs des planchers** par ressource et vitesse de ralentissement.
- **Seuils** de déclenchement de chaque étape de pénurie, et retour à la normale.
- **Heure de référence** de la consommation quotidienne (fixe ou continue).
- Aide au joueur en retour d'absence longue (au-delà de 3 jours).

## Impact sur la simulation 30 jours

La simulation doit modéliser : le cycle jour/nuit, les planchers d'absence, un profil
« joueur absent » (1 à 3 jours sans connexion) et les étapes de pénurie. Ces éléments
sont les leviers pour corriger le constat d'absence de tension (voir `STATE.md`).
