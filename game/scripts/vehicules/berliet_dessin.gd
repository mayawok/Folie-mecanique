# Dessin du Berliet GDR à partir de l'art découpé (BerlietConfig) + modules arrière dessinés par le code
# (plateau, citerne, benne à épaves, grue et plateau, transport de troupes, ridelles hautes).
# Origine du nœud : sol, au droit de u = 0 (arrière du châssis long) ; le camion regarde vers la droite.
class_name BerlietDessin
extends Node2D

var config := BerlietConfig.defaut()
var ppm := 60.0              # pixels d'écran par mètre
var trappe := 0.0            # 0 fermée, 1 ouverte
var angle_roues := 0.0       # rotation des roues (rad)
var secousse := 0.0          # petit tressautement de la caisse quand le moteur tourne (px)
var stabilisateurs := 0.0    # grue : 0 rentrés, 1 posés au sol (à l'arrêt)
var charge_grue := true      # grue : une épave sur le plateau
var teinte := Color.WHITE    # nuit, crépuscule

static var _tex := {}


static func texture(id: String) -> Texture2D:
	if not _tex.has(id):
		_tex[id] = load("res://assets/%s.png" % id)
	return _tex[id]


func k() -> float:
	return ppm / BerlietConfig.ppm_art()


# Point en u (repère de la planche) -> point local du nœud
func p(u: Vector2) -> Vector2:
	return Vector2(u.x, u.y - BerlietConfig.sol()) * k()


func pu(x: float, y: float) -> Vector2:
	return p(Vector2(x, y))


# Sortie de l'échappement (local) : pour la fumée
func sortie_echappement() -> Vector2:
	for c in BerlietConfig.calques(config):
		if c.id == "echappement":
			var t := texture(c.image)
			var w: float = t.get_width() * c.e
			var h: float = t.get_height() * c.e
			return pu(c.x - w + 0.18 * w, c.y - h + 0.04 * h)
	return Vector2.ZERO


func _draw() -> void:
	var sec := Vector2(0, secousse)
	for c in BerlietConfig.calques(config):
		match String(c.id):
			"module":
				draw_set_transform(sec)
				_module()
				draw_set_transform(Vector2.ZERO)
			"roue":
				var t := texture(c.image)
				var taille := Vector2(t.get_width(), t.get_height()) * float(c.e) * k()
				draw_set_transform(pu(c.x, c.y), angle_roues)
				draw_texture_rect(t, Rect2(-taille / 2.0, taille), false, teinte)
				draw_set_transform(Vector2.ZERO)
			"trappe":
				var t := texture(c.image)
				var e: float = float(c.e) * k()
				var piv: Vector2 = c.pivot
				var o := pu(c.x, c.y) + piv * e + sec
				draw_set_transform(o, float(c.ouverture) * trappe)
				draw_texture_rect(t, Rect2(-piv * e, Vector2(t.get_width(), t.get_height()) * e), false, teinte)
				draw_set_transform(Vector2.ZERO)
			_:
				var t := texture(c.image)
				var taille := Vector2(t.get_width(), t.get_height()) * float(c.e)
				var hg := Vector2(c.x, c.y)
				if c.ancre == "bd":
					hg -= taille
				var s := Vector2.ZERO if c.id == "chassis" else sec
				draw_texture_rect(t, Rect2(p(hg) + s, taille * k()), false, teinte)


# --- Modules arrière (code) --------------------------------------------------------------------------------
const BOIS := Color("#6E5233")
const BOIS_C := Color("#8A6A44")
const ACIER := Color("#4C5459")
const ACIER_C := Color("#69736F")
const ROUILLE := Color("#7A4A2A")
const NOIR := Color(0.08, 0.07, 0.06, 0.9)


func _c(col: Color) -> Color:
	return col * teinte


func _rect_u(x0: float, y0: float, x1: float, y1: float, col: Color, contour := true) -> void:
	var r := Rect2(pu(x0, y0), pu(x1, y1) - pu(x0, y0)).abs()
	draw_rect(r, _c(col))
	if contour:
		draw_rect(r, _c(NOIR), false, maxf(1.0, k() * 3.0))


func _ligne_u(a: Vector2, b: Vector2, col: Color, ep_u: float) -> void:
	draw_line(p(a), p(b), _c(col), maxf(1.0, ep_u * k()))


func _rivets(x0: float, x1: float, y: float, pas := 40.0) -> void:
	var x := x0 + pas * 0.5
	while x < x1:
		draw_circle(pu(x, y), maxf(1.0, 4.0 * k()), _c(Color("#9A8A70")))
		x += pas


