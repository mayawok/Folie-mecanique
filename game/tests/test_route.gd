# Route (lot E) : voyage de plusieurs étapes, convois alliés ou hostiles selon la réputation, rumeurs, tempêtes seulement dans les déserts
# (DEC-172, 187, DEC-218). godot --headless --path game -s res://tests/test_route.gd
extends SceneTree

var echecs := 0


func ok(c: bool, t: String) -> void:
	print("OK  " if c else "ÉCHEC ", t)
	if not c:
		echecs += 1


func marche(m: CombatModele, s: float) -> void:
	for i in int(s / CombatModele.DT):
		m.avancer()


func _init() -> void:
	Textes.langue = "fr"
	# 1) Voyage de plusieurs étapes : on traverse les villes intermédiaires sans s'arrêter
	var m := CombatModele.new(1)
	var w := m.monde
	m.stocks.gazole = 1.0e6
	m.meteo_on = false
	m.champs_on = false
	w._assaut_t = 1.0e9
	var loin := -1
	for s in w.secteurs:
		var ch: Array = CarteMonde.chemin(String(w.secteurs[w.secteur].lieu), String(s.lieu))
		if ch.size() == 3:
			loin = int(s.id)
	ok(loin >= 0 and w.choisir_destination(loin), "une ville à deux étapes se choisit (%s)" % w.secteurs[loin].nom)
	ok(w.plan.size() == 1 and w.en_transit(), "le voyage garde l'étape suivante en réserve")
	var milieu: int = int(w.trajet.dest)
	m.ordre_marche("avancer")
	m._prochain_x = INF
	var vu_milieu := false
	for i in 40000:
		m.avancer()
		if w.secteur == milieu and not w.en_transit():
			vu_milieu = true
		if not w.en_transit():
			break
		if w.secteur == milieu:
			vu_milieu = true
			m._prochain_x = INF
	ok(w.secteur == loin and w.plan.is_empty(), "arrivée à la ville lointaine, plan terminé")
	ok(vu_milieu, "la ville intermédiaire est traversée sans s'arrêter")
	ok(not m.ville_dedans() or int(m.ville.secteur) == loin, "pas de ville posée à l'étape intermédiaire")

	# 2) Rumeurs : un texte par destination, sans chiffre, différent selon le danger
	var m2 := CombatModele.new(2)
	var w2 := m2.monde
	var calme := w2.rumeur(w2.indice_lieu("pertuis"))
	var chaud := w2.rumeur(w2.indice_lieu("rhin"))
	ok(calme != "" and chaud != "" and calme != chaud, "rumeur : différente selon la destination")
	ok(not ("niveau" in chaud.to_lower()) and not chaud.contains("+3"), "rumeur : aucun chiffre ni avertissement explicite")
	var hors := w2.rumeur(w2.indice_lieu("estuaire"))
	var dans := w2.rumeur(w2.indice_lieu("kerbrume"))
	ok(hors.length() > dans.length() - 5, "rumeur hors région : l'ambiance est ajoutée")

	# 3) Convois croisés : alliés (aucun tir, salut, cadeau) ou hostiles (armés)
	var m3 := CombatModele.new(3)
	m3.reputation["FAC-003"] = 60.0
	m3.monde.maj_attitudes()
	var r := RandomNumberGenerator.new()
	var alliés := 0
	for i in 20:
		r.seed = i
		m3.ennemis.clear()
		m3._n_rencontres = 5
		m3.monde.secteurs[m3.monde.secteur].niveau = 2
		if m3.rencontre_convoi(r, m3.x_tete + 120.0) or m3.rencontre_convoi(r, m3.x_tete + 120.0) or m3.rencontre_convoi(r, m3.x_tete + 120.0):
			if not m3.ennemis.is_empty() and m3.ennemis[0].allie:
				alliés += 1
	m3.ennemis.clear()
	ok(alliés >= 1, "faction alliée : on croise des convois alliés")
	var m4 := CombatModele.new(4)
	var alié := m4.creer_vehicule("citroen_t23", "ennemi", m4.x_tete + 30.0)
	alié.allie = true
	alié.mode = "face"
	alié.profil["fac"] = "FAC-003"
	m4.ennemis.append(alié)
	m4.reputation["FAC-003"] = 40.0
	var rep0: float = m4.rep_valeur("FAC-003")
	var l0: float = m4.stocks.gazole + m4.stocks.essence
	m4.ordre_marche("avancer")
	m4.stocks.gazole = 1000.0
	l0 = m4.stocks.gazole + m4.stocks.essence
	marche(m4, 25.0)
	ok(alié.salue, "le convoi allié salue en passant")
	ok(m4.rep_valeur("FAC-003") > rep0, "le salut augmente la réputation")
	var m9 := CombatModele.new(9)
	m9.reputation["FAC-003"] = 40.0
	var ami9 := m9.creer_vehicule("citroen_t23", "ennemi", m9.x_tete - 60.0)
	ami9.allie = true
	ami9.profil["fac"] = "FAC-003"
	m9.ennemis.append(ami9)
	var tot9: float = m9.stocks.gazole + m9.stocks.essence
	m9._saluts()
	ok(m9.stocks.gazole + m9.stocks.essence == tot9 + 10.0, "un allié amical passe un bidon de 10 L")
	ok(alié.statut == "actif" and alié.pieces.chassis.pv == alié.pieces.chassis.max, "on ne tire pas sur un convoi allié")
	var m5 := CombatModele.new(5)
	var arme := m5.creer_vehicule("m3_half_track", "ennemi", 10.0)
	arme.allie = true
	ok(m5.eperonne(arme) == false, "un allié n'éperonne jamais")

	# 4) Tempêtes : seulement dans les déserts
	var m6 := CombatModele.new(6, {"meteo": true})
	Terrain.zone = "terre"
	m6._tempete_t = 0.0
	m6._meteo(1.0)
	ok(m6.tempete.is_empty(), "pas de tempête en zone de terre")
	Terrain.zone = "sable"
	m6._tempete_t = 0.0
	m6._meteo(1.0)
	for i in 60:
		if not m6.tempete.is_empty():
			break
		m6._tempete_t = 0.0
		m6._meteo(1.0)
	ok(not m6.tempete.is_empty(), "une tempête peut tomber dans le sable")
	Terrain.zone = "terre"

	# Sauvegarde du plan
	var m7 := CombatModele.new(7)
	m7.monde.plan = [3, 5]
	var m8 := CombatModele.depuis_sauvegarde(JSON.parse_string(JSON.stringify(m7.sauver())))
	ok(m8.monde.plan == [3, 5], "le plan de voyage survit à la sauvegarde")

	print("Échecs : %d" % echecs)
	quit(1 if echecs > 0 else 0)
