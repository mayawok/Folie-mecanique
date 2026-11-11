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
		var avant: int = k.convoi.size() + k.ennemis.size() + k.batiments.size() + k.epaves.size() + k.mines.size() + k.monde.vivants() + k.monde.pnj.size()
		var r := k.kit_apparaitre(e[1], e[2])
		var apres: int = k.convoi.size() + k.ennemis.size() + k.batiments.size() + k.epaves.size() + k.mines.size() + k.monde.vivants() + k.monde.pnj.size()
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

	# --- Lot A : groupes sur mesure, réglages en direct, région de quête ---
	var g := jeu()
	var n0: int = g.ennemis.size()
	ok(g.kit_apparaitre("groupe", {"type": "moto_bmw", "n": 4, "mode": "approche"}) and g.ennemis.size() == n0 + 4, "groupe de 4 motos à l'approche")
	var xs := g.ennemis.map(func(e): return e.x)
	ok(xs.size() == 4 and absf(xs[3] - xs[0]) > 15.0, "les motos du groupe sont étalées")
	var n1: int = g.ennemis.size()
	ok(g.kit_apparaitre("groupe", {"type": "willys_mb", "n": 3, "mode": "poursuite"}) and g.ennemis.size() == n1 + 3, "groupe de 3 jeeps en poursuite")
	ok(g.kit_apparaitre("groupe", {"type": "citroen_t23", "n": 2, "mode": "convoi", "vitesse": 3.0}), "groupe en convoi devant")
	ok(not g.kit_apparaitre("groupe", {"type": "licorne", "n": 2}), "type de groupe inconnu refusé")
	ok(g.kit_apparaitre("groupe", {"type": "moto_bmw", "n": 99}) and g.ennemis.size() <= n1 + 3 + 2 + 8 + 1, "taille de groupe bornée à 8")
	var d0: float = g.kit_reglage_valeur(0)
	ok(g.kit_reglage_pas(0, 1) and g.kit_reglage_valeur(0) > d0 + 0.05, "réglage en direct : dégâts subis par les ennemis augmentent")
	ok(is_equal_approx(float(CombatModele.donnees().equilibrage.ennemi_degats_subis), g.kit_reglage_valeur(0)), "le réglage change les données de combat")
	var iv0: float = g.kit_reglage_valeur(3)
	ok(g.kit_reglage_pas(3, 1) and g.kit_reglage_valeur(3) > iv0, "réglage : délai entre rencontres plus long")
	ok("ennemi_degats_subis" in g.kit_reglages_texte(), "export des réglages en texte")
	g.kit_reglages_reinitialiser()
	ok(is_equal_approx(g.kit_reglage_valeur(0), d0) and is_equal_approx(g.kit_reglage_valeur(3), iv0), "réinitialiser : valeurs d'origine")
	ok(not CombatModele.new(5).kit_reglage_pas(0, 1), "hors Mode créatif : réglages refusés")
	ok(g.malus_hors_region() == 0, "sans région de quête : aucun malus")
	ok(not g.kit_regler_region_quete("atlantide"), "région inconnue refusée")
	var rc := g.kit_region_courante()
	ok(rc != "", "le convoi a une région courante (%s)" % rc)
	var autre := ""
	for R in CarteMonde.regions():
		if String(R.id) != rc:
			autre = String(R.id)
			break
	g.kit_regler_region_quete(autre)
	ok(g.malus_hors_region() == g.kit_malus_region and g.kit_malus_region > 0, "hors région de la quête : niveau +%d" % g.kit_malus_region)
	var niv_hors: int = g.monde.niveau_a(0.0)
	g.kit_regler_region_quete(rc)
	ok(g.monde.niveau_a(0.0) == niv_hors - g.kit_malus_region, "dans la région de la quête : niveau normal")
	# Allié qui rejoint le convoi + M16 quadruple .50 (DEC-236)
	var al := jeu()
	var nc0: int = al.convoi.size()
	ok(al.kit_apparaitre("allie", {"type": "m16_mgmc"}) and al.convoi.size() == nc0 + 1, "kit : un M16 allié rejoint le convoi")
	var q = al.convoi.back()
	ok(q.camp == "joueur" and q.armes.size() == 1 and String(q.armes[0].id) == "mitrailleuse_quad_50", "le M16 porte la quadruple .50")
	var W: Dictionary = CombatModele.donnees().armes
	ok(float(W.mitrailleuse_quad_50.degats) / float(W.mitrailleuse_quad_50.cadence) > 5.0 * float(W.mitrailleuse.degats) / float(W.mitrailleuse.cadence), "le M16 inflige au moins 5 fois la mitrailleuse")
	ok(float(W.mitrailleuse_quad_50.munitions) / float(W.mitrailleuse_quad_50.cadence) > 8.0 * float(W.mitrailleuse.munitions) / float(W.mitrailleuse.cadence), "le M16 consomme au moins 8 fois plus de munitions")
	ok(not al.kit_apparaitre("allie", {"type": "inconnu"}), "kit : un type inconnu est refusé")
	al.stocks.ammo = 2000.0
	al.kit_apparaitre("ennemi", {"type": "citroen_t23", "dx": -60.0})
	var m0: float = al.stocks.ammo
	marche(al, 30.0)
	ok(al.stocks.ammo < m0 - 100.0, "le M16 vide les munitions du convoi (%.0f consommées)" % (m0 - al.stocks.ammo))
	print("--- %s" % ("TOUT EST OK" if echecs == 0 else "%d ÉCHEC(S)" % echecs))
	quit(1 if echecs > 0 else 0)
