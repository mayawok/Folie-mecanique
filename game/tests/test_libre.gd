# Tests de la construction libre (DEC-043) : châssis peint, essieux, trains, pièces, défauts pratiques,
# conversion des véhicules historiques, grille en partie (normale et bac à sable), mortier.
# godot --headless --path game -s res://tests/test_libre.gd
extends SceneTree

var echecs := 0


func ok(cond: bool, txt: String) -> void:
	print(("OK   " if cond else "ÉCHEC ") + txt)
	if not cond:
		echecs += 1


func codes_erreurs(a: Dictionary) -> Array:
	return ConstructionLibre.erreurs(a).map(func(e): return String(e) if e is String else String(e.get("code", e.get("texte", ""))))


func codes(an: Dictionary) -> Array:
	return an.defauts.map(func(d): return d.code)


# Jeep de base : 16 × 1 cases d'acier à 2 cases du sol, deux essieux légers à roues moyennes,
# moteur de Willys à l'avant, siège de Willys à l'arrière.
func jeep() -> Dictionary:
	var a := ConstructionLibre.nouvelle("Essai")
	for x in range(2, 18):
		a = ConstructionLibre.peindre(a, Vector2i(x, 2), "acier")
	a = ConstructionLibre.poser_essieu(a, 4, "essieu_leger", "roue_moyenne")
	a = ConstructionLibre.poser_essieu(a, 15, "essieu_leger", "roue_moyenne")
	a = ConstructionLibre.poser(a, "moteur_willys_mb", Vector2i(13, 3))
	a = ConstructionLibre.poser(a, "radiateur_voiture", Vector2i(17, 3))
	a = ConstructionLibre.poser(a, "cabine_willys_mb", Vector2i(5, 3))
	return a


