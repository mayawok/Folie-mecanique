# Véhicule de profil en formes simples, dessiné par le code à partir de
# data/formes_vehicules.json : caisse, roues qui tournent, chenilles à maillons,
# suspensions à ressort, armes (rafale, recul du canon), équipage.
# L'origine du dessin est le coin bas gauche du contrôle (arrière du véhicule, au sol).
class_name VehiculeDessin
extends Control

const RAIDEUR := 140.0      # ressort de la caisse
const AMORTI := 9.0
const MAILLON := 0.17       # longueur d'un maillon de chenille (m)

static var _data := {}

var type := "willys_mb"
var ppm := 55.0             # pixels par mètre
var vitesse := 0.0          # m/s ; le dessin avance vers l'avant du véhicule
var miroir := false         # regarde vers la gauche
var ennemi := false         # teinte et équipage de pillards
var equipage := true
var sans_roues := false     # épave irréparable : roues arrachées, la caisse repose au sol
var equipage_dehors := false  # réparation : tout l'équipage est descendu sauf le chef de char (on ne le voit plus à bord)
var troupes_a_bord := -1    # nombre de soldats encore sur les bancs (-1 = tous)
var _decal := Vector2.ZERO   # décalage du dessin (épave sans roues)
var x_monde := 0.0          # position de l'arrière dans le monde (m), pour lire le relief
var sol := Callable()       # sol(x_m) -> hauteur du sol (m) ; vide = sol plat

var D: Dictionary
var dist := 0.0
var _h := 0.0
var _hv := 0.0
var _p := 0.0
var _pv := 0.0
var _xc := 0.0
var _appuis := []           # {x, r, y0, y} : roues et galets qui suivent le sol
var _temps := 0.0
var _flash := 0.0
var _flash_mg := 0.0
var _recul := 0.0
var _rafale := 0
var _t_rafale := 0.0
var _fumee := []            # {pos, age}
var _teinte := Color.OLIVE
var _voile := Color.WHITE    # peinture de bande (DEC-080) : ton posé sur les visuels dessinés
var roues_perdues: Array = []   # indices des roues arrachées en combat (DEC-080) : on ne les dessine plus


static func donnees() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open("res://data/formes_vehicules.json", FileAccess.READ)
		_data = JSON.parse_string(f.get_as_text())
	return _data


static func existe(t: String) -> bool:
	return donnees().vehicules.has(t)


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	if D.is_empty():
		configurer(type)


func configurer(t: String) -> void:
	type = t
	configurer_d(donnees().vehicules[t])


# Dessin à partir d'une description directe (atelier : une pièce seule, découpée dans un véhicule).
func configurer_d(d: Dictionary) -> void:
	D = d
	var teintes: Dictionary = donnees().teintes
	_teinte = Color(teintes.pillards if ennemi else teintes[D.teinte])
	_voile = Color.WHITE
	if D.has("peinture") and not ennemi:
		_teinte = Color(String(D.peinture))
		_voile = Color.WHITE.lerp(_teinte.lightened(0.25), 0.55)
	custom_minimum_size = Vector2(D.longueur, D.hauteur) * ppm
	size = custom_minimum_size
	_appuis.clear()
	for r in D.get("roues", []):
		_appuis.append({"x": float(r.x), "r": float(r.r), "y0": float(r.r), "y": float(r.r)})
	if D.has("chenille"):
		var c: Dictionary = D.chenille
		for x in c.galets:
			var y0: float = c.r_galet + c.ep
			_appuis.append({"x": float(x), "r": float(c.r_galet), "y0": y0, "y": y0, "galet": true})
	_xc = 0.0
	for a in _appuis:
		_xc += a.x
	_xc /= maxf(1, _appuis.size())
	_h = 0.0
	_hv = 0.0
	_p = 0.0
	_pv = 0.0
	queue_redraw()


