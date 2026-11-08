# Ville standard dessinée par le code (DEC-143), en attendant les textures propres à chaque ville.
# Calques, du plus loin au plus près : palissade du fond de l'enceinte, toits lointains (parallaxe), maisons rafistolées
# (tôles, carcasses, bus, wagons) et leurs habitants, puis le long de la route : marché, atelier, garage, mairie, café,
# dortoirs, et les deux portes de l'enceinte avec leurs gardes. Plusieurs centaines d'habitants, tous dessinés en vecteurs.
# Placé derrière les véhicules (entre le terrain et la couche des véhicules). Lit vue.m.ville (modele_ville.gd).
class_name VilleDessin
extends Control

# Bâtiments le long de la route : [début, fin] en mètres après la porte d'entrée (x0)
const BATS := {"marche": [8.0, 27.0], "atelier": [29.0, 49.0], "garage": [51.0, 64.0], "mairie": [80.0, 100.0], "cafe": [104.0, 119.0], "dortoir": [122.0, 140.0]}
const PORTE_H := 6.5      # hauteur du passage
const TOUR_H := 12.0      # hauteur du chemin de ronde
const ROUILLE := [Color("#7A4E34"), Color("#6B5A48"), Color("#5E6260"), Color("#8A6A45"), Color("#4F5A4C"), Color("#735040"), Color("#6A6E72")]

var vue
var _graine := -1
var _loin: Array = []
var _milieu: Array = []
var _gens: Array = []
var _style_bulle: StyleBoxFlat
var _f: Font


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_style_bulle = StyleBoxFlat.new()
	_style_bulle.bg_color = Color("#F4EEDF")
	_style_bulle.border_color = Color("#2A2520")
	_style_bulle.set_border_width_all(2)
	_style_bulle.set_corner_radius_all(10)
	_f = ThemeDB.fallback_font


func _process(_d: float) -> void:
	visible = vue != null and vue.m != null and vue.m.ville_active()
	if visible:
		queue_redraw()


# --- Repères -------------------------------------------------------------------------------------
var _ppm := 30.0
var _gy := 700.0
var _nuit := 0.0
var _t := 0.0
var _x0 := 0.0
var _x1 := 0.0


func _ex(x: float) -> float:
	return vue.terrain.ecran_x(x)


func _p(x: float, h: float) -> Vector2:
	return Vector2(_ex(x), _gy - h * _ppm)


# Abscisse écran d'un calque lointain (k < 1 : défile moins vite)
func _par(x: float, k: float) -> float:
	var T = vue.terrain
	var cc: float = T.camera_x + (size.x * 0.5 - T.ancre_x) / _ppm
	return size.x * 0.5 + (x - cc) * _ppm * k


func _dans_murs(sx: float, marge := 0.0) -> bool:
	return sx > _ex(_x0) + marge and sx < _ex(_x1) - marge


func _c(c: Color, loin := 0.0) -> Color:
	var r := c.lerp(Color(0.72, 0.66, 0.58), loin)
	return r.lerp(Color(0.09, 0.11, 0.19), 0.68 * _nuit)


func _lampe(intensite := 1.0) -> Color:
	return Color(1.0, 0.78, 0.4, (0.25 + 0.7 * _nuit) * intensite)


# --- Génération (une fois par ville) ---------------------------------------------------------------
func _generer() -> void:
	var V: Dictionary = vue.m.ville
	_graine = int(V.graine)
	var r := RandomNumberGenerator.new()
	r.seed = _graine
	_loin.clear()
	_milieu.clear()
	_gens.clear()
	var x := _x0 - 20.0
	var clocher := r.randf_range(0.3, 0.7)
	while x < _x1 + 20.0:
		var w := r.randf_range(3.0, 8.0)
		var t: String = ["bloc", "bloc", "bloc", "tour", "chem", "reservoir", "grue"][r.randi() % 7]
		if absf((x - _x0) / (_x1 - _x0) - clocher) < 0.04 and not _loin.any(func(o): return o.t == "clocher"):
			t = "clocher"
		_loin.append({"x": x, "w": w, "h": r.randf_range(5.0, 13.0), "t": t, "c": ROUILLE[r.randi() % ROUILLE.size()]})
		x += w * r.randf_range(0.55, 1.0)
	x = _x0 - 6.0
	while x < _x1 + 6.0:
		var w2 := r.randf_range(4.0, 8.5)
		_milieu.append({"x": x, "w": w2, "h": r.randf_range(3.0, 7.0), "t": ["tole", "tole", "bus", "wagon", "pile", "cabane"][r.randi() % 6],
			"c": ROUILLE[r.randi() % ROUILLE.size()], "f": r.randi() % 3})
		x += w2 + r.randf_range(-0.8, 1.5)
	var n := int(CombatModele.VD().habitants)
	for i in n:
		var rang := 0 if r.randf() < 0.62 else 1
		var xi := r.randf_range(_x0 + 4.0, _x1 - 4.0)
		var cafe: bool = rang == 1 and xi - _x0 > BATS.cafe[0] and xi - _x0 < BATS.cafe[1] - 4.0
		_gens.append({"x": xi, "rang": rang, "amp": 0.0 if r.randf() < 0.45 or cafe else r.randf_range(1.0, 5.0), "vit": r.randf_range(0.12, 0.35),
			"ph": r.randf() * TAU, "peau": r.randi() % 6, "assis": cafe and r.randf() < 0.7, "c": ROUILLE[r.randi() % ROUILLE.size()].lightened(0.15),
			"h": r.randf_range(0.9, 1.1)})


