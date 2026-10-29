# Personnages en formes simples (silhouettes 1940), dessinés par le code.
# Silhouette.dessiner() sert aussi aux équipages dans les véhicules.
# Utilisation seule : var p := Silhouette.new(); p.variante = "pillard"; p.pose = "marche"
class_name Silhouette
extends Control

const PEAUX := ["#C99A74", "#A87653", "#E0B58F", "#7E5539"]

# tenue, pantalon, coiffe, accessoire, foulard éventuel
const VARIANTES := {
	"survivant":  {"nom": "Survivant",  "tenue": "#6B5D45", "bas": "#4A4136", "coiffe": "calot", "objet": ""},
	"survivante": {"nom": "Survivante", "tenue": "#7A6A4F", "bas": "#4F4538", "coiffe": "cheveux", "objet": ""},
	"mecano":     {"nom": "Mécano",     "tenue": "#47525A", "bas": "#47525A", "coiffe": "casquette", "objet": "cle"},
	"tireur":     {"nom": "Tireur",     "tenue": "#555A35", "bas": "#4A4E2E", "coiffe": "casque", "objet": "fusil"},
	"eclaireur":  {"nom": "Éclaireur",  "tenue": "#8A7656", "bas": "#5C5040", "coiffe": "bonnet", "objet": "", "foulard": "#A08D6A"},
	"chef":       {"nom": "Chef",       "tenue": "#5A4A3A", "bas": "#3E352C", "coiffe": "chapeau", "objet": "", "manteau": true},
	"pillard":    {"nom": "Pillard",    "tenue": "#3A3330", "bas": "#2E2926", "coiffe": "foulard", "objet": "fusil", "foulard": "#8C2F25"},
}

var variante := "survivant"
var pose := "debout"        # debout | marche
var ppm := 55.0
var peau := 0
var miroir := false
var phase := 0.0


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0.9, 2.0) * ppm


func _process(delta: float) -> void:
	if pose == "marche":
		phase += delta * 7.0
		queue_redraw()


func _draw() -> void:
	dessiner(self, Vector2(size.x / 2, size.y), ppm, variante,
		{"phase": phase if pose == "marche" else 0.0, "miroir": miroir, "peau": peau})


# pied : point au sol (ou au siège si opts.assis) en pixels écran.
# opts : assis, h (hauteur du buste en m), phase, miroir, peau, bras ("vise" ou "")
static func dessiner(ci: CanvasItem, pied: Vector2, s: float, var_id: String, opts := {}) -> void:
	var v: Dictionary = VARIANTES.get(var_id, VARIANTES.survivant)
	var dir := -1.0 if opts.get("miroir", false) else 1.0
	var assis: bool = opts.get("assis", false)
	var ph: float = opts.get("phase", 0.0)
	var tenue := Color(v.tenue)
	var bas := Color(v.bas)
	var peau := Color(PEAUX[int(opts.get("peau", 0)) % PEAUX.size()])
	var contour := Color(0.08, 0.07, 0.06, 0.9)
	var hanche := pied
	# Jambes
	if not assis:
		hanche = pied + Vector2(0, -0.86 * s)
		for k in 2:
			var a := sin(ph + PI * k) * 0.42 if ph != 0.0 else (0.06 if k == 0 else -0.06)
			var genou := hanche + Vector2(sin(a) * 0.43 * s * dir, cos(a) * 0.43 * s)
			var b := a - absf(sin(ph + PI * k)) * 0.35 if ph != 0.0 else a
			var p := genou + Vector2(sin(b) * 0.43 * s * dir, cos(b) * 0.43 * s)
			var c := bas.darkened(0.15 * k)
			ci.draw_line(hanche, genou, c, 0.13 * s)
			ci.draw_line(genou, p, c, 0.12 * s)
			ci.draw_rect(Rect2(p + Vector2(-0.05 * s, -0.05 * s), Vector2(0.17 * s, 0.07 * s)), Color("#2A231C"))
	# Buste (trapèze), manteau plus long
	var h: float = opts.get("h", 0.58) * s
	var bas_buste := hanche + Vector2(0, 0.12 * s if v.get("manteau", false) and not assis else 0.0)
	var epaule := hanche + Vector2(0, -h)
	var buste := PackedVector2Array([
		bas_buste + Vector2(-0.16 * s, 0), bas_buste + Vector2(0.16 * s, 0),
		epaule + Vector2(0.18 * s, 0.04 * s), epaule + Vector2(-0.17 * s, 0.04 * s)])
	ci.draw_colored_polygon(buste, tenue)
	ci.draw_polyline(buste + PackedVector2Array([buste[0]]), contour, 1.5)
	# Bras
	var bras: String = opts.get("bras", "")
	var ep := epaule + Vector2(0.02 * s * dir, 0.08 * s)
	if bras == "vise":
		ci.draw_line(ep, ep + Vector2(0.42 * s * dir, 0.02 * s), tenue.darkened(0.2), 0.10 * s)
	else:
		var ab := sin(ph + PI) * 0.5 if ph != 0.0 else 0.15
		ci.draw_line(ep, ep + Vector2(sin(ab) * 0.5 * s * dir, cos(ab) * 0.5 * s), tenue.darkened(0.2), 0.10 * s)
		var main := ep + Vector2(sin(ab) * 0.5 * s * dir, cos(ab) * 0.5 * s)
		if v.objet == "cle" and not assis:
			ci.draw_line(main, main + Vector2(0.18 * s * dir, 0.12 * s), Color("#8A8A86"), 0.05 * s)
	if v.objet == "fusil" and bras != "vise" and not assis:
		ci.draw_line(epaule + Vector2(-0.18 * s * dir, -0.1 * s), hanche + Vector2(0.14 * s * dir, 0.2 * s), Color("#3B2E22"), 0.06 * s)
	if v.has("foulard"):
		ci.draw_rect(Rect2(epaule + Vector2(-0.12 * s, -0.02 * s), Vector2(0.24 * s, 0.09 * s)), Color(v.foulard))
	# Tête
	var tete := epaule + Vector2(0.02 * s * dir, -0.15 * s)
	var r := 0.115 * s
	ci.draw_circle(tete, r, peau)
	_coiffe(ci, v, tete, r, s, dir)


