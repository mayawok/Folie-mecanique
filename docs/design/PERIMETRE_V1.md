# Périmètre V1 — Folie Mécanique

Statut : validé (thème 4, DEC-013). Distingue ce qui est **décidé** de ce qui reste **ouvert**.

## Principe

La V1 prouve la boucle centrale **rareté → expédition → retour**. Elle doit rester
livrable par un développeur seul, débutant sur Godot. Tout ce qui ne sert pas cette
boucle est reporté, même si les tables existent déjà dans `data/master/`.

## Inclus en V1

| Domaine | Contenu |
|---|---|
| Ressources | 5 : eau, nourriture, carburant unique (`stocks.fuel`), matériaux, munitions |
| Base | Affectation des travailleurs ; ≈ 8 bâtiments : cuves, atelier, puits/condenseur, cuisine, entrepôt, infirmerie, 2 défenses automatiques |
| Véhicules | Les 10 véhicules validés (DEC-008) ; construction et démantèlement d'épaves |
| Carte | Biome **désert uniquement** ; 10 à 12 points d'intérêt |
| Expéditions | Ordres permanents, départ programmé, événements de trajet |
| Combat | Résolu automatiquement (DEC-009) |
| Faune | **Sous forme d'événements uniquement** : attaques en route et sur la base |
| Temps | 1 jour de jeu = 1 jour réel, planchers d'absence, pénurie graduée, rapport du matin, notifications |
| Récit | 6 à 8 moments narratifs courts |
| Achats | Cosmétiques et pack fondateur uniquement |

## Architecture technique

- **Jeu solo, hors ligne, sans serveur.**
- À la reconnexion, le temps écoulé est recalculé sur l'appareil (simulation de rattrapage
  déterministe à partir de l'horodatage de la dernière sauvegarde).
- Sauvegarde locale.
- Limite acceptée : un joueur peut avancer l'horloge du téléphone pour tricher.
  Sans classement ni échange entre joueurs, l'impact est limité à sa propre partie.

## Reporté

| Élément | Version | Raison |
|---|---|---|
| Sièges / attente devant une ville | V1.1 | Exige fortification du convoi et faune de nuit, équilibrage dédié |
| Biome neige | V1.1 | Extension de carte ; divise par deux le travail graphique et jour/nuit en V1 |
| Abonnement « Commandant », accélérateur de chantier | V1.1 | Après simulation du profil « abonné » (`ACHATS.md`) |
| Vue de combat contrôlée | V2 | DEC-009 |
| Faune comme système complet | Thème 5 / ultérieur | V1 limitée aux événements |
| Factions et diplomatie, captivité, base verticale, élevage avancé | V2 | Ne servent pas la boucle centrale |
| 265 autres véhicules | Ultérieur | Base maître conservée comme réservoir |
| Android, multijoueur, serveur | Non planifié | Voir profil du projet |

## Conséquences sur les autres documents

- `BOUCLE.md` : en V1, seule la colonne « Désert » du tableau jour/nuit s'applique.
- Simulation 30 jours : modéliser le désert seul et le rattrapage hors ligne.
- Garde-fou `monetization.guardrails` inchangé.

## Ouvert

- Liste définitive des bâtiments V1 et de leurs niveaux (thème 5).
- Liste des 10 à 12 points d'intérêt.
- Protection éventuelle contre la manipulation d'horloge (ex. temps écoulé plafonné).
