# Affichage du prototype. Toute l'interface est construite ici, en code,
# pour rester lisible dans un seul fichier. La logique est dans jeu.gd.
#
# Style : panneaux sombres translucides à coins arrondis, police Inter,
# une seule couleur d'accent (ambre). Le décor va jusqu'aux bords de l'écran ;
# l'interface respecte les zones sûres de l'iPhone (encoche, barre d'accueil).
extends Control

const PXM := 55.0          # pixels par mètre dans la scène de base
const SOL_Y := 945.0       # ligne où se posent les bâtiments
const RUE_Y := 1062.0      # ligne où se garent les véhicules
const ZOOM_MIN := 1.0
const ZOOM_MAX := 2.6

# Palette
const C_TEXTE := Color("#F2EEE6")
const C_DISCRET := Color("#A8A196")
const C_ACCENT := Color("#E8A33D")
const C_VERT := Color("#6CC27A")
const C_ORANGE := Color("#F0A040")
const C_ROUGE := Color("#E5594F")
const C_PANNEAU := Color(0.07, 0.075, 0.08, 0.80)
const C_BORD := Color(1, 1, 1, 0.09)
const C_RES := {"water_l": "#5AA9E6", "food": "#8CC152", "fuel_l": "#E8A33D",
	"metal": "#9AA4AE", "materials": "#C08A5B", "ammo": "#B3A65A"}

var jeu: Jeu
var police: Font
var police_gras: Font
var marges := Vector4(24, 20, 24, 20)    # gauche, haut, droite, bas (zones sûres comprises)

var base: Control
var monde: Control           # décor + scène, zoomable
var scene_base: Control      # bâtiments, survivants, véhicules
var carte: Control
var hud_res: HBoxContainer
var lbl_jour: Label
var lbl_journal: Label
var liste_surv: VBoxContainer
var panneau_convoi: PanelContainer
var rapport: Control

var lieu_choisi := ""
var mode_pied := false
var nb_pied := 1
var choix_vehicules := {}    # uid -> Button (bascule)
var ordre_btn: OptionButton
var lbl_briefing: Label
var btn_partir: Button

var lbl_heure: Label
var en_route: VBoxContainer
var ciel: TextureRect
var file_rapports := []      # rapports à montrer l'un après l'autre
var _chrono := 0.0

var zoom := 1.0
var _touches := {}           # index du doigt -> position (zoom à deux doigts)
var menus: Menus
var garage: Garage


func _ready() -> void:
	jeu = Jeu.new()
	police = load("res://assets/fonts/Inter-Medium.otf")
	police_gras = load("res://assets/fonts/Inter-Bold.otf")
	theme = _theme()
	set_anchors_preset(PRESET_FULL_RECT)
	_lire_zones_sures()
	_construire_base()
	_construire_carte()
	_construire_rapport()
	menus = Menus.new()
	menus.main = self
	add_child(menus)
	_montrer(base)
	var args := OS.get_cmdline_user_args()
	if "--neuve" in args:
		jeu.effacer_partie()
	# Rattrapage des heures passées hors du jeu, puis rapport de retour
	_avancer(jeu.rattraper())
	jeu.signaler_action()
	# Vérification visuelle : godot --path game -- --neuve --carte | --pied | --rapport | --zoom | --revolte
	#                         | --base | --pause | --garage=<véhicule> | --personnages  (sans option : menu principal)
	var test := false
	for a in args:
		test = test or (a.begins_with("--") and not a.begins_with("--capture") and a != "--neuve")
	if test:
		menus.titre.visible = false
		_entrer_base()
	else:
		menus.afficher_titre()
	if "--pause" in args:
		menus.basculer_pause()
	for a in args:
		if a.begins_with("--garage") or a == "--personnages":
			_ouvrir_garage()
			if a.begins_with("--garage="):
				garage._choisir(garage.types.find(a.split("=")[1]))
			if a == "--personnages":
				garage._basculer_mode()
	if "--carte" in args or "--pied" in args:
		_ouvrir_carte()
		_choisir_lieu("mine" if "--pied" in args else "oasis")
		if "--pied" in args:
			_changer_mode(true)
		else:
			choix_vehicules.values()[0].button_pressed = true
	if "--zoom" in args:
		_zoomer(2.0, get_viewport_rect().size * Vector2(0.3, 0.8))
	if "--rapport" in args:
		jeu.stocks.fuel_l = 200
		jeu.R.lieux.depot.chance_pillards = 1.0
		jeu.lancer("depot", jeu.vehicules_prets().slice(2, 3), "bout")
		_avancer(jeu.avancer_tests(13))
	if "--revolte" in args:
		jeu.stocks.water_l = 0
		jeu.stocks.food = 0
		_avancer(jeu.avancer_tests(50))
	for a in args:   # --capture=fichier.png : image de l'écran puis fermeture
		if a.begins_with("--capture="):
			for i in 4:
				await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png(a.split("=")[1])
			get_tree().quit()


# --- Zones sûres (iPhone) ---------------------------------------------------
# Sur le Web, la page expose les marges de l'encoche (voir export_presets.cfg,
# html/head_include). On les convertit en pixels du jeu.

