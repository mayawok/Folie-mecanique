# Bouton de marche unique (DEC-160), design du 10/11 : grand panneau en verre fumé ambre.
# Au centre, le témoin de frein à main : gris quand le convoi roule, rouge quand il est à l'arrêt (frein serré).
# À gauche deux chevrons vers la gauche (reculer), à droite deux chevrons vers la droite (avancer).
# Dès qu'on commence à glisser, les chevrons du sens choisi s'étirent sur tout le bouton et l'autre côté s'efface ;
# tant que le convoi roule dans ce sens, ils continuent de défiler. Un simple toucher serre le frein (halte).
class_name BoutonMarche
extends Control

signal geste(dx: float)   # relâché : décalage horizontal en pixels (≈ 0 = simple toucher)

const SEUIL_PX := 40.0
const C_FOND := Color(0.055, 0.05, 0.04, 0.82)
const C_BORD := Color("#E8A33D")
const C_GRIS := Color("#7A756B")
const C_ROUGE := Color("#E2483A")
const C_FLECHE := Color("#E8A33D")

var etat := "halte"          # "halte" | "avancer" | "recul" (état réel du convoi)
var texte := ""              # étiquette particulière (en ville : « Repartir… »), remplace les chevrons
var disabled := false

var _x0 := -1.0
var _dx := 0.0
var _ouv := 0.0              # ouverture animée : -1 (tout à gauche) … 0 (repos) … 1 (tout à droite)
var _t := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(420, 112)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE


func _process(dt: float) -> void:
	_t += dt
	var cible := 0.0
	if _x0 >= 0.0:
		cible = clampf(_dx / SEUIL_PX, -1.0, 1.0)
	elif etat == "avancer":
		cible = 1.0
	elif etat == "recul":
		cible = -1.0
	_ouv = lerpf(_ouv, cible, minf(1.0, dt * 14.0))
	queue_redraw()


func _gui_input(ev: InputEvent) -> void:
	if disabled:
		return
	var presse: bool = (ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT) or ev is InputEventScreenTouch
	if presse:
		if ev.pressed:
			_x0 = ev.position.x
			_dx = 0.0
		elif _x0 >= 0.0:
			var dx: float = ev.position.x - _x0
			_x0 = -1.0
			_dx = 0.0
			accept_event()
			geste.emit(dx)
		return
	if _x0 >= 0.0 and (ev is InputEventMouseMotion or ev is InputEventScreenDrag):
		_dx = ev.position.x - _x0


func _draw() -> void:
	var w := size.x
	var h := size.y
	var a := 0.45 if disabled else 1.0
	var r := Rect2(Vector2.ZERO, size)
	# verre fumé et liseré ambre
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_FOND
	sb.set_corner_radius_all(int(h * 0.3))
	sb.border_color = Color(C_BORD, 0.85 * a)
	sb.set_border_width_all(3)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 6
	draw_style_box(sb, r)
	var cy := h * 0.5
	var ouv := absf(_ouv)
	var sens := 1.0 if _ouv >= 0.0 else -1.0
	# chevrons du côté non choisi : s'effacent
	var repos := 1.0 - ouv
	if texte == "":
		_paire(w * 0.17, cy, h, -1.0, Color(C_FLECHE, 0.9 * a * (repos if _ouv > 0.0 else 1.0)))
		_paire(w * 0.83, cy, h, 1.0, Color(C_FLECHE, 0.9 * a * (repos if _ouv < 0.0 else 1.0)))
	# chevrons du sens choisi : s'étirent sur tout le bouton et défilent
	if ouv > 0.02:
		var n := 6
		var pas := (w - h * 0.7) / float(n)
		for i in n:
			var k := fposmod(float(i) + _t * 1.8 * sens, float(n))
			var x0 := lerpf(w * 0.5, h * 0.35 + (k + 0.5) * pas, ouv)
			var al := (0.25 + 0.75 * (k / float(n) if sens > 0.0 else 1.0 - k / float(n))) * ouv * a
			_chevron(x0, cy, h * 0.3, sens, Color(C_FLECHE, al), h * 0.075)
	# témoin de frein à main au centre : ouvert (gris) ou serré (rouge) ; s'efface quand on glisse
	var serre := etat == "halte"
	var col := (C_ROUGE if serre else C_GRIS)
	col.a = a * (1.0 - clampf(ouv * 1.6, 0.0, 1.0))
	if col.a > 0.01 and texte == "":
		_frein(Vector2(w * 0.5, cy), h * 0.36, col, serre)
	if texte != "":
		var f := get_theme_default_font()
		var tz := f.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, int(h * 0.28))
		draw_string(f, Vector2((w - tz.x) * 0.5, cy + h * 0.1), texte, HORIZONTAL_ALIGNMENT_LEFT, -1, int(h * 0.28), Color(0.95, 0.93, 0.88, a))


# Deux chevrons côte à côte, pointant vers la gauche (sens −1) ou la droite (sens +1)
func _paire(cx: float, cy: float, h: float, sens: float, col: Color) -> void:
	var t := h * 0.3
	for i in 2:
		_chevron(cx + (i - 0.5) * h * 0.34 * sens, cy, t, sens, col, h * 0.075)


func _chevron(x: float, cy: float, t: float, sens: float, col: Color, ep: float) -> void:
	var pts := PackedVector2Array([Vector2(x - sens * t * 0.5, cy - t), Vector2(x + sens * t * 0.5, cy), Vector2(x - sens * t * 0.5, cy + t)])
	draw_polyline(pts, col, maxf(3.0, ep), true)


# Témoin de frein à main de voiture : cercle entouré de deux parenthèses, un « P » au milieu (rouge : serré)
func _frein(c: Vector2, r: float, col: Color, serre: bool) -> void:
	var ep := maxf(3.0, r * 0.14)
	if serre:
		draw_circle(c, r * 1.12, Color(col, col.a * 0.14))
	draw_arc(c, r * 0.66, 0.0, TAU, 40, col, ep, true)
	draw_arc(c, r * 1.0, deg_to_rad(125.0), deg_to_rad(235.0), 20, col, ep, true)    # parenthèse gauche
	draw_arc(c, r * 1.0, deg_to_rad(-55.0), deg_to_rad(55.0), 20, col, ep, true)     # parenthèse droite
	var f := get_theme_default_font()
	var tz := f.get_string_size("P", HORIZONTAL_ALIGNMENT_LEFT, -1, int(r * 0.95))
	draw_string(f, c + Vector2(-tz.x * 0.5, r * 0.33), "P", HORIZONTAL_ALIGNMENT_LEFT, -1, int(r * 0.95), col)
