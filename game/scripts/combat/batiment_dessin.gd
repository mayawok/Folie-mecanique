# Bâtiment ennemi en formes simples (ferme, hangar, bunker), avec ses tireurs aux fenêtres
# et des dégâts visibles. Lit directement l'état du modèle (CombatModele.Bat).
# L'origine du dessin est le coin haut gauche ; le sol est en bas du contrôle.
class_name BatimentDessin
extends Control

var bat: CombatModele.Bat
var ppm := 36.0


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE


func _process(_d: float) -> void:
	queue_redraw()


func _poly(pts: Array, c: Color, W: float, H: float) -> void:
	var p := PackedVector2Array()
	for q in pts:
		p.append(Vector2(q[0] * W, q[1] * H))
	draw_colored_polygon(p, c)
	p.append(p[0])
	draw_polyline(p, c.darkened(0.5), maxf(1.0, ppm * 0.04), true)


func _rect(x0: float, y0: float, x1: float, y1: float, c: Color, W: float, H: float) -> void:
	draw_rect(Rect2(Vector2(x0 * W, y0 * H), Vector2((x1 - x0) * W, (y1 - y0) * H)), c)


func _draw() -> void:
	if bat == null:
		return
	var W := bat.longueur * ppm
	var H := bat.hauteur * ppm
	var ruine := not bat.actif()
	var teinte := 0.55 if ruine else 1.0
	var sombre := Color("#241E18")
	var fenetre_y := 0.62
	match bat.type:
		"ferme":
			_poly([[0.04, 0.40], [0.04, 1.0], [0.96, 1.0], [0.96, 0.40]], Color("#8E7650") * Color(teinte, teinte, teinte), W, H)
			_poly([[0.0, 0.42], [0.5, 0.05 if not ruine else 0.22], [1.0, 0.42]], Color("#6A4A36") * Color(teinte, teinte, teinte), W, H)
			_rect(0.44, 0.66, 0.56, 1.0, sombre, W, H)
			fenetre_y = 0.58
		"hangar":
			var arc := []
			for i in 13:
				arc.append([0.02 + 0.96 * i / 12.0, 0.32 - 0.24 * sin(PI * i / 12.0) * (0.5 if ruine else 1.0)])
			_poly([[0.02, 1.0], [0.02, 0.32]] + arc + [[0.98, 0.32], [0.98, 1.0]], Color("#7A7468") * Color(teinte, teinte, teinte), W, H)
			_rect(0.34, 0.52, 0.66, 1.0, Color("#3A352E"), W, H)
			fenetre_y = 0.46
		"bunker":
			_poly([[0.0, 1.0], [0.07, 0.32], [0.93, 0.32], [1.0, 1.0]], Color("#8A8780") * Color(teinte, teinte, teinte), W, H)
			_rect(0.10, 0.50, 0.90, 0.64, sombre, W, H)
			fenetre_y = 0.64
	# Fenêtres et tireurs
	var n := bat.tireurs.size()
	for i in n:
		var cx := W * (i + 1.0) / (n + 1.0)
		if bat.type != "bunker":
			draw_rect(Rect2(Vector2(cx - 0.55 * ppm, fenetre_y * H - 0.55 * ppm), Vector2(1.1 * ppm, 1.0 * ppm)), sombre)
		if bat.tireurs[i].pv > 0.0:
			Silhouette.dessiner(self, Vector2(cx, fenetre_y * H + 0.25 * ppm), ppm, "pillard",
				{"assis": true, "h": 0.5, "miroir": true, "peau": i + bat.uid, "bras": "vise"})
	# Dégâts : fissures, trous, gravats
	var dmg := 1.0 - bat.pv / bat.pv_max
	var r := RandomNumberGenerator.new()
	r.seed = bat.uid
	for i in 9:
		var seuil := (i + 1) / 10.0
		var px := r.randf_range(0.08, 0.92) * W
		var py := r.randf_range(0.45, 0.95) * H
		if dmg > seuil * 0.8:
			draw_circle(Vector2(px, py), ppm * r.randf_range(0.18, 0.4), Color(0.1, 0.08, 0.07, 0.85))
			draw_line(Vector2(px, py), Vector2(px + r.randf_range(-1, 1) * ppm, py - r.randf_range(0.3, 1.0) * ppm), sombre, maxf(1.0, ppm * 0.05))
	if ruine:
		for i in 8:
			var gx := r.randf_range(0.0, 1.0) * W
			draw_circle(Vector2(gx, H - r.randf_range(0.05, 0.3) * ppm), ppm * r.randf_range(0.25, 0.6), Color("#5A5046"))
