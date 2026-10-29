# Affichage du prototype. Toute l'interface est construite ici, en code,
# pour rester lisible dans un seul fichier. La logique est dans jeu.gd.
extends Control

const PXM := 55.0          # pixels par mètre sur l'écran de base
const SOL_Y := 945.0       # ligne où se posent les bâtiments
const RUE_Y := 1062.0      # ligne où se garent les véhicules
const COUL_TEXTE := Color(0.95, 0.9, 0.8)
const COUL_ALERTE := Color(1.0, 0.55, 0.35)
const COUL_CRITIQUE := Color(1.0, 0.3, 0.25)

var jeu: Jeu
var base: Control            # écran de base
var carte: Control           # écran de carte
var scene_base: Control      # bâtiments, survivants, véhicules (reconstruit à chaque mise à jour)
var barre_res: HBoxContainer
var lbl_jour: Label
var lbl_journal: Label
var liste_surv: VBoxContainer
var panneau_convoi: PanelContainer
var rapport: Control
var lieu_choisi := ""
var choix_vehicules := {}    # uid -> CheckBox
var ordre_btn: OptionButton
var lbl_briefing: Label
var btn_partir: Button


func _ready() -> void:
	jeu = Jeu.new()
	theme = _theme()
	set_anchors_preset(PRESET_FULL_RECT)
	_construire_base()
	_construire_carte()
	_construire_rapport()
	_montrer(base)
	_maj()
	# Vérification visuelle : godot --path game -- --carte (ou --rapport)
	var args := OS.get_cmdline_user_args()
	if "--carte" in args:
		_ouvrir_carte()
		_choisir_lieu("oasis")
		choix_vehicules.values()[0].button_pressed = true
	if "--rapport" in args:
		jeu.stocks.fuel_l = 200
		jeu.R.lieux.depot.chance_pillards = 1.0
		_afficher_rapport(jeu.lancer("depot", jeu.vehicules_prets().slice(2, 3), "bout"))


# --- Outils d'affichage -----------------------------------------------------

func _tex(chemin: String) -> Texture2D:
	return load("res://assets/%s.png" % chemin)


func _image(chemin: String, largeur: float, parent: Control) -> TextureRect:
	var t := _tex(chemin)
	var r := TextureRect.new()
	r.texture = t
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.size = Vector2(largeur, largeur * t.get_height() / t.get_width())
	r.mouse_filter = MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r


func _label(texte: String, taille := 26, parent: Node = null) -> Label:
	var l := Label.new()
	l.text = texte
	l.add_theme_font_size_override("font_size", taille)
	if parent:
		parent.add_child(l)
	return l


func _bouton(texte: String, action: Callable, parent: Node) -> Button:
	var b := Button.new()
	b.text = texte
	b.custom_minimum_size = Vector2(0, 72)
	b.pressed.connect(action)
	parent.add_child(b)
	return b


func _panneau(parent: Node) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.1, 0.08, 0.82)
	sb.border_color = Color(0.55, 0.45, 0.3)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(14)
	p.add_theme_stylebox_override("panel", sb)
	parent.add_child(p)
	return p


func _theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 26
	t.set_color("font_color", "Label", COUL_TEXTE)
	for type in ["Button", "OptionButton"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.36, 0.3, 0.2)
		sb.set_corner_radius_all(6)
		sb.set_content_margin_all(12)
		t.set_stylebox("normal", type, sb)
		var sh := sb.duplicate()
		sh.bg_color = Color(0.48, 0.4, 0.26)
		t.set_stylebox("hover", type, sh)
		t.set_stylebox("pressed", type, sh)
		var sd := sb.duplicate()
		sd.bg_color = Color(0.25, 0.23, 0.2)
		t.set_stylebox("disabled", type, sd)
	return t


func _montrer(ecran: Control) -> void:
	base.visible = ecran == base
	carte.visible = ecran == carte


# --- Écran de base ----------------------------------------------------------

