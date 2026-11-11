# Transmission, accélération, freinage et tenue (DEC-232, DEC-233).
# godot --headless --path game -s res://tests/test_transmission.gd
extends SceneTree

var echecs := 0


func ok(c: bool, t: String) -> void:
	print("OK   " if c else "ÉCHEC ", t)
	if not c:
		echecs += 1


func conduite(urgence: bool, secondes: float, pente := 0.0, adh := 1.0) -> Dictionary:
	var T := Transmission.etat_neuf()
	T.urgence = urgence
	var P := {"vtop": 12.0, "a_base": 2.0, "adh": adh, "masse_f": 1.0, "pente": pente}
	var v := 0.0
	var dt := 0.1
	var vs := []
	for i in int(secondes / dt):
		v = Transmission.pas(T, v, 12.0, dt, P)
		vs.append(v)
	return {"v": v, "T": T, "vs": vs}


func freiner(v0: float, adh: float) -> float:
	var T := Transmission.etat_neuf()
	T.rapport = 4
	var P := {"vtop": 12.0, "a_base": 2.0, "adh": adh, "masse_f": 1.0, "pente": 0.0}
	var v := v0
	var d := 0.0
	for i in 400:
		v = Transmission.pas(T, v, 0.0, 0.1, P)
		d += v * 0.1
		if v <= 0.0:
			break
	return d


func _init() -> void:
	Textes.langue = "fr"
	# Accélération progressive, par rapports
	var calme := conduite(false, 3.0)
	ok(float(calme.v) > 0.5 and float(calme.v) < 8.0, "départ progressif : %.1f m/s après 3 s (pas de saut à la vitesse max)" % float(calme.v))
	var longue := conduite(false, 20.0)
	ok(float(longue.v) > 10.0, "la vitesse de croisière finit par être atteinte (%.1f m/s)" % float(longue.v))
	ok(int(longue.T.rapport) >= 4 and int(longue.T.passages) >= 3, "les rapports montent un à un (rapport %d, %d passages)" % [int(longue.T.rapport), int(longue.T.passages)])
	var vs: Array = longue.vs
	var creux := false
	for i in range(1, vs.size()):
		if float(vs[i]) < float(vs[i - 1]) - 0.05:
			creux = true
	ok(not creux, "pas de recul de vitesse pendant l'accélération (seulement la coupure au passage)")
	# Calme contre urgence
	var urg := conduite(true, 3.0)
	ok(float(urg.v) > float(calme.v) * 1.4, "urgence : démarrage plus vif (%.1f contre %.1f m/s)" % [float(urg.v), float(calme.v)])
	# Pente : plus lent en côte, rétrograde
	var cote := conduite(false, 6.0, 0.09)
	var plat := conduite(false, 6.0, 0.0)
	ok(float(cote.v) < float(plat.v), "côte : accélération réduite (%.1f contre %.1f m/s)" % [float(cote.v), float(plat.v)])
	ok(int(cote.T.rapport) <= int(plat.T.rapport), "côte : un rapport plus bas ou égal")
	# Freinage : progressif, plus long sur sol meuble
	var d_route := freiner(10.0, 1.0)
	var d_sable := freiner(10.0, 0.5)
	ok(d_route > 5.0 and d_route < 20.0, "freinage progressif sur route : %.1f m pour s'arrêter de 10 m/s" % d_route)
	ok(d_sable > d_route * 1.5, "freinage plus long sur sol meuble (%.1f m)" % d_sable)
	ok(Transmission.vitesse_sure(0.0, 4.5) == 0.0 and Transmission.vitesse_sure(20.0, 4.5) > 8.0, "vitesse sûre : nulle au contact, élevée de loin")
	# Renversement
	ok(Transmission.se_renverse(0.5, 10.0) and not Transmission.se_renverse(2.0, 10.0) and not Transmission.se_renverse(0.5, 3.0), "renversement : instable et rapide seulement")
	# Effet accordéon : la tête accélère puis freine, le suiveur s'éloigne puis se rapproche, puis l'écart revient
	var u := 0.0
	var e := 0.0
	var h := 0.0
	var e_min := 0.0
	var e_max := 0.0
	for i in 600:
		var t := i * 0.1
		h = minf(10.0, t * 2.5) if t < 12.0 else maxf(0.0, 10.0 - (t - 12.0) * 6.0)
		var r := Transmission.suiveur(u, e, h, 1.35, 0.1)
		u = r[0]
		e = r[1]
		e_min = minf(e_min, e)
		e_max = maxf(e_max, e)
	ok(e_min < -0.5 and e_max > 0.0, "accordéon : s'éloigne à l'accélération (%.1f m), se rapproche au freinage (+%.1f m)" % [e_min, e_max])
	ok(absf(e) < 0.2, "accordéon : l'écart revient à zéro à l'arrêt (%.2f m)" % e)
	# Dans le modèle : démarreur, démarrage progressif, freinage progressif
	var m := CombatModele.new(4)
	ok(float(m.convoi[0].profil.get("puissance_ch", 0.0)) > 0.0, "la puissance du moteur est dans le profil")
	m.ennemis.clear()
	m.ordres.marche = "avancer"
	m.avancer()
	ok(float(m.trans.demarreur) > 0.0 and m.vitesse_convoi == 0.0, "départ moteur coupé : le démarreur tourne, le convoi ne bouge pas")
	var v_max := 0.0
	for i in 15:
		m.ennemis.clear()
		m.avancer()
		v_max = maxf(v_max, m.vitesse_convoi)
	ok(m.vitesse_convoi > 0.0 and m.vitesse_convoi < 4.0, "après 1,6 s : en mouvement mais pas à pleine vitesse (%.1f m/s)" % m.vitesse_convoi)
	for i in 120:
		m.ennemis.clear()
		m.avancer()
	var v_croisiere := m.vitesse_convoi
	ok(v_croisiere > 3.0 and int(m.trans.rapport) > 1, "après 14 s : vitesse de marche (%.1f m/s), rapport %d" % [v_croisiere, int(m.trans.rapport)])
	m.ordres.marche = "halte"
	m.avancer()
	ok(m.vitesse_convoi > 0.0 and m.vitesse_convoi < v_croisiere, "halte : le convoi ne s'arrête pas net (%.1f m/s)" % m.vitesse_convoi)
	for i in 100:
		m.avancer()
	ok(m.vitesse_convoi == 0.0 and bool(m.trans.moteur_on), "halte : arrêt complet, moteur au ralenti")
	# Urgence automatique : un ennemi en vue
	ok(not bool(m.trans.urgence), "aucun ennemi : mode calme")
	print("--- %s" % ("TOUT EST OK" if echecs == 0 else "%d ÉCHEC(S)" % echecs))
	quit(1 if echecs > 0 else 0)
