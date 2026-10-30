# Mode convoi : vue de profil du convoi, des ennemis et des bâtiments, avec les ordres tactiques.
# Toute la logique est dans CombatModele ; ce script dessine, relaie les ordres et joue les effets.
class_name ConvoiVue
extends Control

const SOL_Y := 700.0
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
var _tirs := []                 # {a: Vector2 (m), b: Vector2 (m), age, classe}
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
	hb.add_theme_constant_override("separation", 22)
	haut.add_child(hb)
	for k in [["ammo", "Munitions", "#E8C25A"], ["fuel_l", "Carburant", "#E8A33D"], ["metal", "Métal", "#9FB3BD"], ["pieces", "Pièces", "#8CC152"]]:
		var l := _label("", hb, 26, Color(k[2]))
		_chips[k[0]] = [l, k[1]]
	var esp := Control.new()
	esp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(esp)
	_lbl_dist = _label("", hb, 26)
	var esp2 := Control.new()
	esp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(esp2)
	_btn_pause = _bouton("Pause", func(): _basculer_pause(), hb, 150)
	for v in [1, 2, 3]:
		var b := _bouton("x%d" % v, func(): vitesse_sim = v, hb, 80)
		b.toggle_mode = true
		_btns_vitesse.append(b)
	# --- Journal
	var jb := VBoxContainer.new()
	jb.position = Vector2(30, 104)
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
	_rangee(ord, "Cible", [["Plus proche", "proche"], ["Véhicules", "vehicules"], ["Bâtiments", "batiments"]],
		func(): return m.ordres.cible, func(v): m.ordre_cible(v), 200.0)
	_rangee(ord, "Visée", [["Libre", "libre"], ["Roues", "roulement"], ["Armes", "armement"], ["Châssis", "chassis"]],
		func(): return m.ordres.visee, func(v): m.ordre_visee(v), 150.0)
	_rangee(ord, "Fouille", [["Automatique", "auto"], ["À l'arrêt seulement", "arret"]],
		func(): return m.ordres.fouille, func(v): m.ordre_fouille(v), 250.0)
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
	_camera(delta)
	_synchroniser()
	_maj_persos(0.0 if pause else delta * vitesse_sim)
	_maj_sons()
	_maj_interface()


func _camera(delta: float) -> void:
	var gauche: float = _rx(m.convoi.back()) if not m.convoi.is_empty() else _rtete() - 20.0
	var droite := _rtete() + 22.0
	for e in m.ennemis:
		if e.actif() and e.x - m.x_tete < 85.0:
			droite = maxf(droite, _rx(e) + e.longueur + 4.0)
	for b in m.batiments:
		if b.actif() and b.x - m.x_tete < 85.0:
			droite = maxf(droite, b.x + b.longueur + 4.0)
	var span := maxf(droite - gauche + 6.0, 30.0)
	var cible := clampf(1620.0 / span, 19.0, 46.0)
	ppm = lerpf(ppm, cible, 1.0 - exp(-2.2 * delta))
	terrain.ppm = ppm
	terrain.camera_x = lerpf(terrain.camera_x, gauche - 2.0, 1.0 - exp(-4.0 * delta))


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
			n.sol = Terrain.sol
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
		n.z_index = 0 if v.actif() else -1   # les épaves passent derrière les véhicules
		n.position = Vector2(terrain.ecran_x(x), SOL_Y - n.size.y)
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
		n.position = Vector2(terrain.ecran_x(b.x), SOL_Y - n.size.y + 2.0)
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
			var cible = m.trouver(e.vers)
			if tireur == null or cible == null:
				return
			var n = noeuds.get(e.de)
			if n is VehiculeDessin:
				n.tirer("canon" if e.classe == "canon" else "mitrailleuse")
			var ha: float = 2.0 if tireur is CombatModele.Bat else float(VehiculeDessin.donnees().vehicules[tireur.type].hauteur) * 0.72
			var a := Vector2(e.x0, ha)
			var b := _centre_veh(cible)
			if e.touche:
				b += Vector2(_rng.randf_range(-1.2, 1.2), _rng.randf_range(-0.4, 0.5))
				_etincelles.append({"p": b, "age": 0.0})
			else:
				b += Vector2(_rng.randf_range(-6.0, 6.0), _rng.randf_range(0.5, 2.5))
			_tirs.append({"a": a, "b": b, "age": 0.0, "classe": e.classe})
			if tireur is CombatModele.Bat:
				_bouffees.append({"p": a, "age": 0.0})
			var joueur: bool = tireur is CombatModele.Veh and tireur.camp == "joueur"
			if joueur:
				if e.classe == "canon":
					_son("sfx_tir_canon")
				elif _temps - _t_son.mitrailleuse > 0.35:
					_t_son.mitrailleuse = _temps
					_son("sfx_tir_mitrailleuse", -6.0)
			if e.touche and not joueur and _temps - _t_son.impact > 0.25:
				_t_son.impact = _temps
				_son("sfx_impact_blindage", -4.0)
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
	for l in [_tirs, _etincelles, _explosions, _bouffees]:
		for x in l:
			x.age += delta
	_tirs = _tirs.filter(func(x): return x.age < 0.16)
	_etincelles = _etincelles.filter(func(x): return x.age < 0.3)
	_explosions = _explosions.filter(func(x): return x.age < 1.4)
	_bouffees = _bouffees.filter(func(x): return x.age < 0.08)


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
	return Vector2(terrain.ecran_x(p.x), SOL_Y - (p.y + Terrain.sol(p.x)) * ppm)


