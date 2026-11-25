# Captures d'un saut sur une crête (DEC-261) : le convoi file dans le sable, la tête décolle, puis retombe.
#   xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 --resolution 1280x720 \
#     -s res://tests/capture_sauts.gd -- /chemin/dossier
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
	var d: String = OS.get_cmdline_user_args()[0]
	# placer le convoi juste avant une crête
	var t = vue.m._tete()
	var cible := -1.0
	for i in range(int(t.x / 240.0) + 1, 400):
		var c := Terrain.crete_case(float(i))
		if not c.is_empty() and float(c[3]) > 0.6:
			cible = float(c[0])
			break
	var dx: float = cible - 25.0 - (t.x + t.longueur)
	vue.m.x_tete += dx
	vue.m.x_tete_prev = vue.m.x_tete
	for v in vue.m.convoi:
		v.x += dx
		v.x_prev = v.x
		v.x_cible += dx
	vue.m.trans.urgence = true
	vue.m.ordre_marche("avancer")
	while t.x + t.longueur < cible:   # vitesse de croisière avant la crête
		await process_frame
		vue.m.trans.urgence_t = 99.0
	Engine.time_scale = 0.12   # ralenti : le rendu logiciel est lent, un vol ne dure que quelques dixièmes de seconde
	var n := 0
	var vu := false
	for i in 2000:
		await process_frame
		vue.m.trans.urgence_t = 99.0
		var en_l_air := false
		for v in vue.m.convoi:
			en_l_air = en_l_air or v.haut > 0.05
		if en_l_air and n < 4:
			n += 1
			root.get_viewport().get_texture().get_image().save_jpg("%s/saut_%d.jpg" % [d, n], 0.85)
			for k in 2: await process_frame
			vu = true
		elif vu and (n >= 4 or not en_l_air):
			break
	print("captures de saut : ", n)
	quit()
