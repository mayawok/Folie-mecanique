# Décor propre à chaque région (DEV-008, DEC-264) : plans lointains, ligne plantée sur les dunes proches, objets du bord de
# route et particules, dessinés par le code sur le calque du décor (Terrain). Les choix par région sont dans
# data/decors_regions.json ; ce fichier ne contient que les dessins. Tout est placé par un pseudo-hasard stable (Terrain.alea) :
# le même endroit montre toujours le même décor.
class_name DecorRegion
extends RefCounted

static var _data := {}
# Ce que ce fichier sait dessiner (le test vérifie que decors_regions.json n'en demande pas d'autres)
const LOINTAINS := ["mer", "phares", "digues", "bocage", "grues", "terrils", "centrale", "tour_fer", "ville", "foret_morte", "front",
	"silos", "pont_effondre", "pins_morts", "raffinerie", "puys", "viaduc", "barrage", "usines", "etang", "montagnes", "fort"]
const LIGNES := ["", "poteaux", "aucune", "pylones", "barbeles", "pins", "sapins", "reverberes", "pieux"]
const OBJETS := ["calvaire", "menhir", "bateau", "pieu", "haie_brulee", "wagonnet", "terril_petit", "pylone", "reverbere", "gravats",
	"derrick", "baril", "herisson", "barbele", "cratere", "arbre_brise", "bunker_petit", "silo_petit", "pin_mort", "basalte", "signal",
	"buisson_sec", "cypres", "sel", "sapin", "rocher_neige", "borne", "obj_charrette"]
const OBJETS_TERRAIN := ["poteau", "cactus", "arbre", "rocher", "herbe", "roseau", "carcasse", "epave", "objet", "cloture", "muret", "bat", "ruine", "clocher", "chateau_eau"]
const PARTICULES := ["", "neige", "cendres", "embruns"]


static func donnees() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/decors_regions.json"))
	return _data


static func region(id: String) -> Dictionary:
	return donnees().get(id, {}) if id != "" else {}


# Cellules visibles d'un plan qui défile à la vitesse vit (parallaxe) : [[indice, x écran du début de cellule], …]
static func _cellules(t: Terrain, w: float, vit: float, cel: float) -> Array:
	var dec := t.camera_x * t.ppm * vit
	var res := []
	var k := floorf((dec - cel) / cel)
	while k * cel - dec < w + cel:
		res.append([k, k * cel - dec])
		k += 1.0
	return res


static func _poly(t: Terrain, pts: Array, c: Color) -> void:
	t.draw_colored_polygon(PackedVector2Array(pts), c)


# --- Plans lointains -----------------------------------------------------------------------------------------------------
static func lointain(t: Terrain, type: String, w: float, hgt: float, vit: float, base: float, col: Color, hor: Color) -> void:
	match type:
		"mer": _mer(t, w, base, col, hor)
		"phares": _phares(t, w, vit, base, col)
		"digues": _digues(t, w, vit, base, col, hor)
		"bocage": _bocage(t, w, vit, base, col)
		"grues": _grues(t, w, vit, base, col)
		"terrils": _terrils(t, w, hgt, vit, base, col)
		"centrale": _centrale(t, w, vit, base, col)
		"tour_fer": _tour_fer(t, w, vit, base, col)
		"ville": _ville(t, w, hgt, vit, base, col)
		"foret_morte": _foret_morte(t, w, vit, base, col)
		"front": _front(t, w, hgt, vit, base, col)
		"silos": _silos(t, w, vit, base, col)
		"pont_effondre": _pont_effondre(t, w, vit, base, col)
		"pins_morts": _pins(t, w, vit, base, col, 1.0)
		"raffinerie": _raffinerie(t, w, vit, base, col)
		"puys": _puys(t, w, hgt, vit, base, col)
		"viaduc": _viaduc(t, w, vit, base, col)
		"barrage": _barrage(t, w, hgt, vit, base, col, hor)
		"usines": _usines(t, w, vit, base, col)
		"etang": _etang(t, w, base, col, hor)
		"montagnes": _montagnes(t, w, hgt, vit, base, col)
		"fort": _fort(t, w, vit, base, col)


static func _mer(t: Terrain, w: float, base: float, col: Color, hor: Color) -> void:
	var mer := hor.lerp(Color("#5F7E8C"), 0.45).lerp(col, 0.2)
	t.draw_rect(Rect2(0, base - 10.0, w, 22.0), mer)
	var tps := Time.get_ticks_msec() * 0.001
	var reflet := Color(hor.lightened(0.3), 0.45 * (1.0 - t.nuit))
	for i in 18:
		var x := fposmod(i * 97.0 + 40.0 * sin(tps * 0.4 + i) - t.camera_x * t.ppm * 0.01, w + 60.0) - 30.0
		t.draw_line(Vector2(x, base - 6.0 + (i % 4) * 4.0), Vector2(x + 18.0 + (i % 3) * 9.0, base - 6.0 + (i % 4) * 4.0), reflet, 1.5)


static func _phares(t: Terrain, w: float, vit: float, base: float, col: Color) -> void:
	for c in _cellules(t, w, vit, 520.0):
		var k: float = c[0]
		if Terrain.alea(k, 61.0) > 0.55:
			continue
		var x: float = c[1] + 120.0 + 260.0 * Terrain.alea(k, 62.0)
		var h := 70.0 + 45.0 * Terrain.alea(k, 63.0)
		Disque.d(t, Vector2(x, base + 6.0), 30.0, col.darkened(0.08))   # îlot de granit
		_poly(t, [Vector2(x - 8.0, base - 2.0), Vector2(x + 8.0, base - 2.0), Vector2(x + 5.0, base - h), Vector2(x - 5.0, base - h)], col)
		t.draw_rect(Rect2(x - 7.0, base - h - 12.0, 14.0, 12.0), col.darkened(0.12))   # lanterne éteinte
		_poly(t, [Vector2(x - 8.0, base - h - 12.0), Vector2(x + 8.0, base - h - 12.0), Vector2(x, base - h - 22.0)], col.darkened(0.18))
		t.draw_line(Vector2(x - 10.0, base - h), Vector2(x + 10.0, base - h), col.darkened(0.2), 2.0)


