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
				n.tirer("canon" if e.classe in ["canon", "mortier"] else "mitrailleuse")
			var a: Vector2 = m.projectiles.back().a
			_bouffees.append({"p": a, "age": 0.0, "grand": e.classe in ["canon", "mortier"]})
			var joueur: bool = (tireur is CombatModele.Veh and tireur.camp == "joueur") or (tireur is CombatModele.Bat and tireur.statut == "neutralise")
			if e.classe in ["canon", "mortier"]:
				_son("sfx_tir_canon", 0.0 if joueur else -6.0)
			elif _temps - _t_son.mitrailleuse > 0.35:
				_t_son.mitrailleuse = _temps
				_son("sfx_tir_mitrailleuse", -6.0 if joueur else -11.0)
		"impact":
			var p := Vector2(e.x, e.y)
			if e.touche and e.reel:
				_etincelles.append({"p": p, "age": 0.0, "gros": e.classe in ["canon", "mortier"]})
				if e.ricoche:
					_ricochets.append({"p": p, "age": 0.0, "sens": 1.0 if _rng.randf() < 0.5 else -1.0})
				if e.sur_joueur and _temps - _t_son.impact > 0.25:
					_t_son.impact = _temps
					_son("sfx_impact_blindage", -4.0)
			elif e.touche:
				_etincelles.append({"p": p, "age": 0.0, "gros": false})
			else:
				_poussieres.append({"p": Vector2(e.x, maxf(e.y, 0.0)), "age": 0.0, "gros": e.classe in ["canon", "mortier"]})
				if e.classe in ["canon", "mortier"]:
					_explosions.append({"p": p, "age": 0.0, "taille": 0.7})
		"choc":   # éperonnage, frottement entre voies (DEC-215, DEC-255) : gerbe d'étincelles, pièces arrachées
			_aide("008")
			var yl: float = 0.8 + CombatModele.voie_dy(float(e.get("voie", 0.0)))
			var pc := Vector2(float(e.x), yl)
			_etincelles.append({"p": pc, "age": 0.0, "gros": true})
			_explosions.append({"p": pc, "age": 0.0, "taille": 0.5 if e.fort else 0.3})
			_son("sfx_impact_blindage", 0.0)
			if bool(e.get("lat", false)):   # tôles qui frottent : traînée d'étincelles le long du flanc
				for k in 4:
					_etincelles.append({"p": pc + Vector2((k - 1.5) * 0.9, -0.2), "age": -0.08 * k, "gros": false})
			_lancer_debris(pc, 7 if e.fort else 4, bool(e.fort))
			if e.fort:
				_son("sfx_explosion", -9.0)
		"melee":   # bagarre sur le toit
			var ym: float = 1.7 + CombatModele.voie_dy(float(e.get("voie", 0.0)))
			_etincelles.append({"p": Vector2(float(e.x), ym), "age": 0.0, "gros": false})
			_gore(Vector2(float(e.x), ym), false, 5.0, float(e.get("voie", 0.0)))
			_son("sfx_impact_blindage", -10.0)
		"repousse":   # un pillard est jeté du plateau : il vole puis retombe sur la route
			var yr: float = 1.7 + CombatModele.voie_dy(float(e.get("voie", 0.0)))
			_debris.append({"p": Vector2(float(e.x), yr), "v": Vector2(_rng.randf_range(-2.5, 2.5), 3.5), "age": 0.0, "forme": "homme", "rot": 0.0, "vrot": _rng.randf_range(-7.0, 7.0), "taille": 1.0,
				"dy": CombatModele.voie_dy(float(e.get("voie", 0.0))), "cadavre": Gore.lire() >= 2, "vie": 6.0})
			_gore(Vector2(float(e.x), yr), false, 6.0, float(e.get("voie", 0.0)))
			_poussieres.append({"p": Vector2(float(e.x), 0.0), "age": 0.0, "gros": true})
			_son("sfx_impact_blindage", -4.0)
		"sang":   # un homme touché ou tué : sang, corps, membres (DEC-257)
			var ys: float = (1.7 if bool(e.get("toit", false)) else 1.3) + CombatModele.voie_dy(float(e.get("voie", 0.0)))
			_gore(Vector2(float(e.x) + _rng.randf_range(-1.2, 1.2), ys), bool(e.mort), float(e.fort), float(e.get("voie", 0.0)))
		"explosion":   # obus, cocktail Molotov, lance explosive, réservoir (DEC-220)
			var pe := Vector2(float(e.x), float(e.y))
			_explosions.append({"p": pe, "age": 0.0, "taille": float(e.taille)})
			if e.feu:
				_explosions.append({"p": pe + Vector2(0.3, 0.2), "age": 0.3, "taille": float(e.taille) * 0.6})
			_etincelles.append({"p": pe, "age": 0.0, "gros": true})
			if float(e.taille) >= 2.0:
				_son("sfx_explosion", -3.0)
		"crevaison":
			_etincelles.append({"p": Vector2(float(e.x), 0.2), "age": 0.0, "gros": true})
			_poussieres.append({"p": Vector2(float(e.x), 0.0), "age": 0.0, "gros": true})
			_son("sfx_impact_blindage", -6.0)
		"esquive":
			_poussieres.append({"p": Vector2(float(e.x), 0.0), "age": 0.0, "gros": false})
		"meute":
			_son("sfx_meute", -3.0)
		"pillards":
			var so2 := get_node_or_null("/root/Son")
			if so2 and _audio_ok and _temps - _t_son.voix > 25.0:
				_t_son.voix = _temps
				so2.voix("voix_pillards")
		"ville":
			match String(e.etat):
				"annonce":
					_son("sfx_radio", -6.0)
				"porte":
					_son("sfx_atelier", -8.0)
				"dedans":
					_aide("004")
					_ville_onglet = "accueil"
					_ville_ferme = false
					_dial_sig = ""
					call("_sauver_vue")   # point de reprise (défini dans vue_interface.gd)
				"depart", "sortie":
					_son("sfx_depart_convoi", -6.0)
		"mission":
			var so := get_node_or_null("/root/Son")
			match String(e.etat):
				"chargement":
					_aide("005")
					_son("sfx_atelier", -4.0)
				"rassemblement":
					if so and _audio_ok:
						so.musique("mus_tambours")   # tambours de guerre jusqu'à la livraison (tools/synth_tambours.py)
					_son("sfx_depart_convoi", -4.0)
				"livree", "echec":
					if so and _audio_ok:
						so.musique(_musique_partie())
					if String(e.etat) == "livree":
						_ville_onglet = "bilan"
						_ville_ferme = false
						_dial_sig = ""
		"pillage":   # ville pillée : tambours pendant la poursuite (DEC-151)
			var so2 := get_node_or_null("/root/Son")
			if so2 and _audio_ok:
				so2.musique("mus_tambours" if String(e.etat) == "poursuite" else _musique_partie())
			if String(e.etat) == "poursuite":
				_son("sfx_depart_convoi", -2.0)
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
		"tempete_annonce", "champ_mines":
			_son("sfx_radio", -4.0)
		"poste":
			_son("sfx_radio", -6.0)
		"halte":
			_aide("003")
		"reputation":
			_aide("006")
		"annonce":   # annonce générale : attaque avant/arrière, ville en vue, champ de mines (DEC-257)
			_annonce = {"cote": String(e.cote), "agr": int(e.agr), "titre": String(e.titre), "sous": String(e.sous), "age": 0.0}
			_son("sfx_impact_blindage", -12.0)
		"groupe":   # un groupe arrive (DEC-253) : annonce colorée selon son agressivité
			_annonce = {"cote": String(e.cote), "n": int(e.n), "agr": int(e.agr), "nom": String(e.nom), "age": 0.0}
			_son("sfx_impact_blindage", -12.0)
		"combat":   # début et fin de la formation de combat (DEC-251)
			var so3 := get_node_or_null("/root/Son")
			if String(e.etat) == "debut":
				_combat_anim = 0.0
				_son("sfx_impact_blindage", -6.0)
			if so3 and _audio_ok and not _accueil_visible():
				so3.musique(_musique_partie())
		"contact":
			if e.ennemi:
				_aide("007")
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
				_lancer_debris(_ancre(v, e.piece), 4, true)   # la pièce part en morceaux
		"roue_perdue":
			_roues_tombees.append({"p": Vector2(e.x, float(e.r) + 0.4), "v": Vector2(float(e.sens) * _rng.randf_range(1.0, 2.5), 3.0), "r": float(e.r), "age": 0.0})
			_son("sfx_impact_blindage", -6.0)
		"epave":
			var v = m.trouver(e.uid)
			if v != null:
				_explosions.append({"p": _centre_veh(v), "age": 0.0, "taille": 2.6})
				_lancer_debris(_centre_veh(v), 9, true)   # la carcasse se disloque
				_son("sfx_explosion")

