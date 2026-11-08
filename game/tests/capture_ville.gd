# Capture : ville standard (DEC-140 à DEC-143). Argument : dossier de sortie.
#   xvfb-run godot --path game --rendering-driver opengl3 --resolution 1280x720 -s res://tests/capture_ville.gd -- /tmp/captures
extends SceneTree
var vue
var dossier := ""


func _photo(nom: String, frames := 45) -> void:
	for i in frames: await process_frame
	root.get_viewport().get_texture().get_image().save_jpg(dossier + "/ville_" + nom + ".jpg", 0.7)
	print("capture ", nom, " : phase=", vue.m.ville_phase(), " x_tete=", int(vue.m.x_tete), " x0=", int(vue.m.ville.get("x0", 0.0)))


func _jusqua(cond: Callable, s_max: float) -> void:
	var s := 0.0
	while s < s_max and not cond.call():
		vue.m.avancer()
		s += CombatModele.DT


func _init() -> void:
	dossier = OS.get_cmdline_user_args()[0]
	vue = ConvoiVue.new()
	root.add_child(vue)
	for i in 30: await process_frame
	vue._nouvelle_partie(7)
	var m = vue.m
	m._prochain_x = INF
	m.champs_on = false
	m.meteo_on = false
	m.monde._assaut_t = 1.0e9
	m.stocks.fuel_l = 500.0
	m.monde.heure = 0.35
	vue.pause = true
	m.ordre_marche("avancer")
	var x0: float = float(m.ville.x0)
	_jusqua(func(): return m.x_tete > x0 - 40.0, 900.0)
	await _photo("1_approche")
	_jusqua(func(): return m.ville_phase() == "ouverture" and float(m.ville.t) > 2.5, 200.0)
	await _photo("2_porte")
	_jusqua(func(): return m.ville_phase() == "entree" and m.x_tete > x0 + 8.0, 200.0)
	await _photo("3_passage")
	_jusqua(func(): return m.ville_dedans(), 200.0)
	await _photo("4_place", 80)
	vue._ville_ferme = true
	await _photo("5_place_sans_panneau", 30)
	m.monde.heure = 0.8
	await _photo("6_nuit", 40)
	m.monde.heure = 0.35
	vue._ville_ferme = false
	vue._action_marche()
	await _photo("7_sorties", 20)
	vue._ouvrir_carte()
	await _photo("8_carte", 20)
	vue._fermer_carte()
	vue.pause = true
	m.ville_partir(int(m.ville_sorties()[0].id))
	_jusqua(func(): return m.ville_phase() == "sortie", 300.0)
	await _photo("9_sortie")
	quit()