static func _digues(t: Terrain, w: float, vit: float, base: float, col: Color, hor: Color) -> void:
	_poly(t, [Vector2(0, base + 4.0), Vector2(w, base + 4.0), Vector2(w, base - 6.0), Vector2(0, base - 6.0)], col)
	for c in _cellules(t, w, vit, 60.0):
		var x: float = c[1]
		t.draw_line(Vector2(x, base - 6.0), Vector2(x, base - 14.0 - 4.0 * Terrain.alea(c[0], 64.0)), col.darkened(0.2), 2.0)
		if Terrain.alea(c[0], 65.0) < 0.12:   # écluse
			t.draw_rect(Rect2(x - 10.0, base - 26.0, 20.0, 20.0), col.darkened(0.15))
			t.draw_rect(Rect2(x - 6.0, base - 22.0, 12.0, 14.0), Color(hor, 0.6))


static func _bocage(t: Terrain, w: float, vit: float, base: float, col: Color) -> void:
	for c in _cellules(t, w, vit, 46.0):
		var k: float = c[0]
		var x: float = c[1]
		if Terrain.alea(k, 66.0) < 0.3:   # tronc brûlé, sans feuilles
			t.draw_line(Vector2(x, base), Vector2(x + 2.0, base - 26.0), col.darkened(0.25), 2.0)
			t.draw_line(Vector2(x + 1.0, base - 18.0), Vector2(x + 8.0, base - 25.0), col.darkened(0.25), 1.5)
		else:
			for j in 3:
				Disque.d(t, Vector2(x + j * 9.0, base - 8.0 - 6.0 * Terrain.alea(k + j, 67.0)), 10.0 + 4.0 * Terrain.alea(k + j, 68.0), col)


static func _grues(t: Terrain, w: float, vit: float, base: float, col: Color) -> void:
	for c in _cellules(t, w, vit, 300.0):
		var k: float = c[0]
		if Terrain.alea(k, 69.0) > 0.6:
			continue
		var x: float = c[1] + 60.0 + 160.0 * Terrain.alea(k, 70.0)
		var h := 80.0 + 40.0 * Terrain.alea(k, 71.0)
		t.draw_line(Vector2(x - 12.0, base), Vector2(x - 6.0, base - h), col, 3.0)
		t.draw_line(Vector2(x + 12.0, base), Vector2(x + 6.0, base - h), col, 3.0)
		t.draw_line(Vector2(x - 40.0, base - h), Vector2(x + 70.0, base - h + 6.0), col, 3.0)   # flèche
		t.draw_line(Vector2(x, base - h - 18.0), Vector2(x + 70.0, base - h + 6.0), col, 1.5)
		t.draw_line(Vector2(x, base - h - 18.0), Vector2(x - 40.0, base - h), col, 1.5)
		t.draw_line(Vector2(x + 55.0, base - h + 5.0), Vector2(x + 55.0, base - h + 34.0), col.darkened(0.1), 1.0)
		if Terrain.alea(k, 72.0) < 0.5:   # cargo échoué
			_poly(t, [Vector2(x + 90.0, base), Vector2(x + 230.0, base), Vector2(x + 245.0, base - 26.0), Vector2(x + 80.0, base - 22.0)], col.darkened(0.06))
			t.draw_rect(Rect2(x + 180.0, base - 44.0, 30.0, 20.0), col.darkened(0.06))


static func _terrils(t: Terrain, w: float, hgt: float, vit: float, base: float, col: Color) -> void:
	for c in _cellules(t, w, vit, 260.0):
		var k: float = c[0]
		if Terrain.alea(k, 73.0) > 0.7:
			continue
		var x: float = c[1] + 130.0 * Terrain.alea(k, 74.0)
		var h := 90.0 + 70.0 * Terrain.alea(k, 75.0)
		var l := h * 1.7
		_poly(t, [Vector2(x - l, base + 2.0), Vector2(x - 6.0, base - h), Vector2(x + 6.0, base - h), Vector2(x + l, base + 2.0)], col.darkened(0.12))
		_poly(t, [Vector2(x - 6.0, base - h), Vector2(x + 6.0, base - h), Vector2(x + l, base + 2.0), Vector2(x + l * 0.3, base + 2.0)], col.darkened(0.2))


static func _centrale(t: Terrain, w: float, vit: float, base: float, col: Color) -> void:
	var tps := Time.get_ticks_msec() * 0.001
	for c in _cellules(t, w, vit, 700.0):
		var k: float = c[0]
		if Terrain.alea(k, 76.0) > 0.6:
			# chevalement de mine
			var xm: float = c[1] + 300.0
			t.draw_line(Vector2(xm - 14.0, base), Vector2(xm, base - 70.0), col, 3.0)
			t.draw_line(Vector2(xm + 14.0, base), Vector2(xm, base - 70.0), col, 3.0)
			t.draw_line(Vector2(xm - 24.0, base), Vector2(xm, base - 70.0), col, 2.0)
			Disque.d(t, Vector2(xm, base - 72.0), 9.0, col.darkened(0.1))
			continue
		var x: float = c[1] + 120.0 + 200.0 * Terrain.alea(k, 77.0)
		t.draw_rect(Rect2(x, base - 60.0, 200.0, 60.0), col)   # salle des machines
		for j in 3:   # cheminées
			t.draw_rect(Rect2(x + 30.0 + j * 50.0, base - 150.0, 12.0, 92.0), col.darkened(0.08))
			for f in 4:   # fumée
				var ph := fposmod(tps * 0.25 + f * 0.25 + j * 0.13, 1.0)
				Disque.d(t, Vector2(x + 36.0 + j * 50.0 + ph * 60.0, base - 155.0 - ph * 70.0), 8.0 + ph * 22.0, Color(col.lightened(0.2), 0.35 * (1.0 - ph)))
		for j in 2:   # tours de refroidissement
			var xt := x + 230.0 + j * 80.0
			_poly(t, [Vector2(xt - 34.0, base), Vector2(xt + 34.0, base), Vector2(xt + 22.0, base - 50.0), Vector2(xt + 26.0, base - 90.0),
				Vector2(xt - 26.0, base - 90.0), Vector2(xt - 22.0, base - 50.0)], col.darkened(0.05))
		if t.nuit > 0.2:   # fenêtres allumées et arcs électriques
			for j in 8:
				t.draw_rect(Rect2(x + 12.0 + j * 23.0, base - 40.0, 8.0, 10.0), Color(1.0, 0.8, 0.4, 0.8 * t.nuit))
			if fposmod(tps * 1.7 + k, 3.0) < 0.12:
				var a := Vector2(x + 200.0, base - 50.0)
				for s in 5:
					var b := a + Vector2(14.0 + 6.0 * sin(tps * 40.0 + s), -10.0 + 14.0 * sin(tps * 33.0 + s * 2.0))
					t.draw_line(a, b, Color(0.7, 0.85, 1.0, 0.9), 2.0)
					a = b


