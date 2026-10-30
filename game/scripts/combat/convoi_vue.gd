# Mode convoi : vue de profil du convoi, des ennemis et des bâtiments, avec les ordres tactiques.
# Toute la logique est dans CombatModele ; ce script dessine, relaie les ordres et joue les effets.
class_name ConvoiVue
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

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	theme = _theme()
	terrain = Terrain.new()
	terrain.ppm = ppm
	terrain.sol_y = SOL_Y
	terrain.ancre_x = 150.0
	terrain.z_index = -10   # le décor reste derrière véhicules, épaves et bâtiments
	add_child(terrain)
	couche = Control.new()
	couche.mouse_filter = MOUSE_FILTER_IGNORE
	couche.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(couche)
	fx = FxVue.new()
	fx.vue = self
	fx.mouse_filter = MOUSE_FILTER_IGNORE
	fx.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(fx)
	_construire_interface()
	_nouvelle_partie(int(Time.get_ticks_msec()) % 100000 + 1)


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


func _construire_interface() -> void:
	# --- Bandeau du haut
	var haut := _panneau(self)
	haut.set_anchors_and_offsets_preset(PRESET_TOP_WIDE)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	haut.add_child(hb)
	for k in [["ammo", "Munitions", "#E8C25A"], ["fuel_l", "Carburant", "#E8A33D"], ["metal", "Métal", "#9FB3BD"], ["pieces", "Pièces", "#8CC152"]]:
		var l := _label("", hb, 24, Color(k[2]))
		_chips[k[0]] = [l, k[1]]
	var esp := Control.new()
	esp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(esp)
	_lbl_dist = _label("", hb, 26)
	var esp2 := Control.new()
	esp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(esp2)
	_btn_surv = _bouton("Survivants", func(): _ouvrir_surv(), hb, 170)
	_btn_carte = _bouton("Carte", func(): _ouvrir_carte(), hb, 110)
	_btn_pause = _bouton("Pause", func(): _basculer_pause(), hb, 130)
	for v in [1, 2, 3]:
		var b := _bouton("x%d" % v, func(): vitesse_sim = v, hb, 68)
		b.toggle_mode = true
		_btns_vitesse.append(b)
	_lbl_quete = _label("", self, 22, C_ACCENT)
	_lbl_quete.position = Vector2(30, 96)
	_lbl_quete.add_theme_constant_override("outline_size", 6)
	_lbl_quete.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	# --- Journal
	var jb := VBoxContainer.new()
	jb.position = Vector2(30, 134)
	jb.custom_minimum_size = Vector2(900, 0)
	jb.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(jb)
	for i in 5:
		var l := _label("", jb, 22)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(900, 0)
		l.add_theme_constant_override("outline_size", 6)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		_lbl_journal.append(l)
	# --- Bannière centrale
	_lbl_banniere = Label.new()
	_lbl_banniere.set_anchors_and_offsets_preset(PRESET_CENTER_TOP)
	_lbl_banniere.position.y = 400
	_lbl_banniere.add_theme_font_size_override("font_size", 34)
	_lbl_banniere.add_theme_constant_override("outline_size", 10)
	_lbl_banniere.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_lbl_banniere.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_banniere.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_lbl_banniere.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_lbl_banniere)
	# --- Barre du bas : cartes des véhicules et ordres
	var bas := _panneau(self)
	bas.set_anchors_and_offsets_preset(PRESET_BOTTOM_WIDE)
	bas.custom_minimum_size = Vector2(0, BARRE_H)
	bas.offset_top = -BARRE_H
	var bb := HBoxContainer.new()
	bb.add_theme_constant_override("separation", 26)
	bas.add_child(bb)
	_boite_cartes = HBoxContainer.new()
	_boite_cartes.add_theme_constant_override("separation", 12)
	bb.add_child(_boite_cartes)
	var ord := VBoxContainer.new()
	ord.add_theme_constant_override("separation", 6)
	ord.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bb.add_child(ord)
	_rangee(ord, "Marche", [["Reculer", "recul"], ["Halte", "halte"], ["Avancer", "avancer"]],
		func(): return m.ordres.marche, func(v): m.ordre_marche(v), 200.0)
	_rangee(ord, "Visée", [["Libre", "libre"], ["Roues", "roulement"], ["Armes", "armement"], ["Châssis", "chassis"]],
		func(): return m.ordres.visee, func(v): m.ordre_visee(v), 150.0)
	# --- Actions du véhicule sélectionné
	_bande_actions = _panneau(self)
	_bande_actions.set_anchors_and_offsets_preset(PRESET_BOTTOM_LEFT)
	_bande_actions.offset_top = -BARRE_H - 84
	_bande_actions.offset_bottom = -BARRE_H
	_bande_actions.offset_left = 0
	var ab := HBoxContainer.new()
	ab.add_theme_constant_override("separation", 10)
	_bande_actions.add_child(ab)
	_btn_feu = _bouton("Cessez-le-feu", func(): _basculer_feu(), ab, 230)
	_btn_rep = _bouton("Réparer", func(): _basculer_rep(), ab, 160)
	_bouton("Rang vers l'arrière", func(): m.descendre(selection), ab, 270)
	_bouton("Rang vers l'avant", func(): m.monter(selection), ab, 250)
	_bouton("Abandonner", func(): m.abandonner(selection), ab, 190)
	_bouton("S'abriter", func(): m.ordre_debarquer(selection), ab, 190)
	_btn_camo = _bouton("Camoufler", func(): _basculer_camo(), ab, 200)
	# --- Alerte à droite : vague ennemie, embuscade, mines
	_panneau_alerte = _panneau(self, Color(0.2, 0.05, 0.04, 0.88))
	_panneau_alerte.set_anchors_and_offsets_preset(PRESET_TOP_RIGHT)
	_panneau_alerte.offset_left = -560
	_panneau_alerte.offset_right = -16
	_panneau_alerte.offset_top = 104
	var av := VBoxContainer.new()
	av.add_theme_constant_override("separation", 8)
	_panneau_alerte.add_child(av)
	_lbl_alerte = _label("", av, 26, C_TEXTE)
	_lbl_alerte.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_alerte.custom_minimum_size = Vector2(500, 0)
	_lbl_camp = _label("", av, 24, Color.WHITE)
	_lbl_camp.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_camp.custom_minimum_size = Vector2(500, 0)
	_lbl_nuit = _label("", av, 24, Color("#9FB8FF"))
	_lbl_nuit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_nuit.custom_minimum_size = Vector2(500, 0)
	_btn_nuit = _bouton("Passer la nuit à l'abri", func(): m.monde.ordre_nuit(), av, 0)
	_btn_embuscade = _bouton("Embuscade : s'abriter et se cacher", func(): _embuscade(), av, 0)
	_btn_mines = _bouton("Poser des mines (12 métal)", func(): m.ordre_mines(3), av, 0)
	_btn_sortir = _bouton("Reprendre la route", func(): _reprendre_route(), av, 0)
	_panneau_alerte.visible = false
	# --- Bouton « Fouiller » flottant au-dessus de la ruine ou de l'épave
	_btn_fouille = Button.new()
	_btn_fouille.custom_minimum_size = Vector2(260, 62)
	_btn_fouille.size = Vector2(260, 62)
	_btn_fouille.visible = false
	_btn_fouille.pressed.connect(func():
		var c = m.cible_fouille()
		if c != null:
			m.ordre_fouiller(c.uid)
		_demarrer_audio())
	add_child(_btn_fouille)
	# --- Menu des survivants
	_voile_surv = Control.new()
	_voile_surv.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_voile_surv.visible = false
	add_child(_voile_surv)
	var fond_s := ColorRect.new()
	fond_s.color = Color(0.03, 0.03, 0.04, 0.94)
	fond_s.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_voile_surv.add_child(fond_s)
	var ps := _panneau(_voile_surv, Color(0.1, 0.11, 0.12, 1.0))
	ps.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	ps.offset_left = 120
	ps.offset_right = -120
	ps.offset_top = 90
	ps.offset_bottom = -60
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 12)
	ps.add_child(sv)
	_label("SURVIVANTS", sv, 36, C_ACCENT)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.custom_minimum_size = Vector2(0, 360)
	sv.add_child(sc)
	_liste_surv = VBoxContainer.new()
	_liste_surv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_liste_surv.add_theme_constant_override("separation", 8)
	sc.add_child(_liste_surv)
	_pied_surv = VBoxContainer.new()
	_pied_surv.add_theme_constant_override("separation", 8)
	sv.add_child(_pied_surv)
	_bouton("Fermer", func(): _fermer_surv(), sv, 0)
	# --- Dialogue : voyageur au bord de la route, camp allié
	_panneau_dial = _panneau(self, Color(0.08, 0.09, 0.1, 0.95))
	_panneau_dial.anchor_left = 1.0
	_panneau_dial.anchor_right = 1.0
	_panneau_dial.anchor_top = 0.5
	_panneau_dial.anchor_bottom = 0.5
	_panneau_dial.offset_left = -800
	_panneau_dial.offset_right = -24
	_panneau_dial.offset_top = -300
	_panneau_dial.offset_bottom = -299
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 10)
	_panneau_dial.add_child(dv)
	_lbl_dial_titre = _label("", dv, 32, C_ACCENT)
	_lbl_dial_texte = _label("", dv, 24)
	_lbl_dial_texte.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_dial_texte.custom_minimum_size = Vector2(720, 0)
	_boite_dial = VBoxContainer.new()
	_boite_dial.add_theme_constant_override("separation", 8)
	dv.add_child(_boite_dial)
	_panneau_dial.visible = false
	# --- Carte du monde
	_voile_carte = Control.new()
	_voile_carte.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_voile_carte.visible = false
	add_child(_voile_carte)
	var fond_c := ColorRect.new()
	fond_c.color = Color(0.03, 0.03, 0.04, 0.96)
	fond_c.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_voile_carte.add_child(fond_c)
	_carte_ctl = CarteMap.new()
	_carte_ctl.vue = self
	_carte_ctl.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_carte_ctl.offset_left = 20
	_carte_ctl.offset_top = 20
	_carte_ctl.offset_bottom = -20
	_carte_ctl.offset_right = -560
	_voile_carte.add_child(_carte_ctl)
	var pc := _panneau(_voile_carte, Color(0.1, 0.11, 0.12, 1.0))
	pc.anchor_left = 1.0
	pc.anchor_right = 1.0
	pc.anchor_top = 0.0
	pc.anchor_bottom = 1.0
	pc.offset_left = -540
	pc.offset_right = -20
	pc.offset_top = 20
	pc.offset_bottom = -20
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 14)
	pc.add_child(cv)
	_label("CARTE DES SECTEURS", cv, 34, C_ACCENT)
	_lbl_carte_info = _label("", cv, 26)
	_lbl_carte_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_carte_info.custom_minimum_size = Vector2(480, 0)
	_lbl_carte_info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_btn_partir = _bouton("Partir vers ce secteur", func(): _partir(), cv, 0)
	_bouton("Fermer la carte", func(): _fermer_carte(), cv, 0)
	# --- Fin de partie
	_voile_fin = ColorRect.new()
	_voile_fin.color = Color(0, 0, 0, 0.72)
	_voile_fin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_voile_fin.visible = false
	add_child(_voile_fin)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_voile_fin.add_child(cc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 30)
	cc.add_child(vb)
	_lbl_fin = _label("", vb, 40)
	_lbl_fin.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bouton("Nouvelle expédition", func(): _nouvelle_partie(int(Time.get_ticks_msec()) % 100000 + 1), vb, 420)


