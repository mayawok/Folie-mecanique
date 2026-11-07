extends SceneTree
# Grille V2 : bases véhicule, rallonge par crans, essieux, modules, blindage, fiabilité, camp de réparation
# Lancer : godot --headless --path game -s res://tests/test_base_vehicule.gd
var echecs := 0


func ok(c: bool, t: String) -> void:
	print("OK  " if c else "ÉCHEC ", t)
	if not c:
		echecs += 1


func _xs_essieux(a: Dictionary) -> Array:
	var xs := []
	for e in a.essieux:
		xs.append(int(e.x))
	xs.sort()
	return xs


func _init() -> void:
	# --- P0 : toutes les bases se créent, se calculent et roulent ---
	for id in BaseVehicule.ids():
		var b := BaseVehicule.creer(String(id))
		ok(not b.is_empty() and BaseVehicule.est_base(b), "%s : base créée" % id)
		if b.is_empty():
			continue
		var an := ConstructionLibre.analyser(b)
		ok(bool(an.ok), "%s : analysable %s" % [id, an.defauts.map(func(d): return d.texte if d is Dictionary else str(d))])
		ok(b.essieux.all(func(e): return float(e.etat) < 1.0), "%s : essieux d'origine usés" % id)
		ok(bool(FiabiliteVehicule.evaluer(b).ok), "%s : fiabilité évaluée" % id)
	var t23 := BaseVehicule.creer("citroen_t23")
	var bx0 := BaseVehicule.bornes_x(t23)
	var xs0 := _xs_essieux(t23)
	# --- P1 : rallonge par crans ---
	var r := BaseVehicule.rallonger(t23, "milieu", 2)
	ok(bool(r.ok), "empattement +2 crans : %s" % r.raison)
	if bool(r.ok):
		var b2: Dictionary = r.a
		var bx := BaseVehicule.bornes_x(b2)
		ok(bx.y - bx.x == bx0.y - bx0.x + 4, "longueur +4 cases (2 crans de 2)")
		var xs := _xs_essieux(b2)
		ok(xs.size() == xs0.size() and int(xs[xs.size() - 1]) - int(xs[0]) == int(xs0[xs0.size() - 1]) - int(xs0[0]) + 4, "empattement +4 cases %s → %s" % [xs0, xs])
		ok(int(b2.base.crans.milieu) == 2 and int(t23.base.crans.milieu) == 0, "crans comptés, grille d'origine intacte")
		ok(bool(ConstructionLibre.analyser(b2).ok), "rallongée : toujours analysable")
		ok(float(r.cout.metal) > 0.0, "rallonge : coûte du métal")
		var plus := BaseVehicule.rallonger(b2, "milieu", 3)
		ok(not bool(plus.ok), "au-delà du maximum de la base : refusé (%s)" % plus.raison)
	var ra := BaseVehicule.rallonger(t23, "arriere", 1)
	ok(bool(ra.ok), "porte-à-faux arrière +1 cran : %s" % ra.raison)
	if bool(ra.ok):
		var bxa := BaseVehicule.bornes_x(ra.a)
		ok(bxa.x == bx0.x and bxa.y == bx0.y + 2, "arrière : l'avant ne bouge pas, la longueur +2")
		ok(_xs_essieux(ra.a)[0] == int(xs0[0]) + 2, "arrière : les essieux avancent avec le véhicule")
	var rv := BaseVehicule.rallonger(t23, "avant", 1)
	ok(bool(rv.ok), "porte-à-faux avant +1 cran : %s" % rv.raison)
	if bool(rv.ok):
		var bxv := BaseVehicule.bornes_x(rv.a)
		ok(bxv.x == bx0.x and bxv.y == bx0.y + 2 and _xs_essieux(rv.a) == xs0, "avant : les essieux ne bougent pas")
	ok(not bool(BaseVehicule.rallonger(ConstructionLibre.nouvelle(), "milieu", 1).ok), "une grille libre n'est pas une base")
	ok(not bool(BaseVehicule.rallonger(t23, "diagonale", 1).ok), "zone inconnue refusée")
	# --- Renforts ---
	var long := BaseVehicule.rallonger(t23, "milieu", 4)
	if bool(long.ok):
		var s0 := FiabiliteVehicule.souplesse(long.a)
		var rf := BaseVehicule.renforcer(long.a)
		ok(bool(rf.ok) and FiabiliteVehicule.souplesse(rf.a) < s0, "renfort : le châssis rallongé fléchit moins (%.2f → %.2f)" % [s0, FiabiliteVehicule.souplesse(rf.a)])
		var e0 := FiabiliteVehicule.evaluer(long.a)
		var e1 := FiabiliteVehicule.evaluer(rf.a)
		ok(float(e1.usure.chassis) < float(e0.usure.chassis), "renfort : châssis moins fatigué")
	# --- Lieux et durées (garage / camp) ---
	ok(not bool(BaseVehicule.permis("rallonger", {"niveau": 0}).ok), "rallonger en camp : refusé")
	ok(bool(BaseVehicule.permis("rallonger", {"niveau": 2}).ok), "rallonger à l'atelier : permis")
	ok(not bool(BaseVehicule.permis("ajouter_essieu", {"niveau": 1}).ok), "ajouter un essieu au garage de fortune : refusé")
	ok(bool(BaseVehicule.permis("changer_essieu", {"niveau": 0}).ok), "changer un essieu cassé en camp : permis")
	ok(BaseVehicule.duree_s("changer_essieu") > BaseVehicule.duree_s("changer_roue"), "essieu plus long qu'une roue")
	ok(BaseVehicule.duree_s("changer_moteur") > BaseVehicule.duree_s("changer_essieu"), "moteur plus long qu'un essieu")
	ok(BaseVehicule.duree_s("changer_essieu", {}, 3) < BaseVehicule.duree_s("changer_essieu", {}, 1), "plus de mécaniciens : plus court")
	ok(BaseVehicule.duree_s("changer_essieu", {"niveau": 2}) < BaseVehicule.duree_s("changer_essieu"), "à l'atelier : plus court qu'en camp")
	ok(BaseVehicule.duree_s("changer_essieu", {"atelier_mobile": true}) < BaseVehicule.duree_s("changer_essieu"), "atelier mobile : plus court en camp")
	# --- Essieux ---
	var cols := {}
	for c in t23.cases:
		cols[int(c[0])] = true
	var xnew := -1
	for x in range(bx0.x + 1, bx0.y):
		if cols.has(x) and not xs0.has(x):
			xnew = x
			break
	var ae := BaseVehicule.ajouter_essieu(t23, xnew, "essieu_lourd", "roue_grande")
	ok(bool(ae.ok) and ae.a.essieux.size() == t23.essieux.size() + 1 and int(ae.a.base.essieux_ajoutes) == 1, "essieu ajouté (6x4) : %s" % ae.raison)
	if bool(ae.ok):
		var ae2 := BaseVehicule.ajouter_essieu(ae.a, xnew + 1, "essieu_lourd", "roue_grande")
		ok(not bool(ae2.ok) or ae.a.essieux.size() < int(BaseVehicule.fiche("citroen_t23").essieux_max), "maximum d'essieux respecté")
	var ce := BaseVehicule.changer_essieu(t23, int(xs0[0]), "essieu_char", "chenille", 0.9)
	ok(bool(ce.ok) and ce.retire.size() >= 1, "essieu changé, l'ancien revient en réserve")
	if bool(ce.ok):
		var neuf := ConstructionLibre.essieu_en(ce.a, int(xs0[0]))
		ok(String(neuf.piece) == "essieu_char" and is_equal_approx(float(neuf.etat), 0.9), "nouvel essieu monté avec son état")
	# --- Moteur et boîte ---
	var cm := BaseVehicule.changer_moteur(t23, "moteur_diamond_t", 1.0)
	ok(bool(cm.ok) or cm.raison != "", "moteur plus gros : %s" % ("monté" if bool(cm.ok) else cm.raison))
	var cb := BaseVehicule.changer_boite(t23, "boite_lourde", 1.0)
	ok(bool(cb.ok) and cb.a.base.boite == "boite_lourde" and cb.retire[0].piece == "boite_moyenne", "boîte changée")
	ok(not bool(BaseVehicule.changer_boite(t23, "boite_inconnue").ok), "boîte inconnue refusée")
	# --- P2 : modules, blindage, rôles ---
	var am := BaseVehicule.poser_module(t23, "atelier_mobile")
	ok(bool(am.ok), "T23 : atelier mobile monté (%s)" % am.raison)
	if bool(am.ok):
		ok(int(BaseVehicule.effets_module(am.a).atelier_niveau) == 1 and BaseVehicule.roles(am.a).has("atelier"), "atelier mobile : niveau 1 et rôle atelier")
		ok(BaseVehicule.poids_supplementaire(am.a) >= 700.0, "module : poids ajouté")
		var comp := BaseVehicule.composition([am.a, BaseVehicule.creer("willys_mb")])
		ok(bool(comp.atelier_mobile) and comp.manques.has("ravitailleur") and not comp.manques.has("atelier"), "convoi : atelier mobile présent, ravitailleur manquant")
	# DEV-019 : module, blindage et renforts comptent dans les statistiques de combat
	var s_base: Dictionary = ConstructionLibre.analyser(t23).stats
	if bool(am.ok):
		ok(float(ConstructionLibre.analyser(am.a).stats.poids_kg) >= float(s_base.poids_kg) + 650.0, "atelier mobile : +700 kg dans le profil de combat")
	var ci := BaseVehicule.poser_module(t23, "citerne")
	ok(bool(ci.ok) and float(ConstructionLibre.analyser(ci.a).stats.reservoir) >= float(s_base.reservoir) + 399.0, "citerne : réservoir +400 L dans le profil")
	var tr := BaseVehicule.poser_module(t23, "bache")
	ok(bool(tr.ok) and int(ConstructionLibre.analyser(tr.a).stats.places_troupes) >= int(s_base.places_troupes) + 6, "bâche : +6 places de troupes")
	var blz := BaseVehicule.blinder_zone(t23, "cabine", "plaque")
	ok(bool(blz.ok) and float(ConstructionLibre.analyser(blz.a).stats.blindage) > float(s_base.blindage), "blindage de cabine : blindage du profil en hausse")
	var w := BaseVehicule.creer("willys_mb")
	ok(not bool(BaseVehicule.poser_module(w, "atelier_mobile").ok), "Willys : atelier mobile refusé (module non prévu)")
	ok(not bool(BaseVehicule.poser_module(w, "bache").ok), "Willys court : bâche refusée (plateau trop court)")
	var wl := BaseVehicule.rallonger(w, "arriere", 1)
	ok(bool(wl.ok) and bool(BaseVehicule.poser_module(wl.a, "bache").ok), "Willys rallongée d'un cran : bâche possible")
	var bl := t23
	for z in BaseVehicule.regles().blindage.zones:
		var rb := BaseVehicule.blinder_zone(bl, String(z), "lourd")
		if bool(rb.ok):
			bl = rb.a
	ok(float(BaseVehicule.effets_blindage(bl).moyenne) >= 4.0 and BaseVehicule.roles(bl).has("blinde"), "blindage lourd partout : rôle blindé")
	ok(float(BaseVehicule.effets_blindage(bl).poids_kg) > 3000.0, "blindage lourd : très lourd")
	ok(not bool(BaseVehicule.blinder_zone(t23, "toit_de_lune", "lourd").ok), "zone de blindage inconnue refusée")
	# --- P3 : fiabilité ---
	var f0 := FiabiliteVehicule.evaluer(t23)
	ok(bool(f0.ok) and f0.usure.essieux.size() == t23.essieux.size(), "T23 d'origine évalué : %s (indice %.2f)" % [f0.verdict, float(f0.indice)])
	if bool(cm.ok):
		var f1 := FiabiliteVehicule.evaluer(cm.a)
		ok(float(f1.usure.boite) != float(f0.usure.boite), "moteur plus puissant : la boîte est plus sollicitée")
		if bool(BaseVehicule.changer_boite(cm.a, "boite_lourde", 1.0).ok):
			var cb2 := BaseVehicule.changer_boite(cm.a, "boite_lourde", 1.0)
			ok(float(FiabiliteVehicule.evaluer(cb2.a).usure.boite) < float(f1.usure.boite), "boîte neuve et plus grosse : s'use moins")
	var cp := BaseVehicule.changer_moteur(t23, "moteur_4cyl_petit", 1.0)
	if bool(cp.ok):
		var fp := FiabiliteVehicule.evaluer(cp.a)
		ok(float(fp.usure.moteur) > float(f0.usure.moteur) * 1.2, "moteur trop petit pour le camion : usure du moteur nettement plus forte (%.2f vs %.2f)" % [float(fp.usure.moteur), float(f0.usure.moteur)])
	if bool(am.ok):
		var charge := FiabiliteVehicule.evaluer(am.a)
		ok(float(charge.masse_kg) > float(f0.masse_kg), "module et blindage comptent dans la masse")
	ok(FiabiliteVehicule.tirer_pannes(t23, 0.0, 1).is_empty(), "0 km : aucune panne")
	ok(FiabiliteVehicule.tirer_pannes(t23, 300.0, 7) == FiabiliteVehicule.tirer_pannes(t23, 300.0, 7), "pannes déterministes pour une graine")
	ok(FiabiliteVehicule.tirer_pannes(t23, 100000.0, 3).size() >= 3, "très longue distance : tout casse")
	# --- Camp de réparation ---
	var x0 := int(xs0[0])
	var courant := ConstructionLibre.essieu_en(t23, x0)
	var reserve := [{"piece": "essieu_lourd", "etat": 0.9}, {"piece": "roue_grande", "etat": 0.8}]
	var P := {"x": x0, "essieu": "essieu_lourd", "train": String(courant.train)}
	var d := CampReparation.demarrer("changer_essieu", P, t23, [], {"niveau": 0}, 1, 2, 11)
	ok(not bool(d.ok), "camp sans pièce de rechange : refusé (%s)" % d.raison)
	ok(not bool(CampReparation.demarrer("rallonger", {}, t23, reserve, {"niveau": 0}, 1, 2, 11).ok), "rallonge en camp : refusée")
	d = CampReparation.demarrer("changer_essieu", P, t23, reserve, {"niveau": 0}, 2, 2, 11)
	ok(bool(d.ok), "camp établi pour changer l'essieu")
	if bool(d.ok):
		var camp: Dictionary = d.camp
		ok(bool(camp.immobilise) and float(camp.duree_s) > 60.0, "véhicule immobilisé, travail long (%.0f s)" % float(camp.duree_s))
		ok(CampReparation.attaques_prevues(float(camp.duree_s), 2, 11) == CampReparation.attaques_prevues(float(camp.duree_s), 2, 11), "attaques déterministes pour une graine")
		var pas := CampReparation.terminer(camp, t23, reserve)
		ok(not bool(pas.ok) and pas.reserve == reserve, "terminer trop tôt : rien ne change")
		var defense := 0.0
		var nb_attaques := 0
		var garde := 0
		while camp.etat == "en_cours" and garde < 2000:
			garde += 1
			var dues := CampReparation.attaques_dues(camp, 5.0)
			if not dues.is_empty():
				defense = 25.0
				nb_attaques += dues.size()
			camp = CampReparation.avancer(camp, 5.0, defense > 0.0)
			defense -= 5.0
			if garde == 3:
				var stop := CampReparation.interrompre(camp)
				var reste := float(stop.restant_s)
				ok(stop.etat == "interrompue" and is_equal_approx(float(CampReparation.avancer(stop, 5.0, false).restant_s), reste), "interrompu : le travail fait est gardé, rien n'avance")
				camp = CampReparation.reprendre(stop)
		ok(camp.etat == "pret", "réparation finie")
		if nb_attaques > 0:
			ok(float(camp.t) > float(camp.duree_s), "%d attaque(s) défendues : le camp a duré plus longtemps (%.0f s pour %.0f s)" % [nb_attaques, float(camp.t), float(camp.duree_s)])
		var fin := CampReparation.terminer(camp, t23, reserve)
		ok(bool(fin.ok) and fin.camp.etat == "terminee" and not bool(fin.camp.immobilise), "essieu changé : le véhicule peut repartir")
		if bool(fin.ok):
			var neuf2 := ConstructionLibre.essieu_en(fin.a, x0)
			ok(String(neuf2.piece) == "essieu_lourd" and is_equal_approx(float(neuf2.etat), 0.9), "essieu de rechange monté avec son état")
			ok(CampReparation._compter(fin.reserve, "roue_grande") == 1, "roues de la réserve intactes")
			ok(reserve.size() == 2, "réserve d'origine non modifiée")
	print("%d ÉCHEC(S)" % echecs if echecs else "TOUT OK")
	quit(1 if echecs else 0)
