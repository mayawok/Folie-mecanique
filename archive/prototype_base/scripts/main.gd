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
var exp_box: VBoxContainer
var couche_bat: Control
var couche_veh: Control
var couche_pions: Control
var couche_bulles: Control
var bat_noeuds := {}         # id -> Control du bâtiment
var veh_noeuds := []         # [{n: VehiculeDessin, v: véhicule}]
var _sig_veh := ""
var pions := {}              # nom -> Silhouette (déplacement à pied entre les postes)
var fiche: ColorRect         # fenêtre de bâtiment ou de véhicule
var _appui := Vector2.ZERO
var _glisse := 0.0
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
	if "--expedition" in args or "--chantier" in args:
		jeu.stocks.metal = 120
		jeu.stocks.materials = 80
		jeu.lancer("oasis", jeu.vehicules_prets().slice(0, 1), "repli")
		_maj()
	if "--chantier" in args:
		jeu.ameliorer("armurerie")
		jeu.survivants[-1].poste = "chantier"
		_maj()
	for a in args:
		if a.begins_with("--fiche="):
			_fiche_batiment(a.split("=")[1])
		if a == "--vehicule":
			_fiche_vehicule(jeu.vehicules[2])
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
		if "--retour" in args:   # passer le rapport d'absence, montrer le retour d'expédition
			_rapport_suivant()
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
	for n in ["couche_bat", "couche_veh", "couche_pions", "couche_bulles"]:
		var c := Control.new()
		c.mouse_filter = MOUSE_FILTER_IGNORE
		scene_base.add_child(c)
		set(n, c)
	_construire_batiments()
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

	# Colonne gauche : expéditions en cours, puis journal
	var colonne := VBoxContainer.new()
	colonne.position = Vector2(marges.x, marges.y + 170)
	colonne.custom_minimum_size = Vector2(720, 0)
	colonne.add_theme_constant_override("separation", 12)
	colonne.mouse_filter = MOUSE_FILTER_IGNORE
	base.add_child(colonne)
	exp_box = VBoxContainer.new()
	exp_box.add_theme_constant_override("separation", 10)
	colonne.add_child(exp_box)
	var pj := _panneau(colonne, 20)
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
	ps.offset_left = -640 - marges.z
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
	_maj_expeditions()
	for c in hud_res.get_children():
		c.queue_free()
	for res in jeu.R.ressources:
		hud_res.add_child(_carte_ressource(res))
	if jeu.etape > 0:
		var noms := ["", "PÉNURIE", "MALADIE", "AGITATION"]
		_puce("%s · étape %d" % [noms[jeu.etape], jeu.etape], C_ROUGE, hud_res)
	lbl_journal.text = "\n".join(jeu.journal.slice(max(0, jeu.journal.size() - 4)))
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
	ic.custom_minimum_size = Vector2(44, 52)
	h.add_child(ic)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 4)
	h.add_child(v)
	var l1 := HBoxContainer.new()
	l1.add_theme_constant_override("separation", 8)
	v.add_child(l1)
	var nom := _label(info.nom, 25, l1, C_DISCRET)
	nom.size_flags_horizontal = SIZE_EXPAND_FILL
	nom.clip_text = true
	var unite: String = (" " + info.unite) if info.unite == "L" else ""
	_label("%d%s" % [stock, unite], 28, l1, C_TEXTE, true)
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
	var l3 := _label(detail, 20, v, C_DISCRET)
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
		var app := Silhouette.apparence_de(s.nom, s.femme)
		var por := Portrait.new()
		por.apparence = app
		por.custom_minimum_size = Vector2(64, 64)
		por.size_flags_vertical = SIZE_SHRINK_CENTER
		por.tooltip_text = Silhouette.description(app)
		h.add_child(por)
		var nv := VBoxContainer.new()
		nv.add_theme_constant_override("separation", -4)
		nv.custom_minimum_size = Vector2(180, 0)
		nv.alignment = BoxContainer.ALIGNMENT_CENTER
		h.add_child(nv)
		_label(s.nom, 28, nv, C_TEXTE, true)
		var dl := _label(Silhouette.description(app), 16, nv, C_DISCRET)
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dl.custom_minimum_size = Vector2(180, 0)
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
	_maj_vehicules()
	_maj_pions()
	_maj_bulles()