# --- Partie ----------------------------------------------------------------

func _nouvelle_partie(g: int) -> void:
	graine = g
	m = CombatModele.new(g)
	_rng.seed = g
	for n in noeuds.values():
		n.queue_free()
	noeuds.clear()
	_tirs.clear()
	_etincelles.clear()
	_explosions.clear()
	_bouffees.clear()
	_cartes_sig = ""
	_persos.clear()
	ouvert = 0
	_icones.clear()
	_marche_prec = "halte"
	_acc = 0.0
	pause = false
	_n_journal = -1
	selection = m.convoi[0].uid
	_voile_fin.visible = false
	terrain.camera_x = m.convoi.back().x
	ppm = 34.0


# Son optionnel : sans l'autoload (tests), rien ne se joue
func _son(nom: String, volume := 0.0) -> void:
	var s := get_node_or_null("/root/Son")
	if s:
		s.effet(nom, volume)


func _ouvrir_surv() -> void:
	_pause_surv = pause
	pause = true
	_surv_sel = {}
	_surv_sig = ""
	_voile_surv.visible = true


func _fermer_surv() -> void:
	_voile_surv.visible = false
	pause = _pause_surv


func _maj_survivants() -> void:
	var liste: Array = m.liste_survivants()
	var sig := str(_surv_sel)
	for q in liste:
		sig += "%s%d%s%d|" % [q.nom, int(q.pv), q.lieu, q.veh_uid]
	sig += str(m.ordres.marche)
	if sig == _surv_sig:
		return
	_surv_sig = sig
	for ch in _liste_surv.get_children():
		ch.queue_free()
	for ch in _pied_surv.get_children():
		ch.queue_free()
	for q in liste:
		var ligne := HBoxContainer.new()
		ligne.add_theme_constant_override("separation", 20)
		_liste_surv.add_child(ligne)
		var ln := _label(q.nom, ligne, 28)
		ln.custom_minimum_size = Vector2(260, 0)
		var etat: String = m.etat_sante(q.pv)
		var le := _label("%s (%d/%d)" % [etat, int(q.pv), int(m.donnees().equipage_pv)], ligne, 26, {"En forme": C_VERT, "Blessé": C_ORANGE, "Gravement blessé": C_ROUGE, "Hors de combat": C_DISCRET}[etat])
		le.custom_minimum_size = Vector2(380, 0)
		var ll := _label(q.lieu, ligne, 26, C_DISCRET)
		ll.custom_minimum_size = Vector2(300, 0)
		if q.veh_uid >= 0 and q.pv > 0.0:
			var qq: Dictionary = q
			_bouton("Affecter", func():
				_surv_sel = {"veh": qq.veh_uid, "idx": qq.idx, "nom": qq.nom}
				_surv_sig = "", ligne, 190)
	if not _surv_sel.is_empty():
		_label("Affecter %s à :" % _surv_sel.nom, _pied_surv, 28, C_ACCENT)
		var rang := HBoxContainer.new()
		rang.add_theme_constant_override("separation", 12)
		_pied_surv.add_child(rang)
		for v in m.convoi:
			if v.uid != _surv_sel.veh and v.actif():
				var libre: bool = v.equipage.size() < int(v.profil.equipage)
				var vuid: int = v.uid
				var bb := _bouton("%s (%d/%d)" % [v.nom, v.equipage.size(), int(v.profil.equipage)], func():
					if m.affecter(_surv_sel.veh, _surv_sel.idx, vuid):
						_surv_sel = {}
					_surv_sig = "", rang, 0)
				bb.disabled = not libre
		_bouton("Annuler", func(): _surv_sel = {}; _surv_sig = "", rang, 0)
	if m.ordres.marche != "halte":
		_label("Mettez le convoi en Halte pour changer les affectations.", _pied_surv, 24, C_ORANGE)


func _ouvrir_carte() -> void:
	_pause_avant = pause
	pause = true
	_carte_sel = -1
	_voile_carte.visible = true
	_carte_ctl.queue_redraw()


func _fermer_carte() -> void:
	_voile_carte.visible = false
	pause = _pause_avant


func _partir() -> void:
	if _carte_sel >= 0 and m.monde.choisir_destination(_carte_sel):
		m.ordre_marche("avancer")
		_fermer_carte()


func _dialogue_bouton(texte: String, action: Callable, actif := true) -> void:
	var b := _bouton(texte, action, _boite_dial, 0)
	b.disabled = not actif
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _embuscade() -> void:
	m.ordre_marche("halte")
	var n := 0
	for v in m.convoi.duplicate():
		if m.ordre_debarquer(v.uid):
			n += 1
		m.ordre_camoufler(v.uid, true)
	if n == 0:
		m.log_("Pas de bâtiment à portée : les véhicules se camouflent sur place.", "info")


func _reprendre_route() -> void:
	for v in m.convoi.duplicate():
		m.ordre_rembarquer(v.uid)
		m.ordre_camoufler(v.uid, false)


func _basculer_camo() -> void:
	var v = m.trouver(selection)
	if v is CombatModele.Veh:
		m.ordre_camoufler(v.uid, not v.camo_voulu)


func _basculer_pause() -> void:
	pause = not pause


func _basculer_feu() -> void:
	var v = m.trouver(selection)
	if v is CombatModele.Veh:
		m.ordre_tir(selection, not v.tir)


func _basculer_rep() -> void:
	var v = m.trouver(selection)
	if v is CombatModele.Veh:
		m.ordre_reparer(selection, not v.reparation)


func selectionner(uid: int) -> void:
	selection = uid


func _input(e: InputEvent) -> void:
	# Le premier toucher peut tomber sur un bouton : on débloque l'audio sur n'importe quelle entrée
	if not _audio_ok and ((e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed) or (e is InputEventKey and e.pressed)):
		_demarrer_audio()


func _unhandled_key_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_SPACE: _basculer_pause()
			KEY_1: vitesse_sim = 1
			KEY_2: vitesse_sim = 2
			KEY_3: vitesse_sim = 3


# Position affichée (m) : interpolée entre deux pas de simulation pour un mouvement fluide
func _rx(o) -> float:
	if o is CombatModele.Veh:
		return lerpf(o.x_prev, o.x, _alpha)
	return o.x


func _rtete() -> float:
	return lerpf(m.x_tete_prev, m.x_tete, _alpha)


# --- Boucle ----------------------------------------------------------------

