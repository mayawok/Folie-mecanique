# Captures du décor de chaque région (DEV-008, DEC-264), de jour, plus quelques-unes de nuit.
#   xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 --resolution 1280x720 \
#     -s res://tests/capture_regions.gd -- /chemin/dossier
extends SceneTree
func _init() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://convoi_save.json"))
	var vue := ConvoiVue.new()
	root.add_child(vue)
	for i in 20: await process_frame
	vue._nouvelle_partie(7, {}, false, true)
	vue.m._prochain_x = INF
	vue.pause = false
	vue.m.ordre_marche("avancer")
	var d: String = OS.get_cmdline_user_args()[0]
	var liste := []
	for R in CarteMonde.regions():
		liste.append([String(R.id), 0.38])
	for id in ["pays_noir", "landes", "alpes"]:
		liste.append([id, 0.9])
	for sc in liste:
		vue.m.kit_regler_decor_region(sc[0])
		vue.m.kit_regler_heure(sc[1])
		for i in 40: await process_frame
		root.get_viewport().get_texture().get_image().save_jpg("%s/region_%s%s.jpg" % [d, sc[0], "_nuit" if sc[1] > 0.8 else ""], 0.85)
	print("captures des régions : ", liste.size())
	quit()