func _lire_zones_sures() -> void:
	if not OS.has_feature("web"):
		return
	var txt = JavaScriptBridge.eval("window.fmZonesSures ? window.fmZonesSures() : ''")
	if typeof(txt) != TYPE_STRING or txt == "":
		return
	var v: PackedStringArray = txt.split(",")
	if v.size() < 5:
		return
	var k: float = get_viewport_rect().size.x / maxf(1.0, v[4].to_float())   # px du jeu par px CSS
	marges = Vector4(24 + v[0].to_float() * k, 20 + v[1].to_float() * k,
		24 + v[2].to_float() * k, 20 + v[3].to_float() * k)


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


func _label(texte: String, taille := 28, parent: Node = null, couleur := C_TEXTE, gras := false) -> Label:
	var l := Label.new()
	l.text = texte
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", couleur)
	if gras:
		l.add_theme_font_override("font", police_gras)
	if parent:
		parent.add_child(l)
	return l


func _bouton(texte: String, action: Callable, parent: Node, principal := false) -> Button:
	var b := Button.new()
	b.text = texte
	b.custom_minimum_size = Vector2(0, 80)
	b.pressed.connect(action)
	b.pressed.connect(func(): Son.effet("sfx_ui_clic"))
	if principal:
		b.theme_type_variation = "BoutonPrincipal"
	parent.add_child(b)
	return b