# Tir : rafale pour une mitrailleuse, recul et fumée pour un canon. Renvoie le type tiré.
# `arme` ("canon" ou "mitrailleuse") force l'arme animée ; vide = canon s'il y en a un.
func tirer(arme := "") -> String:
	var canon := false
	for a in D.get("armes", []):
		canon = canon or a.type in ["canon", "mortier"]
	if arme != "":
		canon = canon and arme == "canon"
	if canon:
		_flash = 0.12
		_recul = 1.0
		_fumee.append({"age": 0.0})
		_pv += 0.35    # le recul cabre légèrement la caisse
		return "canon"
	_rafale = 6
	_t_rafale = 0.0
	return "mitrailleuse"


func _process(delta: float) -> void:
	delta = minf(delta, 1.0 / 30.0)
	_temps += delta
	dist += vitesse * delta
	# Roues et galets : chacun suit le sol, dans la limite du débattement
	var n := _appuis.size()
	var sx := 0.0
	var sy := 0.0
	var sxx := 0.0
	var sxy := 0.0
	for a in _appuis:
		var cible: float = _sol(a.x) + a.y0
		var off: float = cible - a.y0
		sx += a.x
		sy += off
		sxx += a.x * a.x
		sxy += a.x * off
	var pente := 0.0
	var moy := 0.0
	if n > 0:
		moy = sy / n
		var var_x := sxx / n - pow(sx / n, 2)
		if var_x > 0.0001:
			pente = clampf((sxy / n - (sx / n) * (sy / n)) / var_x, -0.3, 0.3)
	# Caisse suspendue : ressort amorti vers la position imposée par le sol
	var vib := 0.006 * sin(_temps * 37.0) if vitesse != 0.0 else 0.0
	_hv += (RAIDEUR * (moy + vib - _h) - AMORTI * _hv) * delta
	_h += _hv * delta
	_pv += (RAIDEUR * (pente - _p) - AMORTI * _pv) * delta
	_p += _pv * delta
	var course: float = D.get("course", 0.1)
	for a in _appuis:
		var repos: float = a.y0 + _h + _p * (a.x - _xc)
		a.y = clampf(_sol(a.x) + a.y0, repos - course, repos + course)
	# Armes
	_flash = maxf(0.0, _flash - delta)
	_flash_mg = maxf(0.0, _flash_mg - delta)
	_recul = maxf(0.0, _recul - delta * 3.0)
	if _rafale > 0:
		_t_rafale -= delta
		if _t_rafale <= 0.0:
			_rafale -= 1
			_flash_mg = 0.045
			_t_rafale = 0.085
	for f in _fumee:
		f.age += delta
	_fumee = _fumee.filter(func(f): return f.age < 1.6)
	queue_redraw()


func _sol(xl: float) -> float:
	return sol.call(x_monde + xl) if sol.is_valid() else 0.0


# --- Repères ---------------------------------------------------------------

# Mètres (repère du véhicule, sans tangage) -> pixels
func _e(m: Vector2) -> Vector2:
	var x := (float(D.longueur) - m.x) if miroir else m.x
	return Vector2(x * ppm, size.y - m.y * ppm)


# Point de la caisse (suspendue, inclinée) -> pixels
func _c(m: Vector2) -> Vector2:
	var q := (m - Vector2(_xc, 0)).rotated(atan(_p)) + Vector2(_xc, _h)
	return _e(q)


func _coul(nom: String) -> Color:
	match nom:
		"caisse": return _teinte
		"sombre": return _teinte.darkened(0.38)
		"clair": return _teinte.lightened(0.18)
		"vitre": return Color("#2E3A40")
		"metal": return Color("#3C3C3A")
		"pneu": return Color("#1E1D1B")
		"bois": return Color("#6D5032") if not ennemi else Color("#5E4430")
		"toile": return Color("#8A8460")
	return Color(nom)


# --- Dessin ----------------------------------------------------------------