static func _tour_fer(t: Terrain, w: float, vit: float, base: float, col: Color) -> void:
	for c in _cellules(t, w, vit, 1400.0):
		var k: float = c[0]
		var x: float = c[1] + 500.0 + 300.0 * Terrain.alea(k, 78.0)
		var h := 190.0
		var p := [[-46.0, 0.0], [-20.0, 0.35], [-9.0, 0.7], [-4.0, 0.86]]
		for s in [-1.0, 1.0]:
			for i in p.size() - 1:
				t.draw_line(Vector2(x + s * p[i][0], base - h * p[i][1]), Vector2(x + s * p[i + 1][0], base - h * p[i + 1][1]), col, 3.0)
				t.draw_line(Vector2(x + s * p[i][0], base - h * p[i][1]), Vector2(x - s * p[i + 1][0], base - h * p[i + 1][1]), col, 1.0)
		t.draw_line(Vector2(x - 24.0, base - h * 0.35), Vector2(x + 24.0, base - h * 0.35), col, 3.0)
		t.draw_line(Vector2(x - 11.0, base - h * 0.7), Vector2(x + 11.0, base - h * 0.7), col, 2.0)
		t.draw_line(Vector2(x - 4.0, base - h * 0.86), Vector2(x + 7.0, base - h * 0.95), col, 2.0)   # sommet tordu, cassé
		_ville(t, w, 0.0, vit, base, col.lerp(Color(col, 0.0), 0.1), 0.6)


static func _ville(t: Terrain, w: float, _hgt: float, vit: float, base: float, col: Color, echelle := 1.0) -> void:
	var cels := _cellules(t, w, vit, 30.0)
	var pts := [Vector2(float(cels[0][1]) - 10.0, base + 4.0)]   # départ sous la première cellule : polygone sans croisement
	var trous := []
	for c in cels:
		var k: float = c[0]
		var x: float = c[1]
		var vide := Terrain.alea(floorf(k / 7.0), 79.0) > 0.7
		var h := (6.0 if vide else 30.0 + 90.0 * Terrain.alea(k, 80.0)) * echelle
		var brise := Terrain.alea(k, 81.0) * 18.0 * echelle
		pts.append(Vector2(x, minf(base - h + brise, base - 2.0)))
		pts.append(Vector2(x + 30.0, base - h))
		if not vide and h > 40.0 and Terrain.alea(k, 82.0) < 0.6:
			trous.append(Rect2(x + 8.0, base - h * 0.7, 6.0 * echelle, 8.0 * echelle))
	pts.append(Vector2(maxf(w + 30.0, (pts[-1] as Vector2).x + 10.0), base + 4.0))
	_poly(t, pts, col)
	var ciel := Color(col.lightened(0.35), 0.55)
	for r in trous:   # fenêtres soufflées : on voit le ciel au travers
		t.draw_rect(r, ciel)


static func _foret_morte(t: Terrain, w: float, vit: float, base: float, col: Color) -> void:
	for c in _cellules(t, w, vit, 22.0):
		var k: float = c[0]
		if Terrain.alea(k, 83.0) < 0.35:
			continue
		var x: float = c[1] + 10.0 * Terrain.alea(k, 84.0)
		var h := 20.0 + 34.0 * Terrain.alea(k, 85.0)
		t.draw_line(Vector2(x, base), Vector2(x + 1.0, base - h), col, 2.5)
		t.draw_line(Vector2(x + 1.0, base - h), Vector2(x + 4.0, base - h + 6.0), col, 1.5)   # cime brisée
		if Terrain.alea(k, 86.0) < 0.5:
			t.draw_line(Vector2(x, base - h * 0.6), Vector2(x - 7.0, base - h * 0.8), col, 1.2)
	t.draw_rect(Rect2(0, base - 2.0, w, 6.0), col)


static func _front(t: Terrain, w: float, _hgt: float, vit: float, base: float, col: Color) -> void:
	_poly(t, [Vector2(0, base + 6.0), Vector2(w, base + 6.0), Vector2(w, base - 8.0), Vector2(0, base - 8.0)], col.darkened(0.05))   # parapet
	for c in _cellules(t, w, vit, 34.0):
		var k: float = c[0]
		var x: float = c[1]
		t.draw_line(Vector2(x, base - 8.0), Vector2(x + 2.0, base - 20.0), col.darkened(0.2), 1.5)   # piquets
		t.draw_line(Vector2(x + 2.0, base - 18.0), Vector2(x + 36.0, base - 17.0 + 2.0 * sin(k)), col.darkened(0.2), 1.0)   # barbelés
		if Terrain.alea(k, 87.0) < 0.1:   # casemate
			_poly(t, [Vector2(x - 26.0, base - 6.0), Vector2(x + 26.0, base - 6.0), Vector2(x + 18.0, base - 26.0), Vector2(x - 18.0, base - 26.0)], col.darkened(0.12))
			t.draw_rect(Rect2(x - 10.0, base - 20.0, 20.0, 4.0), Color(0, 0, 0, 0.6))


static func _silos(t: Terrain, w: float, vit: float, base: float, col: Color) -> void:
	for c in _cellules(t, w, vit, 420.0):
		var k: float = c[0]
		if Terrain.alea(k, 88.0) > 0.65:
			continue
		var x: float = c[1] + 80.0 + 200.0 * Terrain.alea(k, 89.0)
		var n := 3 + int(Terrain.alea(k, 90.0) * 3.0)
		var h := 70.0 + 40.0 * Terrain.alea(k, 91.0)
		for j in n:
			var xs := x + j * 24.0
			t.draw_rect(Rect2(xs, base - h, 22.0, h), col.darkened(0.04 * (j % 2)))
			Disque.d(t, Vector2(xs + 11.0, base - h), 11.0, col.darkened(0.04 * (j % 2)))
		t.draw_rect(Rect2(x + n * 24.0, base - h - 34.0, 18.0, h + 34.0), col.darkened(0.1))   # élévateur
		_poly(t, [Vector2(x + n * 24.0 - 2.0, base - h - 34.0), Vector2(x + n * 24.0 + 20.0, base - h - 34.0), Vector2(x + n * 24.0 + 9.0, base - h - 46.0)], col.darkened(0.14))


