extends SceneTree
# Plateformes de voiture et classe Intercepteur (DEC-083)
var echecs := 0


func ok(c: bool, t: String) -> void:
	print("OK  " if c else "ÉCHEC ", t)
	if not c:
		echecs += 1


func _init() -> void:
	for t in ConstructionLibre.tailles_plateforme():
		var a := ConstructionLibre.voiture(t)
		var an := ConstructionLibre.analyser(a)
		var ids: Array = a.pieces.map(func(p): return String(p.piece))
		ok(an.ok and an.stats.immobile == "", "%s : roule (%.1f m/s, %d kg, défauts %s)" % [t, an.stats.vitesse, an.stats.poids_kg, an.defauts.map(func(d): return d.texte)])
		ok(ids.size() == 4, "%s : carrosserie, radiateur, moteur, poste posés %s" % [t, ids])
		ok(an.stats.classe == "intercepteur", "%s : classe Intercepteur" % t)
	var a := ConstructionLibre.voiture("moyen")
	var o := Vector2i(int(a.plateforme.x), int(a.plateforme.y))
	# Carrosserie interchangeable
	var r := ConstructionLibre.poser_emplacement(a, "carrosserie_pickup", o + Vector2i(2, 1))
	ok(not r.is_empty() and r.remplace == "carrosserie_berline", "pick-up remplace la berline")
	if not r.is_empty():
		ok(r.a.pieces.filter(func(p): return Assemblage.piece(String(p.piece)).get("famille", "") == "coque").size() == 1, "une seule carrosserie")
	ok(ConstructionLibre.poser_emplacement(a, "carrosserie_coupe", o + Vector2i(2, 1)).is_empty(), "coupé (court) refusé sur un châssis moyen")
	# Moteur interchangeable
	var rm := ConstructionLibre.poser_emplacement(a, "moteur_4cyl_nu", o + Vector2i(12, 2))
	ok(not rm.is_empty() and rm.remplace == "moteur_4cyl_moyen", "moteur à nu remplace le 4 cyl.")
	if not rm.is_empty():
		var an2 := ConstructionLibre.analyser(rm.a)
		ok(an2.stats.immobile == "", "moteur à nu : roule (%.1f m/s) %s" % [an2.stats.vitesse, an2.defauts.map(func(d): return d.texte)])
		ok(ConstructionLibre.refroidissement(rm.a).besoin > 52.0, "moteur à nu : chauffe plus")
		ok(an2.stats.vitesse > ConstructionLibre.analyser(a).stats.vitesse, "moteur à nu : plus nerveux (%.2f > %.2f m/s)" % [an2.stats.vitesse, ConstructionLibre.analyser(a).stats.vitesse])
	# Pare-buffle et arme arrière
	var rp := ConstructionLibre.poser_emplacement(a, "greffe_pare_buffle", o + Vector2i(18, 0))
	ok(not rp.is_empty(), "pare-buffle sur le nez")
	var ra := ConstructionLibre.poser_emplacement(a, "arme_mitrailleuse", o + Vector2i(1, 3))
	ok(not ra.is_empty(), "mitrailleuse à l'arrière")
	if not ra.is_empty():
		var w: Array = ra.a.pieces.filter(func(p): return String(p.piece) == "arme_mitrailleuse")
		print("    arme en ", w[0].pos, " origine ", o)
		ok(ConstructionLibre.analyser(ra.a).stats.classe == "intercepteur", "une arme à l'arrière : toujours Intercepteur")
		var b := ConstructionLibre.poser(ra.a, "arme_mitrailleuse", o + Vector2i(10, 5))
		if not b.is_empty():
			ok(ConstructionLibre.analyser(b).stats.classe == "", "deux armes : plus Intercepteur")
	# Garde au sol
	var g0: float = ConstructionLibre.analyser(a).detail.garde_m
	var h := ConstructionLibre.rehausser(a, 3)
	var an3 := ConstructionLibre.analyser(h)
	ok(an3.detail.garde_m > g0 + 0.4 and an3.stats.immobile == "", "rehausse +3 : garde %.2f → %.2f m" % [g0, an3.detail.garde_m])
	ok(h.essieux.all(func(e): return String(e.liaison) == "liaison_tirants"), "rehausse : tirants montés")
	# Changer de longueur (mode créatif)
	var c := ConstructionLibre.changer_plateforme(rp.a, "long")
	var ids2: Array = c.pieces.map(func(p): return String(p.piece))
	ok(ConstructionLibre.plateforme_de(c) == "long" and "carrosserie_limousine" in ids2 and "greffe_pare_buffle" in ids2 and "moteur_4cyl_moyen" in ids2, "moyen → long : limousine, moteur et pare-buffle suivent %s" % [ids2])
	ok(ConstructionLibre.analyser(c).stats.immobile == "", "long : roule")
	var d := ConstructionLibre.deplacer(a, 2, 1)
	ok(int(d.plateforme.x) == o.x + 2 and not ConstructionLibre.poser_emplacement(d, "carrosserie_pickup", Vector2i(-1, -1)).is_empty(), "déplacée : les emplacements suivent")
	print("%d ÉCHEC(S)" % echecs if echecs else "TOUT OK")
	quit()
