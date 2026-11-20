# Corps à corps, armes de fortune, blindés de fortune (DEC-255).
# godot --headless --path game -s res://tests/test_corps_a_corps.gd
extends SceneTree

var echecs := 0


func ok(c: bool, t: String) -> void:
	print("OK  " if c else "ÉCHEC ", t)
	if not c:
		echecs += 1


func kit() -> CombatModele:
	Textes.langue = "fr"
	var m := CombatModele.new(11, {"bac_a_sable": true, "kit_groupe": true})
	m._prochain_x = INF
	m.stocks.gazole = 500.0
	m.stocks.ammo = 400.0
	m.ordre_marche("avancer")
	return m


func _init() -> void:
	var D := CombatModele.donnees()
	# 1) Nouvelles armes et pièces
	for w in ["revolver", "carabine", "arbalete", "bidon_incendiaire"]:
		ok(D.armes.has(w) and Assemblage.piece("arme_" + w) != null and Assemblage.piece("arme_" + w).arme == w, "arme %s : donnée et pièce" % w)
	ok(float(D.armes.mitrailleuse.portee) <= 40.0 and float(D.armes.pistolet.portee) <= 14.0, "portées réduites : plus de tir de loin")

	# 2) Les ennemis ont des armes variées ; le Berliet garde sa mitrailleuse
	var m := kit()
	var vus := {}
	for i in 60:
		var e := m.creer_vehicule("willys_mb" if i % 2 == 0 else "citroen_t23", "ennemi", 0.0)
		for a in e.armes:
			vus[a.id] = true
	ok(vus.size() >= 4, "variété d'armes chez les ennemis (%s)" % ", ".join(vus.keys()))
	ok(m.convoi[0].armes.size() == 1 and m.convoi[0].armes[0].id == "mitrailleuse", "le Berliet garde sa mitrailleuse")
	var allie := m.creer_vehicule("willys_mb", "joueur", 0.0)
	ok(allie.armes[0].id == "pistolet", "nos véhicules gardent le pistolet d'origine")

	# 3) Blindé de fortune
	var b := m.creer_vehicule("opel_blitz", "ennemi", 50.0)
	var pv0: float = b.pieces.chassis.max
	var bl0: int = int(b.profil.blindage)
	m.fortune(b)
	ok(bool(b.profil.fortune) and int(b.profil.blindage) > bl0 and b.pieces.chassis.max > pv0 and float(b.profil.lame_choc) > 1.0, "blindé de fortune : tôles, lame, plus de points de vie")
	ok("blindé de fortune" in b.nom, "blindé de fortune : renommé (%s)" % b.nom)
	var niv5: Array = CombatModele.donnees().rencontres.liste.filter(func(e): return e.has("blindes"))
	ok(niv5.size() >= 3 and niv5.all(func(e): return int(e.niveau_min) >= 5), "rencontres de niveau 5+ avec blindés de fortune")

	# 4) Frottement entre voies : un harceleur qui nous colle donne des coups de volant
	m = kit()
	m.kit_scenario("embuscade", "moyen", "gauche")
	var chocs := 0
	var lat := 0
	var etincelles := false
	for i in int(50.0 / CombatModele.DT):
		m.avancer()
		for e in m.vider_evenements():
			if e.t == "choc":
				chocs += 1
				if e.get("lat", false):
					lat += 1
	ok(chocs > 0, "poursuite : des chocs (%d, dont %d latéraux)" % [chocs, lat])

	# 5) Abordage : plusieurs hommes d'un coup, bagarre sur le toit (somme de trois attaques par l'arrière)
	var pic := 0
	var melee := 0
	var repousses := 0
	for sc in ["assaut", "raid", "embuscade"]:
		m = kit()
		m.kit_scenario(sc, "grand", "gauche")
		for i in int(60.0 / CombatModele.DT):
			m.avancer()
			pic = maxi(pic, m.abordeurs.size())
			for e in m.vider_evenements():
				if e.t == "melee":
					melee += 1
				elif e.t == "repousse":
					repousses += 1
	ok(pic >= 2, "abordage : jusqu'à %d pillards en même temps" % pic)
	ok(melee > 0, "abordage : bagarre sur le toit (%d coups)" % melee)
	print("INFO repoussés : ", repousses)

	print("%d ÉCHEC(S)" % echecs if echecs > 0 else "Tous les tests de corps à corps passent.")
	quit()
