extends SceneTree
# Ville pillée (DEC-151) : portes enfoncées, entrée sans arrêt, récit, poursuite accélérée, convoi des pillards devant,
# réserves reprises s'il est détruit, perdu s'il s'éloigne.   godot --headless --path game -s res://tests/test_ville_pillee.gd
var echecs := 0


func ok(c: bool, t: String) -> void:
	print("OK  " if c else "ÉCHEC ", t)
	if not c:
		echecs += 1


func _jusqua(m: CombatModele, cond: Callable, s_max: float) -> float:
	var s := 0.0
	while s < s_max and not cond.call():
		m.avancer()
		s += CombatModele.DT
	return s


func _entrer(m: CombatModele) -> void:
	ok(m.kit_ville("pillee") and m.ville_pillee(), "Kit : ville pillée devant")
	ok(float(m.ville.porte_e) == 1.0 and float(m.ville.porte_s) == 1.0, "portes enfoncées")
	m.ordre_marche("avancer")
	var arret := [false]
	_jusqua(m, func():
		if m.ville_phase() == "approche" and m.vitesse_convoi <= 0.0 and m.x_tete > float(m.ville.x0) - 10.0:
			arret[0] = true
		return m.ville_dedans(), 300.0)
	ok(m.ville_dedans() and not arret[0], "on entre sans s'arrêter à la porte")


func _init() -> void:
	var P: Dictionary = CombatModele.VD().variantes.pillee
	var m := CombatModele.new(5, {"bac_a_sable": true})
	_entrer(m)
	var stocks0: Dictionary = m.stocks.duplicate()
	ok(m.ville_poursuite(), "poursuite lancée")
	var vmax := [0.0]
	_jusqua(m, func():
		vmax[0] = maxf(vmax[0], m.vitesse_convoi)
		return m.ville_phase() == "fin", 120.0)
	ok(vmax[0] > float(CombatModele.VD().vitesse_forcee) + 0.5, "on traverse la ville en accélérant (%.1f m/s)" % vmax[0])
	m.avancer()
	ok(m.evenement.phase == "chasse" and m.evenement.pillards.size() == P.pillards.size(), "%d pillards devant" % m.evenement.pillards.size())
	var e0 = m.ennemis.filter(func(e): return m.evenement.pillards.has(e.uid))[0]
	var x0 := float(e0.x)
	for i in 20:
		m.avancer()
	ok(float(e0.x) > x0, "le convoi des pillards roule devant, dans notre sens")
	for e in m.ennemis:   # le test détruit les pillards
		if m.evenement.pillards.has(e.uid):
			e.statut = "epave"
	m.avancer()
	ok(m.evenement.is_empty() and bool(m.mission_bilan.get("ok", false)), "pillards détruits : réserves reprises")
	ok(float(m.stocks.vivres) >= float(stocks0.vivres) + float(P.butin.vivres) - 1.0, "vivres récupérés")
	# Pillards perdus
	var m2 := CombatModele.new(8, {"bac_a_sable": true})
	_entrer(m2)
	m2.ville_poursuite()
	_jusqua(m2, func(): return m2.ville_phase() == "fin", 120.0)
	m2.avancer()
	m2.ordre_marche("halte")
	for e in m2.ennemis:
		if m2.evenement.pillards.has(e.uid):
			e.x += float(P.pillards_perdus_m) + 50.0
	m2.avancer()
	ok(m2.evenement.is_empty() and not bool(m2.mission_bilan.get("ok", true)), "pillards trop loin : perdus")
	print("Ville pillée : %d échec(s)." % echecs)
	quit(1 if echecs > 0 else 0)