# --- Dessin ---------------------------------------------------------------------------------------
func _draw() -> void:
	var m = vue.m
	if m == null or not m.ville_active():
		return
	var V: Dictionary = m.ville
	_x0 = float(V.x0)
	_x1 = float(V.x1)
	if int(V.graine) != _graine:
		_generer()
	_ppm = vue.terrain.ppm
	_gy = vue._sy(_x0 + 40.0)
	_nuit = vue.terrain.nuit
	_t = vue._temps
	_fond()
	_maisons()
	_habitants(0)
	_route()
	_habitants(1)
	_personnages(V)
	_porte(_x0, float(V.porte_e), String(V.nom).to_upper(), 0)
	_porte(_x1, float(V.porte_s), "SORTIE", 1)


# Palissade du fond de l'enceinte et toits lointains
func _fond() -> void:
	var k := 0.3
	var base := _gy - 3.2 * _ppm
	var a := maxf(_par(_x0 - 30.0, k), _ex(_x0))
	var b := minf(_par(_x1 + 30.0, k), _ex(_x1))
	if b > a:
		var hp := 3.0 * _ppm * k
		draw_rect(Rect2(a, base - hp, b - a, hp + 3.2 * _ppm), _c(Color("#5A4A3C"), 0.55))
		var px := a
		while px < b:
			draw_rect(Rect2(px, base - hp - 0.6 * _ppm * k, 0.5 * _ppm * k, 0.6 * _ppm * k), _c(Color("#4A3C30"), 0.55))
			px += 1.6 * _ppm * k
	k = 0.45
	base = _gy - 2.2 * _ppm
	for o in _loin:
		var sx := _par(o.x, k)
		var w: float = o.w * _ppm * k
		if not _dans_murs(sx) and not _dans_murs(sx + w):
			continue
		var h: float = o.h * _ppm * k
		var col := _c(o.c, 0.42)
		match o.t:
			"tour":
				draw_rect(Rect2(sx + w * 0.3, base - h * 1.3, w * 0.4, h * 1.3), col)
				draw_rect(Rect2(sx + w * 0.15, base - h * 1.4, w * 0.7, h * 0.15), col.darkened(0.2))
			"chem":
				draw_rect(Rect2(sx, base - h * 0.7, w, h * 0.7), col)
				draw_rect(Rect2(sx + w * 0.7, base - h * 1.2, w * 0.14, h * 0.5), col.darkened(0.25))
				_fumee(Vector2(sx + w * 0.77, base - h * 1.2), _ppm * k, o.x)
			"reservoir":
				draw_rect(Rect2(sx, base - h * 0.5, w, h * 0.5), col)
				for jx in [0.2, 0.8]:
					draw_line(Vector2(sx + w * jx, base - h * 0.5), Vector2(sx + w * jx, base - h * 1.1), col.darkened(0.3), maxf(1.0, _ppm * k * 0.15))
				draw_rect(Rect2(sx + w * 0.05, base - h * 1.45, w * 0.9, h * 0.38), col.darkened(0.1))
			"grue":
				draw_rect(Rect2(sx, base - h * 0.55, w, h * 0.55), col)
				draw_line(Vector2(sx + w * 0.5, base - h * 0.55), Vector2(sx + w * 0.5, base - h * 1.5), col.darkened(0.3), maxf(1.5, _ppm * k * 0.2))
				draw_line(Vector2(sx + w * 0.5, base - h * 1.5), Vector2(sx + w * 1.6, base - h * 1.35), col.darkened(0.3), maxf(1.5, _ppm * k * 0.15))
			"clocher":
				draw_rect(Rect2(sx, base - h * 1.4, w * 0.6, h * 1.4), _c(Color("#9C8E78"), 0.42))
				draw_colored_polygon(PackedVector2Array([Vector2(sx - w * 0.05, base - h * 1.4), Vector2(sx + w * 0.3, base - h * 2.0), Vector2(sx + w * 0.65, base - h * 1.4)]), _c(Color("#4E5258"), 0.42))
			_:
				draw_rect(Rect2(sx, base - h, w, h), col)
				draw_colored_polygon(PackedVector2Array([Vector2(sx, base - h), Vector2(sx + w, base - h * 1.08), Vector2(sx + w, base - h)]), col.darkened(0.2))
		if _nuit > 0.3 and int(o.x) % 3 == 0:
			draw_rect(Rect2(sx + w * 0.35, base - h * 0.6, maxf(2.0, w * 0.12), maxf(2.0, w * 0.12)), _lampe(0.8))


func _fumee(p: Vector2, s: float, graine: float) -> void:
	for i in 4:
		var u := fposmod(_t * 0.18 + i * 0.25 + graine * 0.13, 1.0)
		draw_circle(p + Vector2(u * 2.5 * s + sin(_t + i) * 0.4 * s, -u * 7.0 * s), (0.5 + u * 1.6) * s, Color(0.55, 0.52, 0.5, 0.35 * (1.0 - u)))