static func _pont_effondre(t: Terrain, w: float, vit: float, base: float, col: Color) -> void:
	for c in _cellules(t, w, vit, 900.0):
		var k: float = c[0]
		if Terrain.alea(k, 92.0) > 0.6:
			continue
		var x: float = c[1] + 200.0 + 300.0 * Terrain.alea(k, 93.0)
		var y := base - 40.0
		for j in 5:
			var xp := x + j * 70.0
			t.draw_rect(Rect2(xp, y, 12.0, 40.0), col.darkened(0.06))
		t.draw_rect(Rect2(x - 20.0, y - 8.0, 160.0, 8.0), col)   # tablier encore debout
		_poly(t, [Vector2(x + 146.0, y - 8.0), Vector2(x + 156.0, y - 6.0), Vector2(x + 206.0, base), Vector2(x + 194.0, base)], col)   # travée tombée
		t.draw_rect(Rect2(x + 215.0, y - 8.0, 105.0, 8.0), col)


static func _pins(t: Terrain, w: float, vit: float, base: float, col: Color, echelle: float) -> void:
	for c in _cellules(t, w, vit, 26.0 * echelle):
		var k: float = c[0]
		if Terrain.alea(k, 94.0) < 0.3:
			continue
		var x: float = c[1] + 8.0 * Terrain.alea(k, 95.0)
		var h := (40.0 + 36.0 * Terrain.alea(k, 96.0)) * echelle
		t.draw_line(Vector2(x, base), Vector2(x, base - h), col, 2.0 * echelle)
		for j in 3:   # houppier clairsemé, aiguilles tombées
			var yb := base - h + j * 6.0 * echelle
			t.draw_line(Vector2(x - (6.0 + 3.0 * j) * echelle, yb + 3.0), Vector2(x + (6.0 + 3.0 * j) * echelle, yb), col, 1.5 * echelle)


static func _raffinerie(t: Terrain, w: float, vit: float, base: float, col: Color) -> void:
	var tps := Time.get_ticks_msec() * 0.001
	for c in _cellules(t, w, vit, 640.0):
		var k: float = c[0]
		if Terrain.alea(k, 97.0) > 0.7:
			continue
		var x: float = c[1] + 100.0 + 220.0 * Terrain.alea(k, 98.0)
		for j in 3:   # colonnes de distillation
			var h := 70.0 + 30.0 * j
			t.draw_rect(Rect2(x + j * 26.0, base - h, 14.0, h), col)
			for r in 4:
				t.draw_line(Vector2(x + j * 26.0 - 3.0, base - h * (0.2 + 0.2 * r)), Vector2(x + j * 26.0 + 17.0, base - h * (0.2 + 0.2 * r)), col.darkened(0.15), 1.5)
		for j in 2:   # réservoirs
			t.draw_rect(Rect2(x + 100.0 + j * 52.0, base - 30.0, 44.0, 30.0), col.darkened(0.06))
		Disque.d(t, Vector2(x + 215.0, base - 22.0), 20.0, col.darkened(0.03))   # sphère
		var xf := x + 250.0
		t.draw_line(Vector2(xf, base), Vector2(xf, base - 120.0), col, 2.5)   # torchère
		var fl := 0.8 + 0.2 * sin(tps * 13.0 + k)
		Disque.d(t, Vector2(xf, base - 128.0), 9.0 * fl, Color(1.0, 0.55, 0.15, 0.85))
		Disque.d(t, Vector2(xf, base - 131.0), 5.0 * fl, Color(1.0, 0.9, 0.5, 0.9))
		if t.nuit > 0.1:
			Disque.d(t, Vector2(xf, base - 128.0), 40.0, Color(1.0, 0.5, 0.1, 0.12 * t.nuit))


static func _puys(t: Terrain, w: float, _hgt: float, vit: float, base: float, col: Color) -> void:
	var cels := _cellules(t, w, vit, 220.0)
	var pts := [Vector2(float(cels[0][1]) - 10.0, base + 4.0)]
	for c in cels:
		var k: float = c[0]
		var x: float = c[1]
		if Terrain.alea(k, 99.0) < 0.6:
			var h := 50.0 + 70.0 * Terrain.alea(k, 100.0)
			pts.append_array([Vector2(x + 20.0, base), Vector2(x + 80.0, base - h * 0.85), Vector2(x + 96.0, base - h),
				Vector2(x + 110.0, base - h + 8.0), Vector2(x + 124.0, base - h), Vector2(x + 140.0, base - h * 0.85), Vector2(x + 200.0, base)])
		else:
			pts.append(Vector2(x + 110.0, base - 12.0 - 10.0 * Terrain.alea(k, 101.0)))   # plateau basaltique
	pts.append(Vector2(maxf(w + 30.0, (pts[-1] as Vector2).x + 10.0), base + 4.0))
	_poly(t, pts, col)


static func _viaduc(t: Terrain, w: float, vit: float, base: float, col: Color) -> void:
	for c in _cellules(t, w, vit, 1100.0):
		var k: float = c[0]
		if Terrain.alea(k, 102.0) > 0.7:
			continue
		var x: float = c[1] + 200.0 * Terrain.alea(k, 103.0)
		var y := base - 96.0
		t.draw_rect(Rect2(x, y - 6.0, 460.0, 8.0), col)   # tablier et voie ferrée
		for j in 9:
			var xp := x + j * 52.0
			t.draw_rect(Rect2(xp, y, 8.0, 96.0), col)
			t.draw_arc(Vector2(xp + 30.0, y + 26.0), 22.0, PI, TAU, 10, col, 4.0)


static func _barrage(t: Terrain, w: float, hgt: float, vit: float, base: float, col: Color, hor: Color) -> void:
	for c in _cellules(t, w, vit, 1000.0):
		var k: float = c[0]
		if Terrain.alea(k, 104.0) > 0.7:
			continue
		var x: float = c[1] + 150.0 + 300.0 * Terrain.alea(k, 105.0)
		t.draw_rect(Rect2(x - 260.0, base - 52.0, 240.0, 8.0), hor.lerp(Color("#6F8E9A"), 0.4))   # retenue
		_poly(t, [Vector2(x - 20.0, base - 58.0), Vector2(x + 300.0, base - 58.0), Vector2(x + 310.0, base), Vector2(x - 40.0, base)], col)
		for j in 4:   # vannes et coulures
			t.draw_rect(Rect2(x + 30.0 + j * 70.0, base - 52.0, 18.0, 46.0), col.darkened(0.12))
		t.draw_rect(Rect2(x + 60.0, base - 40.0, 8.0, 40.0), Color(hor.lightened(0.2), 0.5))