func _boite(fond: Color, rayon := 20, bord := C_BORD, marge := 22.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fond
	sb.border_color = bord
	sb.set_border_width_all(1 if bord.a > 0 else 0)
	sb.set_corner_radius_all(rayon)
	sb.set_content_margin_all(marge)
	sb.anti_aliasing = true
	return sb


func _panneau(parent: Node, marge := 22.0) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := _boite(C_PANNEAU, 22, C_BORD, marge)
	sb.shadow_color = Color(0, 0, 0, 0.30)
	sb.shadow_size = 14
	sb.shadow_offset = Vector2(0, 4)
	p.add_theme_stylebox_override("panel", sb)
	parent.add_child(p)
	return p


func _puce(texte: String, couleur: Color, parent: Node) -> PanelContainer:
	# Petite étiquette arrondie (statut, risque).
	var p := PanelContainer.new()
	var sb := _boite(Color(couleur, 0.18), 12, Color(0, 0, 0, 0), 0)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", sb)
	_label(texte, 22, p, couleur)
	parent.add_child(p)
	return p


func _theme() -> Theme:
	var t := Theme.new()
	t.default_font = police
	t.default_font_size = 28
	t.set_color("font_color", "Label", C_TEXTE)
	# Boutons secondaires : verre clair
	for type in ["Button", "OptionButton"]:
		t.set_stylebox("normal", type, _boite(Color(1, 1, 1, 0.08), 16, Color(1, 1, 1, 0.10), 18))
		t.set_stylebox("hover", type, _boite(Color(1, 1, 1, 0.14), 16, Color(1, 1, 1, 0.16), 18))
		t.set_stylebox("pressed", type, _boite(Color(C_ACCENT, 0.22), 16, C_ACCENT, 18))
		t.set_stylebox("hover_pressed", type, _boite(Color(C_ACCENT, 0.28), 16, C_ACCENT, 18))
		t.set_stylebox("disabled", type, _boite(Color(1, 1, 1, 0.04), 16, Color(0, 0, 0, 0), 18))
		t.set_stylebox("focus", type, StyleBoxEmpty.new())
		t.set_color("font_color", type, C_TEXTE)
		t.set_color("font_hover_color", type, C_TEXTE)
		t.set_color("font_pressed_color", type, C_TEXTE)
		t.set_color("font_hover_pressed_color", type, C_TEXTE)
		t.set_color("font_focus_color", type, C_TEXTE)
		t.set_color("font_disabled_color", type, Color(C_TEXTE, 0.35))
	# Bouton principal : ambre plein, texte sombre
	t.set_type_variation("BoutonPrincipal", "Button")
	var fonce := Color("#1B1712")
	t.set_stylebox("normal", "BoutonPrincipal", _boite(C_ACCENT, 16, Color(0, 0, 0, 0), 18))
	t.set_stylebox("hover", "BoutonPrincipal", _boite(C_ACCENT.lightened(0.12), 16, Color(0, 0, 0, 0), 18))
	t.set_stylebox("pressed", "BoutonPrincipal", _boite(C_ACCENT.darkened(0.12), 16, Color(0, 0, 0, 0), 18))
	t.set_stylebox("disabled", "BoutonPrincipal", _boite(Color(C_ACCENT, 0.25), 16, Color(0, 0, 0, 0), 18))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(c, "BoutonPrincipal", fonce)
	t.set_color("font_disabled_color", "BoutonPrincipal", Color(fonce, 0.5))
	t.set_font("font", "BoutonPrincipal", police_gras)
	# Menus déroulants
	t.set_stylebox("panel", "PopupMenu", _boite(Color("#1A1C1E"), 16, Color(1, 1, 1, 0.12), 10))
	t.set_stylebox("hover", "PopupMenu", _boite(Color(C_ACCENT, 0.25), 10, Color(0, 0, 0, 0), 8))
	t.set_font_size("font_size", "PopupMenu", 30)
	t.set_color("font_color", "PopupMenu", C_TEXTE)
	t.set_color("font_hover_color", "PopupMenu", C_TEXTE)
	t.set_constant("v_separation", "PopupMenu", 18)
	# Barres de progression (ressources)
	t.set_stylebox("background", "ProgressBar", _boite(Color(1, 1, 1, 0.10), 6, Color(0, 0, 0, 0), 0))
	t.set_stylebox("fill", "ProgressBar", _boite(C_ACCENT, 6, Color(0, 0, 0, 0), 0))
	# Ascenseur fin
	t.set_stylebox("scroll", "VScrollBar", _boite(Color(1, 1, 1, 0.04), 4, Color(0, 0, 0, 0), 2))
	t.set_stylebox("grabber", "VScrollBar", _boite(Color(1, 1, 1, 0.25), 4, Color(0, 0, 0, 0), 2))
	t.set_stylebox("tooltip_panel", "TooltipPanel", _boite(Color("#1A1C1E"), 10, C_BORD, 10))
	# Curseurs (volumes)
	var rail := _boite(Color(1, 1, 1, 0.12), 6, Color(0, 0, 0, 0), 0)
	rail.content_margin_top = 6
	rail.content_margin_bottom = 6
	t.set_stylebox("slider", "HSlider", rail)
	var plein := _boite(C_ACCENT, 6, Color(0, 0, 0, 0), 0)
	plein.content_margin_top = 6
	plein.content_margin_bottom = 6
	t.set_stylebox("grabber_area", "HSlider", plein)
	t.set_stylebox("grabber_area_highlight", "HSlider", plein)
	return t


func _montrer(ecran: Control) -> void:
	base.visible = ecran == base
	carte.visible = ecran == carte


# --- Écran de base ----------------------------------------------------------

func _construire_base() -> void:
	base = Control.new()
	base.set_anchors_preset(PRESET_FULL_RECT)
	base.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(base)
	# Ciel fixe, plein écran
	ciel = TextureRect.new()
	ciel.texture = _tex("decor/bg_desert_ciel")
	ciel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ciel.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	ciel.set_anchors_preset(PRESET_FULL_RECT)
	ciel.mouse_filter = MOUSE_FILTER_IGNORE
	base.add_child(ciel)
	# Monde zoomable : couches de décor + scène
	monde = Control.new()
	monde.mouse_filter = MOUSE_FILTER_IGNORE
	monde.size = get_viewport_rect().size
	base.add_child(monde)
	for c in [["lointain", 860.0], ["moyen", 960.0], ["sol", 1080.0]]:
		var r := TextureRect.new()
		var t := _tex("decor/bg_desert_" + c[0])
		r.texture = t
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_SCALE
		r.mouse_filter = MOUSE_FILTER_IGNORE
		r.anchor_right = 1.0
		r.offset_top = c[1] - t.get_height()
		r.offset_bottom = c[1]
		monde.add_child(r)
	scene_base = Control.new()
	scene_base.mouse_filter = MOUSE_FILTER_IGNORE
	monde.add_child(scene_base)
	# Zone tactile : glisser pour déplacer, pincer ou molette pour zoomer
	var zone := Control.new()
	zone.set_anchors_preset(PRESET_FULL_RECT)
	zone.gui_input.connect(_entree_zoom)
	base.add_child(zone)
	resized.connect(func(): monde.size = get_viewport_rect().size; _zoomer(zoom, Vector2.ZERO))

	# Bandeau des ressources (haut, pleine largeur)
	var haut := _panneau(base, 16)
	haut.anchor_right = 1.0
	haut.offset_left = marges.x
	haut.offset_right = -marges.z
	haut.offset_top = marges.y
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	haut.add_child(hb)
	var bloc_jour := VBoxContainer.new()
	bloc_jour.custom_minimum_size = Vector2(130, 0)
	bloc_jour.alignment = BoxContainer.ALIGNMENT_CENTER
	bloc_jour.add_theme_constant_override("separation", -6)
	hb.add_child(bloc_jour)
	_label("JOUR", 20, bloc_jour, C_DISCRET, true)
	lbl_jour = _label("", 52, bloc_jour, C_TEXTE, true)
	lbl_heure = _label("", 20, bloc_jour, C_DISCRET)
	hud_res = HBoxContainer.new()
	hud_res.add_theme_constant_override("separation", 14)
	hud_res.size_flags_horizontal = SIZE_EXPAND_FILL
	hb.add_child(hud_res)
	var bp := _bouton("II", func(): menus.basculer_pause(), hb)
	bp.custom_minimum_size = Vector2(90, 90)
	bp.size_flags_vertical = SIZE_SHRINK_CENTER
	bp.add_theme_font_override("font", police_gras)
	bp.tooltip_text = "Pause"

	# Journal (gauche)
	var pj := _panneau(base, 20)
	pj.position = Vector2(marges.x, marges.y + 170)
	pj.custom_minimum_size = Vector2(720, 0)
	var vj := VBoxContainer.new()
	vj.add_theme_constant_override("separation", 8)
	pj.add_child(vj)
	_label("JOURNAL", 20, vj, C_DISCRET, true)
	lbl_journal = _label("", 24, vj, Color(C_TEXTE, 0.9))
	lbl_journal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_journal.custom_minimum_size = Vector2(676, 0)
	lbl_journal.add_theme_constant_override("line_spacing", 4)

	# Survivants + actions (droite)
	var ps := _panneau(base, 20)
	ps.anchor_left = 1.0
	ps.anchor_right = 1.0
	ps.offset_left = -600 - marges.z
	ps.offset_right = -marges.z
	ps.offset_top = marges.y + 170
	var vs := VBoxContainer.new()
	vs.add_theme_constant_override("separation", 12)
	ps.add_child(vs)
	_label("SURVIVANTS", 20, vs, C_DISCRET, true)
	liste_surv = VBoxContainer.new()
	liste_surv.add_theme_constant_override("separation", 10)
	vs.add_child(liste_surv)
	en_route = VBoxContainer.new()
	en_route.add_theme_constant_override("separation", 6)
	vs.add_child(en_route)
	vs.add_child(HSeparator.new())
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	vs.add_child(actions)
	# Bouton de test : fait avancer l'horloge de 6 h (retiré du jeu final)
	_bouton("Test +6 h", func(): _avancer(jeu.avancer_tests(6)), actions).size_flags_horizontal = SIZE_EXPAND_FILL
	_bouton("Expédition", func(): _ouvrir_carte(), actions, true).size_flags_horizontal = SIZE_EXPAND_FILL

	# Zoom (bas droite, hors des véhicules), utile sur ordinateur
	var pz := _panneau(base, 10)
	pz.anchor_left = 1.0
	pz.anchor_right = 1.0
	pz.anchor_top = 1.0
	pz.anchor_bottom = 1.0
	pz.grow_horizontal = GROW_DIRECTION_BEGIN
	pz.grow_vertical = GROW_DIRECTION_BEGIN
	pz.offset_right = -marges.z
	pz.offset_bottom = -marges.w
	var zb := HBoxContainer.new()
	zb.add_theme_constant_override("separation", 10)
	pz.add_child(zb)
	for z in [["−", 1.0 / 1.25], ["+", 1.25]]:
		var b := _bouton(z[0], func(): _zoomer(zoom * z[1], get_viewport_rect().size / 2), zb)
		b.custom_minimum_size = Vector2(80, 80)
		b.add_theme_font_size_override("font_size", 40)
	_bouton("Vue d'ensemble", func(): _zoomer(1.0, Vector2.ZERO), zb)


func _maj() -> void:
	lbl_jour.text = str(jeu.jour())
	var jour_ := jeu.est_jour()
	lbl_heure.text = "%02d h · %s" % [jeu.heure_locale(), "jour" if jour_ else "nuit"]
	# Nuit : simple voile de lumière sur le décor (GRAPHISMES : pas d'images de nuit)
	var teinte := Color.WHITE if jour_ else Color(0.42, 0.48, 0.68)
	monde.modulate = teinte
	ciel.modulate = teinte
	if base.visible and menus and not menus.titre_visible():
		Son.ambiance("amb_desert_jour" if jour_ else "amb_desert_nuit")
	for c in en_route.get_children():
		c.queue_free()
	if jeu.expeditions:
		_label("EN ROUTE", 20, en_route, C_DISCRET, true)
	for e in jeu.expeditions:
		var reste := int(ceil((e.retour - jeu.t) / 3600.0))
		_label("%s %s · retour dans %d h" % ["À pied :" if e.pied else "Convoi :", jeu.R.lieux[e.lieu].nom, reste], 22, en_route)
	for c in hud_res.get_children():
		c.queue_free()
	for res in jeu.R.ressources:
		hud_res.add_child(_carte_ressource(res))
	if jeu.etape > 0:
		var noms := ["", "PÉNURIE", "MALADIE", "AGITATION"]
		_puce("%s · étape %d" % [noms[jeu.etape], jeu.etape], C_ROUGE, hud_res)
	lbl_journal.text = "\n".join(jeu.journal.slice(max(0, jeu.journal.size() - 6)))
	_maj_survivants()
	_maj_scene()


# Une ressource : icône, nom, quantité, barre de remplissage et flèche de tendance.
func _carte_ressource(res: String) -> Control:
	var info: Dictionary = jeu.R.ressources[res]
	var stock: float = jeu.stocks[res]
	var cap: float = info.capacite
	var auto := jeu.autonomie(res)
	var solde := jeu.bilan(res)
	var h := HBoxContainer.new()
	h.size_flags_horizontal = SIZE_EXPAND_FILL
	h.add_theme_constant_override("separation", 10)
	var ic := TextureRect.new()
	ic.texture = _tex("ui/" + info.icone)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.custom_minimum_size = Vector2(52, 52)
	h.add_child(ic)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 4)
	h.add_child(v)
	var l1 := HBoxContainer.new()
	v.add_child(l1)
	var nom := _label(info.nom, 20, l1, C_DISCRET)
	nom.size_flags_horizontal = SIZE_EXPAND_FILL
	nom.clip_text = true
	var unite: String = (" " + info.unite) if info.unite == "L" else ""
	_label("%d%s" % [stock, unite], 26, l1, C_TEXTE, true)
	# Barre + tendance
	var l2 := HBoxContainer.new()
	l2.add_theme_constant_override("separation", 8)
	v.add_child(l2)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = cap
	bar.value = stock
	bar.custom_minimum_size = Vector2(0, 10)
	bar.size_flags_horizontal = SIZE_EXPAND_FILL
	bar.size_flags_vertical = SIZE_SHRINK_CENTER
	var couleur := Color(C_RES[res])
	if auto < 1.0:
		couleur = C_ROUGE
	elif auto < 2.0:
		couleur = C_ORANGE
	bar.add_theme_stylebox_override("fill", _boite(couleur, 6, Color(0, 0, 0, 0), 0))
	l2.add_child(bar)
	var fl := Tendance.new()
	fl.sens = 1 if solde > 0.01 else (-1 if solde < -0.01 else 0)
	fl.custom_minimum_size = Vector2(22, 22)
	l2.add_child(fl)
	# Détail : solde par jour, autonomie
	var detail := ("%+d /j" % int(round(solde))) if fl.sens != 0 else "stable"
	if auto < INF:
		detail += "  ·  %.1f j" % auto
	var l3 := _label(detail, 18, v, C_DISCRET)
	if auto < 1.0:
		l3.add_theme_color_override("font_color", C_ROUGE)
	elif auto < 2.0:
		l3.add_theme_color_override("font_color", C_ORANGE)
	h.tooltip_text = "%s : %d / %d" % [info.nom, stock, cap]
	return h


