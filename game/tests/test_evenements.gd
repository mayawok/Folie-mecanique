# Test sans écran de la tempête de sable (DEC-027) et des champs de mines (DEC-028) :
#   godot --headless --path game -s res://tests/test_evenements.gd
extends SceneTree

var echecs := 0


func verifier(cond: bool, msg: String) -> void:
	print(("OK   " if cond else "ÉCHEC ") + msg)
	if not cond:
		echecs += 1


func _avancer(m: CombatModele, secondes: float) -> void:
	for i in int(secondes / CombatModele.DT):
		m.avancer()


# Modèle isolé : pas de rencontre, carburant et munitions en abondance
func _modele(graine: int, options: Dictionary) -> CombatModele:
	var m := CombatModele.new(graine, options)
	m._prochain_x = INF
	m.stocks.fuel_l = 500.0
	m.stocks.ammo = 200.0
	return m


func _champ(m: CombatModele, x0: float, n := 6) -> void:
	m._champ_id += 1
	for i in n:
		m.mines.append({"x": x0 + i * 6.0, "arme_t": 0.0, "armee": true, "champ": m._champ_id, "marquee": false})


func _degats(m: CombatModele) -> float:
	var d := 0.0
	for v in m.convoi:
		for id in ["roulement", "suspension", "chassis"]:
			d += v.pieces[id].max - v.pieces[id].pv
	return d


func _init() -> void:
	_tempete()
	_mines()
	_abordage()
	print("\n%s" % ("TOUT EST OK" if echecs == 0 else "%d ÉCHEC(S)" % echecs))
	quit(1 if echecs > 0 else 0)