# Maisons rafistolées, à mi-distance (parallaxe 0,7)
func _maisons() -> void:
	var k := 0.7
	var base := _gy - 1.1 * _ppm
	for o in _milieu:
		var sx := _par(o.x, k)
		var w: float = o.w * _ppm * k
		if not _dans_murs(sx + w * 0.5):
			continue
		var h: float = o.h * _ppm * k
		var col := _c(o.c, 0.18)
		match o.t:
			"bus":
				var r := Rect2(sx, base - h * 0.55, w, h * 0.55)
				draw_rect(r, _c(Color("#7C6A3A"), 0.18))
				draw_rect(Rect2(sx, base - h * 0.55, w, h * 0.08), col.darkened(0.2))
				for i in 5:
					draw_rect(Rect2(sx + w * (0.06 + 0.18 * i), base - h * 0.45, w * 0.13, h * 0.16), _lampe() if (i + int(o.x)) % 2 == 0 else _c(Color("#2A2A28")))
				draw_rect(Rect2(sx + w * 0.1, base - h * 0.08, w * 0.8, h * 0.08), _c(Color("#3A332C")))
			"wagon":
				draw_rect(Rect2(sx, base - h * 0.65, w, h * 0.55), col)
				draw_colored_polygon(PackedVector2Array([Vector2(sx - 2, base - h * 0.65), Vector2(sx + w * 0.5, base - h * 0.75), Vector2(sx + w + 2, base - h * 0.65)]), col.darkened(0.25))
				draw_rect(Rect2(sx + w * 0.42, base - h * 0.55, w * 0.16, h * 0.42), _c(Color("#2E2822")))
				for wx in [0.15, 0.85]:
					draw_circle(Vector2(sx + w * wx, base - h * 0.06), h * 0.07, _c(Color("#26221E")))
			"pile":
				for i in 3:
					var y := base - h * (0.3 * i)
					var dx := w * 0.06 * (i % 2)
					draw_rect(Rect2(sx + dx, y - h * 0.28, w * 0.8, h * 0.26), _c(ROUILLE[(i + o.f) % ROUILLE.size()], 0.18))
					draw_rect(Rect2(sx + dx + w * 0.15, y - h * 0.24, w * 0.18, h * 0.12), _c(Color("#2A2E30")))
			"cabane":
				draw_rect(Rect2(sx, base - h * 0.75, w, h * 0.75), _c(Color("#7A6448"), 0.18))
				draw_colored_polygon(PackedVector2Array([Vector2(sx - 3, base - h * 0.75), Vector2(sx + w * 0.5, base - h), Vector2(sx + w + 3, base - h * 0.75)]), col.darkened(0.3))
				draw_rect(Rect2(sx + w * 0.6, base - h * 0.55, w * 0.22, h * 0.2), _lampe())
			_:
				draw_rect(Rect2(sx, base - h, w, h), col)
				var nb := int(w / maxf(4.0, 0.3 * _ppm * k))
				for i in nb:
					draw_line(Vector2(sx + i * w / nb, base - h), Vector2(sx + i * w / nb, base), col.darkened(0.18), 1.0)
				draw_colored_polygon(PackedVector2Array([Vector2(sx - 3, base - h), Vector2(sx + w + 3, base - h * 1.12), Vector2(sx + w + 3, base - h * 0.98), Vector2(sx - 3, base - h * 0.9)]), col.darkened(0.3))
				draw_rect(Rect2(sx + w * 0.2, base - h * 0.6, w * 0.2, h * 0.2), _lampe() if o.f != 0 else _c(Color("#2A2622")))
				draw_rect(Rect2(sx + w * 0.6, base - h * 0.45, w * 0.18, h * 0.45), _c(Color("#33291F")))
	# Guirlandes de lampes entre les maisons
	var y0 := base - 3.2 * _ppm * k
	var x := _x0 + 4.0
	while x < _x1 - 8.0:
		var a := Vector2(_par(x, k), y0)
		var b := Vector2(_par(x + 9.0, k), y0)
		if _dans_murs(a.x) and _dans_murs(b.x):
			var prev := a
			for i in range(1, 9):
				var u := i / 8.0
				var q := a.lerp(b, u) + Vector2(0, sin(u * PI) * 0.6 * _ppm * k)
				draw_line(prev, q, _c(Color("#2A2622")), 1.0)
				draw_circle(q, maxf(1.5, 0.12 * _ppm * k), _lampe(1.2))
				prev = q
		x += 11.0


# Habitants : rang 0 = au loin, entre les maisons ; rang 1 = au bord de la route
func _habitants(rang: int) -> void:
	var k := 0.7 if rang == 0 else 1.0
	var base := (_gy - 1.1 * _ppm) if rang == 0 else (_gy - 0.55 * _ppm)
	var s := _ppm * (0.62 if rang == 0 else 0.86)
	for g in _gens:
		if g.rang != rang:
			continue
		var xm: float = g.x + g.amp * sin(_t * g.vit + g.ph)
		var sx := _par(xm, k) if rang == 0 else _ex(xm)
		if sx < -40.0 or sx > size.x + 40.0 or not _dans_murs(sx, 6.0):
			continue
		var marche: bool = g.amp > 0.0
		var dir := cos(_t * g.vit + g.ph)
		if rang == 1:
			Silhouette.dessiner(self, Vector2(sx, base), s * g.h, "survivant", {"phase": _t * 6.0 + g.ph if marche else 0.0, "miroir": dir < 0.0, "peau": g.peau, "assis": g.assis})
		else:
			_bonhomme(Vector2(sx, base), s * g.h, _c(g.c, 0.15), _t * 5.0 + g.ph if marche else 0.0, dir < 0.0)


