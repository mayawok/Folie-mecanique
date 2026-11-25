# Fin du lot transmission (DEC-261) : sauts sur les crêtes, balancement et poussée des remorques, basculement.
# godot --headless --path game -s res://tests/test_sauts.gd
extends SceneTree

var echecs := 0


func ok(c: bool, t: String) -> void:
	print("OK  " if c else "ÉCHEC ", t)
	if not c:
		echecs += 1


func _rouler(zone: String, urgence: bool, secondes: float) -> Dictionary:
	var m := CombatModele.new(3, {"bac_a_sable": true, "kit_groupe": true})
	m.kit_calme = true
	m._prochain_x = INF
	Terrain.zone = zone
	m.ordre_marche("avancer")
	var r := {"decollages": 0, "vol_max": 0.0, "h_max": 0.0, "impact_max": 0.0, "atterrissages": 0, "v_max": 0.0, "pv0": 0.0, "pv1": 0.0}
	for v in m.convoi:
		for p in v.pieces.values():
			r.pv0 += float(p.pv)
	var en_l_air := {}
	for i in int(secondes * 10.0):
		if urgence:
			m.trans.urgence = true
			m.trans.urgence_t = 99.0
		m.avancer()
		r.v_max = maxf(r.v_max, m.vitesse_convoi)
		for v in m.convoi:
			if v.en_vol and not en_l_air.get(v.uid, false):
				r.decollages += 1
			en_l_air[v.uid] = v.en_vol
			if v.en_vol:
				r.vol_max = maxf(r.vol_max, v.vol_t)
				r.h_max = maxf(r.h_max, m.hauteur_vol(v))
		for e in m.vider_evenements():
			if e.t == "atterrit":
				r.atterrissages += 1
				r.impact_max = maxf(r.impact_max, float(e.fort))
	for v in m.convoi:
		for p in v.pieces.values():
			r.pv1 += float(p.pv)
	r.x = m.x_tete
	return r


func _init() -> void:
	Textes.langue = "fr"
	# Relief : crêtes présentes dans le sable, absentes dans l'eau et sur route forcée ; la pente de route les ignore
	Terrain.zone = "sable"
	var n := 0
	var lisse := true
	for i in 200:
		var c := Terrain.crete_case(float(i))
		if not c.is_empty():
			n += 1
			var xs: float = float(c[0]) + float(c[1]) - 0.2
			lisse = lisse and absf(Terrain.pente(xs) - (Terrain.route(xs + 3.0) - Terrain.route(xs - 3.0)) / 6.0) < 0.0001
	ok(n > 60 and n < 140, "sable : une crête sur deux cases environ (%d sur 200)" % n)
	ok(lisse, "la pente de la route ignore les crêtes (pas de ralentissement à chaque bosse)")
	Terrain.zone = "eau"
	var nul := true
	for i in 200:
		nul = nul and Terrain.crete_case(float(i)).is_empty()
	ok(nul, "pas de crête dans l'eau")
	Terrain.zone = "sable"
	PhysiqueRoulage.surface_forcee = "route"
	ok(Terrain.crete_case(0.0).is_empty() and Terrain.proba_crete() == 0.0, "route forcée (Kit) : pas de crête")
	PhysiqueRoulage.surface_forcee = ""
	var c0: Array = []
	for i in 50:
		c0 = Terrain.crete_case(float(i))
		if not c0.is_empty():
			break
	var lev: float = float(c0[0]) + float(c0[1])
	ok(absf(Terrain.crete(lev - 0.001) - float(c0[3])) < 0.01 and Terrain.crete(float(c0[0]) - 0.1) == 0.0, "lèvre au sommet, rien avant la crête")
	ok(float(c0[3]) <= 0.4 * float(c0[1]) * 0.5 + 0.0001, "pente de lèvre plafonnée")
	# Conduite
	var calme := _rouler("sable", false, 120.0)
	var urg := _rouler("sable", true, 120.0)
	var eau := _rouler("eau", true, 60.0)
	print("  calme : ", calme)
	print("  urgence : ", urg)
	ok(eau.decollages == 0, "pas de saut sans crête")
	ok(urg.decollages > 0 and urg.atterrissages > 0, "urgence dans le sable : le convoi décolle sur les crêtes (%d sauts)" % urg.decollages)
	ok(urg.vol_max > 0.2 and urg.vol_max < 2.0, "durée de vol réaliste (%.2f s)" % urg.vol_max)
	ok(urg.h_max > 0.05 and urg.h_max < 2.0, "hauteur au-dessus du sol réaliste (%.2f m)" % urg.h_max)
	ok(urg.decollages >= calme.decollages, "on saute plus en fonçant qu'en roulant calmement (%d contre %d)" % [urg.decollages, calme.decollages])
	ok(urg.pv1 > urg.pv0 * 0.5, "les sauts usent sans détruire le convoi (%.0f → %.0f pv)" % [urg.pv0, urg.pv1])
	_remorques()
	_basculement()
	print("Échecs : ", echecs)
	quit(1 if echecs > 0 else 0)


