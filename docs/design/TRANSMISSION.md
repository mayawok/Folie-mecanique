# Transmission, accélération et son moteur — Folie Mécanique

Statut : **conception décidée le 11/11 (DEC-232), pas encore codée.** Lot de code : DEV-042.

## Constat

`combat_modele.gd` fixe la vitesse du convoi à sa cible d'un coup (`vit = vmax`), la pente ne fait que multiplier cette cible, et un obstacle ou l'ordre de halte arrêtent net. Le son du moteur est une boucle de volume constant (véhicule le plus lourd), silencieuse à l'arrêt.

## Décisions (DEC-232)

- **Inertie** : la vitesse du convoi devient un état. Accélération = rapport puissance/poids du véhicule le plus faible du convoi (remorques et surcharge comprises) ; freinage limité (arrêt depuis la vitesse max en 2 à 3 s). Un obstacle ou un ennemi devant oblige à freiner à l'avance, sinon choc ou éperonnage.
- **Boîte automatique, gérée par l'équipage** : 4 ou 5 rapports par véhicule, avec une plage de vitesse par rapport, déduits de `puissance_ch`, poids et vitesse max existants (aucune saisie par véhicule). Chaque passage coupe la traction environ 0,4 s. En côte : rétrogradation et vitesse tenable par le rapport inférieur. En descente : frein moteur.
- **Deux départs** : *calme* (aucun ennemi) = passages tôt, montée lente, économe ; *urgence* = pied au plancher, rapports tenus haut, accélération nettement plus forte, consommation en hausse. **Déclenchement automatique** dès qu'un ennemi est en vue ou en approche.
- **Son** : boucles moteur existantes à hauteur variable selon le régime, ralenti à l'arrêt, démarreur, petit à-coup à chaque passage. Aucun nouveau son généré pour ce lot (pas de crédits ElevenLabs).
- **Affichage** : petit indicateur discret (rapport, compte-tours) dans le HUD du convoi ; lecture détaillée (rapport, régime, accélération) dans le panneau du Kit.

## Conséquences à traiter au codage

Distances parcourues en baisse : équilibrage du combat à revoir (DEC-113, 229). Interaction avec la physique des pneus (DEC-231 : adhérence → accélération tenable, enlisement). Départ échelonné des véhicules et effet d'accordéon : plus tard.

## Ouvert

Valeurs des rapports et du freinage à régler en essai sur iPhone ; rôle du bruit moteur sur l'attention des ennemis (non décidé).
