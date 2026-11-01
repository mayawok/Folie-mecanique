# Couche 3 du modèle : atelier (assemblage sur grille) et ouverture guidée (DEC-035).
# Le joueur commence avec une caisse de pièces : il assemble une moto, puis trouve dans l'ordre de quoi
# en faire un side-car, de l'essence, une arme et des munitions. Les ennemis n'arrivent qu'ensuite.
extends "res://scripts/combat/modele_meteo.gd"

var _fin_annoncee := false


# Plan (assemblage historique) que le joueur peut réaliser maintenant sur ce véhicule (null = nouveau véhicule).
# Renvoie "" si aucun : il faut que le plan contienne toutes les pièces actuelles et que les autres soient en réserve.
func plan_possible(v) -> String:
	var actuelles: Array = Assemblage.ids(v.assemblage) if v != null else []
	var plans: Array = ouv().get("plans", [])
	for i in range(plans.size() - 1, -1, -1):   # le plus complet d'abord
		var plan := Assemblage.de_type(plans[i])
		if plan.is_empty():
			continue
		var ids_plan := Assemblage.ids(plan)
		if not Assemblage.manquantes({"chassis": "", "pieces": actuelles.map(func(id): return {"piece": id})}, ids_plan).is_empty():
			continue   # le plan retirerait des pièces du véhicule : ce n'est pas une amélioration
		if ids_plan.size() <= actuelles.size():
			continue
		if Assemblage.manquantes(plan, actuelles + ids_stock()).is_empty():
			return plans[i]
	return ""


# Raison qui empêche d'ouvrir l'atelier ("" = possible).
func raison_atelier() -> String:
	if en_kit:
		return ""
	if ordres.marche != "halte" or vitesse_convoi != 0.0:
		return "Arrêtez-vous pour assembler."
	if menace():
		return "Trop dangereux : des ennemis sont proches."
	return ""


# Ce que l'atelier peut faire maintenant : {uid, plan} (uid 0 = premier véhicule) ; vide si rien.
func atelier_possible() -> Dictionary:
	if en_kit:
		var p := plan_possible(null)
		return {"uid": 0, "plan": p} if p != "" else {}
	if pieces_stock.is_empty() or raison_atelier() != "":
		return {}
	for v in convoi:
		if v.actif() and v.garage == 0:
			var p := plan_possible(v)
			if p != "":
				return {"uid": v.uid, "plan": p}
	return {}


