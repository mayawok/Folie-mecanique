**Spécification intégrée des systèmes**

*Jeu iPhone post-apocalyptique • Version 1.0 • 29 octobre 2026*

Statut : conception, règles et données uniquement. Aucun prototype jouable n'est inclus.

# 1. Architecture générale

Le jeu est organisé autour d'une base persistante, de véhicules récupérés et modifiables, d'équipages, de ressources, d'expéditions tactiques et de factions. Les données statiques (catalogue des véhicules, plans, bâtiments) sont séparées des instances de partie (véhicule particulier, bâtiment construit, soldat, groupe de captifs, expédition).

- Les objets persistants ont des identifiants stables; aucun objet n'est identifié par sa position dans une liste.

- Les actions qui modifient plusieurs systèmes sont atomiques : soit toutes les conséquences sont enregistrées, soit aucune ne l'est.

- Chaque événement possède un identifiant stable et ne peut pas être appliqué deux fois après rechargement.

- Les règles de gameplay sont déterministes à seed égale. Une rencontre déjà résolue ne doit pas être rejouée pour relancer le hasard.

- Les valeurs de ce document sont des valeurs de départ. Elles doivent être ajustées après tests, mais constituent dès maintenant la référence de conception.

# 2. Économie, bâtiments et maintenance

Chaque bâtiment possède : un coût de construction, un délai, des prérequis, des entrées quotidiennes, des sorties, une capacité de stockage, un effectif, une consommation électrique, un entretien et un état (fonctionnel, dégradé, hors service). Le tableur v1.9 contient les valeurs par bâtiment sous forme structurée.

## 2.1 Ordre de simulation quotidienne

1.  1\. Calculer les besoins de population, captifs, animaux, bâtiments et véhicules.

2.  2\. Prélever les coûts d'entretien et les entrées requises; si les ressources sont insuffisantes, appliquer un état de pénurie.

3.  3\. Appliquer le personnel disponible, l'alimentation électrique et les états de panne.

4.  4\. Calculer la production, limitée par les entrées, l'effectif, l'énergie, l'état du bâtiment et la capacité de stockage.

5.  5\. Appliquer les plafonds de stockage et journaliser les pertes, arrondis et alertes.

6.  6\. Déclencher les incidents à risque modéré; les événements majeurs restent annoncés et résolus dans un bilan explicite.

## 2.2 Pénuries

Alerte à deux jours d'autonomie; état critique à un jour. Une pénurie ne doit pas effacer instantanément les stocks ni tuer silencieusement la population. Elle réduit progressivement la production, le moral, la santé ou la disponibilité des services selon une séquence visible. Le joueur doit pouvoir prioriser le rationnement, la production ou une expédition.

## 2.3 Carburant

Un seul stock de carburant en litres. Le type de carburant est une propriété du moteur et conditionne compatibilité et consommation. Le système ne crée pas de stocks séparés essence/diesel. Le moteur ne peut toutefois pas utiliser un carburant incompatible sans adaptation explicitement prévue par le jeu.

# 3. Expéditions tactiques

7.  Préparation : sélectionner véhicule, équipage, objectif, cargaison, carburant, eau, nourriture et munitions compatibles. Prévenir si la réserve estimée est insuffisante.

8.  Détection : observer, contourner, tendre une embuscade ou poursuivre. L'observation coûte du temps mais réduit l'incertitude.

9.  Contact : afficher une classe de menace, le terrain, les lignes de vue et une bande de risque; éviter les pourcentages artificiellement précis.

10. Engagement : choix tactiques — tirer, se couvrir, manœuvrer, utiliser une compétence, protéger un membre d'équipage ou rompre le contact.

11. Dégâts : appliquer des dégâts localisés, consommation de munitions, blessures, moral et éventuelles pertes selon le risque annoncé.

12. Objectif : fouiller, secourir, récupérer une épave, négocier, capturer des survivants ou battre en retraite.

13. Retour : bilan complet des dépenses, dégâts, blessures, butin, réputation et menaces futures.

## 3.1 États de composants

État supérieur ou égal à 70 % : opérationnel. De 30 à 69 % : dégradé. Sous 30 % : désactivé. Ce sont des seuils de gameplay communs, pas des mesures physiques. Le refroidissement reste un module unique à trois états : fonctionnel, endommagé ou absent. Les supports moteur sont traités comme compatibilité directe ou kit adaptateur générique.

## 3.2 Repli et récupération

Le repli est disponible sauf si le groupe est immobilisé ou piégé. Il coûte du temps et du carburant, peut abandonner une partie du butin et peut déclencher une poursuite. En cas d'immobilisation, le joueur choisit une réparation sur place, un remorquage, une mission de secours ou l'abandon explicite de l'épave. Une épave abandonnée peut rester récupérable plus tard tant que la zone n'est pas perdue.

## 3.3 Rapport d'expédition obligatoire

Le rapport inclut identifiant, durée, distance, carburant consommé, provisions, munitions par type, dégâts par composant, blessures, décès éventuels, butin, captifs, variations de réputation et de menace, résultat, option de repli et risque à venir.

# 4. Factions, réputation et diplomatie

Quatre axes sont distincts : réputation (jugement global), confiance (volonté de négocier), menace (probabilité de représailles) et peur (obéissance immédiate par intimidation). Une action peut donc augmenter la peur tout en faisant chuter la confiance.

