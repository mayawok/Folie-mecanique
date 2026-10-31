**Équilibrage général et feuille de route**

*Jeu iPhone post-apocalyptique • 29 octobre 2026 • Version 1.0*

Statut : conception et données uniquement. Aucun prototype jouable n'est inclus dans ce livrable.

# 1. Décisions structurantes

- Le jeu reste un jeu 2D paysage sur iPhone, centré sur la base, les expéditions, la récupération de véhicules, la construction modulaire, les factions et les choix à conséquences.

- Le réalisme mécanique est semi-réaliste : les composants qui changent les décisions sont modélisés; les micro-pièces sans intérêt de gameplay sont abstraites.

- Le carburant est un stock unique en litres. Le type de carburant reste une propriété du moteur et intervient dans compatibilité, consommation et performances.

- Les sauvegardes sont versionnées et migrables. Les transactions multi-systèmes sont atomiques et les événements idempotents.

- La progression hors ligne est plafonnée à 12 heures. Le retour présente un bilan; pas de mort ni de destruction majeure silencieuse.

- Les données de véhicules doivent être assez complètes pour le jeu. Les valeurs probables sont préférées aux champs vides, mais elles sont marquées comme estimations lorsqu'elles ne sont pas solidement établies.

# 2. Captivité : règles chiffrées de départ

Les valeurs ci-dessous sont des hypothèses de balance, non des données historiques. Elles devront être ajustées après validation de la boucle de jeu.

| Installation        | Capacité | Construction | Coût initial                                       | Consommation/captif/jour | Gardes           | Risque quotidien indicatif  |
|---------------------|----------|--------------|----------------------------------------------------|--------------------------|------------------|-----------------------------|
| Enclos improvisé    | 4        | 1 jour       | 45 ferraille, 30 bois, 10 métal                    | 1 nourriture + 4 L d'eau | 1 pour 4 captifs | 5 % évasion; 6 % incident   |
| Cellules renforcées | 8        | 3 jours      | 90 ferraille, 20 bois, 55 métal, 5 électronique    | 1 nourriture + 4 L d'eau | 1 pour 4 captifs | 2,5 % évasion; 3 % incident |
| Quartier sécurisé   | 16       | 6 jours      | 150 ferraille, 20 bois, 110 métal, 15 électronique | 1 nourriture + 4 L d'eau | 1 pour 4 captifs | 1 % évasion; 1,5 % incident |

Les risques sont des valeurs de départ par jour et par installation. La surpopulation, le manque de gardes, le manque de nourriture/eau et le moral bas les augmentent. Les améliorations réduisent les risques, sans les supprimer.

## 2.1 Choix de capture et conséquences

| Action                       | Moral de base     | Réputation locale | Menace            | Effet durable                                                               |
|------------------------------|-------------------|-------------------|-------------------|-----------------------------------------------------------------------------|
| Capturer un survivant ennemi | -4 par captif     | -3 par captif     | +3 par captif     | Risque de vengeance de la faction et de raid de libération.                 |
| Rafler un village pacifique  | -12 par événement | -15 par événement | +12 par événement | Rupture de confiance; risque de coalition, refus de commerce et embuscades. |
| Négocier / troquer           | 0                 | +2                | 0                 | Maintient des voies d'échange et peut ouvrir des informations.              |
| Libérer les captifs          | +3                | +5                | -2                | Réduit le risque de représailles et peut améliorer les relations.           |
| Recrutement volontaire       | +2                | +2                | 0                 | Nécessite logement, provisions et acceptation du survivant.                 |

## 2.2 Travail forcé : rendement et limites

Rendement provisoire par captif affecté et par jour : 2 ferrailles, 1 bois ou 0,5 métal selon la tâche. Un captif ne produit pas dans toutes les filières simultanément. La production exige surveillance, nourriture, eau et capacité de travail disponible. Les incidents, sabotages et tentatives d'évasion augmentent si la sécurité ou les provisions sont insuffisantes. Les captifs ne peuvent jamais être affectés à la garde, aux armes fixes ou aux expéditions.

## 2.3 Réputation

| Score      | Étiquette        | Conséquences indicatives                                                         |
|------------|------------------|----------------------------------------------------------------------------------|
| +60 à +100 | Respecté         | Meilleurs échanges, davantage d'aide et de renseignements.                       |
| +20 à +59  | Toléré           | Relations généralement favorables.                                               |
| -19 à +19  | Neutre           | Pas de modificateur global.                                                      |
| -20 à -59  | Craint / hostile | Prix plus élevés, informations plus rares, patrouilles hostiles plus fréquentes. |
| -60 à -100 | Paria / terreur  | Coalitions, sanctions commerciales et raids de représailles plus probables.      |

# 3. Fortifications et défense de base

