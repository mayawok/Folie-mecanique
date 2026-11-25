# Jeu en anglais (DEC-263) : données traduites au chargement, partie qui tourne sans erreur, textes sans trou.
# godot --headless --path game -s res://tests/test_langue.gd
extends SceneTree

var echecs := 0


func ok(c: bool, t: String) -> void:
	print("OK  " if c else "ÉCHEC ", t)
	if not c:
		echecs += 1


func _init() -> void:
	Textes.langue = "en"   # avant tout chargement de données
	ok(Textes.donnee("Châssis Willys MB") == "Willys MB chassis", "préfixe : « Châssis Willys MB » → %s" % Textes.donnee("Châssis Willys MB"))
	ok(Textes.donnee("Lance-flammes") == "Flamethrower", "texte exact traduit")
	ok(Textes.donnee("Dol") == "Dol", "nom propre inconnu : inchangé")
	ok(String(Assemblage.piece("essieu_leger").get("nom", "")) == "Light axle", "pièces : noms en anglais (%s)" % Assemblage.piece("essieu_leger").get("nom", ""))
	ok(String(VehiculeDessin.donnees().vehicules.willys_mb.get("fiche", "")).begins_with("4×4"), "fiches des véhicules en anglais")
	ok(String(CombatModele.MD().types.values()[0].get("nom", "")) != "", "missions chargées")
	var reste := []
	for k in Textes.donnees().en:
		var v := String(Textes.donnees().en[k])
		if v != "" and v == String(Textes.donnees().fr[k]) and v.length() > 12 and v.contains(" "):
			reste.append(k)
	ok(reste.size() < 25, "peu de textes anglais laissés en français (%d) %s" % [reste.size(), str(reste.slice(0, 8))])
	# Une partie en anglais : Kit, groupes, combat, ville, sans erreur de script
	var m := CombatModele.new(4, {"bac_a_sable": true, "kit_groupe": true})
	m.ordre_marche("avancer")
	m.kit_scenario("raid", "moyen")
	for i in 1500:
		m.avancer()
	ok(m.temps > 100.0 or m.fini, "partie en anglais : la simulation tourne (%.0f s, fin : %s)" % [m.temps, str(m.fini)])
	var fr_vu := false
	for l in m.journal:
		if String(l.txt).contains(" le ") or String(l.txt).contains(" les ") or String(l.txt).contains(" du "):
			fr_vu = true
			print("  journal encore en français : ", l.txt)
	ok(not fr_vu, "journal sans phrase française")
	print("Échecs : ", echecs)
	quit(1 if echecs > 0 else 0)
