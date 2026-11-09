# Couche 2 de la vue : construction et mise à jour de l'interface, actions du joueur, sauvegarde.
extends "res://scripts/combat/vue_dessin.gd"

var _voile_menu: ColorRect       # menu principal : continuer, nouvelle expédition, bac à sable (DEC-043)
var _btn_continuer: Button
var _fond_titre: TextureRect
var _boite_titre: VBoxContainer
var _panneau_options: ColorRect


# --- Construction ----------------------------------------------------------
func _construire_interface() -> void:
	var debut := get_child_count()
	_construire_elements()
	_ui_noeuds = get_children().slice(debut)
	_appliquer_marges()
	resized.connect(_appliquer_marges)


# Décale l'interface hors des bords (encoche, Dynamic Island, coins, confort des pouces) : DEC-056.
# Les offsets d'origine sont gardés en métadonnée : on peut réappliquer à chaque changement de taille.
func _appliquer_marges() -> void:
	_mg = ZonesSures.marges(size)
	for c in _ui_noeuds:
		_decaler(c)


func _decaler(c) -> void:
	if not (c is Control):
		return
	if c is ColorRect and c.anchor_left == 0.0 and c.anchor_right == 1.0 and c.anchor_top == 0.0 and c.anchor_bottom == 1.0:
		for e in c.get_children():   # voile plein écran : le fond reste, le contenu s'écarte des bords
			_decaler(e)
		return
	if not c.has_meta("o0"):
		c.set_meta("o0", [c.offset_left, c.offset_top, c.offset_right, c.offset_bottom])
	var o: Array = c.get_meta("o0")
	var dx_g: float = _mg.g if c.anchor_left == 0.0 else (-_mg.d if c.anchor_left == 1.0 else 0.0)
	var dx_d: float = _mg.g if c.anchor_right == 0.0 else (-_mg.d if c.anchor_right == 1.0 else 0.0)
	var dy_h: float = _mg.h if c.anchor_top == 0.0 else (-_mg.b if c.anchor_top == 1.0 else 0.0)
	var dy_b: float = _mg.h if c.anchor_bottom == 0.0 else (-_mg.b if c.anchor_bottom == 1.0 else 0.0)
	c.offset_left = o[0] + dx_g
	c.offset_top = o[1] + dy_h
	c.offset_right = o[2] + dx_d
	c.offset_bottom = o[3] + dy_b


