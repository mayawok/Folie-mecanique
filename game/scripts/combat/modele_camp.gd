extends "res://scripts/combat/modele_atelier.gd"
# Camp de réparation en route (DEV-018, DEC-129). Couche du modèle de combat : le convoi s'arrête, un véhicule est immobilisé,
# des attaques tombent pendant les travaux (elles les suspendent), et la pièce est changée à la fin, depuis la réserve (pieces_stock).
# La logique des durées, attaques et de l'atomicité est dans CampReparation ; ici on ne fait que la brancher sur le modèle.
# Véhicules d'origine (Veh) : essieu ou roue = pièce « roulement », moteur = pièce « moteur ». La boîte n'existe que sur les bases.

var camp_rep := {}          # {"uid", "camp": CampReparation, "ennemis": [uid]} ; vide = pas de camp
var pannes_on := false      # pannes en route (DEV-019) : option « pannes » du modèle
var _km_pannes := -1        # dernier kilomètre déjà tiré ; -1 = recaler sur la position (nouvelle partie ou reprise)
const ORGANE_PIECE := {"moteur": "moteur", "boite": "moteur", "essieu": "roulement", "chassis": "chassis"}
const NOMS_PANNE := {"moteur": "panne de moteur", "boite": "boîte de vitesses qui lâche", "essieu": "essieu fendu", "chassis": "châssis fissuré"}


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


# Pannes en route (DEV-019, DEC-123) : à chaque kilomètre parcouru, FiabiliteVehicule tire les pannes de chaque véhicule
# du convoi (graine explicite : partie, kilomètre, véhicule). Une panne abîme la pièce (40 % au plus) sans la détruire :
# le convoi peut continuer lentement, réparer à l'arrêt ou établir un camp pour changer la pièce depuis la réserve.
func _pannes() -> void:
	if not pannes_on or camp_actif():
		return
	var k := int(floor(maxf(0.0, x_tete) / 1000.0))
	if _km_pannes < 0:
		_km_pannes = k
		return
	while _km_pannes < k:
		_km_pannes += 1
		for v in convoi:
			if v.statut != "actif" or v.remorque():
				continue
			for pn in FiabiliteVehicule.tirer_pannes(grille_de(v.uid), float(regime_donnees().usure), graine * 7919 + _km_pannes * 131 + v.uid):
				appliquer_panne(v, String(pn.organe))


func appliquer_panne(v, organe: String) -> void:
	var id := String(ORGANE_PIECE.get(organe, ""))
	if id == "" or not v.pieces.has(id):
		return
	var P: Dictionary = v.pieces[id]
	P.pv = minf(float(P.pv), float(P.max) * 0.4)
	log_("%s : %s." % [v.nom, NOMS_PANNE.get(organe, "panne")], "alerte")
	evt({"t": "panne", "uid": v.uid, "organe": organe})


# Un pas de simulation (appelé par avancer)
func _camp(dt: float) -> void:
	_pannes()
	_halte(dt)
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


# --- Transformation d'une base dans la partie (DEV-016, DEC-121, DEC-128) -------------------------------------
# Niveau du lieu : 2 = atelier d'une ville (checkpoint), 1 = véhicule garé dans un hangar ou une grange, 0 = sur la route.
func transformation_contexte(uid: int) -> Dictionary:
	var v = trouver(uid)
	var niveau := 0
	if ville_protegee():
		niveau = 2
	elif v is Veh and int(v.garage) != 0:
		niveau = 1
	var meca := maxi(1, int(v.profil.get("mecaniciens", 0))) if v is Veh else 1
	return {"niveau": niveau, "atelier_mobile": false, "mecaniciens": meca, "metal": float(stocks.metal),
		"reserve": pieces_stock.duplicate(true), "bac_a_sable": bac_a_sable}


# Applique le résultat de l'écran de transformation : la grille passe par construire_grille (pièces, réserve, coût de la grille),
# puis le métal propre aux transformations (rallonge, renforts, modules) est retiré s'il dépasse ce qui a déjà été payé. Atomique :
# rien ne change si le métal manque ou si la grille est refusée.
func transformer(uid: int, a: Dictionary, metal: float, duree_s: float) -> bool:
	if not bac_a_sable and float(stocks.metal) < metal:
		log_("Il faut %d métal (vous en avez %d)." % [int(ceil(metal)), int(stocks.metal)], "alerte")
		return false
	var avant := float(stocks.metal)
	if not construire_grille(uid, a):
		return false
	if not bac_a_sable:
		var deja := avant - float(stocks.metal)
		stocks.metal = maxf(0.0, float(stocks.metal) - maxf(0.0, metal - deja))
	var v = trouver(uid)
	log_("%s transformé : %d min de travaux." % [v.nom if v != null else "Véhicule", int(ceil(duree_s / 60.0))], "info")
	return true


# --- Halte dans la nature (DEV-031, DEC-161) -------------------------------------------------------------------
# Convoi arrêté hors d'une ville : « bivouac » (camp qui se monte peu à peu, nuit possible), « garde » (tous aux aguets,
# les mécaniciens réparent), « embuscade » (débarquer et camoufler, voir la vue), éclaireurs et caches.
# Valeurs dans combat_proto.json → halte.
var halte := {}             # {"mode": "bivouac"|"garde", "t": s, "pret": bool, "nuit": bool} ; vide = aucune
var caches: Array = []      # [{"x", "res": {stock: qté}, "pillee": bool|null}] (DEC-157)
var _eclaireurs_t := 0.0    # > 0 : éclaireurs partis, rapport dans … s

