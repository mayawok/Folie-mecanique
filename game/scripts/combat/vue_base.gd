# Couche 0 de la vue du convoi : constantes, état de la vue, petites classes d'interface, outils.
# Chaîne : vue_base <- vue_dessin <- vue_interface <- convoi_vue (ConvoiVue).
extends Control

const SOL_Y := 700.0
var cam_h := 0.0                # hauteur du sol suivie par la caméra (m)
var _panneau_dial: PanelContainer
var _lbl_dial_titre: Label
var _lbl_dial_texte: Label
var _boite_dial: VBoxContainer
var _dial_sig := ""
var _camp_ferme := 0
var _lbl_camp: Label
var _lbl_nuit: Label
var _btn_nuit: Button
var _btn_mines: Button
var _btn_carte: Button
var _lbl_quete: Label
var _voile_carte: Control
var _carte_ctl: Control
var _carte_sel := -1
var _lbl_carte_info: Label
var _btn_partir: Button
var _pause_avant := false
var _amb_nom := ""
var _t_nuit := 10.0
var _btn_fouille: Button
var _btn_surv: Button
var _voile_surv: Control
var _liste_surv: VBoxContainer
var _pied_surv: VBoxContainer
var _surv_sel := {}
var _surv_sig := ""
var _pause_surv := false
var _look_x := 0.0
var _look_t := 0.0
var _pressing := false
var _drag := false
var _press := Vector2.ZERO
var _poussiere_veh := []        # {p, age} poussière soulevée par les roues
var _dernier_nuage := 0.0
const BARRE_H := 270.0
const DT := CombatModele.DT
const C_TEXTE := Color("#F2EEE6")
const C_DISCRET := Color("#A8A196")
const C_ACCENT := Color("#E8A33D")
const C_VERT := Color("#5FB36B")
const C_ORANGE := Color("#E0A03C")
const C_ROUGE := Color("#D9503F")
const C_FOND := Color(0.07, 0.075, 0.08, 0.86)
const CODES := {"chassis": "CHA", "roulement": "ROU", "suspension": "SUS", "moteur": "MOT", "cabine": "CAB"}
var m: CombatModele
var terrain: Terrain
var couche: Control
var fx: Control
var noeuds := {}                # uid -> VehiculeDessin ou BatimentDessin
var ppm := 34.0
var pause := false
var vitesse_sim := 1
var selection := 0
var graine := 1
var _acc := 0.0
var _tirs := []                 # (inutilisé : les balles viennent du modèle, m.projectiles)
var _poussieres := []           # {p, age} gerbes de terre des tirs manqués
var _ricochets := []            # {p, age} balles qui ricochent sur le blindage
var _panneau_alerte: PanelContainer
var _lbl_alerte: Label
var _btn_embuscade: Button
var _btn_sortir: Button
var _btn_camo: Button
var _etincelles := []           # {p: Vector2 (m), age}
var _explosions := []           # {p: Vector2 (m), age, taille}
var _bouffees := []             # {p: Vector2 (m), age} lueur de tir des tireurs
var _temps := 0.0
var _rng := RandomNumberGenerator.new()
var _t_son := {"mitrailleuse": 0.0, "impact": 0.0, "voix": -99.0}
var _alpha := 0.0               # fraction du pas de simulation écoulée (affichage fluide)
var ouvert := 0                 # uid du véhicule dont on consulte l'état
var _icones := []               # zones tactiles du panneau : {rect, uid, piece | action}
var _persos := []               # petits personnages qui vont fouiller ou réparer
var _audio_ok := false
var _marche_prec := "halte"
var _toggles := []              # {btn, getter, valeur}
var _cartes_sig := ""
var _boite_cartes: HBoxContainer
var _bande_actions: PanelContainer
var _bande_on := false          # menu du véhicule : visible seulement après un toucher sur un véhicule
var _ord: VBoxContainer
var _ord_t := 0.0               # temps restant d'affichage du bandeau d'ordres
var _btn_ordres: Button
var _btn_marche: Button
var _btn_garage: Button
var _save_t := 0.0
const SAVE_PATH := "user://convoi_save.json"
var _btn_feu: Button
var _btn_rep: Button
var _chips := {}
var _lbl_dist: Label
var _lbl_banniere: Label
var _lbl_journal: Array = []
var _n_journal := -1
var _btn_pause: Button
var _btns_vitesse := []
var _voile_fin: ColorRect
var _lbl_fin: Label
class Carte extends Button:
	var vue: ConvoiVue
	var uid := 0

	func _draw() -> void:
		var v = vue.m.trouver(uid)
		var f := get_theme_default_font()
		var sel := vue.selection == uid
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.07, 0.075, 0.08, 0.92))
		draw_rect(Rect2(Vector2.ZERO, size), ConvoiVue.C_ACCENT if sel else Color(1, 1, 1, 0.12), false, 4.0 if sel else 2.0)
		if v == null:
			return
		var rang := vue.m.convoi.find(v)
		draw_string(f, Vector2(14, 36), v.nom, HORIZONTAL_ALIGNMENT_LEFT, size.x - 28, 26, ConvoiVue.C_TEXTE)
		if rang >= 0:
			draw_string(f, Vector2(size.x - 50, 66), "n°%d" % (rang + 1), HORIZONTAL_ALIGNMENT_RIGHT, 40, 18, ConvoiVue.C_DISCRET)
		var q: float = v.pieces.chassis.pv / v.pieces.chassis.max
		draw_rect(Rect2(14, 54, size.x - 28, 10), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(14, 54, (size.x - 28) * q, 10), ConvoiVue.couleur_etat(q))
		for k in v.equipage.size():
			draw_circle(Vector2(26 + k * 28, 92), 9, ConvoiVue.C_VERT if v.equipage[k] > 0.0 else Color(0.3, 0.3, 0.3))
		var txt := "Feu libre" if v.tir else "Cessez-le-feu"
		var col2 := ConvoiVue.C_VERT if v.tir else ConvoiVue.C_ORANGE
		if not v.mobile():
			txt = "IMMOBILISÉ"
			col2 = ConvoiVue.C_ROUGE
		elif v.reparation:
			txt = "Réparation..."
			col2 = Color("#5AA9E6")
		draw_string(f, Vector2(14, 134), txt, HORIZONTAL_ALIGNMENT_LEFT, size.x - 28, 22, col2)