func _construire_elements() -> void:
	# --- Bandeau du haut
	var haut := _panneau(self, Color(0, 0, 0, 0))   # pas de bande : les éléments flottent
	haut.set_anchors_and_offsets_preset(PRESET_TOP_WIDE)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	haut.add_child(hb)
	_horloge_ui = Horloge.new()
	_horloge_ui.vue = self
	hb.add_child(_horloge_ui)
	for k in [["ammo", "Munitions", "#E8C25A"], ["fuel_l", "Carburant", "#E8A33D"], ["eau", "Eau", "#7FB8D8"], ["vivres", "Vivres", "#C9A46A"], ["metal", "Métal", "#9FB3BD"], ["pieces", "Pièces", "#8CC152"]]:
		var bulle := _bulle(hb)
		var bh := HBoxContainer.new()
		bh.add_theme_constant_override("separation", 8)
		bulle.add_child(bh)
		bh.add_child(IconeRes.new(k[0]))
		var l := _label("", bh, 32, Color.WHITE)
		_chips[k[0]] = [l, k[1], bulle]
	var bulle_d := _bulle(self)   # secteur, distance, jour : seconde ligne, à gauche (DEC-149)
	bulle_d.position = Vector2(30, 98)
	_lbl_dist = _label("", bulle_d, 28)
	var esp2 := Control.new()
	esp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(esp2)
	_btn_atelier = _bouton("Assembler", func(): _ouvrir_atelier(), hb, 190)
	_btn_atelier.visible = false
	_btn_nouveau = _bouton("Construire", func(): _ouvrir_editeur(0), hb, 160)
	_btn_nouveau.visible = false
	_btn_kit = _bouton("Kit", _basculer_kit, hb, 90)
	_btn_kit.visible = false
	_btn_surv = _bouton("Survivants", func(): _ouvrir_surv(), hb, 150)
	_btn_carte = _bouton("Carte", func(): _ouvrir_carte(), hb, 110)
	_btn_pause = _bouton("Pause", func(): _basculer_pause(), hb, 110)
	for v in [1, 2, 3]:
		var b := _bouton("x%d" % v, func(): vitesse_sim = v, hb, 60)
		b.toggle_mode = true
		_btns_vitesse.append(b)
	_lbl_quete = _label("", self, 28, C_ACCENT)
	_lbl_quete.position = Vector2(30, 164)
	_lbl_quete.add_theme_constant_override("outline_size", 6)
	_lbl_quete.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	# --- Journal
	var jb := VBoxContainer.new()
	jb.position = Vector2(30, 208)
	jb.custom_minimum_size = Vector2(900, 0)
	jb.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(jb)
	for i in 4:
		var l := _label("", jb, 30)
		l.add_theme_font_override("font", police("inter"))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(900, 0)
		l.add_theme_constant_override("outline_size", 6)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		_lbl_journal.append(l)
	# --- Bannière centrale
	_lbl_banniere = Label.new()
	_lbl_banniere.set_anchors_and_offsets_preset(PRESET_CENTER_TOP)
	_lbl_banniere.position.y = 400
	_lbl_banniere.add_theme_font_size_override("font_size", 50)
	_lbl_banniere.add_theme_font_override("font", police("pochoir", 800))
	_lbl_banniere.add_theme_constant_override("outline_size", 10)
	_lbl_banniere.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_lbl_banniere.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_banniere.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_lbl_banniere.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_lbl_banniere)
	# --- Barre du bas : cartes des véhicules et ordres
	var bas := _panneau(self, Color(0, 0, 0, 0))   # plus de bande noire
	bas.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	ord.visible = false
	_ord = ord
	var cadre_ord := _panneau(bb)   # les ordres gardent un fond lisible, seulement quand ils sont ouverts
	cadre_ord.visible = false
	cadre_ord.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cadre_ord.add_child(ord)
	ord.visible = true
	_ord = cadre_ord
	_rangee(ord, "Marche", [["Reculer", "recul"], ["Halte", "halte"], ["Avancer", "avancer"]],
		func(): return m.ordres.marche, func(v): m.ordre_marche(v), 200.0)
	_rangee(ord, "Visée", [["Libre", "libre"], ["Roues", "roulement"], ["Armes", "armement"], ["Châssis", "chassis"]],
		func(): return m.ordres.visee, func(v): m.ordre_visee(v), 150.0)
	var hd := HBoxContainer.new()
	ord.add_child(hd)
	_bouton("Demi-tour du convoi", func(): _demi_tour(), hd, 330)
	_bouton("Fermer", func(): _ord_t = 0.0, hd, 150)
	_btn_ordres = _bouton("Ordres du convoi", func(): _ord_t = 8.0, self, 300)
	_btn_ordres.set_anchors_and_offsets_preset(PRESET_BOTTOM_RIGHT)
	_btn_ordres.offset_left = -320
	_btn_ordres.offset_right = -16
	_btn_ordres.offset_top = -BARRE_H - 140
	_btn_ordres.offset_bottom = -BARRE_H - 80
	_btn_marche = _bouton("Avancer", func(): _action_marche(), self, 300)
	_btn_marche.set_anchors_and_offsets_preset(PRESET_BOTTOM_RIGHT)
	_btn_marche.offset_left = -320
	_btn_marche.offset_right = -16
	_btn_marche.offset_top = -BARRE_H - 76
	_btn_marche.offset_bottom = -BARRE_H - 12
	# --- Actions du véhicule sélectionné
	_bande_actions = _panneau(self)
	_bande_actions.set_anchors_and_offsets_preset(PRESET_BOTTOM_LEFT)
	_bande_actions.anchor_right = 1.0      # la bande s'arrête avant les boutons de marche et passe à la ligne (DEC-056)
	_bande_actions.offset_top = -BARRE_H - 84
	_bande_actions.offset_bottom = -BARRE_H
	_bande_actions.offset_left = 0
	_bande_actions.offset_right = -340
	_bande_actions.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var ab := HFlowContainer.new()
	ab.add_theme_constant_override("h_separation", 10)
	ab.add_theme_constant_override("v_separation", 8)
	_bande_actions.add_child(ab)
	_btn_feu = _bouton("Cessez-le-feu", func(): _basculer_feu(), ab, 230)
	_btn_rep = _bouton("Réparer", func(): _basculer_rep(), ab, 160)
	_bouton("Rang vers l'arrière", func(): m.descendre(selection), ab, 270)
	_bouton("Rang vers l'avant", func(): m.monter(selection), ab, 250)
	_bouton("Abandonner", func(): m.abandonner(selection), ab, 190)
	_bouton("S'abriter", func(): m.ordre_debarquer(selection), ab, 190)
	_btn_camo = _bouton("Camoufler", func(): _basculer_camo(), ab, 200)
	_btn_garage = _bouton("Garer", func(): _basculer_garage(), ab, 170)
	_btn_modifier = _bouton("Grille", func(): _ouvrir_editeur(selection), ab, 150)
	_btn_demonter = _bouton("Démonter", func(): m.ordre_demonter(selection), ab, 170)
	_btn_troupes = _bouton("Débarquer les troupes", func(): m.ordre_troupes(selection), ab, 300)
	_btn_troupes.visible = false
	_btn_camp = _bouton("Camp", func(): _action_camp(), ab, 330)
	# --- Alerte à droite : vague ennemie, embuscade, mines
	_panneau_alerte = _panneau(self, Color(0.2, 0.05, 0.04, 0.88))
	_panneau_alerte.set_anchors_and_offsets_preset(PRESET_TOP_RIGHT)
	_panneau_alerte.offset_left = -560
	_panneau_alerte.offset_right = -16
	_panneau_alerte.offset_top = 104
	var av := VBoxContainer.new()
	av.add_theme_constant_override("separation", 8)
	_panneau_alerte.add_child(av)
	_lbl_alerte = _label("", av, 31, C_TEXTE)
	_lbl_alerte.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_alerte.custom_minimum_size = Vector2(500, 0)
	_lbl_camp = _label("", av, 29, Color.WHITE)
	_lbl_camp.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_camp.custom_minimum_size = Vector2(500, 0)
	_lbl_nuit = _label("", av, 29, Color("#9FB8FF"))
	_lbl_nuit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_nuit.custom_minimum_size = Vector2(500, 0)
	_btn_nuit = _bouton("Passer la nuit à l'abri", func(): m.monde.ordre_nuit(), av, 0)
	_lbl_meteo = _label("", av, 29, Color("#FFD27A"))
	_lbl_meteo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_meteo.custom_minimum_size = Vector2(500, 0)
	_btn_demin_det = _bouton("Déminer : détecteur de métaux", func(): m.ordre_deminer("detecteur"), av, 0)
	_btn_demin_chien = _bouton("Déminer : chien", func(): m.ordre_deminer("chien"), av, 0)
	_btn_traverser = _bouton("Traverser à l'aveugle", func(): m.ordre_traverser(), av, 0)
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
	_lbl_dial_titre = _label("", dv, 42, C_ACCENT)
	_lbl_dial_titre.add_theme_font_override("font", police("pochoir", 800))
	_lbl_dial_texte = _label("", dv, 27)
	_lbl_dial_texte.add_theme_font_override("font", police("inter"))
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
	_lbl_carte_info = _label("", cv, 31)
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
	_bouton("Mode créatif", func(): _nouvelle_partie(int(Time.get_ticks_msec()) % 100000 + 1, {}, false, true), vb, 420)
	# --- Écran d'accueil (DEC-086) : image plein cadre, quatre boutons sous le titre. Pas utilisé comme menu de pause.
	_voile_menu = ColorRect.new()
	_voile_menu.color = Color.BLACK
	_voile_menu.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_voile_menu.visible = false
	var calque_menu := CanvasLayer.new()   # au-dessus des écrans plein cadre (calque 20) : l'accueil passe devant l'assemblage d'ouverture
	calque_menu.layer = 30
	add_child(calque_menu)
	_voile_menu.theme = theme
	calque_menu.add_child(_voile_menu)
	if ResourceLoader.exists("res://assets/ui/ecran_titre.jpg"):
		var scene := Control.new()   # image + calques animés : le lent zoom s'applique à ce parent, pas aux boutons
		scene.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		scene.mouse_filter = MOUSE_FILTER_IGNORE
		scene.clip_contents = true
		_voile_menu.add_child(scene)
		_fond_titre = TextureRect.new()
		_fond_titre.texture = load("res://assets/ui/ecran_titre.jpg")
		_fond_titre.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_fond_titre.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_fond_titre.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		_fond_titre.mouse_filter = MOUSE_FILTER_IGNORE
		scene.add_child(_fond_titre)
		for mode in ["fumee", "lumiere"]:
			var an := TitreAnim.new()
			an.mode = mode
			scene.add_child(an)
	var ver := Label.new()   # numéro de version et date de la dernière mise en ligne (écrit par le workflow web)
	var txt := "version de développement"
	if FileAccess.file_exists("res://data/version.json"):
		var vj = JSON.parse_string(FileAccess.get_file_as_string("res://data/version.json"))
		if vj is Dictionary and vj.has("version"):
			txt = "Version " + str(vj.version)
	ver.text = txt
	ver.add_theme_font_size_override("font_size", 26)
	ver.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	ver.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	ver.add_theme_constant_override("outline_size", 6)
	ver.mouse_filter = MOUSE_FILTER_IGNORE
	ver.set_anchors_and_offsets_preset(PRESET_CENTER_BOTTOM)
	ver.grow_horizontal = Control.GROW_DIRECTION_BOTH
	ver.offset_top = -50
	_voile_menu.add_child(ver)
	_boite_titre = VBoxContainer.new()
	_boite_titre.add_theme_constant_override("separation", 20)
	_voile_menu.add_child(_boite_titre)
	_btn_continuer = _bouton_titre("Continuer", func():
		_voile_menu.visible = false
		_musique_ecran(false)
		pause = _atelier != null or _editeur != null)
	_bouton_titre("Recommencer", func(): _nouvelle_partie(int(Time.get_ticks_msec()) % 100000 + 1))
	_bouton_titre("Bac à sable", func(): _nouvelle_partie(int(Time.get_ticks_msec()) % 100000 + 1, {}, false, true))
	_bouton_titre("Options", func(): _panneau_options.visible = true)
	_voile_menu.resized.connect(_placer_titre)
	# Options : volumes (Son.regler les mémorise)
	_panneau_options = ColorRect.new()
	_panneau_options.color = Color(0.03, 0.03, 0.03, 0.9)
	_panneau_options.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_panneau_options.visible = false
	_voile_menu.add_child(_panneau_options)
	var co := CenterContainer.new()
	co.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_panneau_options.add_child(co)
	var vo := VBoxContainer.new()
	vo.add_theme_constant_override("separation", 22)
	co.add_child(vo)
	_label("OPTIONS", vo, 48).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_curseurs_son(vo)
	_bouton("Retour", func(): _panneau_options.visible = false, vo, 300)
	_placer_titre()


