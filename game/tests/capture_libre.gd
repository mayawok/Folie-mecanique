# Parcours joué à l'écran : menu principal, bac à sable, grille d'un véhicule historique (convertie),
# construction au doigt d'un véhicule neuf (rectangles de châssis, essieux puis roues, pièces, équipage), puis le convoi sur la route.
#   xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 --resolution 1280x720 \
#     -s res://tests/capture_libre.gd -- /chemin/dossier
extends SceneTree

var vue
var frame := 0
var dossier := "/tmp"
var echecs := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		dossier = args[0]
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://convoi_save.json"))
	vue = load("res://scenes/convoi.tscn").instantiate()
	root.add_child(vue)


func _photo(nom: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	root.get_texture().get_image().save_png("%s/%s.png" % [dossier, nom])
	print("capture ", nom)


func _verifier(c: bool, msg: String) -> void:
	print(("OK   " if c else "ÉCHEC ") + msg)
	if not c:
		echecs += 1


func _clic(ed, p: Vector2, appui: bool) -> void:
	var e := InputEventMouseButton.new()
	e.position = p
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = appui
	ed._gui_input(e)


func _glisser(ed, p: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = p
	ed._gui_input(e)


func _ecran(ed, x: float, y: float) -> Vector2:   # cellule -> écran (centre)
	return ed._px(x + 0.5, y + 0.5)


func _process(_d: float) -> bool:
	frame += 1
	var m: CombatModele = vue.m
	match frame:
		6:
			_verifier(vue._voile_menu.visible, "menu principal affiché au démarrage")
			_photo("libre_0_menu")
		8:
			vue._nouvelle_partie(11, {}, false, true)
			_verifier(vue.m.bac_a_sable and not vue._voile_menu.visible, "bac à sable lancé")
		20:
			vue._ouvrir_editeur(m.convoi[0].uid)
			_verifier(vue._editeur != null and vue.pause, "grille de la Jeep ouverte, jeu en pause")
		26:
			_photo("libre_1_grille_jeep")
			vue._editeur.queue_free()
			vue._editeur = null
			vue.pause = false
		30:
			vue._ouvrir_editeur(0)
		34:
			var ed = vue._editeur
			# 1. Châssis tracé en rectangles (DEC-057) : une rangée d'acier, une de blindage
			ed._choisir_onglet("chassis")
			_clic(ed, _ecran(ed, 16, 3), true)
			_glisser(ed, _ecran(ed, 33, 3))
			_clic(ed, _ecran(ed, 33, 3), false)
			ed.outil.chassis = "blindage"
			_clic(ed, _ecran(ed, 18, 4), true)
			_glisser(ed, _ecran(ed, 31, 4))
			_clic(ed, _ecran(ed, 31, 4), false)
			_verifier(ed.a.cases.size() == 32, "32 cases tracées en deux rectangles (%d)" % ed.a.cases.size())
			_verifier(ed._cell >= 40.0, "cases assez grandes pour le doigt (%d px)" % int(ed._cell))
		38:
			_photo("libre_2_chassis")
			var ed = vue._editeur
			# 2. Essieux d'abord, roues ensuite (DEC-051)
			ed._choisir_onglet("essieux")
			ed.outil.essieux = "essieu_lourd"
			for x in [18, 21, 24, 27, 30]:
				_clic(ed, _ecran(ed, x, 3), true)
				_clic(ed, _ecran(ed, x, 3), false)
			ed.outil.essieux = "essieu_leger"
			_clic(ed, _ecran(ed, 33, 3), true)
			_clic(ed, _ecran(ed, 33, 3), false)
			_verifier(ConstructionLibre.essieux_nus(ed.a).size() == 6, "six essieux posés, encore sans roue")
			ed._choisir_onglet("roues")
			ed.outil.roues = "chenille"
			for x in [18, 21, 24, 27, 30]:
				_clic(ed, _ecran(ed, x, 3), true)
				_clic(ed, _ecran(ed, x, 3), false)
			ed.outil.roues = "roue_grande"
			_clic(ed, _ecran(ed, 33, 3), true)
			_clic(ed, _ecran(ed, 33, 3), false)
			_verifier(ConstructionLibre.essieux_nus(ed.a).is_empty(), "roues et chenilles montées sur les essieux")
		42:
			_photo("libre_3_essieux")
			var ed = vue._editeur
			# 3. Pièces glissées depuis leur catégorie
			for p in [["moteur", "moteur_m3_half_track", 19, 5], ["moteur", "radiateur_camion", 25, 5], ["cabine", "cabine_m3_half_track", 26, 5], ["arme", "arme_mortier", 19, 8], ["arme", "arme_mitrailleuse", 28, 9]]:
				ed._choisir_onglet(p[0])
				var e: Array = Assemblage.piece(p[1]).emprise
				ed._glisse = p[1]
				var pos: Vector2 = ed._px(p[2] + e[0] * 0.5, p[3] + e[1] * 0.5) + Vector2(0, ed.DECALAGE_DOIGT * ed._cell)
				_glisser(ed, pos)
				_clic(ed, pos, false)
			_verifier(ed.a.pieces.size() == 5, "moteur, radiateur, cabine, mortier, mitrailleuse posés (%d)" % ed.a.pieces.size())
			_verifier(not String(ed.a.nom).begins_with("Frankenstein"), "nom proposé : %s" % ed.a.nom)
		46:
			var ed = vue._editeur
			ed._choisir_onglet("arme")
			ed._glisse = "arme_canon_75"
			ed._appui = true
			_glisser(ed, ed._px(22, 11) + Vector2(0, ed.DECALAGE_DOIGT * ed._cell))
			_photo("libre_4_pieces")
			ed._glisse = ""
			ed._appui = false
			ed._choisir_onglet("equipage")
			print("défauts : ", ed._an.defauts.map(func(d): return d.texte))
			print("stats : ", ed._an.stats.vitesse, " m/s, ", ed._an.stats.poids_kg, " kg")
		47:
			_photo("libre_4b_equipage")
		48:
			var ed = vue._editeur
			var n := m.convoi.size()
			ed._terminer()
			_verifier(m.convoi.size() == n + 1, "véhicule construit, il rejoint le convoi")
		50:
			vue.selection = m.convoi.back().uid
			m.ordre_marche("avancer")
		140:
			vue.terrain.camera_x = m.convoi.back().x + 6.0
		146:
			_photo("libre_5_route")
			print("TOUT EST OK" if echecs == 0 else "%d ÉCHEC(S)" % echecs)
			quit(1 if echecs > 0 else 0)
	return false
