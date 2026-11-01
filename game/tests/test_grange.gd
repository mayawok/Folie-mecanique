# Test sans écran de la grille G2 (démontage dans la grange) et G3 (édition libre) :
#   godot --headless --path game -s res://tests/test_grange.gd
extends SceneTree

var echecs := 0


func verifier(cond: bool, msg: String) -> void:
	print(("OK   " if cond else "ÉCHEC ") + msg)
	if not cond:
		echecs += 1


func _avancer(m: CombatModele, secondes: float) -> void:
	for i in int(secondes / CombatModele.DT):
		m.avancer()


# Convoi de départ + une Traction, une grange neutralisée à portée, nuit, aucune menace
func _grange(graine: int) -> Array:
	var m := CombatModele.new(graine)
	m._prochain_x = INF
	m.stocks.fuel_l = 300.0
	m.monde._assaut_t = 1.0e9
	var tr = m.ajouter_vehicule("citroen_traction")
	var b = m.creer_batiment("grange", m.x_tete + 4.0)
	b.statut = "neutralise"
	b.pv = b.pv_max
	for t in b.tireurs:
		t.pv = 0.0
	m.batiments.append(b)
	m.monde.heure = 0.80   # nuit
	return [m, tr, b]


func _init() -> void:
	_demontage()
	_edition()
	_dessin()
	print("\n%s" % ("TOUT EST OK" if echecs == 0 else "%d ÉCHEC(S)" % echecs))
	quit(1 if echecs > 0 else 0)


func _demontage() -> void:
	print("— G2 : démontage dans la grange —")
	var r := _grange(9)
	var m: CombatModele = r[0]
	var tr = r[1]
	var b = r[2]
	var n0 := m.convoi.size()
	verifier(m.raison_demontage(tr.uid) != "", "refusé tant que le véhicule n'est pas garé")
	verifier(m.ordre_garer(tr.uid), "la Traction rentre dans la grange")
	m.monde.heure = 0.30
	verifier("nuit" in m.raison_demontage(tr.uid), "refusé de jour : %s" % m.raison_demontage(tr.uid))
	m.monde.heure = 0.80
	verifier(m.raison_demontage(tr.uid) == "", "autorisé de nuit, garé, convoi arrêté")
	var plan := Assemblage.de_type("citroen_traction")
	var n_pieces: int = plan.pieces.size() + 1
	var metal0: float = m.stocks.metal
	var equipage: int = tr.equipage_vivant()
	var reserve0: int = m.reserve_survivants
	verifier(m.ordre_demonter(tr.uid), "démontage commencé")
	_avancer(m, 10.0)
	verifier(m.convoi.has(tr) and not m.travaux.is_empty(), "le démontage prend du temps de jeu")
	_avancer(m, 20.0)
	verifier(not m.convoi.has(tr) and m.convoi.size() == n0 - 1, "le véhicule quitte le convoi")
	verifier(m.pieces_stock.size() == n_pieces, "toutes les pièces, châssis compris, sont en réserve (%d)" % m.pieces_stock.size())
	verifier(Assemblage.manquantes(plan, m.ids_stock()).is_empty(), "la réserve permet de reconstruire la Traction à l'identique")
	verifier(m.stocks.metal == metal0 + Assemblage.piece(plan.chassis).metal, "+ métal de ferraille du châssis")
	verifier(m.reserve_survivants == reserve0 + equipage, "les survivants valides attendent dans la réserve")
	verifier(not b.garage.has(tr.uid), "la grange est libérée")
	var x_avant := m.x_tete
	# Reconstruire : un véhicule neuf prend place en queue de convoi, sans déplacer le convoi
	var garee = m.convoi[0]
	m.ordre_garer(garee.uid)
	verifier(m.raison_atelier_libre() == "", "l'édition libre est possible : %s" % m.raison_atelier_libre())
	verifier(m.chassis_en_reserve() == [plan.chassis], "le châssis est disponible en réserve")
	verifier(m.assembler(0, plan), "reconstruction de la Traction depuis la réserve")
	verifier(m.convoi.size() == n0 and m.x_tete == x_avant, "le convoi retrouve sa taille sans reculer ni avancer")
	verifier(m.pieces_stock.is_empty(), "la réserve est vidée par la reconstruction")
	verifier(m.convoi[m.convoi.size() - 1].type == "citroen_traction" and m.convoi[m.convoi.size() - 1].equipage_vivant() > 0, "la Traction est en queue, avec équipage")
	# Dernier véhicule
	var s := CombatModele.new(2)
	s.convoi = [s.convoi[0]]
	s.convoi[0].garage = 99
	s.monde.heure = 0.80
	verifier("dernier" in s.raison_demontage(s.convoi[0].uid), "le dernier véhicule ne se démonte pas")
	# Tempête : travail possible de jour
	var t := _grange(9)
	var mt: CombatModele = t[0]
	mt.ordre_garer(t[1].uid)
	mt.monde.heure = 0.30
	mt.tempete = {"phase": "active", "reste": 100.0, "duree": 100.0}
	verifier(mt.raison_demontage(t[1].uid) == "", "à l'abri d'une tempête, le démontage est possible de jour")
	# Interruption par une menace
	mt.ordre_demonter(t[1].uid)
	mt.ennemis.append(mt.creer_vehicule("bmw_r75", "ennemi", mt.x_tete + 20.0))
	_avancer(mt, 1.0)
	verifier(mt.travaux.is_empty() and mt.convoi.has(t[1]), "une menace interrompt le démontage")