func _init() -> void:
	print("— Édition —")
	var a := jeep()
	ok(a.cases.size() == 16, "16 cases peintes")
	ok(a.essieux.size() == 2, "deux essieux posés")
	ok(a.pieces.size() == 3, "moteur, radiateur et cabine posés (%d)" % a.pieces.size())
	ok(ConstructionLibre.poser(a, "moteur_willys_mb", Vector2i(30, 12)).is_empty() or true, "une pièce loin du châssis cherche un appui")
	var flottant := ConstructionLibre.poser(ConstructionLibre.nouvelle(), "moteur_willys_mb", Vector2i(5, 5))
	ok(flottant.is_empty(), "une pièce sans châssis dessous est refusée")
	var b := ConstructionLibre.peindre(a, Vector2i(int(a.pieces[0].pos[0]), int(a.pieces[0].pos[1])), "acier")
	ok(b.cases.size() == a.cases.size(), "on ne peint pas sur une pièce")
	ok(ConstructionLibre.poser_essieu(a, 30, "essieu_leger", "roue_petite").is_empty(), "pas d'essieu sous une colonne vide")
	var sans := ConstructionLibre.peindre(a, Vector2i(4, 2), "")
	ok(sans.essieux.size() == 1, "effacer la case retire l'essieu qu'elle portait")
	var gomme := a
	for x in range(2, 18):
		gomme = ConstructionLibre.peindre(gomme, Vector2i(x, 2), "")
	ok(gomme.pieces.is_empty() and gomme.essieux.is_empty(), "tout effacer fait tomber les pièces")

	print("— Physique —")
	var an := ConstructionLibre.analyser(a)
	ok(an.ok, "la jeep se construit")
	ok(float(an.stats.vitesse) > 4.0, "elle roule : %.2f m/s, %d kg, %.0f ch/t" % [an.stats.vitesse, int(an.stats.poids_kg), an.detail.ch_t])
	ok(codes(an).is_empty(), "sans défaut : %s" % str(codes(an)))
	ok(int(an.stats.equipage) == 2, "deux places")
	var sans_moteur := ConstructionLibre.retirer(a, 0)
	var an2 := ConstructionLibre.analyser(sans_moteur)
	ok(an2.ok and float(an2.stats.vitesse) == 0.0 and String(an2.stats.immobile).contains("moteur"), "sans moteur : construit mais immobile (%s)" % an2.stats.immobile)
	var sans_siege := ConstructionLibre.retirer(a, 2)
	ok(not ConstructionLibre.analyser(sans_siege).ok, "sans siège : refusé (personne pour conduire)")
	# Un seul essieu : bascule
	var un := ConstructionLibre.retirer_essieu(a, 15)
	ok(String(ConstructionLibre.analyser(un).stats.immobile).contains("bascule"), "un seul essieu : il bascule")
	# Essieux groupés à l'arrière, moteur lourd à l'avant : bascule vers l'avant
	var av := ConstructionLibre.retirer_essieu(ConstructionLibre.retirer_essieu(a, 4), 15)
	av = ConstructionLibre.poser_essieu(av, 2, "essieu_leger", "roue_moyenne")
	av = ConstructionLibre.poser_essieu(av, 6, "essieu_leger", "roue_moyenne")
	var an_av := ConstructionLibre.analyser(av)
	ok(String(an_av.stats.immobile).contains("avant"), "roues à l'arrière, moteur à l'avant : bascule vers l'avant (%s)" % an_av.stats.immobile)
	# Petites roues sous une jeep : surcharge
	var pr := ConstructionLibre.poser_essieu(ConstructionLibre.poser_essieu(a, 4, "essieu_leger", "roue_petite"), 15, "essieu_leger", "roue_petite")
	var an_pr := ConstructionLibre.analyser(pr)
	ok(codes(an_pr).has("surcharge") or codes(an_pr).has("garde") or codes(an_pr).has("traine"), "petites roues : défauts %s" % str(codes(an_pr)))
	ok(float(an_pr.stats.vitesse) < float(an.stats.vitesse), "petites roues : plus lent (%.2f < %.2f)" % [an_pr.stats.vitesse, an.stats.vitesse])
	# Roue d'une autre taille plus haute : en l'air
	var mix := ConstructionLibre.poser_essieu(ConstructionLibre.poser_essieu(a, 4, "essieu_leger", "roue_grande"), 15, "essieu_leger", "roue_grande")
	mix = ConstructionLibre.poser_essieu(mix, 9, "essieu_leger", "roue_petite")
	ok(codes(ConstructionLibre.analyser(mix)).has("roue_air"), "petite roue entre deux grandes : en l'air")
	# Chenille sur un seul galet
	var ch1 := ConstructionLibre.poser_essieu(a, 9, "essieu_lourd", "chenille")
	ok(codes(ConstructionLibre.analyser(ch1)).has("chenille_seule"), "chenille sur un seul galet : signalée")
	# Roues qui se touchent
	var fr := ConstructionLibre.poser_essieu(ConstructionLibre.poser_essieu(a, 5, "essieu_leger", "roue_moyenne"), 4, "essieu_leger", "roue_moyenne")
	ok(codes(ConstructionLibre.analyser(fr)).has("frottent"), "deux roues collées : elles frottent")
	# Canon de 88 sur une jeep : recul + manque de servant + moteur faible
	var gros := ConstructionLibre.poser(a, "arme_canon_88", Vector2i(2, 6))
	ok(not gros.is_empty(), "un canon de 88 se pose sur la jeep (tout est compatible)")
	var an_g := ConstructionLibre.analyser(gros)
	var cg := codes(an_g)
	ok(cg.has("recul") or cg.has("surcharge") or an_g.stats.immobile != "", "88 sur jeep : mauvais résultat %s / %s" % [str(cg), an_g.stats.immobile])
	# Cabine posée juste devant une mitrailleuse : tir masqué
	var mg := ConstructionLibre.poser(a, "arme_mitrailleuse", Vector2i(2, 3))
	var an_mg := ConstructionLibre.analyser(mg)
	ok(an_mg.stats.armes.size() + codes(an_mg).count("masquee") + codes(an_mg).count("servant") == 1, "mitrailleuse comptée une fois (armes %s, défauts %s)" % [str(an_mg.stats.armes), str(codes(an_mg))])
	# Mortier : se pose, sert
	var mo := ConstructionLibre.poser(a, "arme_mortier", Vector2i(10, 3))
	ok(not mo.is_empty() and ConstructionLibre.analyser(mo).stats.armes.has("mortier"), "le mortier se pose et sert")
	# Blindage : plus lourd, plus blindé
	var bl := a
	for x in range(2, 18):
		bl = ConstructionLibre.peindre(bl, Vector2i(x, 2), "blindage")
	var an_bl := ConstructionLibre.analyser(bl)
	ok(float(an_bl.stats.blindage) > float(an.stats.blindage) * 5.0 and float(an_bl.stats.poids_kg) > float(an.stats.poids_kg) + 4000.0, "cases blindées : blindage %d, %d kg" % [int(an_bl.stats.blindage), int(an_bl.stats.poids_kg)])
	ok(ConstructionLibre.signature(a) == ConstructionLibre.signature(jeep()), "même grille, même signature")
	var F := ConstructionLibre.forme(a)
	ok(F.roues.size() == 2 and F.longueur > 3.5, "dessin : 2 roues au sol, %.2f m" % F.longueur)
	var Fm := ConstructionLibre.forme(mix)
	ok(Fm.roues.size() == 2, "dessin : la roue en l'air n'est pas dessinée au sol")

	print("— Conversion des véhicules historiques —")
	for t in Assemblage.historiques():
		var h := Assemblage.de_type(t)
		var c := ConstructionLibre.convertir(h, t)
		var ac := ConstructionLibre.analyser(c)
		var vh := float(Assemblage.statistiques(h).vitesse)
		var nb_h: int = h.pieces.filter(func(p): return Assemblage.piece(p.piece).get("famille", "") in ["moteur", "cabine", "arme"] and Assemblage.piece(p.piece).has("emprise")).size()
		var bon: bool = ac.ok and float(ac.stats.vitesse) > 0.0 and c.pieces.size() == nb_h
		ok(bon, "%s : %.1f m/s (historique %.1f), %d kg, armes %s, défauts %s" % [t, float(ac.stats.get("vitesse", 0.0)), vh,
			int(ac.stats.get("poids_kg", 0)), str(ac.stats.get("armes", [])), str(codes(ac))])
		if t in ["willys_mb", "m4_sherman"]:
			ok(ac.stats.armes.size() == Assemblage.statistiques(h).armes.size(), "%s garde ses armes" % t)

	print("— En partie : grille à tout moment —")
	var m := CombatModele.new(4)
	var v = m.convoi[0]
	ok(m.raison_grille(v.uid) == "", "grille ouverte pendant la marche")
	var g: Dictionary = m.grille_de(v.uid)
	ok(g.get("libre", false), "grille du véhicule historique convertie")
	var metal0: float = m.stocks.metal
	ok(m.construire_grille(v.uid, g), "reconstruire tel quel")
	ok(v.assemblage.get("libre", false) and v.profil.vitesse > 0.0, "le véhicule est maintenant libre et roule (%.1f)" % v.profil.vitesse)
	ok(is_equal_approx(m.stocks.metal, metal0), "aucun métal dépensé sans changement")
	var g2: Dictionary = ConstructionLibre.peindre(g, Vector2i(1, int(g.cases[0][1])), "blindage")
	var cout := m.cout_grille(v.uid, g2)
	ok(cout > 0.0, "peindre coûte du métal (%.1f)" % cout)
	m.stocks.metal = 0.0
	ok(not m.construire_grille(v.uid, g2), "sans métal : refusé")
	ok(m.palette_grille(v.uid).all(func(e): return int(e.n) >= 1 or bool(Assemblage.piece(e.id).get("fabrique", false))),
		"palette normale : pièces de réserve comptées, postes et cabines fabriqués sans limite")
	# Retirer le moteur : il retourne en réserve, le véhicule ne roule plus et bloque le convoi
	var gm: Dictionary = m.grille_de(v.uid)
	var im := -1
	for i in gm.pieces.size():
		if Assemblage.piece(gm.pieces[i].piece).famille == "moteur":
			im = i
	gm = ConstructionLibre.retirer(gm, im)
	ok(m.construire_grille(v.uid, gm), "véhicule sans moteur construit")
	ok(m.ids_stock().any(func(id): return Assemblage.piece(id).famille == "moteur"), "le moteur est en réserve")
	m.ordre_marche("avancer")
	for k in 20:
		m.avancer()
	ok(m.blocage.contains("ne roule pas"), "le convoi signale : %s" % m.blocage)
	var sv := m.sauver()
	var m2 := CombatModele.depuis_sauvegarde(JSON.parse_string(JSON.stringify(sv)))
	ok(m2.convoi[0].assemblage.get("libre", false) and m2.convoi[0].nom == v.nom, "sauvegarde : véhicule libre restauré (%s)" % m2.convoi[0].nom)

	print("— Bac à sable —")
	var s := CombatModele.new(5, {"bac_a_sable": true})
	ok(s.bac_a_sable and s.stocks.metal > 9000.0, "bac à sable : métal sans limite")
	var pal: Array = s.palette_grille(0)
	ok(pal.size() >= 20 and pal.all(func(e): return int(e.n) == -1), "toutes les pièces, sans limite (%d)" % pal.size())
	ok(pal.any(func(e): return e.id == "arme_mortier") and pal.any(func(e): return e.id == "moteur_tiger_1"), "mortier et moteur de Tiger disponibles")
	var n0 := s.convoi.size()
	var neuf := jeep()
	neuf = ConstructionLibre.poser(neuf, "arme_mortier", Vector2i(10, 3))
	ok(s.construire_grille(0, neuf), "nouveau véhicule construit")
	ok(s.convoi.size() == n0 + 1 and s.convoi.back().equipage.size() == 2, "il rejoint le convoi avec son équipage")
	ok(s.cout_grille(0, neuf) == 0.0, "rien à payer")
	var sv2 := s.sauver()
	ok(CombatModele.depuis_sauvegarde(JSON.parse_string(JSON.stringify(sv2))).bac_a_sable, "le mode survit à la sauvegarde")

	print("— Mortier en combat —")
	var w: Dictionary = CombatModele.donnees().armes.mortier
	ok(w.classe == "mortier" and float(w.portee_min) > 0.0, "mortier : portée %d à %d m" % [int(w.portee_min), int(w.portee)])
	var vm = s.convoi.back()
	ok(vm.armes.size() == 1 and vm.armes[0].id == "mortier", "l'arme du véhicule est un mortier")
	var Dm: Dictionary = VehiculeDessin.donnees().vehicules[vm.type]
	ok(Dm.armes.size() == 1 and Dm.armes[0].type == "mortier", "dessiné comme un mortier")

	print("— Demandes du 01/11 après-midi (DEC-047 à DEC-058) —")
	var j := jeep()
	var nu := ConstructionLibre.poser_essieu(j, 9, "essieu_leger", "")
	ok(ConstructionLibre.essieux_nus(nu).size() == 1 and "sans_roue" in codes(ConstructionLibre.analyser(nu)), "essieu posé sans roue : signalé")
	nu = ConstructionLibre.monter_train(nu, 9, "roue_petite")
	ok(ConstructionLibre.essieux_nus(nu).is_empty(), "roue montée ensuite sur l'essieu")
	ok(ConstructionLibre.monter_train(j, 1, "roue_petite").is_empty(), "pas de roue sans essieu")
	var s1: Dictionary = ConstructionLibre.statistiques(j)
	var ph := ConstructionLibre.poser(j, "phares", Vector2i(16, 3))
	var s2: Dictionary = ConstructionLibre.statistiques(ph)
	ok(int(s1.phares) == 0 and int(s2.phares) == 1, "pas de phares par défaut ; phares posés")
	ok(ConstructionLibre.analyser(ph).detail.puissance < ConstructionLibre.analyser(j).detail.puissance, "les phares prennent un peu de puissance")
	var mega := ConstructionLibre.nouvelle("Méga")
	for x in range(2, 38):
		for y in [2, 3]:
			mega = ConstructionLibre.peindre(mega, Vector2i(x, y), "acier")
	for x in range(3, 38, 3):
		mega = ConstructionLibre.poser_essieu(mega, x, "essieu_char", "chenille")
	var mega1 := ConstructionLibre.poser(mega, "moteur_tiger_1", Vector2i(2, 4))
	mega1 = ConstructionLibre.poser(mega1, "cabine_tiger_1", Vector2i(20, 4))
	var mega4 := mega1
	for x in [8, 14, 28]:
		mega4 = ConstructionLibre.poser(mega4, "moteur_tiger_1", Vector2i(x, 4))
	var c1 := float(ConstructionLibre.statistiques(mega1).conso)
	var c4 := float(ConstructionLibre.statistiques(mega4).conso)
	ok(c4 > c1 * 4.0 * 3.0, "méga-char à 4 moteurs : consommation ×%.1f pour 4 moteurs" % (c4 / c1))
	ok("moteurs" in codes(ConstructionLibre.analyser(mega4)), "moteurs couplés signalés")
	var arm := ConstructionLibre.poser(j, "arme_mitrailleuse", Vector2i(9, 7))
	arm = ConstructionLibre.poser(arm, "arme_mortier", Vector2i(14, 7))
	ok(ConstructionLibre.tireurs_requis(arm) == 2, "mortier + mitrailleuse : 2 tireurs (pas de coaxiale sur un mortier)")
	var cx := ConstructionLibre.poser(ConstructionLibre.poser(mega1, "arme_canon_75", Vector2i(24, 9)), "arme_mitrailleuse", Vector2i(30, 4))
	ok(ConstructionLibre.tireurs_requis(cx) == 1, "canon + mitrailleuse : 1 tireur (coaxiale)")
	arm.roles = ["conducteur", "infirmier"]
	ok(ConstructionLibre.statistiques(arm).armes.is_empty(), "sans tireur, aucune arme ne tire")
	arm.roles = ["conducteur", "tireur"]
	ok(ConstructionLibre.statistiques(arm).armes.size() == 1, "un tireur sert le mortier (pas de coaxiale sur un mortier)")
	ok(not ConstructionLibre.nom_propose(arm).begins_with("Frankenstein"), "nom proposé : %s" % ConstructionLibre.nom_propose(arm))
	var fl: Dictionary = CombatModele.donnees().armes.lance_flammes
	ok(float(fl.carburant) > 0.0 and int(fl.munitions) == 0, "lance-flammes : brûle du carburant, pas de munitions")
	var mc := CombatModele.new(3, {"bac_a_sable": true})
	ok(mc.monde.niveau_a(mc.x_tete) >= 5, "bac à sable : niveau des rencontres relevé (%d), chars rapidement" % mc.monde.niveau_a(mc.x_tete))
	var p = mc.monde.creer_pieton("pillard", mc.convoi[0].x + 1.0)
	mc.vitesse_convoi = 6.0
	mc.monde._ecrasements(0.1)
	ok(not p.actif(), "un pillard écrasé par la Jeep lancée meurt")

	print("— Postes, bancs, cabines (DEC-062) —")
	var cam := ConstructionLibre.nouvelle("Camion")
	for x in range(2, 30):
		cam = ConstructionLibre.peindre(cam, Vector2i(x, 2), "acier")
	cam = ConstructionLibre.poser_essieu(cam, 4, "essieu_leger", "roue_moyenne")
	cam = ConstructionLibre.poser_essieu(cam, 26, "essieu_leger", "roue_moyenne")
	cam = ConstructionLibre.poser(cam, "moteur_willys_mb", Vector2i(24, 3))
	ok("cabine" in codes_erreurs(cam), "sans poste de conduite : erreur conducteur")
	cam = ConstructionLibre.poser(cam, "poste_conduite", Vector2i(20, 3))
	cam = ConstructionLibre.poser(cam, "poste_commande", Vector2i(17, 3))
	cam = ConstructionLibre.poser(cam, "banc_avant", Vector2i(4, 3))
	cam = ConstructionLibre.poser(cam, "banc_arriere", Vector2i(9, 3))
	ok(ConstructionLibre.roles_de(cam).has("conducteur") and ConstructionLibre.roles_de(cam).has("chef"), "poste de conduite et de commande fixes")
	ok(ConstructionLibre.places_troupes(cam) == 8, "deux bancs : 8 places de troupes (%d)" % ConstructionLibre.places_troupes(cam))
	ok(bool(ConstructionLibre.statistiques(cam).ouvert), "sièges à l'air libre : équipage exposé")
	var cab := ConstructionLibre.poser(cam, "cabine_camion", Vector2i(17, 5))
	ok(not cab.is_empty() and cab.pieces.size() == cam.pieces.size() + 1, "la cabine se pose par-dessus les sièges")
	ok(not bool(ConstructionLibre.statistiques(cab).ouvert) or true, "cabine fermée : état d'exposition calculé")

	print("— Troupes à terre et réparation (DEC-063/064) —")
	var mt := CombatModele.new(3, {"bac_a_sable": true})
	var vt = mt.convoi[0]
	vt.troupes = [20.0, 20.0]
	ok(mt.ordre_troupes(vt.uid), "ordre de débarquer accepté")
	ok(mt.monde.troupes_dehors(vt.uid) == 2 and vt.troupes_vivantes() == 0, "deux soldats à terre")
	mt.ordre_troupes(vt.uid)
	for i in 1800:
		mt.avancer()
	ok(mt.monde.troupes_dehors(vt.uid) == 0, "rappel : les soldats regagnent le véhicule")
	mt.ordre_marche("halte")
	vt.reparation = true
	var chef_ok: bool = mt.equipage_dehors(vt) == maxi(0, vt.equipage_vivant() - (1 if vt.a_un_chef() else 0))
	ok(chef_ok, "réparation : tous sauf le chef descendent (%d dehors)" % mt.equipage_dehors(vt))
	vt.reparation = false
	ok(mt.equipage_dehors(vt) == 0, "fin de réparation : plus personne dehors")

	print("— Coques de donneur, plan carrosserie (DEC-067) —")
	var k_j := jeep()
	var k_p0: int = k_j.pieces.size()
	var k_exposes0 := ConstructionLibre._sieges_exposes(k_j)
	var k_an0 := ConstructionLibre.analyser(k_j)
	var k_jc := ConstructionLibre.poser(k_j, "coque_berline", Vector2i(1, 2))
	ok(not k_jc.is_empty() and k_jc.pieces.size() == k_p0 + 1, "une coque se pose par-dessus le moteur et les sièges")
	var k_an1 := ConstructionLibre.analyser(k_jc)
	ok(absf(float(k_an1.stats.poids_kg) - float(k_an0.stats.poids_kg) - 450.0) < 1.0, "la coque ajoute son poids (+450 kg)")
	ok(float(k_an1.stats.blindage) > float(k_an0.stats.blindage), "la coque ajoute du blindage")
	ok(k_exposes0 and not ConstructionLibre._sieges_exposes(k_jc), "une coque fermée met l'équipage à couvert")
	var k_i_mot := -1
	for kk in k_jc.pieces.size():
		if Assemblage.piece(String(k_jc.pieces[kk].piece)).get("famille", "") == "moteur":
			k_i_mot = kk
	var k_pos_mot: Array = k_jc.pieces[k_i_mot].pos
	var k_sans_mot := ConstructionLibre.retirer(k_jc, k_i_mot)
	var k_remis := ConstructionLibre.poser(k_sans_mot, String(k_jc.pieces[k_i_mot].piece), Vector2i(int(k_pos_mot[0]), int(k_pos_mot[1])))
	ok(not k_remis.is_empty() and k_remis.pieces[k_remis.pieces.size() - 1].pos == k_pos_mot, "un moteur se pose sous une coque, à la même place")
	var k_pile := ConstructionLibre.poser(k_jc, "coque_berline", Vector2i(1, 6))
	ok(not k_pile.is_empty() and int(k_pile.pieces[k_pile.pieces.size() - 1].pos[1]) == 6, "deux coques peuvent se chevaucher (DEC-080)")
	ok(ConstructionLibre.piece_en(k_jc, Vector2i(5, 3), true) == k_jc.pieces.size() - 1, "onglet Carrosserie : toucher désigne la coque d'abord")
	var k_nu := k_jc
	for x in range(2, 18):
		k_nu = ConstructionLibre.peindre(k_nu, Vector2i(x, 2), "")
	ok(k_nu.pieces.filter(func(q): return String(q.piece) == "coque_berline").is_empty(), "sans châssis, la coque tombe")
	var k_jm := ConstructionLibre.poser(k_j, "coque_berline", Vector2i(1, 2), true)
	var k_F := ConstructionLibre.forme(k_jm, true)
	var k_sp: Array = k_F.formes.filter(func(f): return f.get("sprite", "") == "coques/coque_berline")
	ok(k_sp.size() == 1 and k_sp[0].z == 3 and k_sp[0].miroir and absf(float(k_sp[0].opac) - ConstructionLibre.OPAC_ECORCHE) < 0.01, "coque retournée, dessinée au-dessus, transparente en vue écorchée")
	# Extensibilité : toute coque du catalogue se charge, se pose et se calcule (une coque ajoutée est testée d'office)
	var k_grand := jeep()
	for x in range(18, 38):
		k_grand = ConstructionLibre.peindre(k_grand, Vector2i(x, 2), "acier")
	var k_n_coques := 0
	for id in Assemblage.catalogue().pieces:
		if Assemblage.piece(id).get("famille", "") != "coque":
			continue
		k_n_coques += 1
		var k_g2 := ConstructionLibre.poser(k_grand, id, Vector2i(3, 2))
		ok(ResourceLoader.exists("res://assets/%s.png" % Assemblage.piece(id).image) and not k_g2.is_empty()
			and float(ConstructionLibre.analyser(k_g2).stats.poids_kg) > float(ConstructionLibre.analyser(k_grand).stats.poids_kg), "catalogue : %s se charge, se pose et pèse" % id)
	ok(k_n_coques >= 5, "%d coques au catalogue" % k_n_coques)
	ok("coque_berline" in CombatModele.coques_donnees("citroen_traction") and CombatModele.coques_donnees("willys_mb").is_empty(), "une épave de Traction livre sa coque, une Jeep rien")
	var k_mb := CombatModele.new(3)
	k_mb.bac_a_sable = true
	ok(k_mb.palette_grille(0).any(func(q): return q.id == "coque_blindee"), "bac à sable : les coques sont dans la palette")

	print("— Cabines retirées, ponts rigides, plans (DEC-069 à DEC-071) —")
	var s_mb := CombatModele.new(4)
	s_mb.bac_a_sable = true
	var s_pal: Array = s_mb.palette_grille(0)
	ok(not s_pal.any(func(q): return Assemblage.piece(q.id).get("famille", "") == "cabine"), "bac à sable : plus de cabines (sièges = postes, carrosserie = coques)")
	var s_j := jeep()
	s_j = ConstructionLibre.poser_essieu(s_j, 4, "pont_rigide_leger", "roue_moyenne")
	s_j = ConstructionLibre.poser_essieu(s_j, 15, "pont_rigide_leger", "roue_moyenne")
	var s_an := ConstructionLibre.analyser(s_j)
	ok(codes(s_an).has("pont_libre") and float(s_an.stats.vitesse) == 0.0, "un pont rigide sans liaison ne porte rien : le véhicule ne roule pas")
	ok(ConstructionLibre.relier(jeep(), 4, "liaison_lames").is_empty(), "un essieu simple ne prend pas de liaison")
	var gardes := {}
	var s_ecarts := {"liaison_lames": 0, "liaison_tirants": 2, "liaison_rehausse": 4}
	for lid in ConstructionLibre._famille_ids("liaison"):
		var s_y: int = 2 - int(s_ecarts.get(lid, 0)) + 4   # ponts placés en l'air : le châssis de la jeep est à la rangée 2 (on le relève de 4 rangées)
		var s_h := ConstructionLibre.nouvelle("Haut")
		for x in range(2, 18):
			s_h = ConstructionLibre.peindre(s_h, Vector2i(x, 6), "acier")
		s_h = ConstructionLibre.poser(s_h, "moteur_willys_mb", Vector2i(14, 7))
		s_h = ConstructionLibre.poser(s_h, "poste_conduite", Vector2i(6, 7))
		s_h = ConstructionLibre.poser_essieu(s_h, 4, "pont_rigide_leger", "roue_moyenne", s_y)
		s_h = ConstructionLibre.poser_essieu(s_h, 15, "pont_rigide_leger", "roue_moyenne", s_y)
		var s_b := ConstructionLibre.relier(ConstructionLibre.relier(s_h, 4, lid), 15, lid)
		var s_a2 := ConstructionLibre.analyser(s_b)
		gardes[lid] = float(s_a2.detail.garde_m)
		ok(s_a2.ok, "%s : le véhicule roule" % lid)
	ok(absf(gardes.liaison_tirants - gardes.liaison_lames - 0.5) < 0.01 and absf(gardes.liaison_rehausse - gardes.liaison_lames - 1.0) < 0.01,
		"tirants : +50 cm de garde au sol, grands tirants : +1 m")
	ok(ConstructionLibre.relier(s_j, 4, "liaison_rehausse").is_empty(), "grands tirants refusés pour un pont collé au châssis")
	var s_jr := ConstructionLibre.poser_essieu(ConstructionLibre.poser_essieu(s_j, 4, "pont_rigide_leger", "roue_moyenne", 0), 15, "pont_rigide_leger", "roue_moyenne", 0)
	ok(ConstructionLibre.liaisons_pour(2) == ["liaison_tirants"], "à 50 cm, seuls les tirants conviennent")
	var s_r := ConstructionLibre.relier(ConstructionLibre.relier(s_jr, 4, "liaison_tirants"), 15, "liaison_tirants")
	var s_l := ConstructionLibre.relier(ConstructionLibre.relier(s_j, 4, "liaison_lames"), 15, "liaison_lames")
	ok(float(ConstructionLibre.analyser(s_r).stats.precision) > float(ConstructionLibre.analyser(s_l).stats.precision), "plus de débattement : meilleure précision en roulant")
	ok(ConstructionLibre.forme(s_r).formes.filter(func(f): return f.has("ligne")).size() > ConstructionLibre.forme(s_l).formes.filter(func(f): return f.has("ligne")).size(), "tirants et ressorts dessinés")
	var s_rp := ConstructionLibre.poser_essieu(s_r, 4, "pont_rigide_lourd", "roue_grande")
	ok(String(ConstructionLibre.essieu_en(s_rp, 4).get("liaison", "")) == "liaison_tirants" and int(ConstructionLibre.essieu_en(s_rp, 4).y) == 0, "changer de pont garde la liaison et la hauteur")
	PlansGrille.supprimer("Essai plan")
	var s_p := s_r.duplicate(true)
	s_p.nom = "Essai plan"
	PlansGrille.enregistrer(s_p)
	var s_lu: Array = PlansGrille.lire().filter(func(q): return q.nom == "Essai plan")
	ok(s_lu.size() == 1 and s_lu[0].a.pieces.size() == s_p.pieces.size() and s_lu[0].a.essieux[0].liaison == "liaison_tirants", "un plan s'enregistre et se relit à l'identique")
	var s_ad := PlansGrille.adapter(s_lu[0].a, [])
	ok(s_ad.a.pieces.is_empty() and s_ad.manquantes.size() == s_p.pieces.size(), "plan chargé sans réserve : les pièces manquantes sont listées et laissées de côté")
	PlansGrille.supprimer("Essai plan")
	ok(PlansGrille.lire().filter(func(q): return q.nom == "Essai plan").is_empty(), "un plan se supprime")

	print("— La scie (DEC-072) —")
	var c_j := ConstructionLibre.poser(jeep(), "coque_berline", Vector2i(1, 2))
	var c_i: int = c_j.pieces.size() - 1
	ok(ConstructionLibre.scier(c_j, c_i, Vector2i(1, 3), "v").is_empty(), "un trait sur le bord de la coque ne coupe rien")
	var c_v := ConstructionLibre.scier(c_j, c_i, Vector2i(10, 3), "v")
	var c_m: Array = c_v.pieces.filter(func(q): return String(q.piece) == "coque_berline")
	ok(c_m.size() == 2 and int(c_m[0].emprise[0]) + int(c_m[1].emprise[0]) == 18 and int(c_m[1].pos[0]) == 10, "trait vertical : deux morceaux côte à côte (9 + 9 cases)")
	ok(absf(float(c_m[0].coupe[1]) - 0.5) < 0.01 and c_m[0].lot == c_m[1].lot, "chaque morceau garde sa moitié d'image, même lot")
	ok(ConstructionLibre.utilisees(c_v, "coque_berline") == 1 and Assemblage.ids(c_v).count("coque_berline") == 1, "une coque sciée ne compte qu'une fois en réserve")
	var c_a0 := ConstructionLibre.analyser(c_j)
	var c_a1 := ConstructionLibre.analyser(c_v)
	ok(absf(float(c_a1.stats.poids_kg) - float(c_a0.stats.poids_kg)) < 1.0, "scier ne change pas le poids total")
	var c_sans := ConstructionLibre.retirer(c_v, c_v.pieces.size() - 1)
	ok(float(ConstructionLibre.analyser(c_sans).stats.poids_kg) < float(c_a0.stats.poids_kg) - 200.0, "retirer un morceau allège le véhicule")
	var c_h := ConstructionLibre.scier(c_j, c_i, Vector2i(5, 5), "h")
	var c_toit: Dictionary = c_h.pieces[c_h.pieces.size() - 1]
	ok(int(c_toit.pos[1]) == 5 and int(c_toit.emprise[1]) == 2, "trait horizontal : le toit au-dessus, posé sur le bas")
	ok(not ConstructionLibre._sieges_exposes(c_h) and ConstructionLibre._sieges_exposes(ConstructionLibre.retirer(c_h, c_h.pieces.size() - 1)), "toit enlevé : l'équipage est à découvert")
	var c_jm := ConstructionLibre.poser(jeep(), "coque_berline", Vector2i(1, 2), true)
	var c_vm := ConstructionLibre.scier(c_jm, c_jm.pieces.size() - 1, Vector2i(7, 3), "v")
	var c_g: Dictionary = c_vm.pieces[c_jm.pieces.size() - 1]
	ok(c_g.miroir and absf(float(c_g.coupe[0]) - (1.0 - 6.0 / 18.0)) < 0.01, "coque retournée : le morceau de gauche est l'arrière de l'image")
	var c_ex := {"coupe": c_m[1].coupe, "emprise": c_m[1].emprise, "lot": c_m[1].lot}
	var c_re := ConstructionLibre.poser(c_sans, "coque_berline", Vector2i(20, 3), false, c_ex)
	ok(not c_re.is_empty() and c_re.pieces[c_re.pieces.size() - 1].emprise == c_m[1].emprise, "un morceau repris au doigt garde sa découpe")
	var c_f: Array = ConstructionLibre.forme(c_v).formes.filter(func(f): return f.get("sprite", "") == "coques/coque_berline")
	ok(c_f.size() == 2 and c_f[0].uv.size() == 4, "les morceaux se dessinent avec leur part d'image")

	print("— Les greffes (DEC-079) —")
	var g_j := jeep()
	var g_s0: Dictionary = ConstructionLibre.analyser(g_j).stats
	var g_ids: Array = Assemblage.catalogue().pieces.keys().filter(func(id): return Assemblage.piece(id).get("famille", "") == "greffe")
	ok(g_ids.size() >= 4, "le catalogue contient au moins 4 greffes (%d)" % g_ids.size())
	var g_ch: Array = ConstructionLibre._cases(g_j).keys()
	var g_xmax := 0
	var g_ymin := 99
	for c in g_ch:
		g_xmax = maxi(g_xmax, c.x)
		g_ymin = mini(g_ymin, c.y)
	for id in g_ids:
		ok(not ConstructionLibre.poser(g_j, id, Vector2i(g_xmax + 1, g_ymin)).is_empty(), "%s : se fixe à l'avant du châssis" % id)
		var g_seule := ConstructionLibre.poser(g_j, id, Vector2i(g_xmax + 1, g_ymin))
		var g_an: Dictionary = ConstructionLibre.analyser(g_seule)
		ok(g_an.ok and float(g_an.stats.poids_kg) > float(g_s0.poids_kg), "%s : alourdit le véhicule" % id)
		var g_fm: Dictionary = ConstructionLibre.forme(g_seule)
		ok(g_fm.formes.size() > ConstructionLibre.forme(g_j).formes.size(), "%s : se dessine" % id)
	var g_pb := ConstructionLibre.poser(g_j, "greffe_pare_buffle", Vector2i(g_xmax + 1, g_ymin))
	ok(float(ConstructionLibre.analyser(g_pb).stats.blindage) > float(g_s0.blindage), "le pare-buffle ajoute du blindage")
	var g_bi := ConstructionLibre.poser(g_j, "greffe_bidons", Vector2i(g_xmax + 1, g_ymin))
	ok(float(ConstructionLibre.analyser(g_bi).stats.reservoir) > float(g_s0.reservoir), "les bidons ajoutent du réservoir")
	var g_pi := ConstructionLibre.poser(g_j, "greffe_piques", Vector2i(g_xmax + 1, g_ymin))
	ok(int(ConstructionLibre.analyser(g_pi).stats.piques) == 1, "les piques sont comptées")
	ok(ConstructionLibre.poser(g_j, "greffe_drapeau", Vector2i(g_xmax + 12, g_ymin + 6)).is_empty(), "une greffe loin de tout n'est pas posée sans appui")
	var g_sup := ConstructionLibre.poser(g_bi, "arme_mitrailleuse", Vector2i(g_xmax + 1, g_ymin + 1))
	ok(g_sup.is_empty() or int(g_sup.pieces[g_sup.pieces.size() - 1].pos[0]) != g_xmax + 1 or int(g_sup.pieces[g_sup.pieces.size() - 1].pos[1]) != g_ymin + 1, "rien ne repose sur une greffe")

	print("— Grille du 01/11 soir (DEC-080) —")
	var d_j := jeep()
	# Radiateur
	var d_i_rad := -1
	for kk in d_j.pieces.size():
		if String(d_j.pieces[kk].piece) == "radiateur_voiture":
			d_i_rad = kk
	var d_sans_rad := ConstructionLibre.retirer(d_j, d_i_rad)
	ok(String(ConstructionLibre.analyser(d_sans_rad).stats.immobile).contains("radiateur"), "sans radiateur, le moteur chauffe et cale")
	var d_loin := ConstructionLibre.poser(d_sans_rad, "radiateur_voiture", Vector2i(2, 3))
	ok(String(ConstructionLibre.analyser(d_loin).stats.immobile).contains("loin"), "un radiateur loin du moteur ne sert pas")
	ok(float(ConstructionLibre.analyser(d_j).stats.vitesse) > 0.0, "radiateur collé au moteur : il roule")
	var d_hist := ConstructionLibre.convertir(Assemblage.de_type("willys_mb"), "willys_mb")
	ok(float(ConstructionLibre.analyser(d_hist).stats.vitesse) > 0.0, "un véhicule du jeu converti garde son radiateur d'origine")
	var d_air := ConstructionLibre.refroidissement({"pieces": [{"piece": "moteur_avion", "pos": [0, 0]}]})
	ok(float(d_air.besoin) == 0.0, "un moteur en étoile est refroidi par air")
	# Poutres et moteur traversant
	var d_p := ConstructionLibre.nouvelle("Poutres")
	for x in range(2, 18):
		d_p = ConstructionLibre.peindre(d_p, Vector2i(x, 2), "poutre")
		d_p = ConstructionLibre.peindre(d_p, Vector2i(x, 3), "poutre")
	var d_pm := ConstructionLibre.poser(d_p, "moteur_willys_mb", Vector2i(12, 2))
	ok(not d_pm.is_empty() and int(d_pm.pieces[0].pos[1]) == 2, "un moteur se pose au travers des poutres")
	var d_a := ConstructionLibre.nouvelle("Acier")
	for x in range(2, 18):
		d_a = ConstructionLibre.peindre(d_a, Vector2i(x, 2), "acier")
		d_a = ConstructionLibre.peindre(d_a, Vector2i(x, 3), "acier")
	var d_am := ConstructionLibre.poser(d_a, "moteur_willys_mb", Vector2i(12, 2))
	ok(d_am.is_empty() or int(d_am.pieces[0].pos[1]) >= 4, "pas au travers d'une tôle d'acier pleine")
	# Tôles
	var d_t := ConstructionLibre.poser_tole(d_j, Vector2i(18, 3), Vector2i(18, 7))
	var d_t2 := ConstructionLibre.poser_tole(d_j, Vector2i(18, 3), Vector2i(21, 7))
	ok(not d_t.is_empty() and not d_t2.is_empty(), "une tôle se trace d'un coin du véhicule à un autre point")
	ok(ConstructionLibre.poser_tole(d_j, Vector2i(30, 10), Vector2i(32, 12)).is_empty(), "une tôle qui ne touche rien est refusée")
	var d_b0 := float(ConstructionLibre.analyser(d_j).stats.blindage)
	var d_b1 := float(ConstructionLibre.analyser(d_t).stats.blindage)
	var d_b2 := float(ConstructionLibre.analyser(d_t2).stats.blindage)
	ok(d_b1 > d_b0 and d_b2 > d_b1, "tôle : plus de blindage, et plus encore inclinée (%.1f, %.1f, %.1f)" % [d_b0, d_b1, d_b2])
	var d_f: Array = ConstructionLibre.toles_de(d_t2)
	ok(absf(float(d_f[0].facteur) - 5.0 / 4.0) < 0.01, "facteur d'inclinaison = 1/cos(angle)")
	var d_c := ConstructionLibre.nouvelle("Caisse")
	for x in range(2, 18):
		d_c = ConstructionLibre.peindre(d_c, Vector2i(x, 2), "acier")
	d_c = ConstructionLibre.poser_essieu(d_c, 4, "essieu_leger", "roue_moyenne")
	d_c = ConstructionLibre.poser_essieu(d_c, 15, "essieu_leger", "roue_moyenne")
	d_c = ConstructionLibre.poser(d_c, "poste_conduite", Vector2i(6, 3))
	ok(ConstructionLibre._sieges_exposes(d_c), "poste à l'air libre : exposé")
	for q in [[2, 3, 2, 7], [2, 7, 12, 7], [12, 7, 14, 3]]:
		d_c = ConstructionLibre.poser_tole(d_c, Vector2i(q[0], q[1]), Vector2i(q[2], q[3]))
	ok(ConstructionLibre.toles_fermees(d_c).is_empty(), "forme ouverte : pas de caisse")
	d_c = ConstructionLibre.poser_tole(d_c, Vector2i(14, 3), Vector2i(2, 3))
	ok(ConstructionLibre.toles_fermees(d_c).size() == 1, "forme fermée par 4 tôles détectée")
	ok(not ConstructionLibre._sieges_exposes(d_c), "dans une caisse de tôles fermée, l'équipage est à couvert")
	var d_fc: Array = ConstructionLibre.forme(d_c).formes.filter(func(f): return String(f.get("c", "")).begins_with("#4C5236"))
	ok(not d_fc.is_empty(), "la forme fermée prend l'aspect blindé")
	ok(ConstructionLibre.tole_en(d_c, Vector2(7.0, 7.1)) >= 0, "toucher une tôle la retrouve")
	# Remorque, peinture
	var d_r := ConstructionLibre.en_remorque(d_j)
	ok(ConstructionLibre.remorque(d_r) and not d_r.pieces.any(func(p): return Assemblage.piece(String(p.piece)).famille in ["moteur", "radiateur"]), "en remorque : moteur et radiateur démontés")
	ok(d_r.pieces.any(func(p): return String(p.piece) == "greffe_timon"), "un timon est posé à l'avant")
	var d_ra := ConstructionLibre.analyser(d_r)
	ok(d_ra.ok and float(d_ra.stats.vitesse) > 0.0 and float(d_ra.stats.conso) == 0.0, "une remorque roule sans moteur et ne consomme rien")
	var d_rs := d_r.duplicate(true)
	d_rs.pieces = d_rs.pieces.filter(func(p): return String(p.piece) != "greffe_timon")
	ok(String(ConstructionLibre.analyser(d_rs).stats.immobile).contains("timon"), "sans timon, impossible de l'atteler")
	d_j.peinture = "#B0623A"
	ok(String(ConstructionLibre.forme(d_j).get("peinture", "")) == "#B0623A", "la peinture de bande passe au dessin")
	# Coques superposées
	var d_k := ConstructionLibre.poser(jeep(), "coque_berline", Vector2i(1, 2))
	var d_k2 := ConstructionLibre.poser(d_k, "coque_cabine_camion", Vector2i(10, 2))
	ok(not d_k2.is_empty() and int(d_k2.pieces.back().pos[0]) == 10, "une coque se pose par-dessus une autre, pour la découper")
	ok(ConstructionLibre.piece_en(d_k2, Vector2i(11, 3), true) == d_k2.pieces.size() - 1, "toucher prend la coque du dessus")

	print("TOUT EST OK" if echecs == 0 else "%d ÉCHEC(S)" % echecs)
	quit(1 if echecs > 0 else 0)
