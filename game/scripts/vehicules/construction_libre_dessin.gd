# Dessin d'un véhicule construit sur la grille : formes, visuels dessinés, cabines et postes (DEC-062, DEC-066).
# Séparé de construction_libre.gd (règles et analyse) ; lit la grille par ConstructionLibre.
class_name ConstructionLibreDessin
# --- Dessin (fiche au format de formes_vehicules.json) -------------------------------------------
static func _poly_cercle(cx: float, cy: float, r: float, n := 14) -> Array:
	var pts := []
	for k in n:
		var t := TAU * float(k) / float(n)
		pts.append([cx + r * cos(t), cy + r * sin(t)])
	return pts


static func forme(a: Dictionary, ecorche := false) -> Dictionary:
	var an := ConstructionLibre.analyser(a)
	var cases := ConstructionLibre._cases(a)
	var essieux: Array = an.detail.get("essieux", ConstructionLibre._essieux(a))
	var sol: float = an.detail.get("sol", 0.0)
	var x0 := INF
	var x1 := -INF
	var y1 := 0.0
	for c in cases:
		x0 = minf(x0, c.x)
		x1 = maxf(x1, c.x + 1.0)
		y1 = maxf(y1, c.y + 1.0)
	for p in ConstructionLibre._pieces(a):
		x0 = minf(x0, p.pos.x)
		x1 = maxf(x1, p.pos.x + p.e.x)
		y1 = maxf(y1, p.pos.y + p.e.y)
	for e in essieux:
		x0 = minf(x0, e.x + 0.5 - e.r)
		x1 = maxf(x1, e.x + 0.5 + e.r)
	for t in a.get("toles", []):
		x0 = minf(x0, minf(float(t[0]), float(t[2])))
		x1 = maxf(x1, maxf(float(t[0]), float(t[2])))
		y1 = maxf(y1, maxf(float(t[1]), float(t[3])))
	if x0 == INF:
		x0 = 0.0
		x1 = 4.0
	var X := func(x: float) -> float: return (x - x0) * ConstructionLibre.C
	var Y := func(y: float) -> float: return (y - sol) * ConstructionLibre.C
	var formes := []
	for c in cases:
		if cases[c] == "tube":   # châssis tubulaire : treillis de tubes soudés (DEC-074)
			var xa: float = X.call(c.x)
			var xb: float = X.call(c.x + 1.0)
			var ya: float = Y.call(c.y)
			var yb: float = Y.call(c.y + 1.0)
			for l in [[[xa, ya + 0.02], [xb, ya + 0.02]], [[xa, yb - 0.02], [xb, yb - 0.02]], [[xa, ya], [xb, yb]] if (c.x + c.y) % 2 == 0 else [[xa, yb], [xb, ya]]]:
				formes.append({"ligne": l, "ep": 0.035, "c": "metal", "z": 0})
			continue
		if cases[c] == "poutre":   # poutre en I : âme sombre, semelles claires (DEC-080)
			var pa: float = X.call(c.x)
			var pb: float = X.call(c.x + 1.0)
			var pya: float = Y.call(c.y)
			var pyb: float = Y.call(c.y + 1.0)
			formes.append({"pts": [[pa, pya + 0.07], [pb, pya + 0.07], [pb, pyb - 0.07], [pa, pyb - 0.07]], "c": "sombre", "z": 0})
			formes.append({"pts": [[pa, pya], [pb, pya], [pb, pya + 0.06], [pa, pya + 0.06]], "c": "#5A5A52", "z": 0})
			formes.append({"pts": [[pa, pyb - 0.06], [pb, pyb - 0.06], [pb, pyb], [pa, pyb]], "c": "#5A5A52", "z": 0})
			continue
		var col := "sombre" if cases[c] == "blindage" else "caisse"
		formes.append({"pts": [[X.call(c.x), Y.call(c.y)], [X.call(c.x + 1.0), Y.call(c.y)], [X.call(c.x + 1.0), Y.call(c.y + 1.0)], [X.call(c.x), Y.call(c.y + 1.0)]], "c": col, "z": 0})
	var roues := []
	var chenille := {}
	var pistes := {}
	for e in essieux:
		var cx: float = X.call(e.x + 0.5)
		var r: float = e.r * ConstructionLibre.C
		formes.append({"ligne": [[cx, Y.call(e.y)], [cx, Y.call(e.y) - 0.08]], "ep": 0.06, "c": "metal", "z": 1})
		if not e.fiche_l.is_empty():
			_formes_liaison(formes, String(e.fiche_l.get("dessin", "lames")), cx, Y.call(e.y + e.h), Y.call(e.y), cx < X.call((x0 + x1) * 0.5))
		if e.get("piste", -1) >= 0 and e.get("touche", false):
			if not pistes.has(e.piste):
				pistes[e.piste] = []
			pistes[e.piste].append(cx)
		elif e.get("touche", false):
			roues.append({"x": cx, "r": r, "yb": Y.call(e.y)})
		else:   # roue qui ne repose pas au sol : dessinée à sa vraie hauteur
			formes.append({"pts": _poly_cercle(cx, Y.call(e.y), r), "c": "sombre", "z": 2})
			formes.append({"pts": _poly_cercle(cx, Y.call(e.y), r * 0.45, 8), "c": "metal", "z": 2})
	for e in ConstructionLibre.ponts_libres(a):   # pont pas encore relié : dessiné en l'air, là où il a été placé (DEC-075)
		var cxl: float = X.call(int(e.x) + 0.5)
		var yl: float = Y.call(float(e.get("y", ConstructionLibre.y_essieu(a, int(e.x)))))
		var ftl := Assemblage.piece(String(e.get("train", "")))
		if not ftl.is_empty():
			formes.append({"pts": _poly_cercle(cxl, yl, float(ftl.get("diametre_cases", 2)) * 0.5 * ConstructionLibre.C), "c": "pneu", "z": 2})
			formes.append({"pts": _poly_cercle(cxl, yl, float(ftl.get("diametre_cases", 2)) * 0.22 * ConstructionLibre.C, 10), "c": "metal", "z": 2})
		formes.append({"pts": _poly_cercle(cxl, yl, 0.11, 8), "c": "sombre", "z": 2})
	for k in pistes:
		var gal: Array = pistes[k]
		var rg := 0.375 - 0.08
		if chenille.is_empty():
			chenille = {"barbotin": [gal.back() + 0.25, 0.42, 0.25], "tendeur": [gal.front() - 0.25, 0.38, 0.22],
				"galets": gal, "r_galet": rg, "rouleaux": [], "ep": 0.08}
		else:
			for gx in gal:
				roues.append({"x": gx, "r": 0.375})
	var armes := []
	var equipage := []
	var roles_par_piece := {}   # indice de pièce -> rôles de ses sièges d'équipage
	for sg in ConstructionLibre.sieges_equipage(a):
		if not roles_par_piece.has(sg.piece):
			roles_par_piece[sg.piece] = []
		roles_par_piece[sg.piece].append(sg.role)
	for p in ConstructionLibre._pieces(a):
		var r := Rect2(X.call(p.pos.x), Y.call(p.pos.y), p.e.x * ConstructionLibre.C, p.e.y * ConstructionLibre.C)
		if ConstructionLibre._coque(p.fiche):   # au-dessus de tout, sous les armes ; transparente en vue écorchée
			formes.append({"sprite": String(p.fiche.image), "r": [r.position.x, r.position.y, r.size.x, r.size.y], "z": 3,
				"miroir": p.miroir, "opac": ConstructionLibre.OPAC_ECORCHE if ecorche else 1.0,
				"uv": [p.coupe[0], 1.0 - float(p.coupe[3]), p.coupe[1], 1.0 - float(p.coupe[2])]})   # morceau d'image (v vers le bas)
			continue
		if ConstructionLibre._habillage(p.fiche):
			var st := String(p.fiche.get("style", "voiture"))
			if STYLE_SPRITE.has(st):
				_sprite(formes, STYLE_SPRITE[st], r, 2 if st != "ouverte" else -1)   # la carrosserie recouvre les sièges
			else:
				_formes_cabine(formes, st, r)
			continue
		match p.fiche.get("famille", ""):
			"greffe":
				_formes_greffe(formes, String(p.fiche.get("dessin", "")), r)
			"radiateur":   # cadre et faisceau à ailettes (DEC-080)
				formes.append({"pts": [[r.position.x, r.position.y], [r.end.x, r.position.y], [r.end.x, r.end.y], [r.position.x, r.end.y]], "c": "#2E2C28", "z": 2})
				var nf := maxi(3, int(r.size.x / 0.05))
				for k in nf:
					var fx := r.position.x + 0.04 + (r.size.x - 0.08) * (float(k) + 0.5) / nf
					formes.append({"ligne": [[fx, r.position.y + 0.05], [fx, r.end.y - 0.05]], "ep": 0.018, "c": "#8C867A", "z": 2})
				formes.append({"pts": _poly_cercle(r.position.x + r.size.x * 0.5, r.end.y - 0.03, 0.04, 8), "c": "#8C867A", "z": 2})
			"moteur":
				var surface: int = int(p.e.x) * int(p.e.y)
				if bool(p.fiche.get("a_nu", false)):   # moteur à nu (DEC-083) : bloc en bas, compresseur et pipes qui sortent du capot
					var rb := Rect2(r.position, Vector2(r.size.x, r.size.y * 0.55))
					_sprite(formes, "moteur_leger", rb, 1)
					var yb := rb.end.y
					var w := r.size.x
					var xn := r.position.x
					formes.append({"pts": [[xn + w * 0.2, yb - 0.02], [xn + w * 0.8, yb - 0.02], [xn + w * 0.76, yb + r.size.y * 0.28], [xn + w * 0.24, yb + r.size.y * 0.28]], "c": "#3A3631", "z": 4})
					for k in 4:
						var fx := xn + w * (0.28 + 0.15 * k)
						formes.append({"ligne": [[fx, yb + 0.02], [fx, yb + r.size.y * 0.26]], "ep": 0.02, "c": "#8C867A", "z": 4})
					formes.append({"pts": [[xn + w * 0.42, yb + r.size.y * 0.28], [xn + w * 0.62, yb + r.size.y * 0.28], [xn + w * 0.66, r.end.y], [xn + w * 0.38, r.end.y]], "c": "#B8B2A6", "z": 4})
					formes.append({"pts": _poly_cercle(xn + w * 0.86, yb + r.size.y * 0.12, w * 0.08, 10), "c": "#8C867A", "z": 4})
					for k in 3:
						var py := yb - r.size.y * (0.1 + 0.12 * k)
						formes.append({"ligne": [[xn + w * 0.15, py], [xn - w * 0.25, py - 0.06]], "ep": 0.035, "c": "#B8B2A6", "z": 4})
				else:
					_sprite(formes, "moteur_leger" if surface <= 8 else ("moteur_moyen" if surface <= 18 else "moteur_lourd"), r, 1)
			"cabine":
				var style := String(p.fiche.get("style", "ouverte" if bool(p.fiche.get("ouvert", false)) else "voiture"))
				if STYLE_SPRITE.has(style):
					_sprite(formes, STYLE_SPRITE[style], r, -1 if style == "ouverte" else 2)   # jeep : l'équipage s'assoit dans le visuel
				else:
					_formes_cabine(formes, style, r)
				var n := int(p.fiche.get("sieges", 0))
				for k in n:   # cabine complète d'un véhicule historique : ses sièges sont dedans
					var fx := 0.5 if n == 1 else 0.2 + 0.6 * float(k) / float(n - 1)
					var role := String(roles_par_piece.get(p.i, [])[k]) if roles_par_piece.get(p.i, []).size() > k else "tireur"
					if style == "blindee":   # le chef dépasse de la trappe
						if k == 0:
							equipage.append({"x": r.position.x + r.size.x * 0.5, "y": r.end.y, "role": "chef", "h": 0.26})
					else:
						equipage.append({"x": r.position.x + r.size.x * fx, "y": r.position.y + 0.28, "role": role})
			"poste":
				_formes_poste(formes, p.fiche, r)
				var rl: Array = roles_par_piece.get(p.i, [])
				if p.fiche.get("poste", "") == "banc":
					var sens := float(p.fiche.get("sens", 1))
					for k in int(p.fiche.sieges):
						equipage.append({"x": r.position.x + r.size.x * (0.14 + 0.24 * float(k)), "y": r.position.y + 0.28, "role": "troupe", "dir": sens})
				else:
					var role := String(rl[0]) if not rl.is_empty() else "tireur"
					var haut: bool = p.fiche.get("poste", "") == "commande"
					equipage.append({"x": r.position.x + r.size.x * 0.40, "y": r.position.y + (0.46 if haut else 0.27), "role": role, "h": 0.58 if haut else 0.55})
	for w in ConstructionLibre.armes_ordonnees(a):
		var p: Dictionary = w.place
		var r := Rect2(X.call(p.pos.x), Y.call(p.pos.y), p.e.x * ConstructionLibre.C, p.e.y * ConstructionLibre.C)
		var wid := String(p.fiche.arme)
		if wid == "mortier":
			var rs := _rect_sprite("arme_mortier", r, false)
			armes.append({"type": "mortier", "x": rs[0] + rs[2] * 0.5, "y": rs[1], "long": rs[3] * 1.15, "ep": 0.1, "sprite": "arme_mortier", "r": rs,
				"bout": [rs[0] + rs[2] * 0.3, rs[1] + rs[3]]})
		elif wid.begins_with("mitrailleuse") or wid == "lance_flammes":
			var sid := "arme_lance_flammes" if wid == "lance_flammes" else "arme_mitrailleuse"
			var rs := _rect_sprite(sid, r, false)
			armes.append({"type": "mitrailleuse", "x": r.position.x + 0.2, "y": r.position.y, "pied": maxf(0.12, r.size.y - 0.1), "long": maxf(1.0, r.size.x * 1.2), "ep": 0.05,
				"sprite": sid, "r": rs, "bout": [rs[0] + rs[2], rs[1] + rs[3] * 0.62]})
		else:
			var sid := "arme_canon_37" if wid.contains("leger") else ("arme_canon_88" if wid.contains("88") else "arme_canon_75")
			var rs := _rect_sprite(sid, r, false)
			armes.append({"type": "canon", "x": r.position.x, "y": rs[1] + rs[3] * 0.55, "long": rs[2], "ep": 0.1, "frein": false,
				"sprite": sid, "r": rs, "bout": [rs[0] + rs[2], rs[1] + rs[3] * 0.55]})
	var plaques := int(a.get("plaques", 0))
	for k in plaques:
		formes.append({"ligne": [[X.call(x1) - 0.05 - 0.07 * k, Y.call(sol + 1.0)], [X.call(x1) - 0.05 - 0.07 * k, Y.call(sol + 4.0)]], "ep": 0.05, "c": "metal", "z": 2})
	var M: float = an.stats.get("poids_kg", 1000.0) if an.ok else 1000.0
	var moteur := ("char" if M > 20000.0 else "char_leger") if not chenille.is_empty() else ("voiture" if M < 1800.0 else "camion")
	for p in ConstructionLibre._pieces(a):
		if p.id == "phares":
			var rp := Rect2(X.call(p.pos.x), Y.call(p.pos.y), p.e.x * ConstructionLibre.C, p.e.y * ConstructionLibre.C)
			_sprite(formes, "phares", rp, 2, false)
	# Tôles (DEC-080) : une forme fermée prend l'aspect d'une caisse blindée rivetée ; transparente en vue écorchée
	var XY := func(q: Vector2) -> Array: return [X.call(q.x), Y.call(q.y)]
	for poly in ConstructionLibre.toles_fermees(a):
		var fond := "#4C5236" if String(a.get("peinture", "")) == "" else "#" + Color(String(a.peinture)).darkened(0.3).to_html(false)
		formes.append({"pts": Array(poly).map(func(q): return XY.call(q)), "c": fond + ("55" if ecorche else ""), "z": 3})
		var ctr := Vector2.ZERO
		for q in poly:
			ctr += q
		ctr /= poly.size()
		for i in poly.size():
			var qa: Vector2 = poly[i]
			var qb: Vector2 = poly[(i + 1) % poly.size()]
			var n := maxi(1, int(qa.distance_to(qb) * 1.5))
			for k in n:   # rivets le long du bord, un peu à l'intérieur
				var q := qa.lerp(qb, (float(k) + 0.5) / n)
				q = q.lerp(ctr, 0.18 / maxf(0.5, q.distance_to(ctr)))
				formes.append({"pts": _poly_cercle(X.call(q.x), Y.call(q.y), 0.022, 6), "c": "#9A9A88" + ("55" if ecorche else ""), "z": 3})
	for t in ConstructionLibre.toles_de(a):
		formes.append({"ligne": [XY.call(t.a), XY.call(t.b)], "ep": 0.06, "c": "#3A3F2C", "z": 3})
	var res := {"x0": x0, "sol": sol, "nom": String(a.get("nom", "Frankenstein")), "longueur": maxf(0.5, (x1 - x0) * ConstructionLibre.C), "hauteur": maxf(0.5, (y1 - sol) * ConstructionLibre.C),
		"teinte": "joueur", "moteur": moteur, "course": 0.09, "fiche": "Véhicule construit sur la grille.",
		"roues": roues, "formes": formes, "armes": armes, "equipage": equipage, "libre": true}
	if chenille.is_empty() and absf(float(an.detail.get("assiette", 0.0))) > 0.0005:   # véhicule penché (DEC-081)
		res.assiette = float(an.detail.assiette)
		res.pivot = [X.call(an.detail.pivot.x), Y.call(an.detail.pivot.y)]
	if String(a.get("peinture", "")) != "":   # peinture de bande (DEC-080) : ton de tout le véhicule
		res.peinture = String(a.peinture)
	if ConstructionLibre.remorque(a):
		res.remorque = true
	if not chenille.is_empty():
		res.chenille = chenille
	if a.has("base"):   # base véhicule (Grille V2) : visuels étirés par la rallonge
		res = BaseVehicule.habiller(a, res)
	return res