func H() -> Dictionary:
	return donnees().get("halte", {"montage_s": 25.0, "eclaireurs_s": 20.0, "eclaireurs_portee_m": 700.0, "cache_pillage": 0.25, "cache_rayon_m": 25.0})


func halte_possible() -> String:
	if bool(call("ville_dedans")) or ville_protegee():
		return "En ville, le convoi est déjà à l'abri."
	if not ennemis.filter(func(e): return e.actif()).is_empty():
		return "Impossible : des ennemis sont en vue."
	return ""


func halte_bivouac(passer_la_nuit := false) -> bool:
	var r := halte_possible()
	if r != "":
		log_(r, "alerte")
		return false
	ordres.marche = "halte"
	halte = {"mode": "bivouac", "t": 0.0, "pret": false, "nuit": passer_la_nuit}
	log_("Halte : l'équipage descend et monte le camp. Les mitrailleurs restent à leur poste.", "info")
	evt({"t": "halte", "mode": "bivouac"})
	return true


func halte_garde() -> bool:
	var r := halte_possible()
	if r != "":
		log_(r, "alerte")
		return false
	ordres.marche = "halte"
	halte = {"mode": "garde", "t": 0.0, "pret": true, "nuit": false}
	for v in convoi:
		if v.actif():
			v.reparation = true   # les mécaniciens travaillent, les autres restent aux aguets
	log_("Halte : tout le monde aux aguets, les mécaniciens réparent.", "info")
	return true


func halte_lever() -> void:
	if halte.is_empty():
		return
	halte = {}
	log_("On lève le camp.", "info")


# Repos de nuit au bivouac monté : la nuit passe plus vite (comme à l'abri)
func halte_repos() -> bool:
	return not halte.is_empty() and halte.mode == "bivouac" and bool(halte.pret) and bool(halte.nuit)


func _halte(dt: float) -> void:
	if halte.is_empty():
		return
	if ordres.marche != "halte":
		halte = {}   # le convoi repart : le camp est levé
		return
	halte.t += dt
	if not halte.pret and halte.t >= float(H().montage_s):
		halte.pret = true
		log_("Le camp est monté : tentes dressées, feu allumé.", "ok")
	if halte.mode == "bivouac" and not ennemis.filter(func(e): return e.actif()).is_empty() and bool(halte.pret):
		halte.nuit = false   # alerte : personne ne dort
	if _eclaireurs_t > 0.0:
		_eclaireurs_t -= dt
		if _eclaireurs_t <= 0.0:
			_eclaireurs_rapport()


func envoyer_eclaireurs() -> bool:
	if ordres.marche != "halte" or halte.is_empty():
		log_("Les éclaireurs partent seulement pendant une halte.", "alerte")
		return false
	if _eclaireurs_t > 0.0:
		return false
	_eclaireurs_t = float(H().eclaireurs_s)
	log_("Deux éclaireurs partent à pied reconnaître le secteur.", "info")
	return true


# Rapport : prochaine présence ennemie, niveau du secteur, bâtiments en vue. Rien d'aléatoire : c'est ce qui est vraiment devant.
func eclaireurs_rapport_texte() -> String:
	var portee := float(H().eclaireurs_portee_m)
	var morceaux := []
	var niv := monde.niveau_a(x_tete + portee * 0.5)
	morceaux.append(["secteur calme", "secteur peu sûr", "secteur dangereux", "secteur très dangereux"][clampi(niv / 2, 0, 3)])
	var d := float(get("_prochain_x")) - x_tete
	if d < portee and is_finite(d):
		morceaux.append("traces de véhicules à %d m" % int(maxf(0.0, d)))
	else:
		morceaux.append("rien sur %d m" % int(portee))
	var bats := batiments.filter(func(b): return b.x > x_tete and b.x < x_tete + portee)
	if not bats.is_empty():
		morceaux.append("%d bâtiment(s) devant" % bats.size())
	return "Les éclaireurs reviennent : " + ", ".join(morceaux) + "."


func _eclaireurs_rapport() -> void:
	_eclaireurs_t = 0.0
	log_(eclaireurs_rapport_texte(), "alerte")
	evt({"t": "eclaireurs"})


# Cache (DEC-157) : on enterre une part des réserves ici ; au retour, elle a pu être pillée (tirage à graine fixe).
func cache_creer(res: Dictionary) -> bool:
	if ordres.marche != "halte":
		log_("Arrêtez le convoi pour faire une cache.", "alerte")
		return false
	for k in res:
		if float(stocks.get(k, 0.0)) < float(res[k]):
			log_("Pas assez de réserves pour cette cache.", "alerte")
			return false
	for k in res:
		stocks[k] = float(stocks[k]) - float(res[k])
	caches.append({"x": x_tete, "res": res.duplicate(), "pillee": null})
	log_("Cache enterrée au kilomètre %d." % int(x_tete / 1000.0), "ok")
	return true


func cache_proche() -> int:
	for i in caches.size():
		if absf(float(caches[i].x) - x_tete) <= float(H().cache_rayon_m):
			return i
	return -1


func cache_reprendre() -> bool:
	var i := cache_proche()
	if i < 0:
		return false
	var c: Dictionary = caches[i]
	var rr := RandomNumberGenerator.new()
	rr.seed = graine * 4243 + int(c.x)
	caches.remove_at(i)
	if rr.randf() < float(H().cache_pillage):
		log_("La cache a été fouillée : il ne reste rien.", "alerte")
		return true
	for k in c.res:
		stocks[k] = float(stocks.get(k, 0.0)) + float(c.res[k])
	log_("Cache retrouvée intacte.", "ok")
	return true