func _process(delta: float) -> void:
	_temps += delta
	if not pause and not m.fini:
		_acc += delta * vitesse_sim
		var pas := 0
		while _acc >= DT and pas < 8:
			m.avancer()
			_acc -= DT
			pas += 1
		_acc = minf(_acc, DT)
	_alpha = clampf(_acc / DT, 0.0, 1.0)
	for e in m.vider_evenements():
		_evenement(e)
	_vieillir(delta)
	terrain.nuit = m.monde.obscurite()
	_camera(delta)
	_synchroniser()
	_maj_persos(0.0 if pause else delta * vitesse_sim)
	_maj_sons()
	_maj_interface()


func _camera(delta: float) -> void:
	var gauche: float = _rx(m.convoi.back()) if not m.convoi.is_empty() else _rtete() - 20.0
	var droite := _rtete() + 20.0
	var plafond := 62.0
	for e in m.ennemis:
		if e.actif() and e.x - m.x_tete < 85.0:
			droite = maxf(droite, _rx(e) + e.longueur + 3.0)
	for b in m.batiments:
		var proche: bool = b.x - m.x_tete < 85.0 and b.x + b.longueur > gauche - 40.0
		if ((b.actif() or b.ami) and b.x - m.x_tete < 85.0) or (b.garnison.size() > 0 and proche):
			droite = maxf(droite, b.x + b.longueur + 3.0)
			if b.garnison.size() > 0:
				gauche = minf(gauche, b.x - 2.0)
		if proche:
			plafond = minf(plafond, 600.0 / b.hauteur)   # un grand bâtiment (église) doit tenir à l'écran
	var span := maxf(droite - gauche + 4.0, 26.0)
	var cible := clampf(1560.0 / span, 24.0, plafond)
	ppm = lerpf(ppm, cible, 1.0 - exp(-2.2 * delta))
	terrain.ppm = ppm
	if not (_pressing and _drag):
		_look_t -= delta
		if _look_t <= 0.0:
			_look_x = lerpf(_look_x, 0.0, 1.0 - exp(-2.5 * delta))
	terrain.camera_x = lerpf(terrain.camera_x, gauche - 2.0 + _look_x, 1.0 - exp(-4.0 * delta))
	var centre: float = (gauche + droite) * 0.5 + _look_x
	cam_h = lerpf(cam_h, Terrain.sol(centre) * 0.6 + Terrain.sol(_rtete()) * 0.4 - 0.5, 1.0 - exp(-3.0 * delta))
	terrain.sol_y = SOL_Y + cam_h * ppm


func _synchroniser() -> void:
	var vus := {}
	for v in m.convoi + m.ennemis + m.epaves:
		vus[v.uid] = true
		var n: VehiculeDessin = noeuds.get(v.uid)
		if n != null and n.ennemi != (v.camp == "ennemi"):
			n.queue_free()   # véhicule récupéré : il change de camp
			noeuds.erase(v.uid)
			n = null
		if n == null:
			n = VehiculeDessin.new()
			n.type = v.type
			n.ppm = ppm
			n.ennemi = v.camp == "ennemi"
			n.miroir = v.camp == "ennemi"
			n.sol = Terrain.bosses
			couche.add_child(n)
			noeuds[v.uid] = n
		if absf(n.ppm - ppm) > 0.01 and not n.D.is_empty():
			n.ppm = ppm
			n.size = Vector2(n.D.longueur, n.D.hauteur) * ppm
			n.custom_minimum_size = n.size
		var x := _rx(v)
		n.x_monde = x
		n.vitesse = v.vitesse_act if (v.actif() and not pause) else 0.0
		n.equipage = v.actif()
		n.modulate = Color.WHITE if v.actif() else (Color(0.82, 0.8, 0.78) if v.recuperable() else Color(0.4, 0.38, 0.36))
		if v.camo_voulu:
			n.modulate = Color(0.55, 0.66, 0.5, 0.45 if v.camoufle else 0.8)
		n.modulate = n.modulate * Color.WHITE.lerp(Color(0.5, 0.55, 0.75), terrain.nuit)
		n.z_index = 0 if v.actif() else -1   # les épaves passent derrière les véhicules
		var cxv: float = x + v.longueur * 0.5
		n.pivot_offset = Vector2(n.size.x * 0.5, n.size.y)
		n.position = Vector2(terrain.ecran_x(cxv) - n.size.x * 0.5, _sy(cxv, true) - n.size.y)
		n.rotation = -atan2(Terrain.relief(x + v.longueur) - Terrain.relief(x), v.longueur)
	for b in m.batiments:
		vus[b.uid] = true
		var n: BatimentDessin = noeuds.get(b.uid)
		if n == null:
			n = BatimentDessin.new()
			n.bat = b
			n.ppm = ppm
			couche.add_child(n)
			noeuds[b.uid] = n
		n.ppm = ppm
		n.size = Vector2(b.longueur, b.hauteur) * ppm
		n.position = Vector2(terrain.ecran_x(b.x), _sy(b.x + b.longueur * 0.5) - n.size.y + 2.0)
		n.modulate = Color.WHITE.lerp(Color(0.42, 0.48, 0.72), terrain.nuit)
		n.z_index = -2
	for uid in noeuds.keys():
		if not vus.has(uid):
			noeuds[uid].queue_free()
			noeuds.erase(uid)


# --- Événements et effets --------------------------------------------------

func _centre_veh(v) -> Vector2:
	var h: float = float(VehiculeDessin.donnees().vehicules[v.type].hauteur) if v is CombatModele.Veh else v.hauteur
	return Vector2(_rx(v) + v.longueur * 0.5, h * 0.5)


func _evenement(e: Dictionary) -> void:
	match e.t:
		"tir":
			var tireur = m.trouver(e.de)
			if tireur == null or m.projectiles.is_empty():
				return
			var n = noeuds.get(e.de)
			if n is VehiculeDessin:
				n.tirer("canon" if e.classe == "canon" else "mitrailleuse")
			var a: Vector2 = m.projectiles.back().a
			_bouffees.append({"p": a, "age": 0.0, "grand": e.classe == "canon"})
			var joueur: bool = (tireur is CombatModele.Veh and tireur.camp == "joueur") or (tireur is CombatModele.Bat and tireur.statut == "neutralise")
			if e.classe == "canon":
				_son("sfx_tir_canon", 0.0 if joueur else -6.0)
			elif _temps - _t_son.mitrailleuse > 0.35:
				_t_son.mitrailleuse = _temps
				_son("sfx_tir_mitrailleuse", -6.0 if joueur else -11.0)
		"impact":
			var p := Vector2(e.x, e.y)
			if e.touche and e.reel:
				_etincelles.append({"p": p, "age": 0.0, "gros": e.classe == "canon"})
				if e.ricoche:
					_ricochets.append({"p": p, "age": 0.0, "sens": 1.0 if _rng.randf() < 0.5 else -1.0})
				if e.sur_joueur and _temps - _t_son.impact > 0.25:
					_t_son.impact = _temps
					_son("sfx_impact_blindage", -4.0)
			elif e.touche:
				_etincelles.append({"p": p, "age": 0.0, "gros": false})
			else:
				_poussieres.append({"p": Vector2(e.x, maxf(e.y, 0.0)), "age": 0.0, "gros": e.classe == "canon"})
				if e.classe == "canon":
					_explosions.append({"p": p, "age": 0.0, "taille": 0.7})
		"meute":
			_son("sfx_meute", -3.0)
		"pillards":
			var so2 := get_node_or_null("/root/Son")
			if so2 and _audio_ok and _temps - _t_son.voix > 25.0:
				_t_son.voix = _temps
				so2.voix("voix_pillards")
		"nuit_tombe":
			_son("sfx_nuee", -4.0)
		"marteau":
			_son("sfx_atelier", -9.0)
		"voyageur", "secteur", "quete":
			_son("sfx_radio" if e.t == "voyageur" else "sfx_depart_convoi", -4.0)
		"mort":
			_etincelles.append({"p": Vector2(e.x, 0.9), "age": 0.0, "gros": false})
		"mine":
			_explosions.append({"p": Vector2(e.x, 0.3), "age": 0.0, "taille": 2.2})
			_son("sfx_explosion")
		"mines":
			_son("sfx_atelier", -4.0)
		"poste":
			_son("sfx_radio", -6.0)
		"contact":
			if e.ennemi:
				if _temps - _t_son.voix > 25.0:
					_t_son.voix = _temps
					var so := get_node_or_null("/root/Son")
					if so and _audio_ok:
						so.voix("voix_pillards")
			else:
				_son("sfx_radio", -4.0)
		"repare":
			_son("sfx_atelier", -2.0)
		"rejoint":
			_son("sfx_depart_convoi", -2.0)
		"casse":
			var v = m.trouver(e.uid)
			if v != null:
				_explosions.append({"p": _ancre(v, e.piece), "age": 0.0, "taille": 1.1})
		"epave":
			var v = m.trouver(e.uid)
			if v != null:
				_explosions.append({"p": _centre_veh(v), "age": 0.0, "taille": 2.6})
				_son("sfx_explosion")


