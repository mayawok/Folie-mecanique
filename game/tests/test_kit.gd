# Kit de développement du Mode créatif (DEC-110, DEV-010) : route calme, zone, heure, tempête et apparitions à la demande.
# godot --headless --path game -s res://tests/test_kit.gd
extends SceneTree

var echecs := 0


func ok(c: bool, t: String) -> void:
	print("OK  " if c else "ÉCHEC ", t)
	if not c:
		echecs += 1


func marche(m: CombatModele, s: float) -> void:
	for i in int(s / CombatModele.DT):
		m.avancer()


func jeu() -> CombatModele:
	var m := CombatModele.new(5, {"bac_a_sable": true})
	var a := ConstructionLibre.voiture("moyen")
	a.nom = "Essai"
	ok(m.construire_grille(0, a), "un véhicule se construit en Mode créatif")
	m.ordre_marche("avancer")
	return m


func _init() -> void:
	# Hors Mode créatif : le Kit ne fait rien
	var n := CombatModele.new(5)
	ok(not n.kit_apparaitre("ennemi", {"type": "willys_mb"}), "hors Mode créatif : aucune apparition")
	ok(not n.kit_tempete(), "hors Mode créatif : pas de tempête commandée")

	var m := jeu()
	ok(m.kit_calme, "Mode créatif : route calme par défaut")
	marche(m, 120.0)
	ok(m.ennemis.is_empty() and m.batiments.is_empty() and m.monde.vivants() == 0 and m.mines.is_empty() and m.tempete.is_empty(),
		"route calme : 120 s de route sans rencontre, rôdeur, mine ni tempête")

	# Zone
	ok(m.kit_regler_zone("eau") and Terrain.zone == "eau", "zone eau")
	ok(not m.kit_regler_zone("lave") and Terrain.zone == "eau", "zone inconnue refusée")
	for z in CombatModele.KIT_ZONES:
		ok(Terrain.PALETTES.has(z) and Terrain.PALETTES[z].decor.size() > 0, "palette et décor définis pour la zone %s" % z)
	m.kit_regler_zone("sable")

	# Heure et tempête
	m.kit_regler_heure(0.85)
	ok(m.monde.nuit(), "heure : la nuit tombe à 0,85")
	m.kit_regler_heure(0.3)
	ok(not m.monde.nuit(), "heure : le matin est de jour")
	ok(m.kit_tempete() and m.tempete.phase == "annonce", "tempête annoncée à la demande")
	marche(m, 8.0)
	ok(m.tempete_active(), "la tempête éclate")
	m.kit_fin_tempete()
	ok(not m.tempete_active(), "fin de tempête")

	# Toutes les apparitions du panneau réussissent
	for e in PanneauKit.tout_le_catalogue():
		var k := jeu()
		var avant: int = k.ennemis.size() + k.batiments.size() + k.epaves.size() + k.mines.size() + k.monde.vivants() + k.monde.pnj.size()
		var r := k.kit_apparaitre(e[1], e[2])
		var apres: int = k.ennemis.size() + k.batiments.size() + k.epaves.size() + k.mines.size() + k.monde.vivants() + k.monde.pnj.size()
		ok(r and apres > avant, "apparition « %s » (%s)" % [e[0], e[1]])
		marche(k, 20.0)   # la simulation tient avec l'élément présent

	# Convoi à rattraper : il avance dans notre sens, à la vitesse imposée
	var c := jeu()
	c.kit_apparaitre("convoi_devant", {"types": ["citroen_t23", "willys_mb"], "vitesse": 3.0})
	var x0: float = c.ennemis[0].x
	c.ordre_marche("halte")
	marche(c, 10.0)
	ok(c.ennemis[0].mode == "convoi" and absf((c.ennemis[0].x - x0) - 30.0) < 3.0, "convoi ennemi à l'arrêt de notre côté : il avance de ~30 m en 10 s (%.1f)" % (c.ennemis[0].x - x0))

	# Poursuite : arrive derrière, se cale à côté
	var p := jeu()
	p.kit_apparaitre("poursuite", {"types": ["citroen_traction"], "abordeurs": 1})
	ok(p.ennemis[0].mode == "poursuite" and p.ennemis[0].x < p.x_tete, "poursuivant créé derrière le convoi")

	# Route non calme : les rencontres reviennent
	var r2 := jeu()
	r2.kit_regler_calme(false)
	marche(r2, 150.0)
	ok(not r2.ennemis.is_empty() or not r2.batiments.is_empty() or not r2.epaves.is_empty() or r2.monde.vivants() > 0, "route non calme : des rencontres arrivent")

	print("--- %s" % ("TOUT EST OK" if echecs == 0 else "%d ÉCHEC(S)" % echecs))
	quit(1 if echecs > 0 else 0)