# Assemble (ou transforme) un véhicule selon l'assemblage a. uid 0 = nouveau véhicule (premier assemblage).
# Les pièces viennent du véhicule et de la réserve ; celles qui ne servent plus retournent en réserve.
func assembler(uid: int, a: Dictionary) -> bool:
	var raison := raison_atelier()
	if raison != "":
		log_(raison, "alerte")
		return false
	var err := Assemblage.valider(a)
	if not err.is_empty():
		log_("Ça ne roule pas : %s." % err[0].texte, "alerte")
		return false
	var v = trouver(uid) if uid != 0 else null
	if uid != 0 and not (v is Veh and convoi.has(v)):
		return false
	# Plaques de blindage ajoutées : fabriquées avec du métal (valeur du catalogue), non remboursées si on en retire
	var deja := int(v.assemblage.get("plaques", 0)) if v != null else 0
	var cout_plaques: float = maxf(0.0, float(int(a.get("plaques", 0)) - deja)) * float(Assemblage.catalogue().regles.plaque.metal)
	if stocks.metal < cout_plaques:
		log_("Il faut %d métal pour les plaques de blindage." % int(cout_plaques), "alerte")
		return false
	# Pièces disponibles avec leur état : celles du véhicule d'abord (elles restent montées), puis la réserve
	var dispo := []
	if v != null:
		for id in Assemblage.ids(v.assemblage):
			var fam: String = Assemblage.piece(id).get("famille", "")
			dispo.append({"piece": id, "etat": v.ratio(fam) if v.pieces.has(fam) else _etat_arme(v)})
	dispo.append_array(pieces_stock)
	var montees := []
	for id in Assemblage.ids(a):
		var k := -1
		for i in dispo.size():
			if dispo[i].piece == id:
				k = i
				break
		if k < 0:
			log_("Il manque : %s." % Assemblage.piece(id).get("nom", id), "alerte")
			return false
		montees.append(dispo[k])
		dispo.remove_at(k)
	pieces_stock = dispo
	stocks.metal -= cout_plaques
	# État de chaque famille = moyenne des pièces montées
	var somme := {}
	var n := {}
	for e in montees:
		var fam: String = Assemblage.piece(e.piece).famille
		if fam in Assemblage.catalogue().regles.get("pv_chassis", []):
			fam = "chassis"
		somme[fam] = float(somme.get(fam, 0.0)) + float(e.etat)
		n[fam] = int(n.get(fam, 0)) + 1
	var etats := {}
	for fam in somme:
		etats[fam] = somme[fam] / n[fam]
	if v == null:
		var premier := convoi.is_empty()
		v = creer_depuis_assemblage(a, "joueur", 0.0, "", 0)
		appliquer_assemblage(v, a, etats)
		convoi.append(v)
		if premier:
			en_kit = false
			x_tete = v.longueur
			_replacer(true)
			x_tete_prev = x_tete
		else:   # un véhicule neuf, construit dans la grange, prend place en queue de convoi
			v.x = x_tete - 30.0
			_replacer(true)
		v.x_prev = v.x
	else:
		appliquer_assemblage(v, a, etats)
		_aligner_noms(v)
		while v.equipage.size() > int(v.profil.equipage):   # moins de places : les passagers attendent
			v.equipage.pop_back()
			v.noms.pop_back()
			reserve_survivants += 1
	while reserve_survivants > 0 and v.equipage.size() < int(v.profil.equipage):
		v.equipage.append(float(donnees().equipage_pv))
		v.noms.append(_nom_survivant())
		reserve_survivants -= 1
	_replacer(true)
	log_("%s assemblé%s." % [v.nom, "" if v.armes.is_empty() else ", arme montée"], "ok")
	evt({"t": "assemble", "uid": v.uid})
	return true


func _etat_arme(v: Veh) -> float:
	for a in v.armes:
		return v.ratio(a.piece)
	return 1.0


# --- Démontage dans la grange (grille G2, DEC-036) ---------------------------------------
# Un véhicule garé dans un hangar ou une grange, de nuit ou à l'abri d'une tempête, est démonté en un temps de jeu :
# toutes ses pièces (châssis compris, avec leur état) rejoignent la réserve, plus le métal de ferraille du châssis ;
# les survivants valides attendent dans la réserve. Irréversible : on reconstruit pièce par pièce.
func raison_demontage(uid: int) -> String:
	var v = trouver(uid)
	if not (v is Veh) or not convoi.has(v):
		return "Ce véhicule n'est pas dans le convoi."
	if v.garage == 0:
		return "Garez le véhicule dans une grange ou un hangar."
	if donnees().demontage.nuit_ou_tempete and not (monde.nuit() or tempete_active() or tempete_annoncee()):
		return "Il faut attendre la nuit ou une tempête pour travailler à l'abri."
	if not travaux.is_empty():
		return "Un démontage est déjà en cours."
	if convoi.size() <= 1:
		return "Impossible de démonter le dernier véhicule."
	if menace():
		return "Trop dangereux : des ennemis sont proches."
	var mecano := false
	for w in convoi:
		mecano = mecano or w.equipage_vivant() > 0
	if not mecano and reserve_survivants <= 0:
		return "Aucun mécanicien disponible."
	return ""


func ordre_demonter(uid: int) -> bool:
	var r := raison_demontage(uid)
	if r != "":
		log_(r, "alerte")
		return false
	travaux = {"uid": uid, "reste": float(donnees().demontage.duree_s), "total": float(donnees().demontage.duree_s)}
	log_("Démontage de %s commencé." % trouver(uid).nom, "info")
	return true


func _travaux(dt: float) -> void:
	if travaux.is_empty():
		return
	var v = trouver(travaux.uid)
	if not (v is Veh) or not convoi.has(v) or v.garage == 0 or menace():
		travaux = {}
		log_("Démontage interrompu.", "alerte")
		return
	travaux.reste -= dt
	if travaux.reste <= 0.0:
		travaux = {}
		_terminer_demontage(v)


