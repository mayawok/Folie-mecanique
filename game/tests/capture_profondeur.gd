# Captures du lot profondeur (DEC-249) : zone sable du Kit, jour, soir, nuit (lancer avec xvfb et un rendu opengl3)
#   xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 --resolution 1280x720 \
#     -s res://tests/capture_profondeur.gd -- /chemin/dossier
extends SceneTree
func _init() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://convoi_save.json"))
	var vue := ConvoiVue.new()
	root.add_child(vue)
	for i in 20: await process_frame
	vue._nouvelle_partie(7, {}, false, true)
	vue.m.kit_regler_zone("sable")
	vue.pause = false
	vue.m.ordre_marche("avancer")
	var d: String = OS.get_cmdline_user_args()[0]
	for sc in [["profondeur_jour", 0.35], ["profondeur_soir", 0.58], ["profondeur_nuit", 0.9]]:
		vue.m.kit_regler_heure(sc[1])
		if sc[0] == "profondeur_nuit":
			vue.m.convoi[0].profil["phares"] = 1   # pour la capture : un véhicule avec phares (pièce de la grille, DEC-048)
		for i in 150: await process_frame
		if sc[0] == "profondeur_nuit":
			vue._explosions.append({"p": Vector2(vue.m.x_tete + 9.0, 0.6), "age": 0.25, "taille": 1.2})
		root.get_viewport().get_texture().get_image().save_jpg("%s/%s.jpg" % [d, sc[0]], 0.85)
	quit()