# Curseurs de volume (accueil et menu de pause)
func _curseurs_son(vo: Control) -> void:
	var so := get_node_or_null("/root/Son")
	for bus in ["Musique", "Effets", "Voix"]:
		var hbo := HBoxContainer.new()
		hbo.add_theme_constant_override("separation", 20)
		vo.add_child(hbo)
		var l := _label(bus, hbo, 30)
		l.custom_minimum_size = Vector2(160, 0)
		var sl := HSlider.new()
		sl.min_value = 0.0
		sl.max_value = 1.0
		sl.step = 0.05
		sl.custom_minimum_size = Vector2(420, 56)
		sl.value = so.volumes[bus] if so else 0.7
		var nom: String = bus
		sl.value_changed.connect(func(v: float): if so: so.regler(nom, v))
		hbo.add_child(sl)


# Menu de pause : Reprendre, Son, Menu principal (calque sous l'accueil)
func _construire_menu_pause() -> void:
	_calque_pause = CanvasLayer.new()
	_calque_pause.layer = 25
	_calque_pause.visible = false
	add_child(_calque_pause)
	var fond := ColorRect.new()
	fond.color = Color(0, 0, 0, 0.6)
	fond.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_calque_pause.add_child(fond)
	var co := CenterContainer.new()
	co.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	fond.add_child(co)
	var pc := PanelContainer.new()
	var bm := verre(0.8, 0.35, false, 18)   # panneau de pause en verre fumé (DEC-149)
	bm.set_content_margin_all(40)
	pc.add_theme_stylebox_override("panel", bm)
	co.add_child(pc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 18)
	pc.add_child(vb)
	_label("PAUSE", vb, 44).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bouton("Reprendre", func(): _fermer_menu_pause(), vb, 420)
	_label("Son", vb, 30).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_curseurs_son(vb)
	_bouton("Menu principal", func():
		_fermer_menu_pause(false)
		afficher_menu(true), vb, 420)
	fond.theme = theme


