# Équilibrage des ennemis (DEC-113) : plusieurs véhicules par rencontre, plus fragiles et moins meurtriers que le convoi.
# godot --headless --path game -s res://tests/test_equilibrage.gd
extends SceneTree

var echecs := 0


func ok(c: bool, t: String) -> void:
	print("OK  " if c else "ÉCHEC ", t)
	if not c:
		echecs += 1


func _init() -> void:
	var m := CombatModele.new(7)
	var D: Dictionary = m.donnees()
	var EQ: Dictionary = D.equilibrage
	ok(float(EQ.ennemi_degats_subis) > 1.0 and float(EQ.ennemi_degats_infliges) < 1.0 and float(EQ.ennemi_precision) < 1.0, "réglages : ennemis plus fragiles, moins forts, moins précis")

	# Groupes : toute rencontre de véhicules ennemis en compte au moins deux
	var seules := []
	for e in D.rencontres.liste:
		if e.has("vehicules") and e.vehicules.size() < 2 and e.vehicules[0] != "tiger_1":   # le Tiger I seul est le boss de fin
			seules.append(e.vehicules)
	ok(seules.is_empty(), "toute rencontre de véhicules compte au moins 2 véhicules, sauf le Tiger I (isolés : %s)" % [seules])

	# Mêmes dégâts reçus : l'ennemi perd plus de points de vie que le véhicule du joueur
	var w: Dictionary = D.armes[D.armes.keys()[0]]
	var perdus := {}
	for camp in ["joueur", "ennemi"]:
		var v := m.creer_vehicule("willys_mb", camp, 10.0)
		var avant: float = v.pieces.chassis.pv
		m._toucher_vehicule(null, w, v, "", "chassis")
		perdus[camp] = avant - v.pieces.chassis.pv
	ok(perdus.ennemi > perdus.joueur * 1.3, "même tir : l'ennemi perd %.1f PV, le joueur %.1f" % [perdus.ennemi, perdus.joueur])

	# Un tir ennemi frappe moins fort qu'un tir du joueur
	var bonus := {}
	for camp in ["joueur", "ennemi"]:
		var t := CombatModele.new(7)
		var att := t.creer_vehicule("m3_half_track", camp, 0.0)
		var cible := t.creer_vehicule("willys_mb", "ennemi" if camp == "joueur" else "joueur", 8.0)
		t.projectiles.clear()
		var arme: Dictionary = att.armes[0]
		t._tirer(att, arme, D.armes[arme.id], cible)
		bonus[camp] = float(t.projectiles[t.projectiles.size() - 1].bonus) if not t.projectiles.is_empty() else -1.0
	ok(bonus.joueur == 1.0 and absf(bonus.ennemi - float(EQ.ennemi_degats_infliges)) < 0.001, "projectile ennemi : dégâts ×%.2f (joueur ×%.2f)" % [bonus.ennemi, bonus.joueur])

	print("--- %s" % ("TOUT EST OK" if echecs == 0 else "%d ÉCHEC(S)" % echecs))
	quit(1 if echecs > 0 else 0)
