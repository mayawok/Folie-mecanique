# Instructions aux agents de développement --- v1.0

## Avant toute modification

1.  Lire ce fichier, puis `docs/INDEX.md`.
2.  Lire uniquement la tâche assignée, le contrat de données concerné et
    les fichiers du module propriétaire.
3.  Confirmer que les chemins mentionnés existent. Ne pas inventer
    l'état du dépôt.
4.  Si le dépôt réel ne correspond pas à l'architecture documentaire,
    signaler l'écart avant de refactorer.

## Périmètre

-   Ne modifier que le module et les fichiers autorisés par la tâche.
-   Ne pas réécrire des modules non concernés « par propreté ».
-   Ne pas changer les contrats partagés, IDs persistants, unités ou
    formats de sauvegarde sans tâche explicite.
-   Si une modification transverse est indispensable, arrêter et
    proposer une tâche de contrat distincte.

## Qualité

-   Écrire des tests adaptés au changement.
-   Exécuter réellement les tests disponibles et rapporter les résultats
    exacts.
-   Ne jamais affirmer qu'une compilation, un test ou une validation a
    réussi sans l'avoir exécuté.
-   Éviter les dépendances nouvelles sans justification.
-   Toute logique métier doit résider dans son module, pas dans
    l'interface.
-   Toute opération de ressources doit être atomique.
-   Les événements rejouables doivent être idempotents.
-   Les simulations aléatoires doivent utiliser une graine explicite et
    reproductible.

## Données et sauvegardes

-   Les IDs persistants sont stables et indépendants des libellés
    affichés.
-   Toute évolution de schéma inclut une migration et un test.
-   Ne pas supprimer ou renommer un champ persisté sans plan de
    migration.
-   Ne jamais affecter le même survivant, véhicule ou équipage à deux
    usages incompatibles.
-   `stocks.fuel` est le stock commun de carburant, mesuré en litres.

## Textures et assets

-   Ne pas modifier une texture sans mettre à jour le registre d'assets.
-   Ne pas encoder les règles de gameplay dans les textures ou noms de
    fichiers.
-   Vérifier droits, formats, résolution, variantes et modules
    consommateurs.
-   Ne pas déplacer ou renommer des assets référencés sans mise à jour
    du registre et recherche des références.

## Livraison

À la fin, fournir un compte rendu conforme au modèle de `docs/TASKS.md`.
Signaler explicitement ce qui n'a pas été testé, les risques et les
tâches suivantes.
