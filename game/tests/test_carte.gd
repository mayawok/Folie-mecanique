# Carte du monde de conception (DEC-154) : données cohérentes, routes reliées, itinéraires, voyage depuis le Kit.
# godot --headless --path game -s res://tests/test_carte.gd
extends SceneTree

var echecs := 0


func ok(c: bool, t: String) -> void:
	print("OK  " if c else "ÉCHEC ", t)
	if not c:
		echecs += 1


func _init() -> void:
	var D := CarteMonde.donnees()
	var villes := CarteMonde.villes()
	ok(villes.size() == 13, "13 villes-étapes, une par secteur (DEC-101)")
	var ids := {}
	var bons := true
	for l in CarteMonde.lieux():
		if ids.has(l.id):
			bons = false
		ids[l.id] = true
		var p := CarteMonde.pos(String(l.id))
		if p.x < 0.0 or p.x > 1.0 or p.y < 0.0 or p.y > 1.0 or not D.types.has(l.type):
			bons = false
			print("   lieu fautif : ", l.id)
		if String(l.get("zone", "")) not in CombatModele.KIT_ZONES:
			bons = false
			print("   zone inconnue : ", l.id)
		if String(l.get("faction", "")) != "" and not D.factions.has(l.faction):
			bons = false
		if String(l.get("batiment", "")) != "" and not CombatModele.donnees().batiments.has(l.batiment):
			bons = false
			print("   bâtiment inconnu : ", l.id)
	ok(bons, "lieux : ids uniques, positions dans l'image, types, zones, factions et bâtiments connus")
	var rbons := true
	for r in CarteMonde.routes():
		if String(CarteMonde.lieu(r.a).get("type", "")) != "ville" or String(CarteMonde.lieu(r.b).get("type", "")) != "ville" or not D.routes_types.has(r.type):
			rbons = false
			print("   route fautive : ", r.a, " - ", r.b)
	ok(rbons, "routes : entre deux villes, type connu")
	var relie := true
	for v in villes:
		if CarteMonde.chemin("kerbrume", String(v.id)).is_empty():
			relie = false
			print("   injoignable : ", v.id)
	ok(relie, "toutes les villes sont joignables depuis Kerbrume")
	var c := CarteMonde.chemin("kerbrume", "rhin")
	ok(c.size() >= 3 and c[0] == "kerbrume" and c[-1] == "rhin", "itinéraire Kerbrume → Rhin-Gris : %s" % [c])
	ok(CarteMonde.chemin("kerbrume", "inconnu").is_empty(), "itinéraire vers un lieu inconnu : vide")
	ok(CarteMonde.lieu_proche(CarteMonde.pos("capitale"), 0.03) == "capitale", "toucher une ville la choisit")
	ok(CarteKit.texte_lieu("capitale", c).contains("Vieille-Capitale"), "fiche d'une ville")
	ok(CarteKit.texte_lieu("p_brie").contains("Pétrole"), "fiche d'un puits de pétrole")
	ok(ResourceLoader.exists(String(D.image)), "image de la carte présente")

	# Voyage depuis le Kit
	var n := CombatModele.new(5)
	ok(not n.kit_aller("capitale"), "hors Mode créatif : pas de voyage")
	var m := CombatModele.new(5, {"bac_a_sable": true})
	ok(not m.kit_aller("nulle-part"), "lieu inconnu : refusé")
	ok(m.kit_aller("capitale"), "aller à Vieille-Capitale")
	ok(m.ville_active() and String(m.ville.nom) == "Vieille-Capitale", "la ville de la carte est posée devant, avec son nom")
	ok(String(m.ville.maire) == "Vasseur" and m.kit_zone == "cailloux" and m.kit_lieu == "capitale", "maire, zone de décor et position suivent la carte")
	ok(m.kit_aller("pertuis") and String(m.ville.nom) == "Les Pertuis" and m.kit_zone == "terre", "aller ailleurs remplace la ville")
	var nb := m.batiments.size()
	ok(m.kit_aller("d_normandie") and not m.ville_active() and m.batiments.size() == nb + 1, "un dépôt fait apparaître son bunker, sans ville")
	ok(m.kit_aller("p_brie") and m.kit_lieu == "p_brie", "un puits sans bâtiment : position seulement")
	# Régions (10/11)
	ok(CarteMonde.regions().size() >= 12, "12 régions avec un thème")
	var sans := CarteMonde.villes().filter(func(v): return not v.has("region"))
	ok(sans.is_empty(), "chaque ville-étape a sa région")
	ok(String(CarteMonde.region_a(CarteMonde.pos("kerbrume")).get("id", "")) == "armorique", "Kerbrume est en Armorique")
	print("Échecs : ", echecs)
	quit(1 if echecs > 0 else 0)
