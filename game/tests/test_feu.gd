# Lot F (DEC-219..222) : Molotov, lance explosive, incendies, explosions, nouveaux véhicules, couleurs de faction.
# godot --headless --path game -s res://tests/test_feu.gd
extends SceneTree

var echecs := 0

const NOUVEAUX := ["moto_zundapp", "moto_harley", "moto_gnome", "peugeot_202", "juvaquatre", "kubelwagen", "citroen_h", "opel_blitz", "gmc_cckw", "laffly_s15"]


func ok(c: bool, t: String) -> void:
	print("OK  " if c else "ÉCHEC ", t)
	if not c:
		echecs += 1


func jeu(graine := 5) -> CombatModele:
	Textes.langue = "fr"
	var m := CombatModele.new(graine, {"bac_a_sable": true})
	var a := ConstructionLibre.voiture("moyen")
	a.nom = "Essai"
	m.construire_grille(0, a)
	return m


func tir(m: CombatModele, w_id: String, cible: CombatModele.Veh) -> void:
	var w: Dictionary = m.donnees().armes[w_id]
	m.projectiles.append({"att": 0, "cible": cible.uid, "w": w, "classe": w.classe, "a": Vector2(0, 1), "b": Vector2(cible.x + 1.0, 1.0),
		"t": 0.0, "T": 0.1, "touche": true, "zone": "", "ricoche": false, "visee": "libre", "bonus": 1.0})


func _init() -> void:
	var m := jeu()
	# 1) Les dix nouveaux véhicules existent, se construisent et se dessinent
	var formes: Dictionary = VehiculeDessin.donnees().vehicules
	for t in NOUVEAUX:
		var e := m.creer_vehicule(t, "ennemi", 50.0)
		ok(formes.has(t) and e.longueur > 1.0 and e.pieces.has("chassis") and e.profil.poids_kg > 100.0, "véhicule %s : %s (%.0f kg)" % [t, e.nom, e.profil.poids_kg])
	ok(m.est_moto(m.creer_vehicule("moto_harley", "ennemi", 0.0)) and not m.est_moto(m.creer_vehicule("peugeot_202", "ennemi", 0.0)), "motos reconnues, voitures non")
	var lourd := m.creer_vehicule("gmc_cckw", "ennemi", 0.0)
	var leger := m.creer_vehicule("moto_gnome", "ennemi", 0.0)
	ok(lourd.profil.poids_kg > leger.profil.poids_kg * 10.0, "le camion pèse bien plus que la moto")

	# 2) Les motos pillardes portent un cocktail Molotov ou une lance explosive
	var mo := m.creer_vehicule("moto_zundapp", "ennemi", 0.0)
	var porte := false
	for a in mo.armes:
		if a.id == "molotov":
			porte = true
	ok(porte and mo.pieces.has("a0"), "la moto ennemie porte des Molotov")
	var ka := m.creer_vehicule("kubelwagen", "ennemi", 0.0)
	ok(ka.armes.any(func(a): return a.id == "lance_explosive"), "le Kübelwagen porte des lances explosives")
	var pj := m.creer_vehicule("moto_bmw", "joueur", 0.0)
	ok(not pj.armes.any(func(a): return a.id == "molotov"), "notre moto n'a pas de Molotov d'office")

	# 3) Un Molotov met le feu : le véhicule perd des PV, puis le feu s'éteint
	m = jeu()
	var cible: CombatModele.Veh = m._tete()
	var pv0: float = cible.pieces.chassis.pv + cible.pieces.moteur.pv
	m.vider_evenements()
	tir(m, "molotov", cible)
	m._projectiles(0.2)
	ok(cible.feu > 3.0, "le Molotov met le feu (%.1f s)" % cible.feu)
	var evts := m.vider_evenements()
	ok(evts.any(func(e): return e.t == "explosion" and e.feu), "événement d'explosion avec flammes")
	for i in int(7.0 / CombatModele.DT):
		m._feux(CombatModele.DT)
	ok(cible.feu == 0.0, "le feu s'éteint")
	ok(cible.pieces.chassis.pv + cible.pieces.moteur.pv < pv0, "le feu a coûté des PV")

	# 4) Lance explosive : explosion
	m.vider_evenements()
	tir(m, "lance_explosive", cible)
	m._projectiles(0.2)
	ok(m.vider_evenements().any(func(e): return e.t == "explosion" and float(e.taille) >= 2.0), "la lance explosive explose")

	# 5) Une épave brûle, et peut exploser sur ses voisins
	m = jeu()
	var v1: CombatModele.Veh = m._tete()
	var e1 := m.creer_vehicule("peugeot_202", "ennemi", v1.x + v1.longueur + 2.0)
	m.ennemis.append(e1)
	m.donnees().feu.explosion_carburant = 1.0
	var pv_voisin: float = v1.pieces.chassis.pv
	m._detruire(e1)
	ok(e1.feu > 5.0, "l'épave brûle")
	ok(v1.pieces.chassis.pv < pv_voisin, "l'explosion blesse le voisin (%.1f -> %.1f)" % [pv_voisin, v1.pieces.chassis.pv])

	# 6) Couleurs de faction : un ennemi de la région porte la bannière de la faction ; amis -> pillards gris
	m = jeu()
	var fac: String = m.rep_faction_ici()
	m.rep_changer(fac, -80.0, "essai")
	ok(m.rep_faction_ennemie() == fac, "faction hostile : ses véhicules portent sa couleur")
	m.rep_changer(fac, 200.0, "essai")
	ok(m.rep_faction_ennemie() == "bandits", "faction amie : les attaquants sont des pillards sans bannière")
	var vd := VehiculeDessin.new()
	vd.configurer("peugeot_202")
	vd.ennemi = true
	vd.fixer_faction(Color("#B03A2E"))
	ok(vd.faction_couleur.a > 0.0 and vd._teinte != Color(VehiculeDessin.donnees().teintes.pillards), "la caisse prend la teinte de la faction")

	# 8) Chausse-trappes (DEC-228) : posées derrière nous, elles crèvent les pneus d'un poursuivant et le font décrocher
	var m3 := jeu(9)
	var ch: CombatModele.Veh = m3.convoi[0]
	ok(m3.donnees().armes.has("chausse_trappes") and m3.donnees().equilibrage.joueur_jet_degats > 1.0, "chausse-trappes et bonus de jet présents")
	m3.pieges.append({"x": ch.x - 10.0, "charges": 2, "t": 30.0, "touches": []})
	var pour := m3.creer_vehicule("peugeot_202", "ennemi", ch.x - 20.0)
	pour.mode = "harcele"
	m3.ennemis.append(pour)
	var v0 := pour.vitesse()
	for i in 600:
		pour.x += 0.1
		m3._pieges(0.016)
	ok(pour.crevaison > 0.0 or m3.pieges.is_empty(), "le poursuivant qui roule dessus a les pneus crevés")
	ok(pour.vitesse() < v0 or pour.crevaison <= 0.0, "pneus crevés : il ralentit")
	m3._pieges(20.0)
	ok(pour.crevaison == 0.0, "la crevaison finit par passer")

	print("Échecs : %d" % echecs)
	quit(1 if echecs > 0 else 0)