func _fermer_menu_pause(restaurer := true) -> void:
	_calque_pause.visible = false
	if restaurer:
		pause = _pause_avant_menu


# Bouton de l'écran d'accueil : plaque d'acier dessinée par le code (voir titre_bouton.gd)
func _bouton_titre(texte: String, action: Callable) -> Button:
	var b := TitreBouton.new()
	b.text = texte
	b.custom_minimum_size = Vector2(0, 76)
	b.pressed.connect(action)
	b.pressed.connect(func(): _demarrer_audio(); _son("sfx_ui_clic", -6.0))
	_boite_titre.add_child(b)
	return b


# Les boutons suivent l'image (recadrée « cover ») : zone du mur sous le titre, en coordonnées de l'image 1672×941
func _placer_titre() -> void:
	if _boite_titre == null or _voile_menu == null:
		return
	var t := _voile_menu.size
	var ech := maxf(t.x / 1672.0, t.y / 941.0)
	var dec := (t - Vector2(1672.0, 941.0) * ech) * 0.5
	var coin := dec + Vector2(250.0, 420.0) * ech
	var taille := Vector2(520.0, 400.0) * ech
	_boite_titre.position = coin
	_boite_titre.size = taille


# Écran plein (grille, atelier) posé sur son propre calque : au-dessus de toute l'interface, y compris pour le toucher
func _par_dessus(c: Control) -> void:
	var calque := CanvasLayer.new()
	calque.layer = 20
	add_child(calque)
	c.theme = theme   # le calque coupe l'héritage du thème
	calque.add_child(c)
	c.tree_exited.connect(calque.queue_free)


func _accueil_visible() -> bool:
	return _voile_menu != null and _voile_menu.visible


func afficher_menu(continuer: bool) -> void:
	_btn_continuer.visible = continuer
	_panneau_options.visible = false
	_boite_titre.modulate.a = 0.0
	create_tween().tween_property(_boite_titre, "modulate:a", 1.0, 1.4).set_delay(0.5)
	_voile_menu.visible = true
	_musique_ecran(true)
	pause = true


# --- Partie ----------------------------------------------------------------
func _nouvelle_partie(g: int, sauve := {}, ouverture := false, bac := false) -> void:
	graine = g
	if _voile_menu != null:
		if _voile_menu.visible:
			_musique_ecran(false)
		_voile_menu.visible = false
	if _atelier != null:
		_atelier.queue_free()
		_atelier = null
	if _editeur != null:
		_editeur.queue_free()
		_editeur = null
	if sauve.is_empty():
		_effacer_sauvegarde()
		# Départ avec le Berliet, camion de l'expédition (DEC-139) ; l'ancien début guidé (moto à assembler, DEC-035) reste possible par ouverture = true
		var opts := {"bac_a_sable": true} if bac else ({"ouverture": true} if ouverture else {"meteo": true, "champs": true, "villes": true, "pannes": true})
		m = CombatModele.new(g, opts)
	else:
		m = CombatModele.depuis_sauvegarde(sauve)
	_rng.seed = g
	_installer_kit()
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
	selection = m.convoi[0].uid if not m.convoi.is_empty() else 0
	_fin_t = 0.0
	_fin_son = false
	_voile_fin.visible = false
	terrain.camera_x = m.convoi.back().x if not m.convoi.is_empty() else 0.0
	ppm = 34.0
	if m.en_kit:
		_ouvrir_atelier()

# Atelier sur grille : premier assemblage, puis transformations au bord de la route (DEC-035)
func _ouvrir_atelier() -> void:
	var at: Dictionary = m.atelier_possible()
	if at.is_empty() or _atelier != null:
		return
	_demarrer_audio()
	var pause_avant := pause
	pause = true
	_atelier = AtelierGrille.new()
	_atelier.ouvrir(m, int(at.uid), String(at.plan))
	_par_dessus(_atelier)
	_atelier.ferme.connect(func(_ok: bool):
		_atelier = null
		pause = pause_avant and not m.convoi.is_empty()
		if selection == 0 and not m.convoi.is_empty():
			selection = m.convoi[0].uid
			terrain.camera_x = m.convoi.back().x)

# Éditeur libre (G3) : modifier un véhicule garé, ou en construire un neuf sur un châssis de la réserve
func _ouvrir_editeur(vehicule_uid: int) -> void:
	if _editeur != null or _atelier != null:
		return
	var raison: String = m.raison_grille(vehicule_uid)   # grille accessible à tout moment, jeu en pause (DEC-043)
	if raison != "":
		m.log_(raison, "alerte")
		return
	_demarrer_audio()
	var pause_avant := pause
	pause = true
	_editeur = EditeurGrille.new()
	_editeur.ouvrir(m, vehicule_uid)
	_par_dessus(_editeur)
	_editeur.ferme.connect(func(_ok: bool):
		_editeur = null
		pause = pause_avant and not m.convoi.is_empty())

