# Couche 2 de la vue : construction et mise à jour de l'interface, actions du joueur, sauvegarde.
extends "res://scripts/combat/vue_dessin.gd"


# --- Construction ----------------------------------------------------------
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
	_btn_atelier = _bouton("Assembler", func(): _ouvrir_atelier(), hb, 190)
	_btn_atelier.visible = false
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
	ord.visible = false
	_ord = ord
	bb.add_child(ord)
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
	_btn_marche = _bouton("Avancer", func(): m.ordre_marche("halte" if m.ordres.marche == "avancer" else "avancer"), self, 300)
	_btn_marche.set_anchors_and_offsets_preset(PRESET_BOTTOM_RIGHT)
	_btn_marche.offset_left = -320
	_btn_marche.offset_right = -16
	_btn_marche.offset_top = -BARRE_H - 76
	_btn_marche.offset_bottom = -BARRE_H - 12
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
	_btn_garage = _bouton("Garer", func(): _basculer_garage(), ab, 170)
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
func _nouvelle_partie(g: int, sauve := {}, ouverture := true) -> void:
	graine = g
	if _atelier != null:
		_atelier.queue_free()
		_atelier = null
	if sauve.is_empty():
		_effacer_sauvegarde()
		m = CombatModele.new(g, {"ouverture": ouverture})   # début guidé : moto à assembler (DEC-035)
	else:
		m = CombatModele.depuis_sauvegarde(sauve)
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
	selection = m.convoi[0].uid if not m.convoi.is_empty() else 0
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
	add_child(_atelier)
	_atelier.ferme.connect(func(_ok: bool):
		_atelier = null
		pause = pause_avant and not m.convoi.is_empty()
		if selection == 0 and not m.convoi.is_empty():
			selection = m.convoi[0].uid
			terrain.camera_x = m.convoi.back().x)

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
	for k in ["ammo", "fuel_l", "metal"]:
		var l: Label = _chips[k][0]
		var val: float = m.stocks[k]
		var txt: String = "%s %d" % [_chips[k][1], int(val)]
		if k == "fuel_l":
			txt += " L"
		l.text = txt
		l.modulate = C_ROUGE if val <= 0.5 else Color.WHITE
	_chips.pieces[0].text = "Pièces %d" % (m.composants.size() + m.pieces_stock.size())
	_btn_atelier.visible = _atelier == null and not m.en_kit and not m.atelier_possible().is_empty()
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
	_bande_actions.visible = _bande_on and sel is CombatModele.Veh and sel in m.convoi
	_ord.visible = _ord_t > 0.0
	_btn_ordres.visible = _ord_t <= 0.0
	_btn_marche.text = "Halte" if m.ordres.marche == "avancer" else "Avancer"
	if _bande_actions.visible:
		var ab_g = m.abri_garage()
		_btn_garage.text = "Sortir du garage" if sel.garage != 0 else "Garer (%s)" % ("ok" if ab_g != null else "aucun abri")
		_btn_garage.disabled = sel.garage == 0 and ab_g == null
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