func _construire_base() -> void:
	base = Control.new()
	base.set_anchors_preset(PRESET_FULL_RECT)
	add_child(base)
	# Décor en couches (montage de référence : GRAPHISMES / PRODUCTION lot 3)
	var ciel := TextureRect.new()
	ciel.texture = _tex("decor/bg_desert_ciel")
	ciel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ciel.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	ciel.set_anchors_preset(PRESET_FULL_RECT)
	base.add_child(ciel)
	for c in [["lointain", 860.0], ["moyen", 960.0], ["sol", 1080.0]]:
		var r := TextureRect.new()
		var t := _tex("decor/bg_desert_" + c[0])
		r.texture = t
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_SCALE
		r.anchor_right = 1.0
		r.offset_top = c[1] - t.get_height()
		r.offset_bottom = c[1]
		base.add_child(r)
	scene_base = Control.new()
	base.add_child(scene_base)
	# Barre du haut : jour et ressources
	var haut := _panneau(base)
	haut.position = Vector2(16, 12)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 22)
	haut.add_child(hb)
	lbl_jour = _label("", 32, hb)
	barre_res = HBoxContainer.new()
	barre_res.add_theme_constant_override("separation", 22)
	hb.add_child(barre_res)
	# Journal (à gauche)
	var pj := _panneau(base)
	pj.position = Vector2(16, 120)
	pj.custom_minimum_size = Vector2(760, 0)
	lbl_journal = _label("", 22, pj)
	lbl_journal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_journal.custom_minimum_size = Vector2(730, 0)
	# Survivants (à droite)
	var ps := _panneau(base)
	ps.anchor_left = 1.0
	ps.anchor_right = 1.0
	ps.offset_left = -560
	ps.offset_right = -16
	ps.offset_top = 120
	var vs := VBoxContainer.new()
	ps.add_child(vs)
	_label("Survivants", 28, vs)
	liste_surv = VBoxContainer.new()
	vs.add_child(liste_surv)
	# Actions
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 16)
	actions.anchor_left = 1.0
	actions.anchor_right = 1.0
	actions.offset_left = -560
	actions.offset_right = -16
	actions.offset_top = 560
	base.add_child(actions)
	var b1 := _bouton("Passer la journée", _passer, actions)
	var b2 := _bouton("Expédition", func(): _ouvrir_carte(), actions)
	b1.size_flags_horizontal = SIZE_EXPAND_FILL
	b2.size_flags_horizontal = SIZE_EXPAND_FILL


func _maj() -> void:
	lbl_jour.text = "Jour %d" % jeu.jour
	# Ressources
	for c in barre_res.get_children():
		c.queue_free()
	for res in jeu.R.ressources:
		var info: Dictionary = jeu.R.ressources[res]
		var box := HBoxContainer.new()
		barre_res.add_child(box)
		var ic := TextureRect.new()
		ic.texture = _tex("ui/" + info.icone)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.custom_minimum_size = Vector2(56, 56)
		box.add_child(ic)
		var txt := "%d" % jeu.stocks[res]
		var auto := jeu.autonomie(res)
		var l := _label(txt, 26, box)
		if auto < INF:
			l.text += "  (%.1f j)" % auto
			if auto < 1.0:
				l.add_theme_color_override("font_color", COUL_CRITIQUE)
			elif auto < 2.0:
				l.add_theme_color_override("font_color", COUL_ALERTE)
		l.tooltip_text = info.nom
	if jeu.penurie:
		var p := _label("PÉNURIE", 26, barre_res)
		p.add_theme_color_override("font_color", COUL_CRITIQUE)
	# Journal : dernières lignes
	lbl_journal.text = "\n".join(jeu.journal.slice(max(0, jeu.journal.size() - 7)))
	_maj_survivants()
	_maj_scene()


func _maj_survivants() -> void:
	for c in liste_surv.get_children():
		c.queue_free()
	for s in jeu.survivants:
		var h := HBoxContainer.new()
		liste_surv.add_child(h)
		var n := _label(s.nom, 26, h)
		n.custom_minimum_size = Vector2(170, 0)
		if s.occupe > 0:
			_label("en expédition (%d j)" % s.occupe, 24, h)
		elif s.blesse > 0:
			_label("blessé(e) (%d j)" % s.blesse, 24, h).add_theme_color_override("font_color", COUL_ALERTE)
		else:
			var ob := OptionButton.new()
			for p in Jeu.POSTES:
				ob.add_item(jeu.R.postes[p].nom)
			ob.selected = Jeu.POSTES.find(s.poste)
			ob.custom_minimum_size = Vector2(300, 64)
			ob.item_selected.connect(func(i): s.poste = Jeu.POSTES[i]; _maj_scene())
			h.add_child(ob)


