# Couche 1 de la vue : dessin du monde, effets, personnages, panneau d'état, sons.
extends "res://scripts/combat/vue_base.gd"


# --- Événements et effets --------------------------------------------------
func _evenement(e: Dictionary) -> void:
	match e.t:
		"tir":
			var tireur = m.trouver(e.de)
			if tireur == null or m.projectiles.is_empty():
				return
			var n = noeuds.get(e.de)
			if n is VehiculeDessin:
				n.tirer("canon" if e.classe == "canon" else "mitrailleuse")
			var a: Vector2 = m.projectiles.back().a
			_bouffees.append({"p": a, "age": 0.0, "grand": e.classe == "canon"})
			var joueur: bool = (tireur is CombatModele.Veh and tireur.camp == "joueur") or (tireur is CombatModele.Bat and tireur.statut == "neutralise")
			if e.classe == "canon":
				_son("sfx_tir_canon", 0.0 if joueur else -6.0)
			elif _temps - _t_son.mitrailleuse > 0.35:
				_t_son.mitrailleuse = _temps
				_son("sfx_tir_mitrailleuse", -6.0 if joueur else -11.0)
		"impact":
			var p := Vector2(e.x, e.y)
			if e.touche and e.reel:
				_etincelles.append({"p": p, "age": 0.0, "gros": e.classe == "canon"})
				if e.ricoche:
					_ricochets.append({"p": p, "age": 0.0, "sens": 1.0 if _rng.randf() < 0.5 else -1.0})
				if e.sur_joueur and _temps - _t_son.impact > 0.25:
					_t_son.impact = _temps
					_son("sfx_impact_blindage", -4.0)
			elif e.touche:
				_etincelles.append({"p": p, "age": 0.0, "gros": false})
			else:
				_poussieres.append({"p": Vector2(e.x, maxf(e.y, 0.0)), "age": 0.0, "gros": e.classe == "canon"})
				if e.classe == "canon":
					_explosions.append({"p": p, "age": 0.0, "taille": 0.7})
		"meute":
			_son("sfx_meute", -3.0)
		"pillards":
			var so2 := get_node_or_null("/root/Son")
			if so2 and _audio_ok and _temps - _t_son.voix > 25.0:
				_t_son.voix = _temps
				so2.voix("voix_pillards")
		"nuit_tombe":
			_son("sfx_nuee", -4.0)
		"marteau":
			_son("sfx_atelier", -9.0)
		"voyageur", "secteur", "quete":
			_son("sfx_radio" if e.t == "voyageur" else "sfx_depart_convoi", -4.0)
		"mort":
			_etincelles.append({"p": Vector2(e.x, 0.9), "age": 0.0, "gros": false})
		"mine":
			_explosions.append({"p": Vector2(e.x, 0.3), "age": 0.0, "taille": 2.2})
			_son("sfx_explosion")
		"mines":
			_son("sfx_atelier", -4.0)
		"poste":
			_son("sfx_radio", -6.0)
		"contact":
			if e.ennemi:
				if _temps - _t_son.voix > 25.0:
					_t_son.voix = _temps
					var so := get_node_or_null("/root/Son")
					if so and _audio_ok:
						so.voix("voix_pillards")
			else:
				_son("sfx_radio", -4.0)
		"repare":
			_son("sfx_atelier", -2.0)
		"rejoint":
			_son("sfx_depart_convoi", -2.0)
		"casse":
			var v = m.trouver(e.uid)
			if v != null:
				_explosions.append({"p": _ancre(v, e.piece), "age": 0.0, "taille": 1.1})
		"epave":
			var v = m.trouver(e.uid)
			if v != null:
				_explosions.append({"p": _centre_veh(v), "age": 0.0, "taille": 2.6})
				_son("sfx_explosion")

func _vieillir(delta: float) -> void:
	for l in [_etincelles, _explosions, _bouffees, _poussieres, _ricochets]:
		for x in l:
			x.age += delta
	for q in _poussiere_veh:
		q.age += delta
	_poussiere_veh = _poussiere_veh.filter(func(q): return q.age < 0.9)
	_poussieres = _poussieres.filter(func(x): return x.age < 0.7)
	_ricochets = _ricochets.filter(func(x): return x.age < 0.35)
	_etincelles = _etincelles.filter(func(x): return x.age < 0.3)
	_explosions = _explosions.filter(func(x): return x.age < 1.4)
	_bouffees = _bouffees.filter(func(x): return x.age < 0.1)

