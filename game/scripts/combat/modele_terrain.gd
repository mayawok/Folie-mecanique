# Couche 2 du modèle : embuscade (garnison, mines, camouflage), garage, fouille.
extends "res://scripts/combat/modele_tir.gd"


# --- Ordres ----------------------------------------------------------------
func _recruter_survivant() -> bool:
	for v in convoi:
		if v.actif() and v.equipage.size() < int(v.profil.equipage):
			_aligner_noms(v)
			v.equipage.append(float(donnees().equipage_pv))
			v.noms.append(_nom_survivant())
			return true
	for v in convoi:
		if v.actif():
			for i in v.equipage.size():
				if v.equipage[i] <= 0.0:
					v.equipage[i] = float(donnees().equipage_pv)
					_aligner_noms(v)
					v.noms[i] = _nom_survivant()
					return true
	reserve_survivants += 1   # pas de place : il suivra à pied jusqu'au prochain véhicule
	return true


# --- Garage (hangar, grange) : à l'abri et réparé pendant la nuit -----------------
func abri_garage():
	var meilleur = null
	var g_min := 45.0
	for b in batiments:
		if b.garage_max > 0 and b.statut == "neutralise" and b.pv > 0.0 and b.garage.size() < b.garage_max:
			var g: float = ecart(x_tete - 1.0, 1.0, b.x, b.longueur)
			if g < g_min:
				g_min = g
				meilleur = b
	return meilleur

func ordre_garer(uid: int) -> bool:
	var v = trouver(uid)
	if not (v is Veh) or not convoi.has(v) or v.garage != 0:
		return false
	var b = abri_garage()
	if b == null:
		log_("Aucun hangar ni grange à portée avec une place libre.", "alerte")
		return false
	v.garage = b.uid
	v.camo_voulu = false
	v.camoufle = false
	b.garage.append(uid)
	log_("%s rentre dans %s : à l'abri et en réparation." % [v.nom, b.nom], "ok")
	evt({"t": "garage", "uid": b.uid})
	return true

func ordre_sortir(uid: int) -> bool:
	var v = trouver(uid)
	if not (v is Veh) or v.garage == 0:
		return false
	var b = trouver(v.garage)
	if b is Bat:
		b.garage.erase(uid)
	v.garage = 0
	log_("%s sort du garage." % v.nom, "info")
	return true

func _garage(dt: float) -> void:
	var G: Dictionary = donnees().garage
	for b in batiments:
		if b.garage.is_empty():
			continue
		for uid in b.garage.duplicate():
			var v = trouver(uid)
			if not (v is Veh) or not convoi.has(v):
				b.garage.erase(uid)
				continue
			if b.pv <= 0.0:   # le bâtiment s'effondre : les véhicules en sortent abîmés
				v.garage = 0
				v.pieces.chassis.pv *= 0.6
				b.garage.erase(uid)
				continue
			var complet := true
			for pid in v.pieces:
				var pc: Dictionary = v.pieces[pid]
				if pc.pv <= 0.0:
					pc.pv = minf(pc.max * G.plafond_detruite, pc.pv + G.pv_detruite_s * dt + 0.001)
					complet = false
				elif pc.pv < pc.max:
					pc.pv = minf(pc.max, pc.pv + G.pv_s * dt)
					complet = false
				elif pc.pv < pc.max * G.plafond_detruite:
					complet = false
			if complet and not v.get_meta("repare_dit", false):
				v.set_meta("repare_dit", true)
				log_("%s est remis en état." % v.nom, "ok")


# --- Embuscade : garnison, mines, camouflage -------------------------------
func _en_route(b: Bat) -> int:
	var n := 0
	for t in transits:
		if t.mode == "debarque" and t.bat == b.uid:
			n += t.pvs.size()
	return n

func _refuge_pour(v: Veh):
	var E: Dictionary = donnees().embuscade
	var meilleur = null
	var g_min := INF
	for b in batiments:
		if b.statut == "neutralise" and b.pv > 0.0 and b.garnison.size() + _en_route(b) < FENETRES[b.type].size():
			var g := ecart(v.x, v.longueur, b.x, b.longueur)
			if g <= E.portee_refuge and g < g_min:
				g_min = g
				meilleur = b
	return meilleur