static func _usines(t: Terrain, w: float, vit: float, base: float, col: Color) -> void:
	var tps := Time.get_ticks_msec() * 0.001
	for c in _cellules(t, w, vit, 180.0):
		var k: float = c[0]
		if Terrain.alea(k, 106.0) > 0.75:
			continue
		var x: float = c[1] + 20.0 * Terrain.alea(k, 107.0)
		var h := 34.0 + 30.0 * Terrain.alea(k, 108.0)
		var pts := [Vector2(x, base), Vector2(x, base - h)]
		for j in 5:   # toit en dents de scie
			pts.append_array([Vector2(x + j * 28.0, base - h - 14.0), Vector2(x + j * 28.0 + 28.0, base - h)])
		pts.append(Vector2(x + 140.0, base))
		_poly(t, pts, col)
		if Terrain.alea(k, 109.0) < 0.6:
			var xc := x + 150.0
			t.draw_rect(Rect2(xc, base - h - 70.0, 10.0, h + 70.0), col.darkened(0.08))
			if Terrain.alea(k, 110.0) < 0.5:
				for f in 3:
					var ph := fposmod(tps * 0.2 + f * 0.33 + k * 0.1, 1.0)
					Disque.d(t, Vector2(xc + 5.0 + ph * 40.0, base - h - 74.0 - ph * 50.0), 6.0 + ph * 16.0, Color(col.lightened(0.25), 0.3 * (1.0 - ph)))


static func _etang(t: Terrain, w: float, base: float, col: Color, hor: Color) -> void:
	t.draw_rect(Rect2(0, base - 8.0, w, 14.0), hor.lerp(Color("#D8C8C4"), 0.5))   # étang salé, rosé
	for c in _cellules(t, w, 0.05, 160.0):
		if Terrain.alea(c[0], 111.0) < 0.4:   # tas de sel
			var x: float = c[1] + 40.0
			_poly(t, [Vector2(x, base - 6.0), Vector2(x + 50.0, base - 6.0), Vector2(x + 25.0, base - 26.0)], Color("#EFEAE2").lerp(col, 0.25))


static func _montagnes(t: Terrain, w: float, _hgt: float, vit: float, base: float, col: Color) -> void:
	var roc := Color("#566270").lerp(col, 0.3)   # roche bleutée, prise dans la brume (col suit l'heure)
	var cels := _cellules(t, w, vit, 150.0)
	var pts := [Vector2(float(cels[0][1]) - 10.0, base + 4.0)]
	var neige := []
	for c in cels:
		var k: float = c[0]
		var x: float = c[1] + 30.0 * Terrain.alea(k, 116.5)
		var h := 80.0 + 130.0 * Terrain.alea(k, 112.0)
		var s := Vector2(x + 50.0 + 30.0 * Terrain.alea(k, 117.5), base - h)
		pts.append_array([Vector2(x, base - 30.0 * Terrain.alea(k, 113.0)), Vector2(x + 30.0, base - h * (0.55 + 0.2 * Terrain.alea(k, 118.5))), s])
		neige.append([s, h])
	pts.append(Vector2(maxf(w + 30.0, (pts[-1] as Vector2).x + 10.0), base + 4.0))
	_poly(t, pts, roc)
	var blanc := roc.lerp(Color.WHITE, 0.72 * (1.0 - 0.75 * t.nuit))   # calotte : pâle de jour, sombre la nuit
	for n in neige:
		var s: Vector2 = n[0]
		var d := float(n[1]) * 0.2
		_poly(t, [s, s + Vector2(d * 0.9, d * 1.1), s + Vector2(d * 0.3, d * 0.8), s + Vector2(-d * 0.4, d * 1.15), s + Vector2(-d * 0.9, d * 0.95)], blanc)


static func _fort(t: Terrain, w: float, vit: float, base: float, col: Color) -> void:
	for c in _cellules(t, w, vit, 800.0):
		var k: float = c[0]
		if Terrain.alea(k, 114.0) > 0.6:
			continue
		var x: float = c[1] + 200.0 + 300.0 * Terrain.alea(k, 115.0)
		_poly(t, [Vector2(x - 140.0, base), Vector2(x - 60.0, base - 40.0), Vector2(x + 80.0, base - 40.0), Vector2(x + 150.0, base)], col.darkened(0.05))   # éperon
		t.draw_rect(Rect2(x - 50.0, base - 66.0, 120.0, 26.0), col.darkened(0.12))
		for j in 7:   # créneaux
			t.draw_rect(Rect2(x - 50.0 + j * 18.0, base - 72.0, 10.0, 6.0), col.darkened(0.12))
		t.draw_rect(Rect2(x + 40.0, base - 92.0, 22.0, 30.0), col.darkened(0.16))