func _loup(c: CanvasItem, pied: Vector2, dir: float, phase: float, mort: bool, teinte: Color) -> void:
	var k := ppm
	var d := dir
	if mort:
		c.draw_colored_polygon(PackedVector2Array([pied + Vector2(-0.6 * k, 0), pied + Vector2(-0.5 * k, -0.28 * k), pied + Vector2(0.5 * k, -0.25 * k), pied + Vector2(0.7 * k, 0)]), teinte.darkened(0.4))
		return
	var courir: float = sin(phase)
	for j in 4:
		var lx: float = (-0.45 + 0.3 * j) * d
		var pat: float = sin(phase + j * 1.6) * 0.28
		c.draw_line(pied + Vector2(lx * k, -0.5 * k), pied + Vector2((lx + pat * d) * k, -0.02 * k), teinte.darkened(0.25), maxf(2.0, k * 0.07))
	c.draw_colored_polygon(PackedVector2Array([pied + Vector2(-0.6 * d * k, -0.55 * k + courir * 0.03 * k), pied + Vector2(-0.3 * d * k, -0.95 * k), pied + Vector2(0.45 * d * k, -0.92 * k), pied + Vector2(0.65 * d * k, -0.6 * k), pied + Vector2(0.2 * d * k, -0.42 * k), pied + Vector2(-0.45 * d * k, -0.4 * k)]), teinte)
	c.draw_colored_polygon(PackedVector2Array([pied + Vector2(0.5 * d * k, -0.95 * k), pied + Vector2(0.95 * d * k, -0.75 * k), pied + Vector2(0.55 * d * k, -0.55 * k), pied + Vector2(0.4 * d * k, -0.72 * k)]), teinte.lightened(0.05))
	c.draw_line(pied + Vector2(0.55 * d * k, -0.98 * k), pied + Vector2(0.5 * d * k, -1.15 * k), teinte, maxf(2.0, k * 0.06))
	c.draw_line(pied + Vector2(-0.6 * d * k, -0.6 * k), pied + Vector2(-1.05 * d * k, -0.75 * k + courir * 0.08 * k), teinte, maxf(2.0, k * 0.07))
	c.draw_circle(pied + Vector2(0.72 * d * k, -0.74 * k), maxf(1.5, k * 0.04), Color(1.0, 0.3, 0.2))

func _dessiner_monde(c: CanvasItem) -> void:
	var f := get_theme_default_font()
	# Fantassins et animaux
	for p in m.monde.pietons:
		var xx: float = lerpf(p.x_prev, p.x, 0.0 if pause else _alpha)
		var pied := Vector2(terrain.ecran_x(xx), _sy(xx))
		var mort: bool = not p.actif()
		if mort and p.mort_t > 7.0:
			continue
		var marche: bool = absf(p.x - p.x_prev) > 0.001
		var phase: float = _temps * (14.0 if p.animal else 7.0) + p.uid
		if p.animal:
			_loup(c, pied, p.dir if p.dir != 0.0 else -1.0, phase, mort, Color("#5A5650") if p.type == "loup" else Color("#6B5A44"))
		elif mort:
			c.draw_rect(Rect2(pied + Vector2(-0.7 * ppm, -0.22 * ppm), Vector2(1.4 * ppm, 0.22 * ppm)), Color(0.18, 0.15, 0.12, 0.8))
		else:
			Silhouette.dessiner(c, pied, ppm, "pillard", {"phase": phase if marche else 0.0, "miroir": p.dir < 0.0, "peau": p.uid, "bras": "vise" if not marche else ""})
	# Lueur des feux allumés dans les bâtiments
	for b in m.batiments:
		if b.feu:
			var fl: float = 0.75 + 0.25 * sin(_temps * 13.0 + b.uid)
			for g in b.garnison:
				if g.pv > 0.0:
					var pf := _px(b.fenetre(g.slot))
					c.draw_circle(pf, ppm * 1.8, Color(1.0, 0.55, 0.2, 0.12 * fl))
					c.draw_circle(pf, ppm * 0.7, Color(1.0, 0.7, 0.3, 0.35 * fl))
	# Voyageurs au bord de la route
	for v in m.monde.pnj:
		var pv := Vector2(terrain.ecran_x(v.x), _sy(v.x))
		var parti: bool = v.statut == "parti"
		Silhouette.dessiner(c, pv, ppm, "survivant", {"phase": _temps * 7.0 if parti else 0.0, "miroir": parti, "peau": v.peau + 1})
		if v.statut == "attend":
			var hb: float = pv.y - 2.6 * ppm - 5.0 * sin(_temps * 3.0)
			c.draw_circle(Vector2(pv.x, hb), 17.0, C_ACCENT)
			c.draw_string(f, Vector2(pv.x - 8, hb + 9), "!", HORIZONTAL_ALIGNMENT_CENTER, 16, 26, Color("#1A1A18"))
			if v.type == "marchand":
				c.draw_rect(Rect2(pv + Vector2(0.8 * ppm, -0.9 * ppm), Vector2(1.6 * ppm, 0.7 * ppm)), Color("#6A5238"))
				c.draw_circle(pv + Vector2(1.2 * ppm, -0.15 * ppm), 0.28 * ppm, Color("#2A2622"))
				c.draw_circle(pv + Vector2(2.0 * ppm, -0.15 * ppm), 0.28 * ppm, Color("#2A2622"))