## 4.1 Familles de factions

- Communautés : survie, commerce, protection; réagissent à l'aide, aux échanges équitables, aux attaques de villages et au traitement des captifs.

- Pilleurs : butin et représailles; évaluent la valeur visible des convois, les défaites, l'intimidation et les embuscades.

- Milices organisées : territoire et ordre; réagissent aux expansions, armes lourdes, postes fortifiés et alliances.

- Réseaux marchands : contrats fiables et routes sûres; modifient prix, contrats et accès aux marchés.

- Enclaves industrielles : pièces, carburant, machines et plans; offrent réparations, composants rares et savoir-faire selon les relations.

## 4.2 Seuils de réputation

- +60 à +100 : allié fiable — réductions, informations et aide possible, toujours avec un coût.

- +20 à +59 : partenaire — commerce normal et contrats occasionnels.

- -19 à +19 : neutre — accès de base, informations limitées.

- -20 à -59 : hostile — prix élevés, contrôles et risques d'embuscade plus élevés.

- -60 à -100 : ennemi déclaré — embargo ou attaques coordonnées; fréquence également liée à la menace, la distance et la capacité.

Les actions ne sont pas nécessairement connues immédiatement. Témoins, survivants, marchands ou messages interceptés peuvent révéler un événement plus tard. Les raids ont des périodes de récupération et des avertissements lorsque possible afin d'éviter une spirale de punition sans contre-jeu.

# 5. Base verticale, ascenseur et infrastructures

La base se représente en coupe verticale. La surface accueille les deux grandes portes, les murs, les véhicules, les positions extérieures, le commerce et les ateliers de surface. Les niveaux souterrains offrent une meilleure protection contre les raids directs, mais exigent excavation, ventilation, drainage, énergie et maintenance.

## 5.1 Niveaux de référence

- Sous-sol -1 : 4 jours; 90 ferraille, 30 bois, 35 métal. Stockage protégé, atelier léger et détention sécurisée. Risques d'infiltration d'eau et besoins de ventilation.

- Niveau industriel -2 : 7 jours; 140 ferraille, 20 bois, 90 métal, 8 électronique. Atelier lourd, pièces, générateur principal et réserves protégées. Consommation électrique accrue et risques de fumée/incendie.

- Noyau profond -3 : 12 jours; 220 ferraille, 10 bois, 150 métal, 20 électronique. Centre de commandement, soins avancés et stockage stratégique. Ventilation, drainage et réparations plus coûteux.

## 5.2 Ascenseur

Coût initial : 80 ferraille, 45 métal, 8 électronique; construction en 4 jours; 1 unité d'énergie par trajet. La charge autorisée dépend de la masse et du gabarit. Un véhicule trop grand reste en surface jusqu'à l'installation d'une amélioration de levage lourd. En panne, les personnes peuvent emprunter les escaliers, mais les véhicules et charges lourdes restent bloqués.

## 5.3 Priorités électriques

Ordre de priorité : ventilation et pompes, soins, défenses et éclairage, ateliers, confort. En cas de pénurie, les modules les moins prioritaires ralentissent ou s'arrêtent; le joueur reçoit une alerte avant les conséquences durables.

# 6. Sauvegarde, données et progression hors ligne

- Les modèles statiques et les instances de partie sont séparés. Le catalogue du véhicule décrit le modèle; condition, dégâts, carburant, équipage et emplacement appartiennent à l'instance récupérée.

- Les commandes multi-systèmes valident les préconditions, réservent les coûts, appliquent toutes les modifications, inscrivent le journal, puis valident la nouvelle version. Toute erreur entraîne un retour à l'état précédent.

- Les identifiants de commande et d'événement sont idempotents; une action déjà appliquée ne se répète pas après rechargement.

- Chaque changement de schéma possède une migration déterministe. Les sauvegardes conservent version, checksum et point de contrôle de secours.

- Le calcul hors ligne est plafonné à 12 heures. Production et entretien sont simulés de façon déterministe; les raids majeurs, morts, évasions ou pertes permanentes sont reportés à un bilan explicite au retour.

# 7. Catalogue véhicules : politique d'estimation

Le catalogue maître conserve les 275 entrées et ajoute un onglet d'estimations probables. Grade B : valeur typique d'un modèle connu; B/C : famille connue avec variantes; C/D : estimation par catégorie ou prototype. Les valeurs estimées sont arrondies et annotées. Le but est d'éviter les champs clés vides, sans faire passer une approximation pour une donnée constructeur exacte.

# 8. Critères d'acceptation de conception

- Une journée de simulation ne crée pas de ressources sans entrées, effectif, énergie et capacité de stockage disponibles.

- Une expédition peut être préparée, engagée, interrompue, récupérée et résumée sans perdre l'historique des dépenses.

- Une faction réagit à la réputation, la menace, la confiance et la peur de façon distincte.

- Un bâtiment souterrain ne fonctionne pas normalement si ses prérequis de ventilation ou drainage sont absents ou en panne.

- Une sauvegarde rechargée ne duplique ni butin, ni dépenses, ni dégâts, ni événements diplomatiques.

- Les champs estimés des véhicules restent identifiables comme estimations dans le tableur.

- Aucun prototype jouable n'est inclus dans ce livrable.
