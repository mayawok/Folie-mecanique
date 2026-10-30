# Bâtiments en formes simples, d'allure européenne (maison de village, ferme, grange, église, bunker),
# avec leurs tireurs (ennemi) ou leur garnison (nous) aux fenêtres, des dégâts visibles et des ruines.
# Lit directement l'état du modèle (CombatModele.Bat). Origine du dessin : coin haut gauche ;
# le sol est en bas du contrôle. Les fenêtres suivent CombatModele.FENETRES (mêmes points que les tirs).
class_name BatimentDessin
extends Control

var bat: CombatModele.Bat
var ppm := 36.0


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE


func _process(_d: float) -> void:
	queue_redraw()


func _poly(pts: Array, c: Color, W: float, H: float, contour := true) -> void:
	var p := PackedVector2Array()
	for q in pts:
		p.append(Vector2(q[0] * W, q[1] * H))
	draw_colored_polygon(p, c)
	if contour:
		p.append(p[0])
		draw_polyline(p, c.darkened(0.45), maxf(1.0, ppm * 0.04), true)


func _rect(x0: float, y0: float, x1: float, y1: float, c: Color, W: float, H: float) -> void:
	draw_rect(Rect2(Vector2(x0 * W, y0 * H), Vector2((x1 - x0) * W, (y1 - y0) * H)), c)


# Fenêtre à arc (ogive pour l'église)
func _baie(cx: float, cy: float, w: float, h: float, c: Color, ogive := false) -> void:
	draw_rect(Rect2(Vector2(cx - w * 0.5, cy - h * 0.5 + w * 0.5), Vector2(w, h - w * 0.5)), c)
	if ogive:
		draw_colored_polygon(PackedVector2Array([Vector2(cx - w * 0.5, cy - h * 0.5 + w * 0.5), Vector2(cx, cy - h * 0.5 - w * 0.15), Vector2(cx + w * 0.5, cy - h * 0.5 + w * 0.5)]), c)
	else:
		draw_circle(Vector2(cx, cy - h * 0.5 + w * 0.5), w * 0.5, c)


