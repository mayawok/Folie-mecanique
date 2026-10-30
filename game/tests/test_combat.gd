# Test sans écran du mode convoi :
#   godot --headless --path game -s res://tests/test_combat.gd
# Vérifie : déterminisme, marche et carburant, blocage par véhicule immobilisé, effets des pièces
# cassées, combat et butin, fouille, réparation, rencontres. Affiche aussi un bilan d'équilibrage.
extends SceneTree

var echecs := 0


func verifier(cond: bool, msg: String) -> void:
	print(("OK   " if cond else "ÉCHEC ") + msg)
	if not cond:
		echecs += 1


func _avancer(m: CombatModele, secondes: float) -> void:
	for i in int(secondes / CombatModele.DT):
		m.avancer()


# Convoi complet pour les tests de combat : Stuart en tête, half-track, Willys
func _equipe(m: CombatModele) -> void:
	m.ajouter_vehicule("m3_half_track")
	var st: CombatModele.Veh = m.ajouter_vehicule("m3_stuart")
	m.monter(st.uid)
	m.monter(st.uid)
	m._replacer(true)


func _init() -> void:
	# --- Départ
	var m := CombatModele.new(42)
	verifier(m.convoi.size() == 1 and m.convoi[0].type == "willys_mb", "le départ est une Jeep seule")
	_equipe(m)
	verifier(m.convoi.size() == 3, "le convoi de départ compte 3 véhicules")
	var ok_pos := true
	for i in range(1, m.convoi.size()):
		ok_pos = ok_pos and m.convoi[i].x + m.convoi[i].longueur < m.convoi[i - 1].x
	verifier(ok_pos, "les véhicules sont alignés sans se recouvrir")

	# --- Marche et carburant
	var x0 := m.x_tete
	var c0: float = m.stocks.fuel_l
	m.ordre_marche("avancer")
	_avancer(m, 10.0)
	verifier(m.x_tete > x0 + 20.0, "le convoi avance (%.0f m en 10 s)" % (m.x_tete - x0))
	verifier(m.stocks.fuel_l < c0, "le carburant baisse (%.1f L)" % (c0 - m.stocks.fuel_l))
	m.ordre_marche("halte")
	var x1 := m.x_tete
	_avancer(m, 2.0)
	verifier(is_equal_approx(m.x_tete, x1), "Halte : le convoi s'arrête")

	# --- Effets des pièces cassées
	var w: CombatModele.Veh = m.convoi[2]
	var v_ok := w.vitesse()
	w.pieces.suspension.pv = 0.0
	verifier(is_equal_approx(w.vitesse(), v_ok * 0.5), "suspension détruite : vitesse ÷ 2")
	w.pieces.suspension.pv = w.pieces.suspension.max
	w.pieces.roulement.pv = 0.0
	m.ordre_marche("avancer")
	var x2 := m.x_tete
	_avancer(m, 3.0)
	verifier(is_equal_approx(m.x_tete, x2) and m.blocage != "", "roues détruites : le convoi est bloqué (%s)" % m.blocage)
	m.ordre_marche("halte")

	# --- Réparation avec une pièce récupérée
	m.composants.append({"kind": "roulement", "classe": "", "nom": "Roues test", "etat": 0.8})
	verifier(m.ordre_reparer(w.uid, true), "réparation acceptée à l'arrêt")
	_avancer(m, 8.0)
	verifier(w.pieces.roulement.pv > 0.0 and m.composants.is_empty(), "la pièce de rechange est montée et consommée")
	w.reparation = false

	# --- Ordres de rang, cessez-le-feu, abandon
	var u_tete: int = m.convoi[0].uid
	m.descendre(u_tete)
	verifier(m.convoi[1].uid == u_tete, "l'ordre « rang vers l'arrière » échange deux véhicules")
	m.monter(u_tete)
	verifier(m.convoi[0].uid == u_tete, "l'ordre « rang vers l'avant » le remet en tête")
	m.ordre_tir(u_tete, false)
	verifier(not m.convoi[0].tir, "cessez-le-feu appliqué à un véhicule")
	var ab: CombatModele.Veh = m.convoi[2]
	m.abandonner(ab.uid)
	verifier(not m.convoi.has(ab) and m.epaves.has(ab) and ab.statut == "abandonne", "abandon : le véhicule quitte le convoi et devient récupérable")

	# --- Combat : un ennemi attaque, le convoi gagne et récupère le butin
	var m2 := CombatModele.new(7)
	_equipe(m2)
	var e := m2.creer_vehicule("citroen_traction", "ennemi", m2.x_tete + 45.0)
	m2.ennemis.append(e)
	m2._prochain_x = 1.0e9   # pas d'autre rencontre dans ce test
	m2.ordre_marche("halte")
	var muni0: float = m2.stocks.ammo
	_avancer(m2, 120.0)
	verifier(not e.actif() and m2.epaves.has(e), "l'ennemi est hors de combat et devient une épave (statut %s)" % e.statut)
	verifier(m2.stocks.ammo < muni0, "les munitions sont consommées (%.0f -> %.0f)" % [muni0, m2.stocks.ammo])
	verifier(m2.ennemis_detruits == 1, "un ennemi comptabilisé")
	var butin_avant: float = m2.stocks.metal
	_avancer(m2, 10.0)
	verifier(not e.butin_pris, "l'épave est trop loin pour être fouillée à l'arrêt")
	m2.ordre_fouiller(e.uid)
	_avancer(m2, 60.0)
	verifier(e.butin_pris and m2.stocks.metal > butin_avant, "en avançant, le convoi s'arrête et fouille l'épave (+%.0f métal)" % (m2.stocks.metal - butin_avant))

	# --- Visée : viser les roues immobilise plus souvent
	var immob := 0
	var essais := 40
	for k in essais:
		var mt := CombatModele.new(100 + k)
		mt.ordre_visee("roulement")
		var cible := mt.creer_vehicule("citroen_t23", "ennemi", mt.x_tete + 30.0)
		var tireur: CombatModele.Veh = mt.convoi[0]
		var arm: Dictionary = CombatModele.donnees().armes["canon_leger"]
		for n in 12:
			mt._toucher_vehicule(tireur, arm, cible, "roulement")
			if not cible.piece_ok("roulement"):
				break
		if not cible.piece_ok("roulement"):
			immob += 1
	verifier(immob >= essais * 0.8, "viser les roues les détruit (%d/%d en 12 obus)" % [immob, essais])

	# --- Bâtiment : neutralisé en un temps raisonnable, butin disponible
	var m3 := CombatModele.new(5)
	_equipe(m3)
	var b := m3.creer_batiment("ferme", m3.x_tete + 40.0)
	m3.batiments.append(b)
	m3._prochain_x = 1.0e9
	_avancer(m3, 150.0)
	verifier(b.statut == "neutralise", "la ferme est neutralisée (pv %.0f, tireurs %d)" % [b.pv, b.tireurs_vivants()])

	# --- Trouvaille : réparer au toucher, le mécanicien arrive, le véhicule rejoint le convoi
	var m4 := CombatModele.new(3)
	m4._prochain_x = 0.0
	m4.avancer()
	var trouve: CombatModele.Veh = null
	for v in m4.epaves:
		if v.statut == "trouvee":
			trouve = v
	verifier(trouve != null, "la première rencontre est un véhicule à retrouver (%s)" % (trouve.nom if trouve else "?"))
	verifier(m4.batiments.size() == 1 and m4.batiments[0].statut == "neutralise", "avec une ruine à fouiller")
	trouve.x = m4.x_tete + 5.0
	for id in trouve.pieces:
		trouve.pieces[id].pv = trouve.pieces[id].max
	trouve.pieces.moteur.pv = 0.0
	verifier(not m4.peut_rejoindre(trouve), "un véhicule au moteur détruit ne peut pas rejoindre")
	m4.composants.append({"kind": "moteur", "classe": "", "nom": "Moteur test", "etat": 0.9})
	m4.ordre_marche("halte")
	verifier(m4.ordre_reparer(trouve.uid, true, "moteur"), "ordre de réparer une pièce précise")
	_avancer(m4, 3.0)
	verifier(trouve.pieces.moteur.pv <= 0.0, "le mécanicien met du temps à arriver")
	_avancer(m4, 6.0)
	verifier(trouve.pieces.moteur.pv > 0.0 and m4.composants.is_empty(), "moteur remplacé par la pièce récupérée")
	verifier(m4.peut_rejoindre(trouve) and m4.rejoindre(trouve.uid), "le véhicule réparé rejoint le convoi")
	verifier(m4.convoi.size() == 2 and trouve.actif() and trouve.equipage_vivant() == 1, "il est dans le convoi avec un survivant")
	var loin := CombatModele.new(4)
	var fl := loin.creer_vehicule("bmw_r75", "joueur", loin.x_tete + 200.0)
	fl.statut = "trouvee"
	loin.epaves.append(fl)
	verifier(not loin.ordre_reparer(fl.uid, true), "pas de mécanicien à portée d'un véhicule lointain")

	# --- Fouille d'une ruine : survivant recruté
	var m5 := CombatModele.new(8)
	m5._prochain_x = 1.0e9
	var ru := m5.creer_batiment("ferme", m5.x_tete + 3.0)
	ru.statut = "neutralise"
	ru.butin.ressources["survivants"] = 1
	m5.batiments.append(ru)
	m5.convoi[0].equipage.pop_back()
	m5.ordre_fouiller(ru.uid)
	_avancer(m5, 8.0)
	verifier(ru.butin_pris and m5.convoi[0].equipage.size() == 2, "fouiller une ruine peut recruter un survivant")

	# --- Balles en vol : temps de trajet, puis impact
	var mp := CombatModele.new(11)
	mp._prochain_x = 1.0e9
	var cp := mp.creer_vehicule("citroen_traction", "ennemi", mp.x_tete + 30.0)
	mp.ennemis.append(cp)
	mp.ordre_marche("halte")
	var vu_vol := false
	var impacts := 0
	for i in 200:
		mp.avancer()
		vu_vol = vu_vol or not mp.projectiles.is_empty()
		for ev in mp.evenements:
			if ev.t == "impact":
				impacts += 1
	verifier(vu_vol and impacts > 0, "les tirs créent des projectiles en vol puis des impacts (%d)" % impacts)

	# --- Embuscade : débarquer, se poster, tirer en premier, rembarquer
	var me := CombatModele.new(21)
	me._prochain_x = 1.0e9
	var rb := me.creer_batiment("eglise", me.x_tete + 20.0)
	rb.statut = "neutralise"
	me.batiments.append(rb)
	me.ordre_marche("halte")
	var jeep: CombatModele.Veh = me.convoi[0]
	verifier(me.ordre_debarquer(jeep.uid), "l'équipage peut aller se poster dans une église proche")
	verifier(jeep.equipage_vivant() == 0 and me.a_garnison(jeep.uid), "il est en route (véhicule vide)")
	_avancer(me, 12.0)
	verifier(rb.garnison_vivants() == 2, "les survivants sont postés dans l'église (%d)" % rb.garnison_vivants())
	var mc := me.ordre_camoufler(jeep.uid, true)
	_avancer(me, 6.0)
	verifier(mc and jeep.camoufle, "la Jeep vide est camouflée")
	var ee := me.creer_vehicule("citroen_traction", "ennemi", me.x_tete + 45.0)
	me.ennemis.append(ee)
	verifier(not me.alerte().is_empty(), "une vague en approche déclenche l'alerte")
	var v_avant: float = jeep.pieces.chassis.pv
	_avancer(me, 60.0)
	verifier(not ee.actif(), "la garnison détruit l'ennemi (statut %s)" % ee.statut)
	verifier(jeep.pieces.chassis.pv == v_avant, "le véhicule camouflé n'a pas été visé")
	verifier(me.ordre_rembarquer(jeep.uid), "ordre de rembarquer")
	me.ordre_camoufler(jeep.uid, false)
	_avancer(me, 12.0)
	verifier(jeep.equipage_vivant() == 2 and rb.garnison_vivants() == 0, "l'équipage est de retour dans la Jeep")

	# --- Mines : coût en métal et explosion sous un ennemi
	var mm := CombatModele.new(31)
	mm._prochain_x = 1.0e9
	mm.stocks.metal = 5.0
	verifier(not mm.ordre_mines(3), "pas assez de métal pour des mines")
	mm.stocks.metal = 40.0
	verifier(mm.ordre_mines(3) and mm.stocks.metal == 28.0 and mm.mines.size() == 3, "3 mines posées pour 12 métal")
	mm.mines[0].x = mm.x_tete + 20.0
	var em := mm.creer_vehicule("citroen_traction", "ennemi", mm.x_tete + 16.0)
	em.vitesse_act = -5.0
	mm.ennemis.append(em)
	_avancer(mm, 8.0)
	mm.ordre_marche("halte")
	var avant_m: float = em.pieces.roulement.pv
	em.x = mm.mines[0].x - 1.0
	em.vitesse_act = -5.0
	_avancer(mm, 1.0)
	verifier(em.pieces.roulement.pv < avant_m or mm.mines.size() < 3, "une mine armée explose sous un véhicule qui passe dessus")

	# --- Carte, secteurs et zone calme
	var mc2 := CombatModele.new(51)
	var w1 := mc2.monde
	verifier(w1.secteurs.size() == 12 and w1.secteurs[w1.secteur].niveau == 0, "12 secteurs, départ au niveau 0 (%s)" % w1.secteurs[w1.secteur].nom)
	var autre := 0
	for sct in w1.secteurs:
		if sct.niveau >= 3:
			autre = sct.id
	verifier(w1.choisir_destination(autre) and w1.en_transit(), "choisir un secteur lance un trajet calme")
	mc2.ordre_marche("avancer")
	mc2.stocks.fuel_l = 1.0e5
	var vus := 0
	for i in 12000:
		mc2.avancer()
		vus += mc2.ennemis.size() + mc2.batiments.size() if w1.en_transit() else 0
		if not w1.en_transit():
			break
	verifier(w1.secteur == autre and vus == 0, "zone calme : rien sur la route, arrivée au secteur (rencontres vues : %d)" % vus)
	verifier(w1.niveau_a(mc2.x_tete) >= 3, "le niveau des rencontres suit le secteur (%d)" % w1.niveau_a(mc2.x_tete))

	# --- Camps annoncés, fantassins, voyageurs
	var mw := CombatModele.new(61)
	mw._prochain_x = 1.0e9
	var rr := RandomNumberGenerator.new()
	rr.seed = 5
	mw.monde.generer({"camp": "ami"}, mw.x_tete + 120.0, rr)
	var camp: CombatModele.Bat = mw.batiments[0]
	verifier(camp.ami and not camp.actif() and mw.monde.annonces().size() == 1 and mw.monde.annonces()[0].dist > 250.0, "un camp allié est annoncé de loin (%d m)" % int(mw.monde.annonces()[0].dist))
	var lp := mw.monde.creer_pieton("loup", mw.x_tete + 40.0)
	mw.monde.creer_pieton("pillard", mw.x_tete + 60.0)
	_avancer(mw, 25.0)
	verifier(mw.monde.vivants() == 0 and not lp.actif(), "la mitrailleuse abat loups et pillards à pied")
	var vo := {"uid": 7, "x": mw.x_tete + 5.0, "type": "marchand", "nom": "Marchand", "offre": 0, "statut": "attend", "peau": 0}
	mw.monde.pnj.append(vo)
	mw.stocks.metal = 20.0
	var am0: float = mw.stocks.ammo
	_avancer(mw, 1.0)
	verifier(not mw.monde.dialogue.is_empty(), "un voyageur arrête le convoi")
	mw.monde.repondre(true)
	verifier(mw.stocks.ammo == am0 + 40.0 and mw.stocks.metal == 10.0 and mw.monde.dialogue.is_empty(), "échange accepté : +40 munitions, -10 métal")
	mw.monde.quete = {"titre": "t", "abattre": 1, "depart": mw.ennemis_detruits, "recompense": {"metal": 5}}
	mw.monde.creer_pieton("loup", mw.x_tete + 20.0)
	_avancer(mw, 10.0)
	verifier(mw.monde.quete.is_empty() and mw.stocks.metal >= 15.0, "la quête est accomplie et récompensée")

	# --- Nuit : alerte, abri, barricade, feu
	var mn := CombatModele.new(71)
	mn._prochain_x = 1.0e9
	var rb2 := mn.creer_batiment("maison", mn.x_tete + 12.0)
	rb2.statut = "neutralise"
	mn.batiments.append(rb2)
	mn.monde.heure = 0.60
	_avancer(mn, 20.0)
	verifier(mn.monde.nuit() and mn.monde.alerte_nuit(), "la nuit tombe : alerte d'abri")
	verifier(mn.monde.ordre_nuit(), "ordre : passer la nuit à l'abri")
	_avancer(mn, 25.0)
	verifier(rb2.barricade >= 1.0 and rb2.feu and rb2.blindage > rb2.blindage_base, "planches clouées (%.0f%%) et feu allumé" % (rb2.barricade * 100.0))
	var h0: float = mn.monde.heure
	_avancer(mn, 10.0)
	verifier(mn.monde.heure - h0 > 10.0 / MondeJeu.JOUR_S * 2.5, "la nuit passe plus vite à l'abri")

	# --- Survivants : noms, santé, affectation
	var ms := CombatModele.new(81)
	ms._prochain_x = 1.0e9
	var j2: CombatModele.Veh = ms.convoi[0]
	var b2: CombatModele.Veh = ms.ajouter_vehicule("bmw_r75")
	b2.equipage.clear()
	b2.noms.clear()
	var ls := ms.liste_survivants()
	verifier(ls.size() == 2 and ls[0].nom != "" and ms.etat_sante(ls[0].pv) == "En forme", "les survivants ont un nom et un état de santé (%s)" % ls[0].nom)
	ms.ordre_marche("avancer")
	verifier(not ms.affecter(j2.uid, 0, b2.uid), "pas d'affectation en marche")
	ms.ordre_marche("halte")
	var n0: String = j2.noms[0]
	verifier(ms.affecter(j2.uid, 0, b2.uid) and b2.noms[0] == n0 and j2.equipage.size() == 1, "un survivant change de véhicule avec son nom")

	# --- Déterminisme
	var a1 := CombatModele.new(99)
	var a2 := CombatModele.new(99)
	a1.ordre_marche("avancer")
	a2.ordre_marche("avancer")
	_avancer(a1, 300.0)
	_avancer(a2, 300.0)
	verifier(a1.resume() == a2.resume(), "même graine, mêmes ordres : même partie")
	print("   ", a1.resume())

	# --- Rencontres et équilibrage : 6 graines, ordres simples (avancer, fouille auto)
	var distances := []
	var kills := []
	for g in range(1, 7):
		var s := CombatModele.new(g)
		s.stocks.fuel_l = 1.0e6
		s.ordre_marche("avancer")
		var t := 0.0
		while not s.fini and t < 1500.0:
			s.avancer()
			t += CombatModele.DT
		distances.append(int(s.distance_max))
		kills.append(s.ennemis_detruits)
	print("   équilibrage (avancer sans réfléchir, 25 min max) : distances ", distances, " ennemis détruits ", kills)
	verifier(distances.max() > 150, "des rencontres ont bien lieu en avançant")

	print("Échecs : ", echecs)
	quit(1 if echecs > 0 else 0)