static func _coiffe(ci: CanvasItem, v: Dictionary, t: Vector2, r: float, s: float, dir: float) -> void:
	var sombre := Color(v.tenue).darkened(0.35)
	match v.coiffe:
		"casque":
			ci.draw_colored_polygon(_demi_disque(t + Vector2(0, -0.01 * s), r * 1.25), Color("#4E5230"))
			ci.draw_line(t + Vector2(-r * 1.4, -0.01 * s), t + Vector2(r * 1.4, -0.01 * s), Color("#3E4126"), 0.03 * s)
		"calot":
			ci.draw_colored_polygon(PackedVector2Array([t + Vector2(-r, -r * 0.6), t + Vector2(r * 0.9, -r * 0.6),
				t + Vector2(r * 0.6, -r * 1.25), t + Vector2(-r * 0.8, -r * 1.1)]), sombre)
		"casquette":
			ci.draw_colored_polygon(_demi_disque(t + Vector2(0, -r * 0.3), r * 1.02), sombre)
			ci.draw_line(t + Vector2(0, -r * 0.3), t + Vector2(r * 1.6 * dir, -r * 0.2), sombre, 0.03 * s)
		"bonnet":
			ci.draw_colored_polygon(_demi_disque(t + Vector2(0, -r * 0.1), r * 1.12), Color("#5B4532"))
			ci.draw_line(t + Vector2(-r * 0.2 * dir, -r * 0.45), t + Vector2(r * 1.05 * dir, -r * 0.45), Color("#B8B09A"), 0.045 * s)
		"chapeau":
			ci.draw_line(t + Vector2(-r * 1.7, -r * 0.55), t + Vector2(r * 1.7, -r * 0.55), Color("#3A2E24"), 0.04 * s)
			ci.draw_rect(Rect2(t + Vector2(-r * 0.85, -r * 1.35), Vector2(r * 1.7, r * 0.8)), Color("#3A2E24"))
		"cheveux":
			ci.draw_colored_polygon(_demi_disque(t + Vector2(0, -r * 0.05), r * 1.08), Color("#3B2A1E"))
			ci.draw_circle(t + Vector2(-r * 1.0 * dir, -r * 0.2), r * 0.42, Color("#3B2A1E"))
		"foulard":
			ci.draw_colored_polygon(_demi_disque(t + Vector2(0, -r * 0.05), r * 1.15), Color("#4A3A2C"))
			ci.draw_rect(Rect2(t + Vector2(-r, r * 0.05), Vector2(r * 2.05, r * 0.85)), Color(v.get("foulard", "#8C2F25")))
			ci.draw_line(t + Vector2(-r * 0.3 * dir, -r * 0.3), t + Vector2(r * 1.1 * dir, -r * 0.3), Color("#1E1E1E"), 0.05 * s)


static func _demi_disque(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 13:
		var a := PI + PI * i / 12.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts
