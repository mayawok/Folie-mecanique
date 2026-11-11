# Petit indicateur du HUD (DEC-232) : rapport engagé, compte-tours, mode de conduite (urgence), démarreur.
class_name IndicateurRapport
extends Control

const C_FOND := Color(0.055, 0.05, 0.04, 0.72)
const C_BORD := Color("#E8A33D")
const C_GRIS := Color("#7A756B")
const C_ROUGE := Color("#E2483A")
const SEGMENTS := 14

var rapport := 1
var nb := 5
var regime := 0.0
var urgence := false
var demarreur := false
var allume := false


func _ready() -> void:
	custom_minimum_size = Vector2(420, 56)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func maj(T: Dictionary) -> void:
	var r := int(T.rapport)
	var g := float(T.regime)
	var u := bool(T.urgence)
	var d := float(T.demarreur) > 0.0
	var a := bool(T.moteur_on)
	if r != rapport or nb != int(T.nb) or u != urgence or d != demarreur or a != allume or absf(g - regime) > 0.02:
		rapport = r
		nb = int(T.nb)
		regime = g
		urgence = u
		demarreur = d
		allume = a
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), C_FOND)
	draw_rect(Rect2(Vector2.ZERO, size), C_BORD if allume else C_GRIS, false, 2.0)
	var f := get_theme_default_font()
	var col := C_BORD if allume else C_GRIS
	draw_string(f, Vector2(14, size.y * 0.5 + 16), str(rapport) if allume else "–", HORIZONTAL_ALIGNMENT_LEFT, -1, 44, col)
	draw_string(f, Vector2(52, size.y * 0.5 + 14), "/ %d" % nb, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, C_GRIS)
	var x0 := 108.0
	var larg := (size.x - x0 - 150.0) / SEGMENTS
	var plein := int(round(regime / 1.0 * SEGMENTS)) if allume else 0
	for i in SEGMENTS:
		var c := C_BORD
		if i >= SEGMENTS - 3:
			c = C_ROUGE
		if i >= plein:
			c = Color(c.r, c.g, c.b, 0.18)
		draw_rect(Rect2(x0 + i * larg, 14, larg - 4.0, size.y - 28.0), c)
	var txt := ""
	if demarreur:
		txt = Textes.t("trans.demarreur")
	elif urgence:
		txt = Textes.t("trans.urgence")
	elif not allume:
		txt = Textes.t("trans.coupe")
	if txt != "":
		draw_string(f, Vector2(size.x - 144.0, size.y * 0.5 + 8), txt, HORIZONTAL_ALIGNMENT_LEFT, 140, 20, C_ROUGE if urgence else C_BORD)