# Bâtiments : posés une fois (images, ou dessin pour l'armurerie).
func _construire_batiments() -> void:
	for b in jeu.R.batiments:
		var r: Control
		if b.has("image"):
			r = _image("batiments/" + b.image, b.largeur_m * PXM, couche_bat)
		else:
			r = BatimentDessin.new()
			r.size = Vector2(b.largeur_m, b.hauteur_m) * PXM
			r.mouse_filter = MOUSE_FILTER_IGNORE
			couche_bat.add_child(r)
		r.position = Vector2(60 + b.x_m * PXM, SOL_Y - r.size.y)
		r.pivot_offset = Vector2(r.size.x / 2, r.size.y)
		bat_noeuds[b.id] = r


func _centre_bat(id: String) -> float:
	var r: Control = bat_noeuds.get(id, bat_noeuds.entrepot)
	return r.position.x + r.size.x / 2


# Véhicules garés : recréés seulement quand leur état change. Pas de nom affiché :
# toucher un véhicule ouvre sa fiche.
func _maj_vehicules() -> void:
	var sig := str(jeu.vehicules.map(func(v): return [v.uid, v.type, v.etat, v.en_route, v.pv]))
	if sig == _sig_veh:
		return
	_sig_veh = sig
	for c in couche_veh.get_children():
		c.queue_free()
	veh_noeuds.clear()
	var x := 80.0 + marges.x
	for v in jeu.vehicules:
		if v.en_route:
			continue
		var r := _dessin_vehicule(v.type, PXM, false, couche_veh)
		r.position = Vector2(x, RUE_Y - r.size.y)
		r.pivot_offset = Vector2(r.size.x / 2, r.size.y)
		if v.etat == "epave":
			r.modulate = Color(0.45, 0.42, 0.4)
		veh_noeuds.append({"n": r, "v": v})
		x += r.size.x + 50


# Survivants : chacun marche vers le bâtiment de son poste (voir _process).
func _poste_bat(s: Dictionary) -> String:
	if s.poste == "chantier":
		return jeu.chantier.get("bat", "entrepot")
	for b in jeu.R.batiments:
		if b.get("poste", "") == s.poste:
			return b.id
	return "entrepot"


func _maj_pions() -> void:
	var decal := {}
	for s in jeu.survivants:
		var p: Silhouette = pions.get(s.nom)
		if p == null:
			p = Silhouette.new()
			p.variante = "survivante" if s.femme else "survivant"
			p.apparence = Silhouette.apparence_de(s.nom, s.femme)
			p.ppm = PXM
			couche_pions.add_child(p)
			p.size = p.custom_minimum_size
			p.position = Vector2(_centre_bat("entrepot") - p.size.x / 2, SOL_Y + 22 - p.size.y)
			pions[s.nom] = p
		p.visible = s.occupe_h <= 0
		var cle := _poste_bat(s)
		var d: float = decal.get(cle, 0.0)
		decal[cle] = d + 44.0
		p.set_meta("cible", _centre_bat(cle) - 50 + d)
		p.set_meta("travail", s.poste != "repos" and jeu.disponible(s))
		p.modulate = Color(1, 0.72, 0.72) if s.blesse_h > 0 else Color.WHITE
	for nom in pions.keys():
		if not jeu.survivants.any(func(s): return s.nom == nom):
			pions[nom].queue_free()
			pions.erase(nom)


func _bouger_pions(delta: float) -> void:
	for p in pions.values():
		if not p.has_meta("cible"):
			continue
		var cx: float = p.get_meta("cible") - p.size.x / 2
		var dx: float = cx - p.position.x
		if absf(dx) > 2.0:
			p.pose = "marche"
			p.miroir = dx < 0
			p.position.x += signf(dx) * minf(absf(dx), 1.5 * PXM * delta)
		else:
			p.pose = "travaille" if p.get_meta("travail") else "debout"
			if p.pose == "debout":
				p.phase = 0.0
				p.queue_redraw()