# --- Ligne plantée sur les dunes proches (plan à 0,38) ---------------------------------------------------------------
static func ligne(t: Terrain, type: String, w: float, vit: float, niveau: float, amp: float, graine: float, col: Color) -> bool:
	if type == "" or type == "poteaux":
		return false   # la ligne télégraphique d'origine
	if type == "aucune":
		return true
	var pas: float = {"pylones": 260.0, "barbeles": 42.0, "pins": 60.0, "sapins": 52.0, "reverberes": 160.0, "pieux": 30.0}.get(type, 200.0)
	var prec := Vector2.INF
	for c in _cellules(t, w, vit, pas):
		var k: float = c[0]
		var x: float = c[1] + pas * 0.3 * Terrain.alea(k, 116.0)
		var pied := Vector2(x, t._dune_y(x, vit, niveau, amp, graine) + 3.0)
		match type:
			"pylones":   # pylône à treillis, câbles qui pendent
				var h := 96.0
				t.draw_line(pied + Vector2(-14, 0), pied + Vector2(-3, -h), col, 2.5)
				t.draw_line(pied + Vector2(14, 0), pied + Vector2(3, -h), col, 2.5)
				for j in 4:
					var y := -h * (0.2 + 0.2 * j)
					t.draw_line(pied + Vector2(-12.0 + 2.2 * j * 1.2, y), pied + Vector2(12.0 - 2.2 * j * 1.2, y - h * 0.2), col, 1.0)
				t.draw_line(pied + Vector2(-22, -h * 0.85), pied + Vector2(22, -h * 0.85), col, 2.0)
				var tete := pied + Vector2(20, -h * 0.85)
				if prec != Vector2.INF and Terrain.alea(k, 117.0) > 0.15:
					var mi := (prec + tete) * 0.5 + Vector2(0, 22.0)
					t.draw_polyline(PackedVector2Array([prec, mi, tete]), Color(col, 0.7), 1.0)
				prec = tete
			"barbeles":
				t.draw_line(pied, pied + Vector2(1.0, -16.0), col, 2.0)
				if prec != Vector2.INF:
					t.draw_line(prec + Vector2(0, -12.0), pied + Vector2(1.0, -12.0), Color(col, 0.8), 1.0)
					t.draw_line(prec + Vector2(0, -5.0), pied + Vector2(1.0, -6.0), Color(col, 0.8), 1.0)
				prec = pied
			"pins":
				if Terrain.alea(k, 118.0) < 0.6:
					var h2 := 46.0 + 30.0 * Terrain.alea(k, 119.0)
					t.draw_line(pied, pied + Vector2(0, -h2), col, 2.5)
					for j in 3:
						t.draw_line(pied + Vector2(-8.0 - 3.0 * j, -h2 + 6.0 * j + 3.0), pied + Vector2(8.0 + 3.0 * j, -h2 + 6.0 * j), col, 1.5)
			"sapins":
				if Terrain.alea(k, 120.0) < 0.7:
					var h3 := 30.0 + 26.0 * Terrain.alea(k, 121.0)
					_poly(t, [pied + Vector2(-h3 * 0.3, 0), pied + Vector2(h3 * 0.3, 0), pied + Vector2(0, -h3)], col)
					_poly(t, [pied + Vector2(-h3 * 0.18, -h3 * 0.55), pied + Vector2(h3 * 0.18, -h3 * 0.55), pied + Vector2(0, -h3)], Color("#EEF2F4").lerp(col, 0.35))
			"reverberes":
				t.draw_line(pied, pied + Vector2(0, -60.0), col, 2.5)
				t.draw_line(pied + Vector2(0, -60.0), pied + Vector2(12.0, -56.0), col, 2.0)
				t.draw_rect(Rect2(pied + Vector2(9.0, -58.0), Vector2(7.0, 8.0)), col.darkened(0.1))
			"pieux":   # bouchots et piquets de parcs
				t.draw_line(pied + Vector2(0, 2.0), pied + Vector2(0.5, -10.0 - 6.0 * Terrain.alea(k, 122.0)), col, 2.0)
	return true