func _secteur(c: CanvasItem, ctr: Vector2, r: float, a0: float, a1: float, col: Color) -> void:
	var pts := PackedVector2Array([ctr])
	for i in 25:
		pts.append(ctr + Vector2.from_angle(lerpf(a0, a1, i / 24.0)) * r)
	c.draw_colored_polygon(pts, col)

func _horloge(c: CanvasItem) -> void:
	var ctr := Vector2(size.x * 0.5, 168.0)
	var r := 46.0
	var w = m.monde
	var jour_len: float = 1.0 - (MondeJeu.AUBE - MondeJeu.CREPUSCULE)
	var d: float = fposmod(w.heure - MondeJeu.AUBE, 1.0)
	var phi: float = d / jour_len * PI if d < jour_len else PI + (d - jour_len) / (1.0 - jour_len) * PI
	var a0: float = -PI / 2.0 - phi
	c.draw_circle(ctr, r + 5.0, Color(0, 0, 0, 0.6))
	_secteur(c, ctr, r, a0, a0 + PI, Color("#8FC3E8"))
	_secteur(c, ctr, r, a0 + PI, a0 + TAU, Color("#12163A"))
	var ps := ctr + Vector2.from_angle(a0 + PI * 0.5) * r * 0.55
	c.draw_circle(ps, r * 0.2, Color("#FFD84A"))
	for k in 8:
		c.draw_line(ps + Vector2.from_angle(k * TAU / 8.0) * r * 0.27, ps + Vector2.from_angle(k * TAU / 8.0) * r * 0.37, Color("#FFD84A"), 2.0)
	var pl := ctr + Vector2.from_angle(a0 + PI * 1.5) * r * 0.55
	c.draw_circle(pl, r * 0.2, Color("#E8ECF8"))
	c.draw_circle(pl + Vector2(r * 0.09, -r * 0.05), r * 0.18, Color("#12163A"))
	for k2 in 5:
		c.draw_circle(ctr + Vector2.from_angle(a0 + PI * (1.15 + 0.17 * k2)) * r * (0.75 if k2 % 2 == 0 else 0.35), 1.6, Color(1, 1, 0.9, 0.9))
	c.draw_arc(ctr, r, 0.0, TAU, 40, Color(0.95, 0.9, 0.8), 2.5)
	c.draw_colored_polygon(PackedVector2Array([ctr + Vector2(-11, -r - 26), ctr + Vector2(11, -r - 26), ctr + Vector2(0, -r - 6)]), Color("#F2EEE6"))
	c.draw_polyline(PackedVector2Array([ctr + Vector2(-11, -r - 26), ctr + Vector2(11, -r - 26), ctr + Vector2(0, -r - 6), ctr + Vector2(-11, -r - 26)]), Color(0, 0, 0, 0.8), 2.0)