# Bulles au-dessus des bâtiments : chantier en cours, ou amélioration possible.
func _maj_bulles() -> void:
	for c in couche_bulles.get_children():
		c.queue_free()
	for b in jeu.R.batiments:
		var r: Control = bat_noeuds[b.id]
		var bu := Bulle.new()
		bu.police = police_gras
		if jeu.chantier.get("bat", "") == b.id:
			var nb := jeu.ouvriers().size()
			bu.icone = "marteau"
			bu.progres = 1.0 - jeu.chantier.reste / jeu.chantier.total
			bu.texte = "%s" % _duree(jeu.chantier.reste / nb * 3600.0) if nb > 0 else "Sans ouvrier"
		elif jeu.verifier_amelioration(b.id).ok:
			bu.icone = "fleche"
			bu.texte = "Niv. %d" % (jeu.niveau(b.id) + 1)
		else:
			continue
		couche_bulles.add_child(bu)
		bu.position = Vector2(r.position.x + r.size.x / 2 - bu.size.x / 2, r.position.y - bu.size.y - 6)


func _duree(sec: float) -> String:
	var m := int(ceil(maxf(0.0, sec) / 60.0))
	return "%d h %02d" % [m / 60, m % 60] if m >= 60 else "%d min" % m


# Cartes des expéditions en cours : véhicules, équipage, barre jusqu'au retour.
func _maj_expeditions() -> void:
	for c in exp_box.get_children():
		c.queue_free()
	var now := jeu.maintenant()
	for e in jeu.expeditions:
		var p := _panneau(exp_box, 14)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 16)
		p.add_child(hb)
		var vis := HBoxContainer.new()
		vis.alignment = BoxContainer.ALIGNMENT_END
		vis.add_theme_constant_override("separation", 6)
		vis.custom_minimum_size = Vector2(190, 70)
		hb.add_child(vis)
		var types := []
		for uid in e.vehicules:
			for v in jeu.vehicules:
				if v.uid == uid:
					types.append(v.type)
		var long_tot := 0.0
		for ty in types:
			long_tot += float(VehiculeDessin.donnees().vehicules[ty].longueur)
		var ech := minf(30.0, 180.0 / maxf(1.0, long_tot))
		for ty in types:
			_dessin_vehicule(ty, ech, false, vis)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 6)
		hb.add_child(col)
		var l1 := HBoxContainer.new()
		col.add_child(l1)
		var titre := _label(("À pied · " if e.pied else "") + jeu.R.lieux[e.lieu].nom, 24, l1, C_TEXTE, true)
		titre.size_flags_horizontal = SIZE_EXPAND_FILL
		_label(_duree(e.retour - now), 24, l1, C_ACCENT, true)
		var gens := HBoxContainer.new()
		gens.add_theme_constant_override("separation", 2)
		col.add_child(gens)
		for nom in e.equipage:
			var femme := false
			for sv in jeu.survivants:
				if sv.nom == nom:
					femme = sv.femme
			var si := Silhouette.new()
			si.ppm = 22.0
			si.variante = "survivante" if femme else "survivant"
			si.apparence = Silhouette.apparence_de(nom, femme)
			si.pose = "marche" if e.pied else "debout"
			gens.add_child(si)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 12)
		bar.value = 100.0 * clampf(float(now - e.depart) / maxf(1.0, e.retour - e.depart), 0.0, 1.0)
		col.add_child(bar)


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
			if _touches.size() == 1:
				_appui = e.position
				_glisse = 0.0
		else:
			_touches.erase(e.index)
			if _touches.is_empty() and _glisse < 24.0 and e.position.distance_to(_appui) < 24.0:
				_toucher(e.position)
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
			_glisse += e.relative.length()
			_deplacer(e.relative)
	# Souris et pavé tactile (ordinateur). Les événements souris imités
	# depuis le toucher sont ignorés pour ne pas déplacer deux fois.
	elif e.device == InputEvent.DEVICE_ID_EMULATION:
		return
	elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_appui = e.position
			_glisse = 0.0
		elif _glisse < 24.0:
			_toucher(e.position)
	elif e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoomer(zoom * 1.1, e.position)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoomer(zoom / 1.1, e.position)
	elif e is InputEventMouseMotion and e.button_mask & MOUSE_BUTTON_MASK_LEFT:
		_glisse += e.relative.length()
		_deplacer(e.relative)
	elif e is InputEventMagnifyGesture:
		_zoomer(zoom * e.factor, e.position)
	elif e is InputEventPanGesture:
		_deplacer(-e.delta * 20)


