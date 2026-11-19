# Captures de la formation de combat (DEC-251) : route calme, début du combat (bandeau), formation en place, nuit avec phares,
# bâtiments derrière et devant la route.
#   xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 --resolution 1280x720 \
#     -s res://tests/capture_formation.gd -- /chemin/dossier
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
	m.convoi.clear()
	var b := m.creer_vehicule("berliet_gdr", "joueur", m.x_tete - 8.0)
	b.principal = true
	m.convoi.append(b)
	for t in ["bmw_r75", "willys_mb", "bmw_r75"]:
		m.convoi.append(m.creer_vehicule(t, "joueur", m.x_tete - 30.0))
	m._replacer(true)
	m.stocks.gazole = 500.0
	m.stocks.ammo = 300.0
	vue.pause = false
	m.ordre_marche("avancer")
	var d: String = OS.get_cmdline_user_args()[0]
	for i in 90: await process_frame
	root.get_viewport().get_texture().get_image().save_jpg("%s/formation_1_route.jpg" % d, 0.85)
	# deux poursuivants arrivent par l'arrière
	var xq: float = m._queue().x
	for k in 2:
		var e := m.creer_vehicule("citroen_traction" if k == 0 else "willys_mb", "ennemi", xq - 48.0 - 14.0 * k)
		m.preparer_poursuivant(e, {"abordeurs": 1, "types": ["lame"]})
		m.ennemis.append(e)
	var n := 0
	while not m.en_combat and n < 300:
		await process_frame
		n += 1
	for i in 14: await process_frame
	root.get_viewport().get_texture().get_image().save_jpg("%s/formation_2_contact.jpg" % d, 0.85)
	for i in 90: await process_frame
	root.get_viewport().get_texture().get_image().save_jpg("%s/formation_3_en_place.jpg" % d, 0.85)
	m.kit_regler_heure(0.9)
	for i in 40: await process_frame
	root.get_viewport().get_texture().get_image().save_jpg("%s/formation_4_nuit.jpg" % d, 0.85)
	# bâtiments : une ferme derrière la route, une grange devant
	m.ennemis.clear()
	m.kit_regler_heure(0.4)
	for k in 2:
		var bat := m.creer_batiment("ferme" if k == 0 else "grange", m.x_tete + (26.0 if k == 0 else 70.0))
		bat.voie = -1 if k == 0 else 1
		bat.statut = "neutralise"
		m.batiments.append(bat)
	for i in 60: await process_frame
	root.get_viewport().get_texture().get_image().save_jpg("%s/formation_5_batiment_fond.jpg" % d, 0.85)
	for i in 150: await process_frame
	root.get_viewport().get_texture().get_image().save_jpg("%s/formation_6_batiment_devant.jpg" % d, 0.85)
	quit()