func _tempete() -> void:
	print("— Tempête de sable —")
	var C: Dictionary = CombatModele.donnees().tempete
	var m := _modele(7, {"meteo": true})
	m.ajouter_vehicule("m4_sherman")
	var sherman = m.convoi[m.convoi.size() - 1]
	var willys = m.convoi[0]
	var moteur0: float = willys.pieces.moteur.pv
	var moteur_s0: float = sherman.pieces.moteur.pv
	verifier(m.tempete.is_empty(), "aucune tempête au départ")
	m._tempete_t = 0.0
	m.monde.heure = 0.30   # matin
	_avancer(m, 0.2)
	verifier(m.tempete_annoncee(), "la tempête est annoncée à l'avance")
	verifier(m.tempete.reste >= C.annonce[0] - 1.0 and m.tempete.reste <= C.annonce[1], "annonce de 30 à 45 s (%.0f s)" % m.tempete.reste)
	verifier(m.journal.any(func(j): return "Tempête de sable dans" in j.txt), "message « Tempête de sable dans N s »")
	verifier(m.facteur_precision_meteo() == 1.0, "pas d'effet pendant l'annonce")
	_avancer(m, 46.0)
	verifier(m.tempete_active(), "la tempête éclate après l'annonce")
	verifier(m.tempete.duree >= C.duree[0] and m.tempete.duree <= C.duree[1], "durée de 60 à 120 s (%.0f s)" % m.tempete.duree)
	verifier(m.facteur_precision_meteo() == 0.5, "précision ×0,5")
	verifier(is_equal_approx(m.facteur_vitesse_meteo(), 0.6), "vitesse ×0,6")
	# Vitesse réelle du convoi réduite
	var m2 := _modele(7, {"meteo": false})
	m2.ordre_marche("avancer")
	_avancer(m2, 3.0)
	var v_normale := m2.vitesse_convoi
	m.ordre_marche("avancer")
	_avancer(m, 3.0)
	verifier(m.vitesse_convoi > 0.0 and m.vitesse_convoi < v_normale * 0.7, "convoi ralenti (%.1f contre %.1f m/s)" % [m.vitesse_convoi, v_normale])
	m.ordre_marche("halte")
	# Usure des véhicules ouverts, équipages exposés mais jamais tués
	m.tempete.reste = 200.0
	m.tempete.duree = 200.0
	var sante0: float = willys.equipage[0]
	_avancer(m, 60.0)
	verifier(willys.pieces.moteur.pv < moteur0 and willys.pieces.moteur.pv >= 1.0, "moteur de la Jeep (véhicule ouvert) usé, jamais détruit")
	verifier(sherman.pieces.moteur.pv == moteur_s0, "moteur du Sherman (fermé) intact")
	verifier(willys.equipage[0] < sante0 and willys.equipage[0] >= float(C.sante_min), "équipage dehors affaibli sans mourir")
	_avancer(m, 150.0)
	verifier(willys.equipage[0] >= float(C.sante_min) and willys.equipage_vivant() > 0, "l'équipage survit à une longue tempête")
	# Abri : un véhicule garé est protégé
	var m3 := _modele(7, {"meteo": true})
	m3.tempete = {"phase": "active", "reste": 100.0, "duree": 100.0}
	m3.convoi[0].garage = 99999
	var mot3: float = m3.convoi[0].pieces.moteur.pv
	_avancer(m3, 30.0)
	verifier(m3.convoi[0].pieces.moteur.pv == mot3, "un véhicule au garage est protégé")
	# Pas de nouvelle vague pendant la tempête
	var m4 := _modele(7, {"meteo": true})
	m4._prochain_x = 0.0
	m4.tempete = {"phase": "active", "reste": 100.0, "duree": 100.0}
	m4.ordre_marche("avancer")
	_avancer(m4, 5.0)
	verifier(m4.ennemis.is_empty() and m4._n_rencontres == 0, "pas de rencontre pendant la tempête")
	# Fin de tempête
	var m5 := _modele(7, {"meteo": true})
	m5.tempete = {"phase": "active", "reste": 3.0, "duree": 3.0}
	_avancer(m5, 4.0)
	verifier(m5.tempete.is_empty() and m5._tempete_t >= C.intervalle[0], "la tempête prend fin et la suivante est programmée")
	# Désactivée hors partie jouée (anciens tests d'équilibrage)
	var m6 := _modele(7, {})
	m6._tempete_t = 0.0
	_avancer(m6, 5.0)
	verifier(m6.tempete.is_empty(), "pas de tempête sans l'option meteo")
	# Surtout le jour : de nuit, la plupart des tempêtes sont reportées
	var nuit_report := 0
	for g in 40:
		var mn := _modele(g, {"meteo": true})
		mn.monde.heure = 0.80
		mn._tempete_t = 0.0
		mn.avancer()
		if mn.tempete.is_empty():
			nuit_report += 1
	verifier(nuit_report >= 25, "de nuit, %d tempêtes sur 40 reportées (attendu : environ 32)" % nuit_report)
	# Déterminisme
	var a := _modele(11, {"meteo": true})
	var b := _modele(11, {"meteo": true})
	_avancer(a, 600.0)
	_avancer(b, 600.0)
	verifier(a.tempete == b.tempete and is_equal_approx(a._tempete_t, b._tempete_t), "même graine, même calendrier de tempêtes")


