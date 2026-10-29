**Rapport d’avancement — systèmes intégrés**

*29 octobre 2026 • Version 1.5*

Statut : conception et données uniquement. Aucun prototype jouable n'est inclus.

# 1. Travail réalisé

- Consolidation des règles canoniques en version 1.4 : économie, phases d'expédition, dégâts localisés, récupération, factions, base verticale et contrats de sauvegarde.

- Création de la spécification intégrée v1.0, qui décrit les règles, dépendances, prérequis et critères d'acceptation de conception.

- Extension du tableur maître à v1.9 avec six nouvelles feuilles : bâtiments et économie, expéditions tactiques, dégâts et récupération, contrats de sauvegarde, factions et diplomatie, base verticale.

- Retrait des feuilles portant explicitement le nom « prototype » du tableur de livraison, conformément à la consigne de ne pas créer de prototype.

- Conservation de l'onglet d'estimations plausibles pour les 275 véhicules, avec niveaux de confiance; les estimations sont arrondies et ne remplacent pas les données historiques par des certitudes artificielles.

# 2. Règles désormais explicites

- Économie quotidienne : coûts d'entretien et entrées d'abord, personnel/énergie ensuite, production et limites de stockage ensuite, alertes en dernier.

- Pénuries : avertissement à deux jours d'autonomie, critique à un jour; effets progressifs et visibles.

- Expéditions : préparation, détection, contact, engagement, dégâts, objectif, retraite/récupération et rapport.

- Dégâts : états opérationnel/dégradé/désactivé à 70 % et 30 %; refroidissement reste un module à trois états.

- Factions : réputation, confiance, menace et peur sont quatre axes distincts; les témoins peuvent révéler des actions plus tard.

- Base verticale : trois niveaux souterrains avec coûts, délais, ventilation, drainage, énergie et limites de gabarit pour l'ascenseur.

- Sauvegardes : IDs stables, transactions atomiques, événements idempotents, migrations et points de contrôle.

- Hors ligne : 12 heures maximum; les pertes majeures et événements à fort enjeu sont présentés explicitement au retour.

# 3. Fichiers de référence

- Dossier_conception_complet_jeu_iphone_v1_7.zip : archive de livraison sans prototype.

- Specification_integree_systemes_jeu_iphone_v1_0.docx : spécification transversale.

- Regles_canoniques_jeu_iphone_v1_4.json : règles structurées.

- Base_maitre_275_vehicules_v1_9_systemes.xlsx : catalogue et tables de systèmes.

- INDEX_PROJET_JEU_IPHONE_v1_5.txt : index des décisions et priorités.

# 4. Ce qui reste à faire

- Vérifier les coûts de réparation et de fabrication pour éviter qu'une ressource soit sur-utilisée ou inutilisée.

- Définir précisément le contenu de départ, les plans débloqués, la première base et le rythme de progression sur 30 jours.

- Faire une matrice de tests de conception pour pénuries, raids, captifs, pertes de véhicule, rechargement et migrations.

- Consolider les documents historiques en un cahier des charges maître unique et éviter plusieurs versions concurrentes.

Les systèmes sont mieux définis, mais aucun test de jeu n'a été effectué. Les valeurs de balance restent donc des hypothèses de départ et non des résultats validés.