# Pièces arrachées par un choc : tôles, rétroviseurs, portières, boulons (DEC-255)
func _lancer_debris(p: Vector2, n: int, grosses: bool) -> void:
	var formes := ["tole", "tole", "boulon", "retro", "porte"] if grosses else ["tole", "boulon", "retro"]
	for i in n:
		var fm: String = formes[_rng.randi() % formes.size()]
		_debris.append({"p": p + Vector2(_rng.randf_range(-0.4, 0.4), 0.0), "v": Vector2(_rng.randf_range(-4.5, 4.5), _rng.randf_range(2.5, 6.0)),
			"age": 0.0, "forme": fm, "rot": _rng.randf() * TAU, "vrot": _rng.randf_range(-12.0, 12.0), "taille": 1.4 if fm == "porte" else (0.7 if fm == "boulon" else 1.0)})


# Sang, corps et membres (DEC-257) selon le réglage Gore : 0 rien, 1 sang, 2 maximum
func _gore(p: Vector2, mort: bool, fort: float, voie := 0.0) -> void:
	var g := Gore.lire()
	if g == 0:
		return
	var dy := CombatModele.voie_dy(voie)
	var n := (14 if mort else 5) if g == 2 else (7 if mort else 3)
	for i in n:
		if _gouttes.size() >= 220:
			break
		_gouttes.append({"p": p + Vector2(_rng.randf_range(-0.3, 0.3), _rng.randf_range(-0.2, 0.3)), "v": Vector2(_rng.randf_range(-3.5, 3.5), _rng.randf_range(1.5, 5.5)), "age": 0.0, "dy": dy, "r": _rng.randf_range(0.04, 0.1)})
	if mort and g == 2:
		_debris.append({"p": p, "v": Vector2(_rng.randf_range(-2.5, 2.5), 3.0), "age": 0.0, "forme": "homme", "rot": 0.0, "vrot": _rng.randf_range(-6.0, 6.0), "taille": 1.0, "dy": dy, "cadavre": true, "vie": 6.0})
		if _rng.randf() < 0.6 or fort >= 12.0:
			var membres := ["bras", "jambe", "tete"]
			membres.shuffle()
			for fm in membres.slice(0, _rng.randi_range(1, 3)):
				_debris.append({"p": p, "v": Vector2(_rng.randf_range(-5.0, 5.0), _rng.randf_range(3.0, 7.0)), "age": 0.0, "forme": fm, "rot": _rng.randf() * TAU, "vrot": _rng.randf_range(-14.0, 14.0), "taille": 1.0, "dy": dy, "vie": 16.0, "trace": 0.0})