func _plancher(x0: float, x1: float, r: float) -> void:
	_rect_u(x0, r - 26.0, x1, r, BOIS)
	var x := x0 + 70.0
	while x < x1:
		_ligne_u(Vector2(x, r - 26.0), Vector2(x, r), Color("#4A3826"), 2.0)
		x += 70.0
	_rect_u(x0, r, x1, r + 14.0, ACIER)   # traverse sous le plancher


func _ridelle(x0: float, x1: float, y_haut: float, y_bas: float, planche := 40.0, jour := 8.0) -> void:
	# planches horizontales avec un jour entre elles, montants tous les 160 u
	var y := y_bas
	var i := 0
	while y - planche >= y_haut - 0.5:
		_rect_u(x0, y - planche, x1, y, BOIS_C.darkened(0.08 * (i % 2)), false)
		_ligne_u(Vector2(x0, y - planche), Vector2(x1, y - planche), Color("#3E2E1E"), 2.0)
		y -= planche + jour
		i += 1
	var x := x0
	while x <= x1 + 0.5:
		_rect_u(x - 9.0, y_haut - 6.0, x + 9.0, y_bas, BOIS.darkened(0.15))
		x += 160.0


func _module() -> void:
	var m := String(config.module)
	if m == "aucun":
		return
	var pl := BerlietConfig.plateau(config)
	var x0 := pl.x
	var x1 := pl.y
	var r := BerlietConfig.rail(config)
	match m:
		"plateau":
			_plancher(x0, x1, r)
			_ridelle(x0, x0 + 30.0, r - 120.0, r - 26.0, 30.0, 6.0)
			_tablier(x1, r)
		"citerne":
			_citerne(x0, x1, r)
		"benne":
			_benne(x0, x1, r)
		"grue":
			_grue(x0, x1, r)
		"troupes":
			_troupes(x0, x1, r)
		"ridelles":
			_ridelles_hautes(x0, x1, r)


# Tablier avant (protège la cabine)
func _tablier(x1: float, r: float) -> void:
	_rect_u(x1 - 22.0, r - 260.0, x1, r - 26.0, ACIER)
	for y in [r - 240.0, r - 150.0, r - 60.0]:
		_ligne_u(Vector2(x1 - 22.0, y), Vector2(x1, y), ACIER_C, 6.0)


func _citerne(x0: float, x1: float, r: float) -> void:
	var d := 330.0                     # diamètre 1,32 m
	var a := x0 + 40.0
	var b := x1 - 40.0
	var yb := r - 34.0
	var yh := yb - d
	# berceaux
	for x in [a + 120.0, (a + b) / 2.0, b - 120.0]:
		_rect_u(x - 30.0, yb - 40.0, x + 30.0, r, ACIER.darkened(0.2))
	# corps : rectangle + deux fonds bombés
	var col := Color("#5B6248")
	var rr := d / 2.0
	draw_circle(pu(a + rr, yh + rr), rr * k(), _c(col.darkened(0.12)))
	draw_circle(pu(b - rr, yh + rr), rr * k(), _c(col.darkened(0.12)))
	_rect_u(a + rr, yh, b - rr, yb, col, false)
	_ligne_u(Vector2(a + rr, yh + 40.0), Vector2(b - rr, yh + 40.0), col.lightened(0.15), 18.0)   # reflet
	_ligne_u(Vector2(a + rr, yb - 20.0), Vector2(b - rr, yb - 20.0), ROUILLE, 14.0)
	# sangles
	for x in [a + rr + 40.0, (a + b) / 2.0, b - rr - 40.0]:
		_rect_u(x - 12.0, yh - 4.0, x + 12.0, yb + 4.0, ACIER.darkened(0.25))
	# trou d'homme, passerelle et échelle arrière
	_rect_u((a + b) / 2.0 - 45.0, yh - 34.0, (a + b) / 2.0 + 45.0, yh + 4.0, ACIER_C)
	_ligne_u(Vector2(a + 60.0, yh - 50.0), Vector2(b - 60.0, yh - 50.0), ACIER.darkened(0.2), 6.0)
	for x in range(int(a + 80.0), int(b - 60.0), 120):
		_ligne_u(Vector2(x, yh - 50.0), Vector2(x, yh + 6.0), ACIER.darkened(0.2), 5.0)
	_ligne_u(Vector2(a - 4.0, yh + 30.0), Vector2(a - 4.0, r + 30.0), ACIER_C, 6.0)
	_ligne_u(Vector2(a - 34.0, yh + 30.0), Vector2(a - 34.0, r + 30.0), ACIER_C, 6.0)
	var y := yh + 60.0
	while y < r + 30.0:
		_ligne_u(Vector2(a - 34.0, y), Vector2(a - 4.0, y), ACIER_C, 5.0)
		y += 50.0
	# vanne de vidange
	_rect_u(a + 30.0, yb - 10.0, a + 70.0, yb + 30.0, ROUILLE)


