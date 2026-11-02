# État du projet — Folie Mécanique

Mis à jour : 2026-11-01 soir (retours iPhone : grille refaite, équipage, phares, écrasement, lance-flammes). Fichier à lire en premier (court, à garder < 60 lignes).

## Où on en est

- **Mode convoi jouable** (DEC-026) dans `game/`, publié sur GitHub Pages (`game/LISEZMOI.md`).
  Contenu : embuscade, relief, carte 12 secteurs, camps et factions, nuit et abri, fantassins, voyageurs, fouille,
  survivants, garage (hangar/grange), demi-tour, sauvegarde auto, sons.
- Moteur : Godot 4.3 / GDScript (DEC-001). Passage à la 4.6 proposé.
- **Identité : roguelite de convoi** (DEC-032). Gestion de base, temps réel et achats : archivés (DEC-031).
- Code découpé en couches (DEC-033, carte des fichiers dans `CONVOI.md`).
- **Grille G1 faite** (DEC-034) : véhicules = châssis + pièces, statistiques calculées (`GRILLE.md`).
- **La partie commence par la grille** (DEC-035) : moto assemblée, puis side-car, essence, arme, ennemis.
- **Codés le 01/11** : tempête de sable (DEC-036), champs de mines (DEC-037), grille G2 démontage (DEC-038), G3 éditeur libre
  (DEC-039), G4 dessin des assemblages (DEC-040). Tests : 221 vérifications sans écran + parcours écran (`game/tests/`).
- **Refonte de la grille le 01/11** (DEC-043 à 046) : châssis peint case par case, essieux, roues de trois tailles ou chenilles,
  moteurs, cabines, armes (mitrailleuse, canons, **mortier**) ; tout compatible, mauvais résultats calculés ; grille ouverte
  à tout moment (jeu en pause) ; **menu principal avec Bac à sable**.
- **Retours iPhone du 01/11 après-midi** (DEC-047 à DEC-061) : interface écartée des bords (iPhone 14 Pro Max+), grille agrandie
  et centrée, châssis en rectangles, essieu puis roue, onglets par catégorie, vrai dessin pendant le glisser, nom proposé et
  modifiable, rôles d'équipage avec avertissement, phares, méga-char pénalisé, écrasement, lance-flammes, trajectoires réalistes,
  épave sans roues, dézoom de fin, brouillon de grille, rendu limité à 2 px/pt contre les rechargements.
- **Postes, bancs, cabines, troupes** (DEC-062 à 064) : postes de conduite et de commande, bancs de troupes dans les deux sens,
  cabines décor camion/voiture/blindée au-dessus des sièges, troupes débarquables en combat, équipage descendu (sauf le chef) en réparation.
  Tests : 6 suites sans écran vertes ; capture `tests/capture_cabines.gd`. **À vérifier sur iPhone.**
- **Interface allégée** (DEC-065) : bulles de ressources avec icônes, cadran jour/nuit en coin, plus de bandes noires, cartes compactes. À vérifier sur iPhone.
- **Visuels de la grille intégrés** (DEC-066) : roues, moteurs, cabines, phares, armes. Restent : tuiles de châssis, essieux, chenilles, benne.
- **Construction en deux plans** (DEC-067, phase 1 codée : DEC-068, à vérifier sur iPhone) : mécanique sur la grille, carrosserie de donneur posée par-dessus ;
  catalogues extensibles sans code (moteurs, roues, châssis, suspensions et leur hauteur, coques, greffes). Détails : `GRILLE.md`.
- **Ponts rigides, onglet Suspension, plans enregistrés, cabines décor retirées** (DEC-069 à 071). À vérifier sur iPhone.
- **Poursuites et abordages** (DEC-077), silence hors du jeu (DEC-073), suspension en l'air (DEC-075), retirer en glissant (DEC-076). À vérifier sur iPhone.
- Audit du 31/10 : `docs/audits/AUDIT_2026-10-31.md`.

## À confirmer par le porteur de projet (rien d'autre n'est en attente de code)

- **iPhone** : boutons atteignables, taille des cases de la grille, rechargements moins fréquents, écran « Tournez le téléphone » (DEC-056, 059).
- Produire `mus_fin` (`docs/audio/ELEVENLABS.md`) : seul son manquant ; Claude peut le générer via le plugin ElevenLabs (DEC-084) après accord sur le coût. Fond de grille intégré (DEC-078).

- **Son iPhone** (DEC-030, renforcé par DEC-041) : non vérifiable hors appareil. Tester en mode normal puis silencieux.
- Jouer la tempête, les mines et la grange : valeurs à régler dans `combat_proto.json` (`tempete`, `mines_champs`, `demontage`).
- `game/tests/capture_convoi.gd` est un ancien parcours devenu obsolète avec l'ouverture guidée (il n'aboutit pas).

## Décisions ouvertes (à trancher)

1. Modèle économique adapté au roguelite (prix unique, démo + déblocage, cosmétiques).
2. Gel des fonctions pour un cycle d'essais (`docs/design/ESSAIS.md`).
3. But d'une partie et progression entre les parties.
4. Passage à Godot 4.6 ; chemin de compilation iOS sans Mac.

## Prochaines étapes (ordre recommandé)

1. Le porteur de projet essaie le **Mode créatif** (ex-Bac à sable) (construire, rater, corriger) ; puis joue 3 sessions et remplit `ESSAIS.md` ; confirme le son (iPhone non silencieux et silencieux).
2. Essayer dans le Mode créatif la nouvelle grille en icônes (DEC-080) et les véhicules penchés + outil Déplacer + vue à deux doigts (DEC-082) : tôles, poutres, radiateurs, peinture, remorques, véhicules du jeu ; Carrosserie, Suspension, Plans, Greffes. Reste de la phase 3 de DEC-067 : éperon (avec collisions), base roulante trouvée. Plus tard : gazogène, marques des pièces.
3. Voitures sur plateforme (DEC-083) : essayer l'onglet Voitures, les carrosseries rouillées, le moteur à nu et la classe Intercepteur. **À définir** : quelles voitures (modèles) pour chaque longueur de châssis (plusieurs par longueur), et comment on les trouve en jeu (hors mode créatif, la plateforme ne change pas).
4. Coder le lore des marchands sur châssis de char et des villes traversées (DEC-061) ; intégrer les visuels de la grille.
5. Atelier guidé pour les gros véhicules (pièces tirées de leur dessin), art définitif des assemblages.
6. Régler tempête, mines et grange d'après les essais ; trancher la nature du fléau (Sherman Crab) et le chien.
7. Godot 4.6, puis essai d'export iOS dans le nuage.

## Carte du dépôt

| Chemin | Contenu |
|---|---|
| `AGENTS.md` | Règles pour développeurs et IA |
| `docs/INDEX.md` | Ordre de lecture, sources de vérité |
| `docs/DECISIONS.md` | Journal des décisions |
| `docs/design/` | VISION, CONVOI, GRILLE, LORE, GRAPHISMES, ESSAIS |
| `game/` | Prototype Godot (`scripts/combat/` = convoi, `scripts/vehicules/` = pièces), tests dans `game/tests/` |
| `data/master/` | Tables (catalogue de composants, grille) |
| `archive/` | Éléments en sommeil (base, temps réel, simulations) |
| `tools/` | Scripts (export Excel → CSV, sons synthétisés, gabarits) |
