# Captures de l'annonce des groupes d'ennemis (DEC-253) : un niveau d'agressivité par image (vert, jaune, orange, rouge).
#   xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 --resolution 1280x720 \
#     -s res://tests/capture_groupes.gd -- /chemin/dossier
extends SceneTree
func _init() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://convoi_save.json"))
	var vue := ConvoiVue.new()
	root.add_child(vue)
	for i in 20: await process_frame
	vue._nouvelle_partie(7, {}, false, true)
	var m: CombatModele = vue.m
	m.kit_regler_zone("sable")
	m.kit_regler_heure(0.4)
	m._prochain_x = INF
	m.stocks.gazole = 500.0
	m.stocks.ammo = 300.0
	vue.pause = false
	m.ordre_marche("avancer")
	var d: String = OS.get_cmdline_user_args()[0]
	var n := 1
	for c in [["marchands", "droite", "vert"], ["patrouille", "droite", "jaune"], ["raid", "gauche", "orange"], ["assaut", "droite", "rouge"]]:
		m.kit_scenario(c[0], "moyen", c[1])
		for i in 40: await process_frame
		root.get_viewport().get_texture().get_image().save_jpg("%s/groupe_%d_%s.jpg" % [d, n, c[2]], 0.85)
		n += 1
		m.ennemis.clear()
		for i in 120: await process_frame
	quit()