func _maj_scene() -> void:
	for c in scene_base.get_children():
		c.queue_free()
	var centres := {}
	for b in jeu.R.batiments:
		var r := _image("batiments/" + b.image, b.largeur_m * PXM, scene_base)
		r.position = Vector2(60 + b.x_m * PXM, SOL_Y - r.size.y)
		centres[b.id] = r.position.x + r.size.x / 2
	# Survivants devant leur poste (au repos : devant l'entrepôt)
	var decal := {}
	for s in jeu.survivants:
		if s.occupe > 0:
			continue
		var cle: String = s.poste if s.poste != "repos" else "entrepot"
		var pose := "debout" if s.poste == "repos" or s.blesse > 0 else "travaille"
		var img := "personnages/pers_%s_%s" % ["survivante" if s.femme else "survivant", pose]
		var t := _tex(img)
		var h := 1.75 * PXM * (0.75 if pose == "travaille" else 1.0)
		var r := _image(img, h * t.get_width() / t.get_height(), scene_base)
		var d: float = decal.get(cle, 0.0)
		decal[cle] = d + r.size.x + 6
		r.position = Vector2(centres[cle] - 40 + d, SOL_Y + 20 - r.size.y)
		if s.blesse > 0:
			r.modulate = Color(1, 0.75, 0.75)
	# Véhicules garés
	var x := 80.0
	for v in jeu.vehicules:
		var r := _image("vehicules/" + v.type, jeu.stat(v.type, "longueur_m") * PXM, scene_base)
		r.position = Vector2(x, RUE_Y - r.size.y)
		var etat := "%s  %d/%d" % [jeu.stat(v.type, "nom"), v.pv, v.pv_max]
		if v.etat == "epave":
			r.modulate = Color(0.45, 0.42, 0.4)
			etat = "%s  ÉPAVE" % jeu.stat(v.type, "nom")
		var l := _label(etat, 20, scene_base)
		l.position = Vector2(x, RUE_Y - r.size.y - 30)
		x += max(r.size.x, l.get_minimum_size().x) + 40


func _passer() -> void:
	jeu.passer_journee()
	_maj()
	if jeu.perdu():
		_afficher_fin()


# --- Carte et convoi --------------------------------------------------------

func _construire_carte() -> void:
	carte = Control.new()
	carte.set_anchors_preset(PRESET_FULL_RECT)
	add_child(carte)
	var fond := TextureRect.new()
	fond.texture = _tex("carte/carte_fond")
	fond.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fond.stretch_mode = TextureRect.STRETCH_SCALE
	fond.set_anchors_preset(PRESET_FULL_RECT)
	carte.add_child(fond)
	var routes := Routes.new()
	routes.set_anchors_preset(PRESET_FULL_RECT)
	routes.mouse_filter = MOUSE_FILTER_IGNORE
	routes.main = self
	carte.add_child(routes)
	_icone_lieu("carte/carte_icone_base", jeu.R.base_pos, "Base", Callable())
	for id in jeu.R.lieux:
		var l: Dictionary = jeu.R.lieux[id]
		_icone_lieu("carte/" + l.icone, l.pos, l.nom, func(): _choisir_lieu(id))
	var retour := _bouton("Retour à la base", func(): _montrer(base); _maj(), carte)
	retour.position = Vector2(24, 20)
	panneau_convoi = _panneau(carte)
	panneau_convoi.anchor_left = 1.0
	panneau_convoi.anchor_right = 1.0
	panneau_convoi.offset_left = -640
	panneau_convoi.offset_right = -16
	panneau_convoi.offset_top = 16


func _icone_lieu(img: String, pos: Array, nom: String, action: Callable) -> void:
	var b := TextureButton.new()
	b.texture_normal = _tex(img)
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	b.size = Vector2(130, 130)
	b.anchor_left = pos[0]
	b.anchor_right = pos[0]
	b.anchor_top = pos[1]
	b.anchor_bottom = pos[1]
	b.offset_left = -65
	b.offset_right = 65
	b.offset_top = -65
	b.offset_bottom = 65
	if action.is_valid():
		b.pressed.connect(action)
	carte.add_child(b)
	var l := _label(nom, 24, b)
	l.position = Vector2(-40, 128)
	l.add_theme_color_override("font_color", Color(0.15, 0.1, 0.05))


func _ouvrir_carte() -> void:
	lieu_choisi = ""
	panneau_convoi.visible = false
	_montrer(carte)


func _choisir_lieu(id: String) -> void:
	lieu_choisi = id
	var l: Dictionary = jeu.R.lieux[id]
	for c in panneau_convoi.get_children():
		c.queue_free()
	panneau_convoi.visible = true
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panneau_convoi.add_child(vb)
	_label(l.nom, 30, vb)
	var butin := []
	for res in l.butin:
		butin.append(jeu.R.ressources[res].nom.to_lower())
	_label("%d h de route (aller). Butin : %s." % [l.heures, ", ".join(butin)], 22, vb).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label("Véhicules (1 survivant par véhicule)", 24, vb)
	choix_vehicules.clear()
	for v in jeu.vehicules_prets():
		var cb := CheckBox.new()
		cb.text = "%s  (%d/%d PV)" % [jeu.stat(v.type, "nom"), v.pv, v.pv_max]
		cb.custom_minimum_size = Vector2(0, 56)
		cb.toggled.connect(func(_on): _maj_briefing())
		vb.add_child(cb)
		choix_vehicules[v.uid] = cb
	ordre_btn = OptionButton.new()
	for o in Jeu.ORDRES:
		ordre_btn.add_item(Jeu.ORDRES[o])
	ordre_btn.selected = 1
	ordre_btn.custom_minimum_size = Vector2(0, 64)
	vb.add_child(ordre_btn)
	lbl_briefing = _label("", 22, vb)
	lbl_briefing.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_briefing.custom_minimum_size = Vector2(600, 0)
	btn_partir = _bouton("Partir", _partir, vb)
	_maj_briefing()


