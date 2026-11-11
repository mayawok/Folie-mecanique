extends SceneTree
# Missions du maire (DEC-144 à DEC-147) : offres, scènes de départ, escorte, route et vagues, livraison et récompense,
# échec, sauvegarde.   godot --headless --path game -s res://tests/test_mission.gd
var echecs := 0


func ok(c: bool, t: String) -> void:
	print("OK  " if c else "ÉCHEC ", t)
	if not c:
		echecs += 1


func _jusqua(m: CombatModele, cond: Callable, s_max: float, nettoyer := false) -> float:
	var s := 0.0
	while s < s_max and not cond.call():
		m.avancer()
		if nettoyer:
			m.ennemis.clear()   # le test ne juge pas les combats
			m.abordeurs.clear()
		s += CombatModele.DT
	return s


func _en_ville(m: CombatModele) -> void:
	m.ordre_marche("avancer")
	_jusqua(m, func(): return m.ville_dedans(), 1200.0, true)


func _init() -> void:
	var M: Dictionary = CombatModele.MD()
	var cat: Dictionary = JSON.parse_string(FileAccess.open("res://data/pieces.json", FileAccess.READ).get_as_text()).pieces
	for t in M.types:
		ok(BerlietConfig.options("module").has(M.types[t].module), "module du type %s connu du Berliet" % t)
	for pid in M.pieces_recompense:
		ok(cat.has(pid), "pièce de récompense %s au catalogue" % pid)
	var m := CombatModele.new(5, {"bac_a_sable": true})
	m.stocks.gazole = 900.0
	ok(m.kit_ville(), "Kit : ville devant")
	_en_ville(m)
	ok(m.ville_dedans(), "dans la ville")
	var offres: Array = m.mission_offres()
	ok(offres.size() == M.types.size(), "le maire propose toutes les missions dans le Kit (%d)" % offres.size())
	var o: Dictionary = offres.filter(func(x): return x.type == "carburant")[0]
	var voisin: int = m.ville_sorties()[0].id
	ok(int(o.dest) == voisin, "destination : la ville du secteur voisin le plus proche (%s)" % o.dest_nom)
	ok(String(o.texte).contains(o.dest_nom) and String(o.texte).contains("présence ennemie"), "le maire annonce la destination et la présence ennemie, sans détail")
	ok(not String(o.texte).contains("Traction,") and not String(o.texte).contains("moto_bmw"), "le maire ne détaille pas les ennemis")
	# Diversité selon le niveau (DEC-150)
	var plan: Dictionary = m.mission_plan("carburant", int(o.dest))
	var Me: Dictionary = M.menace
	ok(plan.vagues.size() == int(Me.vagues_par_niveau[plan.niveau]), "niveau %d : %d vague(s) prévue(s)" % [plan.niveau, plan.vagues.size()])
	var sortes := {}
	for niv in [0, 3, 6]:
		m.monde.secteurs[int(o.dest)].niveau = niv
		for ty in M.types:
			for v in m.mission_plan(ty, int(o.dest)).vagues:
				sortes[str(v.vehicules) + v.mode] = true
	ok(sortes.size() >= 4, "%d sortes de vagues différentes selon les niveaux et les missions" % sortes.size())
	m.monde.secteurs[int(o.dest)].niveau = 7
	ok(m.mission_plan("carburant", int(o.dest)).presence.contains("très forte"), "niveau 7 : très forte présence annoncée")
	m.monde.secteurs[int(o.dest)].niveau = 0
	m.monde.secteurs[m.monde.secteur].niveau = 0
	ok(m.mission_plan("carburant", int(o.dest)).presence.contains("faible"), "niveau 0 : faible présence annoncée")
	m.monde.secteurs[int(o.dest)].niveau = int(plan.niveau)
	var n0 := m.convoi.size()
	var fuel0 := float(m.stocks.gazole)
	var stock0 := m.pieces_stock.size()
	var module0 := String(m.berliet_config.module)
	ok(m.mission_accepter("carburant"), "mission acceptée")
	ok(m.ville_phase() == "chargement" and m.berliet_config.module == "citerne", "scène de l'atelier, citerne posée sur le Berliet")
	ok(absf(m.x_tete - (float(m.ville.x0) + float(M.pos_atelier_m))) < 0.01, "le camion est à l'atelier")
	for i in 15:
		m.avancer()
	ok(m.mission_module_leve() > 1.0, "la citerne descend du pont roulant (%.1f m)" % m.mission_module_leve())
	ok(m.mission_sous_titre() != "", "sous-titre de la scène")
	m.ordre_marche("avancer")
	ok(m.ordres.marche == "halte" or m.ville_phase() == "chargement", "pas d'ordre pendant la scène")
	_jusqua(m, func(): return m.ville_phase() == "rassemblement", 20.0)
	ok(m.mission_module_leve() == 0.0, "citerne en place")
	ok(m.convoi.size() == n0 + M.escorte.size(), "l'escorte rejoint le convoi (%d véhicules)" % m.convoi.size())
	ok(not m.convoi[0].principal and m.convoi[0].type == M.escorte[0], "une moto ouvre la marche")
	_jusqua(m, func(): return m.ville_phase() == "depart", 20.0)
	ok(m.mission_en_route() and m.monde.en_transit() and int(m.monde.trajet.dest) == int(o.dest), "départ automatique vers %s" % o.dest_nom)
	# Route : les vagues annoncées arrivent
	var vagues := [0]
	_jusqua(m, func():
		if m.ennemis.size() > 0:
			vagues[0] += 1
		return not m.monde.en_transit(), 1800.0, true)
	ok(int(m.mission.vagues) == m.mission.plan.size() and m.mission.plan.size() > 0, "%d vague(s) sur la route" % int(m.mission.vagues))
	ok(m.ville_active() and float(m.ville.x0) - m.x_tete < float(M.ville_arrivee_m) + 1.0, "la ville de destination est au bout de l'étape")
	# Sauvegarde pendant la mission
	var m2 := CombatModele.depuis_sauvegarde(JSON.parse_string(JSON.stringify(m.sauver())))
	ok(m2.mission_en_route() and m2.mission.escorte.size() == M.escorte.size(), "reprise : mission et escorte gardées")
	_en_ville(m)
	print("DBG x=%.1f x0=%.1f vit=%.2f phase=%s dedans=%s marche=%s blocage=%s" % [m.x_tete, float(m.ville.x0), m.vitesse_convoi, m.ville_phase(), str(m.ville_dedans()), str(m.ordres.marche), str(m.get("blocage"))])
	for l in m.journal:
		if String(l.txt).contains("tamponne") or String(l.txt).contains("détruit") or String(l.txt).contains("atterri") or String(l.txt).contains("décolle") or String(l.txt).contains("rev"):
			print("DBGJ ", String(l.txt))
	ok(not m.mission_active() and bool(m.mission_bilan.get("ok", false)), "cargaison livrée")
	ok(String(m.ville.nom) == String(o.dest_nom), "livrée à %s" % m.ville.nom)
	ok(m.convoi.size() == n0, "l'escorte reste dans la ville")
	ok(String(m.berliet_config.module) == module0, "citerne déchargée")
	ok(m.pieces_stock.size() == stock0 + int(M.types.carburant.recompense.pieces), "pièce de véhicule reçue")
	ok(String(m.mission_bilan.texte).contains("gazole"), "bilan : %s" % m.mission_bilan.texte.substr(0, 80))
	# Eau : citerne différente ; échec par demi-tour
	var m3 := CombatModele.new(9, {"bac_a_sable": true})
	m3.stocks.gazole = 900.0
	m3.kit_ville()
	_en_ville(m3)
	ok(m3.mission_accepter("eau") and m3.berliet_config.module == "citerne_eau", "mission eau : citerne d'eau")
	_jusqua(m3, func(): return m3.ville_phase() == "fin", 120.0, true)
	ok(m3.mission_en_route(), "en route")
	m3.ordre_demi_tour()
	ok(not m3.mission_active() and not bool(m3.mission_bilan.get("ok", true)), "demi-tour : mission échouée")
	# Expédition : deux offres
	var m4 := CombatModele.new(7, {"villes": true})
	m4.stocks.gazole = 900.0
	m4.champs_on = false
	m4.meteo_on = false
	m4.monde._assaut_t = 1.0e9
	m4._prochain_x = INF
	_en_ville(m4)
	ok(m4.mission_offres().size() == 2, "expédition : le maire propose deux missions")
	print("Missions : %d échec(s)." % echecs)
	quit(1 if echecs > 0 else 0)
