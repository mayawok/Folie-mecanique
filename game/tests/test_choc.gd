# Chocs entre véhicules (DEC-215) : éperonner, emboutir par l'arrière, doubler, croiser, esquive des motos.
# godot --headless --path game -s res://tests/test_choc.gd
extends SceneTree

var echecs := 0


func ok(c: bool, t: String) -> void:
	print("OK  " if c else "ÉCHEC ", t)
	if not c:
		echecs += 1


func marche(m: CombatModele, s: float) -> void:
	for i in int(s / CombatModele.DT):
		m.avancer()


func jeu() -> CombatModele:
	Textes.langue = "fr"
	var m := CombatModele.new(5, {"bac_a_sable": true})
	var a := ConstructionLibre.voiture("moyen")
	a.nom = "Essai"
	m.construire_grille(0, a)
	m.ordre_marche("avancer")
	return m


func chocs(m: CombatModele) -> int:
	var n := 0
	for l in m.journal:
		if "éperonne" in String(l.txt) or "Choc frontal" in String(l.txt) or "emboutit" in String(l.txt):
			n += 1
	return n


func _init() -> void:
	# 1) Croiser : convoi d'en face pacifique, on évite -> aucun choc, il passe derrière nous
	var m := jeu()
	m.kit_apparaitre("face", {"types": ["citroen_t23"], "eperonne": false})
	var e = m.ennemis.back()
	marche(m, 25.0)
	ok(chocs(m) == 0, "croiser : pas de choc quand personne ne veut éperonner")
	ok(e.x < m._queue().x, "croiser : le convoi d'en face est passé derrière nous")

	# 2) Choc frontal : il nous fonce dessus
	m = jeu()
	m.kit_apparaitre("face", {"types": ["citroen_t23"], "eperonne": true})
	marche(m, 25.0)
	ok(chocs(m) >= 1, "choc frontal : l'ennemi d'en face nous percute")

	# 3) On éperonne un convoi devant nous (par l'arrière) ; en évitant, on le double
	m = jeu()
	m.ordre_conduite("eperonner")
	m.kit_apparaitre("convoi_devant", {"types": ["citroen_t23"], "vitesse": 1.0})
	e = m.ennemis.back()
	var pv0: float = e.pieces.roulement.pv
	marche(m, 30.0)
	ok(chocs(m) >= 1 and e.pieces.roulement.pv < pv0, "éperonner : on emboutit le convoi devant, ses roues prennent")
	m = jeu()
	m.kit_apparaitre("convoi_devant", {"types": ["citroen_t23"], "vitesse": 1.0})
	marche(m, 30.0)
	ok(chocs(m) == 0 and m.x_tete > m.ennemis.back().x + 2.0, "éviter : on double le convoi par la voie d'à côté")

	# 4) Poursuivant qui nous emboutit par l'arrière
	m = jeu()
	m.kit_apparaitre("poursuite", {"types": ["citroen_traction"], "abordeurs": 0})
	m._intention[m.ennemis.back().uid] = true
	marche(m, 30.0)
	var arr := false
	for l in m.journal:
		arr = arr or "emboutit" in String(l.txt)
	ok(arr, "rear-ended : un poursuivant nous emboutit par l'arrière")

	# 5) Les motos esquivent 2 fois sur 3
	m = jeu()
	var C: Dictionary = m.CH()
	var esq := 0
	var essais := 300
	var t = m._tete()
	for i in essais:
		var mo := m.creer_vehicule("moto_bmw", "ennemi", t.x + t.longueur + 0.5)
		mo.mode = "approche"
		m.journal.clear()
		var avant: int = 0
		m._choc(t, mo, 8.0, "avant", "avant", true)
		for j in range(avant, m.journal.size()):
			if "voie d'à côté" in String(m.journal[j].txt):
				esq += 1
	var f := float(esq) / essais
	ok(m.est_moto(m.creer_vehicule("moto_bmw", "ennemi", 0.0)), "la moto est reconnue comme moto")
	ok(absf(f - float(C.esquive_moto)) < 0.1, "motos : environ 2 esquives sur 3 (%.2f)" % f)

	# 6) La lame avant du Berliet frappe plus fort
	m = jeu()
	var a = m._tete()
	var cible1 := m.creer_vehicule("citroen_t23", "ennemi", 0.0)
	var cible2 := m.creer_vehicule("citroen_t23", "ennemi", 0.0)
	for c in [cible1, cible2]:
		c.pieces.moteur.pv = 1000.0
		c.pieces.moteur.max = 1000.0
	var p1: float = cible1.pieces.moteur.pv
	a.profil.lame_choc = 1.0
	m._choc(a, cible1, 2.0, "avant", "avant", true)
	m._cd_choc.clear()
	a.profil.lame_choc = 3.5
	m._choc(a, cible2, 2.0, "avant", "avant", true)
	ok(p1 - float(cible2.pieces.moteur.pv) > p1 - float(cible1.pieces.moteur.pv), "lame : le bélier fait plus de dégâts")

	# 7) Béliers et harceleurs (DEC-219) : le lourd charge, le léger contourne et revient par derrière
	var sur := 0
	var derriere := 0
	var essais_h := 4
	for i in essais_h:
		m = CombatModele.new(100 + i, {"bac_a_sable": true})
		var g := ConstructionLibre.voiture("moyen")
		g.nom = "Essai"
		m.construire_grille(0, g)
		m.ordre_marche("avancer")
		m.kit_apparaitre("ennemi", {"type": "moto_bmw"})
		var mo = m.ennemis.back()
		ok(m.role(mo) == "harceleur" or i > 0, "moto : rôle harceleur")
		for k in int(22.0 / CombatModele.DT):
			m.avancer()
			if mo.mode == "harcele":
				break
		if mo.mode == "harcele":
			derriere += 1
			ok(mo.x < m._queue().x or i > 0, "harceleur : il est passé derrière nous")
		elif not mo.actif():
			sur += 1
	ok(derriere + sur >= essais_h - 1, "motos : contournent ou se font faucher (%d + %d)" % [derriere, sur])
	m = jeu()
	m.kit_apparaitre("ennemi", {"type": "m3_half_track"})
	var lourd = m.ennemis.back()
	ok(m.role(lourd) == "belier", "plus lourd que nous : bélier")
	var x0: float = lourd.x
	marche(m, 10.0)
	ok(lourd.x < x0 - 20.0 or chocs(m) > 0, "le bélier ne s'arrête pas : il charge")

	print("Échecs : %d" % echecs)
	quit(1 if echecs > 0 else 0)
