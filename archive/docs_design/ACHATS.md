# Achats intégrés — Folie Mécanique

Statut : validé (thème 3, DEC-012). Distingue ce qui est **décidé** de ce qui reste **ouvert**.

## Principe

On vend du **confort** et de l'**identité**, jamais de la **puissance** ni de la **rareté**.
La rareté est la difficulté centrale : aucun achat ne doit la contourner.

## Garde-fou (règle canonique `monetization.guardrails`)

Aucun achat ne peut :

- donner des ressources (eau, nourriture, carburant, matériaux, munitions) ;
- donner, débloquer ou améliorer un véhicule, un bâtiment ou une défense ;
- modifier le combat, les expéditions, les événements ou la faune ;
- modifier les planchers d'absence, la pénurie ou ses conséquences ;
- accélérer une expédition, une réparation sous attaque ou une sortie de pénurie.

Toute proposition d'achat future est vérifiée contre cette liste avant d'entrer au backlog.

## Offre décidée

| Offre | Type | Contenu |
|---|---|---|
| Abonnement « Commandant » | Récurrent | 2ᵉ file de chantier, ordres permanents avancés, rapport du matin détaillé, alertes fines |
| Cosmétiques | À l'unité | Peintures, camouflages, emblèmes, décorations de véhicules et de base |
| Pack fondateur | Achat unique | Cosmétiques exclusifs, 1 emplacement de convoi en plus, chronique narrative inédite |
| Accélérateur de chantier | À l'unité, limité | 1 par jour maximum, chantiers de construction uniquement |

Notes :

- La 2ᵉ file de chantier et l'emplacement de convoi en plus ne créent pas de ressources :
  ils consomment les mêmes stocks. À vérifier en simulation (profil abonné) pour confirmer
  que la tension n'est pas réduite.
- L'accélérateur est exclu des expéditions, réparations, soins et pénuries.

## Paiement

- **Pas de monnaie premium.** Prix affichés directement en euros via l'App Store.
- **Pas de coffres aléatoires** ni de contenu à probabilité.
- Pas de publicité (DEC-004).

## Ouvert

- Prix de chaque offre.
- Gain exact de l'accélérateur (durée retirée ou pourcentage).
- Contenu précis des ordres permanents avancés : ne doit pas rendre l'abonné
  significativement plus efficace en combat ou en expédition.
- Catalogue cosmétique de lancement (dépend du thème 6, direction artistique).
- Simulation : ajouter un profil « abonné » pour mesurer l'effet de la 2ᵉ file.