static func couleur_etat(q: float) -> Color:
	if q > 0.66:
		return C_VERT
	if q > 0.33:
		return C_ORANGE
	return C_ROUGE

static func code_piece(v: CombatModele.Veh, id: String) -> String:
	if id == "roulement":
		return "CHE" if v.chenille else "ROU"
	if id.begins_with("a"):
		var wid: String = v.profil.armes[int(id.substr(1))]
		return "CAN" if CombatModele.donnees().armes[wid].classe == "canon" else "MIT"
	return CODES[id]


# --- Construction ----------------------------------------------------------
class MondeJeuCouleurs:
	static func get_c(f: int) -> String:
		return {1: "#3F78C8", 2: "#D6B13C", 3: "#C0392B"}.get(f, "#888888")

class CarteMap extends Control:
	var vue
	var tex: Texture2D = load("res://assets/carte/carte_fond.png")

	func _zone() -> Rect2:
		var t := tex.get_size()
		var k: float = minf(size.x / t.x, size.y / t.y)
		var sz := t * k
		return Rect2((size - sz) * 0.5, sz)

	func _pt(s: Dictionary) -> Vector2:
		var z := _zone()
		return z.position + Vector2(s.pos.x * z.size.x, s.pos.y * z.size.y)

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			var meilleur := -1
			var d_min := 46.0
			for s in vue.m.monde.secteurs:
				var d: float = _pt(s).distance_to(e.position)
				if d < d_min:
					d_min = d
					meilleur = s.id
			vue._carte_sel = meilleur
			queue_redraw()

	func _draw() -> void:
		var z := _zone()
		draw_texture_rect(tex, z, false)
		draw_rect(z, Color(0, 0, 0, 0.18))
		var w = vue.m.monde
		var f := ThemeDB.fallback_font
		var cour: Dictionary = w.secteurs[w.secteur]
		var cible := -1
		if w.en_transit():
			cible = w.trajet.dest
		elif vue._carte_sel >= 0:
			cible = vue._carte_sel
		if cible >= 0 and cible != w.secteur:
			draw_dashed_line(_pt(cour), _pt(w.secteurs[cible]), Color(1, 0.9, 0.5, 0.9), 4.0, 14.0)
		for s in w.secteurs:
			var p := _pt(s)
			var dif: float = clampf(float(s.niveau) / 7.0, 0.0, 1.0)
			var anneau := Color(0.4, 0.85, 0.4).lerp(Color(0.9, 0.2, 0.15), dif)
			var fac := Color(MondeJeuCouleurs.get_c(s.faction))
			draw_circle(p, 22.0, Color(0, 0, 0, 0.6))
			draw_circle(p, 18.0, anneau)
			draw_circle(p, 12.0, fac)
			if s.id == vue._carte_sel:
				draw_arc(p, 28.0, 0.0, TAU, 32, Color.WHITE, 3.0)
			if s.id == w.secteur:
				draw_colored_polygon(PackedVector2Array([p + Vector2(0, -44), p + Vector2(10, -28), p + Vector2(-10, -28)]), Color.WHITE)
			draw_string(f, p + Vector2(-80, 46), s.nom, HORIZONTAL_ALIGNMENT_CENTER, 160, 22, Color(0, 0, 0, 0.9))
			draw_string(f, p + Vector2(-81, 45), s.nom, HORIZONTAL_ALIGNMENT_CENTER, 160, 22, Color("#F6F0DC"))
			draw_string(f, p + Vector2(-20, 4), str(s.faction), HORIZONTAL_ALIGNMENT_CENTER, 40, 18, Color(0.05, 0.05, 0.05))