# --- Visuels dessinés (planches ChatGPT, DEC-066) ------------------------------------------------
const STYLE_SPRITE := {"camion": "cabine_camion", "voiture": "cabine_berline", "blindee": "cabine_blindee", "ouverte": "cabine_jeep"}


# Rectangle [x, y_bas, l, h] d'un visuel dans la pièce r : remplit la pièce si les proportions sont proches, sinon contenu (centré, posé en bas)
static func _rect_sprite(id: String, r: Rect2, remplir: bool) -> Array:
	var t: Texture2D = VehiculeDessin._tex(id)
	var k := t.get_size().x / t.get_size().y
	var w := r.size.x
	var h := r.size.y
	if not remplir or absf(k / (w / h) - 1.0) > 0.35:
		if w / h > k:
			w = h * k
		else:
			h = w / k
	return [r.position.x + (r.size.x - w) * 0.5, r.position.y, w, h]


static func _sprite(formes: Array, id: String, r: Rect2, z: int, remplir := true) -> void:
	formes.append({"sprite": id, "r": _rect_sprite(id, r, remplir), "z": z})


# Liaison d'un pont rigide (DEC-070) : y_ch = dessous du châssis, y_p = centre du pont (m) ; vers_c = le centre du véhicule est à droite
static func _formes_liaison(formes: Array, dessin: String, cx: float, y_ch: float, y_p: float, vers_c: bool) -> void:
	var s := 1.0 if vers_c else -1.0
	formes.append({"pts": _poly_cercle(cx, y_p, 0.11, 8), "c": "sombre", "z": 1})   # carter du pont
	match dessin:
		"lames":   # paquet de lames sous le châssis, jumelles aux extrémités
			for k in 3:
				var yk := y_p + 0.05 + k * 0.035
				formes.append({"ligne": [[cx - 0.55, y_ch - 0.02], [cx, yk]], "ep": 0.03, "c": "metal", "z": 1})
				formes.append({"ligne": [[cx, yk], [cx + 0.55, y_ch - 0.02]], "ep": 0.03, "c": "metal", "z": 1})
		_:   # tirants vers le centre du véhicule, ressort hélicoïdal et amortisseur
			var long := 0.9 if dessin == "tirants" else 1.4
			formes.append({"ligne": [[cx, y_p], [cx + s * long, y_ch]], "ep": 0.05, "c": "metal", "z": 1})
			formes.append({"ligne": [[cx, y_p - 0.06], [cx + s * long * 0.8, y_ch - 0.04]], "ep": 0.035, "c": "metal", "z": 1})
			var n := 7 if dessin == "tirants" else 11
			var xr := cx - s * 0.12
			for k in n:
				var ya := lerpf(y_p, y_ch, float(k) / n)
				var yb := lerpf(y_p, y_ch, float(k + 1) / n)
				formes.append({"ligne": [[xr - 0.07, ya], [xr + 0.07, yb]], "ep": 0.03, "c": "#8A4A2A", "z": 1})
			if dessin == "rehausse":
				formes.append({"ligne": [[cx + s * 0.14, y_p], [cx + s * 0.22, y_ch]], "ep": 0.045, "c": "sombre", "z": 1})