func dessiner_fx(c: CanvasItem) -> void:
	var f := get_theme_default_font()
	var obs: float = m.monde.obscurite()
	if obs > 0.01:
		c.draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.04, 0.12, 0.2 * obs))
		for v in m.convoi:   # phares
			if v.actif() and not v.camoufle:
				var av := _px(Vector2(_rx(v) + v.longueur, 0.9))
				c.draw_colored_polygon(PackedVector2Array([av, av + Vector2(14.0 * ppm, -1.2 * ppm), av + Vector2(14.0 * ppm, 1.8 * ppm)]), Color(1.0, 0.95, 0.7, 0.16 * obs))
	_dessiner_monde(c)
	_horloge(c)
	# Fumée des véhicules endommagés et épaves
	for v in m.convoi + m.ennemis + m.epaves:
		var q: float = v.pieces.chassis.pv / v.pieces.chassis.max
		var feu: bool = v.statut == "epave"
		if q < 0.5 or feu:
			var base := _ancre(v, "moteur")
			var intens: float = 1.0 if feu else clampf((0.5 - q) * 3.0, 0.3, 1.0)
			for k in 5:
				var ph := fposmod(_temps * 0.55 + k * 0.2 + v.uid * 0.13, 1.0)
				var p := _px(base + Vector2(sin(k * 3.1 + ph * 3.0) * 0.4, ph * 3.5))
				var rr: float = (0.25 + ph * 0.9) * ppm
				c.draw_circle(p, rr, Color(0.12, 0.11, 0.1, 0.55 * (1.0 - ph) * intens))
			if feu and not v.butin_pris:
				var pf := _px(base)
				c.draw_circle(pf, ppm * (0.3 + 0.08 * sin(_temps * 14.0 + v.uid)), Color(1.0, 0.55, 0.15, 0.8))
	for b in m.batiments:
		if b.statut == "neutralise":
			for k in 4:
				var ph := fposmod(_temps * 0.5 + k * 0.25 + b.uid * 0.1, 1.0)
				var p := _px(Vector2(b.x + b.longueur * (0.25 + 0.15 * k), 1.5 + ph * 4.0))
				c.draw_circle(p, (0.4 + ph * 1.2) * ppm, Color(0.12, 0.11, 0.1, 0.5 * (1.0 - ph)))
	# Barre de vie et équipage : seulement pour NOS véhicules (l'état de l'ennemi reste inconnu)
	for v in m.convoi:
		if not v.actif():
			continue
		var D: Dictionary = VehiculeDessin.donnees().vehicules[v.type]
		var x0 := terrain.ecran_x(_rx(v))
		var top: float = _sy(_rx(v) + v.longueur * 0.5) - (float(D.hauteur) + 0.7) * ppm
		var w: float = v.longueur * ppm
		var q: float = v.pieces.chassis.pv / v.pieces.chassis.max
		c.draw_rect(Rect2(Vector2(x0, top), Vector2(w, 6)), Color(0, 0, 0, 0.6))
		c.draw_rect(Rect2(Vector2(x0, top), Vector2(w * q, 6)), couleur_etat(q))
		for k in v.equipage.size():
			c.draw_circle(Vector2(x0 + 6 + k * 12, top - 8), 4.0, C_VERT if v.equipage[k] > 0.0 else Color(0.35, 0.35, 0.35))
		if v.camo_voulu:
			var fr: float = 1.0 if v.camoufle else clampf(v.camo_t / CombatModele.donnees().embuscade.camo_s, 0.0, 1.0)
			var cam := Rect2(Vector2(x0 - 4, _sy(_rx(v) + v.longueur * 0.5) - (float(D.hauteur) + 0.3) * ppm), Vector2(w + 8, (float(D.hauteur) + 0.3) * ppm))
			c.draw_rect(cam, Color(0.25, 0.32, 0.18, 0.78 * fr))
			for k in 9:
				c.draw_circle(cam.position + Vector2(cam.size.x * (k + 0.5) / 9.0, cam.size.y * (0.2 + 0.5 * fposmod(k * 0.37, 1.0))), ppm * 0.45, Color(0.18, 0.26, 0.12, 0.8 * fr))
		if v.uid == selection:
			var cx := x0 + w * 0.5
			c.draw_colored_polygon(PackedVector2Array([Vector2(cx - 10, top - 34), Vector2(cx + 10, top - 34), Vector2(cx, top - 20)]), C_ACCENT)
	# Poussière soulevée par les véhicules en marche
	if m.vitesse_convoi != 0.0 and not pause:
		for v in m.convoi:
			if v.actif() and _rng.randf() < 0.35:
				_poussiere_veh.append({"p": Vector2(_rx(v) + 0.3, 0.2), "age": 0.0})
	for q in _poussiere_veh:
		var kq: float = q.age / 0.9
		c.draw_circle(_px(q.p) + Vector2(-kq * ppm * 1.6, -kq * ppm * 0.7), ppm * (0.2 + 0.5 * kq), Color(0.7, 0.6, 0.45, 0.35 * (1.0 - kq)))
	# Mines posées (la LED rouge clignote quand elles sont armées)
	for mn in m.mines:
		var pm := _px(Vector2(mn.x, 0.0))
		c.draw_rect(Rect2(pm + Vector2(-0.35, -0.12) * ppm, Vector2(0.7, 0.2) * ppm), Color("#3A3A32"))
		if mn.armee and fmod(_temps, 1.0) < 0.2:
			c.draw_circle(pm + Vector2(0, -0.15 * ppm), maxf(2.0, ppm * 0.07), C_ROUGE)
	# Équipages en marche vers un bâtiment ou un véhicule
	for t in m.transits:
		var vv = m.trouver(t.veh)
		var bb = m.trouver(t.bat)
		if vv == null or bb == null:
			continue
		var d0: float = vv.x + vv.longueur * 0.5
		var d1: float = bb.x + bb.longueur * 0.5
		if t.mode == "rembarque":
			var tmp := d0
			d0 = d1
			d1 = tmp
		var fr2: float = clampf(1.0 - t.restant / maxf(t.T, 0.1), 0.0, 1.0)
		var gx: float = lerpf(d0, d1, fr2)
		for k in t.pvs.size():
			var xx: float = gx - signf(d1 - d0) * k * 0.9
			Silhouette.dessiner(c, Vector2(terrain.ecran_x(xx), _sy(xx)), ppm, "survivant",
				{"phase": _temps * 7.0 + k, "miroir": d1 < d0, "peau": k + 3})
	# Butin à récupérer
	for cc in m.epaves + m.batiments:
		var libre: bool = (cc is CombatModele.Veh and not cc.butin_pris) or (cc is CombatModele.Bat and cc.statut == "neutralise" and not cc.butin_pris)
		if libre:
			var h: float = 2.0 if cc is CombatModele.Veh else cc.hauteur
			var p := Vector2(terrain.ecran_x(_rx(cc) + cc.longueur * 0.5), _sy(_rx(cc) + cc.longueur * 0.5) - (h + 1.3) * ppm - 4.0 * sin(_temps * 3.0))
			c.draw_rect(Rect2(p - Vector2(10, 10), Vector2(20, 20)), C_ACCENT)
			c.draw_string(f, p + Vector2(-10, 7), "$", HORIZONTAL_ALIGNMENT_CENTER, 20, 18, Color("#1A1A18"))
	if not m.fouille_en_cours.is_empty():
		var cible = m.trouver(m.fouille_en_cours.uid)
		if cible != null:
			var fr: float = 1.0 - m.fouille_en_cours.restant / m.fouille_en_cours.total
			var h2: float = 2.0 if cible is CombatModele.Veh else cible.hauteur
			var p2 := Vector2(terrain.ecran_x(_rx(cible) + cible.longueur * 0.5), _sy(_rx(cible) + cible.longueur * 0.5) - (h2 + 2.4) * ppm)
			c.draw_rect(Rect2(p2 - Vector2(50, 7), Vector2(100, 14)), Color(0, 0, 0, 0.7))
			c.draw_rect(Rect2(p2 - Vector2(48, 5), Vector2(96 * fr, 10)), C_ACCENT)
			c.draw_string(f, p2 + Vector2(-60, -14), "Fouille", HORIZONTAL_ALIGNMENT_CENTER, 120, 20, C_TEXTE)
	_dessiner_persos(c)
	_dessiner_panneau(c)
	# Balles et obus en vol : trajectoire du modèle (bouche de l'arme -> point d'impact)
	for pr in m.projectiles:
		var tt: float = clampf((pr.t + (0.0 if pause else _alpha * CombatModele.DT)) / pr.T, 0.0, 1.0)
		var dist: float = pr.a.distance_to(pr.b)
		var arc: float = (0.03 if pr.classe == "canon" else (0.012 if pr.classe == "fusil" else 0.004)) * dist
		var t0: float = maxf(0.0, tt - (3.2 if pr.classe != "canon" else 2.0) / maxf(dist, 1.0))
		var pa: Vector2 = pr.a.lerp(pr.b, tt) + Vector2(0, sin(PI * tt) * arc)
		var pb: Vector2 = pr.a.lerp(pr.b, t0) + Vector2(0, sin(PI * t0) * arc)
		var sa := _px(pa)
		var sb := _px(pb)
		if pr.classe == "canon":
			c.draw_line(sb, sa, Color(0.8, 0.8, 0.75, 0.35), maxf(3.0, ppm * 0.14))
			c.draw_line(sb.lerp(sa, 0.4), sa, Color(1.0, 0.75, 0.3, 0.95), maxf(4.0, ppm * 0.12))
			c.draw_circle(sa, maxf(3.5, ppm * 0.1), Color(1.0, 0.95, 0.7))
		elif pr.classe == "fusil":
			c.draw_line(sb, sa, Color(1.0, 1.0, 0.9, 0.85), 2.0)
		else:
			c.draw_line(sb, sa, Color(1.0, 0.85, 0.35, 0.35), maxf(5.0, ppm * 0.1))
			c.draw_line(sb, sa, Color(1.0, 0.95, 0.6, 1.0), 2.0)
	for s2 in _poussieres:
		var k2: float = s2.age / 0.7
		var pd := _px(s2.p)
		var rr: float = ppm * (0.25 if not s2.gros else 0.5) * (0.5 + k2)
		c.draw_circle(pd + Vector2(0, -k2 * ppm * 0.6), rr, Color(0.55, 0.46, 0.34, 0.6 * (1.0 - k2)))
		c.draw_circle(pd + Vector2(rr * 0.8, -k2 * ppm * 0.3), rr * 0.7, Color(0.5, 0.42, 0.3, 0.5 * (1.0 - k2)))
	for s3 in _ricochets:
		var k3: float = s3.age / 0.35
		var pr3 := _px(s3.p)
		c.draw_line(pr3, pr3 + Vector2(s3.sens * 70.0 * k3, -110.0 * k3 + 90.0 * k3 * k3), Color(1.0, 0.9, 0.5, 1.0 - k3), 2.5)
	for s in _etincelles:
		var p := _px(s.p)
		var fade2: float = 1.0 - s.age / 0.3
		var gros: bool = s.get("gros", false)
		var nb := 9 if gros else 6
		for k in nb:
			c.draw_line(p, p + Vector2.from_angle(k * TAU / nb + s.age * 3) * ((9 if gros else 6) + (34 if gros else 22) * s.age), Color(1, 0.8, 0.3, fade2), 2.0)
	for s in _bouffees:
		c.draw_circle(_px(s.p), 14.0 if s.get("grand", false) else 8.0, Color(1.0, 0.9, 0.5, 0.9))
	for x in _explosions:
		var p := _px(x.p)
		var k: float = x.age / 1.4
		c.draw_circle(p, x.taille * ppm * (0.4 + k * 1.2), Color(1.0, 0.55 - 0.3 * k, 0.15, 0.85 * (1.0 - k)))
		c.draw_circle(p + Vector2(0, -k * ppm), x.taille * ppm * (0.3 + k), Color(0.15, 0.14, 0.13, 0.5 * (1.0 - k)))


