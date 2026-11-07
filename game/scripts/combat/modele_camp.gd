extends "res://scripts/combat/modele_atelier.gd"
# Camp de réparation en route (DEV-018, DEC-129). Couche du modèle de combat : le convoi s'arrête, un véhicule est immobilisé,
# des attaques tombent pendant les travaux (elles les suspendent), et la pièce est changée à la fin, depuis la réserve (pieces_stock).
# La logique des durées, attaques et de l'atomicité est dans CampReparation ; ici on ne fait que la brancher sur le modèle.
# Véhicules d'origine (Veh) : essieu ou roue = pièce « roulement », moteur = pièce « moteur ». La boîte n'existe que sur les bases.

var camp_rep := {}          # {"uid", "camp": CampReparation, "ennemis": [uid]} ; vide = pas de camp


func camp_actif() -> bool:
	return not camp_rep.is_empty()


# Opérations de camp possibles pour un véhicule, avec leur raison si elles sont impossibles : [{op, nom, params, ok, raison, duree_s}]
func camp_options(uid: int) -> Array:
	var res := []
	var v = trouver(uid)
	if not (v is Veh) or not convoi.has(v):
		return res
	var a := grille_de(uid)
	var ctx := {"niveau": 0, "atelier_mobile": false}
	var meca := maxi(1, int(v.profil.get("mecaniciens", 0)))
	var essieux: Array = a.get("essieux", [])
	if not essieux.is_empty():
		var e: Dictionary = essieux[0]
		var ess := _meilleure_reserve("essieu")
		var train := String(e.get("train", ""))
		var p := {"x": int(e.x), "essieu": ess, "train": train}
		res.append(_option(v, a, ctx, "changer_essieu", "Changer l'essieu", p, ess == "", "aucun essieu en réserve", meca))
		var tr := _meilleure_reserve("train")
		res.append(_option(v, a, ctx, "changer_roue", "Changer les roues", {"x": int(e.x), "train": tr}, tr == "", "aucune roue en réserve", meca))
	var mo := _meilleure_reserve("moteur")
	res.append(_option(v, a, ctx, "changer_moteur", "Changer le moteur", {"moteur": mo}, mo == "", "aucun moteur en réserve", meca))
	return res


func _option(v, a: Dictionary, ctx: Dictionary, op: String, nom: String, params: Dictionary, sans_piece: bool, raison_sans: String, meca: int) -> Dictionary:
	var r := {"op": op, "nom": nom, "params": params, "ok": true, "raison": "", "duree_s": BaseVehicule.duree_s(op, ctx, meca)}
	if sans_piece:
		r.ok = false
		r.raison = raison_sans
	return r


func _meilleure_reserve(famille: String) -> String:
	var best := ""
	var e_best := -1.0
	for r in pieces_stock:
		if String(Assemblage.piece(String(r.piece)).get("famille", "")) == famille and float(r.etat) > e_best:
			best = String(r.piece)
			e_best = float(r.etat)
	return best


# Établit le camp : le convoi s'arrête, le véhicule est immobilisé jusqu'à la fin des travaux.
func camp_etablir(uid: int, op: String, params: Dictionary) -> bool:
	if camp_actif():
		log_("Un camp est déjà installé.", "alerte")
		return false
	var r := raison_grille(uid)
	if r != "":
		log_(r, "alerte")
		return false
	var v = trouver(uid)
	if not ennemis.filter(func(e): return e.actif()).is_empty():
		log_("Impossible d'établir un camp avec des ennemis en vue.", "alerte")
		return false
	var meca := maxi(1, int(v.profil.get("mecaniciens", 0)))
	var d := CampReparation.demarrer(op, params, grille_de(uid), pieces_stock, {"niveau": 0, "atelier_mobile": false}, meca, monde.niveau_a(x_tete), graine * 31 + int(temps))
	if not bool(d.ok):
		log_(String(d.raison) + ".", "alerte")
		return false
	camp_rep = {"uid": uid, "camp": d.camp, "ennemis": []}
	ordres.marche = "halte"
	log_("%s : camp établi, %d min de travaux. Défendez-le." % [v.nom, int(ceil(float(d.camp.duree_s) / 60.0))], "alerte")
	evt({"t": "camp", "uid": uid, "etat": "etabli"})
	return true


func camp_interrompre() -> void:
	if camp_actif():
		camp_rep.camp = CampReparation.interrompre(camp_rep.camp)
		log_("Travaux interrompus : le véhicule reste immobilisé.", "info")


func camp_reprendre() -> void:
	if camp_actif():
		camp_rep.camp = CampReparation.reprendre(camp_rep.camp)


# Un pas de simulation (appelé par avancer)
func _camp(dt: float) -> void:
	if not camp_actif():
		return
	var C: Dictionary = camp_rep.camp
	for at in CampReparation.attaques_dues(C, dt) if C.etat == "en_cours" else []:
		_camp_attaque(float(at.force))
	var en_cours := not ennemis.filter(func(e): return e.actif()).is_empty()
	camp_rep.camp = CampReparation.avancer(C, dt, en_cours)
	if camp_rep.camp.etat == "pret" and not en_cours:
		_camp_terminer()


func _camp_attaque(force: float) -> void:
	var niveau := monde.niveau_a(x_tete)
	var liste := []
	for e in donnees().rencontres.liste:
		if niveau >= int(e.niveau_min) and niveau <= int(e.niveau_max) and not e.get("vehicules", []).is_empty() and String(e.get("mode", "")) != "poursuite":
			liste.append(e)
	var type := "citroen_traction"
	if not liste.is_empty():
		type = String(liste[int(force * 10.0) % liste.size()].vehicules[0])
	var n := 1 if force < 2.0 else 2
	for i in n:
		var e := creer_vehicule(type, "ennemi", x_tete + 120.0 + 12.0 * i)
		e.mode = "approche"
		ennemis.append(e)
		camp_rep.ennemis.append(e.uid)
	log_("Attaque sur le camp ! %d véhicule(s) ennemi(s)." % n, "alerte")
	evt({"t": "contact", "ennemi": true})


# Fin des travaux : la pièce est changée (atomique), la réserve mise à jour, le convoi peut repartir.
func _camp_terminer() -> void:
	var uid := int(camp_rep.uid)
	var v = trouver(uid)
	var fin := CampReparation.terminer(camp_rep.camp, grille_de(uid), pieces_stock)
	if not bool(fin.ok):
		log_(String(fin.raison) + ".", "alerte")
		camp_rep = {}
		return
	pieces_stock = fin.reserve
	if v is Veh:
		var op := String(camp_rep.camp.op)
		var P: Dictionary = camp_rep.camp.params
		if op == "changer_essieu" or op == "changer_roue":
			var e := ConstructionLibre.essieu_en(fin.a, int(P.x))
			v.pieces.roulement.pv = v.pieces.roulement.max * clampf(float(e.get("etat", 1.0)), 0.1, 1.0)
			v.roues_perdues.clear()
		elif op == "changer_moteur":
			v.pieces.moteur.pv = v.pieces.moteur.max * clampf(_etat_moteur(fin.a), 0.1, 1.0)
		log_("%s : réparation terminée, le convoi peut repartir." % v.nom, "ok")
	evt({"t": "camp", "uid": uid, "etat": "termine"})
	camp_rep = {}


# État du moteur posé, lu dans la grille après l'opération
func _etat_moteur(a: Dictionary) -> float:
	for p in a.pieces:
		if String(Assemblage.piece(String(p.piece)).get("famille", "")) == "moteur":
			return float(p.get("etat", 1.0))
	return 1.0
