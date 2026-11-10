extends SceneTree
# Camp de réparation branché sur le modèle de combat (DEV-018) : essieu cassé -> camp -> attaques -> réparation.
#   godot --headless --path game -s res://tests/test_camp.gd
var echecs := 0


func ok(c: bool, t: String) -> void:
	print("OK  " if c else "ÉCHEC ", t)
	if not c:
		echecs += 1


func _avancer(m: CombatModele, s: float) -> void:
	for i in int(s / CombatModele.DT):
		m.avancer()


func _neuf(graine: int) -> Array:
	var m := CombatModele.new(graine)
	m._prochain_x = INF
	m.stocks.fuel_l = 300.0
	m.monde._assaut_t = 1.0e9
	var v = m.convoi[0]
	return [m, v]


func _init() -> void:
	var t := _neuf(5)
	var m: CombatModele = t[0]
	var v = t[1]
	v.pieces.roulement.pv = 0.0   # essieu cassé en combat
	ok(not v.mobile(), "essieu cassé : le véhicule est immobilisé")
	var opts := m.camp_options(v.uid)
	var o_ess: Dictionary = opts.filter(func(o): return o.op == "changer_essieu")[0]
	ok(not bool(o_ess.ok) and String(o_ess.raison) != "", "sans pièce de rechange : option grisée (%s)" % o_ess.raison)
	ok(not m.camp_etablir(v.uid, "changer_essieu", o_ess.params), "pas de camp sans pièce")
	m.pieces_stock.append({"piece": "essieu_lourd", "etat": 0.9})
	m.pieces_stock.append({"piece": "roue_grande", "etat": 0.8})
	o_ess = m.camp_options(v.uid).filter(func(o): return o.op == "changer_essieu")[0]
	ok(bool(o_ess.ok), "avec pièces en réserve : option possible (durée %d s)" % int(o_ess.duree_s))
	ok(m.camp_etablir(v.uid, "changer_essieu", o_ess.params), "camp établi")
	ok(m.camp_actif() and m.ordres.marche == "halte", "le convoi est à l'arrêt")
	ok(not m.camp_etablir(v.uid, "changer_essieu", o_ess.params), "un seul camp à la fois")
	var duree := float(m.camp_rep.camp.duree_s)
	var attaques := 0
	var t_max := duree * 3.0
	var s := 0.0
	var fini := false
	while s < t_max:
		m.avancer()
		s += CombatModele.DT
		attaques = maxi(attaques, m.ennemis.size())
		for e in m.ennemis:   # les défenseurs repoussent les attaques : on neutralise les ennemis pour tester le temps de camp
			e.statut = "detruit"
		m.ennemis = m.ennemis.filter(func(e): return e.actif())
		if not m.camp_actif():
			fini = true
			break
	ok(fini, "camp terminé en %d s (réparation %d s)" % [int(s), int(duree)])
	ok(s >= duree, "le camp dure au moins la durée de réparation")
	ok(v.mobile() and v.ratio("roulement") > 0.5, "essieu changé : le véhicule roule de nouveau (%.2f)" % v.ratio("roulement"))
	ok(m.pieces_stock.any(func(p): return p.piece == "roue_grande"), "roues de la réserve conservées")
	ok(not m.pieces_stock.any(func(p): return p.piece == "essieu_lourd" and is_equal_approx(float(p.etat), 0.9)), "essieu de rechange consommé")
	# Attaques : un camp long en reçoit, et elles retardent les travaux
	var t2 := _neuf(9)
	var m2: CombatModele = t2[0]
	var v2 = t2[1]
	v2.pieces.moteur.pv = 0.0
	m2.pieces_stock.append({"piece": "moteur_4cyl_moyen", "etat": 0.8})
	var o_mot: Dictionary = m2.camp_options(v2.uid).filter(func(o): return o.op == "changer_moteur")[0]
	ok(bool(o_mot.ok), "moteur de rechange : option possible (%s)" % o_mot.raison)
	ok(m2.camp_etablir(v2.uid, "changer_moteur", o_mot.params), "camp moteur établi")
	var vu := false
	var s2 := 0.0
	var d2 := float(m2.camp_rep.camp.duree_s)
	while s2 < d2 * 3.0 and m2.camp_actif():
		m2.avancer()
		s2 += CombatModele.DT
		if not m2.ennemis.is_empty():
			vu = true
			for e in m2.ennemis:
				e.statut = "detruit"
			m2.ennemis = m2.ennemis.filter(func(e): return e.actif())
	ok(vu, "une attaque est tombée sur le camp")
	ok(s2 > d2, "les attaques ont allongé le camp (%d s pour %d s)" % [int(s2), int(d2)])
	ok(not m2.camp_actif() and v2.mobile(), "moteur remplacé après les attaques")
	# Pas de camp avec un ennemi en vue
	var t3 := _neuf(3)
	var m3: CombatModele = t3[0]
	m3.pieces_stock.append({"piece": "moteur_4cyl_moyen", "etat": 0.8})
	var e3 := m3.creer_vehicule("citroen_traction", "ennemi", m3.x_tete + 80.0)
	e3.mode = "approche"
	m3.ennemis.append(e3)
	ok(not m3.camp_etablir(m3.convoi[0].uid, "changer_moteur", {"moteur": "moteur_4cyl_moyen"}), "pas de camp avec un ennemi en vue")
	# Pannes en route (DEV-019) : déterministes, jamais destructrices, absentes sans l'option
	var t4 := _neuf(9)
	var m4: CombatModele = t4[0]
	var v4 = t4[1]
	m4.pannes_on = true
	m4._pannes()
	ok(m4._km_pannes >= 0, "pannes : recalage sur la position au départ")
	m4.appliquer_panne(v4, "essieu")
	ok(v4.pieces.roulement.pv <= v4.pieces.roulement.max * 0.4 + 0.001 and v4.pieces.roulement.pv > 0.0, "panne d'essieu : roues abîmées, pas détruites")
	var t5 := _neuf(9)
	var m5: CombatModele = t5[0]
	m5._pannes()
	m5.x_tete += 50000.0
	m5._pannes()
	ok(m5._km_pannes < 0, "sans l'option : aucune panne tirée")
	var u1 := []
	var u2 := []
	for k in 2:
		var tk := _neuf(11)
		var mk: CombatModele = tk[0]
		mk.pannes_on = true
		mk._pannes()
		mk.x_tete += 400000.0
		mk._pannes()
		var pv := []
		for vk in mk.convoi:
			for id in vk.pieces:
				pv.append(snappedf(float(vk.pieces[id].pv), 0.01))
		if k == 0: u1 = pv
		else: u2 = pv
	ok(u1 == u2, "pannes déterministes pour une graine")
	ok(str(u1) != "", "pannes tirées sur 400 km")
	# Oiseau rare (DEV-004) : de jour, il apparaît puis s'en va ; jamais la nuit
	var t6 := _neuf(4)
	var m6: CombatModele = t6[0]
	m6.monde.heure = 12.0
	m6.monde._oiseau(0.01)
	ok(m6.monde._oiseau_t >= 900.0, "oiseau : délai rare tiré (%d s)" % int(m6.monde._oiseau_t))
	m6.monde._oiseau_t = 0.001
	m6.monde._oiseau(0.01)
	ok(not m6.monde.oiseau.is_empty(), "oiseau : il traverse le ciel de jour")
	m6.monde._oiseau(20.0)
	ok(m6.monde.oiseau.is_empty(), "oiseau : il s'en va")
	m6.monde.heure = 1.0
	m6.monde._oiseau_t = 0.001
	m6.monde._oiseau(0.01)
	ok(m6.monde.oiseau.is_empty() or not m6.monde.nuit(), "oiseau : jamais la nuit")
	# Transformation dans la partie (DEV-016)
	var t7 := _neuf(6)
	var m7: CombatModele = t7[0]
	var v7 = t7[1]
	var cx := m7.transformation_contexte(v7.uid)
	ok(int(cx.niveau) == 0 and cx.has("reserve") and cx.has("metal"), "transformation : sur la route, niveau 0")
	m7.stocks.metal = 5.0
	var g7 := m7.grille_de(v7.uid)
	ok(not m7.transformer(v7.uid, g7, 50.0, 600.0) and absf(float(m7.stocks.metal) - 5.0) < 0.01, "transformation : refusée sans métal, rien ne change")
	m7.stocks.metal = 100.0
	ok(m7.transformer(v7.uid, g7, 30.0, 600.0), "transformation : grille identique acceptée")
	ok(absf(float(m7.stocks.metal) - 70.0) < 0.5, "transformation : métal des travaux retiré (%d)" % int(m7.stocks.metal))
	# Halte dans la nature (DEV-031) et caches (DEC-157)
	var t8 := _neuf(8)
	var m8: CombatModele = t8[0]
	ok(m8.halte_bivouac(true), "halte : le camp se monte")
	ok(not bool(m8.halte.pret), "halte : le camp n'est pas monté tout de suite")
	_avancer(m8, 30.0)
	ok(bool(m8.halte.get("pret", false)), "halte : camp monté après le délai")
	m8.monde.heure = 1.0
	ok(m8.halte_repos(), "halte : camper pour la nuit permet le repos")
	ok(m8.envoyer_eclaireurs(), "éclaireurs : partis")
	_avancer(m8, 25.0)
	ok(m8._eclaireurs_t <= 0.0 and m8.eclaireurs_rapport_texte().begins_with("Les éclaireurs"), "éclaireurs : rapport rendu")
	m8.stocks.fuel_l = 100.0
	ok(m8.cache_creer({"fuel_l": 40.0}) and absf(float(m8.stocks.fuel_l) - 60.0) < 0.01, "cache : 40 L enterrés")
	ok(not m8.cache_creer({"fuel_l": 500.0}), "cache : refusée au-delà des réserves")
	ok(m8.cache_proche() >= 0 and m8.cache_reprendre(), "cache : déterrée sur place")
	ok(m8.caches.is_empty(), "cache : retirée de la liste")
	var sv := m8.sauver()
	ok(sv.has("caches"), "cache : sauvegardée")
	m8.ordre_marche("avancer")
	_avancer(m8, 1.0)
	ok(m8.halte.is_empty(), "halte : levée quand le convoi repart")
	ok(m8.halte_garde() and m8.convoi[0].reparation, "surveillance : les mécaniciens réparent")
	# Berliet dans la grille (DEC-167)
	var gb := ConstructionLibre.convertir(Assemblage.de_type("berliet_gdr"), "berliet_gdr")
	ok(gb.has("berliet"), "Berliet : grille marquée")
	ok(not gb.berliet.fixes.is_empty() and ConstructionLibre.fixe_berliet(gb, "piece", gb.berliet.fixes[0]), "Berliet : cabine fixe")
	ok(ConstructionLibre.fixe_berliet(gb, "essieu", gb.berliet.essieu_av), "Berliet : essieu avant fixe")
	var autre_x := -1
	for e in gb.essieux:
		if int(e.x) != int(gb.berliet.essieu_av):
			autre_x = int(e.x)
	ok(autre_x >= 0 and not ConstructionLibre.fixe_berliet(gb, "essieu", autre_x), "Berliet : essieux arrière libres")
	ok(not ConstructionLibre.fixe_berliet(gb, "cases", gb.cases), "Berliet : châssis d'origine complet")
	ok(ConstructionLibre.fixe_berliet(gb, "cases", gb.cases.slice(1)), "Berliet : case d'origine retirée refusée")
	# Gazogène (DEC-158)
	var gw := ConstructionLibre.convertir(Assemblage.de_type("citroen_t23"), "citroen_t23")
	var s0: Dictionary = ConstructionLibre.analyser(gw).stats
	var gg := {}
	for y in range(0, 18):
		for x in range(0, 48):
			if gg.is_empty():
				gg = ConstructionLibre.poser(gw, "greffe_gazogene", Vector2i(x, y))
	ok(not gg.is_empty(), "gazogène : se pose sur le camion")
	if not gg.is_empty():
		var s1: Dictionary = ConstructionLibre.analyser(gg).stats
		ok(bool(s1.gazogene) and float(s1.conso) < float(s0.conso) * 0.5, "gazogène : consomme peu de carburant (%.2f → %.2f)" % [float(s0.conso), float(s1.conso)])
		ok(float(s1.vitesse) <= float(s0.vitesse), "gazogène : moins de puissance")
	# Bouton de marche (design du 10/11) : le geste est transmis et les chevrons s'étirent
	var bm := BoutonMarche.new()
	bm.size = Vector2(420, 112)
	var recu := []
	bm.geste.connect(func(dx): recu.append(dx))
	var bm_a := InputEventMouseButton.new()
	bm_a.button_index = MOUSE_BUTTON_LEFT
	bm_a.pressed = true
	bm_a.position = Vector2(100, 50)
	bm._gui_input(bm_a)
	var bm_b := InputEventMouseMotion.new()
	bm_b.position = Vector2(180, 50)
	bm._gui_input(bm_b)
	bm._process(0.5)
	ok(bm._ouv > 0.5, "bouton de marche : glisser à droite étire les chevrons vers la droite")
	var bm_c := InputEventMouseButton.new()
	bm_c.button_index = MOUSE_BUTTON_LEFT
	bm_c.pressed = false
	bm_c.position = Vector2(180, 50)
	bm._gui_input(bm_c)
	ok(recu.size() == 1 and absf(float(recu[0]) - 80.0) < 0.01, "bouton de marche : geste transmis (+80 px)")
	bm.etat = "recul"
	for i in 20:
		bm._process(0.1)
	ok(bm._ouv < -0.9, "bouton de marche : en marche arrière, chevrons étirés vers la gauche")
	bm.free()
	print("%d ÉCHEC(S)" % echecs if echecs else "TOUT OK")
	quit(1 if echecs else 0)
