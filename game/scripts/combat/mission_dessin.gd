# Scènes de départ en mission (DEC-145), dessinées par le code au-dessus des véhicules :
# bandes noires de cinéma, sous-titres et fondus ; pont roulant de l'atelier qui descend la cargaison sur le Berliet ;
# pilotes et passagers de l'escorte qui sortent les bras et les armes par les fenêtres en criant (DEC-165).
# Lit vue.m.mission, vue.m.ville (modele_mission.gd, modele_ville.gd).
class_name MissionDessin
extends Control

var vue
var _f: Font
var _style: StyleBoxFlat


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	visible = false
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_f = ThemeDB.fallback_font
	_style = StyleBoxFlat.new()
	_style.bg_color = Color("#F4EEDF")
	_style.border_color = Color("#2A2520")
	_style.set_border_width_all(2)
	_style.set_corner_radius_all(10)


func _process(_d: float) -> void:
	visible = vue != null and vue.m != null and vue.m.mission_active()
	if visible:
		queue_redraw()


func scene() -> bool:
	return vue.m.ville_phase() in ["chargement", "rassemblement"]


func _draw() -> void:
	var m = vue.m
	if m == null or not m.mission_active():
		return
	var ppm: float = vue.terrain.ppm
	var t: float = vue._temps
	var ph: String = m.ville_phase()
	if ph == "chargement":
		_pont_roulant(m, ppm)
	# l'escorte : fous debout sur les véhicules (plus excités pendant la scène et la sortie de la ville)
	var fete: bool = ph in ["rassemblement", "depart", "ouverture_s", "sortie"]
	var cris: Array = CombatModele.MD().cris
	var n := 0
	for uid in m.mission.escorte:
		var v = m.trouver(int(uid))
		if v == null or not v.actif():
			continue
		var x0: float = vue._rx(v)
		var moto: bool = v.longueur < 3.0
		var places := [0.45] if moto else [0.35, 0.7]
		for j in places.size():
			var xm: float = x0 + v.longueur * float(places[j])
			var h := 0.95 if moto else 1.15   # hauteur de la portière : assis, pas debout sur le toit
			var pied := Vector2(vue.terrain.ecran_x(xm), vue._sy(xm) - h * ppm)
			var tambour: bool = n == 0 and not moto
			_fou(pied, ppm * 0.95, t, float(uid) * 1.7 + j, fete, tambour)
			if fete and fposmod(t + float(uid) * 0.9 + j * 1.3, 3.0) < 1.1:
				_bulle(pied + Vector2(0, -1.9 * ppm), String(cris[(int(uid) * 3 + j + int(t / 3.0)) % cris.size()]))
			n += 1
	if scene():
		_cinema(m)


func _pont_roulant(m, ppm: float) -> void:
	var vp = m.vehicule_principal()
	if vp == null:
		return
	var x0v := float(m.ville.x0)
	var a := Vector2(vue.terrain.ecran_x(x0v + 30.0), vue._sy(x0v + 40.0) - 7.6 * ppm)
	var b := Vector2(vue.terrain.ecran_x(x0v + 48.0), a.y)
	draw_line(a, b, Color("#3A3632"), maxf(3.0, 0.3 * ppm))   # poutre du pont roulant
	var xc: float = vue._rx(vp) + vp.longueur * 0.33
	var chariot := Vector2(vue.terrain.ecran_x(xc), a.y)
	draw_rect(Rect2(chariot + Vector2(-0.6, -0.2) * ppm, Vector2(1.2, 0.6) * ppm), Color("#C9A43A"))
	var haut: float = vue._sy(xc) - (3.5 + float(m.mission_module_leve())) * ppm
	var crochet := Vector2(chariot.x, haut)
	draw_line(chariot + Vector2(0, 0.4 * ppm), crochet, Color("#1E1C1A"), maxf(1.5, 0.08 * ppm))
	for dx in [-2.2, 2.2]:   # élingues
		draw_line(crochet, crochet + Vector2(dx * ppm, 0.45 * ppm), Color("#2A2622"), maxf(1.0, 0.05 * ppm))
	draw_arc(crochet + Vector2(0, 0.15 * ppm), 0.18 * ppm, 0.0, PI, 8, Color("#C9A43A"), maxf(2.0, 0.08 * ppm))