func _convoi() -> Array:
	return jeu.vehicules_prets().filter(func(v): return choix_vehicules.has(v.uid) and choix_vehicules[v.uid].button_pressed)


func _maj_briefing() -> void:
	var b := jeu.briefing(lieu_choisi, _convoi())
	var t := "Carburant : %d L (conseillé %d L, stock %d L)\nVivres : %d L d'eau, %d rations\nCapacité de chargement : %d\nÉquipage : %s\nRisque %s : %s" % [
		b.carburant, b.carburant_conseille, jeu.stocks.fuel_l, b.eau, b.vivres, b.capacite,
		", ".join(b.equipage) if b.equipage else "—", b.risque, " ; ".join(b.raisons)]
	if not b.ok:
		t += "\n" + "\n".join(b.erreurs)
	lbl_briefing.text = t
	btn_partir.disabled = not b.ok


func _partir() -> void:
	var ordre: String = Jeu.ORDRES.keys()[ordre_btn.selected]
	var rap := jeu.lancer(lieu_choisi, _convoi(), ordre)
	_montrer(base)
	_maj()
	_afficher_rapport(rap)


# --- Rapport ----------------------------------------------------------------

func _construire_rapport() -> void:
	rapport = ColorRect.new()
	rapport.color = Color(0, 0, 0, 0.6)
	rapport.set_anchors_preset(PRESET_FULL_RECT)
	rapport.visible = false
	add_child(rapport)


func _afficher_rapport(rap: Dictionary) -> void:
	for c in rapport.get_children():
		c.queue_free()
	rapport.visible = true
	var p := _panneau(rapport)
	p.set_anchors_preset(PRESET_CENTER)
	p.custom_minimum_size = Vector2(1500, 860)
	p.position = (get_viewport_rect().size - p.custom_minimum_size) / 2
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	p.add_child(vb)
	_label(rap.titre, 34, vb)
	# File du convoi (vers la droite) face aux pillards (vers la gauche)
	var file := HBoxContainer.new()
	file.add_theme_constant_override("separation", 24)
	file.alignment = BoxContainer.ALIGNMENT_CENTER
	file.custom_minimum_size = Vector2(0, 200)
	vb.add_child(file)
	var convoi: Array = rap.convoi.duplicate()
	convoi.reverse()   # la tête est à droite, face à l'ennemi
	for v in convoi:
		_vignette(v, false, file)
	if rap.pillards:
		_label("  ⟷  ", 40, file)
		for v in rap.pillards:
			_vignette(v, true, file)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = SIZE_EXPAND_FILL
	vb.add_child(sc)
	var lignes := _label("\n".join(rap.lignes), 24, sc)
	lignes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lignes.custom_minimum_size = Vector2(1440, 0)
	_bouton("Fermer", func(): rapport.visible = false; _maj(), vb)


func _vignette(v: Dictionary, ennemi: bool, parent: Node) -> void:
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_END
	parent.add_child(vb)
	var r := TextureRect.new()
	r.texture = _tex("vehicules/" + v.type)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	r.custom_minimum_size = Vector2(jeu.stat(v.type, "longueur_m") * 34, 110)
	r.flip_h = ennemi
	vb.add_child(r)
	var etat: String = {"ok": "intact", "epave": "épave", "perdu": "perdu", "detruit": "détruit"}[v.etat]
	if v.etat != "ok":
		r.modulate = Color(0.4, 0.35, 0.3)
	var l := _label(etat, 20, vb)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if ennemi:
		l.add_theme_color_override("font_color", COUL_ALERTE)


func _afficher_fin() -> void:
	_afficher_rapport({"titre": "La communauté s'est éteinte", "convoi": [], "pillards": [],
		"lignes": ["Plus aucun survivant. Une nouvelle partie commence à la fermeture."]})
	jeu.nouvelle_partie()


# Routes en pointillés entre la base et les lieux.
class Routes extends Control:
	var main
	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()
	func _draw() -> void:
		var R: Dictionary = main.jeu.R
		var b := Vector2(R.base_pos[0], R.base_pos[1]) * size
		for id in R.lieux:
			var p := Vector2(R.lieux[id].pos[0], R.lieux[id].pos[1]) * size
			draw_dashed_line(b, p, Color(0.35, 0.15, 0.05, 0.8), 5.0, 18.0)
