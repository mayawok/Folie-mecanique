# Contrats de données et frontières --- v1.0

## Unités canoniques

-   Nourriture : unité de stock abstraite, avec définition dans
    l'équilibrage.
-   Eau : litres.
-   Carburant : litres, un seul stock partagé `stocks.fuel`.
-   Durées de simulation : heures/jours de jeu explicites, jamais
    confondues avec le temps réel.
-   Santé/condition des composants : pourcentage 0--100.
-   Réputation, confiance, menace, peur, moral : échelles documentées
    séparément, sans réutiliser le même champ.

## Identifiants

-   `vehicle_def_id` : définition du catalogue, stable.
-   `vehicle_instance_id` : exemplaire possédé, stable.
-   `building_def_id` / `building_instance_id` : définition et instance
    séparées.
-   `survivor_id`, `faction_id`, `expedition_id`, `event_id`, `asset_id`
    : IDs stables et uniques.
-   Les libellés et indices de tableau ne sont jamais des IDs
    persistants.

## Principes transactionnels

Une transaction vérifie les préconditions, réserve/débite toutes les
ressources, applique les effets et confirme atomiquement. Si une
précondition échoue, aucune partie de la transaction ne doit être
appliquée.

## Événements

Tout événement persistant porte un `event_id` unique. La réception
répétée du même ID ne doit pas doubler ses effets. Les événements
aléatoires enregistrent une graine ou un résultat reproductible.

## Affectations exclusives

Un survivant, un véhicule, un équipage ou une arme ne peut être affecté
simultanément à plusieurs emplacements incompatibles. Une transition
doit libérer l'affectation précédente et réserver la nouvelle dans la
même opération.

## Séparation définition / instance

Les définitions de catalogue contiennent des données génériques et
relativement stables. Les instances contiennent l'état évolutif :
dégâts, propriétaire, emplacement, modifications, équipage et
historique.

## Versionnage

Toute modification incompatible d'un schéma incrémente sa version et
fournit une migration. Les sauvegardes antérieures doivent être testées
sur une copie avant validation de la migration.
