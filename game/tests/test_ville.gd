extends SceneTree
# Villes standard (DEC-140 à DEC-143) : freinage devant la porte, ouverture, entrée forcée, ville protégée et inscrite
# sur la carte, choix de la sortie, sortie forcée, sauvegarde.
#   godot --headless --path game -s res://tests/test_ville.gd
var echecs := 0


func ok(c: bool, t: String) -> void:
	print("OK  " if c else "ÉCHEC ", t)
	if not c:
		echecs += 1


func _jusqua(m: CombatModele, cond: Callable, s_max: float) -> float:
	var s := 0.0
	while s < s_max and not cond.call():
		m.avancer()
		s += CombatModele.DT
	return s


func _init() -> void:
	var D: Dictionary = CombatModele.VD()
	ok(D.noms.size() >= 30, "%d noms de villes" % D.noms.size())
	var m := CombatModele.new(7, {"meteo": true, "champs": true, "villes": true})
	m.stocks.fuel_l = 500.0
	m.champs_on = false
	m.meteo_on = false
	m.monde._assaut_t = 1.0e9
	ok(m.ville_active() and m.ville_phase() == "approche", "une ville attend sur la route au départ")
	var nom := String(m.ville.nom)
	ok(D.noms.has(nom), "nom tiré de la liste : %s" % nom)
	var x0 := float(m.ville.x0)
	ok(absf(Terrain.relief(x0 + 40.0) - Terrain.relief(x0 + 110.0)) < 0.01, "la ville est plate")
	# Approche : on avance, le convoi freine seul et s'arrête devant la porte
	m._prochain_x = INF
	m.ordre_marche("avancer")
	var s := _jusqua(m, func(): return m.ville_phase() != "approche", 900.0)
	ok(m.ville_phase() == "ouverture", "arrêt devant la porte en %d s" % int(s))
	ok(m.x_tete <= x0 - 2.5 and m.x_tete >= x0 - 3.5, "tête à 3 m de la porte (%.2f m)" % (x0 - m.x_tete))
	ok(m.ordres.marche == "halte", "le convoi est en halte")
	m.ordre_marche("avancer")
	ok(m.ordres.marche == "halte", "ordre de marche ignoré pendant l'ouverture")
	# Ouverture puis entrée au pas
	_jusqua(m, func(): return m.ville_phase() == "entree", 10.0)
	ok(float(m.ville.porte_e) >= 0.99, "porte ouverte")
	var vmax := 0.0
	s = _jusqua(m, func():
		vmax = maxf(vmax, m.vitesse_convoi)
		return m.ville_phase() == "dedans", 200.0)
	ok(m.ville_dedans(), "convoi garé dans la ville en %d s" % int(s))
	ok(vmax <= float(D.vitesse_forcee) + 0.01, "entrée au pas (%.1f m/s au plus)" % vmax)
	ok(m._queue_x() > x0 + 3.0, "tout le convoi est passé")
	ok(float(m.ville.porte_e) <= 0.0, "la porte s'est refermée")
	ok(bool(m.monde.secteurs[m.monde.secteur].get("ville_connue", false)), "ville inscrite sur la carte")
	# Dedans : protégé
	var xd := m.x_tete
	m.ordre_marche("avancer")
	for i in 50:
		m.avancer()
	ok(absf(m.x_tete - xd) < 0.01, "on ne bouge pas sans demander à repartir")
	m.tempete = {"phase": "active", "reste": 60.0, "duree": 60.0}
	m.ennemis.append(m.creer_vehicule("citroen_traction", "ennemi", m.x_tete + 40.0))
	m.avancer()
	ok(m.tempete.is_empty() and m.ennemis.filter(func(e): return e.actif()).is_empty(), "ni tempête ni ennemi dans l'enceinte")
	ok(not m.ordre_demi_tour(), "pas de demi-tour dans la ville")
	# Mécanicien
	var v = m.convoi[0]
	v.pieces.moteur.pv = v.pieces.moteur.max * 0.5
	m.stocks.metal = 999.0
	var cout := m.ville_cout_reparation()
	ok(cout > 0 and m.ville_reparer(), "le mécanicien répare (%d métal)" % cout)
	ok(float(v.pieces.moteur.pv) == float(v.pieces.moteur.max), "moteur remis à neuf")
	ok(m.ville_texte_maire().contains(nom), "le maire parle")
	# Sauvegarde dans la ville (point de reprise)
	var m2 := CombatModele.depuis_sauvegarde(JSON.parse_string(JSON.stringify(m.sauver())))
	ok(m2.ville_dedans() and String(m2.ville.nom) == nom, "reprise dans la ville")
	ok(bool(m2.monde.secteurs[m2.monde.secteur].get("ville_connue", false)), "la carte garde la ville")
	# Sorties
	var so: Array = m.ville_sorties()
	ok(so.size() == int(D.sorties), "%d sorties proposées : %s" % [so.size(), ", ".join(so.map(func(o): return "%s (%s)" % [o.porte, o.secteur]))])
	var dest := int(so[1].id)
	ok(m.ville_partir(dest), "départ demandé")
	ok(m.monde.en_transit() and int(m.monde.trajet.dest) == dest, "la route suivante mène au secteur choisi")
	s = _jusqua(m, func(): return m.ville_phase() == "fin", 300.0)
	ok(m.ville_phase() == "fin", "sortie de la ville en %d s" % int(s))
	ok(m._queue_x() > float(m.ville.x1), "le convoi est dehors, à droite")
	ok(m.ordres.marche == "avancer", "le convoi reprend la route")
	_jusqua(m, func(): return not m.ville_active(), 400.0)
	ok(not m.ville_active() and Terrain.plats.is_empty(), "la ville s'efface derrière nous")
	# Sans l'option : aucune ville (anciens tests et équilibrage inchangés)
	var m3 := CombatModele.new(7)
	ok(not m3.ville_active(), "pas de ville sans l'option villes")
	# Kit
	var mk := CombatModele.new(3, {"bac_a_sable": true})
	ok(mk.kit_ville() and mk.ville_phase() == "approche", "Kit : une ville devant")
	print("Villes : %d échec(s)." % echecs)
	quit(1 if echecs > 0 else 0)
