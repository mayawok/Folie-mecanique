Version 2.0 — 29 octobre 2026

Document de conception interne. Il ne décrit pas un prototype jouable et ne constitue pas une validation du jeu final.

# 1. Protocole

3 000 trajectoires déterministes ont été exécutées: 1 000 par profil (prudent, équilibré, agressif), sur 30 jours. Le modèle représente les consommations quotidiennes, une amélioration initiale de production, des expéditions probabilistes, des gains/pertes de ressources, une menace croissante et des raids simplifiés.

Les graines sont fixes pour rendre les résultats reproductibles. Les profils modifient la fréquence des sorties et le calendrier de l’amélioration de production.

# 2. Résultats comparés

| Profil     | Parties | Nourriture finale médiane | Eau finale médiane (L) | Carburant final médian (L) | Moral final médian | Menace finale médiane | Expéditions médianes | Taux de pénurie alimentaire | Taux de pénurie d'eau | Taux de pénurie de carburant | Taux de brèche | État final médian porte (%) | État final médian mur (%) | État véhicule médian (%) | Parties signalées irrécupérables |
|------------|---------|---------------------------|------------------------|----------------------------|--------------------|-----------------------|----------------------|-----------------------------|-----------------------|------------------------------|----------------|-----------------------------|---------------------------|--------------------------|----------------------------------|
| cautious   | 1000    | 140.5                     | 853.0                  | 76.0                       | 55.0               | 19.9                  | 3.0                  | 0.0                         | 0.0                   | 0.0                          | 0.0            | 94.1                        | 95.8                      | 69.3                     | 0.0                              |
| balanced   | 1000    | 148.8                     | 894.5                  | 56.8                       | 55.0               | 23.0                  | 4.0                  | 0.0                         | 0.0                   | 0.4                          | 0.0            | 93.6                        | 95.5                      | 55.7                     | 0.0                              |
| aggressive | 1000    | 138.6                     | 857.5                  | 32.4                       | 48.7               | 35.9                  | 6.0                  | 0.0                         | 0.0                   | 2.9                          | 0.0            | 84.3                        | 88.8                      | 47.3                     | 0.0                              |

Attention : les chiffres sont ceux du modèle simplifié de cette passe. Les comparaisons servent à repérer les risques d’équilibrage, pas à figer les valeurs de production.

# 3. Principaux risques de conception

- Pénuries en cascade : une expédition ratée peut réduire les réserves et la condition du véhicule, augmentant le coût de la prochaine sortie.

- Raids et réparations : les raids doivent pouvoir endommager les portes et segments de mur sans transformer une seule brèche en perte automatique de partie.

- Récupération : prévoir au moins une option de secours accessible à faible coût (mission courte, commerce, aide d’une faction ou récupération d’urgence).

- Affectations exclusives : survivants, équipages, véhicules et armes doivent être verrouillés à un seul emplacement/usage à la fois.

- Sauvegardes : utiliser transactions atomiques et identifiants d’événement idempotents; un rechargement ne doit pas dupliquer butin ni appliquer deux fois une attaque.

- Les coûts de réparation doivent dépendre du composant et de l’état; une réparation complète ne doit pas coûter autant qu’une pièce neuve dans tous les cas.

# 4. Tests limites

| Test                                   | Attendu                                                                                                                     | État actuel                                                                                                             |
|----------------------------------------|-----------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------|
| Pénurie eau + nourriture               | Alerte critique, pénalités graduelles, pas de mort silencieuse hors validation du rapport de retour                         | Partiel: À formaliser; le modèle actuel applique une pénalité morale et plafonne les stocks à zéro                      |
| Véhicule immobilisé après échec        | Réparation sur place, remorquage, mission de secours ou abandon explicite                                                   | Partiel: Règle canonique présente; simulation actuelle modélise uniquement état véhicule et coût de réparation          |
| Raid pendant réparation                | La réparation consomme ressources/temps; le raid peut interrompre le chantier sans supprimer les ressources déjà consommées | À faire: À modéliser dans la simulation de calendrier                                                                   |
| Rechargement de sauvegarde             | Événement unique appliqué une fois via event_id idempotent                                                                  | Documenté: Contrat documentaire; pas de moteur de sauvegarde exécutable dans cette passe                                |
| Stock négatif après transaction        | Transaction rejetée atomiquement ou état d'urgence explicite                                                                | À faire: Le modèle de simulation plafonne les stocks; l'implémentation finale devra valider la transaction avant commit |
| Récupération après pénurie             | Reprise possible avec production positive, commerce, mission courte ou aide de faction                                      | À faire: Mécanisme de récupération documenté, pas encore équilibré                                                      |
| Équipage affecté à deux endroits       | Affectation exclusive: défense, arme, atelier ou expédition                                                                 | À faire: Règle à imposer dans les contrats d'affectation                                                                |
| Véhicule déployé et défense simultanés | Une instance véhicule ne peut être dans deux lieux à la fois                                                                | À faire: Règle à imposer via état d'occupation exclusif                                                                 |

# 5. Décisions proposées

- Conserver l’alerte de stock à moins de deux jours d’autonomie et l’alerte critique sous un jour.

- Ajouter une voie de récupération après pénurie : commerce de secours, mission courte à faible risque ou aide d’une faction partenaire.

- Éviter les pertes irréversibles hors récapitulatif de retour; afficher les risques avant de confirmer une expédition dangereuse.

- Faire de l’état des portes et des murs des objets distincts, réparables localement, avec état de brèche explicite.

- Ne pas figer les probabilités de raid avant une simulation intégrant la force d’attaque, les armes, les équipages, les angles de tir et les munitions.

# 6. Limites

Ce modèle ne simule pas encore un calendrier de construction complet, le positionnement des soldats, les arcs de tir, l’usage précis des munitions, les factions complètes ni le moteur de sauvegarde. Les valeurs et taux observés doivent être re-testés quand ces sous-systèmes seront détaillés.