func ordre_debarquer(uid: int) -> bool:
	var v = trouver(uid)
	if not (v is Veh) or not convoi.has(v) or v.equipage_vivant() == 0:
		return false
	var b = _refuge_pour(v)
	if b == null:
		log_("Aucun bâtiment à portée pour s'abriter (ruine, ferme, église...).", "alerte")
		return false
	var libres: int = FENETRES[b.type].size() - b.garnison.size() - _en_route(b)
	var pvs := []
	var reste := []
	var noms_p := []
	var noms_r := []
	_aligner_noms(v)
	for i in v.equipage.size():
		if v.equipage[i] > 0.0 and pvs.size() < libres:
			pvs.append(v.equipage[i])
			noms_p.append(v.noms[i])
		else:
			reste.append(v.equipage[i])
			noms_r.append(v.noms[i])
	v.equipage = reste
	v.noms = noms_r
	var T: float = ecart(v.x, v.longueur, b.x, b.longueur) / donnees().embuscade.vitesse_marche + 1.0
	transits.append({"mode": "debarque", "veh": uid, "bat": b.uid, "pvs": pvs, "noms": noms_p, "restant": T, "T": T})
	log_("L'équipage de %s rejoint %s." % [v.nom, b.nom], "info")
	return true

func ordre_rembarquer(uid: int) -> bool:
	var v = trouver(uid)
	if not (v is Veh) or not convoi.has(v):
		return false
	var fait := false
	for b in batiments:
		var sortants := []
		var noms_s := []
		var restants := []
		for g in b.garnison:
			if g.veh == uid and g.pv > 0.0:
				sortants.append(g.pv)
				noms_s.append(g.get("nom", "Survivant"))
			else:
				restants.append(g)
		if not sortants.is_empty():
			b.garnison = restants
			var T: float = ecart(v.x, v.longueur, b.x, b.longueur) / donnees().embuscade.vitesse_marche + 1.0
			transits.append({"mode": "rembarque", "veh": uid, "bat": b.uid, "pvs": sortants, "noms": noms_s, "restant": T, "T": T})
			fait = true
	if fait:
		log_("L'équipage de %s regagne son véhicule." % v.nom, "info")
	return fait

func a_garnison(uid: int) -> bool:
	for b in batiments:
		for g in b.garnison:
			if g.veh == uid:
				return true
	for t in transits:
		if t.veh == uid and t.mode == "debarque":
			return true
	return false

func _slot_libre(b: Bat) -> int:
	var pris := {}
	for g in b.garnison:
		pris[g.slot] = true
	var i := 0
	while pris.has(i):
		i += 1
	return i

func _transits(dt: float) -> void:
	var en_cours := []
	for t in transits:
		t.restant -= dt
		if t.restant > 0.0:
			en_cours.append(t)
			continue
		if t.mode == "debarque":
			var b = trouver(t.bat)
			if b is Bat and b.pv > 0.0:
				for i in t.pvs.size():
					var pv: float = t.pvs[i]
					b.garnison.append({"nom": t.noms[i], "pv": pv, "cd": rng.randf_range(0.5, 1.5), "veh": t.veh, "premier": true, "garde": true, "slot": _slot_libre(b)})
				log_("%d survivant(s) se postent dans %s et attendent l'ennemi." % [t.pvs.size(), b.nom], "ok")
				evt({"t": "poste", "uid": b.uid})
			else:
				var v = trouver(t.veh)
				if v is Veh:
					_aligner_noms(v)
					v.equipage.append_array(t.pvs)
					v.noms.append_array(t.noms)
		else:
			var v = trouver(t.veh)
			if v is Veh:
				_aligner_noms(v)
				v.equipage.append_array(t.pvs)
				v.noms.append_array(t.noms)
				log_("L'équipage de %s a rembarqué." % v.nom, "ok")
	transits = en_cours

func ordre_camoufler(uid: int, actif: bool) -> bool:
	var v = trouver(uid)
	if not (v is Veh) or not convoi.has(v):
		return false
	if actif and v.equipage_vivant() == 0 and not a_garnison(uid):
		return false
	v.camo_voulu = actif
	if not actif:
		v.camoufle = false
		v.camo_t = 0.0
	else:
		log_("%s est camouflé sous des filets et des branchages..." % v.nom, "info")
	return true

func _camouflage(dt: float) -> void:
	var S: float = donnees().embuscade.camo_s
	for v in convoi:
		if v.camo_voulu and not v.camoufle:
			v.camo_t += dt
			if v.camo_t >= S:
				v.camoufle = true
				log_("%s est invisible de la route." % v.nom, "ok")