func _draw() -> void:
	if D.is_empty():
		return
	if sans_roues and not D.has("chenille"):
		var chute := 0.0
		for a in _appuis:
			chute = maxf(chute, a.r)
		_decal = Vector2(0, chute * ppm * 0.85)
		draw_set_transform(_decal)
		_formes(0)
		_formes(1)
		_formes(2)
		_formes(3)
		_armes()
		_decal = Vector2.ZERO
		draw_set_transform(_decal)
		return
	for r in D.get("roues_fond", []):
		_roue(_c(Vector2(r.x, r.r)), r.r, 0.65)
	_formes(-1)
	if equipage:
		_equipage()
	_formes(0)
	_train()
	_formes(1)
	_formes(2)
	_formes(3)   # coques de donneur (DEC-067)
	_armes()


func _formes(z: int) -> void:
	for f in D.formes:
		if int(f.get("z", 1)) != z:
			continue
		var c := _coul(f.get("c", "caisse"))
		if f.has("pts"):
			var pts := PackedVector2Array()
			for p in f.pts:
				pts.append(_c(Vector2(p[0], p[1])))
			draw_colored_polygon(pts, c)
			pts.append(pts[0])
			draw_polyline(pts, c.darkened(0.45), maxf(1.0, ppm * 0.025), true)
		elif f.has("sprite"):
			var q: Array = f.r
			_sprite(String(f.sprite), q[0], q[1], q[2], q[3], 0.0, float(f.get("opac", 1.0)), bool(f.get("miroir", false)), f.get("uv", []))
		elif f.has("cercle"):
			var k: Array = f.cercle
			draw_circle(_c(Vector2(k[0], k[1])), k[2] * ppm, c)
		elif f.has("ligne"):
			var l: Array = f.ligne
			draw_line(_c(Vector2(l[0][0], l[0][1])), _c(Vector2(l[1][0], l[1][1])), c, maxf(1.0, f.get("ep", 0.04) * ppm))
		elif f.has("arc"):
			var a: Array = f.arc
			var pts := PackedVector2Array()
			for i in 13:
				var ang := deg_to_rad(lerpf(a[3], a[4], i / 12.0))
				pts.append(_c(Vector2(a[0], a[1]) + Vector2(cos(ang), sin(ang)) * a[2]))
			draw_polyline(pts, c, maxf(1.0, a[5] * ppm), true)


# Visuel dessiné (planches de la grille) : quadrilatère texturé qui suit le relief et le sens du véhicule
func _sprite(id: String, x: float, y: float, w: float, h: float, decal: float, opac := 1.0, miroir := false, uv := []) -> void:
	var t: Texture2D = _tex(id)
	_quad(t, _c(Vector2(x + decal, y + h)), _c(Vector2(x + w + decal, y + h)), _c(Vector2(x + decal, y)), Color(_voile, opac), miroir, uv)


# Les visuels restent en mémoire : une texture qu'aucun objet ne retient est libérée puis rechargée à chaque image (blanche entre-temps)
static var _textures := {}


static func _tex(id: String) -> Texture2D:
	if not _textures.has(id):
		_textures[id] = load(("res://assets/%s.png" if "/" in id else "res://assets/grille/%s.png") % id)   # "coques/…" : autre dossier
	return _textures[id]


# Texture posée sur un parallélogramme (coin haut-gauche, haut-droit, bas-gauche) : suit l'inclinaison et le sens du véhicule
func _quad(t: Texture2D, hg: Vector2, hd: Vector2, bg: Vector2, teinte: Color, miroir_h := false, uv := []) -> void:   # uv : morceau [u0, v0, u1, v1] (coque sciée)   # miroir_h : image retournée (coque posée à l'envers)
	draw_set_transform(hg + _decal, (hd - hg).angle(), Vector2(1.0, 1.0))
	var larg := (hd - hg).length()
	var haut := (bg - hg).length()
	var flip := (hd - hg).cross(bg - hg) < 0.0   # véhicule tourné vers la gauche : l'image se retourne
	var x0 := 0.0   # une largeur négative retourne l'image sans la déplacer
	var lx := -larg if miroir_h else larg
	var dest := Rect2(x0, haut, lx, -haut) if flip else Rect2(x0, 0, lx, haut)
	if uv.size() == 4:
		var ts := t.get_size()
		draw_texture_rect_region(t, dest, Rect2(float(uv[0]) * ts.x, float(uv[1]) * ts.y, (float(uv[2]) - float(uv[0])) * ts.x, (float(uv[3]) - float(uv[1])) * ts.y), teinte)
	else:
		draw_texture_rect(t, dest, false, teinte)
	draw_set_transform(_decal)