# Écran de transformation d'une base (DEV-016) : ouvert depuis l'atelier d'une ville ; le modèle applique le résultat
func _ouvrir_transformation(vehicule_uid: int) -> void:
	if _editeur != null or _atelier != null:
		return
	var raison: String = m.raison_grille(vehicule_uid)
	if raison != "":
		m.log_(raison, "alerte")
		return
	var pause_avant := pause
	pause = true
	var ecran := EcranTransformation.new()
	ecran.ouvrir(m.grille_de(vehicule_uid), m.transformation_contexte(vehicule_uid))
	_par_dessus(ecran)
	ecran.ferme.connect(func(valide: bool, g: Dictionary, metal: float, duree_s: float):
		if valide:
			m.transformer(vehicule_uid, g, metal, duree_s)
		ecran.queue_free()
		pause = pause_avant and not m.convoi.is_empty())

# --- Camp de réparation (DEV-018) -----------------------------------------------------------------
# Option à proposer : la réparation qui correspond à la panne (essieu ou roues cassés, moteur HS), sinon la première possible
func _option_camp(v) -> Dictionary:
	var opts: Array = m.camp_options(v.uid)
	var voulu := ""
	if not v.piece_ok("roulement"):
		voulu = "changer_essieu"
	elif not v.piece_ok("moteur"):
		voulu = "changer_moteur"
	for o in opts:
		if String(o.op) == voulu:
			return o
	return opts[0] if not opts.is_empty() else {}


func _maj_bouton_camp(sel) -> void:
	if m.camp_actif():
		var pause_camp: bool = String(m.camp_rep.camp.etat) == "interrompue"
		_btn_camp.text = "Reprendre le camp" if pause_camp else "Interrompre le camp"
		_btn_camp.disabled = false
		return
	var o := _option_camp(sel)
	if o.is_empty():
		_btn_camp.text = "Camp : rien à réparer"
		_btn_camp.disabled = true
		return
	var en_vue: bool = not m.ennemis.filter(func(e): return e.actif()).is_empty()
	_btn_camp.text = "Camp : %s (%d min)" % [String(o.nom).to_lower(), int(ceil(float(o.duree_s) / 60.0))]
	_btn_camp.disabled = not bool(o.ok) or en_vue
	if not bool(o.ok):
		_btn_camp.text += " — " + String(o.raison)
	elif en_vue:
		_btn_camp.text += " — ennemis en vue"


func _action_camp() -> void:
	_demarrer_audio()
	if m.camp_actif():
		if String(m.camp_rep.camp.etat) == "interrompue":
			m.camp_reprendre()
		else:
			m.camp_interrompre()
		return
	var sel = m.trouver(selection)
	if not (sel is CombatModele.Veh):
		return
	var o := _option_camp(sel)
	if not o.is_empty():
		m.camp_etablir(sel.uid, String(o.op), o.params)


func _texte_camp() -> String:
	var C: Dictionary = m.camp_rep.camp
	var fait := 1.0 - float(C.restant_s) / maxf(1.0, float(C.duree_s))
	var etat := "TRAVAUX INTERROMPUS" if String(C.etat) == "interrompue" else "CAMP DE RÉPARATION"
	var l := "%s : %d %%, encore %d s" % [etat, int(fait * 100.0), int(ceil(float(C.restant_s)))]
	if not m.ennemis.filter(func(e): return e.actif()).is_empty():
		l += "\nATTAQUE : défendez le camp, les travaux sont suspendus."
	return l


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
		var ll := _label(q.lieu, ligne, 31, C_DISCRET)
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
		_label("Mettez le convoi en Halte pour changer les affectations.", _pied_surv, 29, C_ORANGE)

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
	if m.ville_dedans():   # depuis une ville, on part par la porte de sortie (DEC-141)
		if _carte_sel >= 0 and m.ville_partir(_carte_sel):
			_fermer_carte()
		return
	if _carte_sel >= 0 and m.monde.choisir_destination(_carte_sel):
		m.ordre_marche("avancer")
		_fermer_carte()

# --- Ville (DEC-140 à DEC-143) ----------------------------------------------------------------
func _action_marche() -> void:
	if m.ville_dedans():
		_ville_onglet = "sorties"
		_ville_ferme = false
		_dial_sig = ""
		return
	m.ordre_marche("halte" if m.ordres.marche == "avancer" else "avancer")

func _ville_aller(onglet: String) -> void:
	_ville_onglet = onglet
	_dial_sig = ""

