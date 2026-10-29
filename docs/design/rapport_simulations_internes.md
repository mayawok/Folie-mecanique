Version 1.0 — 29 octobre 2026

Usage : vérification de cohérence de conception uniquement. Aucun prototype jouable n’a été créé. Les chiffres sont des résultats d’un modèle simplifié, pas des tests en jeu ni des valeurs finales.

# 1. Méthode

Simulation Monte-Carlo de 30 jours, 2 000 trajectoires par scénario, graine fixe 20261029. Base de départ supposée : 8 survivants, 100 unités de nourriture, 500 L d’eau, 300 L de carburant, 300 ferrailles, 100 métaux, 15 électroniques. Consommation journalière : 8 unités de nourriture et 40 L d’eau. Production nourriture/eau et fréquence d’incidents varient par scénario. Un incident retire 8 à 24 ferrailles et parfois 2 à 8 métaux. Pas de mort ni de destruction majeure modélisée.

# 2. Résultats sur 30 jours

| Scénario         | Runs avec pénurie nourriture | Runs avec pénurie eau | Jours moyens nourriture à zéro | Jours moyens eau à zéro | Stock médian nourriture J30 | Stock médian eau J30 |
|------------------|------------------------------|-----------------------|--------------------------------|-------------------------|-----------------------------|----------------------|
| Sous-dimensionné | 0.0%                         | 12.2%                 | 0.00                           | 0.30                    | 34                          | 25 L                 |
| Équilibré        | 0.0%                         | 0.0%                  | 0.00                           | 0.00                    | 150                         | 605 L                |
| Sécurisé         | 0.0%                         | 0.0%                  | 0.00                           | 0.00                    | 208                         | 895 L                |

Lecture : la stabilité dépend surtout du débit net nourriture/eau, pas du stock initial. Le scénario équilibré produit seulement +2 nourriture/jour et +5 L eau/jour avant perturbations; une panne de production prolongée suffit donc à vider la réserve. Le scénario sécurisé offre davantage de marge, mais son coût en main-d’œuvre/énergie doit être équilibré séparément.

# 3. Détention : coût souvent sous-estimé

Quatre captifs pendant 7 jours consomment 28 unités de nourriture et 112 L d’eau, avec un garde dédié. Risque cumulé théorique d’au moins une tentative d’évasion si les risques quotidiens sont indépendants : 30.2% en enclos improvisé, 16.2% en bloc renforcé. Ces probabilités sont indicatives et n’incluent pas les modificateurs de garde, moral, surpopulation ou événements.

# 4. Ajustements recommandés

- Ne pas traiter la production nominale comme garantie : appliquer disponibilité, main-d’œuvre et énergie avant de compter les sorties.

- Afficher une autonomie prévisionnelle calculée sur la consommation réelle des 24 dernières heures, avec avertissement sous 2 jours et critique sous 1 jour.

- Pour les nouveaux joueurs, viser au démarrage une marge nette de +25 à +35 % en nourriture et eau quand les bâtiments sont opérationnels; les incidents doivent pouvoir consommer cette marge sans rendre la partie perdue en quelques jours.

- Les pénuries doivent déclencher des choix visibles : rationnement, arrêt d’un atelier, expédition de ravitaillement, échange ou réparation de la production.

- La détention doit afficher son coût journalier avant capture et offrir libération, échange ou intégration volontaire comme options explicites.

- Séparer les résultats calculés des hypothèses de modèle; ne pas annoncer ces chiffres comme un équilibrage validé tant que les mécaniques complètes ne sont pas testées.

# 5. Tests de cohérence

| Cas                                 | Résultat attendu                                                                                  |
|-------------------------------------|---------------------------------------------------------------------------------------------------|
| Stock nourriture exactement nul     | Le stock ne devient jamais négatif; alerte critique et rationnement explicitement journalisé.     |
| Deux raids le même jour             | Chaque raid possède un event_id unique; pas de double application au rechargement.                |
| Véhicule immobilisé avec inventaire | Retour interdit sans option de récupération, remorquage, sauvetage ou abandon explicite.          |
| Panne de ventilation hors ligne     | Avertissement et pénalité progressive; pas de mort instantanée ou destruction silencieuse.        |
| Sauvegarde pendant transaction      | Écriture atomique: l’état chargé est l’ancien état complet ou le nouvel état complet.             |
| Rechargement après récompense       | Même expedition_id + encounter_id ne peut accorder le butin qu’une seule fois.                    |
| Soldat affecté à une mitrailleuse   | Indisponible simultanément pour expédition; l’interface doit montrer ce conflit avant validation. |
| Carburant partagé                   | Un seul stock fuel_l; consommation déduite en litres, compatibilité gérée sur le moteur.          |

# 6. Limites

Le modèle ne simule pas encore les recettes détaillées de chaque bâtiment, le personnel affecté, l’énergie, les prix, la distance réelle des expéditions, la létalité des armes ni le cheminement des raids. Il sert à repérer des contradictions et des marges trop faibles, pas à prouver l’équilibrage final. La prochaine simulation doit porter sur une progression de 30 jours avec bâtiments et expéditions définis jour par jour.