# Escorte (DEC-165) : plus d'hommes peints debout sur les véhicules ; ce sont les pilotes et passagers, assis, qui sortent
# la tête, le bras et l'arme par la fenêtre (ou depuis la selle pour une moto) et l'agitent en criant.
func _fou(pied: Vector2, s: float, t: float, ph: float, fete: bool, _tambour: bool) -> void:
	var peau := Color("#B98A66")
	var veste := Color("#5B5A3E")
	var epaule := pied + Vector2(0, -0.15 * s)
	draw_line(pied + Vector2(0, 0.35 * s), epaule, veste, maxf(3.0, 0.32 * s))   # buste qui dépasse de la portière
	var tete := epaule + Vector2(0.05 * s, -0.22 * s)
	draw_circle(tete, 0.15 * s, peau)
	draw_arc(tete + Vector2(0, -0.03 * s), 0.16 * s, PI, TAU, 8, Color("#3B3326"), maxf(2.0, 0.09 * s))   # casquette ou calot
	draw_line(tete + Vector2(-0.08, -0.03) * s, tete + Vector2(0.12, -0.03) * s, Color("#2A2620"), maxf(1.5, 0.05 * s))   # lunettes de route
	var lever := 0.5 + 0.5 * sin(t * 4.0 + ph) if fete else 0.2
	var coude := epaule + Vector2(0.25 * s, (-0.1 - 0.25 * lever) * s)
	var main := coude + Vector2(0.15 * s, (-0.2 - 0.35 * lever) * s)
	draw_line(epaule, coude, veste, maxf(2.0, 0.12 * s))   # bras sorti par la fenêtre
	draw_line(coude, main, peau, maxf(2.0, 0.1 * s))
	var dir := Vector2(0.9, -0.35 - 0.5 * lever).normalized()
	draw_line(main - dir * 0.25 * s, main + dir * 0.75 * s, Color("#2A2420"), maxf(2.0, 0.09 * s))   # fusil ou pistolet-mitrailleur brandi


func _bulle(bas: Vector2, txt: String) -> void:
	var fs := 18
	var tz := _f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var r := Rect2(bas.x - tz.x * 0.5 - 10.0, bas.y - tz.y - 14.0, tz.x + 20.0, tz.y + 10.0)
	draw_colored_polygon(PackedVector2Array([Vector2(bas.x - 6, r.end.y - 1), Vector2(bas.x + 6, r.end.y - 1), Vector2(bas.x, bas.y)]), Color("#2A2520"))
	draw_style_box(_style, r)
	draw_string(_f, Vector2(r.position.x + 10.0, r.end.y - 8.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("#7A1E18"))


# Bandes noires, sous-titre, fondus au noir aux changements de plan
func _cinema(m) -> void:
	var M: Dictionary = CombatModele.MD()
	var bande := size.y * 0.11
	draw_rect(Rect2(0, 0, size.x, bande), Color.BLACK)
	draw_rect(Rect2(0, size.y - bande, size.x, bande), Color.BLACK)
	var st: String = m.mission_sous_titre()
	if st != "":
		draw_string(_f, Vector2(0, size.y - bande * 0.42), st, HORIZONTAL_ALIGNMENT_CENTER, size.x, 30, Color("#F0E6CC"))
	var t := float(m.ville.t)
	var duree := float(M.chargement_s) if m.ville_phase() == "chargement" else float(M.rassemblement_s)
	var noir := maxf(clampf(1.0 - t / 0.7, 0.0, 1.0), clampf((t - (duree - 0.7)) / 0.7, 0.0, 1.0) if m.ville_phase() == "chargement" else 0.0)
	if noir > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, noir))