# --- Panneau d'état d'un véhicule (au toucher) ------------------------------
func _dessiner_panneau(c: CanvasItem) -> void:
	_icones.clear()
	if ouvert == 0:
		return
	var v = m.trouver(ouvert)
	if not (v is CombatModele.Veh) or v.statut == "epave" or (v.camp == "ennemi" and v.actif()):
		ouvert = 0
		return
	var D: Dictionary = VehiculeDessin.donnees().vehicules[v.type]
	var casses := []
	for id in v.pieces:
		if v.pieces[id].pv < v.pieces[id].max - 0.5:
			casses.append(id)
	var rejoindre: bool = v.recuperable() and v.piece_ok("chassis") and v.piece_ok("roulement") and v.piece_ok("moteur") and m._mecanicien_possible(v)
	var n: int = casses.size() + (1 if rejoindre else 0)
	if n == 0:
		return   # rien de cassé : rien ne s'affiche
	var t := 66.0
	var largeur: float = casses.size() * (t + 8.0) + (198.0 if rejoindre else 0.0) - 8.0
	var x0: float = terrain.ecran_x(_rx(v)) + v.longueur * ppm * 0.5 - largeur * 0.5
	x0 = clampf(x0, 12.0, size.x - largeur - 12.0)
	var y0: float = maxf(150.0, _sy(_rx(v) + v.longueur * 0.5) - (float(D.hauteur) + 0.7) * ppm - 120.0)
	var f := get_theme_default_font()
	for i in casses.size():
		var id: String = casses[i]
		var pq: float = v.pieces[id].pv / v.pieces[id].max
		var r := Rect2(Vector2(x0 + i * (t + 8.0), y0), Vector2(t, t))
		var col: Color = C_ROUGE if pq <= 0.0 else C_ORANGE
		var en_cours: bool = v.reparation and (v.rep_piece == id or (v.rep_piece == "" and m._piece_a_reparer(v) == id))
		c.draw_rect(r, Color(0.06, 0.065, 0.07, 0.92))
		c.draw_rect(r, Color("#5AA9E6") if en_cours else col, false, 4.0 if en_cours else 2.0)
		_glyphe(c, id, v, r.position + Vector2(t, t - 8.0) * 0.5, col)
		c.draw_rect(Rect2(r.position + Vector2(6, t - 9), Vector2(t - 12, 5)), Color(0, 0, 0, 0.7))
		c.draw_rect(Rect2(r.position + Vector2(6, t - 9), Vector2((t - 12) * pq, 5)), col)
		_icones.append({"rect": r, "uid": v.uid, "piece": id})
	if rejoindre:
		var r2 := Rect2(Vector2(x0 + casses.size() * (t + 8.0), y0), Vector2(190, t))
		c.draw_rect(r2, C_VERT.darkened(0.45))
		c.draw_rect(r2, C_VERT, false, 3.0)
		c.draw_string(f, r2.position + Vector2(0, 41), "Rejoindre le convoi", HORIZONTAL_ALIGNMENT_CENTER, r2.size.x, 20, Color.WHITE)
		_icones.append({"rect": r2, "uid": v.uid, "action": "rejoindre"})
	if not casses.is_empty():
		c.draw_string(f, Vector2(x0, y0 - 8.0), "Toucher une pièce : envoyer un mécanicien", HORIZONTAL_ALIGNMENT_LEFT, 460, 18, C_TEXTE)

