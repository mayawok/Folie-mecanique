# Deux carburants, essence et gazole, et capacité = réservoirs + citerne + bidons (DEC-094, 190, 206).
# godot --headless --path game -s res://tests/test_carburant.gd
extends SceneTree

var echecs := 0


func ok(c: bool, t: String) -> void:
	print("OK   " if c else "ÉCHEC ", t)
	if not c:
		echecs += 1


func marche(m: CombatModele, s: float) -> void:
	for i in int(s / CombatModele.DT):
		m.avancer()


func _init() -> void:
	Textes.langue = "fr"
	var m := CombatModele.new(4)
	var D := CombatModele.donnees()
	ok(m.stocks.gazole == float(D.stocks_depart.gazole) and m.stocks.essence == float(D.stocks_depart.essence), "départ : gazole et essence séparés")
	ok(m.carburant_de(m.convoi[0]) == "gazole", "le Berliet brûle du gazole")
	ok(m.carburant_de(m.creer_vehicule("willys_mb", "joueur", 0.0)) == "essence", "la Jeep brûle de l'essence")
	# Capacité : réservoir + bidons (+ citerne)
	var cap0: float = m.capacite_carburant("gazole")
	ok(is_equal_approx(cap0, float(D.carburants.bidons_l) + m.litres_reservoir(m.convoi[0])), "gazole : capacité = réservoir + bidons (%d L)" % int(cap0))
	m.berliet_regler("reservoir", 4)
	ok(m.capacite_carburant("gazole") > cap0 + 300.0, "réservoir 5 : capacité plus grande")
	m.berliet_regler("module", "citerne")
	ok(m.capacite_carburant("gazole") > 3000.0, "module citerne : +3000 L")
	m.berliet_regler("module", "plateau")
	m.berliet_regler("reservoir", 0)
	ok(is_equal_approx(m.capacite_carburant("essence"), float(D.carburants.bidons_l)), "sans véhicule à essence : seulement les bidons")
	# Surplus perdu
	m.stocks.gazole = 5000.0
	var perdu: Dictionary = m.borner_carburants()
	ok(perdu.has("gazole") and is_equal_approx(m.stocks.gazole, m.capacite_carburant("gazole")), "gazole en trop : plafonné à la capacité")
	# Consommation par carburant
	var m2 := CombatModele.new(4)
	m2.stocks.gazole = 60.0
	m2.stocks.essence = 20.0
	m2.ordre_marche("avancer")
	marche(m2, 30.0)
	ok(m2.stocks.gazole < 60.0 and is_equal_approx(m2.stocks.essence, 20.0), "le Berliet consomme du gazole, pas l'essence")
	# Panne sèche par carburant
	m2.stocks.gazole = 0.0
	ok(m2.carburant_manquant() == "gazole", "plus de gazole : panne sèche de gazole")
	marche(m2, 2.0)
	ok("gazole" in m2.blocage, "plus de gazole : le convoi est bloqué (%s)" % m2.blocage)
	# Butin d'un véhicule : son propre carburant
	var w = m2.creer_vehicule("willys_mb", "ennemi", 0.0)
	var b: Dictionary = m2._butin_vehicule(w, 1.0)
	ok(b.ressources.has("essence") and not b.ressources.has("gazole"), "butin d'une Jeep : de l'essence")
	# Sauvegarde et migration
	var m3 := CombatModele.new(4)
	m3.stocks.gazole = 55.0
	m3.stocks.essence = 12.0
	var d3: Dictionary = JSON.parse_string(JSON.stringify(m3.sauver()))
	var r3: CombatModele = CombatModele.depuis_sauvegarde(d3)
	ok(is_equal_approx(r3.stocks.gazole, 55.0) and is_equal_approx(r3.stocks.essence, 12.0), "sauvegarde : deux carburants conservés")
	var ancien: Dictionary = JSON.parse_string(JSON.stringify(m3.sauver()))
	ancien.stocks.erase("gazole")
	ancien.stocks.erase("essence")
	ancien.stocks["fuel_l"] = 42.0
	var r4: CombatModele = CombatModele.depuis_sauvegarde(ancien)
	ok(is_equal_approx(r4.stocks.gazole, 42.0) and r4.stocks.essence > 0.0, "ancienne sauvegarde (fuel_l) : migrée en gazole, essence de départ")
	print("--- %s" % ("TOUT EST OK" if echecs == 0 else "%d ÉCHEC(S)" % echecs))
	quit(1 if echecs > 0 else 0)