func _vieillir(delta: float) -> void:
	for l in [_etincelles, _explosions, _bouffees, _poussieres, _ricochets]:
		for x in l:
			x.age += delta
	for q in _poussiere_veh:
		q.age += delta
	_poussiere_veh = _poussiere_veh.filter(func(q): return q.age < 0.9)
	_poussieres = _poussieres.filter(func(x): return x.age < 0.7)
	_ricochets = _ricochets.filter(func(x): return x.age < 0.35)
	_etincelles = _etincelles.filter(func(x): return x.age < 0.3)
	_explosions = _explosions.filter(func(x): return x.age < 1.4)
	_bouffees = _bouffees.filter(func(x): return x.age < 0.1)


# Position (m) d'une pièce, dans le repère du monde
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


# Ordonnée écran du sol en x (m) ; avec relief seul pour les véhicules
func _sy(x: float, relief_seul := false) -> float:
	return SOL_Y + (cam_h - (Terrain.relief(x) if relief_seul else Terrain.sol(x))) * ppm


func _loup(c: CanvasItem, pied: Vector2, dir: float, phase: float, mort: bool, teinte: Color) -> void:
	var k := ppm
	var d := dir
	if mort:
		c.draw_colored_polygon(PackedVector2Array([pied + Vector2(-0.6 * k, 0), pied + Vector2(-0.5 * k, -0.28 * k), pied + Vector2(0.5 * k, -0.25 * k), pied + Vector2(0.7 * k, 0)]), teinte.darkened(0.4))
		return
	var courir: float = sin(phase)
	for j in 4:
		var lx: float = (-0.45 + 0.3 * j) * d
		var pat: float = sin(phase + j * 1.6) * 0.28
		c.draw_line(pied + Vector2(lx * k, -0.5 * k), pied + Vector2((lx + pat * d) * k, -0.02 * k), teinte.darkened(0.25), maxf(2.0, k * 0.07))
	c.draw_colored_polygon(PackedVector2Array([pied + Vector2(-0.6 * d * k, -0.55 * k + courir * 0.03 * k), pied + Vector2(-0.3 * d * k, -0.95 * k), pied + Vector2(0.45 * d * k, -0.92 * k), pied + Vector2(0.65 * d * k, -0.6 * k), pied + Vector2(0.2 * d * k, -0.42 * k), pied + Vector2(-0.45 * d * k, -0.4 * k)]), teinte)
	c.draw_colored_polygon(PackedVector2Array([pied + Vector2(0.5 * d * k, -0.95 * k), pied + Vector2(0.95 * d * k, -0.75 * k), pied + Vector2(0.55 * d * k, -0.55 * k), pied + Vector2(0.4 * d * k, -0.72 * k)]), teinte.lightened(0.05))
	c.draw_line(pied + Vector2(0.55 * d * k, -0.98 * k), pied + Vector2(0.5 * d * k, -1.15 * k), teinte, maxf(2.0, k * 0.06))
	c.draw_line(pied + Vector2(-0.6 * d * k, -0.6 * k), pied + Vector2(-1.05 * d * k, -0.75 * k + courir * 0.08 * k), teinte, maxf(2.0, k * 0.07))
	c.draw_circle(pied + Vector2(0.72 * d * k, -0.74 * k), maxf(1.5, k * 0.04), Color(1.0, 0.3, 0.2))


func _dessiner_monde(c: CanvasItem) -> void:
	var f := get_theme_default_font()
	# Fantassins et animaux
	for p in m.monde.pietons:
		var xx: float = lerpf(p.x_prev, p.x, 0.0 if pause else _alpha)
		var pied := Vector2(terrain.ecran_x(xx), _sy(xx))
		var mort: bool = not p.actif()
		if mort and p.mort_t > 7.0:
			continue
		var marche: bool = absf(p.x - p.x_prev) > 0.001
		var phase: float = _temps * (14.0 if p.animal else 7.0) + p.uid
		if p.animal:
			_loup(c, pied, p.dir if p.dir != 0.0 else -1.0, phase, mort, Color("#5A5650") if p.type == "loup" else Color("#6B5A44"))
		elif mort:
			c.draw_rect(Rect2(pied + Vector2(-0.7 * ppm, -0.22 * ppm), Vector2(1.4 * ppm, 0.22 * ppm)), Color(0.18, 0.15, 0.12, 0.8))
		else:
			Silhouette.dessiner(c, pied, ppm, "pillard", {"phase": phase if marche else 0.0, "miroir": p.dir < 0.0, "peau": p.uid, "bras": "vise" if not marche else ""})
	# Lueur des feux allumés dans les bâtiments
	for b in m.batiments:
		if b.feu:
			var fl: float = 0.75 + 0.25 * sin(_temps * 13.0 + b.uid)
			for g in b.garnison:
				if g.pv > 0.0:
					var pf := _px(b.fenetre(g.slot))
					c.draw_circle(pf, ppm * 1.8, Color(1.0, 0.55, 0.2, 0.12 * fl))
					c.draw_circle(pf, ppm * 0.7, Color(1.0, 0.7, 0.3, 0.35 * fl))
	# Voyageurs au bord de la route
	for v in m.monde.pnj:
		var pv := Vector2(terrain.ecran_x(v.x), _sy(v.x))
		var parti: bool = v.statut == "parti"
		Silhouette.dessiner(c, pv, ppm, "survivant", {"phase": _temps * 7.0 if parti else 0.0, "miroir": parti, "peau": v.peau + 1})
		if v.statut == "attend":
			var hb: float = pv.y - 2.6 * ppm - 5.0 * sin(_temps * 3.0)
			c.draw_circle(Vector2(pv.x, hb), 17.0, C_ACCENT)
			c.draw_string(f, Vector2(pv.x - 8, hb + 9), "!", HORIZONTAL_ALIGNMENT_CENTER, 16, 26, Color("#1A1A18"))
			if v.type == "marchand":
				c.draw_rect(Rect2(pv + Vector2(0.8 * ppm, -0.9 * ppm), Vector2(1.6 * ppm, 0.7 * ppm)), Color("#6A5238"))
				c.draw_circle(pv + Vector2(1.2 * ppm, -0.15 * ppm), 0.28 * ppm, Color("#2A2622"))
				c.draw_circle(pv + Vector2(2.0 * ppm, -0.15 * ppm), 0.28 * ppm, Color("#2A2622"))


func _secteur(c: CanvasItem, ctr: Vector2, r: float, a0: float, a1: float, col: Color) -> void:
	var pts := PackedVector2Array([ctr])
	for i in 25:
		pts.append(ctr + Vector2.from_angle(lerpf(a0, a1, i / 24.0)) * r)
	c.draw_colored_polygon(pts, col)


# Roue du temps : moitié jour (soleil), moitié nuit (lune) ; la flèche fixe indique l'instant présent
func _horloge(c: CanvasItem) -> void:
	var ctr := Vector2(size.x * 0.5, 168.0)
	var r := 46.0
	var w = m.monde
	var jour_len: float = 1.0 - (MondeJeu.AUBE - MondeJeu.CREPUSCULE)
	var d: float = fposmod(w.heure - MondeJeu.AUBE, 1.0)
	var phi: float = d / jour_len * PI if d < jour_len else PI + (d - jour_len) / (1.0 - jour_len) * PI
	var a0: float = -PI / 2.0 - phi
	c.draw_circle(ctr, r + 5.0, Color(0, 0, 0, 0.6))
	_secteur(c, ctr, r, a0, a0 + PI, Color("#8FC3E8"))
	_secteur(c, ctr, r, a0 + PI, a0 + TAU, Color("#12163A"))
	var ps := ctr + Vector2.from_angle(a0 + PI * 0.5) * r * 0.55
	c.draw_circle(ps, r * 0.2, Color("#FFD84A"))
	for k in 8:
		c.draw_line(ps + Vector2.from_angle(k * TAU / 8.0) * r * 0.27, ps + Vector2.from_angle(k * TAU / 8.0) * r * 0.37, Color("#FFD84A"), 2.0)
	var pl := ctr + Vector2.from_angle(a0 + PI * 1.5) * r * 0.55
	c.draw_circle(pl, r * 0.2, Color("#E8ECF8"))
	c.draw_circle(pl + Vector2(r * 0.09, -r * 0.05), r * 0.18, Color("#12163A"))
	for k2 in 5:
		c.draw_circle(ctr + Vector2.from_angle(a0 + PI * (1.15 + 0.17 * k2)) * r * (0.75 if k2 % 2 == 0 else 0.35), 1.6, Color(1, 1, 0.9, 0.9))
	c.draw_arc(ctr, r, 0.0, TAU, 40, Color(0.95, 0.9, 0.8), 2.5)
	c.draw_colored_polygon(PackedVector2Array([ctr + Vector2(-11, -r - 26), ctr + Vector2(11, -r - 26), ctr + Vector2(0, -r - 6)]), Color("#F2EEE6"))
	c.draw_polyline(PackedVector2Array([ctr + Vector2(-11, -r - 26), ctr + Vector2(11, -r - 26), ctr + Vector2(0, -r - 6), ctr + Vector2(-11, -r - 26)]), Color(0, 0, 0, 0.8), 2.0)