func _glyphe(c: CanvasItem, id: String, v: CombatModele.Veh, p: Vector2, col: Color) -> void:
	var fond := Color(0.06, 0.065, 0.07)
	match CombatModele.genre_piece(id):
		"roulement":
			if v.chenille:
				c.draw_rect(Rect2(p + Vector2(-23, 2), Vector2(46, 17)), col)
				for k in 3:
					c.draw_circle(p + Vector2(-14 + k * 14, 10.5), 5.0, fond)
			else:
				c.draw_circle(p + Vector2(0, 4), 16, col)
				c.draw_circle(p + Vector2(0, 4), 7, fond)
				c.draw_circle(p + Vector2(0, 4), 3, col)
		"moteur":
			c.draw_rect(Rect2(p + Vector2(-17, -6), Vector2(34, 22)), col)
			c.draw_rect(Rect2(p + Vector2(-13, -14), Vector2(8, 8)), col)
			c.draw_rect(Rect2(p + Vector2(5, -14), Vector2(8, 8)), col)
			c.draw_circle(p + Vector2(0, 5), 6, fond)
		"suspension":
			var pts := PackedVector2Array()
			for k in 7:
				pts.append(p + Vector2((8.0 if k % 2 else -8.0), -16 + k * 5.5))
			c.draw_polyline(pts, col, 4.0)
			c.draw_line(p + Vector2(-14, -18), p + Vector2(14, -18), col, 4.0)
			c.draw_line(p + Vector2(-14, 18), p + Vector2(14, 18), col, 4.0)
		"cabine":
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(-19, 15), p + Vector2(-19, -2), p + Vector2(-9, -15), p + Vector2(10, -15), p + Vector2(19, -2), p + Vector2(19, 15)]), col)
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(-11, -2), p + Vector2(-6, -10), p + Vector2(8, -10), p + Vector2(13, -2)]), fond)
		"chassis":
			c.draw_rect(Rect2(p + Vector2(-23, -5), Vector2(46, 17)), col)
			c.draw_rect(Rect2(p + Vector2(-17, -11), Vector2(22, 7)), col)
			c.draw_circle(p + Vector2(-13, 14), 5, fond)
			c.draw_circle(p + Vector2(13, 14), 5, fond)
		_:
			var wid: String = v.profil.armes[int(id.substr(1))]
			if CombatModele.donnees().armes[wid].classe == "canon":
				c.draw_rect(Rect2(p + Vector2(-4, -5), Vector2(30, 9)), col)
				c.draw_rect(Rect2(p + Vector2(-20, -10), Vector2(18, 20)), col)
				c.draw_circle(p + Vector2(-11, 0), 5, fond)
			else:
				c.draw_line(p + Vector2(-4, -6), p + Vector2(24, -6), col, 4.0)
				c.draw_rect(Rect2(p + Vector2(-16, -12), Vector2(14, 12)), col)
				c.draw_line(p + Vector2(-9, 0), p + Vector2(-17, 16), col, 3.0)
				c.draw_line(p + Vector2(-9, 0), p + Vector2(0, 16), col, 3.0)