func _benne(x0: float, x1: float, r: float) -> void:
	var h := 220.0
	var yh := r - 26.0 - h
	# chargement d'épaves qui dépasse : roue, poutres tordues, portière, tôle
	draw_circle(pu(x0 + 220.0, yh + 10.0), 85.0 * k(), _c(Color("#2A2522")))
	draw_circle(pu(x0 + 220.0, yh + 10.0), 40.0 * k(), _c(ROUILLE))
	_ligne_u(Vector2(x0 + 360.0, yh + 40.0), Vector2(x0 + 560.0, yh - 110.0), ACIER.darkened(0.2), 22.0)
	_ligne_u(Vector2(x0 + 560.0, yh - 110.0), Vector2(x0 + 640.0, yh - 60.0), ACIER.darkened(0.2), 22.0)
	draw_colored_polygon(PackedVector2Array([pu(x1 - 380.0, yh + 20.0), pu(x1 - 330.0, yh - 120.0), pu(x1 - 170.0, yh - 90.0),
		pu(x1 - 150.0, yh + 20.0)]), _c(Color("#5E6A70")))
	draw_colored_polygon(PackedVector2Array([pu(x1 - 330.0, yh - 100.0), pu(x1 - 220.0, yh - 85.0), pu(x1 - 230.0, yh - 40.0),
		pu(x1 - 330.0, yh - 50.0)]), _c(Color("#1E2224")))   # vitre de portière
	_ligne_u(Vector2(x0 + 700.0, yh + 30.0), Vector2(x0 + 760.0, yh - 70.0), ROUILLE, 30.0)
	# caisse d'acier avec nervures
	_rect_u(x0, yh, x1, r - 10.0, ACIER)
	var x := x0 + 90.0
	while x < x1 - 20.0:
		_rect_u(x - 10.0, yh, x + 10.0, r - 10.0, ACIER_C, false)
		x += 120.0
	_rect_u(x0 - 6.0, yh - 14.0, x1 + 6.0, yh + 10.0, ACIER.darkened(0.25))
	_ligne_u(Vector2(x0, r - 60.0), Vector2(x1, r - 60.0), ROUILLE, 16.0)
	# vérin de bennage
	_ligne_u(Vector2(x1 - 160.0, r + 40.0), Vector2(x1 - 90.0, r - 10.0), Color("#8A8A80"), 16.0)
	# charnière arrière
	draw_circle(pu(x0 + 14.0, r - 4.0), 14.0 * k(), _c(ACIER.darkened(0.3)))


func _grue(x0: float, x1: float, r: float) -> void:
	_plancher(x0, x1, r)
	# épave lourde posée sur le plateau (silhouette de voiture sans roues)
	if charge_grue:
		var a := x0 + 70.0
		var b := minf(x1 - 260.0, a + 950.0)
		var y := r - 26.0
		var corps := PackedVector2Array([pu(a, y), pu(a, y - 150.0), pu(a + 0.18 * (b - a), y - 170.0), pu(a + 0.32 * (b - a), y - 300.0),
			pu(a + 0.62 * (b - a), y - 300.0), pu(a + 0.76 * (b - a), y - 175.0), pu(b, y - 150.0), pu(b, y)])
		draw_colored_polygon(corps, _c(Color("#4E4A3E")))
		draw_polyline(corps, _c(NOIR), maxf(1.0, 3.0 * k()))
		draw_colored_polygon(PackedVector2Array([pu(a + 0.36 * (b - a), y - 280.0), pu(a + 0.58 * (b - a), y - 280.0),
			pu(a + 0.68 * (b - a), y - 180.0), pu(a + 0.3 * (b - a), y - 180.0)]), _c(Color("#1C1E1E")))
		_ligne_u(Vector2(a + 40.0, y - 70.0), Vector2(b - 40.0, y - 70.0), ROUILLE, 20.0)
		# sangles
		for x in [a + 0.25 * (b - a), a + 0.75 * (b - a)]:
			_ligne_u(Vector2(x, y), Vector2(x + 30.0, y - 160.0), Color("#C9A15A"), 7.0)
	# tourelle et flèche, inclinée vers l'arrière
	var base := Vector2(x1 - 110.0, r - 26.0)
	_rect_u(base.x - 90.0, base.y - 110.0, base.x + 90.0, base.y, ACIER)
	_rivets(base.x - 80.0, base.x + 80.0, base.y - 95.0, 32.0)
	var piv := base + Vector2(0.0, -150.0)
	var bout := Vector2(x0 + 280.0, r - 620.0)
	_ligne_u(base + Vector2(-60.0, -110.0), piv, ACIER.darkened(0.2), 34.0)
	_ligne_u(base + Vector2(60.0, -110.0), piv, ACIER.darkened(0.2), 34.0)
	# flèche en treillis
	var dirv := (bout - piv).normalized()
	var nrm := Vector2(-dirv.y, dirv.x) * 26.0
	_ligne_u(piv + nrm, bout + nrm * 0.5, ACIER, 14.0)
	_ligne_u(piv - nrm, bout - nrm * 0.5, ACIER, 14.0)
	var n := 9
	for i in n:
		var t0 := float(i) / n
		var t1 := float(i + 1) / n
		var a0 := piv.lerp(bout, t0) + nrm * lerpf(1.0, 0.5, t0)
		var b1 := piv.lerp(bout, t1) - nrm * lerpf(1.0, 0.5, t1)
		_ligne_u(a0, b1, ACIER_C, 6.0)
	# vérin de levage
	_ligne_u(base + Vector2(-20.0, -60.0), piv.lerp(bout, 0.35), Color("#8A8A80"), 18.0)
	# câble et crochet
	var croc := Vector2(bout.x, r - 300.0)
	_ligne_u(bout, croc, Color("#2A2A28"), 4.0)
	draw_arc(pu(croc.x, croc.y + 22.0), 22.0 * k(), -PI * 0.1, PI * 1.1, 10, _c(ACIER_C), maxf(1.0, 7.0 * k()))
	draw_circle(pu(bout.x, bout.y), 18.0 * k(), _c(ACIER.darkened(0.3)))
	# stabilisateurs arrière : descendent jusqu'au sol à l'arrêt
	var y_sol := BerlietConfig.sol()
	for x in [x0 + 40.0]:
		var bas := lerpf(r + 40.0, y_sol, stabilisateurs)
		_rect_u(x - 14.0, r, x + 14.0, bas, ACIER.darkened(0.15))
		_rect_u(x - 40.0, bas - 12.0, x + 40.0, bas, ACIER.darkened(0.3))