func _bonhomme(pied: Vector2, s: float, col: Color, ph: float, miroir: bool) -> void:
	var d := -1.0 if miroir else 1.0
	var hanche := pied + Vector2(0, -0.85 * s)
	for i in 2:
		var a := sin(ph + PI * i) * 0.4 if ph != 0.0 else 0.08 * (1 - 2 * i)
		draw_line(hanche, hanche + Vector2(sin(a) * 0.85 * s * d, 0.85 * s), col.darkened(0.35), maxf(1.0, 0.13 * s))
	draw_rect(Rect2(hanche + Vector2(-0.17 * s, -0.62 * s), Vector2(0.34 * s, 0.64 * s)), col)
	draw_circle(hanche + Vector2(0, -0.8 * s), 0.16 * s, _c(Color("#C9A27E")))


# Le long de la route : marché, atelier, garage, mairie, café, dortoirs
func _route() -> void:
	_marche()
	_atelier()
	_garage()
	_mairie()
	_cafe()
	_dortoir()


func _b(id: String) -> Array:
	return [_x0 + float(BATS[id][0]), _x0 + float(BATS[id][1])]


func _visible(a: float, b: float) -> bool:
	return _ex(b) > -20.0 and _ex(a) < size.x + 20.0


func _toles(r: Rect2, col: Color) -> void:
	draw_rect(r, col)
	var n := int(r.size.x / maxf(5.0, 0.35 * _ppm))
	for i in range(1, n):
		var x := r.position.x + i * r.size.x / n
		draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), col.darkened(0.22), maxf(1.0, _ppm * 0.04))
	draw_rect(Rect2(r.position.x, r.position.y + r.size.y * 0.45, r.size.x * 0.3, r.size.y * 0.25), col.lightened(0.08))


func _enseigne(x: float, h: float, w: float, txt: String, fond: Color, encre: Color) -> void:
	var r := Rect2(_p(x, h).x, _p(x, h).y, w * _ppm, 1.1 * _ppm)
	draw_rect(r, _c(fond))
	draw_rect(r, _c(Color("#1E1A16")), false, maxf(1.0, _ppm * 0.05))
	var fs := int(clampf(_ppm * 0.75, 10.0, 48.0))
	draw_string(_f, Vector2(r.position.x, r.position.y + r.size.y * 0.78), txt, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, _c(encre))


func _marche() -> void:
	var b := _b("marche")
	if not _visible(b[0], b[1]):
		return
	var couleurs := [Color("#9C3B2E"), Color("#C9B48A"), Color("#3E5E6E"), Color("#A86A2C")]
	for i in 4:
		var x: float = b[0] + i * 4.8
		for px in [x, x + 4.0]:
			draw_line(_p(px, 0.0), _p(px, 3.0), _c(Color("#3E3226")), maxf(2.0, _ppm * 0.12))
		var c1: Color = couleurs[i]
		for j in 5:   # bâche rayée
			draw_colored_polygon(PackedVector2Array([_p(x - 0.3 + j * 0.92, 3.4), _p(x + 0.62 + j * 0.92, 3.4), _p(x + 0.62 + j * 0.92, 2.8), _p(x - 0.3 + j * 0.92, 2.9)]), _c(c1 if j % 2 == 0 else Color("#E4DCC8")))
		draw_rect(Rect2(_p(x + 0.2, 1.0), Vector2(3.6 * _ppm, 1.0 * _ppm)), _c(Color("#6B5236")))
		for j in 4:   # caisses, bidons, cageots
			var cc: Color = [Color("#8A6A3C"), Color("#4E5A4C"), Color("#9A8A5A"), Color("#6E3A2A")][(i + j) % 4]
			draw_rect(Rect2(_p(x + 0.4 + j * 0.85, 1.45), Vector2(0.65 * _ppm, 0.45 * _ppm)), _c(cc))
	_enseigne(b[0] + 5.0, 4.9, 9.0, "MARCHÉ", Color("#D8CBA8"), Color("#3A2A1E"))


func _atelier() -> void:
	var b := _b("atelier")
	if not _visible(b[0], b[1]):
		return
	var w: float = b[1] - b[0]
	var pts := PackedVector2Array()
	for i in 17:   # toit en arc (hangar)
		var u := i / 16.0
		pts.append(_p(b[0] + u * w, 6.0 + sin(u * PI) * 3.2))
	pts.append(_p(b[1], 0.0))
	pts.append(_p(b[0], 0.0))
	draw_colored_polygon(pts, _c(Color("#6E6A62")))
	for i in range(1, 12):
		var xx: float = b[0] + i * w / 12.0
		var hh := 6.0 + sin(i / 12.0 * PI) * 3.2
		draw_line(_p(xx, 0.0), _p(xx, hh), _c(Color("#5A5650")), maxf(1.0, _ppm * 0.05))
	var porte := Rect2(_p(b[0] + 3.0, 5.2), Vector2((w - 6.0) * _ppm, 5.2 * _ppm))
	draw_rect(porte, _c(Color("#1C1A18")))
	# un châssis sur cales, des étincelles de soudure
	draw_rect(Rect2(_p(b[0] + 5.0, 1.4), Vector2(8.0 * _ppm, 0.45 * _ppm)), _c(Color("#4A3A2C")))
	for wx in [6.2, 11.5]:
		draw_circle(_p(b[0] + wx, 0.55), 0.55 * _ppm, _c(Color("#2A2522")))
	if fposmod(_t, 2.3) < 1.2:
		var sp := _p(b[0] + 9.0, 1.9)
		draw_circle(sp, _ppm * 0.5, Color(1.0, 0.95, 0.7, 0.35))
		for i in 6:
			var a := _t * 9.0 + i
			draw_line(sp, sp + Vector2(cos(a), -absf(sin(a))) * _ppm * 0.7, Color(1.0, 0.8, 0.3), 1.5)
	_enseigne(b[0] + 6.0, 7.7, 8.0, "ATELIER", Color("#C9B98F"), Color("#2C241C"))