# Greffes (DEC-079) : formes dessinées dans le rectangle r de la pièce (mètres, y vers le haut)
static func _formes_greffe(formes: Array, dessin: String, r: Rect2) -> void:
	var x0 := r.position.x
	var y0 := r.position.y
	var w := r.size.x
	var h := r.size.y
	match dessin:
		"pare_buffle":   # cadre de barres, plus incliné vers l'avant
			formes.append({"ligne": [[x0 + w * 0.1, y0 + h * 0.05], [x0 + w * 0.9, y0 + h * 0.25]], "ep": 0.07, "c": "#B9B2A0", "z": 3})
			formes.append({"ligne": [[x0 + w * 0.1, y0 + h * 0.95], [x0 + w * 0.9, y0 + h * 0.75]], "ep": 0.07, "c": "#B9B2A0", "z": 3})
			formes.append({"ligne": [[x0 + w * 0.9, y0 + h * 0.25], [x0 + w * 0.9, y0 + h * 0.75]], "ep": 0.08, "c": "#B9B2A0", "z": 3})
			formes.append({"ligne": [[x0 + w * 0.5, y0 + h * 0.15], [x0 + w * 0.5, y0 + h * 0.85]], "ep": 0.04, "c": "sombre", "z": 3})
		"piques":   # rangée de pointes
			var n := maxi(2, int(round(w / 0.17)))
			formes.append({"ligne": [[x0, y0 + 0.03], [x0 + w, y0 + 0.03]], "ep": 0.05, "c": "sombre", "z": 3})
			for k in n:
				var cx := x0 + (float(k) + 0.5) * w / n
				formes.append({"pts": [[cx - 0.05, y0 + 0.05], [cx + 0.05, y0 + 0.05], [cx, y0 + h * 0.95]], "c": "#B9B2A0", "z": 3})
		"bidons":   # deux jerrycans
			for k in 2:
				var bx := x0 + w * (0.06 + 0.46 * k)
				var bw := w * 0.42
				formes.append({"pts": [[bx, y0], [bx + bw, y0], [bx + bw, y0 + h * 0.8], [bx + bw * 0.7, y0 + h * 0.95], [bx, y0 + h * 0.95]], "c": "#6E7038" if k == 0 else "#8A4A2A", "z": 3})
				formes.append({"ligne": [[bx + bw * 0.15, y0 + h * 0.5], [bx + bw * 0.85, y0 + h * 0.5]], "ep": 0.02, "c": "sombre", "z": 3})
		"timon":   # barre triangulée et anneau d'attelage
			formes.append({"ligne": [[x0, y0 + h * 0.9], [x0 + w * 0.92, y0 + h * 0.4]], "ep": 0.05, "c": "#B9B2A0", "z": 3})
			formes.append({"ligne": [[x0, y0 + h * 0.1], [x0 + w * 0.92, y0 + h * 0.4]], "ep": 0.05, "c": "#B9B2A0", "z": 3})
			formes.append({"pts": _poly_cercle(x0 + w * 0.95, y0 + h * 0.4, 0.06, 8), "c": "sombre", "z": 3})
		"gazogene":   # cuve cylindrique du gazogène, couvercle, tuyau et filtre (DEC-158)
			formes.append({"pts": [[x0 + w * 0.08, y0], [x0 + w * 0.62, y0], [x0 + w * 0.62, y0 + h * 0.88], [x0 + w * 0.08, y0 + h * 0.88]], "c": "#4A4A44", "z": 3})
			formes.append({"pts": [[x0 + w * 0.02, y0 + h * 0.88], [x0 + w * 0.68, y0 + h * 0.88], [x0 + w * 0.6, y0 + h], [x0 + w * 0.1, y0 + h]], "c": "#2E2E2A", "z": 3})
			for k in 3:
				formes.append({"ligne": [[x0 + w * 0.08, y0 + h * (0.25 + 0.22 * k)], [x0 + w * 0.62, y0 + h * (0.25 + 0.22 * k)]], "ep": 0.02, "c": "#7A3A1E", "z": 3})
			formes.append({"ligne": [[x0 + w * 0.62, y0 + h * 0.7], [x0 + w * 0.95, y0 + h * 0.7], [x0 + w * 0.95, y0 + h * 0.15]], "ep": 0.05, "c": "#8A8A80", "z": 3})
			formes.append({"pts": [[x0 + w * 0.78, y0], [x0 + w * 1.0, y0], [x0 + w * 1.0, y0 + h * 0.3], [x0 + w * 0.78, y0 + h * 0.3]], "c": "#6A5238", "z": 3})
		"drapeau":   # mât et fanion
			formes.append({"ligne": [[x0 + w * 0.2, y0], [x0 + w * 0.2, y0 + h]], "ep": 0.03, "c": "#B9B2A0", "z": 3})
			formes.append({"pts": [[x0 + w * 0.2, y0 + h], [x0 + w * 1.0, y0 + h * 0.82], [x0 + w * 0.2, y0 + h * 0.62]], "c": "#9A2F2F", "z": 3})