func _mines() -> void:
	print("— Champs de mines —")
	var C: Dictionary = CombatModele.donnees().mines_champs
	# Génération à graine fixe, plus fréquente avec le niveau
	var g1 := _modele(5, {"champs": true})
	var g2 := _modele(5, {"champs": true})
	g1.x_tete = 6000.0
	g2.x_tete = 6000.0
	g1._champs_generer()
	g2._champs_generer()
	var n1 := g1.mines.filter(func(mn): return int(mn.get("champ", 0)) > 0).size()
	verifier(n1 > 0, "des champs sont tirés sur la route (%d mines)" % n1)
	verifier(g1.mines.map(func(mn): return mn.x) == g2.mines.map(func(mn): return mn.x), "même graine, mêmes champs")
	var off := _modele(5, {})
	off.x_tete = 6000.0
	off._champs_generer()
	verifier(off.mines.is_empty(), "pas de champ sans l'option champs")
	# Détection et arrêt automatique
	var m := _modele(3, {"champs": true})
	_champ(m, m.x_tete + 70.0)
	m.ordre_marche("avancer")
	_avancer(m, 5.0)
	verifier(m.journal.any(func(j): return "Champ de mines à" in j.txt), "alerte « Champ de mines à N m »")
	_avancer(m, 40.0)
	var c := m.champ_devant()
	verifier(not c.is_empty() and c.n == 6, "le champ est repéré (6 mines)")
	verifier(c.dist >= 0.0 and c.dist <= C.arret_m + 1.0, "le convoi s'arrête devant le champ (à %.1f m)" % c.dist)
	verifier(m.vitesse_convoi == 0.0 and "mines" in m.blocage, "blocage affiché : %s" % m.blocage)
	verifier(_degats(m) == 0.0, "aucun dégât : arrêt avant la première mine")
	# Sans moyen : refus
	m.ordre_marche("halte")
	verifier(m.raison_demin("detecteur") != "", "sans détecteur, le déminage est refusé")
	# Détecteur de métaux
	m.equip_demin.detecteur = true
	var ammo0: float = m.stocks.ammo
	var metal0: float = m.stocks.metal
	verifier(m.ordre_deminer("detecteur"), "déminage au détecteur accepté")
	_avancer(m, 7.0 * 6.0 + 10.0)
	verifier(m.champ_devant().is_empty() and m.demin.is_empty(), "le champ est entièrement déminé")
	verifier(m.stocks.ammo < ammo0 or m.stocks.metal > metal0, "mines sautées au tir ou récupérées")
	verifier(_degats(m) == 0.0, "aucun dégât pendant le déminage")
	m.ordre_marche("avancer")
	_avancer(m, 10.0)
	verifier(m.vitesse_convoi > 0.0, "le convoi repart")
	# Interruption par une menace et manque de munitions
	var mm := _modele(3, {"champs": true})
	_champ(mm, mm.x_tete + 40.0)
	mm.equip_demin.detecteur = true
	mm.stocks.ammo = 0.0
	verifier(mm.raison_demin("detecteur") != "", "pas de munitions : déminage refusé")
	# Chien : plus rapide, peut être blessé (réglé sans blessure puis avec)
	var D: Dictionary = CombatModele.donnees()
	var blesse0: float = D.mines_champs.chien_blesse
	D.mines_champs.chien_blesse = 0.0
	var mc := _modele(3, {"champs": true})
	_champ(mc, mc.x_tete + 40.0)
	mc.equip_demin.chien_pv = 3
	verifier(mc.moyens_demin() == ["chien"], "le chien est un moyen de déminage")
	verifier(mc.ordre_deminer("chien"), "déminage au chien accepté")
	_avancer(mc, 3.0 * 6.0 + 5.0)
	verifier(mc.champ_devant().is_empty() and mc.equip_demin.chien_pv == 3, "le chien déminé plus vite (6 mines en %.0f s) sans blessure" % (3.0 * 6.0 + 5.0))
	D.mines_champs.chien_blesse = 1.0
	var md := _modele(3, {"champs": true})
	_champ(md, md.x_tete + 40.0)
	md.equip_demin.chien_pv = 2
	md.ordre_deminer("chien")
	_avancer(md, 20.0)
	verifier(md.equip_demin.chien_pv == 0 and md.demin.is_empty() and not md.champ_devant().is_empty(), "le chien blessé deux fois est perdu, le champ reste")
	D.mines_champs.chien_blesse = blesse0
	# Fléau sur un véhicule à chenilles
	var mf := _modele(3, {"champs": true})
	var sh = mf.ajouter_vehicule("m4_sherman")
	while mf.convoi[0] != sh:
		mf.monter(sh.uid)
	_champ(mf, mf.x_tete + 40.0)
	mf.equip_demin.fleau_pv = 100.0
	verifier(mf.fleau_pret(), "fléau prêt : chenilles en tête")
	mf.ordre_marche("avancer")
	_avancer(mf, 60.0)
	verifier(mf.champ_devant().is_empty() and mf.x_tete > 60.0, "le convoi traverse derrière le fléau")
	verifier(_degats(mf) == 0.0, "aucun dégât : les mines explosent contre le fléau")
	verifier(mf.equip_demin.fleau_pv < 100.0, "le fléau s'use (%.0f / 100)" % mf.equip_demin.fleau_pv)
	var ms := _modele(3, {"champs": true})   # fléau mais véhicule sans chenilles en tête
	ms.equip_demin.fleau_pv = 100.0
	verifier(not ms.fleau_pret(), "le fléau exige un véhicule à chenilles en tête")
	# Traversée à l'aveugle
	var mt := _modele(3, {"champs": true})
	_champ(mt, mt.x_tete + 40.0)
	mt.ordre_marche("avancer")
	_avancer(mt, 40.0)
	verifier(mt.vitesse_convoi == 0.0, "arrêt devant le champ avant le choix")
	verifier(mt.ordre_traverser(), "traversée choisie")
	_avancer(mt, 40.0)
	verifier(_degats(mt) > 50.0, "traversée à l'aveugle : gros dégâts (%.0f)" % _degats(mt))
	# Sauvegarde
	var ss := _modele(3, {"champs": true, "meteo": true})
	ss.equip_demin.detecteur = true
	ss.equip_demin.chien_pv = 2
	var r := CombatModele.depuis_sauvegarde(ss.sauver())
	verifier(r.champs_on and r.meteo_on and r.equip_demin.detecteur and r.equip_demin.chien_pv == 2, "sauvegarde : options et moyens de déminage conservés")