func _terminer_demontage(v: Veh) -> void:
	var etats := {"roulement": v.ratio("roulement"), "suspension": v.ratio("suspension"), "moteur": v.ratio("moteur"),
		"cabine": v.ratio("cabine"), "arme": _etat_arme(v), "attelage": v.ratio("chassis")}
	var res := Assemblage.demonter(v.assemblage, etats)
	pieces_stock.append({"piece": v.assemblage.chassis, "etat": v.ratio("chassis")})
	for p in res.pieces:
		pieces_stock.append(p)
	stocks.metal += float(res.metal)
	reserve_survivants += v.equipage_vivant()
	for b in batiments:
		b.garage.erase(v.uid)
	convoi.erase(v)
	_replacer()
	log_("%s démonté : %d pièces en réserve, +%d métal." % [v.nom, res.pieces.size() + 1, int(res.metal)], "ok")
	evt({"t": "demonte", "uid": v.uid})


# Édition libre (G3) : réservée à la grange, de nuit ou à l'abri d'une tempête, convoi arrêté et sans menace.
func raison_atelier_libre() -> String:
	var r := raison_atelier()
	if r != "":
		return r
	var grange := false
	for v in convoi:
		grange = grange or v.garage != 0
	if not grange:
		return "Garez un véhicule dans une grange ou un hangar pour travailler."
	if donnees().demontage.nuit_ou_tempete and not (monde.nuit() or tempete_active() or tempete_annoncee()):
		return "Il faut attendre la nuit ou une tempête pour travailler à l'abri."
	return ""


# Châssis disponibles en réserve (pour construire un véhicule neuf)
func chassis_en_reserve() -> Array:
	return pieces_stock.filter(func(e): return Assemblage.piece(e.piece).get("famille", "") == "chassis").map(func(e): return e.piece)


# Rencontre scriptée de l'ouverture (ou vide si l'ouverture est finie).
func choix_ouverture() -> Dictionary:
	if not ouverture_en_cours():
		if ouverture and not calme_ouverture() and not _fin_annoncee:
			_fin_annoncee = true
			log_("Des moteurs grondent au loin. Vous n'êtes plus seuls sur la route.", "alerte")
		return {}
	var e: Dictionary = ouv().etapes[etape_ouverture]
	etape_ouverture += 1
	return e


# --- Grille libre (DEC-043) ------------------------------------------------------------------
# Accessible à tout moment, pour chaque véhicule : l'écran met le jeu en pause pendant l'édition.
# Un véhicule historique est converti en construction libre à l'ouverture de sa grille (châssis d'origine,
# essieux sous ses roues, mêmes moteur, cabine et armes). Bac à sable : toutes les pièces, sans limite, métal infini.

# Grille actuelle d'un véhicule (uid 0 = véhicule neuf, grille vide)
func grille_de(uid: int) -> Dictionary:
	var v = trouver(uid) if uid != 0 else null
	if v is Veh:
		return ConstructionLibre.convertir(v.assemblage, v.type)
	return ConstructionLibre.nouvelle("Frankenstein %d" % (convoi.size() + 1))


func raison_grille(uid: int) -> String:
	if en_kit:
		return "Assemblez d'abord la moto."
	if fini:
		return "La partie est terminée."
	if uid != 0:
		var v = trouver(uid)
		if not (v is Veh and convoi.has(v)):
			return "Ce véhicule n'est pas dans le convoi."
	return ""


# Pièces mécaniques utilisables sur la grille : [{id, n}] ; n = -1 : sans limite (bac à sable)
func palette_grille(uid: int) -> Array:
	var res := []
	var fams: Array = ConstructionLibre.FAMILLES_PIECES
	if bac_a_sable:
		for id in Assemblage.catalogue().pieces:
			var f := Assemblage.piece(id)
			if f.get("famille", "") in fams and f.has("emprise"):
				res.append({"id": id, "n": -1})
	else:
		var liste := ids_stock()
		if uid != 0:
			liste += Assemblage.ids(grille_de(uid))
		var c := Assemblage.compter(liste)
		for id in c:
			if Assemblage.piece(id).get("famille", "") in fams and Assemblage.piece(id).has("emprise"):
				res.append({"id": id, "n": int(c[id])})
	var ordre := {"moteur": 0, "cabine": 1, "arme": 2, "equipement": 3}
	res.sort_custom(func(p, q):
		var fp := Assemblage.piece(p.id)
		var fq := Assemblage.piece(q.id)
		if fp.famille != fq.famille:
			return ordre[fp.famille] < ordre[fq.famille]
		return float(fp.get("poids_kg", 0)) < float(fq.get("poids_kg", 0)))
	return res


