# Camp de réparation sur la route (Grille V2). Le convoi s'arrête et établit un camp pour changer un essieu, une roue,
# le moteur ou la boîte : c'est long, le véhicule reste immobilisé, et il faut défendre le camp. Les transformations lourdes
# (rallonge, essieu ajouté) restent réservées au garage (BaseVehicule.permis). Modèle pur, sans écran ; l'intégration au monde
# (alerte à droite, ennemis, abri) lit attaques_dues() et appelle avancer().
#
# Camp : {"op", "params", "duree_s", "restant_s", "t", "etat": "en_cours" | "interrompue" | "pret" | "terminee",
#         "immobilise", "attaques": [{t, force}]}.
# Réserve : Array de {"piece": id, "etat": 0 à 1}. Terminer est atomique : tout réussit, ou rien ne change.
class_name CampReparation
extends RefCounted

const OPS_CAMP := ["changer_roue", "changer_essieu", "changer_moteur", "changer_boite"]


# Pièces à prendre dans la réserve pour une opération
static func pieces_requises(op: String, params: Dictionary, a: Dictionary) -> Array:
	var res := []
	if op == "changer_essieu":
		res.append(String(params.essieu))
		if String(ConstructionLibre.essieu_en(a, int(params.x)).get("train", "")) != String(params.train):
			res.append(String(params.train))
	elif op == "changer_roue":
		res.append(String(params.train))
	elif op == "changer_moteur":
		res.append(String(params.moteur))
	return res


static func _compter(reserve: Array, id: String) -> int:
	var n := 0
	for r in reserve:
		if String(r.piece) == id:
			n += 1
	return n


# Retire de la réserve (copie) la meilleure pièce d'identifiant id : {"ok", "reserve", "etat"}
static func _prendre(reserve: Array, id: String) -> Dictionary:
	var meilleur := -1
	for i in reserve.size():
		if String(reserve[i].piece) == id and (meilleur < 0 or float(reserve[i].etat) > float(reserve[meilleur].etat)):
			meilleur = i
	if meilleur < 0:
		return {"ok": false, "reserve": reserve, "etat": 0.0}
	var copie := reserve.duplicate(true)
	var etat := float(copie[meilleur].etat)
	copie.remove_at(meilleur)
	return {"ok": true, "reserve": copie, "etat": etat}


# Attaques prévues pendant un camp (graine explicite) : le camp dure plus que la réparation puisque les attaques la suspendent
static func attaques_prevues(duree_s: float, niveau_secteur: int, graine: int) -> Array:
	var C: Dictionary = BaseVehicule.regles().camp
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var res := []
	var t := float(C.attaque_intervalle_s) * 0.5 + rng.randf() * float(C.attaque_alea_s)
	while t < duree_s * 2.5 and res.size() < 40:
		res.append({"t": t, "force": float(C.force_base) + float(C.force_par_niveau_secteur) * float(niveau_secteur) + rng.randf() * float(C.force_alea)})
		t += float(C.attaque_intervalle_s) + rng.randf() * float(C.attaque_alea_s)
	return res


# contexte : {niveau, atelier_mobile} ; mecaniciens : survivants qui réparent. {"ok", "raison", "camp"}
static func demarrer(op: String, params: Dictionary, a: Dictionary, reserve: Array, contexte: Dictionary, mecaniciens: int, niveau_secteur: int, graine: int) -> Dictionary:
	if not op in OPS_CAMP:
		return {"ok": false, "raison": "cette opération ne se fait pas en camp : garage requis"}
	var p := BaseVehicule.permis(op, contexte)
	if not bool(p.ok):
		return {"ok": false, "raison": String(p.raison)}
	var manque := []
	var vues := {}
	for id in pieces_requises(op, params, a):
		vues[id] = int(vues.get(id, 0)) + 1
		if _compter(reserve, String(id)) < int(vues[id]):
			manque.append(String(id))
	if not manque.is_empty():
		return {"ok": false, "raison": "pièce(s) manquante(s) : %s" % ", ".join(manque), "manque": manque}
	var d := BaseVehicule.duree_s(op, contexte, mecaniciens)
	return {"ok": true, "raison": "", "camp": {"op": op, "params": params.duplicate(true), "duree_s": d, "restant_s": d, "t": 0.0,
		"etat": "en_cours", "immobilise": true, "attaques": attaques_prevues(d, niveau_secteur, graine)}}