func _draw() -> void:
	if bat == null:
		return
	var W := bat.longueur * ppm
	var H := bat.hauteur * ppm
	var ruine := not bat.actif()
	var t := 0.6 if ruine else 1.0
	var T := Color(t, t, t)
	var sombre := Color("#241E18")
	var dmg := 1.0 - bat.pv / bat.pv_max
	match bat.type:
		"ferme":   # murs de pierre, toit de tuiles à quatre pans, porte cintrée
			_poly([[0.03, 0.55], [0.03, 1.0], [0.97, 1.0], [0.97, 0.55]], Color("#B5A27C") * T, W, H)
			_poly([[0.0, 0.57], [0.18, 0.20], [0.82, 0.20], [1.0, 0.57]] if not ruine else [[0.0, 0.57], [0.2, 0.40], [0.5, 0.50], [0.82, 0.30], [1.0, 0.57]], Color("#A24F34") * T, W, H)
			_poly([[0.18, 0.20], [0.5, 0.0], [0.82, 0.20]] if not ruine else [[0.2, 0.40], [0.3, 0.30], [0.5, 0.50]], Color("#8C4430") * T, W, H)
			_rect(0.72, 0.05, 0.78, 0.30, Color("#6E6A62") * T, W, H)   # cheminée
			_baie(W * 0.5, H * 0.86, W * 0.12, H * 0.34, sombre, false)
		"maison":   # maison de village à étage, toit d'ardoise à forte pente, volets
			_poly([[0.06, 0.44], [0.06, 1.0], [0.94, 1.0], [0.94, 0.44]], Color("#CFC2A4") * T, W, H)
			_poly([[0.0, 0.46], [0.5, 0.0], [1.0, 0.46]] if not ruine else [[0.0, 0.46], [0.3, 0.2], [0.55, 0.34], [0.8, 0.14], [1.0, 0.46]], Color("#4C5560") * T, W, H)
			_rect(0.74, 0.04, 0.82, 0.24, Color("#7A5A48") * T, W, H)   # cheminée de brique
			_rect(0.06, 0.44, 0.94, 0.47, Color("#8F8268") * T, W, H)   # corniche
			_baie(W * 0.5, H * 0.88, W * 0.16, H * 0.24, Color("#4A3322") * T, false)
			for fx in [0.3, 0.7]:
				for fy in [0.55, 0.80]:
					if ruine:
						continue
					_rect(fx - 0.11, fy - 0.06, fx - 0.07, fy + 0.07, Color("#5F7A5A") * T, W, H)   # volets verts
					_rect(fx + 0.07, fy - 0.06, fx + 0.11, fy + 0.07, Color("#5F7A5A") * T, W, H)
		"grange":   # grande grange de pierre, toit en bâtière, grand portail de bois
			_poly([[0.02, 0.50], [0.02, 1.0], [0.98, 1.0], [0.98, 0.50]], Color("#A8987A") * T, W, H)
			_poly([[0.0, 0.52], [0.5, 0.0], [1.0, 0.52]] if not ruine else [[0.0, 0.52], [0.25, 0.25], [0.5, 0.40], [1.0, 0.52]], Color("#8E4A36") * T, W, H)
			_poly([[0.38, 1.0], [0.38, 0.68], [0.5, 0.58], [0.62, 0.68], [0.62, 1.0]], Color("#4E3A28") * T, W, H)
			draw_line(Vector2(W * 0.5, H * 0.60), Vector2(W * 0.5, H), sombre, maxf(1.0, ppm * 0.05))
		"eglise":   # nef à contreforts + clocher à flèche, baies en ogive, rosace
			var nef_h := 0.52
			_poly([[0.04, nef_h], [0.04, 1.0], [0.66, 1.0], [0.66, nef_h]], Color("#B9B1A0") * T, W, H)
			_poly([[0.02, nef_h + 0.02], [0.35, nef_h - 0.2], [0.68, nef_h + 0.02]] if not ruine else [[0.02, nef_h + 0.02], [0.2, nef_h - 0.08], [0.4, nef_h + 0.02]], Color("#5A5E66") * T, W, H)
			for bx in [0.04, 0.35, 0.66]:   # contreforts
				_rect(bx - 0.012, nef_h + 0.02, bx + 0.02, 1.0, Color("#9C9484") * T, W, H)
			for wx in [0.14, 0.26, 0.45, 0.56]:
				_baie(W * wx, H * 0.80, W * 0.045, H * 0.22, Color("#2A3340") * T, true)
			draw_circle(Vector2(W * 0.35, H * 0.62), W * 0.03, Color("#5A4E70") * T)   # rosace
			# Clocher
			_poly([[0.66, 1.0], [0.66, 0.30], [0.96, 0.30], [0.96, 1.0]], Color("#C4BCAA") * T, W, H)
			_rect(0.66, 0.30, 0.96, 0.33, Color("#9C9484") * T, W, H)
			if not ruine or dmg < 0.9:
				_poly([[0.64, 0.31], [0.81, 0.0], [0.98, 0.31]] if not ruine else [[0.64, 0.31], [0.74, 0.17], [0.80, 0.28], [0.86, 0.2], [0.98, 0.31]], Color("#4C5560") * T, W, H)
			_baie(W * 0.81, H * 0.40, W * 0.07, H * 0.20, sombre, true)   # baie du beffroi
			draw_circle(Vector2(W * 0.81, H * 0.55), W * 0.032, Color("#E6DFC8") * T)   # horloge
			_baie(W * 0.81, H * 0.92, W * 0.07, H * 0.18, Color("#3E2C1E") * T, true)   # portail
		"bunker":
			_poly([[0.0, 1.0], [0.07, 0.32], [0.93, 0.32], [1.0, 1.0]], Color("#8A8780") * T, W, H)
			_rect(0.10, 0.50, 0.90, 0.64, sombre, W, H)
	# Fenêtres de tir : ennemi (pillard) ou nos survivants embusqués
	var fen: Array = CombatModele.FENETRES.get(bat.type, [])
	for i in fen.size():
		var f: Array = fen[i]
		var px: float = W * float(f[0])
		var py: float = H * (1.0 - float(f[1]))
		if bat.type != "bunker" and bat.type != "eglise":
			draw_rect(Rect2(Vector2(px - 0.5 * ppm, py - 0.55 * ppm), Vector2(1.0 * ppm, 1.1 * ppm)), sombre)
		if not ruine and i < bat.tireurs.size() and bat.tireurs[i].pv > 0.0:
			Silhouette.dessiner(self, Vector2(px, py + 0.5 * ppm), ppm, "pillard",
				{"assis": true, "h": 0.5, "miroir": true, "peau": i + bat.uid, "bras": "vise"})
	if ruine and bat.revele_t > 0.0:   # embusqués : visibles seulement quand ils viennent de tirer
		for g in bat.garnison:
			if g.pv > 0.0 and g.slot < fen.size():
				var f2: Array = fen[g.slot]
				if bat.type != "bunker" and bat.type != "eglise":
					draw_rect(Rect2(Vector2(W * f2[0] - 0.5 * ppm, H * (1.0 - f2[1]) - 0.55 * ppm), Vector2(1.0 * ppm, 1.1 * ppm)), sombre)
				Silhouette.dessiner(self, Vector2(W * f2[0], H * (1.0 - f2[1]) + 0.5 * ppm), ppm, "survivant",
					{"assis": true, "h": 0.5, "miroir": false, "peau": g.slot + 2, "bras": "vise"})
	# Dégâts : trous, fissures, gravats
	var r := RandomNumberGenerator.new()
	r.seed = bat.uid
	for i in 9:
		var seuil := (i + 1) / 10.0
		var px2 := r.randf_range(0.08, 0.92) * W
		var py2 := r.randf_range(0.5, 0.95) * H
		if dmg > seuil * 0.8:
			draw_circle(Vector2(px2, py2), ppm * r.randf_range(0.18, 0.4), Color(0.1, 0.08, 0.07, 0.85))
			draw_line(Vector2(px2, py2), Vector2(px2 + r.randf_range(-1, 1) * ppm, py2 - r.randf_range(0.3, 1.0) * ppm), sombre, maxf(1.0, ppm * 0.05))
	if ruine:
		for i in 10:
			var gx := r.randf_range(0.0, 1.0) * W
			draw_circle(Vector2(gx, H - r.randf_range(0.05, 0.3) * ppm), ppm * r.randf_range(0.25, 0.6), Color("#5A5046"))