func dessiner_fx(c: CanvasItem) -> void:
	var f := get_theme_default_font()
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
		if not b.actif():
			for k in 4:
				var ph := fposmod(_temps * 0.5 + k * 0.25 + b.uid * 0.1, 1.0)
				var p := _px(Vector2(b.x + b.longueur * (0.25 + 0.15 * k), 1.5 + ph * 4.0))
				c.draw_circle(p, (0.4 + ph * 1.2) * ppm, Color(0.12, 0.11, 0.1, 0.5 * (1.0 - ph)))
	# Barres de vie, équipage et pièces abîmées
	for v in m.convoi + m.ennemis:
		if not v.actif():
			continue
		var D: Dictionary = VehiculeDessin.donnees().vehicules[v.type]
		var x0 := terrain.ecran_x(_rx(v))
		var top: float = SOL_Y - (float(D.hauteur) + 0.7) * ppm
		var w: float = v.longueur * ppm
		var q: float = v.pieces.chassis.pv / v.pieces.chassis.max
		c.draw_rect(Rect2(Vector2(x0, top), Vector2(w, 6)), Color(0, 0, 0, 0.6))
		c.draw_rect(Rect2(Vector2(x0, top), Vector2(w * q, 6)), couleur_etat(q) if v.camp == "joueur" else C_ROUGE)
		for k in v.equipage.size():
			c.draw_circle(Vector2(x0 + 6 + k * 12, top - 8), 4.0, C_VERT if v.equipage[k] > 0.0 else Color(0.35, 0.35, 0.35))
		if v.camp == "joueur" and v.uid == selection:
			var cx := x0 + w * 0.5
			c.draw_colored_polygon(PackedVector2Array([Vector2(cx - 10, top - 34), Vector2(cx + 10, top - 34), Vector2(cx, top - 20)]), C_ACCENT)
	for b in m.batiments:
		if b.actif():
			var x0 := terrain.ecran_x(b.x)
			var top: float = SOL_Y - (b.hauteur + 0.7) * ppm
			var w: float = b.longueur * ppm
			c.draw_rect(Rect2(Vector2(x0, top), Vector2(w, 6)), Color(0, 0, 0, 0.6))
			c.draw_rect(Rect2(Vector2(x0, top), Vector2(w * b.pv / b.pv_max, 6)), C_ROUGE)
			for k in b.tireurs.size():
				c.draw_circle(Vector2(x0 + 6 + k * 12, top - 8), 4.0, C_ROUGE if b.tireurs[k].pv > 0.0 else Color(0.35, 0.35, 0.35))
	# Butin à récupérer
	for cc in m.epaves + m.batiments:
		var libre: bool = (cc is CombatModele.Veh and not cc.butin_pris) or (cc is CombatModele.Bat and cc.statut == "neutralise" and not cc.butin_pris)
		if libre:
			var h: float = 2.0 if cc is CombatModele.Veh else cc.hauteur
			var p := Vector2(terrain.ecran_x(_rx(cc) + cc.longueur * 0.5), SOL_Y - (h + 1.3) * ppm - 4.0 * sin(_temps * 3.0))
			c.draw_rect(Rect2(p - Vector2(10, 10), Vector2(20, 20)), C_ACCENT)
			c.draw_string(f, p + Vector2(-10, 7), "$", HORIZONTAL_ALIGNMENT_CENTER, 20, 18, Color("#1A1A18"))
	if not m.fouille_en_cours.is_empty():
		var cible = m.trouver(m.fouille_en_cours.uid)
		if cible != null:
			var fr: float = 1.0 - m.fouille_en_cours.restant / m.fouille_en_cours.total
			var h2: float = 2.0 if cible is CombatModele.Veh else cible.hauteur
			var p2 := Vector2(terrain.ecran_x(_rx(cible) + cible.longueur * 0.5), SOL_Y - (h2 + 2.4) * ppm)
			c.draw_rect(Rect2(p2 - Vector2(50, 7), Vector2(100, 14)), Color(0, 0, 0, 0.7))
			c.draw_rect(Rect2(p2 - Vector2(48, 5), Vector2(96 * fr, 10)), C_ACCENT)
			c.draw_string(f, p2 + Vector2(-60, -14), "Fouille", HORIZONTAL_ALIGNMENT_CENTER, 120, 20, C_TEXTE)
	_dessiner_persos(c)
	_dessiner_panneau(c)
	# Traits de tir, étincelles, explosions
	for t in _tirs:
		var a := _px(t.a)
		var b := _px(t.b)
		var fade: float = 1.0 - t.age / 0.16
		if t.classe == "canon":
			c.draw_line(a, b, Color(1.0, 0.7, 0.25, fade), 4.0)
		else:
			c.draw_line(a, b, Color(1.0, 0.9, 0.5, fade * 0.9), 2.0)
	for s in _etincelles:
		var p := _px(s.p)
		var fade2: float = 1.0 - s.age / 0.3
		for k in 6:
			c.draw_line(p, p + Vector2.from_angle(k * TAU / 6 + s.age * 3) * (6 + 22 * s.age) , Color(1, 0.8, 0.3, fade2), 2.0)
	for s in _bouffees:
		c.draw_circle(_px(s.p), 8.0, Color(1.0, 0.9, 0.5, 0.9))
	for x in _explosions:
		var p := _px(x.p)
		var k: float = x.age / 1.4
		c.draw_circle(p, x.taille * ppm * (0.4 + k * 1.2), Color(1.0, 0.55 - 0.3 * k, 0.15, 0.85 * (1.0 - k)))
		c.draw_circle(p + Vector2(0, -k * ppm), x.taille * ppm * (0.3 + k), Color(0.15, 0.14, 0.13, 0.5 * (1.0 - k)))


# --- Panneau d'état d'un véhicule (au toucher) ------------------------------

func _gui_input(e: InputEvent) -> void:
	if not (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
		return
	_demarrer_audio()
	var p: Vector2 = e.position
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
		var r := Rect2(Vector2(terrain.ecran_x(_rx(v)) - 12.0, SOL_Y - float(D.hauteur) * ppm - 50.0), Vector2(v.longueur * ppm + 24.0, float(D.hauteur) * ppm + 60.0))
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
	var y0: float = maxf(150.0, SOL_Y - (float(D.hauteur) + 0.7) * ppm - 120.0)
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
		var pied := Vector2(terrain.ecran_x(x), SOL_Y - Terrain.sol(x) * ppm)
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
		so.ambiance("amb_desert_jour")
		so.musique("mus_combat")


func _maj_sons() -> void:
	if not _audio_ok:
		return
	var so := get_node_or_null("/root/Son")
	if so == null:
		return
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
	_lbl_dist.text = "Distance %d m   Niveau %d" % [int(m.x_tete), int(m.x_tete / 400.0)]
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
	if m.fini:
		_lbl_fin.text = "Convoi anéanti\nDistance : %d m   Ennemis détruits : %d" % [int(m.distance_max), m.ennemis_detruits]