func dessiner_fx(c: CanvasItem) -> void:
	var f := get_theme_default_font()
	var obs: float = m.monde.obscurite()
	if obs > 0.01:
		c.draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.04, 0.12, 0.2 * obs))
		for v in m.convoi:   # phares
			if v.actif() and not v.camoufle:
				var av := _px(Vector2(_rx(v) + v.longueur, 0.9))
				c.draw_colored_polygon(PackedVector2Array([av, av + Vector2(14.0 * ppm, -1.2 * ppm), av + Vector2(14.0 * ppm, 1.8 * ppm)]), Color(1.0, 0.95, 0.7, 0.16 * obs))
	_dessiner_monde(c)
	_horloge(c)
	# Fumée des véhicules endommagés et épaves
	for v in m.convoi + m.ennemis + m.epaves:
		var q: float = v.pieces.chassis.pv / v.pieces.chassis.max
		var feu: bool = v.statut == "epave"
		if q < 0.5 or feu:
			var base := _ancre(v, "moteur")
			var intens: float = 1.0 if feu else clampf((0.5 - q) * 3.0, 0.3, 1.0)
			for k in 5:
				var ph := fposmod(_temps * 0.55 + k * 0.2 + v.uid * 0.13, 1.0)
				var p := _px(base + Vector2(sin(k * 3.1 + ph * 3.0) * 0.4, ph * 3.5))
				var rr: float = (0.25 + ph * 0.9) * ppm
				c.draw_circle(p, rr, Color(0.12, 0.11, 0.1, 0.55 * (1.0 - ph) * intens))
			if feu and not v.butin_pris:
				var pf := _px(base)
				c.draw_circle(pf, ppm * (0.3 + 0.08 * sin(_temps * 14.0 + v.uid)), Color(1.0, 0.55, 0.15, 0.8))
	for b in m.batiments:
		if b.statut == "neutralise":
			for k in 4:
				var ph := fposmod(_temps * 0.5 + k * 0.25 + b.uid * 0.1, 1.0)
				var p := _px(Vector2(b.x + b.longueur * (0.25 + 0.15 * k), 1.5 + ph * 4.0))
				c.draw_circle(p, (0.4 + ph * 1.2) * ppm, Color(0.12, 0.11, 0.1, 0.5 * (1.0 - ph)))
	# Barre de vie et équipage : seulement pour NOS véhicules (l'état de l'ennemi reste inconnu)
	for v in m.convoi:
		if not v.actif():
			continue
		var D: Dictionary = VehiculeDessin.donnees().vehicules[v.type]
		var x0 := terrain.ecran_x(_rx(v))
		var top: float = _sy(_rx(v) + v.longueur * 0.5) - (float(D.hauteur) + 0.7) * ppm
		var w: float = v.longueur * ppm
		var q: float = v.pieces.chassis.pv / v.pieces.chassis.max
		c.draw_rect(Rect2(Vector2(x0, top), Vector2(w, 6)), Color(0, 0, 0, 0.6))
		c.draw_rect(Rect2(Vector2(x0, top), Vector2(w * q, 6)), couleur_etat(q))
		for k in v.equipage.size():
			c.draw_circle(Vector2(x0 + 6 + k * 12, top - 8), 4.0, C_VERT if v.equipage[k] > 0.0 else Color(0.35, 0.35, 0.35))
		if v.camo_voulu:
			var fr: float = 1.0 if v.camoufle else clampf(v.camo_t / CombatModele.donnees().embuscade.camo_s, 0.0, 1.0)
			var cam := Rect2(Vector2(x0 - 4, _sy(_rx(v) + v.longueur * 0.5) - (float(D.hauteur) + 0.3) * ppm), Vector2(w + 8, (float(D.hauteur) + 0.3) * ppm))
			c.draw_rect(cam, Color(0.25, 0.32, 0.18, 0.78 * fr))
			for k in 9:
				c.draw_circle(cam.position + Vector2(cam.size.x * (k + 0.5) / 9.0, cam.size.y * (0.2 + 0.5 * fposmod(k * 0.37, 1.0))), ppm * 0.45, Color(0.18, 0.26, 0.12, 0.8 * fr))
		if v.uid == selection:
			var cx := x0 + w * 0.5
			c.draw_colored_polygon(PackedVector2Array([Vector2(cx - 10, top - 34), Vector2(cx + 10, top - 34), Vector2(cx, top - 20)]), C_ACCENT)
	# Poussière soulevée par les véhicules en marche
	if m.vitesse_convoi != 0.0 and not pause:
		for v in m.convoi:
			if v.actif() and _rng.randf() < 0.35:
				_poussiere_veh.append({"p": Vector2(_rx(v) + 0.3, 0.2), "age": 0.0})
	for q in _poussiere_veh:
		var kq: float = q.age / 0.9
		c.draw_circle(_px(q.p) + Vector2(-kq * ppm * 1.6, -kq * ppm * 0.7), ppm * (0.2 + 0.5 * kq), Color(0.7, 0.6, 0.45, 0.35 * (1.0 - kq)))
	# Mines posées (la LED rouge clignote quand elles sont armées)
	for mn in m.mines:
		var pm := _px(Vector2(mn.x, 0.0))
		c.draw_rect(Rect2(pm + Vector2(-0.35, -0.12) * ppm, Vector2(0.7, 0.2) * ppm), Color("#3A3A32"))
		if mn.armee and fmod(_temps, 1.0) < 0.2:
			c.draw_circle(pm + Vector2(0, -0.15 * ppm), maxf(2.0, ppm * 0.07), C_ROUGE)
	# Équipages en marche vers un bâtiment ou un véhicule
	for t in m.transits:
		var vv = m.trouver(t.veh)
		var bb = m.trouver(t.bat)
		if vv == null or bb == null:
			continue
		var d0: float = vv.x + vv.longueur * 0.5
		var d1: float = bb.x + bb.longueur * 0.5
		if t.mode == "rembarque":
			var tmp := d0
			d0 = d1
			d1 = tmp
		var fr2: float = clampf(1.0 - t.restant / maxf(t.T, 0.1), 0.0, 1.0)
		var gx: float = lerpf(d0, d1, fr2)
		for k in t.pvs.size():
			var xx: float = gx - signf(d1 - d0) * k * 0.9
			Silhouette.dessiner(c, Vector2(terrain.ecran_x(xx), _sy(xx)), ppm, "survivant",
				{"phase": _temps * 7.0 + k, "miroir": d1 < d0, "peau": k + 3})
	# Butin à récupérer
	for cc in m.epaves + m.batiments:
		var libre: bool = (cc is CombatModele.Veh and not cc.butin_pris) or (cc is CombatModele.Bat and cc.statut == "neutralise" and not cc.butin_pris)
		if libre:
			var h: float = 2.0 if cc is CombatModele.Veh else cc.hauteur
			var p := Vector2(terrain.ecran_x(_rx(cc) + cc.longueur * 0.5), _sy(_rx(cc) + cc.longueur * 0.5) - (h + 1.3) * ppm - 4.0 * sin(_temps * 3.0))
			c.draw_rect(Rect2(p - Vector2(10, 10), Vector2(20, 20)), C_ACCENT)
			c.draw_string(f, p + Vector2(-10, 7), "$", HORIZONTAL_ALIGNMENT_CENTER, 20, 18, Color("#1A1A18"))
	if not m.fouille_en_cours.is_empty():
		var cible = m.trouver(m.fouille_en_cours.uid)
		if cible != null:
			var fr: float = 1.0 - m.fouille_en_cours.restant / m.fouille_en_cours.total
			var h2: float = 2.0 if cible is CombatModele.Veh else cible.hauteur
			var p2 := Vector2(terrain.ecran_x(_rx(cible) + cible.longueur * 0.5), _sy(_rx(cible) + cible.longueur * 0.5) - (h2 + 2.4) * ppm)
			c.draw_rect(Rect2(p2 - Vector2(50, 7), Vector2(100, 14)), Color(0, 0, 0, 0.7))
			c.draw_rect(Rect2(p2 - Vector2(48, 5), Vector2(96 * fr, 10)), C_ACCENT)
			c.draw_string(f, p2 + Vector2(-60, -14), "Fouille", HORIZONTAL_ALIGNMENT_CENTER, 120, 20, C_TEXTE)
	_dessiner_persos(c)
	_dessiner_panneau(c)
	# Balles et obus en vol : trajectoire du modèle (bouche de l'arme -> point d'impact)
	for pr in m.projectiles:
		var tt: float = clampf((pr.t + (0.0 if pause else _alpha * CombatModele.DT)) / pr.T, 0.0, 1.0)
		var dist: float = pr.a.distance_to(pr.b)
		var arc: float = (0.03 if pr.classe == "canon" else (0.012 if pr.classe == "fusil" else 0.004)) * dist
		var t0: float = maxf(0.0, tt - (3.2 if pr.classe != "canon" else 2.0) / maxf(dist, 1.0))
		var pa: Vector2 = pr.a.lerp(pr.b, tt) + Vector2(0, sin(PI * tt) * arc)
		var pb: Vector2 = pr.a.lerp(pr.b, t0) + Vector2(0, sin(PI * t0) * arc)
		var sa := _px(pa)
		var sb := _px(pb)
		if pr.classe == "canon":
			c.draw_line(sb, sa, Color(0.8, 0.8, 0.75, 0.35), maxf(3.0, ppm * 0.14))
			c.draw_line(sb.lerp(sa, 0.4), sa, Color(1.0, 0.75, 0.3, 0.95), maxf(4.0, ppm * 0.12))
			c.draw_circle(sa, maxf(3.5, ppm * 0.1), Color(1.0, 0.95, 0.7))
		elif pr.classe == "fusil":
			c.draw_line(sb, sa, Color(1.0, 1.0, 0.9, 0.85), 2.0)
		else:
			c.draw_line(sb, sa, Color(1.0, 0.85, 0.35, 0.35), maxf(5.0, ppm * 0.1))
			c.draw_line(sb, sa, Color(1.0, 0.95, 0.6, 1.0), 2.0)
	for s2 in _poussieres:
		var k2: float = s2.age / 0.7
		var pd := _px(s2.p)
		var rr: float = ppm * (0.25 if not s2.gros else 0.5) * (0.5 + k2)
		c.draw_circle(pd + Vector2(0, -k2 * ppm * 0.6), rr, Color(0.55, 0.46, 0.34, 0.6 * (1.0 - k2)))
		c.draw_circle(pd + Vector2(rr * 0.8, -k2 * ppm * 0.3), rr * 0.7, Color(0.5, 0.42, 0.3, 0.5 * (1.0 - k2)))
	for s3 in _ricochets:
		var k3: float = s3.age / 0.35
		var pr3 := _px(s3.p)
		c.draw_line(pr3, pr3 + Vector2(s3.sens * 70.0 * k3, -110.0 * k3 + 90.0 * k3 * k3), Color(1.0, 0.9, 0.5, 1.0 - k3), 2.5)
	for s in _etincelles:
		var p := _px(s.p)
		var fade2: float = 1.0 - s.age / 0.3
		var gros: bool = s.get("gros", false)
		var nb := 9 if gros else 6
		for k in nb:
			c.draw_line(p, p + Vector2.from_angle(k * TAU / nb + s.age * 3) * ((9 if gros else 6) + (34 if gros else 22) * s.age), Color(1, 0.8, 0.3, fade2), 2.0)
	for s in _bouffees:
		c.draw_circle(_px(s.p), 14.0 if s.get("grand", false) else 8.0, Color(1.0, 0.9, 0.5, 0.9))
	for x in _explosions:
		var p := _px(x.p)
		var k: float = x.age / 1.4
		c.draw_circle(p, x.taille * ppm * (0.4 + k * 1.2), Color(1.0, 0.55 - 0.3 * k, 0.15, 0.85 * (1.0 - k)))
		c.draw_circle(p + Vector2(0, -k * ppm), x.taille * ppm * (0.3 + k), Color(0.15, 0.14, 0.13, 0.5 * (1.0 - k)))