class FxVue extends Control:
	var vue: ConvoiVue

	func _draw() -> void:
		vue.dessiner_fx(self)

	func _process(_d: float) -> void:
		queue_redraw()

func _theme() -> Theme:
	var t := Theme.new()
	t.default_font = load("res://assets/fonts/Inter-Medium.otf")
	t.default_font_size = 26
	for etat in ["normal", "hover", "pressed", "disabled", "focus"]:
		var s := StyleBoxFlat.new()
		s.set_corner_radius_all(14)
		s.set_content_margin_all(12)
		s.bg_color = {"normal": Color("#2E302F"), "hover": Color("#3A3C3A"), "pressed": C_ACCENT, "disabled": Color("#1E1F1E"), "focus": Color(0, 0, 0, 0)}[etat]
		if etat == "focus":
			s.draw_center = false
		t.set_stylebox(etat, "Button", s)
	t.set_color("font_color", "Button", C_TEXTE)
	t.set_color("font_hover_color", "Button", C_TEXTE)
	t.set_color("font_pressed_color", "Button", Color("#1A1A18"))
	t.set_color("font_disabled_color", "Button", C_DISCRET)
	t.set_font_size("font_size", "Button", 26)
	t.set_font_size("font_size", "Label", 26)
	return t

func _panneau(parent: Node, fond := C_FOND) -> PanelContainer:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = fond
	s.set_corner_radius_all(0)
	s.set_content_margin_all(14)
	p.add_theme_stylebox_override("panel", s)
	parent.add_child(p)
	return p

func _bouton(texte: String, action: Callable, parent: Node, largeur := 0.0) -> Button:
	var b := Button.new()
	b.text = texte
	b.custom_minimum_size = Vector2(largeur, 64)
	b.pressed.connect(action)
	b.pressed.connect(func(): _demarrer_audio(); _son("sfx_ui_clic", -6.0))
	parent.add_child(b)
	return b

func _label(texte: String, parent: Node, taille := 26, couleur := C_TEXTE) -> Label:
	var l := Label.new()
	l.text = texte
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", couleur)
	parent.add_child(l)
	return l