func _vieillir(delta: float) -> void:
	for d in _debris:   # vol, rebonds, puis la pièce reste un moment sur la route
		d.age += delta
		d.v.y -= 9.8 * delta
		d.p += d.v * delta
		d.rot += d.vrot * delta
		var sol: float = 0.1 + float(d.get("dy", 0.0))
		if d.p.y < sol:
			d.p.y = sol
			d.v.y = -d.v.y * 0.3
			d.v.x *= 0.7
			d.vrot *= 0.6
			if d.get("cadavre", false) and d.age > 0.15:   # le corps s'abat sur la route et y reste
				d["cadavre"] = false
				d.age = 99.0
				if _corps.size() >= 18:
					_corps.pop_front()
				_corps.append({"x": d.p.x, "dy": float(d.get("dy", 0.0)), "age": 0.0, "peau": _rng.randi() % 5, "flip": _rng.randf() < 0.5})
				_taches.append({"x": d.p.x, "dy": float(d.get("dy", 0.0)), "r": 0.8, "age": 0.0})
		if d.has("trace") and d.age < 1.4:   # un membre arraché sème des gouttes
			d.trace -= delta
			if d.trace <= 0.0 and _gouttes.size() < 220:
				d.trace = 0.07
				_gouttes.append({"p": d.p, "v": Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(0.0, 1.5)), "age": 0.0, "dy": float(d.get("dy", 0.0)), "r": 0.05})
	_debris = _debris.filter(func(d): return d.age < float(d.get("vie", 5.0)))
	for g in _gouttes:
		g.age += delta
		g.v.y -= 9.8 * delta
		g.p += g.v * delta
		if g.p.y <= 0.05 + g.dy:
			g.age = 99.0
			if _taches.size() < 90 and Gore.lire() >= 1:
				_taches.append({"x": g.p.x, "dy": g.dy, "r": g.r * _rng.randf_range(2.0, 4.0), "age": 0.0})
	_gouttes = _gouttes.filter(func(g): return g.age < 3.0)
	for t in _taches:
		t.age += delta
	_taches = _taches.filter(func(t): return t.age < 120.0)
	for k in _corps:
		k.age += delta
	_corps = _corps.filter(func(k): return k.age < 180.0)
	if not _annonce.is_empty():
		_annonce.age += delta
		if _annonce.age > float(CombatModele.donnees().groupes.annonce_s):
			_annonce = {}
	if _combat_anim >= 0.0:
		_combat_anim += delta
		if _combat_anim > 2.6:
			_combat_anim = -1.0
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
	for w in _roues_tombees:   # chute, rebonds, puis la roue roule et s'arrête sur la route
		w.age += delta
		w.v.y -= 9.8 * delta
		w.p += w.v * delta
		if w.p.y < w.r:
			w.p.y = w.r
			w.v.y = -w.v.y * 0.35
			w.v.x *= 0.85
	_roues_tombees = _roues_tombees.filter(func(w): return w.age < 6.0)

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
			var allie: bool = p.camp == "joueur"   # soldat débarqué : tenue du convoi
			Silhouette.dessiner(c, pied, ppm, "tireur" if allie else "pillard", {"phase": phase if marche else 0.0, "miroir": p.dir < 0.0, "peau": p.uid, "bras": "vise" if not marche else ""})
	# Pillards qui sautent à l'abordage (DEC-077) : arc entre les deux véhicules, puis debout sur le toit
	for ab in m.abordeurs:
		var xa: float = ab.x
		var haut: float = 1.7 + (sin(PI * float(ab.t)) * 1.6 if ab.etat == "saut" else 0.0)
		var de_v = m.trouver(int(ab.de))
		var vers_v = m.trouver(int(ab.vers))
		var dya: float = lerpf(_dyv(de_v) if de_v != null else 0.0, _dyv(vers_v) if vers_v != null else 0.0, float(ab.t))
		var pa := Vector2(terrain.ecran_x(xa), _sy(xa) - haut * ppm - dya)
		Silhouette.dessiner(c, pa, ppm, "pillard", {"phase": _temps * 9.0 if ab.etat == "bord" else 0.0, "miroir": false, "peau": int(ab.uid), "bras": "vise"})
		if ab.type == "bombe":   # lance explosive : hampe et charge, mèche qui crépite
			var bout := pa + Vector2(0.9 * ppm, -1.5 * ppm)
			c.draw_line(pa + Vector2(0.1 * ppm, -0.9 * ppm), bout, Color("#5A4632"), maxf(2.0, ppm * 0.06))
			c.draw_circle(bout, ppm * 0.16, Color("#3A3A36"))
			c.draw_circle(bout + Vector2(0.1, -0.2) * ppm, ppm * (0.06 + 0.04 * sin(_temps * 30.0)), Color(1.0, 0.75, 0.2))
		else:   # lame
			c.draw_line(pa + Vector2(0.35 * ppm, -1.0 * ppm), pa + Vector2(0.9 * ppm, -1.35 * ppm + sin(_temps * 12.0) * 0.2 * ppm), Color("#C9C6BC"), maxf(2.0, ppm * 0.05))
	# Lueur des feux allumés dans les bâtiments
	for b in m.batiments:
		if b.feu:
			var fl: float = 0.75 + 0.25 * sin(_temps * 13.0 + b.uid)
			for g in b.garnison:
				if g.pv > 0.0:
					var pf := _px(b.fenetre(g.slot))
					c.draw_circle(pf, ppm * 1.8, Color(1.0, 0.55, 0.2, 0.12 * fl))
					c.draw_circle(pf, ppm * 0.7, Color(1.0, 0.7, 0.3, 0.35 * fl))
	_dessiner_halte(c)
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

func _horloge(c: CanvasItem, ctr: Vector2, r: float) -> void:
	var w = m.monde
	var jour_len: float = 1.0 - (MondeJeu.AUBE - MondeJeu.CREPUSCULE)
	var d: float = fposmod(w.heure - MondeJeu.AUBE, 1.0)
	var phi: float = d / jour_len * PI if d < jour_len else PI + (d - jour_len) / (1.0 - jour_len) * PI
	var a0: float = -PI / 2.0 - phi
	c.draw_circle(ctr, r + 7.0, Color("#2A2018"))   # cadre en métal patiné
	c.draw_arc(ctr, r + 4.0, 0.0, TAU, 40, Color("#B8903A"), 3.0)
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
	c.draw_arc(ctr, r, 0.0, TAU, 40, Color(0, 0, 0, 0.55), 2.0)
	c.draw_colored_polygon(PackedVector2Array([ctr + Vector2(-8, -r - 15), ctr + Vector2(8, -r - 15), ctr + Vector2(0, -r - 2)]), Color("#F2EEE6"))
	c.draw_polyline(PackedVector2Array([ctr + Vector2(-8, -r - 15), ctr + Vector2(8, -r - 15), ctr + Vector2(0, -r - 2), ctr + Vector2(-8, -r - 15)]), Color(0, 0, 0, 0.8), 1.5)

# Tempête de sable (DEC-027) : mur de sable à l'horizon pendant l'annonce, voile et rafales pendant la tempête
func _dessiner_tempete(c: CanvasItem) -> void:
	if m.tempete_annoncee():
		var k: float = clampf(1.0 - m.tempete.reste / 45.0, 0.0, 1.0)
		var w := size.x * (0.04 + 0.2 * k)
		c.draw_rect(Rect2(size.x - w, 0.0, w, size.y), Color(0.78, 0.62, 0.36, 0.25 + 0.25 * k))
	elif m.tempete_active():
		var tp: float = minf(minf(1.0, (m.tempete.duree - m.tempete.reste) / 4.0), minf(1.0, m.tempete.reste / 4.0))
		c.draw_rect(Rect2(Vector2.ZERO, size), Color(0.78, 0.62, 0.36, 0.5 * tp))
		for i in 46:
			var y := fposmod(float(i) * 97.3, size.y)
			var x := fposmod(float(i) * 211.7 - _temps * (700.0 + float(i % 5) * 160.0), size.x + 240.0) - 120.0
			c.draw_line(Vector2(x, y), Vector2(x + 70.0, y + 9.0), Color(0.95, 0.85, 0.62, 0.4 * tp), 2.0)

