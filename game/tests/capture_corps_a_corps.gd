# Captures du corps à corps (DEC-255) : choc avec étincelles et débris, blindé de fortune, bagarre sur le toit.
#   xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 --resolution 1280x720 \
#     -s res://tests/capture_corps_a_corps.gd -- /chemin/dossier
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
	# 1) blindé de fortune qui charge
	var b := m.creer_vehicule("opel_blitz", "ennemi", m.x_tete + 40.0)
	b.mode = "approche"
	m.fortune(b)
	m._role[b.uid] = "belier"
	m.ennemis.append(b)
	for i in 70: await process_frame
	root.get_viewport().get_texture().get_image().save_jpg("%s/cac_1_fortune.jpg" % d, 0.85)
	# 2) choc fort : étincelles et débris
	for i in 150:
		await process_frame
		if not vue._debris.is_empty():
			break
	for i in 6: await process_frame
	root.get_viewport().get_texture().get_image().save_jpg("%s/cac_2_choc.jpg" % d, 0.85)
	# 3) poursuite, abordage
	m.ennemis.clear()
	m.kit_scenario("assaut", "grand", "gauche")
	for i in 400:
		await process_frame
		if m.abordeurs.size() >= 2:
			break
	for i in 25: await process_frame
	root.get_viewport().get_texture().get_image().save_jpg("%s/cac_3_abordage.jpg" % d, 0.85)
	quit()