# Horloge : toutes les 5 s, le jeu rattrape les heures pleines écoulées.
func _process(delta: float) -> void:
	_chrono += delta
	_bouger_pions(delta)
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
	var gains := {}
	for res in jeu.R.ressources:
		var d: float = b.apres[res] - b.avant[res]
		if abs(d) >= 1:
			gains[res] = int(d)
	return {"titre": "Pendant ton absence", "sous_titre": "%d h écoulées" % b.heures, "type": "absence",
		"butin": gains, "convoi": [], "pillards": [], "lignes": b.lignes}


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
	rapport.color = Color(0.055, 0.058, 0.062, 0.985)
	rapport.set_anchors_preset(PRESET_FULL_RECT)
	rapport.visible = false
	add_child(rapport)


func _afficher_rapport(rap: Dictionary) -> void:
	for c in rapport.get_children():
		c.queue_free()
	rapport.visible = true
	Son.effet("sfx_radio")
	var expedition: bool = rap.has("issue")
	if expedition:
		Son.voix("voix_retour_convoi")
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	vb.offset_left = marges.x + 40
	vb.offset_right = -marges.z - 40
	vb.offset_top = marges.y + 20
	vb.offset_bottom = -marges.w - 10
	vb.add_theme_constant_override("separation", 18)
	rapport.add_child(vb)
	# Grand titre
	var gros: String = "RÉVOLTE" if rap.get("decision", false) else rap.titre.to_upper()
	if expedition:
		gros = "RETOUR À PIED" if rap.has("marcheurs") else "RETOUR D'EXPÉDITION"
	var t := _label(gros, 76, vb, C_ACCENT, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sous := HBoxContainer.new()
	sous.alignment = BoxContainer.ALIGNMENT_CENTER
	sous.add_theme_constant_override("separation", 16)
	vb.add_child(sous)
	var st: String = rap.get("sous_titre", "")
	if expedition:
		st = rap.titre.split(" : ")[-1] + ("  ·  " + rap.heure if rap.has("heure") else "")
	elif rap.get("decision", false):
		st = rap.titre
	if st != "":
		_label(st, 30, sous, C_TEXTE)
	if expedition:
		var issue: String = rap.issue
		_puce({"victoire": "Réussite", "repli": "Repli", "defaite": "Convoi perdu"}[issue],
			{"victoire": C_VERT, "repli": C_ORANGE, "defaite": C_ROUGE}[issue], sous)
	var esp1 := Control.new()
	esp1.size_flags_vertical = SIZE_EXPAND_FILL
	vb.add_child(esp1)
	# File du convoi (vers la droite) face aux pillards (vers la gauche)
	var file := HBoxContainer.new()
	file.add_theme_constant_override("separation", 30)
	file.alignment = BoxContainer.ALIGNMENT_CENTER
	file.custom_minimum_size = Vector2(0, 220)
	vb.add_child(file)
	for m in rap.get("marcheurs", []):
		var si := Silhouette.new()
		si.ppm = 70.0
		si.variante = "survivante" if m.femme else "survivant"
		si.apparence = Silhouette.apparence_de(m.get("nom", ""), m.femme)
		si.pose = "marche"
		file.add_child(si)
	var convoi: Array = rap.get("convoi", []).duplicate()
	convoi.reverse()   # la tête est à droite, face à l'ennemi
	for v in convoi:
		_vignette(v, false, file)
	if rap.get("pillards", []):
		_label("contre", 30, file, C_DISCRET, true)
		for v in rap.pillards:
			_vignette(v, true, file)
	file.visible = file.get_child_count() > 0
	# Ce qui a été récupéré (ou perdu pendant l'absence) : grandes tuiles
	var tuiles := HFlowContainer.new()
	tuiles.alignment = FlowContainer.ALIGNMENT_CENTER
	tuiles.add_theme_constant_override("h_separation", 16)
	tuiles.add_theme_constant_override("v_separation", 16)
	vb.add_child(tuiles)
	var butin: Dictionary = rap.get("butin", {})
	for res in butin:
		if butin[res] != 0:
			_tuile(tuiles, "ui/" + jeu.R.ressources[res].icone, butin[res], jeu.R.ressources[res].nom)
	for nom in rap.get("recrues", []):
		_tuile(tuiles, "", 1, "Recrue : " + nom, nom)
	if expedition and tuiles.get_child_count() == 0:
		_label("Rien de rapporté.", 30, tuiles, C_DISCRET)
	var i := 0
	for c in tuiles.get_children():
		c.modulate.a = 0.0
		create_tween().tween_property(c, "modulate:a", 1.0, 0.35).set_delay(0.25 + 0.12 * i)
		i += 1
	# Détails
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, 150)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(sc)
	var lignes := _label("\n".join(rap.lignes.filter(func(l): return not l.begins_with("BUTIN"))), 22, sc, C_DISCRET)
	lignes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lignes.size_flags_horizontal = SIZE_EXPAND_FILL
	lignes.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lignes.add_theme_constant_override("line_spacing", 6)
	var esp2 := Control.new()
	esp2.size_flags_vertical = SIZE_EXPAND_FILL
	vb.add_child(esp2)
	var bas := HBoxContainer.new()
	bas.alignment = BoxContainer.ALIGNMENT_CENTER
	bas.add_theme_constant_override("separation", 12)
	vb.add_child(bas)
	if rap.get("decision", false):
		for c in [["pardonner", "Pardonner"], ["partir", "Le laisser partir"], ["executer", "Exécuter"]]:
			_bouton(c[1], func(): jeu.decider(c[0]); _maj(); _rapport_suivant(), bas).custom_minimum_size.x = 340
	else:
		_bouton("Continuer", func(): _maj(); _rapport_suivant(), bas, true).custom_minimum_size.x = 520


