# Désert procédural qui défile (menu principal, garage) : ciel, dunes lointaines
# en parallaxe, sol bosselé avec cailloux. Terrain.sol(x) donne le relief en mètres,
# lu aussi par les véhicules pour leurs suspensions.
class_name Terrain
extends Control

var camera_x := 0.0     # position du monde (m) au point d'ancrage
var ppm := 55.0
var sol_y := 900.0      # ligne du sol (px) pour une hauteur nulle
var ancre_x := 0.0      # abscisse écran (px) qui correspond à camera_x


static func sol(x: float) -> float:
	var h := 0.07 * sin(x * 0.55) + 0.05 * sin(x * 1.7 + 1.3) + 0.02 * sin(x * 4.1)
	# Cailloux tous les 9 m environ
	var k := floorf(x / 9.0)
	var c := k * 9.0 + 4.5 + 3.0 * sin(k * 12.9898)
	var d := (x - c) / 0.35
	h += 0.16 * exp(-d * d) * (0.5 + 0.5 * absf(sin(k * 78.233)))
	return h


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
	var haut := Color("#7FA6BF")
	var horizon := Color("#E9CFA0")
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, sol_y), Vector2(0, sol_y)]),
		PackedColorArray([haut, haut, horizon, horizon]))
	draw_circle(Vector2(w * 0.78, sol_y * 0.28), 70, Color(1.0, 0.95, 0.82, 0.85))
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
