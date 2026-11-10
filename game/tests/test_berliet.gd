# Berliet GDR dessiné par l'art (BerlietConfig) et halte de l'équipage (Bivouac).
# godot --headless --path game -s res://tests/test_berliet.gd
extends SceneTree

var echecs := 0


func ok(c: bool, t: String) -> void:
	print("OK  " if c else "ÉCHEC ", t)
	if not c:
		echecs += 1


func simuler(b: Bivouac, s: float, jusqua := "") -> float:
	var dt := 1.0 / 30.0
	var t := 0.0
	while t < s:
		b.avancer(dt)
		t += dt
		if jusqua != "" and b.phase == jusqua:
			break
	return t


func _init() -> void:
	# --- Configuration ---
	var c := BerlietConfig.defaut()
	ok(BerlietConfig.valide(c), "configuration par défaut valide")
	ok(BerlietConfig.options("chassis").size() == 2, "deux châssis (court, long)")
	ok(BerlietConfig.options("pneu_av").size() == 5 and BerlietConfig.options("pneu_ar").size() == 5, "5 pneus avant, 5 pneus arrière")
	ok(BerlietConfig.options("echappement").size() == 5 and BerlietConfig.options("reservoir").size() == 5, "5 échappements, 5 réservoirs")
	ok(BerlietConfig.options("module").size() >= 7, "modules : châssis nu, plateau, citerne, benne, grue, troupes, ridelles")
	ok(not BerlietConfig.regler(c, "pneu_av", "volant"), "valeur inconnue refusée")
	ok(not BerlietConfig.regler(c, "couleur", "rouge"), "clé inconnue refusée")
	ok(BerlietConfig.regler(c, "echappement", "4") and int(c.echappement) == 4, "niveau d'échappement réglé (5e)")
	# toutes les images de toutes les options se chargent
	var manque := []
	for ch in BerlietConfig.options("chassis"):
		for pa in BerlietConfig.options("pneu_av"):
			for n in 5:
				var cc := BerlietConfig.defaut()
				cc.chassis = ch
				cc.pneu_av = pa
				cc.pneu_ar = pa
				cc.echappement = n
				cc.reservoir = n
				for k in BerlietConfig.calques(cc):
					if k.has("image") and BerlietDessin.texture(String(k.image)) == null:
						manque.append(k.image)
	ok(manque.is_empty(), "toutes les images se chargent %s" % [manque])
	# calage : roues au sol, roue avant sous le passage de roue, cabine identique sur les deux châssis
	for ch in ["court", "long"]:
		var cc := BerlietConfig.defaut()
		cc.chassis = ch
		var mo := BerlietConfig.moyeux(cc)
		ok(mo.size() == (2 if ch == "court" else 3), "%s : %d essieux" % [ch, mo.size()])
		var av: Dictionary = mo[mo.size() - 1]
		ok(av.cote == "av" and is_equal_approx(float(av.x), 1912.0), "%s : essieu avant au même endroit" % ch)
		var r := float(BerlietConfig.donnees().rayon_roue)
		ok(absf(float(av.y) + r - BerlietConfig.sol()) < 1.0, "%s : la roue avant touche le sol" % ch)
		var A := BerlietConfig.ancrages_m(cc)
		ok(A.feu < A.arriere and A.porte_arriere < A.porte_avant and A.toit_y > 2.4, "%s : feu derrière, deux portières, toit à %.2f m" % [ch, A.toit_y])
	var court := BerlietConfig.defaut()
	court.chassis = "court"
	var long := BerlietConfig.defaut()
	long.chassis = "long"
	ok(BerlietConfig.longueur_m(long) > BerlietConfig.longueur_m(court) + 1.0, "le châssis long est plus long (%.1f m contre %.1f m)" % [BerlietConfig.longueur_m(long), BerlietConfig.longueur_m(court)])
	ok(BerlietConfig.valeurs(long).charge_t > BerlietConfig.valeurs(court).charge_t, "le châssis long porte plus")
	BerlietConfig.regler(c, "reservoir", 4)
	ok(BerlietConfig.valeurs(c).gazole_l > BerlietConfig.valeurs(BerlietConfig.defaut()).gazole_l, "réservoir plus grand = plus de gazole")

	# --- Halte de l'équipage ---
	var b := Bivouac.new(BerlietConfig.ancrages_m(court))
	ok(b.phase == "route" and b.vitesse > 0.0 and b.a_bord() == b.equipiers.size(), "en route, tout le monde à bord")
	ok(not b.repartir(), "on ne peut pas repartir sans s'être arrêté")
	ok(b.arreter(), "ordre d'arrêt accepté")
	simuler(b, 10.0, "descente")
	ok(b.phase == "descente" and b.vitesse == 0.0, "le camion s'arrête avant que l'équipage descende")
	var t_desc := simuler(b, 40.0, "camp")
	ok(b.phase == "camp", "tout le monde à son poste (%.1f s)" % t_desc)
	var v = b.vigie()
	ok(v != null and absf(v.y - b.A.toit_y) < 0.01 and b.trappe > 0.0, "la vigie est sur le toit, trappe ouverte")
	var meca := 0
	var assis := 0
	for q in b.equipiers:
		if q.action == "repare":
			meca += 1
		if q.action in ["cuisine", "assis"]:
			assis += 1
	ok(meca == 2, "deux mécaniciens réparent")
	ok(assis == 2, "la cuisinière et le tireur sont au feu")
	simuler(b, 6.0)
	ok(b.feu >= 1.0, "le feu a pris")
	ok(b.repartir(), "ordre de repartir accepté")
	simuler(b, 0.5)
	ok(b.vitesse == 0.0 and b.phase != "route", "le départ n'est pas instantané")
	var t_rem := simuler(b, 60.0, "demarrage")
	ok(b.phase == "demarrage" and b.a_bord() == b.equipiers.size() and b.trappe <= 0.0 and b.feu <= 0.0,
		"feu éteint, tout le monde remonte, trappe refermée (%.1f s)" % t_rem)
	ok(t_rem > 3.0, "la remontée prend du temps")
	simuler(b, 20.0, "route")
	ok(b.phase == "route" and is_equal_approx(b.vitesse, b.vitesse_route), "le camion repart")

	# Repartir pendant la descente : ceux qui n'étaient pas sortis restent à bord
	var b2 := Bivouac.new(BerlietConfig.ancrages_m(long))
	b2.arreter()
	simuler(b2, 10.0, "descente")
	simuler(b2, 0.8)
	ok(b2.repartir(), "repartir pendant la descente")
	simuler(b2, 60.0, "demarrage")
	ok(b2.phase == "demarrage" and b2.a_bord() == b2.equipiers.size(), "tout le monde remonte même interrompu")

	# --- Camion de l'expédition dans le jeu (DEC-139) ---
	var m := CombatModele.new(4)
	var cam = m.convoi[0]
	ok(cam.type == "berliet_gdr" and cam.principal, "nouvelle partie : le Berliet est le véhicule principal")
	ok(cam.equipage_vivant() >= 2 and not cam.armes.is_empty(), "le Berliet a son équipage et sa mitrailleuse")
	var mc := CombatModele.new(4, {"bac_a_sable": true})
	ok(mc.convoi[0].type == "berliet_gdr" and mc.convoi[0].principal, "Mode créatif : départ avec le Berliet")
	m.convoi.append(m.creer_vehicule("willys_mb", "joueur", 0.0))
	m.abandonner(cam.uid)
	ok(m.convoi.has(cam), "on n'abandonne pas le camion de l'expédition")
	cam.garage = 99
	m.monde.heure = 0.80
	ok("camion de l'expédition" in m.raison_demontage(cam.uid), "il ne se démonte pas")
	var l0: float = cam.longueur
	ok(m.berliet_regler("chassis", "long") and cam.longueur > l0 + 1.0, "châssis long : le camion s'allonge (%.1f m)" % cam.longueur)
	ok(not m.berliet_regler("module", "piscine"), "module inconnu refusé")
	# Valeurs de jeu branchées (DEV-022)
	var mv := CombatModele.new(4)
	var cv = mv.convoi[0]
	var v0: float = cv.vitesse()
	var rmax0: float = cv.pieces.roulement.max
	mv.berliet_regler("pneu_av", "chaines"); mv.berliet_regler("pneu_ar", "chaines")
	ok(cv.vitesse() < v0 - 0.01, "pneus à chaînes : plus lent sur route (%.2f contre %.2f)" % [cv.vitesse(), v0])
	mv.berliet_regler("pneu_av", "blindee"); mv.berliet_regler("pneu_ar", "blindee")
	ok(cv.pieces.roulement.max > rmax0 * 1.5, "pneus blindés : roulement plus résistant")
	mv.berliet_regler("pneu_av", "route"); mv.berliet_regler("pneu_ar", "route")
	ok(is_equal_approx(cv.vitesse(), v0) and is_equal_approx(cv.pieces.roulement.max, rmax0), "retour aux pneus d'origine : valeurs d'origine")
	mv.berliet_regler("echappement", 4)
	ok(cv.vitesse() > v0 * 1.05, "grande cheminée : moteur plus puissant")
	mv.berliet_regler("reservoir", 4)
	ok(is_equal_approx(float(cv.profil.gazole_l), 560.0), "réservoir 5 : 560 L de gazole")
	mv.berliet_regler("chassis", "long")
	ok(float(cv.profil.charge_t) > 5.0, "châssis long : charge 6 t")
	mv.appliquer_assemblage(cv, cv.assemblage, {}, "berliet_gdr")
	ok(float(cv.profil.gazole_l) == 560.0 and cv.vitesse() > v0 * 1.05, "reconstruction de l'assemblage : valeurs gardées")
	m.berliet_regler("module", "citerne")
	m.berliet_regler("pneu_ar", "chaines")
	var m2 := CombatModele.depuis_sauvegarde(JSON.parse_string(JSON.stringify(m.sauver())))
	var cam2 = m2.convoi[0]
	ok(cam2.principal and cam2.type == "berliet_gdr", "sauvegarde : le Berliet reste le véhicule principal")
	ok(m2.berliet_config.chassis == "long" and m2.berliet_config.module == "citerne" and m2.berliet_config.pneu_ar == "chaines",
		"sauvegarde : pièces du Berliet gardées")
	ok(absf(cam2.longueur - cam.longueur) < 0.01, "sauvegarde : longueur gardée")
	print("Échecs : %d" % echecs)
	quit(1 if echecs > 0 else 0)
