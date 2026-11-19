# Contournement d'un obstacle et camion principal hors service (DEC-252).
# godot --headless --path game -s res://tests/test_contournement.gd
extends SceneTree

var echecs := 0


func ok(c: bool, t: String) -> void:
	print("OK  " if c else "ÉCHEC ", t)
	if not c:
		echecs += 1


func marche(m: CombatModele, s: float) -> void:
	for i in int(s / CombatModele.DT):
		m.avancer()


func convoi() -> CombatModele:
	Textes.langue = "fr"
	var m := CombatModele.new(5, {"bac_a_sable": true})
	m._prochain_x = INF
	m.stocks.gazole = 500.0
	m.stocks.ammo = 200.0
	m.convoi.clear()
	var b := m.creer_vehicule("berliet_gdr", "joueur", m.x_tete - 8.0)
	b.principal = true
	m.convoi.append(b)
	for t in ["willys_mb", "bmw_r75"]:
		m.convoi.append(m.creer_vehicule(t, "joueur", m.x_tete - 30.0))
	m._replacer(true)
	m.ordre_marche("avancer")
	return m


func barrage(m: CombatModele, d := 60.0) -> CombatModele.Veh:
	var e := m.creer_vehicule("citroen_traction", "ennemi", m.x_tete + d)
	e.mode = "barrage"
	e.armes = []
	m._intention[e.uid] = false
	m.ennemis.append(e)
	return e


func _init() -> void:
	# 1) Barrage : arrêt, recul, passage par la voie d'à côté, retour au milieu
	var m := convoi()
	var e := barrage(m)
	var x0: float = m.x_tete
	var recule := false
	var passe := false
	var min_x: float = m.x_tete
	for i in int(70.0 / CombatModele.DT):
		m.avancer()
		min_x = minf(min_x, m.x_tete)
		if m._contour == "recul":
			recule = true
		if m._contour == "passage":
			passe = true
	ok(recule, "barrage : le convoi recule")
	ok(passe, "barrage : le convoi passe sur la voie d'à côté")
	ok(m.x_tete > e.x + e.longueur, "barrage : la tête a dépassé l'obstacle (%.0f > %.0f)" % [m.x_tete, e.x + e.longueur])
	ok(m._contour == "" or m.x_tete > e.x + 50.0, "barrage : manœuvre terminée")
	ok(m.convoi.all(func(v): return v.actif()), "barrage : aucun véhicule perdu, aucun choc destructeur")
	marche(m, 15.0)
	ok(m.convoi.all(func(v): return absf(v.voie_f) < 0.05), "barrage : tout le convoi est revenu au milieu")

	# 2) Les deux voies sont prises par des ennemis : pas de contournement
	m = convoi()
	e = barrage(m)
	for l in [-1, 1]:
		var g := m.creer_vehicule("citroen_traction", "ennemi", e.x)
		g.mode = "poursuite"
		g.voie = l
		g.voie_f = float(l)
		g.armes = []
		m._intention[g.uid] = false
		m.ennemis.append(g)
	m._voies(0.0)
	ok(not m._voie_degagee(1, e) and not m._voie_degagee(-1, e), "voies prises : aucune voie dégagée")

	# 3) Une épave ennemie sur la route arrête le convoi, qui la contourne
	m = convoi()
	var ep := m.creer_vehicule("citroen_traction", "ennemi", m.x_tete + 40.0)
	ep.statut = "epave"
	m.epaves.append(ep)
	marche(m, 50.0)
	ok(m.x_tete > ep.x + ep.longueur, "épave : contournée (%.0f > %.0f)" % [m.x_tete, ep.x + ep.longueur])

	# 4) Camion principal hors service : il reste en tête, le convoi s'arrête ; réparé, il repart
	m = convoi()
	var b: CombatModele.Veh = m.convoi[0]
	marche(m, 3.0)
	b.pieces.chassis.pv = 0.0
	m._detruire(b)
	ok(m.convoi.has(b) and not m.epaves.has(b), "Berliet : reste dans le convoi")
	ok(not b.actif(), "Berliet : hors service")
	var x1: float = m.x_tete
	marche(m, 5.0)
	ok(absf(m.x_tete - x1) < 1.0, "Berliet HS : le convoi ne repart pas")
	ok(m.blocage == Textes.t("voie.006"), "Berliet HS : message de blocage")
	# remise en service
	for id in b.pieces:
		b.pieces[id].pv = b.pieces[id].max
	m.reserve_survivants = 1
	marche(m, 1.0)
	ok(b.actif(), "Berliet réparé : remis en service")
	var x2: float = m.x_tete
	marche(m, 6.0)
	ok(m.x_tete > x2 + 2.0, "Berliet réparé : le convoi repart")

	# 5) Un autre allié détruit est laissé sur place
	m = convoi()
	var w: CombatModele.Veh = m.convoi[1]
	w.pieces.chassis.pv = 0.0
	m._detruire(w)
	ok(not m.convoi.has(w) and m.epaves.has(w), "allié détruit : abandonné sur la route")

	print("%d ÉCHEC(S)" % echecs if echecs > 0 else "Tous les tests de contournement passent.")
	quit()