# Attaques qui tombent dans les dt prochaines secondes (temps du camp)
static func attaques_dues(camp: Dictionary, dt: float) -> Array:
	var res := []
	for at in camp.attaques:
		if float(at.t) > float(camp.t) and float(at.t) <= float(camp.t) + dt:
			res.append(at)
	return res


# Fait avancer le temps. Pendant une attaque (attaque_en_cours), les mécaniciens défendent : la réparation n'avance pas.
static func avancer(camp: Dictionary, dt: float, attaque_en_cours: bool) -> Dictionary:
	var c := camp.duplicate(true)
	if c.etat != "en_cours":
		return c
	c.t = float(c.t) + dt
	if not attaque_en_cours:
		c.restant_s = maxf(0.0, float(c.restant_s) - dt)
		if float(c.restant_s) <= 0.0:
			c.etat = "pret"
	return c


# Interrompre (départ forcé, fuite) : le travail fait est conservé, le véhicule reste immobilisé
static func interrompre(camp: Dictionary) -> Dictionary:
	var c := camp.duplicate(true)
	if c.etat == "en_cours":
		c.etat = "interrompue"
	return c


static func reprendre(camp: Dictionary) -> Dictionary:
	var c := camp.duplicate(true)
	if c.etat == "interrompue":
		c.etat = "en_cours"
	return c


# Applique le résultat. Atomique : {"ok", "a", "reserve", "camp", "raison"} ; en cas d'échec rien n'est modifié.
static func terminer(camp: Dictionary, a: Dictionary, reserve: Array) -> Dictionary:
	if camp.etat != "pret":
		return {"ok": false, "a": a, "reserve": reserve, "camp": camp, "raison": "la réparation n'est pas finie"}
	var op := String(camp.op)
	var P: Dictionary = camp.params
	var res := reserve
	var etats := {}
	for id in pieces_requises(op, P, a):
		var t := _prendre(res, String(id))
		if not bool(t.ok):
			return {"ok": false, "a": a, "reserve": reserve, "camp": camp, "raison": "pièce manquante : %s" % id}
		res = t.reserve
		etats[String(id)] = float(t.etat)
	var r := {}
	if op == "changer_essieu":
		r = BaseVehicule.changer_essieu(a, int(P.x), String(P.essieu), String(P.train), float(etats.get(String(P.essieu), 1.0)))
	elif op == "changer_roue":
		r = BaseVehicule.changer_roue(a, int(P.x), String(P.train), float(etats.get(String(P.train), 1.0)))
	elif op == "changer_moteur":
		r = BaseVehicule.changer_moteur(a, String(P.moteur), float(etats.get(String(P.moteur), 1.0)))
	elif op == "changer_boite":
		r = BaseVehicule.changer_boite(a, String(P.boite), float(P.get("etat", 1.0)))
	if r.is_empty() or not bool(r.ok):
		return {"ok": false, "a": a, "reserve": reserve, "camp": camp, "raison": String(r.get("raison", "opération impossible"))}
	for pr in r.get("retire", []):
		if float(pr.etat) > 0.05 and op != "changer_boite":
			res = res.duplicate(true)
			res.append({"piece": String(pr.piece), "etat": float(pr.etat)})
	var fin := camp.duplicate(true)
	fin.etat = "terminee"
	fin.immobilise = false
	return {"ok": true, "a": r.a, "reserve": res, "camp": fin, "raison": ""}
