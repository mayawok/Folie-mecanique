extends SceneTree
# Camp de réparation branché sur le modèle de combat (DEV-018) : essieu cassé -> camp -> attaques -> réparation.
#   godot --headless --path game -s res://tests/test_camp.gd
var echecs := 0


func ok(c: bool, t: String) -> void:
	print("OK  " if c else "ÉCHEC ", t)
	if not c:
		echecs += 1


func _avancer(m: CombatModele, s: float) -> void:
	for i in int(s / CombatModele.DT):
		m.avancer()


func _neuf(graine: int) -> Array:
	var m := CombatModele.new(graine)
	m._prochain_x = INF
	m.stocks.fuel_l = 300.0
	m.monde._assaut_t = 1.0e9
	var v = m.convoi[0]
	return [m, v]


func _init() -> void:
	var t := _neuf(5)
	var m: CombatModele = t[0]
	var v = t[1]
	v.pieces.roulement.pv = 0.0   # essieu cassé en combat
	ok(not v.mobile(), "essieu cassé : le véhicule est immobilisé")
	var opts := m.camp_options(v.uid)
	var o_ess: Dictionary = opts.filter(func(o): return o.op == "changer_essieu")[0]
	ok(not bool(o_ess.ok) and String(o_ess.raison) != "", "sans pièce de rechange : option grisée (%s)" % o_ess.raison)
	ok(not m.camp_etablir(v.uid, "changer_essieu", o_ess.params), "pas de camp sans pièce")
	m.pieces_stock.append({"piece": "essieu_lourd", "etat": 0.9})
	m.pieces_stock.append({"piece": "roue_grande", "etat": 0.8})
	o_ess = m.camp_options(v.uid).filter(func(o): return o.op == "changer_essieu")[0]
	ok(bool(o_ess.ok), "avec pièces en réserve : option possible (durée %d s)" % int(o_ess.duree_s))
	ok(m.camp_etablir(v.uid, "changer_essieu", o_ess.params), "camp établi")
	ok(m.camp_actif() and m.ordres.marche == "halte", "le convoi est à l'arrêt")
	ok(not m.camp_etablir(v.uid, "changer_essieu", o_ess.params), "un seul camp à la fois")
	var duree := float(m.camp_rep.camp.duree_s)
	var attaques := 0
	var t_max := duree * 3.0
	var s := 0.0
	var fini := false
	while s < t_max:
		m.avancer()
		s += CombatModele.DT
		attaques = maxi(attaques, m.ennemis.size())
		for e in m.ennemis:   # les défenseurs repoussent les attaques : on neutralise les ennemis pour tester le temps de camp
			e.statut = "detruit"
		m.ennemis = m.ennemis.filter(func(e): return e.actif())
		if not m.camp_actif():
			fini = true
			break
	ok(fini, "camp terminé en %d s (réparation %d s)" % [int(s), int(duree)])
	ok(s >= duree, "le camp dure au moins la durée de réparation")
	ok(v.mobile() and v.ratio("roulement") > 0.5, "essieu changé : le véhicule roule de nouveau (%.2f)" % v.ratio("roulement"))
	ok(m.pieces_stock.any(func(p): return p.piece == "roue_grande"), "roues de la réserve conservées")
	ok(not m.pieces_stock.any(func(p): return p.piece == "essieu_lourd"), "essieu de rechange consommé")
	# Attaques : un camp long en reçoit, et elles retardent les travaux
	var t2 := _neuf(9)
	var m2: CombatModele = t2[0]
	var v2 = t2[1]
	v2.pieces.moteur.pv = 0.0
	m2.pieces_stock.append({"piece": "moteur_4cyl_moyen", "etat": 0.8})
	var o_mot: Dictionary = m2.camp_options(v2.uid).filter(func(o): return o.op == "changer_moteur")[0]
	ok(bool(o_mot.ok), "moteur de rechange : option possible (%s)" % o_mot.raison)
	ok(m2.camp_etablir(v2.uid, "changer_moteur", o_mot.params), "camp moteur établi")
	var vu := false
	var s2 := 0.0
	var d2 := float(m2.camp_rep.camp.duree_s)
	while s2 < d2 * 3.0 and m2.camp_actif():
		m2.avancer()
		s2 += CombatModele.DT
		if not m2.ennemis.is_empty():
			vu = true
			for e in m2.ennemis:
				e.statut = "detruit"
			m2.ennemis = m2.ennemis.filter(func(e): return e.actif())
	ok(vu, "une attaque est tombée sur le camp")
	ok(s2 > d2, "les attaques ont allongé le camp (%d s pour %d s)" % [int(s2), int(d2)])
	ok(not m2.camp_actif() and v2.mobile(), "moteur remplacé après les attaques")
	# Pas de camp avec un ennemi en vue
	var t3 := _neuf(3)
	var m3: CombatModele = t3[0]
	m3.pieces_stock.append({"piece": "moteur_4cyl_moyen", "etat": 0.8})
	var e3 := m3.creer_vehicule("citroen_traction", "ennemi", m3.x_tete + 80.0)
	e3.mode = "approche"
	m3.ennemis.append(e3)
	ok(not m3.camp_etablir(m3.convoi[0].uid, "changer_moteur", {"moteur": "moteur_4cyl_moyen"}), "pas de camp avec un ennemi en vue")
	print("%d ÉCHEC(S)" % echecs if echecs else "TOUT OK")
	quit(1 if echecs else 0)