# --- Petits personnages : fouille et réparation ----------------------------
func _equipiers() -> int:
	var n := 0
	for v in m.convoi:
		n += v.equipage_vivant()
	return n

func _origine_x(cx: float) -> float:
	var meilleur := cx
	var d_min := INF
	for v in m.convoi:
		var ctr: float = _rx(v) + v.longueur * 0.5
		if absf(ctr - cx) < d_min:
			d_min = absf(ctr - cx)
			meilleur = ctr
	return meilleur

func _maj_persos(delta: float) -> void:
	var voulus := {}
	if not m.fouille_en_cours.is_empty():
		var cible = m.trouver(m.fouille_en_cours.uid)
		if cible != null:
			var cx: float = _rx(cible) + cible.longueur * 0.5
			voulus["fouille"] = {"cible": cx, "variante": "survivant", "n": clampi(_equipiers(), 1, 2), "origine": _origine_x(cx)}
	if m.ordres.marche == "halte":
		for v in m.convoi + m.epaves:
			if v.reparation and v.rep_pret >= 0.0:
				var id: String = m._piece_a_reparer(v)
				if id != "":
					var cx: float = _ancre(v, id).x
					voulus["rep%d" % v.uid] = {"cible": cx, "variante": "mecano", "n": 1, "origine": _origine_x(_rx(v) + v.longueur * 0.5)}
	for cle in voulus:
		var d: Dictionary = voulus[cle]
		var existants := _persos.filter(func(q): return q.cle == cle)
		for q in existants:
			q.mode = "va" if q.mode == "retour" else q.mode
			q.cible = d.cible + (q.idx - (d.n - 1) * 0.5) * 1.1
		for i in range(existants.size(), d.n):
			_persos.append({"cle": cle, "idx": i, "variante": d.variante, "x": d.origine, "origine": d.origine,
				"cible": d.cible + (i - (d.n - 1) * 0.5) * 1.1, "mode": "va", "phase": 0.0, "dir": 1.0})
	for q in _persos:
		if not voulus.has(q.cle):
			q.mode = "retour"
			q.origine = _origine_x(q.x)
		var but: float = q.origine if q.mode == "retour" else q.cible
		var dx: float = but - q.x
		if absf(dx) > 0.15:
			q.x += signf(dx) * minf(2.6 * delta, absf(dx))
			q.dir = signf(dx)
			q.phase += delta * 7.0
		elif q.mode == "va":
			q.mode = "travaille"
		elif q.mode == "travaille":
			q.phase += delta * 7.0
		else:
			q.mode = "fini"
	_persos = _persos.filter(func(q): return q.mode != "fini")