func _sens() -> float:
	return -1.0 if miroir else 1.0


# Roue : pneu, jante, rayons qui tournent avec la distance parcourue
func _roue(c: Vector2, r: float, clarte := 1.0) -> void:
	var rp := r * ppm
	if D.get("libre", false):   # visuel dessiné, qui tourne
		var t: Texture2D = _tex("roue_petite" if r < 0.3 else ("roue_moyenne" if r < 0.5 else "roue_grande"))
		var ang0 := dist / r * _sens()
		_quad(t, c + Vector2(-rp, -rp).rotated(ang0), c + Vector2(rp, -rp).rotated(ang0), c + Vector2(-rp, rp).rotated(ang0), Color(clarte, clarte, clarte))
		return
	draw_circle(c, rp, _coul("pneu").lerp(Color.BLACK, 1.0 - clarte))
	draw_circle(c, rp * 0.62, _teinte.darkened(0.25).lerp(Color.BLACK, 1.0 - clarte))
	draw_circle(c, rp * 0.2, Color("#2B2A27"))
	var ang := dist / r * _sens()
	for k in 5:
		var d := Vector2.from_angle(ang + k * TAU / 5)
		draw_line(c + d * rp * 0.22, c + d * rp * 0.55, Color("#2B2A27"), maxf(1.0, rp * 0.07))
	for k in 10:
		var d := Vector2.from_angle(ang + k * TAU / 10)
		draw_line(c + d * rp * 0.82, c + d * rp * 0.98, Color("#3A3936"), maxf(1.0, rp * 0.06))


func _ressort(a: Vector2, b: Vector2) -> void:
	var n := 7
	var dir := b - a
	var perp := dir.orthogonal().normalized() * ppm * 0.06
	var pts := PackedVector2Array([a])
	for i in range(1, n):
		pts.append(a + dir * (float(i) / n) + perp * (1.0 if i % 2 else -1.0))
	pts.append(b)
	draw_polyline(pts, Color("#2F2E2B"), maxf(1.0, ppm * 0.03), true)


func _train() -> void:
	# Suspensions : ressort entre le moyeu et la caisse
	for a in _appuis:
		var moyeu := _e(Vector2(a.x, a.y))
		var attache := _c(Vector2(a.x, a.y0 + (0.28 if a.has("galet") else a.r * 0.9)))
		_ressort(moyeu, attache)
	if D.has("chenille"):
		_chenille()
	for i in _appuis.size():
		var a: Dictionary = _appuis[i]
		if not a.has("galet") and not roues_perdues.has(i):
			_roue(_e(Vector2(a.x, a.y)), a.r)