func ordre_mines(n := 3) -> bool:
	var E: Dictionary = donnees().embuscade
	var equipiers := 0
	for v in convoi:
		equipiers += v.equipage_vivant()
	for b in batiments:
		equipiers += b.garnison_vivants()
	if equipiers == 0:
		return false
	var cout: float = E.mine_cout * n
	if stocks.metal < cout:
		log_("Il faut %d métal pour poser %d mines." % [int(cout), n], "alerte")
		return false
	stocks.metal -= cout
	for i in n:
		mines.append({"x": x_tete + E.mine_dist + i * 9.0 + rng.randf_range(0.0, 3.0), "arme_t": temps + 6.0 + i * 3.0, "armee": false})
	log_("%d mines posées sur la route devant le convoi : ne les franchissez pas." % n, "ok")
	evt({"t": "mines"})
	return true

func _mines(_dt: float) -> void:
	var gardees := []
	for mn in mines:
		if not mn.armee and temps >= mn.arme_t:
			mn.armee = true
		var saute = null
		if mn.armee:
			for e in ennemis:
				if e.actif() and e.vitesse_act != 0.0 and e.x <= mn.x and mn.x <= e.x + e.longueur:
					saute = e
					break
			if saute == null and vitesse_convoi != 0.0:
				for v in convoi:
					if v.actif() and v.x <= mn.x and mn.x <= v.x + v.longueur:
						saute = v
						break
		if saute != null:
			_sauter_sur_mine(saute, mn)
		else:
			gardees.append(mn)
	mines = gardees

func _sauter_sur_mine(v: Veh, mn: Dictionary) -> void:
	var degats := {"roulement": 70.0, "suspension": 40.0, "chassis": 25.0}
	for k in degats:
		var avant: float = v.pieces[k].pv
		v.pieces[k].pv = maxf(0.0, avant - degats[k])
		if avant > 0.0 and v.pieces[k].pv <= 0.0 and k != "chassis":
			evt({"t": "casse", "uid": v.uid, "piece": k})
	_blesser_equipage(v, 8.0)
	evt({"t": "mine", "x": mn.x, "uid": v.uid})
	log_("Une mine explose sous %s !" % v.nom, "ok" if v.camp == "ennemi" else "alerte")
	if v.pieces.chassis.pv <= 0.0:
		_detruire(v)
	elif v.equipage_vivant() == 0 and v.actif():
		_neutraliser(v)

func _armes_garnison(dt: float) -> void:
	var W: Dictionary = donnees().armes.fusil_antichar
	for b in batiments:
		if b.revele_t > 0.0:
			b.revele_t -= dt
			if b.revele_t <= 0.0:
				for g in b.garnison:
					g.premier = true
		for g in b.garnison:
			g.cd -= dt
			if g.pv <= 0.0 or g.cd > 0.0 or stocks.ammo < 1.0:
				continue
			var cible = null
			var g_min := INF
			for e in ennemis:
				if e.actif():
					var gp := ecart(b.x, b.longueur, e.x, e.longueur)
					if gp <= W.portee and gp < g_min:
						g_min = gp
						cible = e
			if cible == null:
				cible = monde.pieton_proche(b.x, b.longueur, W.portee)
			if cible == null:
				g.cd = 0.0
				continue
			b.revele_t = 8.0
			_tirer(b, g, W, cible)

func alerte() -> Dictionary:
	var n := 0
	var d_min := INF
	var eta := -1.0
	for e in ennemis:
		if e.actif():
			var d: float = e.x - x_tete
			var stand: float = e.profil.get("standoff", 26.0)
			if d > stand + 4.0 and d < 170.0:
				n += 1
				if d < d_min:
					d_min = d
					eta = (d - stand) / maxf(e.vitesse(), 0.1) if e.mode == "approche" else -1.0
	return {"n": n, "dist": d_min, "eta": eta} if n > 0 else {}


# --- Fouille ---------------------------------------------------------------
func menace() -> bool:
	var F: Dictionary = donnees().fouille
	for p in monde.pietons:
		if p.actif() and absf(p.x - x_tete) < F.menace_distance:
			return true
	for e in ennemis:
		if e.actif() and absf(e.x - x_tete) < F.menace_distance:
			return true
	for b in batiments:
		if b.actif() and ecart(x_tete - 1.0, 1.0, b.x, b.longueur) < F.menace_distance * 0.75:
			return true
	return false

