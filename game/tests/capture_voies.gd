# Captures des voies de profondeur (DEC-250) : un poursuivant au fond, une moto devant, le convoi au milieu.
#   xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 --resolution 1280x720 \
#     -s res://tests/capture_voies.gd -- /chemin/dossier
extends SceneTree
func _init() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://convoi_save.json"))
	var vue := ConvoiVue.new()
	root.add_child(vue)
	for i in 20: await process_frame
	vue._nouvelle_partie(7, {}, false, true)
	vue.m.kit_regler_zone("sable")
	vue.m.kit_regler_heure(0.4)
	vue.m._prochain_x = INF
	vue.pause = false
	vue.m.ordre_marche("avancer")
	for i in 30: await process_frame
	var t = vue.m._tete()
	var d: String = OS.get_cmdline_user_args()[0]
	# un poursuivant au fond, une moto qui remonte devant, un harceleur derrière au milieu
	for spec in [["citroen_traction", -1, -3.0], ["bmw_r75", 1, -1.0], ["willys_mb", 0, -22.0]]:
		var e = vue.m.creer_vehicule(spec[0], "ennemi", t.x + spec[2])
		e.mode = "poursuite" if spec[1] != 0 else "harcele"
		vue.m._cote[e.uid] = spec[1]
		vue.m._place[e.uid] = true
		e.voie_f = float(spec[1])
		e.armes = []
		vue.m.ennemis.append(e)
	for i in 40: await process_frame
	root.get_viewport().get_texture().get_image().save_jpg("%s/voies_jour.jpg" % d, 0.85)
	vue.m.kit_regler_heure(0.9)
	for i in 60: await process_frame
	root.get_viewport().get_texture().get_image().save_jpg("%s/voies_nuit.jpg" % d, 0.85)
	quit()