func _chenille() -> void:
	var c: Dictionary = D.chenille
	var ep: float = c.ep
	var cercles := []   # [centre px, rayon m]
	var b: Array = c.barbotin
	var t: Array = c.tendeur
	cercles.append([_c(Vector2(b[0], b[1])), float(b[2])])
	cercles.append([_c(Vector2(t[0], t[1])), float(t[2])])
	for a in _appuis:
		if a.has("galet"):
			cercles.append([_e(Vector2(a.x, a.y)), a.r])
	for x in c.get("rouleaux", []):
		cercles.append([_c(Vector2(x, b[1] + b[2] - 0.08)), 0.08])
	# Bande = enveloppe convexe des roues, écartée d'une demi-épaisseur
	var nuage := PackedVector2Array()
	for k in cercles:
		for i in 16:
			nuage.append(k[0] + Vector2.from_angle(i * TAU / 16) * (k[1] + ep * 0.5) * ppm)
	var env := Geometry2D.convex_hull(nuage)
	draw_polyline(env, Color("#2A2825"), ep * ppm, true)
	# Maillons : défilent le long de la bande (le brin du haut avance)
	var long_tot := 0.0
	for i in env.size() - 1:
		long_tot += env[i].distance_to(env[i + 1])
	var pas := MAILLON * ppm
	var sens := 1.0 if _aire(env) > 0 else -1.0
	var depart := fposmod(dist * ppm * sens * _sens(), pas)
	var parcouru := 0.0
	var prochain := depart
	for i in env.size() - 1:
		var a2 := env[i]
		var b2 := env[i + 1]
		var l := a2.distance_to(b2)
		var u := (b2 - a2) / maxf(l, 0.001)
		while prochain <= parcouru + l:
			var p := a2 + u * (prochain - parcouru)
			var nrm := u.orthogonal() * ep * ppm * 0.55
			draw_line(p - nrm, p + nrm, Color("#4A4742"), maxf(1.0, pas * 0.35))
			prochain += pas
		parcouru += l
	# Barbotin denté, galet tendeur, rouleaux, galets
	var ang := dist / float(b[2]) * _sens()
	var cb: Vector2 = cercles[0][0]
	draw_circle(cb, b[2] * ppm, Color("#34332F"))
	for k in 10:
		draw_circle(cb + Vector2.from_angle(ang + k * TAU / 10) * b[2] * ppm * 0.92, b[2] * ppm * 0.12, Color("#25241F"))
	draw_circle(cb, b[2] * ppm * 0.35, _teinte.darkened(0.3))
	_roue(cercles[1][0], t[2], 0.95)
	for x in c.get("rouleaux", []):
		draw_circle(_c(Vector2(x, b[1] + b[2] - 0.08)), 0.08 * ppm, Color("#3A3936"))
	for x in c.get("galets_fond", []):
		var y := 0.0
		for a in _appuis:   # hauteur moyenne des galets voisins
			if a.has("galet") and absf(a.x - x) < 0.4:
				y = maxf(y, a.y)
		_roue(_e(Vector2(x, y if y > 0 else c.r_galet + ep)), c.r_galet, 0.6)
	for a in _appuis:
		if a.has("galet"):
			_roue(_e(Vector2(a.x, a.y)), a.r)


static func _aire(p: PackedVector2Array) -> float:
	var s := 0.0
	for i in p.size() - 1:
		s += p[i].x * p[i + 1].y - p[i + 1].x * p[i].y
	return s