func _edition() -> void:
	print("— G3 : édition libre sur la grille —")
	var hist := Assemblage.de_type("citroen_traction")
	var a := Assemblage.nouvelle(hist.chassis)
	var ok := true
	for p in hist.pieces:
		var b := Assemblage.poser(a, p.piece, Vector2i(int(p.pos[0]), int(p.pos[1])))
		if b.is_empty() or int(b.pieces.back().pos[0]) != int(p.pos[0]) or int(b.pieces.back().pos[1]) != int(p.pos[1]):
			ok = false
			break
		a = b
	verifier(ok and Assemblage.apercu(a).ok, "reposer les pièces historiques à leur place donne un véhicule valide")
	verifier(is_equal_approx(float(Assemblage.apercu(a).stats.vitesse), float(Assemblage.statistiques(hist).vitesse)), "mêmes statistiques que l'historique")
	# Aimantation
	var roues := ""
	for p in hist.pieces:
		if Assemblage.piece(p.piece).famille == "roulement":
			roues = p.piece
	var base := Assemblage.nouvelle(hist.chassis)
	var r := Assemblage.poser(base, roues, Vector2i(1, 5))
	verifier(not r.is_empty() and int(r.pieces[0].pos[1]) == 0, "les roues s'aimantent au sol (y = 0)")
	var arme := Assemblage.poser(base, "arme_mitrailleuse", Vector2i(2, 0))
	var g := Assemblage.taille_grille(base)
	verifier(not arme.is_empty() and int(arme.pieces[0].pos[1]) + 1 >= (g.y + 1) / 2, "l'arme remonte dans la moitié haute")
	verifier(Assemblage.poser(base, "piece_inexistante", Vector2i.ZERO).is_empty(), "une pièce inconnue est refusée")
	verifier(Assemblage.poser(base, hist.chassis, Vector2i.ZERO).is_empty(), "un châssis ne se pose pas sur un châssis")
	# Chevauchement : la pièce glisse vers une place libre ou retourne au bac
	var deux := Assemblage.poser(r, roues, Vector2i(1, 0))
	verifier(deux.is_empty() or Assemblage.defauts_pose(deux).is_empty(), "un chevauchement est évité ou refusé")
	# Retirer et retrouver une pièce
	var i := Assemblage.piece_en(a, Vector2i(int(hist.pieces[0].pos[0]), int(hist.pieces[0].pos[1])))
	verifier(i >= 0, "toucher une cellule retrouve la pièce posée")
	verifier(Assemblage.retirer(a, i).pieces.size() == a.pieces.size() - 1, "retirer enlève une pièce")
	verifier(Assemblage.piece_en(a, Vector2i(-5, -5)) == -1, "une cellule hors grille ne contient rien")
	verifier(not Assemblage.apercu(Assemblage.retirer(a, i)).ok, "sans la pièce, l'aperçu signale ce qui manque")
	# Plaques de blindage : fabriquées avec du métal
	var t := _grange(9)
	var m: CombatModele = t[0]
	m.ordre_garer(m.convoi[0].uid)
	m.pieces_stock = m.pieces_stock + Assemblage.ids(hist).map(func(id): return {"piece": id, "etat": 1.0})
	var blindee := hist.duplicate(true)
	blindee.plaques = 2
	m.stocks.metal = 5.0
	verifier(not m.assembler(0, blindee), "pas assez de métal pour 2 plaques (8 requis, 5 disponibles)")
	verifier(m.pieces_stock.size() == Assemblage.ids(hist).size(), "la réserve n'est pas touchée par un refus")
	m.stocks.metal = 20.0
	verifier(m.assembler(0, blindee), "2 plaques fabriquées avec 8 métal")
	verifier(is_equal_approx(m.stocks.metal, 12.0), "métal restant : %.0f" % m.stocks.metal)
	verifier(m.convoi[m.convoi.size() - 1].profil.blindage > Assemblage.statistiques(hist).blindage, "le blindage du véhicule est plus élevé")