func _maj_survivants() -> void:
	for c in liste_surv.get_children():
		c.queue_free()
	for s in jeu.survivants:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		liste_surv.add_child(h)
		var n := _label(s.nom, 28, h, C_TEXTE, true)
		n.custom_minimum_size = Vector2(190, 0)
		if s.occupe_h > 0:
			_puce("En expédition · %d h" % s.occupe_h, C_ACCENT, h)
		elif s.blesse_h > 0:
			_puce("%s · %d h" % ["Malade" if s.malade else "Blessé(e)", s.blesse_h], C_ORANGE, h)
		else:
			var ob := OptionButton.new()
			for p in Jeu.POSTES:
				ob.add_item(jeu.R.postes[p].nom)
			ob.selected = Jeu.POSTES.find(s.poste)
			ob.custom_minimum_size = Vector2(0, 68)
			ob.size_flags_horizontal = SIZE_EXPAND_FILL
			ob.item_selected.connect(func(i): jeu.affecter(s, Jeu.POSTES[i]); _maj())
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
		if s.occupe_h > 0:
			continue
		var cle: String = s.poste if s.poste != "repos" else "entrepot"
		var pose := "debout" if s.poste == "repos" or s.blesse_h > 0 else "travaille"
		var img := "personnages/pers_%s_%s" % ["survivante" if s.femme else "survivant", pose]
		var t := _tex(img)
		var h := 1.75 * PXM * (0.75 if pose == "travaille" else 1.0)
		var r := _image(img, h * t.get_width() / t.get_height(), scene_base)
		var d: float = decal.get(cle, 0.0)
		decal[cle] = d + r.size.x + 6
		r.position = Vector2(centres[cle] - 40 + d, SOL_Y + 20 - r.size.y)
		if s.blesse_h > 0:
			r.modulate = Color(1, 0.75, 0.75)
	# Véhicules garés
	var x := 80.0 + marges.x
	for v in jeu.vehicules:
		if v.en_route:
			continue
		var r := _dessin_vehicule(v.type, PXM, false, scene_base)
		r.position = Vector2(x, RUE_Y - r.size.y)
		var etat := "%s · %d/%d" % [jeu.stat(v.type, "nom"), v.pv, v.pv_max]
		if v.etat == "epave":
			r.modulate = Color(0.45, 0.42, 0.4)
			etat = "%s · ÉPAVE" % jeu.stat(v.type, "nom")
		var l := _label(etat, 20, scene_base, C_TEXTE, true)
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
		l.add_theme_constant_override("shadow_offset_y", 2)
		l.position = Vector2(x, RUE_Y - r.size.y - 30)
		x += max(r.size.x, l.get_minimum_size().x) + 40