# --- Objets du bord de route ----------------------------------------------------------------------------------------------
# pied : point au sol en pixels ; p : pixels par mètre ; kk : indice stable de l'objet. Rend faux si le genre est inconnu.
static func objet(t: Terrain, genre: String, pied: Vector2, p: float, kk: float) -> bool:
	var a := Terrain.alea(kk, 130.0)
	match genre:
		"calvaire":   # croix de granit sur un socle
			var g := Color("#7E7C74")
			t.draw_rect(Rect2(pied + Vector2(-0.6 * p, -0.6 * p), Vector2(1.2 * p, 0.6 * p)), g.darkened(0.1))
			t.draw_rect(Rect2(pied + Vector2(-0.14 * p, -3.2 * p), Vector2(0.28 * p, 2.6 * p)), g)
			t.draw_rect(Rect2(pied + Vector2(-0.7 * p, -2.6 * p), Vector2(1.4 * p, 0.26 * p)), g)
		"menhir":
			_poly(t, [pied + Vector2(-0.5 * p, 0), pied + Vector2(0.55 * p, 0), pied + Vector2(0.35 * p, -2.6 * p), pied + Vector2(-0.1 * p, -3.0 * p),
				pied + Vector2(-0.45 * p, -2.2 * p)], Color("#8A877C").darkened(0.15 * a))
		"bateau":   # chalutier échoué, couché sur le flanc
			var b := Color("#5A4A3C")
			_poly(t, [pied + Vector2(-3.0 * p, 0), pied + Vector2(2.6 * p, 0.1 * p), pied + Vector2(3.4 * p, -1.6 * p), pied + Vector2(-2.6 * p, -1.9 * p)], b)
			t.draw_rect(Rect2(pied + Vector2(-0.6 * p, -2.9 * p), Vector2(1.4 * p, 1.1 * p)), b.lightened(0.15))
			t.draw_line(pied + Vector2(1.6 * p, -1.8 * p), pied + Vector2(3.2 * p, -4.4 * p), b.darkened(0.2), maxf(2.0, 0.1 * p))
			t.draw_line(pied + Vector2(-2.8 * p, -0.9 * p), pied + Vector2(3.0 * p, -0.8 * p), Color("#8C3A2A"), maxf(1.5, 0.08 * p))
		"pieu":
			for j in 3:
				t.draw_line(pied + Vector2((j - 1) * 0.5 * p, 0), pied + Vector2((j - 1) * 0.5 * p, -(1.0 + 0.5 * Terrain.alea(kk + j, 131.0)) * p), Color("#4E3F30"), maxf(2.0, 0.12 * p))
		"haie_brulee":
			for j in 5:
				Disque.d(t, pied + Vector2((j - 2) * 0.6 * p, -0.5 * p - 0.3 * p * Terrain.alea(kk + j, 132.0)), (0.45 + 0.25 * Terrain.alea(kk + j, 133.0)) * p, Color("#3A322A"))
			t.draw_line(pied + Vector2(0.3 * p, 0), pied + Vector2(0.5 * p, -2.0 * p), Color("#2A2420"), maxf(1.5, 0.08 * p))
		"wagonnet":   # berline de mine renversée
			var cw := Color("#4A3E36")
			_poly(t, [pied + Vector2(-1.0 * p, -0.3 * p), pied + Vector2(1.0 * p, -0.3 * p), pied + Vector2(1.2 * p, -1.2 * p), pied + Vector2(-1.2 * p, -1.2 * p)], cw)
			Disque.d(t, pied + Vector2(-0.6 * p, -0.2 * p), 0.22 * p, Color("#2A2622"))
			Disque.d(t, pied + Vector2(0.6 * p, -0.2 * p), 0.22 * p, Color("#2A2622"))
			_poly(t, [pied + Vector2(-0.9 * p, -1.2 * p), pied + Vector2(0.9 * p, -1.2 * p), pied + Vector2(0.4 * p, -1.6 * p)], Color("#1E1C1B"))   # charbon
		"terril_petit":
			_poly(t, [pied + Vector2(-2.5 * p, 0.1 * p), pied + Vector2(2.5 * p, 0.1 * p), pied + Vector2(0.3 * p, -1.4 * p)], Color("#2E2C2A"))
		"pylone":
			var cp := Color("#3A3A3C")
			t.draw_line(pied + Vector2(-0.7 * p, 0), pied + Vector2(-0.15 * p, -6.0 * p), cp, maxf(2.0, 0.1 * p))
			t.draw_line(pied + Vector2(0.7 * p, 0), pied + Vector2(0.15 * p, -6.0 * p), cp, maxf(2.0, 0.1 * p))
			for j in 4:
				t.draw_line(pied + Vector2(-0.6 * p + j * 0.1 * p, -(1.0 + 1.3 * j) * p), pied + Vector2(0.6 * p - j * 0.1 * p, -(1.6 + 1.3 * j) * p), cp, maxf(1.0, 0.05 * p))
			t.draw_line(pied + Vector2(-1.4 * p, -5.4 * p), pied + Vector2(1.4 * p, -5.4 * p), cp, maxf(1.5, 0.08 * p))
		"reverbere":
			var cr := Color("#2E2E2C")
			t.draw_line(pied, pied + Vector2(0, -4.0 * p), cr, maxf(2.0, 0.1 * p))
			t.draw_line(pied + Vector2(0, -4.0 * p), pied + Vector2(0.6 * p, -3.8 * p), cr, maxf(1.5, 0.07 * p))
			t.draw_rect(Rect2(pied + Vector2(0.45 * p, -3.9 * p), Vector2(0.35 * p, 0.45 * p)), cr)
			if t.nuit > 0.3 and a < 0.3:   # un sur trois brûle encore
				Disque.d(t, pied + Vector2(0.62 * p, -3.6 * p), 1.2 * p, Color(1.0, 0.8, 0.45, 0.25 * t.nuit))
		"gravats":
			for j in 5:
				_poly(t, [pied + Vector2((j - 2) * 0.6 * p, 0), pied + Vector2((j - 2) * 0.6 * p + 0.7 * p, 0), pied + Vector2((j - 2) * 0.6 * p + 0.3 * p, -(0.3 + 0.5 * Terrain.alea(kk + j, 134.0)) * p)],
					Color("#7A7068").darkened(0.12 * float(j % 3)))
			t.draw_line(pied + Vector2(-0.8 * p, -0.4 * p), pied + Vector2(0.9 * p, -1.1 * p), Color("#4A3A30"), maxf(1.5, 0.06 * p))   # fer à béton
		"derrick":   # chevalet de pompage
			var cd := Color("#3A3632")
			t.draw_line(pied + Vector2(-0.8 * p, 0), pied + Vector2(0, -2.6 * p), cd, maxf(2.0, 0.1 * p))
			t.draw_line(pied + Vector2(0.8 * p, 0), pied + Vector2(0, -2.6 * p), cd, maxf(2.0, 0.1 * p))
			var bal := sin(Time.get_ticks_msec() * 0.002 + kk) * 0.35   # le balancier bouge encore
			t.draw_line(pied + Vector2(0, -2.6 * p) + Vector2(-2.0 * p, 0).rotated(bal), pied + Vector2(0, -2.6 * p) + Vector2(1.8 * p, 0).rotated(bal), cd, maxf(3.0, 0.16 * p))
			var tete := pied + Vector2(0, -2.6 * p) + Vector2(-2.0 * p, 0).rotated(bal)
			t.draw_line(tete, pied + Vector2(-2.0 * p, 0), cd, maxf(1.0, 0.04 * p))   # tige de pompage
		"baril":
			for j in 2 + int(a * 3.0):
				var cb := Color("#6E3A26") if (int(kk) + j) % 3 else Color("#3E5A6A")
				t.draw_rect(Rect2(pied + Vector2((j - 1) * 0.65 * p - 0.3 * p, -1.0 * p), Vector2(0.6 * p, 1.0 * p)), cb.darkened(0.1 * j))
				t.draw_line(pied + Vector2((j - 1) * 0.65 * p - 0.3 * p, -0.5 * p), pied + Vector2((j - 1) * 0.65 * p + 0.3 * p, -0.5 * p), cb.darkened(0.35), maxf(1.0, 0.04 * p))
		"herisson":   # hérisson tchèque antichar
			var ch := Color("#3C3A36")
			for j in 3:
				var ang := PI * j / 3.0 + 0.3
				t.draw_line(pied + Vector2(0, -0.8 * p) + Vector2.from_angle(ang) * 1.0 * p, pied + Vector2(0, -0.8 * p) - Vector2.from_angle(ang) * 1.0 * p, ch, maxf(3.0, 0.18 * p))
		"barbele":
			for j in 4:
				var xp := (j - 1.5) * 0.9 * p
				t.draw_line(pied + Vector2(xp, 0), pied + Vector2(xp + 0.1 * p, -1.1 * p), Color("#4A3A2C"), maxf(1.5, 0.06 * p))
			for j in 3:
				t.draw_arc(pied + Vector2((j - 1) * 0.9 * p, -0.6 * p), 0.45 * p, 0.0, TAU, 8, Color("#5A5650"), 1.0)
		"cratere":
			_poly(t, [pied + Vector2(-2.2 * p, 0.05 * p), pied + Vector2(-1.4 * p, -0.35 * p), pied + Vector2(1.4 * p, -0.35 * p), pied + Vector2(2.2 * p, 0.05 * p)], Color("#5C564C"))
			_poly(t, [pied + Vector2(-1.3 * p, -0.32 * p), pied + Vector2(1.3 * p, -0.32 * p), pied + Vector2(0.9 * p, -0.08 * p), pied + Vector2(-0.9 * p, -0.08 * p)], Color("#3E3A34"))
		"arbre_brise":
			var cb2 := Color("#3A2E26")
			t.draw_line(pied, pied + Vector2(0.1 * p, -2.2 * p), cb2, maxf(3.0, 0.2 * p))
			_poly(t, [pied + Vector2(-0.15 * p, -2.2 * p), pied + Vector2(0.3 * p, -2.2 * p), pied + Vector2(0.05 * p, -2.9 * p)], cb2)
			t.draw_line(pied + Vector2(0.4 * p, 0), pied + Vector2(2.6 * p, -0.3 * p), cb2, maxf(2.0, 0.14 * p))   # tronc tombé
		"bunker_petit":
			var cbk := Color("#8C8A82")
			_poly(t, [pied + Vector2(-2.0 * p, 0), pied + Vector2(2.0 * p, 0), pied + Vector2(1.5 * p, -1.4 * p), pied + Vector2(-1.5 * p, -1.4 * p)], cbk)
			t.draw_rect(Rect2(pied + Vector2(-0.9 * p, -1.0 * p), Vector2(1.8 * p, 0.25 * p)), Color(0.05, 0.05, 0.05, 0.85))
		"silo_petit":
			var cs := Color("#9A8E78")
			t.draw_rect(Rect2(pied + Vector2(-0.8 * p, -4.0 * p), Vector2(1.6 * p, 4.0 * p)), cs)
			Disque.d(t, pied + Vector2(0, -4.0 * p), 0.8 * p, cs.darkened(0.06))
			t.draw_line(pied + Vector2(-0.8 * p, -2.0 * p), pied + Vector2(0.8 * p, -2.0 * p), cs.darkened(0.2), maxf(1.0, 0.04 * p))
		"pin_mort":
			_pins_un(t, pied, p, a)
		"basalte":   # orgues basaltiques
			for j in 4:
				var hb := (1.0 + 1.2 * Terrain.alea(kk + j, 135.0)) * p
				t.draw_rect(Rect2(pied + Vector2((j - 2) * 0.42 * p, -hb), Vector2(0.38 * p, hb)), Color("#3E3A3A").lightened(0.06 * float(j % 2)))
		"signal":   # signal ferroviaire à palette
			var cg := Color("#2E2C2A")
			t.draw_line(pied, pied + Vector2(0, -4.2 * p), cg, maxf(2.0, 0.09 * p))
			t.draw_rect(Rect2(pied + Vector2(0, -4.1 * p), Vector2(1.2 * p, 0.3 * p)), Color("#8C2A22"))
		"buisson_sec":
			for j in 5:
				var ang2 := -PI * (0.15 + 0.7 * j / 4.0)
				t.draw_line(pied, pied + Vector2.from_angle(ang2) * (0.7 + 0.3 * Terrain.alea(kk + j, 136.0)) * p, Color("#6E6040"), maxf(1.5, 0.05 * p))
		"cypres":
			_poly(t, [pied + Vector2(-0.35 * p, 0), pied + Vector2(0.35 * p, 0), pied + Vector2(0.4 * p, -2.0 * p), pied + Vector2(0, -4.2 * p), pied + Vector2(-0.4 * p, -2.0 * p)], Color("#3E4A2C"))
		"sel":
			_poly(t, [pied + Vector2(-1.4 * p, 0), pied + Vector2(1.4 * p, 0), pied + Vector2(0.1 * p, -1.1 * p)], Color("#EDE7DE"))
		"sapin":
			var h := (2.4 + 1.4 * a) * p
			_poly(t, [pied + Vector2(-0.8 * p, 0), pied + Vector2(0.8 * p, 0), pied + Vector2(0, -h)], Color("#2E3E32"))
			_poly(t, [pied + Vector2(-0.45 * p, -h * 0.5), pied + Vector2(0.45 * p, -h * 0.5), pied + Vector2(0, -h)], Color("#E8EEF0"))
		"rocher_neige":
			for j in 3:
				var c0 := pied + Vector2((j - 1) * 0.5 * p, 0.1 * p)
				var r0 := (0.35 + 0.3 * Terrain.alea(kk + j, 137.0)) * p
				Disque.d(t, c0, r0, Color("#6E6A66").darkened(0.1 * j))
				Disque.d(t, c0 + Vector2(0, -r0 * 0.45), r0 * 0.7, Color("#EEF2F4"))
		"borne":   # borne kilométrique
			t.draw_rect(Rect2(pied + Vector2(-0.25 * p, -0.7 * p), Vector2(0.5 * p, 0.7 * p)), Color("#E6E2D8"))
			t.draw_rect(Rect2(pied + Vector2(-0.25 * p, -0.9 * p), Vector2(0.5 * p, 0.22 * p)), Color("#A8342A"))
		"obj_charrette":
			var cc := Color("#5C4632")
			t.draw_rect(Rect2(pied + Vector2(-1.2 * p, -1.1 * p), Vector2(2.2 * p, 0.6 * p)), cc)
			Disque.d(t, pied + Vector2(-0.3 * p, -0.45 * p), 0.45 * p, cc.darkened(0.25))
			t.draw_line(pied + Vector2(1.0 * p, -0.8 * p), pied + Vector2(2.4 * p, -0.1 * p), cc, maxf(1.5, 0.07 * p))
		_:
			return false
	return true