func _armes() -> void:
	for a in D.get("armes", []):
		var base := Vector2(a.x, a.y)
		var ep: float = a.ep
		if a.has("sprite"):   # visuel dessiné : seuls le recul et les flammes restent calculés
			var q: Array = a.r
			var rec := _recul * 0.3 if a.type == "canon" else 0.0
			_sprite(String(a.sprite), q[0], q[1], q[2], q[3], -rec)
			var bt: Vector2 = Vector2(a.bout[0], a.bout[1]) if a.has("bout") else Vector2(q[0] + q[2], q[1] + q[3] * 0.8)
			if a.type == "mitrailleuse" and _flash_mg > 0.0:
				_eclair(_c(bt), 0.22)
			elif _flash > 0.0:
				_eclair(_c(bt + Vector2(0.1, 0)), 0.55 if a.type == "canon" else 0.4)
			if a.type == "canon":
				for fu in _fumee:
					var k2: float = fu.age / 1.6
					draw_circle(_c(bt + Vector2(0.4 + k2 * 1.4, 0.1 + k2 * 0.6)), (0.25 + k2 * 0.7) * ppm, Color(0.75, 0.72, 0.66, 0.45 * (1.0 - k2)))
			continue
		if a.type == "mitrailleuse":
			var haut := base + Vector2(0, a.pied)
			if a.pied > 0:
				draw_line(_c(base), _c(haut), Color("#2F2E2B"), maxf(1.0, 0.05 * ppm))
			var boite := PackedVector2Array([_c(haut + Vector2(-0.16, -0.05)), _c(haut + Vector2(0.16, -0.05)),
				_c(haut + Vector2(0.16, 0.09)), _c(haut + Vector2(-0.16, 0.09))])
			draw_colored_polygon(boite, Color("#2B2A27"))
			var bout := haut + Vector2(a.long - 0.16, 0.02)
			draw_line(_c(haut + Vector2(0.16, 0.02)), _c(bout), Color("#24231F"), maxf(1.0, ep * ppm))
			if _flash_mg > 0.0:
				_eclair(_c(bout), 0.22)
		elif a.type == "mortier":   # tube court levé à 55°, sur sa plaque de base
			var bout: Vector2 = base + Vector2(0.57, 0.82) * a.long
			draw_line(_c(base), _c(bout), _teinte.darkened(0.45), maxf(2.0, ep * ppm))
			draw_line(_c(base + Vector2(0.15, 0.0)), _c(base + Vector2(0.3, 0.35) * a.long), Color("#2F2E2B"), maxf(1.0, 0.03 * ppm))
			if _flash > 0.0:
				_eclair(_c(bout), 0.4)
		else:
			var recul := _recul * 0.3
			var debut := base + Vector2(-recul, 0)
			var bout := debut + Vector2(a.long, 0)
			var pts := PackedVector2Array([_c(debut + Vector2(0, -ep / 2)), _c(bout + Vector2(0, -ep * 0.4)),
				_c(bout + Vector2(0, ep * 0.4)), _c(debut + Vector2(0, ep / 2))])
			draw_colored_polygon(pts, _teinte.darkened(0.2))
			draw_polyline(pts + PackedVector2Array([pts[0]]), _teinte.darkened(0.55), maxf(1.0, ppm * 0.02))
			if a.get("frein", false):
				draw_rect(_rect_c(bout + Vector2(-0.25, -ep * 0.9), bout + Vector2(0, ep * 0.9)), _teinte.darkened(0.35))
			if _flash > 0.0:
				_eclair(_c(bout + Vector2(0.1, 0)), 0.55)
			for f in _fumee:
				var k: float = f.age / 1.6
				draw_circle(_c(bout + Vector2(0.4 + k * 1.4, 0.1 + k * 0.6)), (0.25 + k * 0.7) * ppm,
					Color(0.75, 0.72, 0.66, 0.45 * (1.0 - k)))


func _rect_c(a: Vector2, b: Vector2) -> Rect2:
	var p := _c(a)
	var q := _c(b)
	return Rect2(Vector2(minf(p.x, q.x), minf(p.y, q.y)), (q - p).abs())


func _eclair(p: Vector2, taille: float) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var r := taille * ppm * (1.0 if i % 2 == 0 else 0.4)
		pts.append(p + Vector2.from_angle(i * TAU / 10 + _temps * 7) * r)
	draw_colored_polygon(pts, Color(1.0, 0.85, 0.35, 0.95))
	draw_circle(p, taille * ppm * 0.3, Color(1, 1, 0.85))


func _equipage() -> void:
	var i := 0
	var vus_troupes := 0
	for m in D.get("equipage", []):
		i += 1
		if m.role == "troupe":
			vus_troupes += 1
			if troupes_a_bord >= 0 and vus_troupes > troupes_a_bord:
				continue   # ce soldat est descendu
		elif equipage_dehors and m.role != "chef":
			continue   # descendu réparer : on ne le voit plus à bord
		var var_id := "pillard" if ennemi else ("tireur" if m.role in ["tireur", "chef"] else ("survivante" if i % 2 else "survivant"))
		var debout: bool = m.get("debout", false)
		var pied := _c(Vector2(m.x, m.y))
		var sens: bool = miroir != (float(m.get("dir", 1.0)) < 0.0)   # banc tourné vers l'arrière
		Silhouette.dessiner(self, pied, ppm, var_id, {"assis": true, "h": m.get("h", 0.62 if debout else 0.55),
			"miroir": sens, "peau": i + type.length(), "bras": "vise" if m.role == "tireur" else ""})
