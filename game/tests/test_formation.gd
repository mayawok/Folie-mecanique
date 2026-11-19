# Formation de combat (DEC-251) : détection du combat, escorteurs sur les flancs du camion principal, retour dans la ligne,
# flancs bouchés, bâtiments derrière ou devant la route, phares du Berliet.
# godot --headless --path game -s res://tests/test_formation.gd
extends SceneTree

var echecs := 0


func ok(c: bool, t: String) -> void:
	print("OK  " if c else "ÉCHEC ", t)
	if not c:
		echecs += 1


func marche(m: CombatModele, s: float) -> void:
	for i in int(s / CombatModele.DT):
		m.avancer()


# Convoi : Berliet principal en tête, deux motos et une jeep armées derrière
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
	for t in ["bmw_r75", "willys_mb", "bmw_r75"]:
		var v := m.creer_vehicule(t, "joueur", m.x_tete - 30.0)
		m.convoi.append(v)
	m._replacer(true)
	m.ordre_marche("avancer")
	return m


func ennemi_poursuite(m: CombatModele, dist := 50.0) -> CombatModele.Veh:
	var xq: float = m._queue().x
	var e := m.creer_vehicule("citroen_traction", "ennemi", xq - dist)
	m.preparer_poursuivant(e, {"abordeurs": 1, "types": ["lame"]})
	m._intention[e.uid] = false
	e.armes = []
	m.ennemis.append(e)
	return e


func _init() -> void:
	# 1) Phares d'origine du Berliet
	var m := convoi()
	var berliet = m.convoi[0]
	ok(int(berliet.profil.get("phares", 0)) >= 1, "Berliet : phares d'origine")

	# 2) Route calme : pas de combat, tout le monde reste en ligne
	marche(m, 5.0)
	ok(not m.en_combat, "route calme : pas de formation de combat")
	ok(m.convoi.all(func(v): return v.garde == 0 and absf(v.voie_f) < 0.01), "route calme : tout le convoi reste au milieu, en ligne")

	# 3) Un poursuivant arrive : combat, les escorteurs légers armés se postent sur les flancs du Berliet
	var evts := []
	var e := ennemi_poursuite(m)
	var debut := false
	for i in int(8.0 / CombatModele.DT):
		m.avancer()
		for ev in m.vider_evenements():
			if ev.t == "combat" and ev.etat == "debut":
				debut = true
	ok(m.en_combat and debut, "poursuivant à portée : le combat commence (événement émis)")
	var gardes: Array = m.convoi.filter(func(v): return v.garde != 0)
	ok(gardes.size() >= 2, "formation : au moins deux escorteurs postés (%d)" % gardes.size())
	ok(gardes.any(func(v): return v.garde == 1) and gardes.any(func(v): return v.garde == -1), "formation : un flanc de chaque côté")
	ok(berliet.garde == 0 and absf(berliet.voie_f) < 0.01, "formation : le Berliet reste au milieu")
	var alignes := true
	for v in gardes:
		var c_garde: float = v.x + v.longueur * 0.5
		alignes = alignes and absf(absf(v.voie_f) - 1.0) < 0.05 and c_garde > berliet.x - 1.0 and c_garde < berliet.x + berliet.longueur + 1.0
	ok(alignes, "formation : les escorteurs roulent sur les voies de côté, à hauteur du Berliet")

	# 4) Flancs bouchés : le poursuivant ne peut pas monter à côté, il reste derrière et personne n'aborde
	var abord := false
	var superpose := false
	for i in int(10.0 / CombatModele.DT):
		m.avancer()
		abord = abord or not m.abordeurs.is_empty()
		if e.actif() and absf(e.voie_f) < 0.5 and e.x + e.longueur > berliet.x + 0.5 and e.x < berliet.x + berliet.longueur - 0.5:
			superpose = true
	ok(not abord, "flancs gardés : aucun abordage")
	ok(not superpose, "flancs gardés : le poursuivant ne se superpose pas au Berliet sur la voie du milieu")
	ok(m.journal.any(func(l): return "ordre de combat" in String(l.txt)), "journal : annonce de la formation de combat")

	# 5) Fin du combat : l'ennemi disparaît, la ligne se reforme
	m.ennemis.clear()
	marche(m, 30.0)
	ok(not m.en_combat, "fin du combat : plus de menace, la formation se défait")
	ok(m.convoi.all(func(v): return v.garde == 0 and absf(v.voie_f) < 0.05), "fin du combat : tout le monde est revenu au milieu")
	var ordre_ok := true
	for i in range(1, m.convoi.size()):
		ordre_ok = ordre_ok and m.convoi[i].x < m.convoi[i - 1].x
	ok(ordre_ok, "fin du combat : l'ordre de la ligne est retrouvé")

	# 6) Pas de formation en ville
	m = convoi()
	m.ennemis.append(m.creer_vehicule("citroen_traction", "ennemi", m.x_tete + 20.0))
	ok(m._menace_proche(75.0), "menace proche détectée")

	# 7) Bâtiments : jamais sur la route, derrière (-1) ou devant (1)
	m = convoi()
	var devant := 0
	var derriere := 0
	for i in 60:
		var b2 := m.creer_batiment("ferme", 100.0 + i * 37.0)
		ok(b2.voie == -1 or b2.voie == 1, "bâtiment : voie -1 ou 1") if i < 2 else null
		if b2.voie == 1:
			devant += 1
		else:
			derriere += 1
	ok(derriere > devant and devant > 0, "bâtiments : surtout derrière, quelques-uns devant (%d devant, %d derrière)" % [devant, derriere])
	var bd := m.creer_batiment("ferme", 500.0)
	bd.voie = -1
	var f0: Vector2 = bd.fenetre(0)
	bd.voie = 1
	var f1: Vector2 = bd.fenetre(0)
	ok(f0.y > f1.y, "bâtiment : une fenêtre du fond est plus haute à l'écran que celle de devant")

	print("%d ÉCHEC(S)" % echecs if echecs > 0 else "Tous les tests de formation passent.")
	quit()
