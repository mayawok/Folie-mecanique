# Physique des pneus et des suspensions (DEC-230) : adhérence par surface, enlisement et dégagement, chocs, Berliet, déterminisme.
# godot --headless --path game -s res://tests/test_physique.gd
extends SceneTree

var echecs := 0


func ok(c: bool, t: String) -> void:
	print("OK   " if c else "ÉCHEC ", t)
	if not c:
		echecs += 1


func profil(pneu: String, charge: float, deb := 0.2, vit := 8.0) -> Dictionary:
	return {"vitesse": vit, "physique": {"pneu": pneu, "debattement": deb, "charge_essieu": charge}}


func _init() -> void:
	Textes.langue = "fr"
	PhysiqueRoulage.surface_forcee = ""
	# Un profil sans données de roulage reste neutre
	ok(float(PhysiqueRoulage.evaluer({"vitesse": 8.0}, "sable").vitesse) == 1.0, "sans bloc physique : neutre")
	# La terre est la surface de référence : un véhicule normal n'y perd rien
	var normal := PhysiqueRoulage.evaluer(profil("roue_moyenne", 1500.0), "terre")
	ok(is_equal_approx(float(normal.vitesse), 1.0) and not bool(normal.enlise), "terre : véhicule normal à pleine vitesse")
	# Sable : petite roue chargée = enlisée ; roue de tracteur = passe, et plus vite
	var petite := PhysiqueRoulage.evaluer(profil("roue_petite", 2000.0), "sable")
	var tracteur := PhysiqueRoulage.evaluer(profil("roue_tracteur", 2000.0), "sable")
	ok(bool(petite.enlise), "sable : petite roue chargée, enlisée (adhérence %.2f)" % float(petite.adherence))
	ok(not bool(tracteur.enlise) and float(tracteur.vitesse) > float(petite.vitesse), "sable : roue de tracteur passe et va plus vite")
	# Chaque pneu a sa surface : crampons dans la boue, route sur route
	var cr_boue := PhysiqueRoulage.evaluer(profil("berliet_crampons", 4000.0), "boue")
	var ro_boue := PhysiqueRoulage.evaluer(profil("berliet_route", 4000.0), "boue")
	var cr_route := PhysiqueRoulage.evaluer(profil("berliet_crampons", 4000.0), "route")
	var ro_route := PhysiqueRoulage.evaluer(profil("berliet_route", 4000.0), "route")
	ok(float(cr_boue.adherence) > float(ro_boue.adherence), "boue : crampons mieux que pneus route")
	ok(float(ro_route.adherence) > float(cr_route.adherence), "route : pneus route mieux que crampons")
	var ch_neige := PhysiqueRoulage.evaluer(profil("berliet_chaines", 4000.0), "neige")
	var ro_neige := PhysiqueRoulage.evaluer(profil("berliet_route", 4000.0), "neige")
	ok(float(ch_neige.adherence) > float(ro_neige.adherence), "neige : chaînes mieux que pneus route")
	# Suspension : sur sol cassé et vite, une suspension courte secoue plus qu'une longue
	var courte := PhysiqueRoulage.evaluer(profil("roue_moyenne", 1500.0, 0.2, 12.0), "cailloux")
	var longue := PhysiqueRoulage.evaluer(profil("roue_moyenne", 1500.0, 0.85, 12.0), "cailloux")
	ok(float(courte.chocs) > float(longue.chocs), "cailloux : suspension courte, plus de chocs")
	ok(float(courte.vitesse) < float(longue.vitesse) and float(courte.precision) < float(longue.precision), "cailloux : suspension courte, plus lente et moins précise")
	ok(float(PhysiqueRoulage.evaluer(profil("roue_moyenne", 1500.0, 0.2, 12.0), "route").chocs) < float(courte.chocs), "route : moins de chocs que les cailloux")
	# Consommation : le sable coûte plus cher que la route
	ok(float(PhysiqueRoulage.evaluer(profil("roue_moyenne", 1500.0), "sable").conso) > float(normal.conso), "sable : consommation plus forte")
	# Le Berliet porte ses pneus : la configuration compte sur le sable
	var m := CombatModele.new(4)
	var b = m.convoi[0]
	ok(b.profil.has("physique"), "Berliet : bloc physique présent")
	m.berliet_regler("pneu_ar", "route")
	m.berliet_regler("pneu_av", "route")
	PhysiqueRoulage.surface_forcee = "sable"
	var f_route: float = b.facteur_vitesse()
	m.berliet_regler("pneu_ar", "crampons")
	m.berliet_regler("pneu_av", "crampons")
	var f_cramp: float = b.facteur_vitesse()
	ok(f_cramp > f_route, "Berliet sur sable : crampons plus rapides que pneus route (%.2f > %.2f)" % [f_cramp, f_route])
	# Enlisement puis dégagement : jamais définitif, et lent après dégagement
	b.profil["physique"] = {"pneu": "roue_petite", "debattement": 0.2, "charge_essieu": 3000.0}
	var f_libre: float = b.facteur_vitesse() / PhysiqueRoulage.facteur_vitesse(b.profil)
	var vu_enlise := false
	var vu_degage := false
	for i in 80:
		m._physique(0.5, [b], 5.0)
		vu_enlise = vu_enlise or b.enlise
		vu_degage = vu_degage or b.degage > 0.0
	ok(vu_enlise and vu_degage, "enlisement puis dégagement par l'équipage")
	b.enlise = true
	b.degage = 5.0
	var f_deg: float = b.facteur_vitesse()
	b.degage = 0.0
	var f_bloque: float = b.facteur_vitesse()
	ok(f_deg > f_bloque and f_bloque > 0.0, "dégagé : plus rapide qu'enlisé, et jamais à l'arrêt complet")
	ok(f_libre > 0.0, "facteur de base lisible")
	# Déterminisme : mêmes graines, mêmes crevaisons
	var cre := []
	for essai in 2:
		var m2 := CombatModele.new(9)
		var v2 = m2.convoi[0]
		PhysiqueRoulage.surface_forcee = "cailloux"
		v2.profil["physique"] = {"pneu": "roue_course", "debattement": 0.2, "charge_essieu": 800.0}
		var n := 0
		for i in 8000:
			var avant: float = v2.crevaison
			m2._physique(0.5, [v2], 12.0)
			if v2.crevaison > avant:
				n += 1
		cre.append(n)
	ok(cre[0] == cre[1], "crevaisons déterministes (%d et %d)" % [cre[0], cre[1]])
	ok(cre[0] > 0, "des crevaisons surviennent sur les cailloux avec des pneus de course (%d)" % cre[0])
	PhysiqueRoulage.surface_forcee = ""
	print("--- %s" % ("TOUT EST OK" if echecs == 0 else "%d ÉCHEC(S)" % echecs))
	quit(1 if echecs > 0 else 0)