# --- Zoom de la base --------------------------------------------------------

func _zoomer(z: float, centre: Vector2) -> void:
	var ancien := zoom
	zoom = clampf(z, ZOOM_MIN, ZOOM_MAX)
	# Garder le point sous les doigts au même endroit de l'écran
	var p := monde.position
	if ancien > 0:
		p = centre - (centre - p) * (zoom / ancien)
	monde.scale = Vector2(zoom, zoom)
	monde.position = p
	_borner()


func _deplacer(delta: Vector2) -> void:
	monde.position += delta
	_borner()


func _borner() -> void:
	# Le monde couvre toujours l'écran ; le zoom s'ancre sur le sol (bas).
	var ecran := get_viewport_rect().size
	monde.position.x = clampf(monde.position.x, ecran.x - ecran.x * zoom, 0.0)
	monde.position.y = clampf(monde.position.y, ecran.y - ecran.y * zoom, 0.0)


func _entree_zoom(e: InputEvent) -> void:
	# Doigts (iPhone) : un doigt déplace, deux doigts pincent.
	if e is InputEventScreenTouch:
		if e.pressed:
			_touches[e.index] = e.position
		else:
			_touches.erase(e.index)
	elif e is InputEventScreenDrag:
		if _touches.size() >= 2 and _touches.has(e.index):
			var autre: Vector2 = _touches[_touches.keys().filter(func(k): return k != e.index)[0]]
			var avant := autre.distance_to(_touches[e.index])
			_touches[e.index] = e.position
			var apres := autre.distance_to(e.position)
			if avant > 10:
				_zoomer(zoom * apres / avant, (autre + e.position) / 2)
		else:
			_touches[e.index] = e.position
			_deplacer(e.relative)
	# Souris et pavé tactile (ordinateur). Les événements souris imités
	# depuis le toucher sont ignorés pour ne pas déplacer deux fois.
	elif e.device == InputEvent.DEVICE_ID_EMULATION:
		return
	elif e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoomer(zoom * 1.1, e.position)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoomer(zoom / 1.1, e.position)
	elif e is InputEventMouseMotion and e.button_mask & MOUSE_BUTTON_MASK_LEFT:
		_deplacer(e.relative)
	elif e is InputEventMagnifyGesture:
		_zoomer(zoom * e.factor, e.position)
	elif e is InputEventPanGesture:
		_deplacer(-e.delta * 20)