# Halte dans la nature (DEC-161) : l'équipage descend peu à peu, plante des tentes, allume un feu (bivouac) ;
# en surveillance, les hommes se postent autour des véhicules, armes pointées, et les mécaniciens travaillent aux moteurs.
# Les mitrailleurs restent dans leurs véhicules (le dessin de bord les montre déjà).
func _dessiner_halte(c: CanvasItem) -> void:
	var H: Dictionary = m.halte
	if H.is_empty() or m.convoi.is_empty():
		return
	var k := clampf(float(H.t) / maxf(1.0, float(m.H().montage_s)), 0.0, 1.0)
	var xq: float = INF
	var xt: float = -INF
	var n_hommes := 0
	for v in m.convoi:
		if v.actif():
			xq = minf(xq, _rx(v))
			xt = maxf(xt, _rx(v) + v.longueur)
			n_hommes += maxi(0, v.equipage_vivant() - (1 if v.armes.size() > 0 else 0))
	if not is_finite(xq):
		return
	n_hommes = mini(n_hommes, 10)
	var bas := 1.6   # le camp se tient juste devant la route, côté spectateur
	if String(H.mode) == "bivouac":
		var n_tentes := int(ceil(float(maxi(1, n_hommes / 2)) * k))
		for i in n_tentes:   # petites tentes de toile kaki
			var xt0: float = xq + 2.0 + i * 4.2
			var p0 := Vector2(terrain.ecran_x(xt0), _sy(xt0) + bas * ppm)
			var mont := clampf(k * float(maxi(1, n_tentes)) - i, 0.2, 1.0)
			var h := 1.3 * mont * ppm
			c.draw_colored_polygon(PackedVector2Array([p0, p0 + Vector2(2.4 * ppm, 0), p0 + Vector2(1.2 * ppm, -h)]), Color("#6B6A48"))
			c.draw_line(p0 + Vector2(1.2 * ppm, 0), p0 + Vector2(1.2 * ppm, -h), Color("#2E2B22"), maxf(1.0, 0.05 * ppm))
			c.draw_colored_polygon(PackedVector2Array([p0 + Vector2(0.95 * ppm, 0), p0 + Vector2(1.45 * ppm, 0), p0 + Vector2(1.2 * ppm, -h * 0.55)]), Color("#2A281E"))
		if bool(H.pret):   # feu de camp au milieu
			var xf: float = (xq + xt) * 0.5
			var pf := Vector2(terrain.ecran_x(xf), _sy(xf) + (bas + 0.4) * ppm)
			var fl := 0.8 + 0.2 * sin(_temps * 14.0)
			c.draw_circle(pf, 3.0 * ppm, Color(1.0, 0.55, 0.2, 0.1 * fl))
			for j in 3:
				var dx := (j - 1) * 0.22 * ppm
				c.draw_colored_polygon(PackedVector2Array([pf + Vector2(dx - 0.2 * ppm, 0), pf + Vector2(dx + 0.2 * ppm, 0), pf + Vector2(dx + sin(_temps * 9.0 + j) * 0.08 * ppm, -(0.7 + 0.2 * sin(_temps * 11.0 + j)) * ppm * fl)]), Color(1.0, 0.6 + 0.2 * j * 0.5, 0.15))
			c.draw_line(pf + Vector2(-0.5, 0.1) * ppm, pf + Vector2(0.5, -0.05) * ppm, Color("#3A2A1A"), maxf(2.0, 0.1 * ppm))
		for i in int(n_hommes * k):   # hommes autour du feu ou qui portent le matériel
			var xh: float = xq + 1.0 + float(i) * (xt - xq - 2.0) / maxf(1.0, n_hommes)
			var ph := Vector2(terrain.ecran_x(xh), _sy(xh) + (bas + 0.6) * ppm)
			Silhouette.dessiner(c, ph, ppm, "survivant", {"phase": _temps * 7.0 if not bool(H.pret) else 0.0, "miroir": i % 2 == 1, "peau": i + 2})
	else:   # surveillance : tous aux aguets, les mécaniciens au travail
		var i := 0
		for v in m.convoi:
			if not v.actif():
				continue
			var xm: float = _rx(v) + v.longueur * 0.8
			var pm := Vector2(terrain.ecran_x(xm), _sy(xm) + 0.3 * ppm)
			if int(v.profil.get("mecaniciens", 0)) > 0 or i == 0:
				Silhouette.dessiner(c, pm, ppm, "survivant", {"phase": 0.0, "miroir": true, "peau": i + 5})
				if fposmod(_temps + i, 1.4) < 0.15:   # étincelle de clé ou de soudure
					c.draw_circle(pm + Vector2(-0.5 * ppm, -1.0 * ppm), 0.12 * ppm, Color(1.0, 0.85, 0.4))
			i += 1
		for j in n_hommes:
			var xg: float = xq - 1.5 + float(j) * (xt - xq + 3.0) / maxf(1.0, n_hommes - 1)
			var pg := Vector2(terrain.ecran_x(xg), _sy(xg) + bas * ppm)
			Silhouette.dessiner(c, pg, ppm, "tireur", {"phase": 0.0, "miroir": j % 2 == 0, "peau": j + 1, "bras": "vise" if fposmod(_temps * 0.5 + j, 4.0) < 2.5 else ""})


# Oiseau rare (DEV-004) : il traverse le ciel de droite à gauche en battant des ailes, avec un halo discret qui attire l'œil
func _dessiner_oiseau(c: CanvasItem) -> void:
	var O: Dictionary = m.monde.oiseau
	if O.is_empty():
		return
	var k: float = float(O.t) / float(O.duree)
	var p := _px(Vector2(float(O.x0) - k * 90.0, float(O.y) + sin(k * 9.0) * 1.2))
	var e := ppm * 0.55
	var b := sin(_temps * 11.0) * e * 0.6
	var a := minf(1.0, minf(k * 6.0, (1.0 - k) * 6.0))
	c.draw_circle(p, e * 2.2, Color(1.0, 0.9, 0.6, 0.12 * a))
	var col := Color(0.08, 0.07, 0.06, a)
	c.draw_polyline(PackedVector2Array([p + Vector2(-e, b), p + Vector2(-e * 0.4, -e * 0.15), p]), col, maxf(1.5, e * 0.18), true)
	c.draw_polyline(PackedVector2Array([p, p + Vector2(e * 0.4, -e * 0.15), p + Vector2(e, b)]), col, maxf(1.5, e * 0.18), true)


# --- Lot profondeur (DEC-249) ----------------------------------------------------------------
# Ombres portées : ellipse douce sous chaque véhicule, couchée sur la pente. Le soleil est à droite : l'ombre part
# vers la gauche, courte à midi, longue et plus diffuse le soir ; presque rien la nuit ou sous l'orage.
func dessiner_ombres(c: CanvasItem) -> void:
	var nuit := terrain.nuit
	var soir := terrain.soir
	var force := 0.42 * (1.0 - 0.75 * nuit) * (1.0 - 0.5 * terrain.orage)
	if force < 0.02:
		return
	for v in m.convoi + m.ennemis + m.epaves:
		if not v.actif() and v.statut != "epave":
			continue
		var L: float = v.longueur
		var xc: float = _rx(v) + L * 0.5 - lerpf(0.25, 1.3, soir)
		var p := Vector2(terrain.ecran_x(xc), _sy(xc) + 0.06 * ppm - _dyv(v))
		var ang := atan2(_sy(xc + 1.0) - _sy(xc - 1.0), 2.0 * ppm)
		var demi := L * lerpf(0.5, 0.72, soir) * ppm * CombatModele.voie_echelle(v.voie_f)
		var ep := lerpf(0.16, 0.11, soir)   # aplatissement de l'ellipse
		c.draw_set_transform(p, ang, Vector2(1.0, ep))
		for k in 8:   # bord flou : huit ellipses empilées, de plus en plus petites
			c.draw_circle(Vector2.ZERO, demi * (1.05 - 0.075 * k), Color(0.08, 0.06, 0.04, force * 0.14))
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# Lueur additive : quatre disques empilés, plus vive au centre
func _lueur(c: CanvasItem, p: Vector2, r: float, col: Color, a: float) -> void:
	for k in 4:
		c.draw_circle(p, r * (1.0 - 0.22 * k), Color(col, a * 0.3))