func _rangee(parent: Node, titre: String, options: Array, getter: Callable, setter: Callable, large := 150.0) -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	parent.add_child(hb)
	var l := _label(titre, hb, 22, C_DISCRET)
	l.custom_minimum_size = Vector2(110, 0)
	var groupe := ButtonGroup.new()
	for o in options:
		var b := Button.new()
		b.text = o[0]
		b.toggle_mode = true
		b.button_group = groupe
		b.custom_minimum_size = Vector2(large, 56)
		b.add_theme_font_size_override("font_size", 22)
		var val: String = o[1]
		b.pressed.connect(func(): setter.call(val); _demarrer_audio(); _son("sfx_ui_clic", -6.0))
		hb.add_child(b)
		_toggles.append({"btn": b, "getter": getter, "valeur": val})


# --- Partie ----------------------------------------------------------------
func _son(nom: String, volume := 0.0) -> void:
	var s := get_node_or_null("/root/Son")
	if s:
		s.effet(nom, volume)


# --- Sauvegarde : reprise après rechargement de la page (iPhone) ---------------------
func _rx(o) -> float:
	if o is CombatModele.Veh:
		return lerpf(o.x_prev, o.x, _alpha)
	return o.x

func _rtete() -> float:
	return lerpf(m.x_tete_prev, m.x_tete, _alpha)


# --- Événements et effets --------------------------------------------------
func _centre_veh(v) -> Vector2:
	var h: float = float(VehiculeDessin.donnees().vehicules[v.type].hauteur) if v is CombatModele.Veh else v.hauteur
	return Vector2(_rx(v) + v.longueur * 0.5, h * 0.5)

func _ancre(v, id: String) -> Vector2:
	var D: Dictionary = VehiculeDessin.donnees().vehicules[v.type]
	var L: float = D.longueur
	var H: float = D.hauteur
	var p := Vector2(L * 0.5, H * 0.4)
	match id:
		"roulement":
			p = Vector2(L * 0.5, 0.4)
		"suspension":
			p = Vector2(L * 0.35, 0.7)
		"moteur":
			p = Vector2(L * 0.85, H * 0.35)
		"cabine":
			p = Vector2(L * 0.45, H * 0.6)
			var eq: Array = D.get("equipage", [])
			if not eq.is_empty():
				p = Vector2(eq[0].x, eq[0].y + 0.5)
		"chassis":
			p = Vector2(L * 0.5, H * 0.3)
		_:
			if id.begins_with("a"):
				var armes: Array = D.get("armes", [])
				var i := int(id.substr(1))
				if i < armes.size():
					p = Vector2(armes[i].x + armes[i].long * 0.4, armes[i].y + armes[i].get("pied", 0.0) * 0.6)
	var gx: float = _rx(v) + (L - p.x if v.camp == "ennemi" else p.x)
	return Vector2(gx, p.y)

func _px(p: Vector2) -> Vector2:
	return Vector2(terrain.ecran_x(p.x), SOL_Y + cam_h * ppm - (p.y + Terrain.sol(p.x)) * ppm)

func _sy(x: float, relief_seul := false) -> float:
	return SOL_Y + (cam_h - (Terrain.relief(x) if relief_seul else Terrain.sol(x))) * ppm


# --- Sons ------------------------------------------------------------------
const MOTEURS := {"willys_mb": "sfx_moteur_jeep", "bmw_r75": "sfx_moteur_moto", "citroen_traction": "sfx_moteur_voiture",
	"citroen_t23": "sfx_moteur_camion", "diamond_t": "sfx_moteur_camion", "dukw": "sfx_moteur_camion",
	"m3_half_track": "sfx_moteur_semi_chenille", "m3_stuart": "sfx_moteur_char_leger", "m4_sherman": "sfx_moteur_char", "tiger_1": "sfx_moteur_char"}
func _demarrer_audio() -> void:
	if _audio_ok:
		return
	_audio_ok = true
	var so := get_node_or_null("/root/Son")
	if so:
		so.musique("mus_combat")
		_son("sfx_ui_clic")
