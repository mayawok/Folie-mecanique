# Écarts entre la Bible et le prototype — 2026-11-07

Statut : **tranché le 07/11, toutes les recommandations retenues (DEC-109, OQ-022 résolue)**. Les tâches de code sont DEV-006 à DEV-009. Référence : Bible (`docs/lore/01_BIBLE_FOUNDATION`, DEC-091).
Méthode : Bible relue (01.3, 03.3, 04.1 bis/ter/quater, 04.6, 05, 09.3) puis comparée au contenu de `docs/design/CONVOI.md` et de `docs/design/GRILLE.md`.
Seule la grille est conservée d'office (DEC-092) ; tout le reste est à garder, adapter ou supprimer, élément par élément.

## A. Écarts déjà connus (tâches existantes, pas de nouvelle décision)

| # | Prototype | Bible | Suite |
|---|---|---|---|
| E1 | Un seul stock « carburant » | Essence et gazole (04.6, DEC-094) | DEV-001 |
| E2 | Factions 1/2/3, relations fixes (1 alliée, 2 neutre, 3 hostile) | 5 factions FAC-001 à 005, aucune bonne ou mauvaise, relations changeantes (05, DEC-098) | DEV-002, bloqué par OQ-010 |
| E3 | Ouverture : caisse de pièces, moto, side-car | Convoi existant avec un camion (DEC-100) | DEV-003, bloqué par OQ-006 à 008 |

## B. Écarts nouveaux, à trancher

| # | Prototype | Bible | Options | Recommandation |
|---|---|---|---|---|
| E4 | **Tempêtes de sable** partout, toutes les 240 à 420 s, surtout le jour | Seulement dans les parties désertiques du no man's land (04.1 bis) | Garder / limiter aux zones désertes et rarifier / supprimer | Limiter : zone « désert » de la carte, rare ; mécanique gardée |
| E5 | **Loups et chiens** en meutes, plus fréquents la nuit ; rôdeurs de nuit | Animaux rares, dangereux rares, « pas de loups toutes les nuits » ; un oiseau est un événement (04.1 bis, DEC-097) | Adapter les fréquences / événement rare | Adapter (DEV-004) ; ajouter l'oiseau comme événement valorisé |
| E6 | **Chien démineur** trouvé en ferme, chez un réfugié ou un voyageur | Animaux rares ; chaque animal vivant est remarquable | Garder comme trouvaille rare / supprimer | Garder, très rare (devient un moment fort) |
| E7 | **Zone calme** (250 m + 900 m par unité de distance) entre secteurs, danger croissant avec la distance | Le no man's land entre les zones est dangereux et porte l'essentiel des combats (04.1 ter, DEC-095) | Inverser : calme dans les zones habitées, danger entre elles / garder | Inverser : zones = lieux calmes ; trajet = no man's land |
| E8 | **Camps** nombreux (pillards, fortifiés, alliés) avec échanges, atelier à 70 %, repos | Zones rares, villes non florissantes ; au plus un checkpoint ou un garage par chapitre (DEC-099) | Camps = lieux de zones / réduire à un point par chapitre / garder | Les services (échange, atelier, repos) deviennent le checkpoint de chapitre |
| E9 | Décor **désertique unique** (cactus, arbres morts, rochers) | Sols variés : terre et un peu d'herbe, cailloux, sable, eau (04.1 bis) ; France reconnaissable mais déformée (04.1 quater) | Un décor par type de zone / garder | Décor par type de zone ; l'eau est à créer |
| E10 | Carte : **niveau 0 à 7** par secteur, 12 secteurs aléatoires | 12 ou 13 secteurs sur une France déformée, noms nouveaux, rien de connu au départ (DEC-101) | Carte fixe dessinée / aléatoire | Carte fixe (OQ-010, OQ-011) ; le niveau suit la faction et la position |

## C. Compatibles a priori (à confirmer en essai, pas des écarts)

- Principe « on ne revoit jamais ceux qui s'éloignent » (MYS-001, 09.3) : déjà appliqué.
- Champs de mines, fléau (Sherman Crab), voyageurs et quêtes : cohérents avec les armes et véhicules de la Bible (01.3, 05.5) ; à régler en essai (OQ-012).
- Véhicules historiques réels (Willys, Sherman, Tiger…) : cohérents avec 01.3 ; marques à traiter en production (OQ-016).
- **Rareté des ressources** : le butin de fouille (munitions, carburant, métal) est-il trop généreux face à 04.1 bis ? Non mesuré, à vérifier en essai.
