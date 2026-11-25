# Décor par région (DEV-008, DEC-264) : chaque région de la carte a son décor, tout ce qu'il demande sait se dessiner,
# la région suit le voyage et se choisit dans le Kit.
# godot --headless --path game -s res://tests/test_regions.gd
extends SceneTree

var echecs := 0


func ok(c: bool, t: String) -> void:
	print("OK  " if c else "ÉCHEC ", t)
	if not c:
		echecs += 1


func _init() -> void:
	Textes.langue = "fr"
	var manquantes := []
	var inconnus := []
	for R in CarteMonde.regions():
		var D := DecorRegion.region(String(R.id))
		if D.is_empty():
			manquantes.append(R.id)
			continue
		for l in D.get("lointain", []):
			if not String(l) in DecorRegion.LOINTAINS:
				inconnus.append("%s : lointain %s" % [R.id, l])
		if not String(D.get("ligne", "")) in DecorRegion.LIGNES:
			inconnus.append("%s : ligne %s" % [R.id, D.ligne])
		if not String(D.get("particules", "")) in DecorRegion.PARTICULES:
			inconnus.append("%s : particules %s" % [R.id, D.particules])
		var seuil := 0.0
		for o in D.get("proche", []):
			if not (String(o[0]) in DecorRegion.OBJETS or String(o[0]) in DecorRegion.OBJETS_TERRAIN):
				inconnus.append("%s : objet %s" % [R.id, o[0]])
			if float(o[1]) <= seuil:
				inconnus.append("%s : seuil non croissant (%s)" % [R.id, o[0]])
			seuil = float(o[1])
	ok(manquantes.is_empty(), "les 12 régions de la carte ont un décor %s" % str(manquantes))
	ok(inconnus.is_empty(), "tout ce que demandent les décors sait se dessiner %s" % str(inconnus))
	# Le décor suit le voyage
	var m := CombatModele.new(3, {})
	ok(Terrain.region == String(m.monde.secteurs[m.monde.secteur].region) and Terrain.region != "", "départ : décor de la région du secteur (%s)" % Terrain.region)
	# Kit : choisir le décor d'une région, puis revenir au type de sol seul
	var k := CombatModele.new(3, {"bac_a_sable": true})
	ok(k.kit_regler_decor_region("alpes") and Terrain.region == "alpes" and Terrain.zone == "neige", "Kit : décor des Alpes (sol neige)")
	ok(k.kit_regler_zone("sable") and Terrain.region == "", "Kit : choisir un type de sol efface la région")
	ok(not k.kit_regler_decor_region("atlantide"), "Kit : région inconnue refusée")
	# Couleurs : la région change la palette du sol, sinon celle du type de zone
	var t := Terrain.new()
	Terrain.zone = "cailloux"
	Terrain.region = "pays_noir"
	ok(String(t._palette().sol) == String(DecorRegion.region("pays_noir").sol), "palette du sol du Pays Noir")
	Terrain.region = ""
	ok(String(t._palette().sol) == String(Terrain.PALETTES.cailloux.sol), "sans région : palette du type de zone")
	t.free()
	print("Échecs : ", echecs)
	quit(1 if echecs > 0 else 0)