# --- Panneau d'état d'un véhicule (au toucher) ------------------------------

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_pressing = true
			_drag = false
			_press = e.position
		else:
			if _pressing and not _drag:
				_tap(e.position)
			_pressing = false
			_drag = false
	elif e is InputEventMouseMotion and _pressing:
		if not _drag and e.position.distance_to(_press) > 16.0:
			_drag = true
		if _drag:
			_look_x = clampf(_look_x - e.relative.x / ppm, -70.0, 70.0)
			_look_t = 3.0
			accept_event()


func _tap(p: Vector2) -> void:
	_demarrer_audio()
	for ic in _icones:
		if ic.rect.has_point(p):
			_action_icone(ic)
			accept_event()
			return
	var trouve := 0
	for v in m.convoi + m.epaves:
		if v.statut == "epave":
			continue
		var D: Dictionary = VehiculeDessin.donnees().vehicules[v.type]
		var r := Rect2(Vector2(terrain.ecran_x(_rx(v)) - 12.0, _sy(_rx(v) + v.longueur * 0.5) - float(D.hauteur) * ppm - 50.0), Vector2(v.longueur * ppm + 24.0, float(D.hauteur) * ppm + 60.0))
		if r.has_point(p):
			trouve = v.uid
	ouvert = 0 if trouve == ouvert else trouve
	if m.trouver(trouve) in m.convoi:
		selection = trouve
	accept_event()


func _action_icone(ic: Dictionary) -> void:
	var v = m.trouver(ic.uid)
	if not (v is CombatModele.Veh):
		return
	if ic.has("action"):
		if m.ordres.marche != "halte":
			m.ordre_marche("halte")
		if m.rejoindre(ic.uid):
			ouvert = 0
		return
	if v.reparation and v.rep_piece == ic.piece:
		m.ordre_reparer(ic.uid, false)
		return
	if m.ordres.marche != "halte":
		m.ordre_marche("halte")
	m.ordre_reparer(ic.uid, true, ic.piece)


func _dessiner_panneau(c: CanvasItem) -> void:
	_icones.clear()
	if ouvert == 0:
		return
	var v = m.trouver(ouvert)
	if not (v is CombatModele.Veh) or v.statut == "epave" or (v.camp == "ennemi" and v.actif()):
		ouvert = 0
		return
	var D: Dictionary = VehiculeDessin.donnees().vehicules[v.type]
	var casses := []
	for id in v.pieces:
		if v.pieces[id].pv < v.pieces[id].max - 0.5:
			casses.append(id)
	var rejoindre: bool = v.recuperable() and v.piece_ok("chassis") and v.piece_ok("roulement") and v.piece_ok("moteur") and m._mecanicien_possible(v)
	var n: int = casses.size() + (1 if rejoindre else 0)
	if n == 0:
		return   # rien de cassé : rien ne s'affiche
	var t := 66.0
	var largeur: float = casses.size() * (t + 8.0) + (198.0 if rejoindre else 0.0) - 8.0
	var x0: float = terrain.ecran_x(_rx(v)) + v.longueur * ppm * 0.5 - largeur * 0.5
	x0 = clampf(x0, 12.0, size.x - largeur - 12.0)
	var y0: float = maxf(150.0, _sy(_rx(v) + v.longueur * 0.5) - (float(D.hauteur) + 0.7) * ppm - 120.0)
	var f := get_theme_default_font()
	for i in casses.size():
		var id: String = casses[i]
		var pq: float = v.pieces[id].pv / v.pieces[id].max
		var r := Rect2(Vector2(x0 + i * (t + 8.0), y0), Vector2(t, t))
		var col: Color = C_ROUGE if pq <= 0.0 else C_ORANGE
		var en_cours: bool = v.reparation and (v.rep_piece == id or (v.rep_piece == "" and m._piece_a_reparer(v) == id))
		c.draw_rect(r, Color(0.06, 0.065, 0.07, 0.92))
		c.draw_rect(r, Color("#5AA9E6") if en_cours else col, false, 4.0 if en_cours else 2.0)
		_glyphe(c, id, v, r.position + Vector2(t, t - 8.0) * 0.5, col)
		c.draw_rect(Rect2(r.position + Vector2(6, t - 9), Vector2(t - 12, 5)), Color(0, 0, 0, 0.7))
		c.draw_rect(Rect2(r.position + Vector2(6, t - 9), Vector2((t - 12) * pq, 5)), col)
		_icones.append({"rect": r, "uid": v.uid, "piece": id})
	if rejoindre:
		var r2 := Rect2(Vector2(x0 + casses.size() * (t + 8.0), y0), Vector2(190, t))
		c.draw_rect(r2, C_VERT.darkened(0.45))
		c.draw_rect(r2, C_VERT, false, 3.0)
		c.draw_string(f, r2.position + Vector2(0, 41), "Rejoindre le convoi", HORIZONTAL_ALIGNMENT_CENTER, r2.size.x, 20, Color.WHITE)
		_icones.append({"rect": r2, "uid": v.uid, "action": "rejoindre"})
	if not casses.is_empty():
		c.draw_string(f, Vector2(x0, y0 - 8.0), "Toucher une pièce : envoyer un mécanicien", HORIZONTAL_ALIGNMENT_LEFT, 460, 18, C_TEXTE)


