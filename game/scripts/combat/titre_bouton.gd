# Bouton de l'écran d'accueil (DEC-088) : plaque d'acier d'atelier dessinée par le code.
# Dégradé d'acier, bord rouillé, quatre rivets, éclats de rouille propres à chaque bouton, liseré rouge
# comme le titre ; au survol la plaque s'éclaire d'une lueur de lampe, à l'appui elle s'enfonce.
class_name TitreBouton
extends Button

const ACIER_HAUT := Color(0.30, 0.25, 0.20)
const ACIER_BAS := Color(0.15, 0.12, 0.10)
const ROUILLE := Color(0.62, 0.27, 0.12)
const ROUGE := Color(0.72, 0.17, 0.10)
const CREME := Color(0.96, 0.89, 0.74)

var _plaque: Control
var _lueur := 0.0
var _eclats: Array = []


func _ready() -> void:
	flat = true
	for etat in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(etat, StyleBoxEmpty.new())
	var f := FontVariation.new()
	f.base_font = load("res://assets/fonts/Inter-Bold.otf")
	f.spacing_glyph = 3
	add_theme_font_override("font", f)
	add_theme_font_size_override("font_size", 30)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		add_theme_color_override(c, CREME)
	add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02, 0.9))
	add_theme_constant_override("outline_size", 6)
	text = text.to_upper()
	# éclats de rouille : toujours les mêmes pour un même bouton
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(text)
	for i in 14:
		var bord := rng.randi_range(0, 3)   # haut, bas, gauche, droite
		_eclats.append({"bord": bord, "t": rng.randf(), "r": rng.randf_range(0.03, 0.14), "a": rng.randf_range(0.25, 0.6)})
	_plaque = Control.new()
	_plaque.show_behind_parent = true
	_plaque.mouse_filter = MOUSE_FILTER_IGNORE
	_plaque.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_plaque.draw.connect(_dessiner)
	add_child(_plaque)


func _process(d: float) -> void:
	if not is_visible_in_tree():
		return
	var cible := 1.0 if (is_hovered() or has_focus()) and not disabled else 0.0
	_lueur = move_toward(_lueur, cible, d * 5.0)
	_plaque.queue_redraw()


func _dessiner() -> void:
	var enfonce := get_draw_mode() == DRAW_PRESSED or get_draw_mode() == DRAW_HOVER_PRESSED
	var w := size.x
	var h := size.y
	var dy := 2.0 if enfonce else 0.0
	var r := Rect2(Vector2(0, dy), Vector2(w, h - 3.0))
	# ombre portée sous la plaque
	if not enfonce:
		_plaque.draw_rect(Rect2(Vector2(2, 4), Vector2(w - 2, h - 3)), Color(0, 0, 0, 0.45))
	# acier : dégradé vertical en bandes fines
	var n := 18
	for i in n:
		var u := float(i) / float(n - 1)
		var c := ACIER_HAUT.lerp(ACIER_BAS, u)
		if enfonce:
			c = c.darkened(0.25)
		c = c.lerp(Color(0.55, 0.32, 0.12), _lueur * 0.35 * (1.0 - u * 0.5))
		_plaque.draw_rect(Rect2(r.position + Vector2(0, r.size.y * u), Vector2(r.size.x, r.size.y / n + 1.0)), Color(c.r, c.g, c.b, 0.93))
	# éclats de rouille sur les bords
	for e in _eclats:
		var p := Vector2.ZERO
		var rayon: float = e.r * h
		match e.bord:
			0: p = r.position + Vector2(e.t * w, 0)
			1: p = r.position + Vector2(e.t * w, r.size.y)
			2: p = r.position + Vector2(0, e.t * r.size.y)
			_: p = r.position + Vector2(w, e.t * r.size.y)
		_plaque.draw_circle(p, rayon, Color(ROUILLE.r, ROUILLE.g, ROUILLE.b, e.a))
	# bord : filet clair en haut, sombre en bas, cadre rouille
	_plaque.draw_rect(r, Color(0.04, 0.03, 0.02, 0.95), false, 3.0)
	_plaque.draw_rect(r.grow(-3.0), ROUILLE.lerp(Color(1.0, 0.7, 0.3), _lueur), false, 1.5)
	_plaque.draw_line(r.position + Vector2(4, 4), r.position + Vector2(w - 4, 4), Color(1, 0.9, 0.7, 0.18), 1.5)
	# liseré rouge à gauche (même rouge que le titre)
	_plaque.draw_rect(Rect2(r.position + Vector2(8, 10), Vector2(6, r.size.y - 20)), ROUGE)
	# rivets
	for cx in [18.0, w - 18.0]:
		for cy in [r.position.y + 12.0, r.position.y + r.size.y - 12.0]:
			_plaque.draw_circle(Vector2(cx, cy) + Vector2(1, 1.5), 5.0, Color(0, 0, 0, 0.55))
			_plaque.draw_circle(Vector2(cx, cy), 5.0, Color(0.36, 0.31, 0.26))
			_plaque.draw_circle(Vector2(cx - 1.5, cy - 1.5), 2.0, Color(0.78, 0.7, 0.58, 0.8))
	# lueur chaude de lampe au survol
	if _lueur > 0.01:
		_plaque.draw_rect(r.grow(-1.0), Color(1.0, 0.72, 0.32, 0.16 * _lueur), true)
