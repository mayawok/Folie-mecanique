# Capture : ville pillée (DEC-151), dans le Kit.
extends SceneTree
var vue
var dossier := ""


func _photo(nom: String, frames := 40) -> void:
	for i in frames: await process_frame
	root.get_viewport().get_texture().get_image().save_jpg(dossier + "/pillee_" + nom + ".jpg", 0.7)
	print("capture ", nom, " : phase=", vue.m.ville_phase())


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
	vue._nouvelle_partie(6, {}, false, true)
	var m = vue.m
	m.monde.heure = 0.3
	vue.pause = true
	m.kit_ville("pillee")
	m.ordre_marche("avancer")
	_jusqua(func(): return m.x_tete > float(m.ville.x0) - 30.0, 200.0)
	await _photo("1_approche")
	_jusqua(func(): return m.ville_phase() == "entree" and m.x_tete > float(m.ville.x0) + 20.0, 100.0)
	await _photo("2_entree")
	_jusqua(func(): return m.ville_dedans(), 200.0)
	await _photo("3_recit", 60)
	vue._ville_ferme = true
	m.monde.heure = 0.8
	await _photo("4_nuit", 40)
	m.monde.heure = 0.3
	m.ville_poursuite()
	_jusqua(func(): return m.evenement.get("phase", "") == "chasse", 120.0)
	_jusqua(func(): return m.ennemis.any(func(e): return e.x - m.x_tete < 60.0), 120.0)
	await _photo("5_poursuite", 40)
	quit()