# --- Formes simples des cabines et des postes (DEC-062) -----------------------------------------
static func _pt(r: Rect2, fx: float, fy: float) -> Array:   # fraction de la pièce -> mètres (y vers le haut)
	return [r.position.x + fx * r.size.x, r.position.y + fy * r.size.y]


static func _poly(r: Rect2, pts: Array) -> Array:
	return pts.map(func(q): return _pt(r, q[0], q[1]))


# Cadre autour d'une ouverture : une bande par côté entre le contour et l'ouverture (même nombre de sommets)
static func _cadre(formes: Array, ext: Array, int_: Array, couleur: String) -> void:
	for i in ext.size():
		var j := (i + 1) % ext.size()
		formes.append({"pts": [ext[i], ext[j], int_[j], int_[i]], "c": couleur, "z": 1})


# Cabine vue de profil, tournée vers la droite. Le fond sombre passe derrière l'équipage (z -1), la vitre
# (z 2) est translucide : on voit les occupants à travers. Styles : camion, voiture, blindee, bricolee, ouverte.
static func _formes_cabine(formes: Array, style: String, r: Rect2) -> void:
	var vitre := "#2E3A40B8"
	var bas := []
	var ext := []
	var inte := []
	var fond := []
	match style:
		"camion":
			bas = [[0, 0], [1, 0], [1, 0.36], [0, 0.36]]
			ext = [[0.0, 0.36], [1.0, 0.36], [0.90, 1.0], [0.02, 1.0], [0.0, 0.94]]
			inte = [[0.10, 0.42], [0.92, 0.42], [0.85, 0.88], [0.10, 0.88], [0.10, 0.88]]
			fond = [[0, 0], [1, 0], [1, 0.36], [0.90, 1.0], [0.02, 1.0], [0, 0.94]]
		"voiture":
			bas = [[0, 0], [1, 0], [1, 0.30], [0.92, 0.40], [0.0, 0.40], [0.0, 0.12]]
			ext = [[0.14, 0.40], [0.72, 0.40], [0.54, 0.92], [0.28, 0.92]]
			inte = [[0.19, 0.44], [0.67, 0.44], [0.52, 0.86], [0.30, 0.86]]
			fond = [[0, 0], [1, 0], [1, 0.30], [0.92, 0.40], [0.72, 0.40], [0.54, 0.92], [0.28, 0.92], [0.14, 0.40], [0.0, 0.40]]
		"blindee":
			bas = [[0, 0], [1, 0], [1, 0.45], [0, 0.45]]
			ext = [[0.0, 0.45], [1.0, 0.45], [0.84, 0.88], [0.12, 0.96], [0.0, 0.80]]
			inte = [[0.22, 0.62], [0.80, 0.62], [0.76, 0.70], [0.24, 0.74], [0.22, 0.72]]
			fond = [[0, 0], [1, 0], [1, 0.45], [0.84, 0.88], [0.12, 0.96], [0.0, 0.80]]
			formes.append({"pts": _poly(r, [[0.40, 0.92], [0.62, 0.89], [0.60, 1.0], [0.42, 1.0]]), "c": "metal", "z": 2})
		"bricolee":
			bas = [[0, 0], [1, 0], [1, 0.30], [0, 0.30]]
			ext = [[0.0, 0.30], [1.0, 0.30], [0.95, 0.76], [0.80, 1.0], [0.12, 0.92], [0.0, 0.70]]
			inte = [[0.12, 0.38], [0.82, 0.38], [0.84, 0.68], [0.74, 0.84], [0.18, 0.80], [0.12, 0.70]]
			fond = [[0, 0], [1, 0], [1, 0.30], [0.95, 0.76], [0.80, 1.0], [0.12, 0.92], [0.0, 0.70]]
			formes.append({"ligne": [_pt(r, 0.10, 0.95), _pt(r, 0.10, 1.2), _pt(r, 0.86, 1.2), _pt(r, 0.86, 0.95)], "ep": 0.03, "c": "metal", "z": 2})
			formes.append({"ligne": [_pt(r, 0.45, 0.30), _pt(r, 0.45, 0.0)], "ep": 0.02, "c": "metal", "z": 2})
		_:   # ouverte : portière basse et cadre de pare-brise
			bas = [[0, 0], [1, 0], [1, 0.45], [0, 0.45]]
			ext = [[0.82, 0.45], [0.98, 0.45], [0.88, 1.0], [0.80, 1.0]]
			inte = [[0.85, 0.52], [0.94, 0.52], [0.86, 0.94], [0.83, 0.94]]
	if not fond.is_empty():
		formes.append({"pts": _poly(r, fond), "c": "sombre", "z": -1})
	formes.append({"pts": _poly(r, bas), "c": "caisse", "z": 1})
	if not ext.is_empty():
		var E := _poly(r, ext)
		var I := _poly(r, inte)
		_cadre(formes, E, I, "caisse")
		formes.append({"pts": I, "c": vitre, "z": 2})
	if style == "camion" or style == "voiture":
		var fx := 0.46 if style == "camion" else 0.44
		formes.append({"ligne": [_pt(r, fx, 0.36 if style == "camion" else 0.40), _pt(r, fx, 0.04)], "ep": 0.02, "c": "sombre", "z": 2})
		formes.append({"ligne": [_pt(r, fx + 0.08, 0.30), _pt(r, fx + 0.14, 0.30)], "ep": 0.025, "c": "metal", "z": 2})


