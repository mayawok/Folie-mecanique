# Capture DEC-081 : véhicule penché (grandes roues derrière) sur la route, et grille avec l'outil Déplacer.
#   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path game --rendering-driver opengl3 -s res://tests/capture_penche.gd -- /chemin/dossier
extends SceneTree

var vue
var frame := 0
var dossier := "/tmp"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		dossier = args[0]
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://convoi_save.json"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://grille_brouillon.json"))
	vue = load("res://scenes/convoi.tscn").instantiate()
	root.add_child(vue)


func _photo(nom: String) -> void:
	root.get_texture().get_image().save_png("%s/%s.png" % [dossier, nom])
	print("capture ", nom)


func penche() -> Dictionary:
	var a := ConstructionLibre.nouvelle("Le Cabré")
	for x in range(8, 26):
		a = ConstructionLibre.peindre(a, Vector2i(x, 5), "acier")
	a = ConstructionLibre.poser_essieu(a, 10, "essieu_lourd", "roue_geante")
	a = ConstructionLibre.poser_essieu(a, 23, "essieu_leger", "roue_petite")
	a = ConstructionLibre.poser(a, "poste_conduite", Vector2i(14, 6))
	a = ConstructionLibre.poser(a, "moteur_willys_mb", Vector2i(18, 6))
	a = ConstructionLibre.poser(a, "radiateur_voiture", Vector2i(22, 6))
	a.nom_choisi = true
	return a


func _process(_d: float) -> bool:
	frame += 1
	var m: CombatModele = vue.m if vue != null else null
	match frame:
		8:
			vue._nouvelle_partie(11, {}, false, true)
		20:
			vue._ouvrir_editeur(0)
		24:
			var ed = vue._editeur
			ed.a = penche()
			ed._choisir_onglet("vehicule")
			ed._maj(true)
			print("défauts : ", ed._an.get("defauts", []).map(func(d): return d.texte), " immobile=", ed._an.stats.get("immobile", ""))
			var x0: int = int(ed.a.cases[0][0])
			var p0: Vector2 = ed._px(float(x0) + 0.5, float(ed.a.cases[0][1]) + 0.5)
			ed._doigt = p0
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = true
			ev.position = p0
			ed._gui_input(ev)
			var mv := InputEventMouseMotion.new()
			mv.position = p0 + Vector2(3 * ed._cell, -ed._cell)
			ed._doigt = mv.position
			ed._gui_input(mv)
		26:
			var ed = vue._editeur
			var x0: int = int(ed.a.cases[0][0])
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = false
			ev.position = ed._doigt
			ed._gui_input(ev)
			print("OK  " if int(ed.a.cases[0][0]) == x0 + 3 else "ÉCHEC ", "véhicule déplacé de 3 cases : ", x0, " → ", int(ed.a.cases[0][0]))
		28:
			_photo("p081_1_grille_deplacer")
			var ed = vue._editeur
			ed._terminer()
			if vue._editeur != null:
				vue._editeur._terminer()
			var v = m.convoi.back()
			v.x_prev = v.x
			m.ordre_marche("avancer")
		90:
			vue.selection = m.convoi.back().uid
			vue.terrain.camera_x = m.convoi.back().x + 5.0
		110:
			_photo("p081_2_route")
			quit()
	return false
