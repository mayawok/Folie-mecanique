# Pipeline artistique et textures --- v1.0

## Objectif

Permettre à une équipe artistique de travailler sur les textures et aux
développeurs d'intégrer ou remplacer les ressources sans relire la
logique du jeu.

## Registre des assets

Chaque asset possède un `asset_id` stable, un type, un module
propriétaire, un chemin, un format, des dimensions, des variantes, un
statut, une source/licence et une liste de consommateurs.

## Règles

-   Les textures ne contiennent jamais de règles de gameplay.
-   Les chemins d'assets ne doivent pas être dispersés dans les règles
    métier.
-   Les références passent par un registre/identifiant logique adapté au
    moteur.
-   Toute suppression ou renommage met à jour le registre et toutes les
    références.
-   Les sources éditables sont conservées séparément des exports
    optimisés, si la licence le permet.
-   Les variantes visuelles (normal, endommagé, nuit, neige/poussière)
    doivent partager une convention stable.
-   Les contraintes exactes de texture, atlas, compression et import
    seront fixées après audit du moteur choisi.

## Colonnes recommandées pour `asset-register.csv`

`asset_id,type,module,path,format,width,height,variants,status,source_license,consumers,notes`

## Critères de validation

Un asset est prêt si ses dimensions/format sont conformes au pipeline,
son ID est unique, sa licence est documentée, ses variantes sont listées
et tous les consommateurs le référencent par le mécanisme convenu.
