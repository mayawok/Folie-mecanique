# Missions du maire — Folie Mécanique

Statut : **transport de cargaison codé le 08/11 (DEC-144 à DEC-147)**. Code : `game/scripts/combat/modele_mission.gd` (logique),
`mission_dessin.gd` (scènes), `ville_dessin.gd` (maire) ; données : `game/data/missions.json` ; musique : `tools/synth_tambours.py` →
`game/assets/audio/mus_tambours.wav` ; test : `game/tests/test_mission.gd` ; captures : `game/tests/capture_mission.gd`.

## Déroulé

1. **Mairie** : le maire propose ses missions (Kit : toutes ; expédition : deux par ville). Chaque offre dit la cargaison, la destination
   (ville du secteur voisin le plus proche, une seule étape, sans détour), les ennemis de la route, l'escorte donnée et la récompense.
2. **Atelier** (8 s) : le Berliet est dans l'atelier ; le pont roulant descend la cargaison sur le plateau.
3. **Rassemblement** (11 s) : sur la place, l'escorte (2 side-cars armés, une Jeep, une Traction à mitrailleuse) entoure le camion.
   Ses hommes, peints à la craie, crient (« HOURRA ! », « EN ROUTE ! »…) et lèvent leurs armes ; un joueur de tambour sur la Jeep.
   Tambours de guerre. Le maire : « Bonne chance. » La porte s'ouvre.
4. **Départ automatique** vers la destination (pas de choix de sortie). Bandes noires, sous-titres et fondus pendant les scènes ; aucun ordre possible.
5. **Route** : motos en chasse à 30 % de l'étape, voiture armée et motos en travers à 70 %. La ville de destination est 250 m après l'entrée du secteur.
6. **Livraison** à l'arrivée dans la ville, Berliet en état : récompense, cargaison déchargée, l'escorte reste dans la ville.
   **Échec** si le Berliet est hors d'usage ou en cas de demi-tour.

## Cargaisons

| Type | Sur le Berliet | Récompense |
|---|---|---|
| Carburant | citerne vert olive, bande jaune « GAZOLE » | 150 L, 60 munitions, 20 métal, 1 pièce |
| Eau potable | **citerne gris-bleu, bande bleue « EAU POTABLE »** | 40 eau, 10 vivres, 25 métal, 1 pièce |
| Vivres | ridelles hautes (cageots) | 30 vivres, 60 L, 40 munitions |
| Munitions | caisses olive au pochoir jaune, sanglées | 220 munitions, 15 métal, 1 pièce |
| Pièces détachées | benne | 60 métal, 40 L, 3 pièces |

Valeurs provisoires, à régler en essai. Ajouter un type, changer l'escorte, les vagues ou les récompenses : `missions.json`, sans code.

## Ouvert (OQ-027)

Eau et vivres : comptés mais ni affichés ni consommés (rations retirées le 07/11) ; garder l'escorte ? cargaison abîmée par les tirs ?
nombre de missions en expédition ; escortes et vagues selon le niveau ; voix du maire (DEV-026).