func _remplir_ville() -> void:
	for ch in _boite_dial.get_children():
		ch.queue_free()
	var V: Dictionary = m.ville
	if m.ville_pillee() and _ville_onglet != "bilan":   # ville pillée : le récit du rescapé et la poursuite (DEC-151)
		_lbl_dial_titre.text = "%s brûle" % V.nom
		_lbl_dial_texte.text = String(CombatModele.VD().variantes.pillee.recit)
		_dialogue_bouton("Prendre la poursuite", func(): m.ville_poursuite(), m.evenement.is_empty())
		_dialogue_bouton("Fermer", func(): _ville_ferme = true)
		return
	match "mission" if _ville_onglet.begins_with("mission:") else _ville_onglet:
		"maire":
			_lbl_dial_titre.text = "Mairie de %s" % V.nom
			var offres: Array = m.mission_offres()
			if offres.is_empty():
				_lbl_dial_texte.text = m.ville_texte_maire()
			else:   # le maire propose ses missions (DEC-144)
				_lbl_dial_texte.text = "M. %s, maire de %s, déplie une carte sur son bureau. « J'ai du travail pour un convoi comme le vôtre. Choisissez. »" % [V.maire, V.nom]
				for o in offres:
					var ty: String = o.type
					_dialogue_bouton("%s pour %s (%d m)" % [o.nom, o.dest_nom, o.distance_m], func(): _ville_aller("mission:" + ty))
			_dialogue_bouton("Retour", func(): _ville_aller("accueil"))
		"marche":   # eau et vivres contre du métal (DEC-148)
			_lbl_dial_titre.text = "Marché de %s" % V.nom
			_lbl_dial_texte.text = "Bidons d'eau et caisses de vivres, par lots de %d. Il vous reste %d jours d'eau et %d jours de vivres pour %d bouches." % [
				int(CombatModele.VD().marche.lot), int(minf(m.jours_de("eau"), 99.0)), int(minf(m.jours_de("vivres"), 99.0)), m.survivants_nourris()]
			for k in ["eau", "vivres"]:
				var kk: String = k
				var p: int = m.ville_prix_lot(kk)
				_dialogue_bouton("Acheter %d %s (%d métal)" % [int(CombatModele.VD().marche.lot), "bidons d'eau" if kk == "eau" else "caisses de vivres", p], func(): m.ville_acheter(kk); _ville_aller("marche"), m.bac_a_sable or m.stocks.metal >= p)
			_dialogue_bouton("Retour", func(): _ville_aller("accueil"))
		"bilan":
			var b: Dictionary = m.mission_bilan
			_lbl_dial_titre.text = String(b.get("titre", V.nom))
			_lbl_dial_texte.text = String(b.get("texte", ""))
			_dialogue_bouton("Continuer", func(): _ville_aller("accueil"))
		"garage":
			_lbl_dial_titre.text = "Garage · mécanique"
			var c: int = m.ville_cout_reparation()
			if m.ville_a_reparer():
				_lbl_dial_texte.text = "« Laissez-moi le convoi, je vous le rends comme neuf. » Prix : %d métal." % (0 if m.bac_a_sable else c)
				_dialogue_bouton("Faire réparer tout le convoi", func(): m.ville_reparer(); _ville_aller("garage"), m.bac_a_sable or m.stocks.metal >= c)
			else:
				_lbl_dial_texte.text = "« Rien à faire sur vos véhicules. Revenez quand ça cognera. »"
			_dialogue_bouton("Retour", func(): _ville_aller("accueil"))
		"atelier":
			_lbl_dial_titre.text = "Atelier de %s" % V.nom
			_lbl_dial_texte.text = "Les postes à souder et le pont roulant sont à vous : transformez vos véhicules sur la grille."
			var vp = m.vehicule_principal()
			var cible: int = selection if m.trouver(selection) in m.convoi else (vp.uid if vp != null else 0)
			_dialogue_bouton("Ouvrir la grille", func(): _ouvrir_editeur(cible), cible != 0)
			_dialogue_bouton("Transformer (rallonge, plateau, blindage)", func(): _ouvrir_transformation(cible), cible != 0)
			_dialogue_bouton("Retour", func(): _ville_aller("accueil"))
		"sorties":
			_lbl_dial_titre.text = "Quitter %s" % V.nom
			_lbl_dial_texte.text = "Par quelle porte sortir ? La route qui suit mène au secteur choisi."
			for o in m.ville_sorties():
				var dest: int = o.id
				var t := "%s : %s, niveau %d, %d m" % [o.porte, o.secteur, o.niveau, o.distance_m]
				if String(o.ville) != "":
					t += " (ville : %s)" % o.ville
				_dialogue_bouton(t, func(): m.ville_partir(dest))
			_dialogue_bouton("Rester", func(): _ville_aller("accueil"))
		"mission":
			var ty: String = _ville_onglet.substr(8)
			var offre := {}
			for o in m.mission_offres():
				if o.type == ty:
					offre = o
			_lbl_dial_titre.text = "Mission : %s" % String(offre.get("nom", ty)).to_lower()
			_lbl_dial_texte.text = String(offre.get("texte", ""))
			_dialogue_bouton("Accepter", func(): m.mission_accepter(ty), not offre.is_empty())
			_dialogue_bouton("Refuser", func(): _ville_aller("maire"))
		_:
			_lbl_dial_titre.text = V.nom
			_lbl_dial_texte.text = "Plusieurs centaines d'âmes derrière des murs de tôle. Ici, ni tempête ni pillard : le convoi est à l'abri."
			_dialogue_bouton("Mairie : parler au maire (missions)", func(): _ville_aller("maire"))
			_dialogue_bouton("Marché : eau et vivres", func(): _ville_aller("marche"))
			_dialogue_bouton("Garage : le mécanicien", func(): _ville_aller("garage"))
			_dialogue_bouton("Atelier : la grille", func(): _ville_aller("atelier"))
			_dialogue_bouton("Repartir : choisir la sortie", func(): _ville_aller("sorties"))
			_dialogue_bouton("Fermer", func(): _ville_ferme = true)

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
	if _calque_pause == null:
		_construire_menu_pause()
	if _calque_pause.visible:
		_fermer_menu_pause()
	elif not _accueil_visible():
		_pause_avant_menu = pause
		pause = true
		_calque_pause.visible = true

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
	_bande_on = true