# Horloge : toutes les 5 s, le jeu rattrape les heures pleines écoulées.
func _process(delta: float) -> void:
	_chrono += delta
	if _chrono >= 5.0:
		_chrono = 0.0
		_avancer(jeu.rattraper())


func _input(e: InputEvent) -> void:
	if e is InputEventScreenTouch or e is InputEventMouseButton:
		jeu.signaler_action()


# Après un passage du temps : rapport de retour, expéditions revenues, révolte.
func _avancer(bilan: Dictionary) -> void:
	if not bilan.is_empty() and bilan.heures >= 2:
		file_rapports.append(_rapport_absence(bilan))
	file_rapports.append_array(jeu.rapports)
	jeu.rapports.clear()
	jeu.sauver()
	if jeu.perdu():
		file_rapports.append({"titre": "La communauté s'est éteinte", "convoi": [], "pillards": [],
			"lignes": ["Plus aucun survivant. Une nouvelle partie commence."]})
		jeu.effacer_partie()
	_maj()
	if not rapport.visible:
		_rapport_suivant()


func _rapport_absence(b: Dictionary) -> Dictionary:
	var lignes := []
	for res in jeu.R.ressources:
		var d: float = b.apres[res] - b.avant[res]
		if abs(d) >= 1:
			lignes.append("%s : %+d (%d)" % [jeu.R.ressources[res].nom, int(d), int(b.apres[res])])
	lignes.append("")
	lignes.append_array(b.lignes)
	return {"titre": "Pendant ton absence (%d h)" % b.heures, "convoi": [], "pillards": [], "lignes": lignes}


func _rapport_suivant() -> void:
	if file_rapports:
		_afficher_rapport(file_rapports.pop_front())
	elif not jeu.decision.is_empty():
		_afficher_revolte()
	else:
		rapport.visible = false


func _afficher_revolte() -> void:
	var nom: String = jeu.decision.nom
	_afficher_rapport({"titre": "Révolte : " + nom, "convoi": [], "pillards": [], "decision": true,
		"lignes": ["%s refuse de travailler et menace de partir avec une partie des vivres." % nom,
			"Les autres survivants attendent ta décision."]})


# --- Carte et convoi --------------------------------------------------------

func _construire_carte() -> void:
	carte = Control.new()
	carte.set_anchors_preset(PRESET_FULL_RECT)
	add_child(carte)
	var fond := TextureRect.new()
	fond.texture = _tex("carte/carte_fond")
	fond.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fond.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
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
	var retour := _bouton("‹  Base", func(): _montrer(base); _maj(), carte)
	retour.position = Vector2(marges.x, marges.y)
	retour.custom_minimum_size = Vector2(200, 80)
	var sb: StyleBoxFlat = _boite(C_PANNEAU, 16, C_BORD, 18)
	retour.add_theme_stylebox_override("normal", sb)
	panneau_convoi = _panneau(carte, 26)
	panneau_convoi.anchor_left = 1.0
	panneau_convoi.anchor_right = 1.0
	panneau_convoi.offset_left = -680 - marges.z
	panneau_convoi.offset_right = -marges.z
	panneau_convoi.offset_top = marges.y


func _icone_lieu(img: String, pos: Array, nom: String, action: Callable) -> void:
	var b := TextureButton.new()
	b.texture_normal = _tex(img)
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
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
	# Nom du lieu dans une pastille sombre, centrée sous l'icône
	var p := PanelContainer.new()
	var sb := _boite(Color(0.07, 0.075, 0.08, 0.82), 12, Color(0, 0, 0, 0), 0)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = MOUSE_FILTER_IGNORE
	var l := _label(nom, 22, p, C_TEXTE, true)
	b.add_child(p)
	p.position = Vector2(65 - (l.get_minimum_size().x + 28) / 2, 132)


func _ouvrir_carte() -> void:
	lieu_choisi = ""
	panneau_convoi.visible = false
	_montrer(carte)


func _choisir_lieu(id: String) -> void:
	lieu_choisi = id
	_construire_panneau_convoi()


func _changer_mode(pied: bool) -> void:
	mode_pied = pied
	nb_pied = 1
	_construire_panneau_convoi()


