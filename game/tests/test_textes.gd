# Textes fr/en (DEC-193) : mêmes clés dans les deux langues, remplacement des valeurs, repli sur le français.
# godot --headless --path game -s res://tests/test_textes.gd
extends SceneTree

var echecs := 0


func ok(c: bool, t: String) -> void:
	print("OK   " if c else "ÉCHEC ", t)
	if not c:
		echecs += 1


func _init() -> void:
	var D := Textes.donnees()
	var fr: Array = D.fr.keys()
	var en: Array = D.en.keys()
	fr.sort()
	en.sort()
	ok(fr == en, "fr et en ont exactement les mêmes clés (%d)" % fr.size())
	# Mêmes valeurs à insérer dans les deux langues (%s, %d…), sinon le jeu plante ou affiche un trou
	var mal: Array = []
	var re := RegEx.new()
	re.compile("%[sd]")
	for k in D.fr:
		if re.search_all(String(D.fr[k])).size() != re.search_all(String(D.en[k])).size():
			mal.append(k)
	ok(mal.is_empty(), "mêmes valeurs à insérer en fr et en anglais %s" % str(mal))
	Textes.langue = "fr"
	ok(Textes.t("res.gazole") == "Gazole", "français : Gazole")
	Textes.langue = "en"
	ok(Textes.t("res.gazole") == "Diesel", "anglais : Diesel")
	ok(Textes.t("carb.perdu", [12, "diesel"]) == "Tanks full: 12 L of diesel lost.", "valeurs insérées")
	ok(Textes.t("cle.inconnue") == "cle.inconnue", "clé inconnue : la clé elle-même")
	Textes.langue = "de"
	ok(Textes.t("res.eau") == "Eau", "langue inconnue : repli sur le français")
	Textes.langue = "fr"
	var dirs := ["res://scripts/combat/vue_interface.gd"]
	var f := FileAccess.open(dirs[0], FileAccess.READ)
	ok(f.get_as_text().contains('Textes.t("res.gazole")'), "le HUD lit ses libellés dans les textes")
	print("--- %s" % ("TOUT EST OK" if echecs == 0 else "%d ÉCHEC(S)" % echecs))
	quit(1 if echecs > 0 else 0)