# Pictogramme d'une pièce, centré en `p`
func _glyphe(c: CanvasItem, id: String, v: CombatModele.Veh, p: Vector2, col: Color) -> void:
	var fond := Color(0.06, 0.065, 0.07)
	match CombatModele.genre_piece(id):
		"roulement":
			if v.chenille:
				c.draw_rect(Rect2(p + Vector2(-23, 2), Vector2(46, 17)), col)
				for k in 3:
					c.draw_circle(p + Vector2(-14 + k * 14, 10.5), 5.0, fond)
			else:
				c.draw_circle(p + Vector2(0, 4), 16, col)
				c.draw_circle(p + Vector2(0, 4), 7, fond)
				c.draw_circle(p + Vector2(0, 4), 3, col)
		"moteur":
			c.draw_rect(Rect2(p + Vector2(-17, -6), Vector2(34, 22)), col)
			c.draw_rect(Rect2(p + Vector2(-13, -14), Vector2(8, 8)), col)
			c.draw_rect(Rect2(p + Vector2(5, -14), Vector2(8, 8)), col)
			c.draw_circle(p + Vector2(0, 5), 6, fond)
		"suspension":
			var pts := PackedVector2Array()
			for k in 7:
				pts.append(p + Vector2((8.0 if k % 2 else -8.0), -16 + k * 5.5))
			c.draw_polyline(pts, col, 4.0)
			c.draw_line(p + Vector2(-14, -18), p + Vector2(14, -18), col, 4.0)
			c.draw_line(p + Vector2(-14, 18), p + Vector2(14, 18), col, 4.0)
		"cabine":
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(-19, 15), p + Vector2(-19, -2), p + Vector2(-9, -15), p + Vector2(10, -15), p + Vector2(19, -2), p + Vector2(19, 15)]), col)
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(-11, -2), p + Vector2(-6, -10), p + Vector2(8, -10), p + Vector2(13, -2)]), fond)
		"chassis":
			c.draw_rect(Rect2(p + Vector2(-23, -5), Vector2(46, 17)), col)
			c.draw_rect(Rect2(p + Vector2(-17, -11), Vector2(22, 7)), col)
			c.draw_circle(p + Vector2(-13, 14), 5, fond)
			c.draw_circle(p + Vector2(13, 14), 5, fond)
		_:
			var wid: String = v.profil.armes[int(id.substr(1))]
			if CombatModele.donnees().armes[wid].classe == "canon":
				c.draw_rect(Rect2(p + Vector2(-4, -5), Vector2(30, 9)), col)
				c.draw_rect(Rect2(p + Vector2(-20, -10), Vector2(18, 20)), col)
				c.draw_circle(p + Vector2(-11, 0), 5, fond)
			else:
				c.draw_line(p + Vector2(-4, -6), p + Vector2(24, -6), col, 4.0)
				c.draw_rect(Rect2(p + Vector2(-16, -12), Vector2(14, 12)), col)
				c.draw_line(p + Vector2(-9, 0), p + Vector2(-17, 16), col, 3.0)
				c.draw_line(p + Vector2(-9, 0), p + Vector2(0, 16), col, 3.0)


# --- Petits personnages : fouille et réparation ----------------------------

func _equipiers() -> int:
	var n := 0
	for v in m.convoi:
		n += v.equipage_vivant()
	return n


func _origine_x(cx: float) -> float:
	var meilleur := cx
	var d_min := INF
	for v in m.convoi:
		var ctr: float = _rx(v) + v.longueur * 0.5
		if absf(ctr - cx) < d_min:
			d_min = absf(ctr - cx)
			meilleur = ctr
	return meilleur


func _maj_persos(delta: float) -> void:
	var voulus := {}
	if not m.fouille_en_cours.is_empty():
		var cible = m.trouver(m.fouille_en_cours.uid)
		if cible != null:
			var cx: float = _rx(cible) + cible.longueur * 0.5
			voulus["fouille"] = {"cible": cx, "variante": "survivant", "n": clampi(_equipiers(), 1, 2), "origine": _origine_x(cx)}
	if m.ordres.marche == "halte":
		for v in m.convoi + m.epaves:
			if v.reparation and v.rep_pret >= 0.0:
				var id: String = m._piece_a_reparer(v)
				if id != "":
					var cx: float = _ancre(v, id).x
					voulus["rep%d" % v.uid] = {"cible": cx, "variante": "mecano", "n": 1, "origine": _origine_x(_rx(v) + v.longueur * 0.5)}
	for cle in voulus:
		var d: Dictionary = voulus[cle]
		var existants := _persos.filter(func(q): return q.cle == cle)
		for q in existants:
			q.mode = "va" if q.mode == "retour" else q.mode
			q.cible = d.cible + (q.idx - (d.n - 1) * 0.5) * 1.1
		for i in range(existants.size(), d.n):
			_persos.append({"cle": cle, "idx": i, "variante": d.variante, "x": d.origine, "origine": d.origine,
				"cible": d.cible + (i - (d.n - 1) * 0.5) * 1.1, "mode": "va", "phase": 0.0, "dir": 1.0})
	for q in _persos:
		if not voulus.has(q.cle):
			q.mode = "retour"
			q.origine = _origine_x(q.x)
		var but: float = q.origine if q.mode == "retour" else q.cible
		var dx: float = but - q.x
		if absf(dx) > 0.15:
			q.x += signf(dx) * minf(2.6 * delta, absf(dx))
			q.dir = signf(dx)
			q.phase += delta * 7.0
		elif q.mode == "va":
			q.mode = "travaille"
		elif q.mode == "travaille":
			q.phase += delta * 7.0
		else:
			q.mode = "fini"
	_persos = _persos.filter(func(q): return q.mode != "fini")


func _dessiner_persos(c: CanvasItem) -> void:
	for q in _persos:
		var x: float = q.x
		var pied := Vector2(terrain.ecran_x(x), _sy(x))
		var marche: bool = q.mode != "travaille"
		Silhouette.dessiner(c, pied, ppm, q.variante, {"phase": q.phase if marche else 0.0, "miroir": q.dir < 0.0,
			"travaille": q.phase if not marche else 0.0, "peau": q.idx})


# --- Sons ------------------------------------------------------------------

const MOTEURS := {"willys_mb": "sfx_moteur_jeep", "bmw_r75": "sfx_moteur_moto", "citroen_traction": "sfx_moteur_voiture",
	"citroen_t23": "sfx_moteur_camion", "diamond_t": "sfx_moteur_camion", "dukw": "sfx_moteur_camion",
	"m3_half_track": "sfx_moteur_semi_chenille", "m3_stuart": "sfx_moteur_char_leger", "m4_sherman": "sfx_moteur_char", "tiger_1": "sfx_moteur_char"}


# Les navigateurs n'autorisent le son qu'après un premier toucher : on démarre alors ambiance et musique
func _demarrer_audio() -> void:
	if _audio_ok:
		return
	_audio_ok = true
	var so := get_node_or_null("/root/Son")
	if so:
		so.musique("mus_combat")


func _maj_sons() -> void:
	if not _audio_ok:
		return
	var so := get_node_or_null("/root/Son")
	if so == null:
		return
	var amb: String = "amb_desert_nuit" if m.monde.obscurite() > 0.5 else "amb_desert_jour"
	if amb != _amb_nom:
		_amb_nom = amb
		so.ambiance(amb)
	if m.monde.obscurite() > 0.6 and not pause:
		_t_nuit -= get_process_delta_time()
		if _t_nuit <= 0.0:
			_t_nuit = _rng.randf_range(14.0, 30.0)
			_son("sfx_meute" if _rng.randf() < 0.6 else "sfx_nuee", -10.0)
	var lourd = null
	for v in m.convoi:
		if v.actif() and (lourd == null or v.profil.metal > lourd.profil.metal):
			lourd = v
	var nom := ""
	if lourd != null and m.vitesse_convoi != 0.0 and not pause and not m.fini:
		nom = MOTEURS.get(lourd.type, "")
	so.moteur(nom)
	if m.ordres.marche != _marche_prec:
		if m.ordres.marche == "avancer":
			_son("sfx_depart_marche", -4.0)
		_marche_prec = m.ordres.marche


# --- Interface -------------------------------------------------------------