func _construire_panneau_convoi() -> void:
	var l: Dictionary = jeu.R.lieux[lieu_choisi]
	for c in panneau_convoi.get_children():
		c.queue_free()
	panneau_convoi.visible = true
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	panneau_convoi.add_child(vb)
	_label(l.nom, 38, vb, C_TEXTE, true)
	var infos := HBoxContainer.new()
	infos.add_theme_constant_override("separation", 10)
	vb.add_child(infos)
	_puce("%d h de route" % l.heures, C_TEXTE, infos)
	var c_risque: Color = {"faible": C_VERT, "modere": C_ORANGE, "eleve": C_ROUGE, "critique": C_ROUGE}[l.risque]
	_puce("Risque " + Jeu.RISQUES[l.risque], c_risque, infos)
	var butin := []
	for res in l.butin:
		butin.append(jeu.R.ressources[res].nom.to_lower())
	_label("Butin : " + ", ".join(butin), 24, vb, C_DISCRET)
	# Mode : véhicules ou à pied (contrôle segmenté)
	var seg := HBoxContainer.new()
	seg.add_theme_constant_override("separation", 8)
	vb.add_child(seg)
	var groupe := ButtonGroup.new()
	for m in [[false, "Véhicules"], [true, "À pied"]]:
		var b := Button.new()
		b.text = m[1]
		b.toggle_mode = true
		b.button_group = groupe
		b.button_pressed = mode_pied == m[0]
		b.custom_minimum_size = Vector2(0, 68)
		b.size_flags_horizontal = SIZE_EXPAND_FILL
		b.pressed.connect(func(): if mode_pied != m[0]: _changer_mode(m[0]))
		seg.add_child(b)
	choix_vehicules.clear()
	ordre_btn = null
	if mode_pied:
		var st := HBoxContainer.new()
		st.add_theme_constant_override("separation", 12)
		vb.add_child(st)
		_label("Marcheurs", 28, st).size_flags_horizontal = SIZE_EXPAND_FILL
		var moins := _bouton("−", func(): nb_pied = max(1, nb_pied - 1); _construire_panneau_convoi(), st)
		var lbl := _label(str(nb_pied), 34, st, C_TEXTE, true)
		lbl.custom_minimum_size = Vector2(50, 0)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var plus := _bouton("+", func(): nb_pied += 1; _construire_panneau_convoi(), st)
		for b in [moins, plus]:
			b.custom_minimum_size = Vector2(80, 72)
			b.add_theme_font_size_override("font_size", 36)
		var dispo := jeu.survivants.filter(jeu.disponible).size()
		moins.disabled = nb_pied <= 1
		plus.disabled = nb_pied >= dispo
	else:
		_label("Un survivant par véhicule", 22, vb, C_DISCRET)
		var grille := GridContainer.new()
		grille.columns = 2
		grille.add_theme_constant_override("h_separation", 10)
		grille.add_theme_constant_override("v_separation", 10)
		vb.add_child(grille)
		for v in jeu.vehicules_prets():
			var b := Button.new()
			b.toggle_mode = true
			b.text = "%s\n%d/%d PV" % [jeu.stat(v.type, "nom"), v.pv, v.pv_max]
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.add_theme_font_size_override("font_size", 24)
			b.custom_minimum_size = Vector2(305, 92)
			b.toggled.connect(func(_on): _maj_briefing())
			grille.add_child(b)
			choix_vehicules[v.uid] = b
		ordre_btn = OptionButton.new()
		for o in Jeu.ORDRES:
			ordre_btn.add_item(Jeu.ORDRES[o])
		ordre_btn.selected = 1
		ordre_btn.custom_minimum_size = Vector2(0, 72)
		vb.add_child(ordre_btn)
	lbl_briefing = _label("", 23, vb, Color(C_TEXTE, 0.85))
	lbl_briefing.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_briefing.custom_minimum_size = Vector2(620, 0)
	btn_partir = _bouton("Partir", _partir, vb, true)
	_maj_briefing()


func _convoi() -> Array:
	return jeu.vehicules_prets().filter(func(v): return choix_vehicules.has(v.uid) and choix_vehicules[v.uid].button_pressed)


func _maj_briefing() -> void:
	var t := ""
	var b: Dictionary
	if mode_pied:
		b = jeu.briefing_pied(lieu_choisi, nb_pied)
		t = "Durée : %d h de marche (%d j)\nVivres : %d L d'eau, %d rations\nPortage : %d\nGroupe : %s\nRisque %s : %s" % [
			int(b.heures), b.jours, b.eau, b.vivres, b.capacite,
			", ".join(b.equipage) if b.equipage else "—", b.risque, " ; ".join(b.raisons)]
	else:
		b = jeu.briefing(lieu_choisi, _convoi())
		t = "Carburant : %d L (conseillé %d, stock %d)\nVivres : %d L d'eau, %d rations\nChargement : %d\nÉquipage : %s\nRisque %s : %s" % [
			b.carburant, b.carburant_conseille, jeu.stocks.fuel_l, b.eau, b.vivres, b.capacite,
			", ".join(b.equipage) if b.equipage else "—", b.risque, " ; ".join(b.raisons)]
		if not b.ok and b.erreurs.has("Carburant insuffisant."):
			t += "\nAstuce : sans carburant, partez à pied vers un lieu proche."
	if not b.ok:
		t += "\n" + "\n".join(b.erreurs)
	lbl_briefing.text = t
	btn_partir.disabled = not b.ok


func _partir() -> void:
	var r: Dictionary
	if mode_pied:
		r = jeu.lancer_pied(lieu_choisi, nb_pied)
	else:
		var ordre: String = Jeu.ORDRES.keys()[ordre_btn.selected]
		r = jeu.lancer(lieu_choisi, _convoi(), ordre)
	if not r.ok:
		lbl_briefing.text = "\n".join(r.erreurs)
		return
	Son.effet("sfx_depart_marche" if mode_pied else "sfx_depart_convoi")
	_montrer(base)
	_maj()


# --- Rapport ----------------------------------------------------------------

func _construire_rapport() -> void:
	rapport = ColorRect.new()
	rapport.color = Color(0, 0, 0, 0.55)
	rapport.set_anchors_preset(PRESET_FULL_RECT)
	rapport.visible = false
	add_child(rapport)