func _dessin() -> void:
	print("— G4 : dessin des véhicules assemblés —")
	var trac := Assemblage.de_type("citroen_traction")
	verifier(FormeAssemblage.type_dessin(trac) == "citroen_traction", "un assemblage historique garde son dessin d'origine")
	verifier(FormeAssemblage.type_dessin(Assemblage.de_type("side_bmw")) == "side_bmw", "les règles d'apparence de la BMW sont respectées")
	var blindee := trac.duplicate(true)
	blindee.plaques = 2
	var cle := FormeAssemblage.type_dessin(blindee)
	verifier(cle.begins_with("asm_") and VehiculeDessin.existe(cle), "un assemblage modifié reçoit sa propre fiche (%s)" % cle)
	verifier(FormeAssemblage.type_dessin(blindee.duplicate(true)) == cle, "même assemblage, même clé")
	var deplace := trac.duplicate(true)
	deplace.pieces[3].pos = [6, 4]   # cabine décalée d'une cellule
	verifier(FormeAssemblage.type_dessin(deplace) != "citroen_traction", "une pièce déplacée change l'apparence")
	var F: Dictionary = VehiculeDessin.donnees().vehicules[cle]
	var g := Assemblage.taille_grille(blindee)
	verifier(is_equal_approx(F.longueur, g.x * 0.25) and is_equal_approx(F.hauteur, g.y * 0.25), "dimensions tirées de la grille (%.2f × %.2f m)" % [F.longueur, F.hauteur])
	verifier(F.roues.size() == 2 and F.armes.size() == Assemblage.statistiques(blindee).armes.size(), "2 roues, autant d'armes dessinées que de pièces d'armement")
	verifier(F.equipage.size() >= 1, "l'équipage est placé dans la cabine")
	verifier(VehiculeDessin.donnees().teintes.has(F.teinte), "teinte connue")
	var sher := Assemblage.de_type("m4_sherman")
	sher.plaques = 1
	var F2: Dictionary = VehiculeDessin.donnees().vehicules[FormeAssemblage.type_dessin(sher)]
	verifier(F2.has("chenille") and F2.chenille.galets.size() >= 2 and F2.armes.size() == 2 and F2.armes[0].type == "canon", "chenilles et canon d'un char assemblé")
	# Dans le jeu : le véhicule fabriqué se pose, s'ancre et survit à la sauvegarde
	var t := _grange(9)
	var m: CombatModele = t[0]
	m.ordre_garer(m.convoi[0].uid)
	m.pieces_stock = m.pieces_stock + Assemblage.ids(trac).map(func(id): return {"piece": id, "etat": 1.0})
	m.stocks.metal = 50.0
	verifier(m.assembler(0, blindee), "le véhicule assemblé rejoint le convoi")
	var v = m.convoi[m.convoi.size() - 1]
	verifier(v.type == cle and v.nom == F.nom, "son type de dessin est la fiche fabriquée")
	var an: Vector2 = CombatModele.ancre(v, "a0")
	verifier(is_finite(an.x) and is_finite(an.y) and an.x >= v.x, "l'ancrage de l'arme est calculé sur la fiche fabriquée")
	var r := CombatModele.depuis_sauvegarde(m.sauver())
	verifier(r.convoi[r.convoi.size() - 1].type == cle, "la sauvegarde restitue le même dessin")