# Lumières en mélange additif, au-dessus des véhicules : phares (cône, flaque au sol, éblouissement), feux arrière,
# incendies, explosions et départs de coups. Les carrosseries prises dans un faisceau s'éclairent vraiment.
func dessiner_lumieres(c: CanvasItem) -> void:
	var obs: float = m.monde.obscurite()
	if obs > 0.05:
		var cc := Color(1.0, 0.9, 0.65)
		for v in m.convoi:
			if not v.actif() or v.camoufle or int(v.profil.get("phares", 0)) <= 0:   # seulement s'il en a (DEC-048)
				continue
			var L: float = v.longueur
			var dy: float = CombatModele.voie_dy(v.voie_f)
			var lampe := _px(Vector2(_rx(v) + L - 0.1, 0.9 + dy))
			var xb: float = _rx(v) + L + 14.0
			var a := 0.4 * obs
			c.draw_polygon(PackedVector2Array([lampe + Vector2(0, -0.12 * ppm), _px(Vector2(xb, 2.6 + dy)), _px(Vector2(xb, -0.2 + dy)), lampe + Vector2(0, 0.12 * ppm)]),
				PackedColorArray([Color(cc, a), Color(cc, 0.0), Color(cc, 0.0), Color(cc, a)]))
			var xf: float = _rx(v) + L + 5.5   # flaque de lumière sur la route
			var pf := _px(Vector2(xf, dy))
			c.draw_set_transform(pf, atan2(_sy(xf + 1.0) - _sy(xf - 1.0), 2.0 * ppm), Vector2(1.0, 0.16))
			for k in 3:
				c.draw_circle(Vector2.ZERO, 5.0 * ppm * (1.0 - 0.25 * k), Color(cc, 0.09 * obs))
			c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			_lueur(c, lampe, 0.6 * ppm, cc, 0.5 * obs)
			_lueur(c, _px(Vector2(_rx(v) + 0.1, 0.8 + dy)), 0.4 * ppm, Color(1.0, 0.2, 0.1), 0.35 * obs)   # feu arrière
	var k_feu := 0.3 + 0.7 * obs   # en plein jour, les flammes éclairent peu
	for v in m.convoi + m.ennemis + m.epaves:
		if (v.statut == "epave" and not v.butin_pris) or v.feu > 0.0:   # épave ou véhicule en feu (DEC-220)
			var fl: float = 0.8 + 0.2 * sin(_temps * 11.0 + v.uid)
			_lueur(c, _px(_ancre(v, "moteur")), 4.5 * ppm * fl, Color(1.0, 0.5, 0.18), 0.28 * k_feu)
	for b in m.batiments:
		if b.feu:
			for g in b.garnison:
				if g.pv > 0.0:
					_lueur(c, _px(b.fenetre(g.slot)), 3.0 * ppm * (0.85 + 0.15 * sin(_temps * 13.0 + b.uid)), Color(1.0, 0.55, 0.2), 0.22 * k_feu)
	for ex in _explosions:
		var t: float = clampf(ex.age / 1.4, 0.0, 1.0)
		_lueur(c, _px(ex.p), ppm * (1.5 + 3.0 * float(ex.taille)) * (0.6 + t), Color(1.0, 0.7, 0.35), 0.6 * (1.0 - t) * (1.0 - t) * (0.5 + 0.5 * obs))
	for bf in _bouffees:
		_lueur(c, _px(bf.p), ppm * (3.0 if bf.get("grand", false) else 1.6), Color(1.0, 0.8, 0.45), 0.4 * clampf(1.0 - bf.age / 0.1, 0.0, 1.0) * (0.4 + 0.6 * obs))


# Début de combat (DEC-251) : bords rouges qui pulsent, bandeau sombre qui glisse en travers de l'écran avec « CONTACT ! » au pochoir
func dessiner_bandeau(c: CanvasItem) -> void:
	_dessiner_annonce(c)
	if _combat_anim < 0.0:
		return
	var t := _combat_anim
	var a: float = clampf(1.0 - maxf(0.0, t - 1.7) / 0.9, 0.0, 1.0)
	var w := size.x
	var h := size.y
	var pulse: float = (0.55 + 0.45 * sin(t * 13.0)) * a
	var rouge := Color(0.78, 0.1, 0.05, 0.42 * pulse)
	var nul := Color(rouge, 0.0)
	var ep := 110.0
	c.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(ep, 0), Vector2(ep, h), Vector2(0, h)]), PackedColorArray([rouge, nul, nul, rouge]))
	c.draw_polygon(PackedVector2Array([Vector2(w - ep, 0), Vector2(w, 0), Vector2(w, h), Vector2(w - ep, h)]), PackedColorArray([nul, rouge, rouge, nul]))
	c.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, ep * 0.6), Vector2(0, ep * 0.6)]), PackedColorArray([rouge, rouge, nul, nul]))
	var glisse: float = 1.0 - pow(1.0 - clampf(t / 0.3, 0.0, 1.0), 3.0)   # arrivée vive, freinage net
	var bh := 92.0
	var y := h * 0.26
	var x0: float = lerpf(-w, 0.0, glisse)
	c.draw_rect(Rect2(x0, y, w, bh), Color(0.05, 0.045, 0.04, 0.8 * a))
	c.draw_rect(Rect2(x0, y, w, 3.0), Color(C_ACCENT, a))
	c.draw_rect(Rect2(x0, y + bh - 3.0, w, 3.0), Color(C_ACCENT, a))
	var txt := Textes.t("formation.003")
	var f := police("pochoir", 800)
	var xt: float = lerpf(-w * 0.4, 0.0, glisse)
	c.draw_string(f, Vector2(xt + 3.0, y + bh * 0.5 + 25.0), txt, HORIZONTAL_ALIGNMENT_CENTER, w, 70, Color(0, 0, 0, 0.7 * a))
	c.draw_string(f, Vector2(xt, y + bh * 0.5 + 22.0), txt, HORIZONTAL_ALIGNMENT_CENTER, w, 70, Color(C_ACCENT.lightened(0.15), a))