func _garage() -> void:
	var b := _b("garage")
	if not _visible(b[0], b[1]):
		return
	var w: float = b[1] - b[0]
	_toles(Rect2(_p(b[0], 6.0), Vector2(w * _ppm, 6.0 * _ppm)), _c(Color("#7A4E34")))
	draw_colored_polygon(PackedVector2Array([_p(b[0] - 0.4, 6.0), _p(b[1] + 0.4, 6.6), _p(b[1] + 0.4, 6.2), _p(b[0] - 0.4, 5.7)]), _c(Color("#4A3428")))
	draw_rect(Rect2(_p(b[0] + 1.5, 4.2), Vector2(7.0 * _ppm, 4.2 * _ppm)), _c(Color("#201C18")))
	draw_rect(Rect2(_p(b[0] + 2.0, 1.6), Vector2(4.8 * _ppm, 1.2 * _ppm)), _c(Color("#5C6A5E")))   # voiture sur cric
	draw_rect(Rect2(_p(b[0] + 3.3, 0.4), Vector2(0.3 * _ppm, 0.6 * _ppm)), _c(Color("#8A8A80")))
	for i in 4:   # pneus empilés
		draw_circle(_p(b[1] - 2.2, 0.35 + i * 0.6), 0.55 * _ppm, _c(Color("#1E1C1A")))
		draw_circle(_p(b[1] - 2.2, 0.35 + i * 0.6), 0.25 * _ppm, _c(Color("#3A3632")))
	for i in 2:
		draw_rect(Rect2(_p(b[1] - 0.9 - i * 0.9, 1.0), Vector2(0.7 * _ppm, 1.0 * _ppm)), _c(Color("#2E4A3A") if i == 0 else Color("#8A3A2A")))
	_enseigne(b[0] + 0.8, 7.6, w - 1.6, "GARAGE · MÉCANIQUE", Color("#E3D6B0"), Color("#7A1E18"))


func _mairie() -> void:
	var b := _b("mairie")
	if not _visible(b[0] - 2.0, b[1] + 2.0):
		return
	var x0: float = b[0] + 2.0
	var x1: float = b[1] - 2.0
	var w := x1 - x0
	var pierre := _c(Color("#C9B797"))
	# annexe rafistolée et sacs de sable
	_toles(Rect2(_p(b[0], 5.0), Vector2(2.2 * _ppm, 5.0 * _ppm)), _c(Color("#6A6E72")))
	for i in 5:
		draw_rect(Rect2(_p(x1 + 0.1 + (i % 3) * 0.6, 0.45 + 0.42 * (i / 3)), Vector2(0.62 * _ppm, 0.42 * _ppm)), _c(Color("#A08A62")))
	# corps : deux étages, toit d'ardoise, fronton central avec horloge
	draw_rect(Rect2(_p(x0, 9.0), Vector2(w * _ppm, 9.0 * _ppm)), pierre)
	draw_rect(Rect2(_p(x0, 4.6), Vector2(w * _ppm, 0.3 * _ppm)), pierre.darkened(0.12))
	draw_colored_polygon(PackedVector2Array([_p(x0 - 0.5, 9.0), _p(x0 + 0.8, 10.6), _p(x1 - 0.8, 10.6), _p(x1 + 0.5, 9.0)]), _c(Color("#4A5058")))
	var cx := (x0 + x1) * 0.5
	draw_colored_polygon(PackedVector2Array([_p(cx - 3.0, 9.0), _p(cx, 11.6), _p(cx + 3.0, 9.0)]), pierre.lightened(0.05))
	draw_circle(_p(cx, 9.75), 0.62 * _ppm, _c(Color("#EDE6D2")))
	draw_arc(_p(cx, 9.75), 0.62 * _ppm, 0.0, TAU, 24, _c(Color("#2A2520")), maxf(1.0, _ppm * 0.06))
	draw_line(_p(cx, 9.75), _p(cx, 10.2), _c(Color("#2A2520")), maxf(1.0, _ppm * 0.06))
	draw_line(_p(cx, 9.75), _p(cx + 0.3, 9.75), _c(Color("#2A2520")), maxf(1.0, _ppm * 0.06))
	var fs := int(clampf(_ppm * 0.9, 10.0, 56.0))
	draw_string(_f, _p(x0, 7.85), "MAIRIE", HORIZONTAL_ALIGNMENT_CENTER, w * _ppm, fs, _c(Color("#3A2E22")))
	draw_string(_f, _p(x0, 5.15), "LIBERTÉ · ÉGALITÉ · FRATERNITÉ", HORIZONTAL_ALIGNMENT_CENTER, w * _ppm, int(fs * 0.38), _c(Color("#5A4A3A")))
	# fenêtres à volets (deux étages), porte en arc au centre, marches
	for et in 2:
		for i in 4:
			var fx := x0 + 1.2 + i * (w - 2.4) / 3.0 - 0.6
			if et == 0 and i in [1, 2]:
				continue
			var fy := 3.6 if et == 0 else 7.2
			draw_rect(Rect2(_p(fx, fy), Vector2(1.2 * _ppm, 2.0 * _ppm)), _lampe() if (i + et) % 2 == 0 and _nuit > 0.2 else _c(Color("#2E3238")))
			draw_rect(Rect2(_p(fx - 0.45, fy), Vector2(0.4 * _ppm, 2.0 * _ppm)), _c(Color("#5E7A86")))
			draw_rect(Rect2(_p(fx + 1.25, fy), Vector2(0.4 * _ppm, 2.0 * _ppm)), _c(Color("#5E7A86")))
	draw_rect(Rect2(_p(cx - 1.2, 3.2), Vector2(2.4 * _ppm, 3.2 * _ppm)), _c(Color("#3A2A1E")))
	draw_circle(_p(cx, 3.2), 1.2 * _ppm, _c(Color("#3A2A1E")))
	for i in 3:
		draw_rect(Rect2(_p(cx - 2.0 - 0.3 * i, 0.25 * (3 - i)), Vector2((4.0 + 0.6 * i) * _ppm, 0.25 * _ppm)), pierre.darkened(0.08 + 0.04 * i))
	# mât et drapeau délavé
	var mat := _p(cx, 11.6)
	draw_line(mat, _p(cx, 15.0), _c(Color("#2A2622")), maxf(1.5, _ppm * 0.08))
	var cols := [Color("#3F4F7A"), Color("#E6E0D2"), Color("#9A3A34")]
	for i in 3:
		var pts := PackedVector2Array()
		for j in 2:
			var u0 := (i + j) / 3.0
			pts.append(_p(cx + u0 * 2.4, 14.9 + 0.15 * sin(_t * 3.0 + u0 * 4.0)))
		for j in 2:
			var u1 := (i + 1 - j) / 3.0
			pts.append(_p(cx + u1 * 2.4, 13.6 + 0.15 * sin(_t * 3.0 + u1 * 4.0)))
		draw_colored_polygon(pts, _c(cols[i].lerp(Color("#A89A80"), 0.3)))


