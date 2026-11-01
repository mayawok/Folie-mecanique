# Parcours joué à l'écran : menu principal, bac à sable, grille d'un véhicule historique (convertie),
# construction au doigt d'un véhicule neuf (peindre, essieux, pièces), puis le convoi sur la route.
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
			# 1. Peindre : une caisse de 18 cases, deux rangs dont un en blindage
			_clic(ed, _ecran(ed, 6, 3), true)
			for x in range(6, 24):
				_glisser(ed, _ecran(ed, x, 3))
			_clic(ed, _ecran(ed, 23, 3), false)
			ed.pinceau = "blindage"
			_clic(ed, _ecran(ed, 8, 4), true)
			for x in range(8, 22):
				_glisser(ed, _ecran(ed, x, 4))
			_clic(ed, _ecran(ed, 21, 4), false)
			_verifier(ed.a.cases.size() == 32, "32 cases peintes au doigt (%d)" % ed.a.cases.size())
		38:
			_photo("libre_2_chassis")
			var ed = vue._editeur
			ed._btn_suiv.pressed.emit()
			_verifier(ed.etape == 2, "le bouton Suivant mène aux essieux")
			ed.essieu_choisi = "essieu_lourd"
			ed.train_choisi = "chenille"
			for x in [8, 11, 14, 17, 20]:
				_clic(ed, _ecran(ed, x, 3), true)
				_clic(ed, _ecran(ed, x, 3), false)
			ed.train_choisi = "roue_grande"
			_clic(ed, _ecran(ed, 23, 3), true)
			_clic(ed, _ecran(ed, 23, 3), false)
			_verifier(ed.a.essieux.size() == 6, "six essieux posés : chenille et une roue avant")
		42:
			_photo("libre_3_essieux")
			var ed = vue._editeur
			ed._etape(3)
			for p in [["moteur_m3_half_track", 9, 5], ["cabine_m3_half_track", 16, 5], ["arme_mortier", 9, 8], ["arme_mitrailleuse", 18, 9]]:
				ed._sel = p[0]
				ed._doigt = _ecran(ed, p[1], p[2])
				_clic(ed, ed._doigt, true)
				_clic(ed, ed._doigt, false)
			_verifier(ed.a.pieces.size() == 4, "moteur, cabine, mortier, mitrailleuse posés (%d)" % ed.a.pieces.size())
		46:
			var ed = vue._editeur
			ed._doigt = _ecran(ed, 12, 10)
			ed._sel = "arme_canon_75"
			_photo("libre_4_pieces")
			print("défauts : ", ed._an.defauts.map(func(d): return d.texte))
			print("stats : ", ed._an.stats.vitesse, " m/s, ", ed._an.stats.poids_kg, " kg")
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