func a_fouiller():
	var F: Dictionary = donnees().fouille
	var meilleur = null
	var g_min := INF
	var cands: Array = []
	for v in epaves:
		if not v.butin_pris:
			cands.append(v)
	for b in batiments:
		if b.statut == "neutralise" and not b.butin_pris:
			cands.append(b)
	for c in cands:
		for v in convoi:
			if v.actif():
				var g := ecart(v.x, v.longueur, c.x, c.longueur)
				if g <= F.portee and g < g_min:
					g_min = g
					meilleur = c
	return meilleur

func cible_fouille():
	var F: Dictionary = donnees().fouille
	var meilleur = null
	var g_min := 40.0
	var cands: Array = []
	for v in epaves:
		if not v.butin_pris:
			cands.append(v)
	for b in batiments:
		if b.statut == "neutralise" and not b.butin_pris:
			cands.append(b)
	for c in cands:
		var centre_conv: float = x_tete - 4.0
		var g: float = absf(c.x + c.longueur * 0.5 - centre_conv)
		if g < g_min:
			g_min = g
			meilleur = c
	return meilleur

func ordre_fouiller(uid: int) -> bool:
	var c = trouver(uid)
	if c == null or c.butin_pris or menace():
		return false
	fouille_demandee = uid
	ordres.marche = "avancer" if c.x + c.longueur * 0.5 > x_tete - 3.0 else "recul"
	return true

func _fouiller(dt: float) -> void:
	var F: Dictionary = donnees().fouille
	if fouille_en_cours.is_empty():
		if fouille_demandee == 0:
			return
		var c = trouver(fouille_demandee)
		if c == null or c.butin_pris or menace():
			fouille_demandee = 0
			return
		var proche := false
		for v in convoi:
			if v.actif() and ecart(v.x, v.longueur, c.x, c.longueur) <= F.portee:
				proche = true
		if proche:
			ordres.marche = "halte"
			fouille_demandee = 0
			fouille_en_cours = {"uid": c.uid, "restant": F.duree_base, "total": F.duree_base}
			evt({"t": "fouille", "uid": c.uid})
	else:
		if menace():
			fouille_en_cours = {}
			log_("Fouille interrompue.", "alerte")
			return
		fouille_en_cours.restant -= dt
		if fouille_en_cours.restant <= 0.0:
			var c2 = trouver(fouille_en_cours.uid)
			fouille_en_cours = {}
			if c2 != null:
				_recolter(c2)

func _recolter(c) -> void:
	c.butin_pris = true
	var res: Dictionary = c.butin.ressources
	var morceaux := []
	var noms := {"ammo": "munitions", "fuel_l": "L carburant", "metal": "métal"}
	for k in res:
		if res[k] <= 0:
			continue
		if k == "survivants":
			for i in int(res[k]):
				if _recruter_survivant():
					morceaux.append("un survivant se joint à vous")
		else:
			stocks[k] = stocks.get(k, 0.0) + res[k]
			morceaux.append("+%d %s" % [int(res[k]), noms.get(k, k)])
	# Pièces de véhicule (grille) : elles vont en réserve, prêtes à être assemblées
	for pid in c.butin.get("pieces", []):
		pieces_stock.append({"piece": pid, "etat": 1.0})
		morceaux.append(Assemblage.piece(pid).get("nom", pid))
	if not c.butin.get("pieces", []).is_empty():
		evt({"t": "pieces"})
		if ouverture:   # au bord de la route : on s'arrête pour assembler
			ordres.marche = "halte"
			log_("De quoi bricoler ! Touchez « Assembler ».", "ok")
	# Les pièces ne se prennent que sur les épaves détruites ; un véhicule entier se répare
	var comps: Array = c.butin.composants if (c is Bat or c.statut == "epave") else []
	for comp in comps:
		composants.append(comp)
		morceaux.append("%s %d %%" % [comp.nom, int(comp.etat * 100)])
	if composants.size() > 20:
		composants = composants.slice(composants.size() - 20)
	log_("Butin : " + (", ".join(morceaux) if not morceaux.is_empty() else "rien d'utile."), "ok")
	evt({"t": "butin", "uid": c.uid})
