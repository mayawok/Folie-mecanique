# Désert procédural qui défile (menu principal, garage) : ciel, dunes lointaines
# en parallaxe, sol bosselé avec cailloux. Terrain.sol(x) donne le relief en mètres,
# lu aussi par les véhicules pour leurs suspensions.
class_name Terrain
extends Control

# Type de sol (Kit, DEC-110) : sable, terre, cailloux ou eau. sol, crête, cailloux de premier plan, trois couches lointaines
static var zone := "terre"
const PALETTES := {
	"sable": {"sol": "#A87A4A", "crete": "#8C6238", "trace": "#7E5A34", "couches": ["#C9A57A", "#BC925F", "#B08452"],
		"decor": [["poteau", 0.18], ["cactus", 0.38], ["arbre", 0.55], ["rocher", 0.78], ["carcasse", 0.86]]},
	"terre": {"sol": "#6E5A3C", "crete": "#4F5B2E", "trace": "#54452C", "couches": ["#8E8A66", "#7B7C55", "#69703F"],
		"decor": [["poteau", 0.10], ["herbe", 0.50], ["arbre", 0.62], ["rocher", 0.72], ["carcasse", 0.78]]},
	"cailloux": {"sol": "#7A7570", "crete": "#5C5853", "trace": "#5A5651", "couches": ["#A7A29A", "#928D86", "#7E7973"],
		"decor": [["poteau", 0.08], ["rocher", 0.80], ["carcasse", 0.88]]},
	"eau": {"sol": "#4F6B73", "crete": "#9BBBC2", "trace": "#86A9B1", "couches": ["#9DB4BA", "#8AA3AA", "#738E96"],
		"decor": [["poteau", 0.20], ["roseau", 0.60], ["carcasse", 0.68]]},
}

# Images du décor « terre et herbe » (DEV-011) ; sans les fichiers, on retombe sur le dessin vectoriel.
# genre -> [fichier, hauteur réelle en m]
const ELEMENTS := {"poteau": ["poteau", 5.0], "herbe": ["buissons", 1.0], "arbre": ["arbre", 6.0], "rocher": ["rocher", 1.3],
	"cloture": ["cloture", 1.2], "muret": ["muret", 1.0], "ruine": ["ruine", 7.0], "clocher": ["clocher", 14.0], "chateau_eau": ["chateau_eau", 12.0]}
static var _tex := {}

var camera_x := 0.0     # position du monde (m) au point d'ancrage
var ppm := 55.0
var sol_y := 900.0      # ligne du sol (px) pour une hauteur nulle
var nuit := 0.0         # 0 = plein jour, 1 = pleine nuit
var ancre_x := 0.0      # abscisse écran (px) qui correspond à camera_x


# Collines : grandes ondulations (jusqu'à 15° de pente) ; le véhicule les suit en s'inclinant
static func relief(x: float) -> float:
	return 3.4 * sin(x / 46.0) + 2.0 * sin(x / 19.0 + 1.0) + 0.7 * sin(x / 8.0 + 2.0) - 3.4 * sin(0.0)


# Petites bosses et cailloux (secousses des suspensions)
static func bosses(x: float) -> float:
	var h := 0.07 * sin(x * 0.55) + 0.05 * sin(x * 1.7 + 1.3) + 0.02 * sin(x * 4.1)
	var k := floorf(x / 9.0)
	var c := k * 9.0 + 4.5 + 3.0 * sin(k * 12.9898)
	var d := (x - c) / 0.35
	h += 0.16 * exp(-d * d) * (0.5 + 0.5 * absf(sin(k * 78.233)))
	return h


static func sol(x: float) -> float:
	return relief(x) + bosses(x)


# Pente moyenne (m/m) sur 6 m autour de x : positive en montée
static func pente(x: float) -> float:
	return (relief(x + 3.0) - relief(x - 3.0)) / 6.0


# Pseudo-hasard stable pour semer le décor
static func alea(k: float, graine: float) -> float:
	return fposmod(sin(k * 127.1 + graine * 311.7) * 43758.5453, 1.0)


static func texture(nom: String) -> Texture2D:
	if not _tex.has(nom):
		var chemin := "res://assets/decor/%s.png" % nom
		_tex[nom] = load(chemin) if ResourceLoader.exists(chemin) else null
	return _tex[nom]