func _afficher_rapport(rap: Dictionary) -> void:
	for c in rapport.get_children():
		c.queue_free()
	rapport.visible = true
	Son.effet("sfx_radio")
	if rap.get("convoi", []) or rap.get("marcheurs", []):
		Son.voix("voix_retour_convoi")
	var ecran := get_viewport_rect().size
	var p := _panneau(rapport, 32)
	(p.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = Color("#141618")
	p.custom_minimum_size = Vector2(min(1500.0, ecran.x - marges.x - marges.z), ecran.y - marges.y - marges.w - 40)
	p.position = (ecran - p.custom_minimum_size) / 2
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	p.add_child(vb)
	_label(rap.titre, 40, vb, C_TEXTE, true)
	if rap.has("heure"):
		_label("Retour " + rap.heure, 22, vb, C_DISCRET)
	# File du convoi (vers la droite) face aux pillards (vers la gauche)
	var file := HBoxContainer.new()
	file.add_theme_constant_override("separation", 24)
	file.alignment = BoxContainer.ALIGNMENT_CENTER
	file.custom_minimum_size = Vector2(0, 190)
	vb.add_child(file)
	for m in rap.get("marcheurs", []):
		var r := TextureRect.new()
		r.texture = _tex("personnages/pers_%s_marche" % ("survivante" if m.femme else "survivant"))
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		r.custom_minimum_size = Vector2(80, 160)
		file.add_child(r)
	var convoi: Array = rap.get("convoi", []).duplicate()
	convoi.reverse()   # la tête est à droite, face à l'ennemi
	for v in convoi:
		_vignette(v, false, file)
	if rap.get("pillards", []):
		_label("⟷", 40, file, C_DISCRET)
		for v in rap.pillards:
			_vignette(v, true, file)
	file.visible = file.get_child_count() > 0
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(sc)
	var lignes := _label("\n".join(rap.lignes), 26, sc, Color(C_TEXTE, 0.9))
	lignes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lignes.size_flags_horizontal = SIZE_EXPAND_FILL
	lignes.add_theme_constant_override("line_spacing", 6)
	if rap.get("decision", false):
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 12)
		vb.add_child(hb)
		for c in [["pardonner", "Pardonner"], ["partir", "Le laisser partir"], ["executer", "Exécuter"]]:
			_bouton(c[1], func(): jeu.decider(c[0]); _maj(); _rapport_suivant(), hb).size_flags_horizontal = SIZE_EXPAND_FILL
	else:
		_bouton("Continuer", func(): _maj(); _rapport_suivant(), vb, true)


func _vignette(v: Dictionary, ennemi: bool, parent: Node) -> void:
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_END
	parent.add_child(vb)
	var r := _dessin_vehicule(v.type, 34.0, ennemi, vb)
	var etat: String = {"ok": "intact", "epave": "épave", "perdu": "perdu", "detruit": "détruit"}[v.etat]
	if v.etat != "ok":
		r.modulate = Color(0.4, 0.35, 0.3)
	var coul := C_ROUGE if ennemi else (C_VERT if v.etat == "ok" else C_ORANGE)
	var l := _label(etat, 20, vb, coul, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


# Flèche de tendance : ▲ verte (excédent), ▼ rouge (déficit), trait gris (stable).
class Tendance extends Control:
	var sens := 0
	func _draw() -> void:
		var s := size
		if sens > 0:
			draw_colored_polygon(PackedVector2Array([Vector2(s.x / 2, 2), Vector2(s.x - 1, s.y - 3), Vector2(1, s.y - 3)]), Color("#6CC27A"))
		elif sens < 0:
			draw_colored_polygon(PackedVector2Array([Vector2(1, 3), Vector2(s.x - 1, 3), Vector2(s.x / 2, s.y - 2)]), Color("#E5594F"))
		else:
			draw_rect(Rect2(2, s.y / 2 - 2, s.x - 4, 4), Color(1, 1, 1, 0.35))


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
			draw_dashed_line(b, p, Color(0.2, 0.1, 0.03, 0.75), 5.0, 18.0)


# --- Dessin des véhicules, menus, garage ------------------------------------

func _dessin_vehicule(type: String, echelle: float, ennemi: bool, parent: Node) -> VehiculeDessin:
	var d := VehiculeDessin.new()
	d.type = type
	d.ppm = echelle
	d.ennemi = ennemi
	d.miroir = ennemi
	parent.add_child(d)
	return d


# Arrivée sur la base (depuis le menu principal ou au lancement des tests).
func _entrer_base() -> void:
	Son.musique("mus_base")
	_maj()


func _nouvelle_partie() -> void:
	jeu.effacer_partie()
	file_rapports.clear()
	rapport.visible = false
	jeu.signaler_action()
	jeu.sauver()
	_montrer(base)
	_maj()


func _ouvrir_garage() -> void:
	if garage == null:
		garage = Garage.new()
		garage.main = self
		add_child(garage)
	garage.visible = true
	garage._maj_son()
	Son.ambiance("")


func _fermer_garage() -> void:
	garage.visible = false
	if menus.titre_visible():
		Son.moteur("sfx_moteur_semi_chenille")
	else:
		_entrer_base()


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel") and not menus.titre_visible() and not (garage and garage.visible):
		menus.basculer_pause()
