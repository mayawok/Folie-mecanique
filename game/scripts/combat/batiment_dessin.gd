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


const COULEURS_FACTION := {1: "#3F78C8", 2: "#D6B13C", 3: "#C0392B"}


# Mât et drapeau de faction (couleur et numéro : on sait à qui appartient le camp avant d'arriver)
func _drapeau(fx: float, fy: float, h_mat: float, T: Color) -> void:
	var W := bat.longueur * ppm
	var H := bat.hauteur * ppm
	var base := Vector2(W * fx, H * 0.05 + h_mat)
	var haut := Vector2(W * fx, base.y - 2.4 * ppm)
	draw_line(base, haut, Color("#3A2E22"), maxf(2.0, ppm * 0.08))
	var col := Color(COULEURS_FACTION.get(bat.faction, "#888888")) * T
	var ond: float = 0.12 * ppm * sin(Time.get_ticks_msec() * 0.006)
	draw_colored_polygon(PackedVector2Array([haut, haut + Vector2(1.7 * ppm, 0.2 * ppm + ond), haut + Vector2(1.6 * ppm, 1.1 * ppm + ond), haut + Vector2(0, 1.0 * ppm)]), col)
	draw_string(ThemeDB.fallback_font, haut + Vector2(0.45 * ppm, 0.85 * ppm), str(bat.faction), HORIZONTAL_ALIGNMENT_LEFT, -1, int(ppm * 0.8), Color(0.05, 0.05, 0.05, 0.9))