# Tuile de gain : icône, « +58 », nom. Sans icône : portrait de la recrue.
func _tuile(parent: Node, icone: String, q: int, nom: String, recrue := "") -> void:
	var p := _panneau(parent, 18)
	p.custom_minimum_size = Vector2(250, 0)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 4)
	p.add_child(vb)
	if recrue != "":
		var por := Portrait.new()
		por.apparence = Silhouette.apparence_de(recrue, false)
		por.custom_minimum_size = Vector2(84, 84)
		por.size_flags_horizontal = SIZE_SHRINK_CENTER
		vb.add_child(por)
	else:
		var ic := TextureRect.new()
		ic.texture = _tex(icone)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.custom_minimum_size = Vector2(0, 84)
		vb.add_child(ic)
	var l := _label("%+d" % q, 48, vb, C_VERT if q > 0 else C_ROUGE, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var n := _label(nom, 22, vb, C_DISCRET)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _vignette(v: Dictionary, ennemi: bool, parent: Node) -> void:
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_END
	parent.add_child(vb)
	var r := _dessin_vehicule(v.type, 56.0, ennemi, vb)
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


# --- Toucher un bâtiment ou un véhicule ---------------------------------------

func _toucher(pos: Vector2) -> void:
	if fiche and fiche.visible:
		return
	var local := (pos - monde.position) / zoom
	for i in range(veh_noeuds.size() - 1, -1, -1):
		var n: Control = veh_noeuds[i].n
		if Rect2(n.position, n.size).grow(10).has_point(local):
			_rebond(n)
			_fiche_vehicule(veh_noeuds[i].v)
			return
	for b in jeu.R.batiments:
		var r: Control = bat_noeuds[b.id]
		var zone := Rect2(r.position + Vector2(0, -110), r.size + Vector2(0, 110))
		if zone.has_point(local):
			_rebond(r)
			_fiche_batiment(b.id)
			return


func _rebond(n: Control) -> void:
	Son.effet("sfx_ui_clic")
	var tw := create_tween()
	tw.tween_property(n, "scale", Vector2(1.05, 0.93), 0.08)
	tw.tween_property(n, "scale", Vector2(0.97, 1.06), 0.10)
	tw.tween_property(n, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# Fenêtre centrale ; toucher le fond la ferme.
func _ouvrir_fiche(largeur: float) -> VBoxContainer:
	if fiche == null:
		fiche = ColorRect.new()
		fiche.color = Color(0, 0, 0, 0.55)
		fiche.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		fiche.gui_input.connect(_fond_fiche)
		add_child(fiche)
		move_child(fiche, rapport.get_index())
	for c in fiche.get_children():
		c.queue_free()
	fiche.visible = true
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	cc.mouse_filter = MOUSE_FILTER_IGNORE
	fiche.add_child(cc)
	var p := _panneau(cc, 30)
	(p.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = Color("#141618")
	p.custom_minimum_size = Vector2(largeur, 0)
	p.scale = Vector2(0.94, 0.94)
	p.modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(p, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(p, "modulate:a", 1.0, 0.12)
	p.resized.connect(func(): p.pivot_offset = p.size / 2)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	p.add_child(vb)
	return vb


func _fond_fiche(e: InputEvent) -> void:
	if (e is InputEventMouseButton or e is InputEventScreenTouch) and e.pressed:
		fiche.visible = false


func _fiche_vehicule(v: Dictionary) -> void:
	var vb := _ouvrir_fiche(1000)
	var forme: Dictionary = VehiculeDessin.donnees().vehicules[v.type]
	_label(jeu.stat(v.type, "nom"), 44, vb, C_TEXTE, true)
	_label(forme.fiche, 24, vb, C_DISCRET).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 30)
	vb.add_child(hb)
	var cadre := CenterContainer.new()
	cadre.custom_minimum_size = Vector2(430, 220)
	hb.add_child(cadre)
	var d := _dessin_vehicule(v.type, minf(70.0, 400.0 / float(forme.longueur)), false, cadre)
	if v.etat == "epave":
		d.modulate = Color(0.45, 0.42, 0.4)
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 26)
	g.add_theme_constant_override("v_separation", 6)
	hb.add_child(g)
	var lignes := [
		["État", "ÉPAVE" if v.etat == "epave" else "%d / %d PV" % [v.pv, v.pv_max]],
		["Blindage", str(jeu.stat(v.type, "blindage"))],
		["Puissance de feu", str(jeu.stat(v.type, "feu"))],
		["Précision", "%d %%" % int(jeu.stat(v.type, "precision") * 100)],
		["Vitesse", "×%.1f" % jeu.stat(v.type, "vitesse")],
		["Consommation", "%d L/h" % jeu.stat(v.type, "conso_l_h")],
		["Chargement", str(jeu.stat(v.type, "capacite"))],
		["Équipage", "%d max" % jeu.stat(v.type, "equipage_max")]]
	for l in lignes:
		_label(l[0], 24, g, C_DISCRET)
		_label(l[1], 24, g, C_TEXTE, true)
	_bouton("Fermer", func(): fiche.visible = false, vb, true)


func _fiche_batiment(id: String) -> void:
	var b: Dictionary = jeu.batiment(id)
	var n := jeu.niveau(id)
	var nmax := jeu.niveau_max(id)
	var vb := _ouvrir_fiche(1250)
	var tete := HBoxContainer.new()
	vb.add_child(tete)
	_label(b.nom, 44, tete, C_TEXTE, true).size_flags_horizontal = SIZE_EXPAND_FILL
	_puce("Niveau %d / %d" % [n, nmax], C_ACCENT, tete)
	_label(b.role, 24, vb, C_DISCRET).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if b.get("poste", "") != "":
		var noms := jeu.survivants.filter(func(s): return s.poste == b.poste and jeu.disponible(s)).map(func(s): return s.nom)
		_label("Au travail : " + (", ".join(noms) if noms else "personne (affecter un survivant au poste %s)" % jeu.R.postes[b.poste].nom), 24, vb)
	# Arbre d'amélioration : un nœud par niveau, reliés de gauche à droite
	_label("ARBRE D'AMÉLIORATION", 20, vb, C_DISCRET, true)
	var arbre := HBoxContainer.new()
	arbre.add_theme_constant_override("separation", 0)
	arbre.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(arbre)
	var etapes := [{"n": 1, "effet": "Bâtiment de base", "cout": {}, "heures": 0}]
	etapes.append_array(b.get("niveaux", []))
	for i in etapes.size():
		var e: Dictionary = etapes[i]
		var en_cours: bool = jeu.chantier.get("bat", "") == id and int(jeu.chantier.n) == int(e.n)
		var couleur := C_VERT if int(e.n) <= n else (C_ACCENT if en_cours or int(e.n) == n + 1 else C_DISCRET)
		if i > 0:
			var lien := ColorRect.new()
			lien.color = Color(couleur, 0.6)
			lien.custom_minimum_size = Vector2(40, 4)
			lien.size_flags_vertical = SIZE_SHRINK_CENTER
			arbre.add_child(lien)
		var noeud := PanelContainer.new()
		noeud.add_theme_stylebox_override("panel", _boite(Color(couleur, 0.10), 16, couleur, 16))
		noeud.custom_minimum_size = Vector2(300, 0)
		arbre.add_child(noeud)
		var nv := VBoxContainer.new()
		nv.add_theme_constant_override("separation", 2)
		noeud.add_child(nv)
		var etat := "Acquis" if int(e.n) <= n else ("En chantier" if en_cours else ("Suivant" if int(e.n) == n + 1 else "Verrouillé"))
		_label("Niveau %d · %s" % [e.n, etat], 20, nv, couleur, true)
		_label(e.effet, 26, nv, C_TEXTE, true)
		if e.cout:
			var c := []
			for res in e.cout:
				c.append("%d %s" % [e.cout[res], jeu.R.ressources[res].nom.to_lower()])
			_label(", ".join(c), 20, nv, C_DISCRET)
			_label("%d h de travail" % e.heures, 20, nv, C_DISCRET)
		if en_cours:
			var bar := ProgressBar.new()
			bar.show_percentage = false
			bar.custom_minimum_size = Vector2(0, 10)
			bar.value = 100.0 * (1.0 - jeu.chantier.reste / jeu.chantier.total)
			nv.add_child(bar)
	# Action
	var v := jeu.verifier_amelioration(id)
	if jeu.chantier.get("bat", "") == id:
		var nb := jeu.ouvriers().size()
		_label("Chantier en cours : %s." % ("encore " + _duree(jeu.chantier.reste / nb * 3600.0) + " avec %d ouvrier(s)" % nb if nb > 0
			else "arrêté, aucun survivant au poste Chantier"), 24, vb, C_ACCENT)
	elif n < nmax:
		var bt := _bouton("Améliorer au niveau %d" % (n + 1), func(): _lancer_chantier(id), vb, true)
		bt.disabled = not v.ok
		if not v.ok:
			_label(" ".join(v.erreurs), 22, vb, C_ORANGE)
		_label("Le chantier avance grâce aux survivants affectés au poste Chantier ; deux ouvriers vont deux fois plus vite.", 20, vb, C_DISCRET).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bouton("Fermer", func(): fiche.visible = false, vb)


func _lancer_chantier(id: String) -> void:
	var r := jeu.ameliorer(id)
	if r.ok:
		Son.effet("sfx_atelier")
		_rebond(bat_noeuds[id])
	_maj()
	_fiche_batiment(id)


# Portrait d'un survivant (visage tiré de son nom).
class Portrait extends Control:
	var apparence := {}
	func _draw() -> void:
		Silhouette.portrait(self, size / 2, minf(size.x, size.y), apparence)


# Bulle au-dessus d'un bâtiment : flèche (amélioration possible) ou marteau (chantier).
class Bulle extends Control:
	var texte := ""
	var icone := ""
	var progres := -1.0
	var police: Font
	var _t := 0.0
	func _ready() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE
		var w := police.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
		size = Vector2(w + 76, 62 if progres >= 0 else 54)
	func _process(d: float) -> void:
		_t += d
		position.y += sin(_t * 3.0) * 0.15
		queue_redraw()
	func _draw() -> void:
		var fond := Color("#E8A33D") if icone == "fleche" else Color("#1B1D1F")
		var encre := Color("#1B1712") if icone == "fleche" else Color("#F2EEE6")
		var sb := StyleBoxFlat.new()
		sb.bg_color = fond
		sb.set_corner_radius_all(14)
		sb.anti_aliasing = true
		var h := 46.0 if progres < 0 else 54.0
		draw_style_box(sb, Rect2(0, 0, size.x, h))
		var mx := size.x / 2
		draw_colored_polygon(PackedVector2Array([Vector2(mx - 9, h - 1), Vector2(mx + 9, h - 1), Vector2(mx, h + 8)]), fond)
		var c := Vector2(28, 23)
		if icone == "fleche":
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -12), c + Vector2(11, 2), c + Vector2(4, 2),
				c + Vector2(4, 12), c + Vector2(-4, 12), c + Vector2(-4, 2), c + Vector2(-11, 2)]), encre)
		else:
			var a := sin(_t * 8.0) * 0.5 - 0.3
			var m := Vector2.from_angle(a - PI / 2)
			draw_line(c + Vector2(-2, 10), c + m * 10, Color("#A87A4A"), 4)
			draw_line(c + m * 10 + m.orthogonal() * 8, c + m * 10 - m.orthogonal() * 8, encre, 7)
		draw_string(police, Vector2(48, 31), texte, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, encre)
		if progres >= 0:
			draw_rect(Rect2(12, 42, size.x - 24, 6), Color(1, 1, 1, 0.15))
			draw_rect(Rect2(12, 42, (size.x - 24) * clampf(progres, 0, 1), 6), Color("#E8A33D"))