func _troupes(x0: float, x1: float, r: float) -> void:
	_plancher(x0, x1, r)
	# soldats assis sur deux bancs (dos à dos), vus de profil
	var places := 6 if x1 - x0 > 900.0 else 4
	var pas := (x1 - x0 - 120.0) / places
	for i in places:
		var x := x0 + 80.0 + pas * (i + 0.5)
		var pied := pu(x, r - 26.0 - 110.0)
		Silhouette.dessiner(self, pied, ppm, "tireur" if i % 2 == 0 else "survivant",
			{"assis": true, "miroir": i % 2 == 1, "peau": i, "h": 0.55})
	# bancs
	_rect_u(x0 + 60.0, r - 140.0, x1 - 40.0, r - 120.0, BOIS)
	# ridelles basses et arceaux de bâche (bâche roulée à l'avant)
	_ridelle(x0, x1, r - 150.0, r - 26.0, 38.0, 6.0)
	var x := x0 + 40.0
	while x < x1 - 20.0:
		draw_arc(pu(x + 130.0, r - 150.0), 130.0 * k(), PI, TAU, 12, _c(ACIER_C), maxf(1.0, 7.0 * k()))
		x += 260.0
	_rect_u(x1 - 70.0, r - 300.0, x1 - 10.0, r - 150.0, Color("#6B6A4A"))   # bâche roulée


func _ridelles_hautes(x0: float, x1: float, r: float) -> void:
	_plancher(x0, x1, r)
	var yh := r - 26.0 - 330.0
	# vivres qui dépassent : cageots et fruits, légumes
	var x := x0 + 40.0
	var i := 0
	var couleurs := [Color("#C0662A"), Color("#8DA046"), Color("#A83A2C"), Color("#D2A43A"), Color("#5E7A3A")]
	while x < x1 - 60.0:
		var hc := 60.0 + 30.0 * float(i % 3)
		_rect_u(x, yh - hc + 40.0, x + 110.0, yh + 40.0, BOIS_C.lightened(0.1))
		for j in 4:
			draw_circle(pu(x + 18.0 + 25.0 * j, yh - hc + 30.0), 17.0 * k(), _c(couleurs[(i + j) % couleurs.size()]))
		x += 130.0
		i += 1
	_ridelle(x0, x1, yh, r - 26.0, 46.0, 12.0)
	_tablier(x1, r)


# Hauteur (u) du haut du module : pour placer une caméra ou des effets
func haut_module_u() -> float:
	var r := BerlietConfig.rail(config)
	match String(config.module):
		"citerne": return r - 400.0
		"benne": return r - 380.0
		"grue": return r - 650.0
		"troupes": return r - 300.0
		"ridelles": return r - 420.0
	return r
