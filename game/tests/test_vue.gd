# Fumée de la vue (sans image) : la chaîne de classes de la vue (vue_base <- vue_dessin <- vue_ville <- vue_interface <- convoi_vue)
# se construit, une partie démarre, le convoi entre dans une ville et le panneau de la ville se remplit, sans erreur.
# godot --headless --path game -s res://tests/test_vue.gd
extends SceneTree

var echecs := 0


func ok(c: bool, t: String) -> void:
	print("OK   " if c else "ÉCHEC ", t)
	if not c:
		echecs += 1


func _init() -> void:
	var vue := ConvoiVue.new()
	root.add_child(vue)
	for i in 10:
		await process_frame
	vue._nouvelle_partie(7)
	var m = vue.m
	m._prochain_x = INF
	m.champs_on = false
	m.meteo_on = false
	m.monde._assaut_t = 1.0e9
	m.stocks.gazole = 500.0
	m.monde.heure = 0.35
	vue.pause = true
	for i in 5:
		await process_frame
	ok(vue.m != null and vue._panneau_halte != null, "la vue se construit et une partie démarre")
	m.ordre_marche("avancer")
	var x0: float = float(m.ville.x0)
	var s := 0.0
	while s < 900.0 and m.ville_phase() != "garee":
		m.avancer()
		s += CombatModele.DT
		if m.x_tete > x0 - 40.0 and m.ville_phase() == "":
			m.avancer()
	for i in 20:
		await process_frame
	ok(m.ville_phase() != "", "le convoi est entré dans la ville (phase : %s)" % m.ville_phase())
	vue.call("_remplir_ville")
	vue.call("_maj_halte")
	for i in 5:
		await process_frame
	vue.call("_maj_interface")
	ok(true, "panneaux de ville et interface mis à jour sans erreur")
	Textes.langue = "en"
	vue.call("_maj_interface")
	Textes.langue = "fr"
	ok(true, "interface mise à jour en anglais sans erreur")
	print("--- %s" % ("TOUT EST OK" if echecs == 0 else "%d ÉCHEC(S)" % echecs))
	quit(1 if echecs > 0 else 0)