# Armurerie dessinée par le code (pas encore d'image peinte).
class BatimentDessin extends Control:
	func _draw() -> void:
		var w := size.x
		var h := size.y
		var sol := h
		# Bunker en béton, toit de tôle ondulée
		var b := Rect2(w * 0.12, h * 0.38, w * 0.62, h * 0.62)
		draw_rect(b, Color("#9C8768"))
		draw_rect(Rect2(b.position.x, b.position.y, b.size.x, 10), Color("#8C765A"))
		var toit := PackedVector2Array([Vector2(w * 0.06, h * 0.40), Vector2(w * 0.80, h * 0.40), Vector2(w * 0.74, h * 0.28), Vector2(w * 0.10, h * 0.28)])
		draw_colored_polygon(toit, Color("#6E6A62"))
		for i in 14:
			var x := lerpf(w * 0.10, w * 0.76, i / 13.0)
			draw_line(Vector2(x, h * 0.285), Vector2(x - 4, h * 0.395), Color("#57534C"), 2)
		# Porte sombre, plaque, meurtrière
		draw_rect(Rect2(w * 0.30, h * 0.58, w * 0.18, h * 0.42), Color("#2C241C"))
		draw_rect(Rect2(w * 0.32, h * 0.60, w * 0.14, h * 0.38), Color("#3A3026"))
		draw_rect(Rect2(w * 0.54, h * 0.52, w * 0.14, h * 0.05), Color("#2C241C"))
		# Sacs de sable devant
		for rang in 3:
			for i in 5:
				var cx := w * (0.02 + i * 0.075) + (rang % 2) * w * 0.035
				var cy := sol - 12 - rang * 18
				draw_circle(Vector2(cx, cy), 15, Color("#A88F68"))
				draw_arc(Vector2(cx, cy), 15, 0, TAU, 16, Color("#9C8462"), 2)
		# Caisses de munitions
		for i in 3:
			var r := Rect2(w * (0.76 + (i % 2) * 0.11), sol - 34 - (i / 2) * 34, w * 0.11, 32)
			draw_rect(r, Color("#55592F"))
			draw_rect(r, Color("#3A3D20"), false, 2)
			draw_line(r.position + Vector2(6, 16), r.end - Vector2(6, 16), Color("#C8B070"), 2)
		# Mât et fanion
		draw_line(Vector2(w * 0.70, h * 0.28), Vector2(w * 0.70, h * 0.02), Color("#3A3936"), 3)
		draw_colored_polygon(PackedVector2Array([Vector2(w * 0.70, h * 0.03), Vector2(w * 0.84, h * 0.08), Vector2(w * 0.70, h * 0.13)]), Color("#9A3A26"))