# Annonce d'un groupe qui arrive (DEC-253) : pastille en haut au centre et flèche sur le bord de l'écran du côté d'arrivée ;
# la couleur suit l'agressivité (vert pacifique, jaune méfiant, orange hostile, rouge meurtrier)
func _dessiner_annonce(c: CanvasItem) -> void:
	if _annonce.is_empty():
		return
	var G: Dictionary = CombatModele.donnees().groupes
	var col := Color(String(G.agressivite[int(_annonce.agr)].couleur))
	var t: float = _annonce.age
	var dur := float(G.annonce_s)
	var a: float = clampf(minf(t / 0.25, (dur - t) / 0.6), 0.0, 1.0)
	var clignote: float = 1.0 if int(_annonce.agr) < 2 else (0.7 + 0.3 * sin(t * (9.0 if int(_annonce.agr) == 2 else 15.0)))
	var w := size.x
	var droite: bool = _annonce.cote == "droite"
	var f := police("pochoir", 800)
	var l1 := "%s  %s" % [Textes.t("groupe.cd" if droite else "groupe.cg").to_upper(), ""]
	var l2 := ""
	if _annonce.has("titre"):   # annonce générale (DEC-257)
		l1 = _annonce.titre
		l2 = _annonce.sous
	else:
		l2 = "%s · %d · %s" % [_annonce.nom, int(_annonce.n), Textes.t("groupe.a%d" % int(_annonce.agr))]
	var bw := 560.0
	var bh := 92.0
	var r := Rect2((w - bw) * 0.5, 120.0, bw, bh)
	c.draw_rect(r, Color(0.05, 0.045, 0.04, 0.82 * a))
	c.draw_rect(Rect2(r.position, Vector2(bw, 4.0)), Color(col, a * clignote))
	c.draw_rect(Rect2(r.position + Vector2(0, bh - 4.0), Vector2(bw, 4.0)), Color(col, a * clignote))
	c.draw_string(f, r.position + Vector2(0, 38.0), l1.strip_edges(), HORIZONTAL_ALIGNMENT_CENTER, bw, 34, Color(col.lightened(0.15), a))
	c.draw_string(get_theme_default_font(), r.position + Vector2(0, 74.0), l2, HORIZONTAL_ALIGNMENT_CENTER, bw, 28, Color(C_TEXTE, a))
	if String(_annonce.cote) == "":
		return   # pas de flèche : ville, mines
	var cy := r.position.y + bh * 0.5
	var pulse: float = 0.5 + 0.5 * sin(t * 6.0)
	var dx := 24.0 + 14.0 * pulse
	var sens := 1.0 if droite else -1.0
	var bx: float = (w - 18.0 - dx) if droite else (18.0 + dx)
	c.draw_colored_polygon(PackedVector2Array([Vector2(bx + sens * 26.0, cy), Vector2(bx - sens * 8.0, cy - 30.0), Vector2(bx - sens * 8.0, cy + 30.0)]), Color(col, a * clignote))


# Taches, corps restés sur la route et gouttes en vol (DEC-257)
func _dessiner_gore(c: CanvasItem) -> void:
	for t in _taches:
		var al: float = 0.85 * clampf((120.0 - t.age) / 40.0, 0.0, 1.0)
		var p := _px(Vector2(t.x, 0.0)) - Vector2(0.0, float(t.dy) * ppm)
		c.draw_set_transform(p, 0.0, Vector2(1.0, 0.22))
		c.draw_circle(Vector2.ZERO, float(t.r) * ppm, Color(0.3, 0.03, 0.03, al))
	for k in _corps:
		var al2: float = clampf((180.0 - k.age) / 30.0, 0.0, 1.0)
		var p2 := _px(Vector2(k.x, 0.0)) - Vector2(0.0, float(k.dy) * ppm)
		var sx: float = -1.0 if k.flip else 1.0
		c.draw_set_transform(p2, 0.0, Vector2(sx, 1.0))
		c.draw_set_transform(p2, 0.0, Vector2(sx, 1.0))
		c.draw_rect(Rect2(-0.6 * ppm, -0.08 * ppm, 1.9 * ppm, 0.12 * ppm), Color(0.3, 0.03, 0.03, 0.8 * al2))
		c.draw_rect(Rect2(-0.45 * ppm, -0.26 * ppm, 0.85 * ppm, 0.24 * ppm), Color(0.27, 0.28, 0.2, al2))
		c.draw_rect(Rect2(0.4 * ppm, -0.2 * ppm, 0.85 * ppm, 0.18 * ppm), Color(0.2, 0.19, 0.16, al2))
		c.draw_circle(Vector2(-0.62 * ppm, -0.15 * ppm), 0.13 * ppm, Color(0.62, 0.48, 0.38, al2))
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for g in _gouttes:
		c.draw_circle(_px(g.p) - Vector2(0.0, float(g.dy) * ppm), maxf(1.5, float(g.r) * ppm), Color(0.58, 0.04, 0.04, 0.95))