func _remorque(m: CombatModele):
	var r := ConstructionLibre.nouvelle("Remorque")
	for x in range(2, 14):
		r = ConstructionLibre.peindre(r, Vector2i(x, 2), "acier")
	r = ConstructionLibre.poser_essieu(r, 4, "essieu_leger", "roue_moyenne")
	r = ConstructionLibre.poser_essieu(r, 11, "essieu_leger", "roue_moyenne")
	r = ConstructionLibre.en_remorque(r)
	var rv = m.creer_depuis_assemblage(r, "joueur", 0.0, "", 0)
	m.convoi.insert(1, rv)
	m._replacer(true)
	return rv


func _remorques() -> void:
	var m := CombatModele.new(7, {})
	m._prochain_x = INF
	var tete = m.convoi[0]
	var rv = _remorque(m)
	ok(m.tracteur_de(rv) == tete, "remorque attelée au véhicule de tête")
	m.vitesse_convoi = 6.0
	tete.garde = 1   # le tracteur part sur la voie de devant (comme un garde de flanc)
	var vmin := 0.0
	var vmax := -1.0
	for i in 60:   # 6 s : le tracteur passe sur la voie de devant, la remorque suit
		m._voies(m.DT)
		vmax = maxf(vmax, rv.voie_f)
		if i == 4:
			vmin = rv.voie_f
	ok(vmin < tete.voie_f - 0.05, "la remorque change de voie en retard sur son tracteur (%.2f contre %.2f)" % [vmin, tete.voie_f])
	ok(vmax > 1.01, "puis elle dépasse un peu la voie et revient : balancement (%.2f)" % vmax)
	ok(absf(rv.voie_f - 1.0) < 0.1, "le balancement s'amortit (%.2f)" % rv.voie_f)
	# lente : pas de dépassement
	var m2 := CombatModele.new(7, {})
	var t2 = m2.convoi[0]
	var r2 = _remorque(m2)
	m2.vitesse_convoi = 1.0
	t2.garde = 1
	var v2 := -1.0
	for i in 60:
		m2._voies(m2.DT)
		v2 = maxf(v2, r2.voie_f)
	ok(v2 < vmax, "à faible allure, le balancement est plus amorti (%.2f contre %.2f)" % [v2, vmax])
	# remorque lourde : balancement nettement plus fort
	var m3 := CombatModele.new(7, {})
	var t3 = m3.convoi[0]
	var r3 = _remorque(m3)
	r3.profil["poids_kg"] = float(t3.profil.get("poids_kg", 5000.0))
	m3.vitesse_convoi = 6.0
	t3.garde = 1
	var v3 := -1.0
	for i in 60:
		m3._voies(m3.DT)
		v3 = maxf(v3, r3.voie_f)
	ok(v3 > vmax + 0.05, "remorque aussi lourde que le tracteur : balancement plus fort (%.2f contre %.2f)" % [v3, vmax])
	# poussée en descente : freinage réduit
	var P_plat: Dictionary = m._params_conduite([tete, rv])
	var x_desc := -1.0
	for k in 4000:
		if Terrain.pente(float(k)) < -0.03:
			x_desc = float(k)
			break
	m.x_tete = x_desc
	var P_desc: Dictionary = m._params_conduite([tete, rv])
	ok(x_desc > 0.0 and float(P_desc.masse_f) < float(P_plat.masse_f), "en descente, la remorque pousse : freinage réduit (%.2f contre %.2f)" % [float(P_desc.masse_f), float(P_plat.masse_f)])


func _basculement() -> void:
	ok(Transmission.bascule(0.4, 0.5) and not Transmission.bascule(1.2, 0.5) and not Transmission.bascule(99.0, 3.0) and not Transmission.bascule(0.4, -0.5),
		"basculement : seulement si la charge dépasse la stabilité d'un véhicule de la grille")
	var m := CombatModele.new(7, {})
	m._prochain_x = INF
	var v = m.convoi[0]
	v.profil["stabilite"] = 0.3   # véhicule de la grille au centre de gravité très haut
	m.trans.accel = -4.5
	m.vider_evenements()
	m._tenue(m.DT, 6.0, [v])
	var ev := m.vider_evenements().filter(func(e): return e.t == "bascule")
	ok(ev.size() == 1 and bool(ev[0].avant), "freinage brusque : le véhicule instable pique du nez")
	m._tenue(m.DT, 6.0, [v])
	ok(m.vider_evenements().filter(func(e): return e.t == "bascule").is_empty(), "pas de basculement à répétition (délai)")
	var m2 := CombatModele.new(7, {})
	var v2 = m2.convoi[0]
	m2.trans.accel = -4.5
	m2._tenue(m2.DT, 6.0, [v2])
	ok(m2.vider_evenements().filter(func(e): return e.t == "bascule").is_empty(), "un véhicule du catalogue ne bascule pas")