# Postes : siège, volant, banc (formes simples, tournées vers la droite ; le banc arrière est inversé)
static func _formes_poste(formes: Array, f: Dictionary, r: Rect2) -> void:
	var w := r.size.x
	var X := func(fx: float) -> float: return r.position.x + fx * w
	var Y := func(m: float) -> float: return r.position.y + m
	match String(f.get("poste", "")):
		"banc":
			var sens := float(f.get("sens", 1))
			var dos := 0.0 if sens > 0.0 else 1.0
			formes.append({"pts": [[X.call(0.02), Y.call(0.20)], [X.call(0.98), Y.call(0.20)], [X.call(0.98), Y.call(0.27)], [X.call(0.02), Y.call(0.27)]], "c": "bois", "z": 2})
			for fx in [0.10, 0.90]:
				formes.append({"ligne": [[X.call(fx), Y.call(0.20)], [X.call(fx), Y.call(0.0)]], "ep": 0.03, "c": "metal", "z": 2})
			formes.append({"ligne": [[X.call(dos), Y.call(0.27)], [X.call(dos), Y.call(0.50)]], "ep": 0.04, "c": "bois", "z": 2})
		"commande":
			formes.append({"ligne": [[X.call(0.40), Y.call(0.0)], [X.call(0.40), Y.call(0.38)]], "ep": 0.05, "c": "metal", "z": 2})
			formes.append({"pts": [[X.call(0.08), Y.call(0.38)], [X.call(0.72), Y.call(0.38)], [X.call(0.72), Y.call(0.45)], [X.call(0.08), Y.call(0.45)]], "c": "sombre", "z": 2})
			formes.append({"pts": [[X.call(0.04), Y.call(0.45)], [X.call(0.18), Y.call(0.45)], [X.call(0.14), Y.call(0.74)], [X.call(0.02), Y.call(0.74)]], "c": "sombre", "z": 2})
			formes.append({"ligne": [[X.call(0.84), Y.call(0.40)], [X.call(0.84), Y.call(0.80)]], "ep": 0.03, "c": "metal", "z": 2})   # périscope
			formes.append({"ligne": [[X.call(0.80), Y.call(0.80)], [X.call(0.96), Y.call(0.80)]], "ep": 0.04, "c": "metal", "z": 2})
		_:
			formes.append({"ligne": [[X.call(0.40), Y.call(0.0)], [X.call(0.40), Y.call(0.19)]], "ep": 0.05, "c": "metal", "z": 2})
			formes.append({"pts": [[X.call(0.08), Y.call(0.19)], [X.call(0.72), Y.call(0.19)], [X.call(0.72), Y.call(0.26)], [X.call(0.08), Y.call(0.26)]], "c": "sombre", "z": 2})
			formes.append({"pts": [[X.call(0.04), Y.call(0.26)], [X.call(0.18), Y.call(0.26)], [X.call(0.14), Y.call(0.50)], [X.call(0.02), Y.call(0.50)]], "c": "sombre", "z": 2})
			if String(f.get("poste", "")) == "conduite":   # tableau de bord et volant
				formes.append({"pts": [[X.call(0.80), Y.call(0.10)], [X.call(1.0), Y.call(0.10)], [X.call(1.0), Y.call(0.38)], [X.call(0.86), Y.call(0.38)]], "c": "metal", "z": 2})
				formes.append({"ligne": [[X.call(0.82), Y.call(0.36)], [X.call(0.66), Y.call(0.46)]], "ep": 0.03, "c": "metal", "z": 2})


