# Transmission, accélération et son moteur — Folie Mécanique

Statut : **codé et validé** (DEC-234, 11/11) ; **limites levées le 25/11 (DEC-261)** : sauts réels sur des crêtes du relief, balancement et poussée des remorques, basculement au freinage. Lot de code : DEV-042 (fait).

## Constat

`combat_modele.gd` fixe la vitesse du convoi à sa cible d'un coup (`vit = vmax`), la pente ne fait que multiplier cette cible, et un obstacle ou l'ordre de halte arrêtent net. Le son du moteur est une boucle de volume constant (véhicule le plus lourd), silencieuse à l'arrêt.

## Décisions (DEC-232)

- **Inertie** : la vitesse du convoi devient un état. Accélération = rapport puissance/poids du véhicule le plus faible du convoi (remorques et surcharge comprises) ; freinage limité (arrêt depuis la vitesse max en 2 à 3 s). Un obstacle ou un ennemi devant oblige à freiner à l'avance, sinon choc ou éperonnage.
- **Boîte automatique, gérée par l'équipage** : 4 ou 5 rapports par véhicule, avec une plage de vitesse par rapport, déduits de `puissance_ch`, poids et vitesse max existants (aucune saisie par véhicule). Chaque passage coupe la traction environ 0,4 s. En côte : rétrogradation et vitesse tenable par le rapport inférieur. En descente : frein moteur.
- **Deux départs** : *calme* (aucun ennemi) = passages tôt, montée lente, économe ; *urgence* = pied au plancher, rapports tenus haut, accélération nettement plus forte, consommation en hausse. **Déclenchement automatique** dès qu'un ennemi est en vue ou en approche.
- **Son** : boucles moteur existantes à hauteur variable selon le régime, ralenti à l'arrêt, démarreur, petit à-coup à chaque passage. Aucun nouveau son généré pour ce lot (pas de crédits ElevenLabs).
- **Affichage** : petit indicateur discret (rapport, compte-tours) dans le HUD du convoi ; lecture détaillée (rapport, régime, accélération) dans le panneau du Kit.

## Extension du lot (DEC-233) : freinage, tenue de route et convoi

Thèmes retenus le 11/11 : **freinage et tenue**, **convoi**. Thèmes proposés mais **non retenus pour ce lot** (à reprendre plus tard) : moteur (courbe de couple, surchauffe avec radiateurs, moteur et boîte abîmés, calage, grand froid) ; mécanique de la grille (roues motrices, différentiel, traînée, consommation selon régime).

- **Freinage selon le sol** : distance d'arrêt allongée sur sable et boue, glissade sur neige (adhérence des pneus, DEC-231).
- **Virages et demi-tours** : ralentissement dans les virages ; un demi-tour à pleine vitesse fait déraper.
- **Transfert de charge et renversement** : un freinage brusque ou une pente raide déleste l'avant ou l'arrière ; risque de renversement si le centre de gravité est haut (assiette et centre de gravité déjà calculés par la grille).
- **Sauts** : un véhicule rapide décolle sur une crête ; l'atterrissage secoue l'équipage et use la suspension.
- **Départ échelonné et effet accordéon** : les véhicules démarrent l'un après l'autre, l'écart s'allonge et se resserre, un freinage brusque peut provoquer un tamponnement.
- **Remorques** : inertie propre, poussée en descente, balancement au virage.
- **Dégagement des enlisés** : treuil ou remorquage par un autre véhicule, à la place du dégagement automatique de DEC-231 (réponse à OQ-037, détail à fixer au codage).

## Conséquences à traiter au codage

Distances parcourues en baisse : équilibrage du combat à revoir (DEC-113, 229). Interaction avec la physique des pneus (DEC-231 : adhérence → accélération tenable, enlisement). Départ échelonné des véhicules et effet d'accordéon : plus tard.

## Ouvert

Valeurs des rapports et du freinage à régler en essai sur iPhone ; rôle du bruit moteur sur l'attention des ennemis (non décidé).

## Complément du 25/11 (DEC-261)

- **Crêtes** : `Terrain.crete(x)`, bosses isolées (rampe douce, lèvre, retombée), fréquence selon le sol (bloc `cretes` de `transmission.json`). `Terrain.route(x)` = relief sans les crêtes (pente ressentie, caméra).
- **Sauts** : `CombatModele._vols` (sous-pas), `hauteur_vol(v)`, événement `atterrit` ; dessin dans `convoi_vue.gd` et `VehiculeDessin.atterrir`.
- **Remorques** : `_balancer_remorques` (`modele_voies.gd`), poussée en descente dans `_params_conduite`.
- **Basculement** : `Transmission.bascule`, section 5 de `_tenue`, événement `bascule`, `VehiculeDessin.basculer`.
- **Reste ouvert** : bruit moteur et attention des ennemis ; thèmes reportés de DEC-233 (couple, surchauffe, calage, grand froid, roues motrices, différentiel).