func _demi_tour() -> void:
	if m.ordre_demi_tour():
		_ord_t = 0.0
		terrain.camera_x = m.convoi.back().x
		_look_x = 0.0
		for n in noeuds.values():
			n.queue_free()
		noeuds.clear()

func _basculer_garage() -> void:
	var v = m.trouver(selection)
	if v is CombatModele.Veh:
		if v.garage != 0:
			m.ordre_sortir(v.uid)
		else:
			m.ordre_garer(v.uid)


# --- Sauvegarde : reprise après rechargement de la page (iPhone) ---------------------
func _sauver_vue() -> void:
	if m == null or m.fini:
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(m.sauver()))

func _charger_sauvegarde() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if d is Dictionary and d.has("convoi") and not d.convoi.is_empty() and d.has("graine"):
		return d
	return {}

func _effacer_sauvegarde() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


# --- Interface -------------------------------------------------------------
func _maj_interface() -> void:
	for k in ["ammo", "fuel_l", "metal", "eau", "vivres"]:
		var l: Label = _chips[k][0]
		var val: float = m.stocks.get(k, 0.0)
		l.text = "∞" if val >= 99990.0 else ("%d" % int(ceil(val)) + (" L" if k == "fuel_l" else ""))
		var bas: bool = k in ["eau", "vivres"] and m.jours_de(k) < 1.0
		l.modulate = C_ROUGE if val <= 0.5 else (C_ACCENT if bas else Color.WHITE)
	_chips.pieces[0].text = "%d" % (m.composants.size() + m.pieces_stock.size())
	_horloge_ui.queue_redraw()
	_btn_atelier.visible = _atelier == null and not m.en_kit and not m.atelier_possible().is_empty()
	_btn_nouveau.visible = _atelier == null and _editeur == null and not m.en_kit and not m.fini
	_btn_pause.text = "Pause"
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
			cte.custom_minimum_size = Vector2(270, 96)
			cte.pressed.connect(func(): selectionner(v.uid))
			_boite_cartes.add_child(cte)
		if m.trouver(selection) == null or not (m.trouver(selection) in m.convoi):
			selection = m.convoi[0].uid if not m.convoi.is_empty() else 0
	for ch in _boite_cartes.get_children():
		ch.queue_redraw()
	var sel = m.trouver(selection)
	_bande_actions.visible = _bande_on and sel is CombatModele.Veh and sel in m.convoi
	_ord.visible = _ord_t > 0.0
	_btn_ordres.visible = _ord_t <= 0.0
	_btn_marche.text = "Halte" if m.ordres.marche == "avancer" else "Avancer"
	_btn_marche.disabled = m.ville_protegee() and not m.ville_dedans()
	if m.ville_dedans():
		_btn_marche.text = "Repartir…"
	elif m.ville_protegee():
		_btn_marche.text = "Entrée en ville" if m.ville_phase() in ["ouverture", "entree"] else "Sortie de la ville"
	if _bande_actions.visible:
		var ab_g = m.abri_garage()
		_btn_garage.text = "Sortir du garage" if sel.garage != 0 else "Garer (%s)" % ("ok" if ab_g != null else "aucun abri")
		_btn_garage.disabled = sel.garage == 0 and ab_g == null
		_btn_modifier.visible = true
		_btn_modifier.disabled = m.raison_grille(sel.uid) != ""
		_btn_demonter.visible = sel.garage != 0
		_maj_bouton_camp(sel)
		var travaille: bool = not m.travaux.is_empty() and m.travaux.uid == sel.uid
		_btn_demonter.text = "Démontage %d %%" % int(100.0 * (1.0 - m.travaux.reste / m.travaux.total)) if travaille else "Démonter"
		_btn_demonter.disabled = m.raison_demontage(sel.uid) != "" and not travaille
		_btn_feu.text = "Cessez-le-feu" if sel.tir else "Reprendre le feu"
		_btn_rep.text = "Arrêter" if sel.reparation else "Réparer"
		_btn_troupes.visible = int(sel.profil.get("places_troupes", 0)) > 0
		if _btn_troupes.visible:   # troupes : descendre des bancs ou y remonter
			var a_bord: int = sel.troupes_vivantes()
			var dehors: int = m.monde.troupes_dehors(sel.uid)
			_btn_troupes.text = ("Débarquer les troupes (%d)" % a_bord) if a_bord > 0 else (("Rembarquer les troupes (%d)" % dehors) if dehors > 0 else "Aucune troupe à bord")
			_btn_troupes.disabled = a_bord == 0 and dehors == 0
	if m.fini and not _fin_son:
		_fin_son = true
		var so := get_node_or_null("/root/Son")
		if so:   # musique du désert avec voix (ElevenLabs, à produire : mus_fin) ; en attendant, celle du menu
			so.moteur("")
			so.musique("mus_fin" if ResourceLoader.exists("res://assets/audio/mus_fin.mp3") else "mus_menu")
	_voile_fin.visible = m.fini and _fin_t > 5.0   # d'abord le dézoom, puis le bilan (DEC-055)
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
	var tempete: bool = m.tempete_annoncee() or m.tempete_active()
	var champ: Dictionary = m.champ_devant()
	var champ_vu: bool = not champ.is_empty() and champ.dist <= float(m.mines_cfg().alerte_m)
	var vf = w.voyageur_actuel()
	var camp = w.camp_proche()
	var vdial: bool = m.ville_dedans() and not _ville_ferme
	var dial: bool = vdial or vf != null or (camp != null and m.ordres.marche == "halte" and camp.uid != _camp_ferme)
	_panneau_alerte.visible = (m.camp_actif() or not al.is_empty() or poste or cache or m.mines.any(func(mn): return not mn.has("champ")) or not m.transits.is_empty() or not ann.is_empty() or nuit_alerte or tempete or champ_vu) and not dial and not _voile_carte.visible
	if _panneau_alerte.visible:
		var txt := ""
		if not al.is_empty():
			txt = "ENNEMIS EN APPROCHE\n%d véhicule(s), à %d m" % [al.n, int(al.dist)]
			if al.eta >= 0.0:
				txt += ", contact dans %d s" % int(al.eta)
		elif poste or cache:
			txt = "Embuscade en place : l'ennemi ne vous voit pas. La première salve surprend."
		if m.camp_actif():
			txt = _texte_camp() + ("\n\n" + txt if txt != "" else "")
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
		_btn_nuit.text = "S'abriter de la tempête" if tempete and not nuit_alerte else "Passer la nuit à l'abri"
		_btn_nuit.visible = (nuit_alerte or tempete) and not abri.is_empty()
		var lm := ""
		if m.tempete_annoncee():
			lm = "TEMPÊTE DE SABLE dans %d s : précision et vitesse réduites." % int(m.tempete.reste)
		elif m.tempete_active():
			lm = "TEMPÊTE DE SABLE (encore %d s) : précision ÷2, vitesse réduite, véhicules ouverts usés." % int(m.tempete.reste)
		if champ_vu:
			lm += ("\n" if lm != "" else "") + "CHAMP DE MINES à %d m (%d mines)%s" % [int(champ.dist), champ.n, " : déminage en cours" if not m.demin.is_empty() else ""]
		_lbl_meteo.text = lm
		_lbl_meteo.visible = lm != ""
		var moy: Array = m.moyens_demin()
		_btn_demin_det.visible = champ_vu and moy.has("detecteur") and m.demin.is_empty()
		_btn_demin_chien.visible = champ_vu and moy.has("chien") and m.demin.is_empty()
		_btn_traverser.visible = champ_vu and not m.champ_traverse and m.demin.is_empty()
		_btn_demin_det.disabled = m.raison_demin("detecteur") != ""
		_btn_demin_chien.disabled = m.raison_demin("chien") != ""
		_btn_embuscade.visible = not al.is_empty() or poste or cache
		_btn_mines.visible = not al.is_empty() or poste or cache
		_btn_sortir.visible = poste or cache or not m.transits.is_empty()
	# Dialogue : voyageur ou camp allié
	_panneau_dial.visible = dial and not _voile_carte.visible
	if _panneau_dial.visible and vdial:
		var sig_v := "ville|%s|%d|%d|%d|%d" % [_ville_onglet, int(m.stocks.metal), m.ville_cout_reparation(), int(m.stocks.get("eau", 0.0)), int(m.stocks.get("vivres", 0.0))]
		if sig_v != _dial_sig:
			_dial_sig = sig_v
			_remplir_ville()
	elif _panneau_dial.visible:
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
	_lbl_dist.text = "%s · %d m · Jour %d" % [sct.nom, int(m.x_tete), w.jour]
	if w.en_transit():
		if m.mission_en_route():   # mission du maire (DEC-146)
			_lbl_quete.text = "Mission : %s pour %s, %d m" % [String(CombatModele.MD().types[m.mission.type].nom).to_lower(), m.mission.dest_nom, int(w.trajet.reste)]
		else:
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
		_btn_fouille.position = Vector2(clampf(terrain.ecran_x(cx) - 130.0, _mg.g, size.x - 260.0 - _mg.d), maxf(150.0, _sy(cx) - (hf + 1.3) * ppm - 90.0))
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