func _draw() -> void:
	if bat == null:
		return
	var W := bat.longueur * ppm
	var H := bat.hauteur * ppm
	var ruine: bool = bat.statut == "neutralise"
	var t := 0.6 if ruine else 1.0
	var T := Color(t, t, t)
	var sombre := Color("#241E18")
	var dmg := 1.0 - bat.pv / bat.pv_max
	# Fondations : le bâtiment repose sur la pente
	var h0: float = Terrain.sol(bat.x + bat.longueur * 0.5)
	for i in 12:
		var fx: float = (i + 0.5) / 12.0
		var prof: float = (h0 - Terrain.sol(bat.x + fx * bat.longueur)) * ppm
		if prof > 0.0:
			draw_rect(Rect2(Vector2(fx * W - W / 24.0 - 1.0, H - 2.0), Vector2(W / 12.0 + 2.0, prof + 4.0)), Color("#7C7366") * T)
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
		"hangar":   # hangar de tôle : toit plat légèrement incliné, grande porte coulissante
			_poly([[0.0, 0.34], [0.0, 1.0], [1.0, 1.0], [1.0, 0.28]], Color("#7B8186") * T, W, H)
			_poly([[0.0, 0.34], [0.0, 0.22], [1.0, 0.16], [1.0, 0.28]], Color("#5A4A44") * T, W, H)
			_poly([[0.14, 1.0], [0.14, 0.50], [0.86, 0.46], [0.86, 1.0]], Color("#3E3A36") * T, W, H)
			for gx in [0.30, 0.46, 0.62, 0.78]:
				draw_line(Vector2(W * gx, H * 0.48), Vector2(W * gx, H), sombre, maxf(1.0, ppm * 0.05))
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
		"camp_pillard":   # palissade de rondins, tentes de toile, mirador, drapeau
			for k in 3:
				var tx: float = 0.18 + 0.27 * k
				_poly([[tx - 0.09, 0.62], [tx, 0.18 + 0.08 * k], [tx + 0.09, 0.62]] if not ruine else [[tx - 0.09, 0.62], [tx - 0.02, 0.45], [tx + 0.09, 0.62]], Color("#7C6B4C") * T, W, H)
			_rect(0.88, 0.1, 0.96, 0.66, Color("#5A4630") * T, W, H)   # mirador
			_rect(0.84, 0.06, 1.0, 0.16, Color("#4A3826") * T, W, H)
			for k2 in 22:
				var lx: float = 0.01 + k2 * 0.045
				_rect(lx, 0.55 + 0.03 * sin(k2 * 2.3), lx + 0.036, 1.0, Color("#6A5238") * T, W, H)
			_drapeau(0.5, 0.0, H * 0.02, T)
		"camp_fortifie":   # murs de sacs et de pierre, deux miradors, fil barbelé, drapeau
			_rect(0.0, 0.55, 1.0, 1.0, Color("#9A8E72") * T, W, H)
			for k3 in 16:
				draw_rect(Rect2(Vector2(W * (0.01 + k3 * 0.062), H * 0.52), Vector2(W * 0.05, H * 0.07)), Color("#B3A57E") * T)
			for tx2 in [0.02, 0.86]:
				_rect(tx2, 0.08, tx2 + 0.12, 0.6, Color("#6B5A44") * T, W, H)
				_poly([[tx2 - 0.02, 0.1], [tx2 + 0.06, 0.0], [tx2 + 0.14, 0.1]], Color("#3F4A40") * T, W, H)
			_rect(0.36, 0.34, 0.64, 0.56, Color("#7F7A6C") * T, W, H)   # casemate
			_rect(0.38, 0.40, 0.62, 0.46, sombre, W, H)
			for k4 in 8:
				draw_line(Vector2(W * (k4 * 0.125), H * 0.98), Vector2(W * (k4 * 0.125 + 0.06), H * 0.88), Color("#3A3A3A"), 1.5)
			_drapeau(0.5, 0.0, H * 0.34, T)
		"camp_ami":   # tentes vertes, feu de camp, clôture basse, drapeau
			for k5 in 3:
				var tx3: float = 0.16 + 0.3 * k5
				_poly([[tx3 - 0.12, 1.0], [tx3, 0.25 + 0.1 * k5], [tx3 + 0.12, 1.0]], Color("#5E7550").lightened(0.06 * k5), W, H)
				_rect(tx3 - 0.015, 0.7, tx3 + 0.015, 1.0, sombre, W, H)
			var fl: float = 0.7 + 0.3 * sin(Time.get_ticks_msec() * 0.012)
			draw_circle(Vector2(W * 0.5, H * 0.9), ppm * 0.4 * fl, Color(1.0, 0.55, 0.15, 0.9))
			draw_circle(Vector2(W * 0.5, H * 0.9), ppm * 1.4, Color(1.0, 0.55, 0.2, 0.15 * fl))
			draw_line(Vector2(0, H * 0.82), Vector2(W, H * 0.82), Color("#6A5238"), 3.0)
			_drapeau(0.5, 0.0, H * 0.04, T)
			for q in 2:
				Silhouette.dessiner(self, Vector2(W * (0.32 + 0.3 * q), H), ppm, "survivant", {"phase": 0.0, "miroir": q == 1, "peau": q + bat.uid})
		"bunker":
			_poly([[0.0, 1.0], [0.07, 0.32], [0.93, 0.32], [1.0, 1.0]], Color("#8A8780") * T, W, H)
			_rect(0.10, 0.50, 0.90, 0.64, sombre, W, H)
	# Fenêtres de tir : ennemi (pillard) ou nos survivants embusqués
	var fen: Array = CombatModele.FENETRES.get(bat.type, [])
	for i in fen.size():
		var f: Array = fen[i]
		var px: float = W * float(f[0])
		var py: float = H * (1.0 - float(f[1]))
		if bat.type != "bunker" and bat.type != "eglise" and not bat.type.begins_with("camp"):
			draw_rect(Rect2(Vector2(px - 0.5 * ppm, py - 0.55 * ppm), Vector2(1.0 * ppm, 1.1 * ppm)), sombre)
		if not ruine and i < bat.tireurs.size() and bat.tireurs[i].pv > 0.0:
			Silhouette.dessiner(self, Vector2(px, py + 0.5 * ppm), ppm, "pillard",
				{"assis": true, "h": 0.5, "miroir": true, "peau": i + bat.uid, "bras": "vise"})
	if ruine and bat.revele_t > 0.0:   # embusqués : visibles seulement quand ils viennent de tirer
		for g in bat.garnison:
			if g.pv > 0.0 and g.slot < fen.size():
				var f2: Array = fen[g.slot]
				if bat.type != "bunker" and bat.type != "eglise" and not bat.type.begins_with("camp"):
					draw_rect(Rect2(Vector2(W * f2[0] - 0.5 * ppm, H * (1.0 - f2[1]) - 0.55 * ppm), Vector2(1.0 * ppm, 1.1 * ppm)), sombre)
				Silhouette.dessiner(self, Vector2(W * f2[0], H * (1.0 - f2[1]) + 0.5 * ppm), ppm, "survivant",
					{"assis": true, "h": 0.5, "miroir": false, "peau": g.slot + 2, "bras": "vise"})
	# Feu allumé à l'intérieur (nuit) : lueur dans les ouvertures
	if bat.feu:
		var fl2: float = 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.013 + bat.uid)
		for i in fen.size():
			var f3: Array = fen[i]
			var gx2: float = W * float(f3[0])
			var gy2: float = H * (1.0 - float(f3[1]))
			draw_circle(Vector2(gx2, gy2), ppm * 1.6, Color(1.0, 0.55, 0.2, 0.13 * fl2))
			draw_rect(Rect2(Vector2(gx2 - 0.4 * ppm, gy2 - 0.45 * ppm), Vector2(0.8 * ppm, 0.9 * ppm)), Color(1.0, 0.7, 0.3, 0.85 * fl2))
	# Planches clouées aux ouvertures et à la porte
	if bat.barricade > 0.0:
		var nb: int = int(ceil(bat.barricade * 3.0))
		var portes := {"ferme": [0.5, 0.86], "maison": [0.5, 0.88], "grange": [0.5, 0.82], "hangar": [0.5, 0.80], "eglise": [0.81, 0.90]}
		var cibles: Array = []
		for f4 in fen:
			cibles.append([W * float(f4[0]), H * (1.0 - float(f4[1])), 0.55])
		if portes.has(bat.type):
			cibles.append([W * portes[bat.type][0], H * portes[bat.type][1], 0.9])
		for cb in cibles:
			for k6 in nb:
				var oy: float = (k6 - 1) * 0.36 * ppm
				var tilt: float = (0.12 if k6 % 2 == 0 else -0.1) * ppm
				draw_line(Vector2(cb[0] - cb[2] * ppm, cb[1] + oy + tilt), Vector2(cb[0] + cb[2] * ppm, cb[1] + oy - tilt), Color("#6E4E30"), maxf(3.0, ppm * 0.22))
				draw_circle(Vector2(cb[0] - cb[2] * ppm * 0.8, cb[1] + oy + tilt * 0.8), maxf(1.5, ppm * 0.05), Color("#2A2018"))
				draw_circle(Vector2(cb[0] + cb[2] * ppm * 0.8, cb[1] + oy - tilt * 0.8), maxf(1.5, ppm * 0.05), Color("#2A2018"))
		if bat.barricade_cible and bat.barricade < 1.0 and bat.garnison_vivants() > 0:   # un survivant cloue les planches
			Silhouette.dessiner(self, Vector2(W * 0.02 - 0.8 * ppm, H), ppm, "survivant", {"travaille": Time.get_ticks_msec() * 0.007, "peau": 1})
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
