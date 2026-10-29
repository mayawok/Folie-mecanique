# Garage : vitrine des 10 véhicules et des personnages, en formes simples.
# Le véhicule roule sur un désert bosselé (suspensions, chenilles) et peut tirer.
class_name Garage
extends Control

var main          # main.gd : styles et sortie
var terrain: Terrain
var vehicule: VehiculeDessin
var personnages: Control
var lbl_nom: Label
var lbl_fiche: Label
var lbl_statut: Label
var btn_rouler: Button
var btn_tirer: Button
var btn_mode: Button
var types := []
var index := 0
var roule := true
var mode_perso := false


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	types = VehiculeDessin.donnees().vehicules.keys()
	terrain = Terrain.new()
	add_child(terrain)
	vehicule = VehiculeDessin.new()
	vehicule.sol = Terrain.sol
	add_child(vehicule)
	personnages = Control.new()
	personnages.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(personnages)
	var m: Vector4 = main.marges
	# Fiche (haut gauche)
	var p: PanelContainer = main._panneau(self, 22)
	p.position = Vector2(m.x, m.y)
	p.custom_minimum_size = Vector2(760, 0)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	p.add_child(vb)
	main._label("GARAGE", 20, vb, main.C_DISCRET, true)
	lbl_nom = main._label("", 46, vb, main.C_TEXTE, true)
	lbl_fiche = main._label("", 24, vb, Color(main.C_TEXTE, 0.9))
	lbl_fiche.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_fiche.custom_minimum_size = Vector2(716, 0)
	lbl_statut = main._label("", 22, vb, main.C_ACCENT, true)
	# Commandes (bas)
	var pb: PanelContainer = main._panneau(self, 12)
	pb.anchor_top = 1.0
	pb.anchor_bottom = 1.0
	pb.anchor_left = 0.5
	pb.anchor_right = 0.5
	pb.grow_horizontal = GROW_DIRECTION_BOTH
	pb.grow_vertical = GROW_DIRECTION_BEGIN
	pb.offset_bottom = -m.w
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	pb.add_child(hb)
	for b in [main._bouton("◀", func(): _changer(-1), hb), main._bouton("▶", func(): _changer(1), hb)]:
		b.custom_minimum_size = Vector2(100, 80)
	btn_rouler = main._bouton("Arrêter", _basculer_roule, hb)
	btn_rouler.custom_minimum_size.x = 190
	btn_tirer = main._bouton("Tirer", _tirer, hb)
	btn_tirer.custom_minimum_size.x = 160
	btn_mode = main._bouton("Personnages", _basculer_mode, hb)
	btn_mode.custom_minimum_size.x = 240
	main._bouton("Retour", fermer, hb, true).custom_minimum_size.x = 180
	resized.connect(_placer)
	_choisir(0)


func _unhandled_input(e: InputEvent) -> void:
	if visible and e.is_action_pressed("ui_cancel"):
		fermer()
		get_viewport().set_input_as_handled()


func fermer() -> void:
	Son.moteur("")
	main._fermer_garage()


func _changer(d: int) -> void:
	_choisir(posmod(index + d, types.size()))


func _choisir(i: int) -> void:
	index = i
	var t: String = types[i]
	var d: Dictionary = VehiculeDessin.donnees().vehicules[t]
	var ecran := get_viewport_rect().size
	vehicule.ppm = minf(130.0, ecran.x * 0.5 / float(d.longueur))
	vehicule.configurer(t)
	lbl_nom.text = d.nom
	lbl_fiche.text = d.fiche
	var R: Dictionary = main.jeu.R
	lbl_statut.text = "Dans le prototype" if R.vehicules.has(t) else "Pas encore dans le jeu"
	_placer()
	_maj_son()


func _placer() -> void:
	var ecran := size
	terrain.ppm = vehicule.ppm if not mode_perso else 150.0
	terrain.sol_y = ecran.y * 0.80
	terrain.ancre_x = ecran.x * 0.5
	vehicule.position = Vector2(ecran.x * 0.5 - vehicule.size.x * 0.5, terrain.sol_y - vehicule.size.y)
	if mode_perso:
		_placer_personnages()


func _basculer_roule() -> void:
	roule = not roule
	btn_rouler.text = "Arrêter" if roule else "Rouler"
	_maj_son()


func _maj_son() -> void:
	var d: Dictionary = VehiculeDessin.donnees().vehicules[types[index]]
	Son.moteur("sfx_moteur_" + d.moteur if roule and not mode_perso and visible else "")


func _tirer() -> void:
	Son.effet("sfx_tir_" + vehicule.tirer())


func _basculer_mode() -> void:
	mode_perso = not mode_perso
	vehicule.visible = not mode_perso
	personnages.visible = mode_perso
	btn_tirer.disabled = mode_perso
	btn_mode.text = "Véhicules" if mode_perso else "Personnages"
	lbl_nom.text = "Personnages" if mode_perso else VehiculeDessin.donnees().vehicules[types[index]].nom
	lbl_fiche.text = "Silhouettes provisoires des survivants et des pillards." if mode_perso else VehiculeDessin.donnees().vehicules[types[index]].fiche
	lbl_statut.text = ""
	_placer()
	_maj_son()


func _placer_personnages() -> void:
	for c in personnages.get_children():
		c.queue_free()
	var ids := Silhouette.VARIANTES.keys()
	var pas := minf(240.0, (size.x - 200) / ids.size())
	var x0 := size.x * 0.5 - pas * (ids.size() - 1) * 0.5
	for i in ids.size():
		var s := Silhouette.new()
		s.variante = ids[i]
		s.pose = "marche" if roule else "debout"
		s.ppm = 150.0
		s.peau = i
		s.phase = i * 0.7
		personnages.add_child(s)
		s.size = s.custom_minimum_size
		s.position = Vector2(x0 + i * pas - s.size.x / 2, terrain.sol_y - s.size.y + 4)
		var l: Label = main._label(Silhouette.VARIANTES[ids[i]].nom, 24, personnages, main.C_TEXTE, true)
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
		l.add_theme_constant_override("shadow_offset_y", 2)
		l.position = Vector2(x0 + i * pas - l.get_minimum_size().x / 2, terrain.sol_y + 30)


func _process(delta: float) -> void:
	if not visible:
		return
	var v := 0.0
	if roule:
		v = 1.4 if mode_perso else 4.0
	terrain.camera_x += v * delta
	vehicule.vitesse = v
	vehicule.x_monde = terrain.camera_x - (terrain.ancre_x - vehicule.position.x) / vehicule.ppm
	if mode_perso:
		for s in personnages.get_children():
			if s is Silhouette:
				s.pose = "marche" if roule else "debout"
				if not roule:
					s.phase = 0.0
					s.queue_redraw()
