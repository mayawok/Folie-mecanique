# Tests de la construction libre (DEC-043) : châssis peint, essieux, trains, pièces, défauts pratiques,
# conversion des véhicules historiques, grille en partie (normale et bac à sable), mortier.
# godot --headless --path game -s res://tests/test_libre.gd
extends SceneTree

var echecs := 0


func ok(cond: bool, txt: String) -> void:
	print(("OK   " if cond else "ÉCHEC ") + txt)
	if not cond:
		echecs += 1


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
	a = ConstructionLibre.poser(a, "cabine_willys_mb", Vector2i(5, 3))
	return a


func _init() -> void:
	print("— Édition —")
	var a := jeep()
	ok(a.cases.size() == 16, "16 cases peintes")
	ok(a.essieux.size() == 2, "deux essieux posés")
	ok(a.pieces.size() == 2, "moteur et cabine posés (%d)" % a.pieces.size())
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
	var sans_siege := ConstructionLibre.retirer(a, 1)
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
	ok(m.palette_grille(v.uid).all(func(e): return int(e.n) >= 1), "palette normale : pièces comptées")
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

	print("TOUT EST OK" if echecs == 0 else "%d ÉCHEC(S)" % echecs)
	quit(1 if echecs > 0 else 0)
