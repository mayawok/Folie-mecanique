# Désert procédural qui défile (menu principal, garage) : ciel, dunes lointaines
# en parallaxe, sol bosselé avec cailloux. Terrain.sol(x) donne le relief en mètres,
# lu aussi par les véhicules pour leurs suspensions.
class_name Terrain
extends Control

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


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)


func _process(_d: float) -> void:
	queue_redraw()


func ecran_x(xm: float) -> float:
	return ancre_x + (xm - camera_x) * ppm


func _draw() -> void:
	var w := size.x
	var hgt := size.y
	# Ciel en dégradé
	var haut := Color("#7FA6BF").lerp(Color("#070D1C"), nuit)
	var horizon := Color("#E9CFA0").lerp(Color("#2B2B48"), nuit)
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, sol_y), Vector2(0, sol_y)]),
		PackedColorArray([haut, haut, horizon, horizon]))
	if nuit > 0.2:
		for i in 70:
			draw_circle(Vector2(fposmod(i * 137.5 + 40.0, w), 20.0 + fposmod(i * 71.3, sol_y * 0.55)), 1.0 + 1.3 * alea(i, 11.0), Color(1, 1, 0.9, nuit * (0.4 + 0.5 * alea(i, 12.0))))
	draw_circle(Vector2(w * 0.78, sol_y * 0.28), 70 if nuit < 0.5 else 46, Color(1.0, 0.95, 0.82, 0.85).lerp(Color(0.85, 0.9, 1.0, 0.95), nuit))
	# Dunes en parallaxe (lointain -> proche)
	var couches := [[0.08, 0.62, 70.0, Color("#C9A57A")], [0.2, 0.74, 55.0, Color("#BC925F")], [0.45, 0.86, 40.0, Color("#B08452")]]
	for c in couches:
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
	while xv <= w + 24:
		var uu: float = floorf((camera_x * ppm * 0.12 + xv) / 24.0)
		var hh: float = 18.0 + 70.0 * alea(uu, 1.0) * (1.0 if alea(uu, 2.0) > 0.35 else 0.25)
		var yb: float = sol_y * 0.80 - 14.0
		ville.append(Vector2(xv, yb - hh))
		ville.append(Vector2(xv + 24, yb - hh * (0.5 + 0.5 * alea(uu, 3.0))))
		xv += 24
	ville.append(Vector2(w, hgt))
	draw_colored_polygon(ville, Color("#A88B6C"))
	# Nuages lents
	for i in 5:
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
	draw_colored_polygon(sol_pts, Color("#A87A4A"))
	draw_polyline(crete, Color("#8C6238"), 3.0, true)
	# Traces et cailloux de premier plan
	var m0 := floorf((camera_x - ancre_x / ppm) / 3.0)
	for i in int(w / ppm / 3.0) + 2:
		var k := m0 + i
		var xm2 := k * 3.0 + 1.5 * sin(k * 3.7)
		var px := ecran_x(xm2)
		var py := sol_y - sol(xm2) * ppm + 18 + 30 * absf(sin(k * 5.3))
		draw_circle(Vector2(px, py), 3 + 4 * absf(sin(k * 9.1)), Color("#7E5A34"))


	# Décor semé sur la route : poteaux, cactus, arbres morts, rochers, carcasses
	var k0 := floorf(camera_x - ancre_x / ppm - 4.0)
	var k1 := floorf(camera_x + (w - ancre_x) / ppm + 4.0)
	var pas := 11.0
	var kk := floorf(k0 / pas)
	while kk * pas <= k1:
		var xm3 := kk * pas + alea(kk, 6.0) * pas
		var r := alea(kk, 7.0)
		var pied := Vector2(ecran_x(xm3), sol_y - sol(xm3) * ppm)
		if r < 0.18:   # poteau télégraphique penché
			var hp := 4.6 * ppm
			draw_line(pied, pied + Vector2(0.15 * ppm, -hp), Color("#4A3828"), maxf(3.0, ppm * 0.12))
			draw_line(pied + Vector2(-0.7 * ppm, -hp * 0.93), pied + Vector2(0.9 * ppm, -hp * 0.95), Color("#4A3828"), maxf(2.0, ppm * 0.08))
		elif r < 0.38:   # cactus
			var hc := (1.2 + 1.2 * alea(kk, 8.0)) * ppm
			var cc := Color("#5F7A4A")
			draw_line(pied, pied + Vector2(0, -hc), cc, maxf(4.0, ppm * 0.28))
			draw_line(pied + Vector2(0, -hc * 0.45), pied + Vector2(-0.5 * ppm, -hc * 0.45), cc, maxf(3.0, ppm * 0.18))
			draw_line(pied + Vector2(-0.5 * ppm, -hc * 0.45), pied + Vector2(-0.5 * ppm, -hc * 0.8), cc, maxf(3.0, ppm * 0.18))
		elif r < 0.55:   # arbre mort
			var ha := (2.0 + 1.5 * alea(kk, 9.0)) * ppm
			var cb := Color("#3E2E22")
			draw_line(pied, pied + Vector2(0.1 * ppm, -ha), cb, maxf(3.0, ppm * 0.16))
			draw_line(pied + Vector2(0.1 * ppm, -ha * 0.6), pied + Vector2(0.9 * ppm, -ha * 0.95), cb, maxf(2.0, ppm * 0.08))
			draw_line(pied + Vector2(0.1 * ppm, -ha * 0.7), pied + Vector2(-0.8 * ppm, -ha * 1.0), cb, maxf(2.0, ppm * 0.08))
		elif r < 0.78:   # rochers
			for j in 3:
				draw_circle(pied + Vector2((j - 1) * 0.5 * ppm, 0.1 * ppm), (0.35 + 0.3 * alea(kk + j, 10.0)) * ppm, Color("#8A7358").darkened(0.1 * j))
		elif r < 0.86:   # carcasse de voiture rouillée
			var cr := Color("#6B4A3A")
			draw_rect(Rect2(pied + Vector2(-1.6 * ppm, -0.9 * ppm), Vector2(3.2 * ppm, 0.7 * ppm)), cr)
			draw_rect(Rect2(pied + Vector2(-0.8 * ppm, -1.5 * ppm), Vector2(1.7 * ppm, 0.6 * ppm)), cr.darkened(0.15))
			draw_circle(pied + Vector2(-1.0 * ppm, -0.2 * ppm), 0.35 * ppm, Color("#2A2622"))
			draw_circle(pied + Vector2(1.0 * ppm, -0.2 * ppm), 0.35 * ppm, Color("#2A2622"))
		kk += 1.0
	if nuit > 0.01:
		draw_rect(Rect2(Vector2(0, 0), size), Color(0.02, 0.04, 0.12, 0.5 * nuit))