# Métal à payer pour passer de la grille actuelle à a (0 en bac à sable). Rien n'est remboursé en retirant.
func cout_grille(uid: int, a: Dictionary) -> float:
	if bac_a_sable:
		return 0.0
	var avant := grille_de(uid)
	var cout := maxf(0.0, ConstructionLibre.cout_metal(a) - ConstructionLibre.cout_metal(avant))
	var dp := maxi(0, int(a.get("plaques", 0)) - int(avant.get("plaques", 0)))
	return cout + dp * float(Assemblage.catalogue().regles.plaque.metal)


# Construit (uid 0) ou reconstruit un véhicule selon la grille a. Renvoie false (et un message) si impossible.
func construire_grille(uid: int, a: Dictionary) -> bool:
	var r := raison_grille(uid)
	if r != "":
		log_(r, "alerte")
		return false
	var err := ConstructionLibre.erreurs(a)
	if not err.is_empty():
		log_(String(err[0].texte) + ".", "alerte")
		return false
	var v = trouver(uid) if uid != 0 else null
	var avant := grille_de(uid)
	var etats := {}
	if v != null:
		for fam in PIECES_BASE:
			if v.pieces.has(fam):
				etats[fam] = v.ratio(fam)
		if not v.armes.is_empty():
			etats.arme = _etat_arme(v)
	if not bac_a_sable:
		var cout := cout_grille(uid, a)
		if stocks.metal < cout:
			log_("Il faut %d métal (vous en avez %d)." % [int(ceil(cout)), int(stocks.metal)], "alerte")
			return false
		var manque := Assemblage.manquantes(a, Assemblage.ids(avant) + ids_stock())
		if not manque.is_empty():
			log_("Il manque : %s." % Assemblage.piece(manque[0]).get("nom", manque[0]), "alerte")
			return false
		var reste := Assemblage.compter(Assemblage.ids(a))
		for id in Assemblage.ids(avant):   # pièces du véhicule : réutilisées d'abord, sinon rangées en réserve
			if int(reste.get(id, 0)) > 0:
				reste[id] -= 1
			else:
				var fam: String = Assemblage.piece(id).get("famille", "")
				pieces_stock.append({"piece": id, "etat": float(etats.get(fam, 1.0))})
		for id in reste:
			for k in int(reste[id]):
				for i in pieces_stock.size():
					if pieces_stock[i].piece == id:
						pieces_stock.remove_at(i)
						break
		stocks.metal -= cout
	if v == null:
		var premier := convoi.is_empty()
		v = creer_depuis_assemblage(a, "joueur", 0.0, "", 0)
		convoi.append(v)
		v.x = x_tete - 30.0 if not premier else 0.0
		if premier:
			x_tete = v.longueur
	else:
		appliquer_assemblage(v, a, etats)
		_aligner_noms(v)
		while v.equipage.size() > int(v.profil.equipage):   # moins de places : les passagers attendent
			v.equipage.pop_back()
			v.noms.pop_back()
			reserve_survivants += 1
	var D := donnees()
	while v.equipage.size() < int(v.profil.equipage) and (reserve_survivants > 0 or bac_a_sable):
		v.equipage.append(float(D.equipage_pv))
		v.noms.append(_nom_survivant())
		if reserve_survivants > 0:
			reserve_survivants -= 1
	_replacer(true)
	v.x_prev = v.x
	var p: Dictionary = v.profil
	log_("%s construit%s." % [v.nom, "" if float(p.vitesse) > 0.0 else " : il ne roule pas (%s)" % p.get("immobile", "")], "ok" if float(p.vitesse) > 0.0 else "alerte")
	evt({"t": "assemble", "uid": v.uid})
	return true