func _cafe() -> void:
	var b := _b("cafe")
	if not _visible(b[0], b[1]):
		return
	var w: float = b[1] - b[0]
	draw_rect(Rect2(_p(b[0], 7.0), Vector2(w * _ppm, 7.0 * _ppm)), _c(Color("#A88C68")))
	draw_colored_polygon(PackedVector2Array([_p(b[0] - 0.4, 7.0), _p(b[0] + w * 0.5, 8.6), _p(b[1] + 0.4, 7.0)]), _c(Color("#6A3A2A")))
	for i in 3:
		draw_rect(Rect2(_p(b[0] + 1.2 + i * 4.6, 6.0), Vector2(1.4 * _ppm, 1.6 * _ppm)), _lampe() if i != 1 else _c(Color("#2E2A26")))
	draw_rect(Rect2(_p(b[0] + 0.5, 3.4), Vector2((w - 1.0) * _ppm, 3.1 * _ppm)), _lampe(0.7) if _nuit > 0.2 else _c(Color("#3A3028")))
	for j in 7:   # store
		draw_colored_polygon(PackedVector2Array([_p(b[0] + j * w / 7.0, 3.9), _p(b[0] + (j + 1) * w / 7.0, 3.9), _p(b[0] + (j + 1) * w / 7.0 + 0.3, 3.3), _p(b[0] + j * w / 7.0 + 0.3, 3.3)]), _c(Color("#7A2A22") if j % 2 == 0 else Color("#D8CDB2")))
	for i in 3:   # tables de terrasse
		var tx: float = b[0] + 2.0 + i * 4.5
		draw_line(_p(tx, 0.0), _p(tx, 0.9), _c(Color("#2A2622")), maxf(1.0, _ppm * 0.06))
		draw_line(_p(tx - 0.5, 0.9), _p(tx + 0.5, 0.9), _c(Color("#2A2622")), maxf(2.0, _ppm * 0.1))
	_enseigne(b[0] + 3.0, 5.4, w - 6.0, "CAFÉ", Color("#2A2622"), Color("#E8C57A"))


func _dortoir() -> void:
	var b := _b("dortoir")
	if not _visible(b[0], b[1]):
		return
	for i in 3:   # wagons et caisses empilés : dortoirs
		var x: float = b[0] + i * 6.0
		var c: Color = ROUILLE[(i + 2) % ROUILLE.size()]
		_toles(Rect2(_p(x, 3.0), Vector2(5.6 * _ppm, 3.0 * _ppm)), _c(c))
		_toles(Rect2(_p(x + 0.6, 6.0), Vector2(4.6 * _ppm, 3.0 * _ppm)), _c(c.lightened(0.1)))
		draw_rect(Rect2(_p(x + 1.0, 2.2), Vector2(1.0 * _ppm, 1.0 * _ppm)), _lampe() if i != 1 else _c(Color("#2A2622")))
		draw_rect(Rect2(_p(x + 2.4, 5.2), Vector2(1.0 * _ppm, 1.0 * _ppm)), _lampe() if i == 1 else _c(Color("#2A2622")))
	var a := _p(b[0] + 1.0, 4.2)   # linge qui sèche
	var z := _p(b[1] - 1.0, 4.2)
	draw_line(a, z, _c(Color("#2A2622")), 1.0)
	for i in 8:
		var q := a.lerp(z, (i + 0.5) / 8.0)
		draw_rect(Rect2(q, Vector2(0.7 * _ppm, (0.8 + 0.3 * (i % 2)) * _ppm)), _c([Color("#C9C2B0"), Color("#7A8A9A"), Color("#A85A4A")][i % 3]))


