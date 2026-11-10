extends SceneTree
# Eau et vivres (DEC-148) : consommation par survivant et par jour, équipage affaibli à sec (jamais mort de faim),
# alerte, achat au marché de la ville, sauvegardes anciennes.   godot --headless --path game -s res://tests/test_ravitaillement.gd
var echecs := 0


func ok(c: bool, t: String) -> void:
	print("OK  " if c else "ÉCHEC ", t)
	if not c:
		echecs += 1


func _init() -> void:
	var R: Dictionary = CombatModele.donnees().ravitaillement
	var m := CombatModele.new(4)
	ok(m.stocks.has("eau") and m.stocks.has("vivres"), "eau et vivres au départ (%d, %d)" % [int(m.stocks.eau), int(m.stocks.vivres)])
	var n := m.survivants_nourris()
	ok(n > 0, "%d survivants à nourrir" % n)
	var e0 := float(m.stocks.eau)
	m.ordres.marche = "halte"
	m._prochain_x = INF
	for i in int(100.0 / CombatModele.DT):
		m._ravitaillement(CombatModele.DT)
	var attendu := float(R.eau_jour) * n * 100.0 / MondeJeu.JOUR_S
	ok(absf((e0 - float(m.stocks.eau)) - attendu) < 0.01, "consommation d'eau : %.2f en 100 s (attendu %.2f)" % [e0 - float(m.stocks.eau), attendu])
	ok(m.jours_de("eau") > 0.0, "jours d'eau restants : %.1f" % m.jours_de("eau"))
	# À sec
	m.stocks.eau = 0.0
	m.stocks.vivres = 0.0
	var v = m.convoi[0]
	var pv0 := float(v.equipage[0])
	for i in int(60.0 / CombatModele.DT):
		m._ravitaillement(CombatModele.DT)
	ok(float(v.equipage[0]) < pv0, "à sec, l'équipage s'affaiblit (%.1f → %.1f pv)" % [pv0, float(v.equipage[0])])
	m.journal.clear()
	for i in int(2000.0 / CombatModele.DT):
		m._ravitaillement(CombatModele.DT)
	ok(float(v.equipage[0]) >= float(R.pv_min), "jamais sous %.0f pv : on ne meurt pas de faim" % float(R.pv_min))
	# Marché
	var mv := CombatModele.new(7, {"villes": true})
	mv.champs_on = false
	mv.meteo_on = false
	mv.monde._assaut_t = 1.0e9
	mv._prochain_x = INF
	mv.stocks.gazole = 500.0
	mv.ordre_marche("avancer")
	var s := 0.0
	while s < 600.0 and not mv.ville_dedans():
		mv.avancer()
		s += CombatModele.DT
	mv.stocks.metal = 100.0
	var eau0 := float(mv.stocks.eau)
	ok(mv.ville_acheter("eau"), "achat d'eau au marché")
	ok(absf(float(mv.stocks.eau) - eau0 - float(CombatModele.VD().marche.lot)) < 0.01 and int(mv.stocks.metal) == 100 - mv.ville_prix_lot("eau"), "lot reçu, métal payé")
	mv.stocks.metal = 0.0
	ok(not mv.ville_acheter("vivres"), "pas de métal, pas de vivres")
	# Sauvegarde d'avant le 08/11 : pas d'eau ni de vivres
	var d: Dictionary = JSON.parse_string(JSON.stringify(m.sauver()))
	d.stocks.erase("eau")
	d.stocks.erase("vivres")
	var m2 := CombatModele.depuis_sauvegarde(d)
	ok(float(m2.stocks.eau) == float(CombatModele.donnees().stocks_depart.eau), "ancienne sauvegarde : réserve d'eau de départ")
	# Kit : sans limite, pas de consommation
	var mk := CombatModele.new(3, {"bac_a_sable": true})
	var ek := float(mk.stocks.eau)
	for i in 100:
		mk.avancer()
	ok(float(mk.stocks.eau) == ek and ek > 9999.0, "Kit : eau sans limite")
	print("Ravitaillement : %d échec(s)." % echecs)
	quit(1 if echecs > 0 else 0)
