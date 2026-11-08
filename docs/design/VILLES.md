# Villes — Folie Mécanique

Statut : **ville standard codée le 08/11 (DEC-140 à DEC-143)**, dessinée par le code en attendant les textures propres à chaque ville.
Code : `game/scripts/combat/modele_ville.gd` (logique), `game/scripts/combat/ville_dessin.gd` (dessin) ; valeurs et noms : `game/data/villes.json` ;
test : `game/tests/test_ville.gd` ; captures : `game/tests/capture_ville.gd`.

## Principe (demande du créateur, 08/11)

Une ville est un lieu sûr et reconnaissable, plat, fermé par un **mur d'enceinte** avec une **grande porte**. Aucune ville ne tire
sur le convoi pour l'instant ; des hommes armés montent la garde sur le chemin de ronde. La ville sert de **point de reprise**.

## Déroulé

1. **Approche** : la ville est annoncée à 160 m (« Les murs de … en vue »). Le convoi **freine seul** et s'arrête à 3 m de la porte fermée.
2. **Ouverture** (5 s) : les gardes ouvrent ; la porte glisse vers le haut.
3. **Entrée forcée** : le convoi roule au pas (2 m/s) sans ordre du joueur, la porte se referme derrière lui, il s'arrête sur la place
   (tête à 75 m de la porte, devant la mairie).
4. **Dans la ville** : le joueur ne peut pas bouger ; il doit **demander à repartir** (bouton « Repartir… »). Rien ne peut arriver :
   ni ennemi, ni tempête, ni rôdeur, ni demi-tour. À la première arrivée, la ville est **inscrite sur la carte** (petite enceinte
   et son nom) ; la partie est sauvegardée aussitôt.
5. **Choix de la sortie** : trois portes, une par secteur voisin le plus proche (« Porte vers le nord : … niveau 2, 1 400 m »).
   C'est ainsi qu'on change de direction sans route à embranchements.
6. **Sortie forcée** : le convoi gagne la porte de sortie, elle s'ouvre, il sort vers la droite de l'écran au pas, puis reprend la route :
   la route qui suit mène au secteur choisi. La ville s'efface 260 m plus loin.

## Ce qu'on trouve dans la ville (de gauche à droite)

| Lieu | Rôle aujourd'hui |
|---|---|
| Marché (étals bâchés) | décor |
| Atelier (hangar en arc, soudure) | ouvre la grille du véhicule choisi (ou du Berliet) |
| Garage · mécanique | le mécanicien remet tout le convoi en état contre du métal (0,05 métal par point de vie manquant) |
| **Mairie** | bâtiment de pierre reconnaissable : fronton, horloge, « MAIRIE », devise, volets, drapeau délavé ; le **maire** (écharpe tricolore) reçoit ; pas encore de quête |
| Café, dortoirs | décor (terrasse, linge, fenêtres allumées) |

Toucher la mairie, le garage ou l'atelier ouvre leur panneau. Bulles au-dessus du maire, du mécanicien et de l'atelier ;
des habitants lancent de temps en temps une phrase (`phrases` de `villes.json`). 280 habitants dessinés (au loin et au bord de la route),
maisons de tôles, bus, wagons, carcasses empilées, guirlandes, cheminées qui fument, projecteurs la nuit. Terrain aplani dans l'enceinte.

## Apparition

- Nouvelle expédition : une ville à 600 m du départ, puis une par secteur, 700 m après l'entrée dans le secteur.
- Le nom est tiré au hasard dans la liste de 30 lieux-dits quand la ville approche, puis gardé par le secteur (maire compris).
- Mode créatif : Kit → « Ville devant ».
- Option `villes` du modèle : sans elle (anciens tests, équilibrage), aucune ville.

## Noms (30)

Saint-Firmin-des-Prés, La Croix-Blanche, Le Moulin-Brûlé, Les Trois-Maisons, La Belle-Épine, Le Gué-de-l'Aune, La Chapelle-aux-Naux,
Villeneuve-la-Lionne, Mesnil-Rury, Les Granges-Hautes, Fontaine-le-Comte, Champ-Rond, La Maison-Rouge, Les Quatre-Chemins,
Le Plessis-Grimoult, Bourg-Achard, La Pierre-Levée, Vieux-Moulin, Le Bout-du-Monde, La Folie-Herbault, Les Baraques, La Tuilerie,
Le Relais-de-la-Poste, Haut-Clocher, Sainte-Colombe-sur-Gand, Les Ormes-Brûlés, Notre-Dame-de-Cenilly, Beauregard-Vendon,
Saint-Aubin-des-Bois, La Ferté-Aurain. Ajouter un nom = une ligne dans `villes.json`, sans code.

## Ouvert (OQ-026)

- Textures propres à chaque ville (images), et à quel moment.
- Quêtes du maire et des habitants ; marché (commerce), recrutement.
- La route entre deux secteurs est aujourd'hui une « zone calme » (code antérieur) ; avec les villes, faut-il la rendre dangereuse (no man's land, DEC-095) ?
- Décor de la route suivante selon la sortie choisie (zone de sable, terre, cailloux).
- Une ville peut-elle être hostile (portes fermées, tirs) ?