# Maire, mécanicien, chef d'atelier ; bulles des habitants
func _personnages(V: Dictionary) -> void:
	var dedans: bool = String(V.phase) in ["entree", "dedans", "depart"]
	var roles := [["mairie", 90.0, "Le maire"], ["garage", 56.0, "Mécanicien"], ["atelier", 39.0, "Atelier"]]
	for rr in roles:
		var x: float = _x0 + float(rr[1])
		if not _visible(x - 2.0, x + 2.0):
			continue
		var pied := Vector2(_ex(x), _gy - 0.5 * _ppm)
		var opts := {"phase": 0.0, "peau": 2 if rr[0] == "mairie" else 4, "miroir": true}
		if rr[0] == "garage":
			opts["travaille"] = _t * 7.0
		Silhouette.dessiner(self, pied, _ppm * 0.95, "survivant", opts)
		if rr[0] == "mairie":   # écharpe tricolore
			draw_line(pied + Vector2(-0.18, -1.45) * _ppm, pied + Vector2(0.2, -0.95) * _ppm, _c(Color("#3F4F7A")), maxf(2.0, _ppm * 0.1))
			draw_line(pied + Vector2(-0.12, -1.48) * _ppm, pied + Vector2(0.26, -0.98) * _ppm, _c(Color("#9A3A34")), maxf(1.5, _ppm * 0.06))
		var hb := pied + Vector2(0, -2.6 * _ppm - (4.0 * sin(_t * 3.0) if dedans else 0.0))
		_bulle(hb, String(rr[2]), dedans)
	if not dedans:
		return
	# Une bulle d'habitant de temps en temps
	var phrases: Array = CombatModele.VD().phrases
	var cycle := int(_t / 4.0)
	if fposmod(_t, 4.0) > 3.2:
		return
	var proches := []
	for g in _gens:
		if g.rang == 1:
			var sx := _ex(float(g.x) + float(g.amp) * sin(_t * float(g.vit) + float(g.ph)))
			if sx > 120.0 and sx < size.x - 400.0:
				proches.append(sx)
	if proches.is_empty():
		return
	var px: float = proches[(cycle * 7) % proches.size()]
	_bulle(Vector2(px, _gy - 2.2 * _ppm), String(phrases[(cycle * 5 + _graine) % phrases.size()]), false)