# Poursuites et abordages (DEC-077)
func _poursuivant(m: CombatModele, types: Array) -> CombatModele.Veh:
	var xq := m.x_tete
	for v in m.convoi:
		xq = minf(xq, v.x)
		m.ordre_tir(v.uid, false)   # cessez-le-feu : on laisse l'ennemi aborder
	var e := m.creer_vehicule("citroen_traction", "ennemi", xq - 60.0)
	m.preparer_poursuivant(e, {"abordeurs": 1, "types": types})
	e.armes = []   # désarmé : on teste l'abordage seul
	m.ennemis.append(e)
	return e


func _abordage() -> void:
	print("\n— Poursuites et abordages (DEC-077) —")
	var m := _modele(5, {})
	var e := _poursuivant(m, ["lame"])
	var x0: float = e.x
	m.ordre_marche("avancer")
	var vu_saut := false
	var vu_bord := false
	for i in int(40.0 / CombatModele.DT):
		m.avancer()
		for ab in m.abordeurs:
			vu_saut = vu_saut or ab.etat == "saut"
			vu_bord = vu_bord or ab.etat == "bord"
	verifier(e.x > x0 + 40.0, "le poursuivant rattrape le convoi par l'arrière (%.0f m parcourus)" % (e.x - x0))
	verifier(m.convoi.any(func(v): return absf((v.x + v.longueur * 0.5) - (e.x + e.longueur * 0.5)) < 4.0), "il se cale à hauteur d'un véhicule du convoi")
	verifier(vu_saut and vu_bord, "un pillard saute et prend pied sur le véhicule")
	verifier(m.abordeurs.is_empty(), "le combat à la lame se termine (pillard repoussé ou équipage tombé)")
	var m2 := _modele(6, {})
	var e2 := _poursuivant(m2, ["bombe"])
	m2.ordre_marche("avancer")
	var avant := 0.0
	for v in m2.convoi:
		for id in v.pieces:
			avant += v.pieces[id].pv
	_avancer(m2, 40.0)
	var apres := 0.0
	for v in m2.convoi:
		for id in v.pieces:
			apres += v.pieces[id].pv
	verifier(apres < avant - 10.0, "la lance explosive endommage le véhicule abordé (%.0f PV perdus)" % (avant - apres))
	verifier(not m2.convoi.any(func(v): return false) and m2.blocage != "La route est barrée par un véhicule ennemi.", "un poursuivant à côté ne barre pas la route")