| Élément                      | Valeurs de départ                                                                 | Règle de gameplay                                                      |
|------------------------------|-----------------------------------------------------------------------------------|------------------------------------------------------------------------|
| Grande porte gauche / droite | Chaque porte : niveaux 1/2/3 à 500/850/1300 PV; coûts progressifs dans le tableur | Portes indépendantes; état ouvert/fermé, réparation et brèche séparés. |
| Segment de mur               | Niveaux à 300/550/900 PV                                                          | Les dégâts sont localisés; un segment détruit crée une brèche.         |
| Tour de guet                 | 55 ferraille, 25 bois, 10 métal; 2 gardes                                         | Améliore détection et couverture de tir.                               |
| Bunker                       | 80 ferraille, 60 métal; 2 gardes                                                  | Réduit l'exposition des défenseurs.                                    |
| Éclairage                    | 15 ferraille, 8 électronique; 2 énergie par nuit                                  | Améliore détection nocturne; dépend de l'énergie.                      |
| Mitrailleuse lourde fixe     | 70 ferraille, 35 métal, 5 électronique; 2 servants; 40 munitions/attaque          | Bonne cadence et consommation élevée.                                  |
| Canon de défense             | 100 ferraille, 80 métal, 8 électronique; 3 servants; 12 munitions/attaque         | Efficace contre véhicules et brèches; lent et coûteux.                 |
| Mortier                      | 90 ferraille, 55 métal, 10 électronique; 3 servants; 8 munitions/attaque          | Tir indirect; efficacité réduite à courte portée.                      |

Les véhicules stationnés à l'extérieur (voiture blindée, semi-chenillé, char ou camion armé) exigent un emplacement, un équipage, du carburant et des munitions. Ils ne peuvent pas partir en expédition simultanément. Une défense statique est puissante mais immobilise du matériel et peut subir immobilisation ou perte si le secteur tombe.

# 4. Économie, expéditions et sauvegardes

## 4.1 Économie de référence

| Indicateur      | Valeur de départ       | Règle                                                                                        |
|-----------------|------------------------|----------------------------------------------------------------------------------------------|
| Nourriture      | 1 unité/personne/jour  | Les besoins sont calculés à partir de la population réellement hébergée.                     |
| Eau             | 5 L/personne/jour      | Les captifs consomment 4 L supplémentaires par captif et par jour.                           |
| Alerte stocks   | 2 jours d'autonomie    | Avertissement de pénurie selon consommation prévisionnelle.                                  |
| Alerte critique | 1 jour d'autonomie     | Proposer rationnement, production ou expédition prioritaire.                                 |
| Carburant       | Stock unique en litres | Consommation déterminée par moteur, masse, terrain et état; type moteur non interchangeable. |

## 4.2 Rapport obligatoire d'expédition

Chaque retour affiche le temps écoulé, la distance, le carburant, les provisions, les munitions, les dégâts par composant, les blessures, le butin, les changements de réputation et le risque de la prochaine étape. Le repli est une décision disponible sauf immobilisation ou piège; dans ces cas, une option de dépannage ou de sauvetage doit exister.

## 4.3 Sauvegarde

Les transactions qui touchent simultanément les stocks, les équipages, les véhicules et la réputation doivent être atomiques. Les événements ont un identifiant stable et ne peuvent s'appliquer deux fois après rechargement. Toute évolution de schéma doit avoir une migration. Le calcul hors ligne s'arrête au plafond de 12 heures et affiche les effets avant toute décision sensible.

# 5. Politique de données véhicules : « au plus probable »

- Grade A — donnée solide : source technique identifiable et variante claire.

- Grade B — valeur typique largement établie; variantes possibles.

- Grade C — estimation plausible; marge indicative d'environ ±10 à 20 % selon la donnée.

- Grade D — valeur de secours orientée gameplay; ne pas présenter comme caractéristique constructeur exacte.

Règle pratique : conserver les chiffres exacts lorsqu'ils sont connus, arrondir les estimations, préférer une fiche complète mais explicitement incertaine à une fiche inutilisable. Les dimensions, masses, puissances et autonomies des prototypes ou variantes rares doivent être les premières à porter le grade C/D. La précision du gameplay doit être stable même si la précision historique est approximative.

# 6. Chantiers suivants

| Priorité | Chantier                | Livrable de conception                                                 | Critère d'acceptation                                                                      |
|----------|-------------------------|------------------------------------------------------------------------|--------------------------------------------------------------------------------------------|
| P0       | Données véhicules       | Catalogue complété, grades de confiance, valeurs gameplay arrondies    | Aucun champ clé ne bloque la génération d'une fiche; estimations visibles dans le tableur. |
| P0       | Ressources et bâtiments | Table d'entrées/sorties, stockage, effectifs, maintenance              | Aucun bâtiment ne produit gratuitement; coûts et rendements sont explicites.               |
| P0       | Expéditions tactiques   | Phases, décisions, blessures, munitions, retraite et rapport           | Chaque risque majeur est annoncé; les conséquences sont journalisées.                      |
| P0       | Persistance             | Contrats d'objets, migrations, idempotence et transactions atomiques   | Rechargement ne duplique ni butin ni dépenses.                                             |
| P1       | Factions et réputation  | Seuils, réactions, commerce, rumeurs et représailles                   | Les actions de coercition affectent réellement l'accès au monde.                           |
| P1       | Progression de base     | Niveaux, ascenseur, étages souterrains, énergie, ventilation, drainage | La croissance verticale a des coûts et des risques spécifiques.                            |

Ordre recommandé : données véhicules et ressources/bâtiments, puis expéditions/persistance, puis factions et progression. Aucun prototype n'est créé dans cette phase.
