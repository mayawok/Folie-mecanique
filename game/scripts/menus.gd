# Menu principal (convoi qui roule dans le désert), menu pause et options de son.
# Le jeu est en temps réel : la pause n'arrête pas le monde, elle masque la base.
class_name Menus
extends Control

var main          # main.gd
var titre: Control
var terrain: Terrain
var convoi := []
var pause: ColorRect
var options: ColorRect
var confirmation: ColorRect
var _pause_vers := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	_construire_titre()
	pause = _voile()
	options = _voile()
	confirmation = _voile()
	_construire_pause()
	_construire_options()


func _voile() -> ColorRect:
	var v := ColorRect.new()
	v.color = Color(0, 0, 0, 0.6)
	v.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	v.visible = false
	add_child(v)
	return v


func _centre(parent: Control, largeur: float) -> VBoxContainer:
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	parent.add_child(c)
	var p: PanelContainer = main._panneau(c, 36)
	(p.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = Color("#141618")
	p.custom_minimum_size = Vector2(largeur, 0)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	p.add_child(vb)
	return vb


# --- Écran titre ------------------------------------------------------------

func _construire_titre() -> void:
	titre = Control.new()
	titre.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(titre)
	terrain = Terrain.new()
	terrain.ppm = 58.0
	titre.add_child(terrain)
	for t in ["willys_mb", "m3_half_track", "m4_sherman"]:
		var v := VehiculeDessin.new()
		v.type = t
		v.ppm = 58.0
		v.sol = Terrain.sol
		v.vitesse = 3.0
		titre.add_child(v)
		convoi.append(v)
	# Bandeau sombre à gauche pour la lisibilité
	var ombre := TextureRect.new()
	var g := GradientTexture2D.new()
	g.gradient = Gradient.new()
	g.gradient.set_color(0, Color(0.05, 0.04, 0.03, 0.88))
	g.gradient.set_color(1, Color(0.05, 0.04, 0.03, 0.0))
	ombre.texture = g
	ombre.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ombre.anchor_bottom = 1.0
	ombre.offset_right = 1100
	ombre.mouse_filter = MOUSE_FILTER_IGNORE
	titre.add_child(ombre)
	var m: Vector4 = main.marges
	var vb := VBoxContainer.new()
	vb.position = Vector2(m.x + 70, m.y + 90)
	vb.custom_minimum_size = Vector2(560, 0)
	vb.add_theme_constant_override("separation", 18)
	titre.add_child(vb)
	main._label("FOLIE", 110, vb, main.C_ACCENT, true)
	main._label("MÉCANIQUE", 110, vb, main.C_TEXTE, true)
	main._label("Prototype · Désert, 1940 et quelques", 26, vb, main.C_DISCRET)
	var esp := Control.new()
	esp.custom_minimum_size = Vector2(0, 30)
	vb.add_child(esp)
	main._bouton("Continuer", fermer_titre, vb, true)
	main._bouton("Nouvelle partie", func(): confirmation.visible = true, vb)
	main._bouton("Garage", func(): main._ouvrir_garage(), vb)
	main._bouton("Options", func(): options.visible = true, vb)
	var version := "locale"
	if FileAccess.file_exists("res://data/version.json"):
		var d = JSON.parse_string(FileAccess.get_file_as_string("res://data/version.json"))
		if typeof(d) == TYPE_DICTIONARY:
			version = d.get("version", version)
	var ver: Label = main._label("Version du %s" % version, 20, titre, main.C_DISCRET)
	ver.anchor_top = 1.0
	ver.anchor_bottom = 1.0
	ver.offset_left = m.x + 70
	ver.offset_top = -m.w - 40


func afficher_titre() -> void:
	titre.visible = true
	pause.visible = false
	Son.musique("mus_menu")
	Son.moteur("sfx_moteur_semi_chenille")


func fermer_titre() -> void:
	titre.visible = false
	Son.moteur("")
	main._entrer_base()


func titre_visible() -> bool:
	return titre.visible


func _process(delta: float) -> void:
	if not titre.visible:
		return
	var ecran := size
	terrain.sol_y = ecran.y * 0.86
	terrain.ancre_x = ecran.x * 0.5
	terrain.camera_x += 3.0 * delta
	var x := ecran.x - 120.0
	for i in range(convoi.size() - 1, -1, -1):   # le char en tête, à droite
		var v: VehiculeDessin = convoi[i]
		x -= v.size.x
		v.position = Vector2(x, terrain.sol_y - v.size.y)
		v.x_monde = terrain.camera_x + (x - terrain.ancre_x) / terrain.ppm
		x -= 110.0


# --- Pause ------------------------------------------------------------------

func _construire_pause() -> void:
	var vb := _centre(pause, 620)
	main._label("PAUSE", 46, vb, main.C_TEXTE, true)
	var n: Label = main._label("Le monde continue d'avancer : 1 jour de jeu = 1 jour réel.", 24, vb, main.C_DISCRET)
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main._bouton("Reprendre", basculer_pause, vb, true)
	main._bouton("Options", func(): options.visible = true, vb)
	main._bouton("Garage", func(): pause.visible = false; main._ouvrir_garage(), vb)
	main._bouton("Menu principal", func(): pause.visible = false; afficher_titre(), vb)


func basculer_pause() -> void:
	if titre.visible:
		return
	pause.visible = not pause.visible
	options.visible = false


# --- Options et confirmation ------------------------------------------------

func _construire_options() -> void:
	var vb := _centre(options, 700)
	main._label("OPTIONS", 40, vb, main.C_TEXTE, true)
	for b in Son.BUS:
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 20)
		vb.add_child(hb)
		var l: Label = main._label({"Musique": "Musique", "Effets": "Bruitages", "Voix": "Voix"}[b], 28, hb)
		l.custom_minimum_size = Vector2(200, 0)
		var s := HSlider.new()
		s.min_value = 0.0
		s.max_value = 1.0
		s.step = 0.05
		s.value = Son.volumes[b]
		s.custom_minimum_size = Vector2(400, 60)
		s.size_flags_vertical = SIZE_SHRINK_CENTER
		s.value_changed.connect(func(val): Son.regler(b, val))
		s.drag_ended.connect(func(_c): Son.effet("sfx_ui_clic"))
		hb.add_child(s)
	main._bouton("Fermer", func(): options.visible = false, vb, true)
	# Confirmation de nouvelle partie
	var vc := _centre(confirmation, 700)
	main._label("Nouvelle partie ?", 40, vc, main.C_TEXTE, true)
	var t: Label = main._label("La partie en cours sera effacée définitivement.", 26, vc, main.C_DISCRET)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var hb2 := HBoxContainer.new()
	hb2.add_theme_constant_override("separation", 12)
	vc.add_child(hb2)
	main._bouton("Annuler", func(): confirmation.visible = false, hb2).size_flags_horizontal = SIZE_EXPAND_FILL
	main._bouton("Effacer et commencer", _confirmer_nouvelle, hb2, true).size_flags_horizontal = SIZE_EXPAND_FILL


func _confirmer_nouvelle() -> void:
	confirmation.visible = false
	main._nouvelle_partie()
	fermer_titre()
