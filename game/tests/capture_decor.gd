# Captures du décor terre : jour, soir, orage (lancer avec xvfb et un rendu opengl3)
extends SceneTree
func _init() -> void:
	var vue := ConvoiVue.new()
	root.add_child(vue)
	for i in 20: await process_frame
	vue._nouvelle_partie(7, {}, false, true)
	vue.m.kit_regler_zone("terre")
	vue.pause = false
	var d: String = OS.get_cmdline_user_args()[0]
	var scenes := [["jour", 0.35], ["soir", 0.58], ["orage", 0.35]]
	for sc in scenes:
		vue.m.kit_regler_heure(sc[1])
		if sc[0] == "orage":
			vue.m.kit_tempete()
			vue.terrain.orage = 1.0
		for i in 150: await process_frame
		root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [d, sc[0]])
	quit()
