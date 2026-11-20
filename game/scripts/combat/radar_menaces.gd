class_name RadarMenaces
extends Control
# Radar des menaces (DEC-258) : une barre fine, notre convoi au centre ; devant à droite, derrière à gauche.
# Ennemis (rouge), alliés (vert), ville (blanc), champ de mines (orange) ; au-delà de la portée, le repère reste au bord.

const PORTEE := 140.0   # mètres affichés de chaque côté
var vue: Control        # ConvoiVue


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if vue == null or vue.m == null or vue.m.convoi.is_empty():
		return
	var m: CombatModele = vue.m
	var w := size.x
	var h := size.y
	var r := Rect2(0, 0, w, h)
	draw_rect(r, Color(0.04, 0.045, 0.05, 0.62))
	draw_rect(r, Color(1, 1, 1, 0.14), false, 1.0)
	var cy := h * 0.5
	var xq: float = 1e9
	for v in m.convoi:
		xq = minf(xq, v.x)
	var xt: float = m.x_tete
	# graduations tous les 50 m
	for k in range(-2, 3):
		var gx := w * 0.5 + float(k) * 50.0 / PORTEE * (w * 0.5)
		draw_line(Vector2(gx, cy - 4), Vector2(gx, cy + 4), Color(1, 1, 1, 0.12), 1.0)
	# notre convoi : trait épais entre l'arrière et la tête
	var a := clampf(w * 0.5 + (xq - xt) / PORTEE * (w * 0.5), 8.0, w * 0.5)
	draw_rect(Rect2(a, cy - 3, w * 0.5 - a + 2.0, 6), Color(0.37, 0.7, 0.42, 0.95))
	var f := ThemeDB.fallback_font
	for e in m.ennemis:
		if not e.actif():
			continue
		var d: float = (e.x + e.longueur * 0.5) - xt
		var hors: bool = absf(d) > PORTEE
		var px := clampf(w * 0.5 + d / PORTEE * (w * 0.5), 10.0, w - 10.0)
		var col := Color("#5FB36B") if e.allie else Color("#E04B3A")
		var s := 8.0
		var sens := 1.0 if d >= 0.0 else -1.0
		if hors:   # chevron au bord : la menace arrive
			draw_colored_polygon(PackedVector2Array([Vector2(px + sens * s, cy), Vector2(px - sens * s * 0.4, cy - s), Vector2(px - sens * s * 0.4, cy + s)]), Color(col, 0.7))
		else:
			draw_colored_polygon(PackedVector2Array([Vector2(px, cy - s), Vector2(px + s, cy + s * 0.8), Vector2(px - s, cy + s * 0.8)]), col)
	var proches := {-1: 1e9, 1: 1e9}   # menace hostile la plus proche de chaque côté : sa distance s'affiche
	for e in m.ennemis:
		if e.actif() and not e.allie:
			var dd: float = (e.x + e.longueur * 0.5) - xt
			var cote := 1 if dd >= 0.0 else -1
			proches[cote] = minf(proches[cote], absf(dd))
	for cote in [-1, 1]:
		if proches[cote] < 1e8:
			var ax: float = w * 0.5 + float(cote) * (w * 0.5 - 56.0) - 24.0
			draw_string(ThemeDB.fallback_font, Vector2(ax, h - 6.0), "%d m" % int(proches[cote]), HORIZONTAL_ALIGNMENT_CENTER, 48.0, 14, Color("#F2B8B0"))
	if m.ville_active() and m.ville_phase() != "fin":
		var dv: float = float(m.ville.x0) - xt
		var pv := clampf(w * 0.5 + dv / PORTEE * (w * 0.5), 10.0, w - 10.0)
		draw_rect(Rect2(pv - 6, cy - 6, 12, 12), Color(0.95, 0.95, 0.9, 0.95))
		draw_rect(Rect2(pv - 6, cy - 6, 12, 12), Color(0, 0, 0, 0.6), false, 1.0)
	var c: Dictionary = m.champ_devant()
	if not c.is_empty():
		var dm: float = float(c.x0) - xt
		var pm := clampf(w * 0.5 + dm / PORTEE * (w * 0.5), 10.0, w - 10.0)
		draw_colored_polygon(PackedVector2Array([Vector2(pm, cy - 9), Vector2(pm + 9, cy), Vector2(pm, cy + 9), Vector2(pm - 9, cy)]), Color("#E8A33D"))
	draw_string(f, Vector2(8, h - 6), "◄", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.35))
	draw_string(f, Vector2(w - 22, h - 6), "►", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.35))