func _maj_interface() -> void:
	for k in ["ammo", "fuel_l", "metal"]:
		var l: Label = _chips[k][0]
		var val: float = m.stocks[k]
		var txt: String = "%s %d" % [_chips[k][1], int(val)]
		if k == "fuel_l":
			txt += " L"
		l.text = txt
		l.modulate = C_ROUGE if val <= 0.5 else Color.WHITE
	_chips.pieces[0].text = "Pièces %d" % m.composants.size()
	_btn_pause.text = "Reprendre" if pause else "Pause"
	for i in _btns_vitesse.size():
		_btns_vitesse[i].set_pressed_no_signal(vitesse_sim == i + 1)
	for t in _toggles:
		t.btn.set_pressed_no_signal(t.getter.call() == t.valeur)
	# Journal
	if m.journal.size() != _n_journal or not m.journal.is_empty():
		_n_journal = m.journal.size()
		var dern: Array = m.journal.slice(maxi(0, m.journal.size() - 5))
		for i in _lbl_journal.size():
			var l: Label = _lbl_journal[i]
			if i < dern.size():
				var e: Dictionary = dern[i]
				l.text = e.txt
				l.modulate = {"ok": C_VERT, "alerte": C_ORANGE, "info": C_TEXTE}.get(e.ton, C_TEXTE)
				l.modulate.a = clampf(1.0 - (m.temps - e.t) / 25.0, 0.35, 1.0)
			else:
				l.text = ""
	# Bannière
	var ban := ""
	if pause:
		ban = "PAUSE : les ordres restent possibles"
	elif m.blocage != "" and m.ordres.marche != "halte":
		ban = m.blocage
	elif m.ordres.marche == "halte" and m.temps < 1.0:
		ban = "Appuyez sur Avancer pour partir"
	_lbl_banniere.text = ban
	# Cartes de véhicules
	var sig := ""
	for v in m.convoi:
		sig += str(v.uid) + ","
	if sig != _cartes_sig:
		_cartes_sig = sig
		for ch in _boite_cartes.get_children():
			ch.queue_free()
		var ordre: Array = m.convoi.duplicate()
		ordre.reverse()
		for v in ordre:
			var cte := Carte.new()
			cte.vue = self
			cte.uid = v.uid
			cte.flat = true
			cte.custom_minimum_size = Vector2(318, 150)
			cte.pressed.connect(func(): selectionner(v.uid))
			_boite_cartes.add_child(cte)
		if m.trouver(selection) == null or not (m.trouver(selection) in m.convoi):
			selection = m.convoi[0].uid if not m.convoi.is_empty() else 0
	for ch in _boite_cartes.get_children():
		ch.queue_redraw()
	var sel = m.trouver(selection)
	_bande_actions.visible = sel is CombatModele.Veh and sel in m.convoi
	if _bande_actions.visible:
		_btn_feu.text = "Cessez-le-feu" if sel.tir else "Reprendre le feu"
		_btn_rep.text = "Arrêter" if sel.reparation else "Réparer"
	_voile_fin.visible = m.fini
	# Alertes : vague ennemie, camps annoncés, nuit, embuscade
	var al: Dictionary = m.alerte()
	var w = m.monde
	var poste := false
	for bt in m.batiments:
		poste = poste or bt.garnison.size() > 0
	var cache := false
	for v in m.convoi:
		cache = cache or v.camo_voulu
	var ann: Array = w.annonces()
	var nuit_alerte: bool = w.alerte_nuit()
	var vf = w.voyageur_actuel()
	var camp = w.camp_proche()
	var dial: bool = vf != null or (camp != null and m.ordres.marche == "halte" and camp.uid != _camp_ferme)
	_panneau_alerte.visible = (not al.is_empty() or poste or cache or not m.mines.is_empty() or not m.transits.is_empty() or not ann.is_empty() or nuit_alerte) and not dial and not _voile_carte.visible
	if _panneau_alerte.visible:
		var txt := ""
		if not al.is_empty():
			txt = "ENNEMIS EN APPROCHE\n%d véhicule(s), à %d m" % [al.n, int(al.dist)]
			if al.eta >= 0.0:
				txt += ", contact dans %d s" % int(al.eta)
		elif poste or cache:
			txt = "Embuscade en place : l'ennemi ne vous voit pas. La première salve surprend."
		_lbl_alerte.text = txt
		_lbl_alerte.visible = txt != ""
		var lignes := ""
		for an in ann:
			lignes += "%s %s (%s) à %d m%s\n" % [an.nom, "ALLIÉ" if an.ami else "HOSTILE", MondeJeu.FACTIONS[an.faction], int(an.dist), " : fortifié" if an.fortifie else ""]
		_lbl_camp.text = lignes.strip_edges()
		_lbl_camp.visible = lignes != ""
		var hostile_annonce := false
		for an2 in ann:
			hostile_annonce = hostile_annonce or not an2.ami
		_lbl_camp.modulate = Color("#FFB35A") if hostile_annonce else Color("#9BE89B")
		var abri: Dictionary = w.abri_proche()
		_lbl_nuit.text = "LA NUIT TOMBE : les rôdeurs sortent.\n%s" % ("Abri : %s à %d m (%s)." % [abri.nom, int(abri.dist), "devant" if abri.devant else "derrière"] if not abri.is_empty() else "Aucun abri en vue : cherchez une ruine ou une église.")
		_lbl_nuit.visible = nuit_alerte
		_btn_nuit.visible = nuit_alerte and not abri.is_empty()
		_btn_embuscade.visible = not al.is_empty() or poste or cache
		_btn_mines.visible = not al.is_empty() or poste or cache
		_btn_sortir.visible = poste or cache or not m.transits.is_empty()
	# Dialogue : voyageur ou camp allié
	_panneau_dial.visible = dial and not _voile_carte.visible
	if _panneau_dial.visible:
		var sig_d := "%s|%d|%d|%d" % ["v" if vf != null else "c", vf.uid if vf != null else camp.uid, int(m.stocks.metal), int(m.stocks.ammo)]
		if sig_d != _dial_sig:
			_dial_sig = sig_d
			for ch in _boite_dial.get_children():
				ch.queue_free()
			if vf != null:
				var o: Dictionary = w.offre_de(vf)
				_lbl_dial_titre.text = vf.nom
				_lbl_dial_texte.text = o.texte
				_dialogue_bouton("Accepter : %s" % o.titre, func(): w.repondre(true), w.peut_accepter(o))
				_dialogue_bouton("Refuser", func(): w.repondre(false))
			else:
				_lbl_dial_titre.text = "%s allié (%s)" % [camp.nom, MondeJeu.FACTIONS[camp.faction]]
				_lbl_dial_texte.text = "Les sentinelles vous laissent entrer. Vous pouvez échanger, réparer ou vous reposer."
				for a in w.actions_camp():
					var ok := true
					for k in a.prend:
						ok = ok and m.stocks[k] >= a.prend[k]
					var aid: String = a.id
					_dialogue_bouton(a.txt, func(): w.camp_action(aid), ok)
				var cuid: int = camp.uid
				_dialogue_bouton("Fermer", func(): _camp_ferme = cuid)
	else:
		_dial_sig = ""
	if camp == null:
		_camp_ferme = 0
	# HUD : secteur, horloge, quête
	var sct: Dictionary = w.secteurs[w.secteur]
	_lbl_dist.text = "%s (F%d)  %d m  Jour %d, %s" % [sct.nom, sct.faction, int(m.x_tete), w.jour, w.periode()]
	if w.en_transit():
		_lbl_quete.text = "Cap sur %s : %d m de route calme" % [w.secteurs[w.trajet.dest].nom, int(w.trajet.reste)]
	elif not w.quete.is_empty():
		_lbl_quete.text = "Quête : %s (%d/%d)" % [w.quete.titre, mini(m.ennemis_detruits - w.quete.depart, w.quete.abattre), w.quete.abattre]
	else:
		_lbl_quete.text = ""
	# Bouton Fouiller
	var cf = m.cible_fouille()
	var voir_f: bool = cf != null and m.fouille_demandee == 0 and m.fouille_en_cours.is_empty() and not m.menace() and not _voile_carte.visible and not _voile_surv.visible and not dial
	_btn_fouille.visible = voir_f
	if voir_f:
		var hf: float = 2.0 if cf is CombatModele.Veh else cf.hauteur
		var cx: float = _rx(cf) + cf.longueur * 0.5
		_btn_fouille.text = "Fouiller : %s" % cf.nom
		_btn_fouille.position = Vector2(clampf(terrain.ecran_x(cx) - 130.0, 10.0, size.x - 270.0), maxf(150.0, _sy(cx) - (hf + 1.3) * ppm - 90.0))
	if _voile_surv.visible:
		_maj_survivants()
	# Carte
	if _voile_carte.visible:
		var inf := ""
		if _carte_sel >= 0:
			var ss: Dictionary = w.secteurs[_carte_sel]
			inf = "%s\n%s : %s\nDifficulté : niveau %d sur 7\nDistance : environ %d m de route calme" % [ss.nom, MondeJeu.FACTIONS[ss.faction], {"ami": "alliée", "neutre": "neutre", "hostile": "hostile"}[MondeJeu.ATTITUDE[ss.faction]], ss.niveau, int(250.0 + w.distance_secteur(_carte_sel) * 900.0)]
		else:
			inf = "Touchez un secteur pour le choisir.\nLes anneaux vont du vert (calme) au rouge (dangereux). La couleur du centre est la faction."
		_lbl_carte_info.text = "Vous êtes à %s.\n\n%s" % [sct.nom, inf]
		_btn_partir.disabled = _carte_sel < 0 or _carte_sel == w.secteur
	if _btn_camo != null:
		_btn_camo.text = "Découvrir" if (sel is CombatModele.Veh and sel.camo_voulu) else "Camoufler"
	if m.fini:
		_lbl_fin.text = "Convoi anéanti\nDistance : %d m   Ennemis détruits : %d\n\nOn ne revoit jamais ceux qui s'éloignent." % [int(m.distance_max), m.ennemis_detruits]