func dessiner_fx(c: CanvasItem) -> void:
	var f := get_theme_default_font()
	var obs: float = m.monde.obscurite()
	_dessiner_tempete(c)
	if obs > 0.01:
		c.draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.04, 0.12, 0.2 * obs))
		# les phares sont dessinés par le calque de lumières additives (dessiner_lumieres, DEC-249)
	_dessiner_monde(c)
	_dessiner_oiseau(c)
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
				var p := _px(Vector2(b.x + b.longueur * (0.25 + 0.15 * k), 1.5 + ph * 4.0 + CombatModele.voie_dy(float(b.voie))))
				c.draw_circle(p, (0.4 + ph * 1.2) * ppm, Color(0.12, 0.11, 0.1, 0.5 * (1.0 - ph)))
	# Barre de vie et équipage : seulement pour NOS véhicules (l'état de l'ennemi reste inconnu)
	for v in m.convoi:
		if not v.actif():
			continue
		var D: Dictionary = VehiculeDessin.donnees().vehicules[v.type]
		var x0 := terrain.ecran_x(_rx(v))
		var top: float = _sy(_rx(v) + v.longueur * 0.5) - _dyv(v) - (float(D.hauteur) + 0.7) * ppm
		var w: float = v.longueur * ppm
		var q: float = v.pieces.chassis.pv / v.pieces.chassis.max
		c.draw_rect(Rect2(Vector2(x0, top), Vector2(w, 6)), Color(0, 0, 0, 0.6))
		c.draw_rect(Rect2(Vector2(x0, top), Vector2(w * q, 6)), couleur_etat(q))
		for k in v.equipage.size():
			c.draw_circle(Vector2(x0 + 6 + k * 12, top - 8), 4.0, C_VERT if v.equipage[k] > 0.0 else Color(0.35, 0.35, 0.35))
		if v.camo_voulu:
			var fr: float = 1.0 if v.camoufle else clampf(v.camo_t / CombatModele.donnees().embuscade.camo_s, 0.0, 1.0)
			var cam := Rect2(Vector2(x0 - 4, _sy(_rx(v) + v.longueur * 0.5) - _dyv(v) - (float(D.hauteur) + 0.3) * ppm), Vector2(w + 8, (float(D.hauteur) + 0.3) * ppm))
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
				_poussiere_veh.append({"p": Vector2(_rx(v) + 0.3, 0.2 + CombatModele.voie_dy(v.voie_f)), "age": 0.0})
	for q in _poussiere_veh:
		var kq: float = q.age / 0.9
		c.draw_circle(_px(q.p) + Vector2(-kq * ppm * 1.6, -kq * ppm * 0.7), ppm * (0.2 + 0.5 * kq), Color(0.7, 0.6, 0.45, 0.35 * (1.0 - kq)))
	# Mines posées (la LED rouge clignote quand elles sont armées)
	for mn in m.mines:
		var pm := _px(Vector2(mn.x, 0.0))
		c.draw_rect(Rect2(pm + Vector2(-0.35, -0.12) * ppm, Vector2(0.7, 0.2) * ppm), Color("#3A3A32"))
		if mn.armee and fmod(_temps, 1.0) < 0.2:
			c.draw_circle(pm + Vector2(0, -0.15 * ppm), maxf(2.0, ppm * 0.07), C_ROUGE)
	for pg in m.pieges:   # chausse-trappes : petites pointes sur la route
		var pp2 := _px(Vector2(pg.x, 0.0))
		for k in 3:
			var o := Vector2((k - 1) * 0.4, 0.0) * ppm
			c.draw_colored_polygon(PackedVector2Array([pp2 + o + Vector2(-0.15, 0.02) * ppm, pp2 + o + Vector2(0.15, 0.02) * ppm, pp2 + o + Vector2(0.0, -0.3) * ppm]), Color("#B8B8B0"))
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
			var p := Vector2(terrain.ecran_x(_rx(cc) + cc.longueur * 0.5), _sy(_rx(cc) + cc.longueur * 0.5) - _dyv(cc) - (h + 1.3) * ppm - 4.0 * sin(_temps * 3.0))
			c.draw_rect(Rect2(p - Vector2(10, 10), Vector2(20, 20)), C_ACCENT)
			c.draw_string(f, p + Vector2(-10, 7), "$", HORIZONTAL_ALIGNMENT_CENTER, 20, 18, Color("#1A1A18"))
	if not m.fouille_en_cours.is_empty():
		var cible = m.trouver(m.fouille_en_cours.uid)
		if cible != null:
			var fr: float = 1.0 - m.fouille_en_cours.restant / m.fouille_en_cours.total
			var h2: float = 2.0 if cible is CombatModele.Veh else cible.hauteur
			var p2 := Vector2(terrain.ecran_x(_rx(cible) + cible.longueur * 0.5), _sy(_rx(cible) + cible.longueur * 0.5) - _dyv(cible) - (h2 + 2.4) * ppm)
			c.draw_rect(Rect2(p2 - Vector2(50, 7), Vector2(100, 14)), Color(0, 0, 0, 0.7))
			c.draw_rect(Rect2(p2 - Vector2(48, 5), Vector2(96 * fr, 10)), C_ACCENT)
			c.draw_string(f, p2 + Vector2(-60, -14), "Fouille", HORIZONTAL_ALIGNMENT_CENTER, 120, 20, C_TEXTE)
	_dessiner_persos(c)
	_dessiner_panneau(c)
	# Balles et obus en vol : trajectoire du modèle (bouche de l'arme -> point d'impact)
	for pr in m.projectiles:
		var tt: float = clampf((pr.t + (0.0 if pause else _alpha * CombatModele.DT)) / pr.T, 0.0, 1.0)
		var dist: float = pr.a.distance_to(pr.b)
		# Trajectoire : flèche réelle d'après la vitesse à la bouche du calibre (DEC-054) ; le mortier tire en cloche
		var arc: float
		if pr.classe == "mortier":
			arc = 0.35 * dist
		elif pr.classe == "incendiaire":
			arc = 0.3 * dist   # bouteille lancée à la main : arc haut
		elif pr.classe == "lance":
			arc = 0.12 * dist
		else:
			var v0: float = {"canon": 700.0, "fusil": 820.0, "flamme": 30.0}.get(pr.classe, 760.0)
			var tv: float = dist / v0
			arc = minf(9.81 * tv * tv / 8.0, dist * 0.25)
		var t0: float = maxf(0.0, tt - (3.2 if pr.classe != "canon" else 2.0) / maxf(dist, 1.0))
		var pa: Vector2 = pr.a.lerp(pr.b, tt) + Vector2(0, sin(PI * tt) * arc)
		var pb: Vector2 = pr.a.lerp(pr.b, t0) + Vector2(0, sin(PI * t0) * arc)
		var sa := _px(pa)
		var sb := _px(pb)
		if pr.classe == "flamme":   # jet de feu : boules qui grossissent
			for k in 4:
				var tk: float = maxf(0.0, tt - 0.07 * k)
				var pk := _px(pr.a.lerp(pr.b, tk) + Vector2(0, sin(PI * tk) * arc))
				c.draw_circle(pk, ppm * (0.18 + 0.35 * tk), Color(1.0, 0.45 + 0.1 * k, 0.1, 0.75 - 0.15 * k))
		elif pr.classe == "incendiaire":   # bouteille qui tourne, traînée de flammes
			for k in 3:
				var tk2: float = maxf(0.0, tt - 0.05 * k)
				var pk2 := _px(pr.a.lerp(pr.b, tk2) + Vector2(0, sin(PI * tk2) * arc))
				c.draw_circle(pk2, maxf(3.0, ppm * (0.16 - 0.03 * k)), Color(1.0, 0.5 + 0.15 * k, 0.1, 0.9 - 0.25 * k))
			c.draw_circle(sa, maxf(2.5, ppm * 0.08), Color(0.35, 0.6, 0.35))
		elif pr.classe == "lance":   # hampe de bois et pointe qui rougeoie
			c.draw_line(sb, sa, Color(0.45, 0.32, 0.18), maxf(2.5, ppm * 0.06))
			c.draw_circle(sa, maxf(4.0, ppm * 0.12), Color(1.0, 0.55, 0.15))
			c.draw_circle(sa, maxf(2.0, ppm * 0.06), Color(1.0, 0.95, 0.6))
		elif pr.classe == "canon":
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
		if s.age < 0.0:
			continue
		var p := _px(s.p)
		var fade2: float = 1.0 - s.age / 0.3
		var gros: bool = s.get("gros", false)
		var nb := 9 if gros else 6
		for k in nb:
			c.draw_line(p, p + Vector2.from_angle(k * TAU / nb + s.age * 3) * ((9 if gros else 6) + (34 if gros else 22) * s.age), Color(1, 0.8, 0.3, fade2), 2.0)
	for s in _bouffees:
		c.draw_circle(_px(s.p), 14.0 if s.get("grand", false) else 8.0, Color(1.0, 0.9, 0.5, 0.9))
	_dessiner_gore(c)
	for d in _debris:   # pièces et hommes qui volent (DEC-255)
		var pd := _px(d.p)
		var k: float = ppm * 0.22 * float(d.taille)
		var a: float = clampf(float(d.get("vie", 5.0)) - d.age, 0.0, 1.0)
		c.draw_set_transform(pd, d.rot, Vector2.ONE)
		match String(d.forme):
			"tole":
				c.draw_colored_polygon(PackedVector2Array([Vector2(-k, -k * 0.4), Vector2(k * 1.2, -k * 0.2), Vector2(k * 0.8, k * 0.5), Vector2(-k * 0.9, k * 0.3)]), Color(0.42, 0.38, 0.33, a))
			"porte":
				c.draw_rect(Rect2(-k * 1.2, -k * 0.7, k * 2.4, k * 1.4), Color(0.4, 0.36, 0.3, a))
				c.draw_rect(Rect2(-k * 0.9, -k * 0.45, k * 1.2, k * 0.5), Color(0.2, 0.26, 0.28, a))
			"retro":
				c.draw_rect(Rect2(-k * 0.2, -k * 0.2, k * 0.9, k * 0.4), Color(0.2, 0.2, 0.19, a))
				c.draw_circle(Vector2(k * 0.9, 0), k * 0.4, Color(0.75, 0.8, 0.82, a))
			"homme":
				Silhouette.dessiner(c, Vector2.ZERO, ppm, "pillard", {"phase": d.age * 9.0, "miroir": false, "peau": 1, "bras": "vise"})
			"bras":
				c.draw_line(Vector2(-k * 1.6, 0), Vector2(k * 1.6, 0), Color(0.62, 0.48, 0.38, a), maxf(2.0, ppm * 0.1))
				c.draw_circle(Vector2(-k * 1.6, 0), maxf(2.0, ppm * 0.07), Color(0.6, 0.04, 0.04, a))
			"jambe":
				c.draw_line(Vector2(-k * 2.0, 0), Vector2(k * 2.0, 0), Color(0.28, 0.27, 0.22, a), maxf(3.0, ppm * 0.14))
				c.draw_circle(Vector2(-k * 2.0, 0), maxf(2.0, ppm * 0.08), Color(0.6, 0.04, 0.04, a))
			"tete":
				c.draw_circle(Vector2.ZERO, maxf(3.0, ppm * 0.15), Color(0.62, 0.48, 0.38, a))
				c.draw_circle(Vector2(-ppm * 0.07, 0), maxf(2.0, ppm * 0.07), Color(0.6, 0.04, 0.04, a))
			_:
				c.draw_circle(Vector2.ZERO, k * 0.35, Color(0.55, 0.5, 0.45, a))
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for e in m.ennemis:   # blindés de fortune : tôles boulonnées, pointes aux deux bouts (DEC-255)
		if e.actif() and bool(e.profil.get("fortune", false)):
			var ech: float = CombatModele.voie_echelle(e.voie_f)
			var rx: float = _rx(e)
			var dyl: float = CombatModele.voie_dy(e.voie_f)
			for k in 3:
				var xp: float = rx + e.longueur * (0.18 + 0.3 * k)
				var r := Rect2(_px(Vector2(xp, 1.05 + dyl)), Vector2(e.longueur * 0.26 * ppm * ech, 0.62 * ppm * ech))
				c.draw_rect(r, Color(0.38, 0.34, 0.29, 0.92))
				c.draw_rect(r, Color(0.12, 0.11, 0.1, 0.9), false, 2.0)
				c.draw_circle(r.position + Vector2(5, 5), 2.0, Color(0.7, 0.66, 0.6))
				c.draw_circle(r.position + Vector2(r.size.x - 5, r.size.y - 5), 2.0, Color(0.7, 0.66, 0.6))
			for xp2 in [rx - 0.1, rx + e.longueur + 0.1]:
				var p0 := _px(Vector2(xp2, 0.7 + dyl))
				var sens: float = -1.0 if xp2 < rx + e.longueur * 0.5 else 1.0
				c.draw_colored_polygon(PackedVector2Array([p0 + Vector2(0, -0.2 * ppm * ech), p0 + Vector2(sens * 0.55 * ppm * ech, 0), p0 + Vector2(0, 0.2 * ppm * ech)]), Color(0.55, 0.5, 0.45))
	for v in m.convoi:   # timon entre une remorque et son tracteur (DEC-080)
		if v.remorque() and v.actif() and v.garage == 0:
			var t = m.tracteur_de(v)
			if t != null and t.garage == 0:
				c.draw_line(_px(Vector2(_rx(v) + v.longueur - 0.1, 0.55 + CombatModele.voie_dy(v.voie_f))), _px(Vector2(_rx(t) + 0.1, 0.55 + CombatModele.voie_dy(t.voie_f))), Color("#2E2C28"), maxf(3.0, ppm * 0.07))
	for w in _roues_tombees:
		var rp: float = w.r * ppm
		var tex: Texture2D = VehiculeDessin._tex("roue_petite" if w.r < 0.3 else ("roue_moyenne" if w.r < 0.5 else "roue_grande"))
		c.draw_set_transform(_px(w.p), -w.p.x / w.r, Vector2.ONE)
		c.draw_texture_rect(tex, Rect2(-rp, -rp, 2.0 * rp, 2.0 * rp), false, Color(1, 1, 1, clampf(6.0 - w.age, 0.0, 1.0)))
		c.draw_set_transform(Vector2.ZERO)
	for v in m.convoi + m.ennemis + m.epaves:   # véhicules en feu : flammes qui dansent et fumée (DEC-220)
		if v.feu <= 0.0:
			continue
		var pf: Vector2 = _px(_centre_veh(v))
		var amp: float = clampf(v.feu / 3.0, 0.3, 1.0)
		for k in 4:
			var ph: float = _temps * 9.0 + k * 1.7 + float(v.uid)
			var off := Vector2((k - 1.5) * ppm * 0.45 + sin(ph) * ppm * 0.08, -ppm * (0.2 + 0.15 * absf(sin(ph * 0.7))))
			var hf: float = ppm * (0.35 + 0.18 * sin(ph * 1.3)) * amp
			c.draw_circle(pf + off, hf, Color(1.0, 0.42 + 0.2 * sin(ph), 0.1, 0.75))
			c.draw_circle(pf + off + Vector2(0, -hf * 0.3), hf * 0.55, Color(1.0, 0.85, 0.3, 0.8))
			c.draw_circle(pf + off + Vector2(sin(ph) * ppm * 0.2, -ppm * (0.9 + 0.3 * absf(sin(ph * 0.5)))), hf * 0.9, Color(0.14, 0.13, 0.12, 0.35 * amp))
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
	var y0: float = maxf(150.0, _sy(_rx(v) + v.longueur * 0.5) - _dyv(v) - (float(D.hauteur) + 0.7) * ppm - 120.0)
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
					voulus["rep%d" % v.uid] = {"cible": cx, "variante": "mecano", "n": clampi(m.equipage_dehors(v), 1, 4), "origine": _origine_x(_rx(v) + v.longueur * 0.5)}
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
	if lourd != null and (m.vitesse_convoi != 0.0 or bool(m.trans.moteur_on)) and not pause and not m.fini:   # ralenti à l'arrêt, démarreur au départ (DEC-232)
		nom = MOTEURS.get(lourd.type, "sfx_moteur_" + String(VehiculeDessin.donnees().vehicules[lourd.type].get("moteur", "")))
	so.moteur(nom)
	if float(m.trans.demarreur) > 0.0:
		so.moteur_hauteur(0.55)   # le démarreur peine
	else:
		so.moteur_hauteur(lerpf(0.75, 1.5, clampf((float(m.trans.regime) - 0.2) / 0.9, 0.0, 1.0)))
	if m.ordres.marche != _marche_prec:
		if m.ordres.marche == "avancer":
			_son("sfx_depart_marche", -4.0)
		_marche_prec = m.ordres.marche