static func _pins_un(t: Terrain, pied: Vector2, p: float, a: float) -> void:
	var h := (4.0 + 2.5 * a) * p
	var c := Color("#3A2E24")
	t.draw_line(pied, pied + Vector2(0.1 * p, -h), c, maxf(2.0, 0.14 * p))
	for j in 3:
		t.draw_line(pied + Vector2(-(0.4 + 0.2 * j) * p, -h + (0.4 + 0.5 * j) * p), pied + Vector2((0.5 + 0.2 * j) * p, -h + 0.5 * j * p), c, maxf(1.5, 0.07 * p))


# --- Particules, devant tout (calque du premier plan) ---------------------------------------------------------------------
static func particules(t: Terrain, type: String, w: float, hgt: float) -> void:
	if type == "":
		return
	var tps := Time.get_ticks_msec() * 0.001
	match type:
		"neige", "cendres":
			var c := Color(0.95, 0.97, 1.0, 0.75) if type == "neige" else Color(0.18, 0.17, 0.16, 0.55)
			var n := 70 if type == "neige" else 45
			for i in n:
				var vx := (-30.0 - 25.0 * Terrain.alea(i, 140.0)) if type == "neige" else (-60.0 - 40.0 * Terrain.alea(i, 140.0))
				var vy := (55.0 + 40.0 * Terrain.alea(i, 141.0)) if type == "neige" else (18.0 + 14.0 * Terrain.alea(i, 141.0))
				var x := fposmod(i * 211.0 + vx * tps - t.camera_x * t.ppm * 1.2 + 12.0 * sin(tps * 1.3 + i), w + 40.0) - 20.0
				var y := fposmod(i * 97.0 + vy * tps, hgt + 40.0) - 20.0
				Disque.d(t, Vector2(x, y), 1.6 + 2.2 * Terrain.alea(i, 142.0), c)
		"embruns":   # voiles d'air salé qui passent
			for i in 5:
				var x2 := fposmod(i * 420.0 - tps * (40.0 + 10.0 * i) - t.camera_x * t.ppm * 0.6, w + 600.0) - 300.0
				t.draw_set_transform(Vector2(x2, hgt * (0.35 + 0.1 * i)), 0.0, Vector2(6.0, 0.6))
				Disque.d(t, Vector2.ZERO, 40.0, Color(1, 1, 1, 0.05 * (1.0 - 0.5 * t.nuit)))
				t.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