func _dessiner_persos(c: CanvasItem) -> void:
	for q in _persos:
		var x: float = q.x
		var pied := Vector2(terrain.ecran_x(x), _sy(x))
		var marche: bool = q.mode != "travaille"
		Silhouette.dessiner(c, pied, ppm, q.variante, {"phase": q.phase if marche else 0.0, "miroir": q.dir < 0.0,
			"travaille": q.phase if not marche else 0.0, "peau": q.idx})


# --- Sons ------------------------------------------------------------------
func _maj_sons() -> void:
	if not _audio_ok:
		return
	var so := get_node_or_null("/root/Son")
	if so == null:
		return
	var amb: String = "amb_desert_nuit" if m.monde.obscurite() > 0.5 else "amb_desert_jour"
	if amb != _amb_nom:
		_amb_nom = amb
		so.ambiance(amb)
	if m.monde.obscurite() > 0.6 and not pause:
		_t_nuit -= get_process_delta_time()
		if _t_nuit <= 0.0:
			_t_nuit = _rng.randf_range(14.0, 30.0)
			_son("sfx_meute" if _rng.randf() < 0.6 else "sfx_nuee", -10.0)
	var lourd = null
	for v in m.convoi:
		if v.actif() and (lourd == null or v.profil.metal > lourd.profil.metal):
			lourd = v
	var nom := ""
	if lourd != null and m.vitesse_convoi != 0.0 and not pause and not m.fini:
		nom = MOTEURS.get(lourd.type, "")
	so.moteur(nom)
	if m.ordres.marche != _marche_prec:
		if m.ordres.marche == "avancer":
			_son("sfx_depart_marche", -4.0)
		_marche_prec = m.ordres.marche