func _avec_images() -> bool:
	return zone == "terre" and texture("terre_ciel") != null and texture("terre_sol") != null


func _bande(nom: String, vit: float, bas: float) -> void:
	var t := texture(nom)
	var k := size.y / t.get_height()
	var lw := t.get_width() * k
	var x0 := -fposmod(camera_x * ppm * vit, lw)
	var teinte := Color.WHITE.lerp(Color(0.25, 0.3, 0.5), nuit)
	while x0 < size.x:
		draw_texture_rect(t, Rect2(x0, bas - size.y, lw + 1.0, size.y), false, teinte)
		if bas < size.y:   # vallée : on prolonge la dernière ligne de l'image vers le bas, plus de trou
			draw_texture_rect_region(t, Rect2(x0, bas, lw + 1.0, size.y - bas), Rect2(0, t.get_height() - 1, t.get_width(), 1), teinte)
		x0 += lw


func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)


func _process(_d: float) -> void:
	queue_redraw()


func ecran_x(xm: float) -> float:
	return ancre_x + (xm - camera_x) * ppm


func _draw() -> void:
	var w := size.x
	var hgt := size.y
	var img := _avec_images()
	var teinte := Color.WHITE.lerp(Color(0.25, 0.3, 0.5), nuit)
	if img:
		var g := relief(camera_x - ancre_x / ppm + w * 0.5 / ppm) * ppm   # les collines lointaines suivent un peu la vallée
		draw_texture_rect(texture("terre_ciel"), Rect2(0, 0, w, hgt), false, teinte)
		_bande("terre_lointain", 0.08, sol_y * 0.93 - g * 0.25)
		_bande("terre_moyen", 0.2, sol_y * 1.0 - g * 0.5)
	# Ciel en dégradé
	var haut := Color("#7FA6BF").lerp(Color("#070D1C"), nuit)
	var horizon := Color("#E9CFA0").lerp(Color("#2B2B48"), nuit)
	if not img:
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, sol_y), Vector2(0, sol_y)]),
			PackedColorArray([haut, haut, horizon, horizon]))
	if nuit > 0.2:
		for i in 70:
			draw_circle(Vector2(fposmod(i * 137.5 + 40.0, w), 20.0 + fposmod(i * 71.3, sol_y * 0.55)), 1.0 + 1.3 * alea(i, 11.0), Color(1, 1, 0.9, nuit * (0.4 + 0.5 * alea(i, 12.0))))
	if not img:
		draw_circle(Vector2(w * 0.78, sol_y * 0.28), 70 if nuit < 0.5 else 46, Color(1.0, 0.95, 0.82, 0.85).lerp(Color(0.85, 0.9, 1.0, 0.95), nuit))
	# Dunes en parallaxe (lointain -> proche)
	var pal: Dictionary = PALETTES[zone] if PALETTES.has(zone) else PALETTES.sable
	var cl: Array = pal.couches
	var couches := [[0.08, 0.62, 70.0, Color(cl[0])], [0.2, 0.74, 55.0, Color(cl[1])], [0.45, 0.86, 40.0, Color(cl[2])]]
	for c in (couches if not img else []):
		var pts := PackedVector2Array([Vector2(0, hgt)])
		var x := 0.0
		while x <= w + 20:
			var u: float = (camera_x * ppm * c[0] + x) / 300.0
			var y: float = sol_y * c[1] - c[2] * (0.6 * sin(u * 0.9) + 0.4 * sin(u * 2.1 + 2.0))
			pts.append(Vector2(x, y))
			x += 20
		pts.append(Vector2(w, hgt))
		draw_colored_polygon(pts, c[3])
	# Silhouette d'une ville en ruine, très loin
	var ville := PackedVector2Array([Vector2(0, hgt)])
	var xv := 0.0
	while xv <= w + 24 and not img:
		var uu: float = floorf((camera_x * ppm * 0.12 + xv) / 24.0)
		var hh: float = 18.0 + 70.0 * alea(uu, 1.0) * (1.0 if alea(uu, 2.0) > 0.35 else 0.25)
		var yb: float = sol_y * 0.80 - 14.0
		ville.append(Vector2(xv, yb - hh))
		ville.append(Vector2(xv + 24, yb - hh * (0.5 + 0.5 * alea(uu, 3.0))))
		xv += 24
	ville.append(Vector2(w, hgt))
	if not img:
		draw_colored_polygon(ville, Color(cl[0]).darkened(0.12))
	# Nuages lents
	for i in (5 if not img else 0):
		var cx := fposmod(i * 460.0 + 120.0 - camera_x * ppm * 0.03 - Time.get_ticks_msec() * 0.006 * (1 + i % 2), w + 400.0) - 200.0
		var cy := 60.0 + 38.0 * alea(i, 4.0) + i * 14.0
		for j in 4:
			draw_circle(Vector2(cx + j * 46.0, cy + 8.0 * sin(j * 1.7)), 30.0 + 8.0 * alea(i + j, 5.0), Color(1, 1, 1, 0.22))
	# Sol proche
	var sol_pts := PackedVector2Array([Vector2(0, hgt)])
	var crete := PackedVector2Array()
	var x2 := 0.0
	while x2 <= w + 8:
		var xm := camera_x + (x2 - ancre_x) / ppm
		var p := Vector2(x2, sol_y - sol(xm) * ppm)
		sol_pts.append(p)
		crete.append(p)
		x2 += 8
	sol_pts.append(Vector2(w, hgt))
	draw_colored_polygon(sol_pts, Color("#302510") if img else Color(pal.sol))
	if img:
		var ts := texture("terre_sol")
		var th := float(ts.get_height())
		var v0 := 0.74
		var recul := 0.9 * ppm   # la route commence derrière les roues : les véhicules roulent au milieu de la bande
		var prof := th * (1.0 - v0) + recul
		for i in range(crete.size() - 1):
			var a: Vector2 = crete[i]
			var b: Vector2 = crete[i + 1]
			var ua := (a.x + camera_x * ppm) / ts.get_width()
			var ub := (b.x + camera_x * ppm) / ts.get_width()
			draw_polygon(PackedVector2Array([a + Vector2(0, -recul), b + Vector2(0, -recul), b + Vector2(0, prof - recul), a + Vector2(0, prof - recul)]),
				PackedColorArray([teinte, teinte, teinte, teinte]),
				PackedVector2Array([Vector2(ua, v0), Vector2(ub, v0), Vector2(ub, 1.0), Vector2(ua, 1.0)]), ts)
	else:
		draw_polyline(crete, Color(pal.crete), 3.0, true)
	# Traces et cailloux de premier plan
	var m0 := floorf((camera_x - ancre_x / ppm) / 3.0)
	for i in int(w / ppm / 3.0) + 2:
		var k := m0 + i
		var xm2 := k * 3.0 + 1.5 * sin(k * 3.7)
		var px := ecran_x(xm2)
		var py := sol_y - sol(xm2) * ppm + 18 + 30 * absf(sin(k * 5.3))
		draw_circle(Vector2(px, py), 3 + 4 * absf(sin(k * 9.1)), Color(pal.trace))


	# Décor semé sur la route : poteaux, cactus, arbres morts, rochers, carcasses
	var k0 := floorf(camera_x - ancre_x / ppm - 4.0)
	var k1 := floorf(camera_x + (w - ancre_x) / ppm + 4.0)
	var pas := 11.0
	var kk := floorf(k0 / pas)
	while kk * pas <= k1:
		var xm3 := kk * pas + alea(kk, 6.0) * pas
		var r := alea(kk, 7.0)
		var pied := Vector2(ecran_x(xm3), sol_y - sol(xm3) * ppm)
		var genre := ""
		for dk in pal.decor:
			if r < float(dk[1]):
				genre = dk[0]
				break
		if img and ELEMENTS.has(genre):
			var te := texture("elem_" + String(ELEMENTS[genre][0]))
			var nom_e: String = ELEMENTS[genre][0]
			if genre == "arbre" and alea(kk, 16.0) > 0.5:
				te = texture("elem_arbre_mort")
				nom_e = "arbre_mort"
			if te != null:
				var hm: float = 5.0 if nom_e == "arbre_mort" else float(ELEMENTS[genre][1])
				var sc := hm * ppm / te.get_height()
				draw_texture_rect(te, Rect2(pied + Vector2(-te.get_width() * sc * 0.5, -te.get_height() * sc - 0.7 * ppm), te.get_size() * sc), false, teinte)
		elif genre == "poteau":   # poteau télégraphique penché
			var hp := 4.6 * ppm
			draw_line(pied, pied + Vector2(0.15 * ppm, -hp), Color("#4A3828"), maxf(3.0, ppm * 0.12))
			draw_line(pied + Vector2(-0.7 * ppm, -hp * 0.93), pied + Vector2(0.9 * ppm, -hp * 0.95), Color("#4A3828"), maxf(2.0, ppm * 0.08))
		elif genre == "cactus":
			var hc := (1.2 + 1.2 * alea(kk, 8.0)) * ppm
			var cc := Color("#5F7A4A")
			draw_line(pied, pied + Vector2(0, -hc), cc, maxf(4.0, ppm * 0.28))
			draw_line(pied + Vector2(0, -hc * 0.45), pied + Vector2(-0.5 * ppm, -hc * 0.45), cc, maxf(3.0, ppm * 0.18))
			draw_line(pied + Vector2(-0.5 * ppm, -hc * 0.45), pied + Vector2(-0.5 * ppm, -hc * 0.8), cc, maxf(3.0, ppm * 0.18))
		elif genre == "arbre":   # arbre mort
			var ha := (2.0 + 1.5 * alea(kk, 9.0)) * ppm
			var cb := Color("#3E2E22")
			draw_line(pied, pied + Vector2(0.1 * ppm, -ha), cb, maxf(3.0, ppm * 0.16))
			draw_line(pied + Vector2(0.1 * ppm, -ha * 0.6), pied + Vector2(0.9 * ppm, -ha * 0.95), cb, maxf(2.0, ppm * 0.08))
			draw_line(pied + Vector2(0.1 * ppm, -ha * 0.7), pied + Vector2(-0.8 * ppm, -ha * 1.0), cb, maxf(2.0, ppm * 0.08))
		elif genre == "rocher":
			for j in 3:
				draw_circle(pied + Vector2((j - 1) * 0.5 * ppm, 0.1 * ppm), (0.35 + 0.3 * alea(kk + j, 10.0)) * ppm, Color("#8A7358").darkened(0.1 * j))
		elif genre == "herbe":   # touffes d'herbe
			var cg := Color("#6C8A3C").darkened(0.2 * alea(kk, 13.0))
			for j in 6:
				var dx := (j - 2.5) * 0.18 * ppm
				draw_line(pied + Vector2(dx, 0), pied + Vector2(dx + (j - 2.5) * 0.06 * ppm, -(0.35 + 0.4 * alea(kk + j, 14.0)) * ppm), cg, maxf(2.0, ppm * 0.05))
		elif genre == "roseau":   # roseaux dans l'eau
			var cro := Color("#6F7F4A")
			for j in 4:
				var dx2 := (j - 1.5) * 0.2 * ppm
				draw_line(pied + Vector2(dx2, 0), pied + Vector2(dx2 + 0.1 * ppm, -(0.8 + 0.7 * alea(kk + j, 15.0)) * ppm), cro, maxf(2.0, ppm * 0.06))
			draw_line(pied + Vector2(-0.9 * ppm, 0.15 * ppm), pied + Vector2(0.9 * ppm, 0.15 * ppm), Color(1, 1, 1, 0.25), 2.0)
		elif genre == "carcasse":   # carcasse de voiture rouillée
			var cr := Color("#6B4A3A")
			draw_rect(Rect2(pied + Vector2(-1.6 * ppm, -0.9 * ppm), Vector2(3.2 * ppm, 0.7 * ppm)), cr)
			draw_rect(Rect2(pied + Vector2(-0.8 * ppm, -1.5 * ppm), Vector2(1.7 * ppm, 0.6 * ppm)), cr.darkened(0.15))
			draw_circle(pied + Vector2(-1.0 * ppm, -0.2 * ppm), 0.35 * ppm, Color("#2A2622"))
			draw_circle(pied + Vector2(1.0 * ppm, -0.2 * ppm), 0.35 * ppm, Color("#2A2622"))
		kk += 1.0
	if nuit > 0.01:
		draw_rect(Rect2(Vector2(0, 0), size), Color(0.02, 0.04, 0.12, 0.5 * nuit))
