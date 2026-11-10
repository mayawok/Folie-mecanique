# Capture : mission du maire (DEC-144 à DEC-147), dans le Kit. Argument : dossier de sortie.
extends SceneTree
var vue
var dossier := ""


func _photo(nom: String, frames := 40) -> void:
	for i in frames: await process_frame
	root.get_viewport().get_texture().get_image().save_jpg(dossier + "/mission_" + nom + ".jpg", 0.7)
	print("capture ", nom, " : phase=", vue.m.ville_phase(), " t=", snappedf(float(vue.m.ville.get("t", 0.0)), 0.1))


func _jusqua(cond: Callable, s_max: float) -> void:
	var s := 0.0
	while s < s_max and not cond.call():
		vue.m.avancer()
		vue.m.ennemis.clear()
		s += CombatModele.DT


func _init() -> void:
	dossier = OS.get_cmdline_user_args()[0]
	vue = ConvoiVue.new()
	root.add_child(vue)
	for i in 30: await process_frame
	vue._nouvelle_partie(5, {}, false, true)
	var m = vue.m
	m.stocks.gazole = 900.0
	m.monde.heure = 0.3
	vue.pause = true
	m.kit_ville()
	m.ordre_marche("avancer")
	_jusqua(func(): return m.ville_dedans(), 300.0)
	vue._ville_onglet = "maire"
	vue._ville_ferme = false
	vue._dial_sig = ""
	await _photo("1_maire", 20)
	vue._ville_onglet = "mission:carburant"
	vue._dial_sig = ""
	await _photo("2_offre", 20)
	m.mission_accepter("carburant")
	_jusqua(func(): return float(m.ville.t) > 2.6, 10.0)
	await _photo("3_atelier", 50)
	_jusqua(func(): return m.ville_phase() == "rassemblement" and float(m.ville.t) > 2.0, 20.0)
	await _photo("4_rassemblement", 50)
	_jusqua(func(): return float(m.ville.t) > 5.5, 10.0)
	await _photo("5_bonne_chance", 20)
	_jusqua(func(): return m.ville_phase() == "sortie", 60.0)
	await _photo("6_sortie", 40)
	_jusqua(func(): return m.ville_dedans(), 600.0)
	await _photo("7_livraison", 60)
	quit()