# Panneau Kit du Mode créatif (DEC-110) : créé à chaque nouvelle partie, seulement en Mode créatif
func _installer_kit() -> void:
	if _kit != null:
		_kit.queue_free()
		_kit = null
	_btn_kit.visible = m.bac_a_sable
	if not m.bac_a_sable:
		return
	_kit = PanneauKit.new(m, func(): _demarrer_audio(), _ouvrir_vitrine_berliet, _ouvrir_carte_kit)
	_kit.set_anchors_and_offsets_preset(PRESET_RIGHT_WIDE)
	_kit.offset_left = -470
	_kit.offset_right = -20
	_kit.offset_top = 114
	_kit.offset_bottom = -(BARRE_H + 10)
	_kit.visible = false
	add_child(_kit)


# Vitrine du Berliet GDR (pièces interchangeables et halte de l'équipage), ouverte depuis le Kit ; le jeu est en pause
func _ouvrir_vitrine_berliet() -> void:
	var pause_avant := pause
	pause = true
	if _kit != null:
		_kit.visible = false
	var vit := VitrineBerliet.new()
	vit.modele = m   # les pièces choisies s'appliquent au camion du convoi
	_par_dessus(vit)
	vit.ferme.connect(func(): pause = pause_avant)


# Carte du monde de conception (DEC-154), ouverte depuis le Kit ; le jeu est en pause
func _ouvrir_carte_kit() -> CarteKit:
	var pause_avant := pause
	pause = true
	if _kit != null:
		_kit.visible = false
	var c := CarteKit.new()
	c.modele = m
	_par_dessus(c)
	c.ferme.connect(func(): pause = pause_avant)
	return c


func _basculer_kit() -> void:
	if _kit != null:
		_kit.visible = not _kit.visible