func _bulle(bas: Vector2, txt: String, accent: bool) -> void:
	var fs := int(clampf(_ppm * 0.48, 14.0, 26.0))
	var tz := _f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var r := Rect2(bas.x - tz.x * 0.5 - 12.0, bas.y - tz.y - 18.0, tz.x + 24.0, tz.y + 12.0)
	draw_colored_polygon(PackedVector2Array([Vector2(bas.x - 7, r.end.y - 1), Vector2(bas.x + 7, r.end.y - 1), Vector2(bas.x, bas.y)]), Color("#2A2520"))
	_style_bulle.bg_color = Color("#F4D58A") if accent else Color("#F4EEDF")
	draw_style_box(_style_bulle, r)
	draw_string(_f, Vector2(r.position.x + 12.0, r.end.y - 9.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("#1E1A16"))


# Porte de l'enceinte : tour de tôles rivetées, passage de 6,5 m, porte qui monte, chemin de ronde et gardes armés
func _porte(xg: float, ouverture: float, titre: String, cote: int) -> void:
	var a := xg - 1.0
	var b := xg + 4.0
	if not _visible(a - 4.0, b + 4.0):
		return
	var w := b - a
	var metal := _c(Color("#6E5440"))
	# murailles qui partent de la tour (vues de biais, plus basses)
	var dx := -1.0 if cote == 0 else 1.0
	var m0 := a if cote == 0 else b
	draw_colored_polygon(PackedVector2Array([_p(m0, 0.0), _p(m0, 9.0), _p(m0 + dx * 6.0, 7.2), _p(m0 + dx * 6.0, 0.0)]), _c(Color("#5A4636")))
	for i in 6:
		draw_line(_p(m0 + dx * i, 0.0), _p(m0 + dx * i, 9.0 - 0.3 * i), _c(Color("#4A382A")), maxf(1.0, _ppm * 0.05))
	# passage : fond sombre
	draw_rect(Rect2(_p(a, PORTE_H), Vector2(w * _ppm, PORTE_H * _ppm)), _c(Color("#1A1612")))
	# porte (glisse vers le haut)
	var bas := ouverture * PORTE_H
	if bas < PORTE_H - 0.05:
		var r := Rect2(_p(a + 0.3, PORTE_H), Vector2((w - 0.6) * _ppm, (PORTE_H - bas) * _ppm))
		draw_rect(r, _c(Color("#7A5C44")))
		var nb := 4
		for i in range(1, nb):
			var yy := r.position.y + i * r.size.y / nb
			draw_line(Vector2(r.position.x, yy), Vector2(r.end.x, yy), _c(Color("#4E3A2A")), maxf(1.0, _ppm * 0.07))
		draw_line(r.position, r.end, _c(Color("#4E3A2A")), maxf(2.0, _ppm * 0.14))
		draw_line(Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.position.y), _c(Color("#4E3A2A")), maxf(2.0, _ppm * 0.14))
		for i in 6:
			for j in 3:
				draw_circle(Vector2(r.position.x + (i + 0.5) * r.size.x / 6.0, r.position.y + (j + 0.5) * r.size.y / 3.0), maxf(1.0, _ppm * 0.06), _c(Color("#A08060")))
	# montants du passage
	draw_rect(Rect2(_p(a, PORTE_H), Vector2(0.35 * _ppm, PORTE_H * _ppm)), metal.darkened(0.15))
	draw_rect(Rect2(_p(b - 0.35, PORTE_H), Vector2(0.35 * _ppm, PORTE_H * _ppm)), metal.darkened(0.15))
	# corps de la tour au-dessus du passage
	var corps := Rect2(_p(a - 0.3, TOUR_H), Vector2((w + 0.6) * _ppm, (TOUR_H - PORTE_H) * _ppm))
	draw_rect(corps, metal)
	for i in 5:
		for j in 3:
			var pr := Rect2(corps.position + Vector2(i * corps.size.x / 5.0, j * corps.size.y / 3.0), Vector2(corps.size.x / 5.0, corps.size.y / 3.0))
			draw_rect(pr, metal.darkened(0.08 * ((i + j) % 3)), false, maxf(1.0, _ppm * 0.04))
	# panneau peint au-dessus de la porte
	var fs := int(clampf(_ppm * 0.62, 10.0, 40.0))
	var pan := Rect2(_p(a - 1.2, 8.9), Vector2((w + 2.4) * _ppm, 1.3 * _ppm))
	draw_rect(pan, _c(Color("#D9CCA6")))
	draw_rect(pan, _c(Color("#2A2018")), false, maxf(1.0, _ppm * 0.06))
	draw_string(_f, Vector2(pan.position.x, pan.position.y + pan.size.y * 0.75), titre, HORIZONTAL_ALIGNMENT_CENTER, pan.size.x, fs, _c(Color("#3A2418")))
	# chemin de ronde : créneaux de tôle, guérite, drapeau de bande
	for i in 7:
		if i % 2 == 0:
			draw_rect(Rect2(_p(a - 0.3 + i * (w + 0.6) / 7.0, TOUR_H + 1.1), Vector2((w + 0.6) / 7.0 * _ppm, 1.1 * _ppm)), metal.darkened(0.1))
	draw_rect(Rect2(_p(a - 0.3, TOUR_H + 0.35), Vector2((w + 0.6) * _ppm, 0.35 * _ppm)), metal.darkened(0.2))
	var gx := b - 1.6 if cote == 0 else a + 0.2
	draw_rect(Rect2(_p(gx, TOUR_H + 2.6), Vector2(1.4 * _ppm, 2.6 * _ppm)), _c(Color("#5A4A3A")))
	draw_colored_polygon(PackedVector2Array([_p(gx - 0.3, TOUR_H + 2.6), _p(gx + 0.7, TOUR_H + 3.3), _p(gx + 1.7, TOUR_H + 2.6)]), _c(Color("#3A2E24")))
	draw_rect(Rect2(_p(gx + 0.35, TOUR_H + 1.9), Vector2(0.7 * _ppm, 0.5 * _ppm)), _lampe())
	var mx := a + 0.4 if cote == 0 else b - 0.4
	draw_line(_p(mx, TOUR_H), _p(mx, TOUR_H + 4.2), _c(Color("#2A2622")), maxf(1.5, _ppm * 0.07))
	var drap := PackedVector2Array([_p(mx, TOUR_H + 4.1), _p(mx + 1.6, TOUR_H + 3.9 + 0.2 * sin(_t * 4.0)), _p(mx + 1.5, TOUR_H + 3.2 + 0.2 * sin(_t * 4.0 + 1.0)), _p(mx, TOUR_H + 3.3)])
	draw_colored_polygon(drap, _c(Color("#8A3A2A")))
	# projecteur la nuit
	if _nuit > 0.35:
		var src := _p(gx + 0.7, TOUR_H + 2.1)
		var ang := (-0.35 if cote == 0 else -2.8) + 0.35 * sin(_t * 0.5 + cote)
		var l := 30.0 * _ppm
		draw_colored_polygon(PackedVector2Array([src, src + Vector2(cos(ang - 0.08), sin(ang - 0.08) + 0.4) * l, src + Vector2(cos(ang + 0.08), sin(ang + 0.08) + 0.4) * l]), Color(1.0, 0.95, 0.75, 0.08 * _nuit))
	# gardes armés sur le chemin de ronde (aucune ville ne tire pour l'instant)
	for i in 3:
		var px: float = a + 0.3 + i * 1.6
		if absf(px - gx - 0.7) < 0.8:
			continue
		var vise := fposmod(_t * 0.4 + i * 1.7 + cote, 6.0) < 1.6
		Silhouette.dessiner(self, _p(px, TOUR_H + 0.7), _ppm, "tireur", {"phase": 0.0, "miroir": (cote == 1) != (i == 2), "peau": i + 3 * cote, "bras": "vise" if vise else ""})
