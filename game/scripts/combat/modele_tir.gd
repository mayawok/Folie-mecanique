# Couche 1 du modèle : tir, projectiles, dégâts, destruction, réparation.
extends "res://scripts/combat/modele_reputation.gd"


# --- Ordres ----------------------------------------------------------------
func _mecanicien_possible(v: Veh) -> bool:
	var F: Dictionary = donnees().fouille
	for c in convoi:
		if c.actif() and c.equipage_vivant() > 0:
			if c == v or convoi.has(v) or ecart(c.x, c.longueur, v.x, v.longueur) <= F.portee_reparation:
				return true
	return false


# --- Tir -------------------------------------------------------------------
func _armes_vehicule(v: Veh, dt: float) -> void:
	if v.equipage_vivant() == 0 or v.camoufle or v.garage != 0 or v.allie:
		return
	if equipage_dehors(v) > 0:
		return   # l'équipage est descendu réparer : plus personne aux armes (DEC-064)
	var D := donnees()
	for a in v.armes:
		a.cd -= dt
		if a.cd > 0.0 or not v.piece_ok(a.piece):
			continue
		var w: Dictionary = D.armes[a.id]
		if v.camp == "joueur":
			if not v.tir:
				a.cd = 0.0
				continue
			if float(w.get("carburant", 0.0)) > 0.0 and stocks.gazole < float(w.carburant):
				a.cd = 0.0   # lance-flammes : il brûle le carburant du convoi (DEC-052)
				continue
			if stocks.ammo < w.munitions:
				if not _alerte_muni:
					_alerte_muni = true
					log_(Textes.t("tir.001"), "alerte")
				a.cd = 0.0
				continue
		if w.classe == "mortier" and absf(v.vitesse_act) > 0.3:
			a.cd = 0.0   # le mortier ne tire qu'à l'arrêt
			continue
		var cible = _choisir_cible(v, w)
		if cible == null:
			a.cd = 0.0
			continue
		_tirer(v, a, w, cible)

func _armes_batiment(b: Bat, dt: float) -> void:
	var D := donnees()
	var wf: Dictionary = D.armes.fusil
	for t in b.tireurs:
		t.cd -= dt
		if t.pv > 0.0 and t.cd <= 0.0:
			var cible = _choisir_cible(b, wf)
			if cible == null:
				t.cd = 0.0
			else:
				_tirer(b, t, wf, cible)
	if b.arme_fixe != "" and b.tireurs_vivants() > 0:
		b.cd_fixe -= dt
		if b.cd_fixe <= 0.0:
			var w: Dictionary = D.armes[b.arme_fixe]
			var cible = _choisir_cible(b, w)
			if cible == null:
				b.cd_fixe = 0.0
			else:
				_tirer(b, {"id": b.arme_fixe, "cd": 0.0, "fixe": true, "slot": 1}, w, cible)

func _choisir_cible(att, w: Dictionary):
	var joueur: bool = att is Veh and att.camp == "joueur"
	if not joueur:
		# Ennemis : tirent sur le convoi, en priorité sur les véhicules de tête
		var poids := []
		var cands := []
		var rang := 0
		for v in convoi:
			if v.actif():
				if not v.camoufle and v.garage == 0 and ecart(att.x, att.longueur, v.x, v.longueur) <= w.portee:
					cands.append(v)
					poids.append(1.0 / (1.0 + rang))
				rang += 1
		for b in batiments:
			if b.revele_t > 0.0 and b.garnison_vivants() > 0 and ecart(att.x, att.longueur, b.x, b.longueur) <= w.portee:
				cands.append(b)
				poids.append(1.2)
		for s in monde.pietons:   # soldats débarqués : cibles à découvert
			if s.camp == "joueur" and s.actif() and ecart(att.x, att.longueur, s.x, s.longueur) <= w.portee:
				cands.append(s)
				poids.append(float(donnees().troupes.cible_poids))
		if cands.is_empty():
			return null
		var total := 0.0
		for p in poids:
			total += p
		var r := rng.randf() * total
		for i in cands.size():
			r -= poids[i]
			if r <= 0.0:
				return cands[i]
		return cands[cands.size() - 1]
	if w.classe != "canon":
		var pp = monde.pieton_proche(att.x, att.longueur, w.portee)
		if pp != null:
			return pp
	var meilleur = null
	var score_min := INF
	for e in ennemis:
		if not e.actif() or e.allie:
			continue
		if w.classe in ["mitrailleuse", "flamme"] and e.profil.blindage > 25.0:
			continue   # la mitrailleuse ne perce pas un blindé : on économise les munitions
		var g := ecart(att.x, att.longueur, e.x, e.longueur)
		if g > w.portee or g < float(w.get("portee_min", 0.0)):
			continue
		var s := g + (1000.0 if ordres.cible == "batiments" else 0.0)
		if s < score_min:
			score_min = s
			meilleur = e
	for b in batiments:
		if not b.actif():
			continue
		var g := ecart(att.x, att.longueur, b.x, b.longueur)
		if g > w.portee or g < float(w.get("portee_min", 0.0)):
			continue
		var s := g + (1000.0 if ordres.cible == "vehicules" else 0.0)
		if s < score_min:
			score_min = s
			meilleur = b
	return meilleur

func _tirer(att, a: Dictionary, w: Dictionary, cible) -> void:
	var garde: bool = a.has("garde")
	var joueur: bool = (att is Veh and att.camp == "joueur") or garde
	var Z: Dictionary = donnees().zones
	if joueur:
		stocks.ammo -= w.munitions
		stocks.gazole = maxf(0.0, stocks.gazole - float(w.get("carburant", 0.0)))
		_alerte_muni = false
	var cd: float = w.cadence * rng.randf_range(0.9, 1.1)
	if att is Veh and int(att.profil.get("chargeurs", 0)) > 0:   # un chargeur raccourcit le rechargement (DEC-050)
		var ER: Dictionary = donnees().equipage_roles
		cd *= float(ER.chargeur_canon) if w.classe in ["canon", "mortier"] else float(ER.chargeur_mitrailleuse)
	if a.has("fixe"):
		att.cd_fixe = cd
	else:
		a.cd = cd
	var g := ecart(att.x, att.longueur, cible.x, cible.longueur)
	var visee: String = ordres.visee if (joueur and not garde) else "libre"
	var chance: float = w.precision * clampf(1.25 - 0.6 * g / w.portee, 0.45, 1.0)
	if att is Veh and att.camp == "ennemi":
		chance *= float(donnees().equilibrage.ennemi_precision)
	if att is Veh:
		chance *= att.facteur_precision()
	if visee != "libre":
		chance *= Z.visee_precision
	var bonus := 1.0
	if garde and a.get("premier", false):
		chance = minf(0.95, chance * 1.4)   # l'embuscade surprend l'ennemi : première salve redoutable
		bonus = 2.0
		a.premier = false
	if cible is Bat:
		chance = minf(0.95, chance * 1.2)
	if cible is MondeJeu.Pieton:
		chance *= 0.8
	if monde.nuit() and joueur and not garde and not (att is Veh and int(att.profil.get("phares", 0)) > 0):
		chance *= 0.8   # on y voit mal la nuit, sauf avec des phares (DEC-048)
	chance *= facteur_precision_meteo()   # tempête de sable : précision ×0,5 pour tous (DEC-027)
	var touche := rng.randf() < chance
	var origine := _bouche(att, a)
	var zone := ""
	var point := Vector2.ZERO
	var ricoche := false
	var centre_x: float = cible.x + cible.longueur * 0.5
	if touche:
		if cible is Veh:
			zone = _zone(cible, visee)
			point = ancre(cible, zone)
			var arm: float = cible.profil.blindage * Z.blindage_zone[genre_piece(zone)]
			ricoche = w.penetration / (w.penetration + arm) < 0.3
		elif cible is MondeJeu.Pieton:
			zone = ""
			point = Vector2(cible.x + 0.35, 0.9)
		else:
			zone = "structure"
			point = Vector2(cible.x + cible.longueur * rng.randf_range(0.25, 0.75), cible.hauteur * rng.randf_range(0.15, 0.6))
	else:
		var sens := 1.0 if centre_x >= origine.x else -1.0
		point = Vector2(centre_x + sens * rng.randf_range(1.0, 7.0), rng.randf_range(0.0, 1.6))
	if not joueur:
		bonus *= float(donnees().equilibrage.ennemi_degats_infliges)   # tout ce qui tire contre le convoi frappe moins fort (DEC-113)
	projectiles.append({"att": att.uid, "cible": cible.uid, "w": w, "classe": w.classe, "a": origine, "b": point,
		"t": 0.0, "T": maxf(0.12, origine.distance_to(point) / w.vitesse), "touche": touche, "zone": zone,
		"ricoche": ricoche, "visee": visee, "bonus": bonus})
	evt({"t": "tir", "de": att.uid, "vers": cible.uid, "classe": w.classe, "touche": touche, "zone": zone, "x0": origine.x})

func _bouche(att, a: Dictionary) -> Vector2:
	if att is MondeJeu.Pieton:
		return Vector2(att.x + 0.3, 1.3)
	if att is Bat:
		return att.fenetre(int(a.get("slot", 0)))
	var D: Dictionary = VehiculeDessin.donnees().vehicules[att.type]
	var armes: Array = D.get("armes", [])
	var i := int(a.get("idx", 0))
	var lx: float = att.longueur * 0.9
	var ly: float = float(D.hauteur) * 0.7
	if i < armes.size():
		var ar: Dictionary = armes[i]
		if ar.type == "mitrailleuse":
			lx = ar.x + ar.long - 0.16
			ly = ar.y + ar.get("pied", 0.0) + 0.02
		elif ar.type == "mortier":
			lx = ar.x + ar.long * 0.57
			ly = ar.y + ar.long * 0.82
		else:
			lx = ar.x + ar.long
			ly = ar.y
	return Vector2(att.x + (att.longueur - lx if att.camp == "ennemi" else lx), ly)

func _projectiles(dt: float) -> void:
	var en_vol := []
	for p in projectiles:
		p.t += dt
		if p.t >= p.T:
			_impact(p)
		else:
			en_vol.append(p)
	projectiles = en_vol

func _impact(p: Dictionary) -> void:
	var cible = trouver(p.cible)
	var reel := false
	if p.touche and cible != null:
		var w: Dictionary = p.w
		if p.bonus != 1.0:
			w = w.duplicate()
			w.degats *= p.bonus
		if cible is Veh:
			if cible.statut != "epave":
				_toucher_vehicule(null, w, cible, p.visee, p.zone)
				reel = true
		elif cible is MondeJeu.Pieton:
			monde.toucher_pieton(cible, w)
			reel = true
		else:
			_toucher_batiment(w, cible, p.visee)
			reel = true
	var wx: Dictionary = p.w
	if cible is Veh and p.touche and reel and wx.has("feu"):   # cocktail Molotov : le véhicule prend feu
		cible.feu = maxf(cible.feu, float(wx.feu))
		cible.feu_dps = float(wx.feu_dps)
		if cible.camp == "joueur":
			log_(Textes.t("feu.001", [cible.nom]), "alerte")
	if wx.has("explosion") or wx.has("feu") or p.classe in ["canon", "mortier"]:
		evt({"t": "explosion", "x": p.b.x, "y": maxf(p.b.y, 0.2), "taille": float(wx.get("explosion", 0.9 if wx.has("feu") else 0.8)), "feu": wx.has("feu")})
	evt({"t": "impact", "x": p.b.x, "y": p.b.y, "touche": p.touche, "reel": reel, "classe": p.classe,
		"ricoche": p.ricoche, "uid": p.cible, "sur_joueur": cible is Veh and cible.camp == "joueur"})

# Véhicules en feu : perte de PV par seconde sur le moteur, la carrosserie et l'équipage ; l'épave brûle un moment (DEC-220)
func _feux(dt: float) -> void:
	var F: Dictionary = donnees().feu
	for v in convoi + ennemis + epaves:
		if v.feu <= 0.0:
			continue
		v.feu = maxf(0.0, v.feu - dt)
		if v.statut == "epave" or v.pieces.chassis.pv <= 0.0:
			continue
		var d: float = v.feu_dps * dt * (float(F.degats_ennemi) if v.camp == "ennemi" else 1.0)
		var cible: String = "moteur" if rng.randf() < 0.5 else "chassis"
		v.pieces[cible].pv = maxf(0.0, v.pieces[cible].pv - d)
		_blesser_equipage(v, d * float(F.equipage))
		if v.pieces.chassis.pv <= 0.0:
			_detruire(v)
		elif v.equipage_vivant() == 0 and v.actif():
			_neutraliser(v)


# Un véhicule qui explose : souffle sur les voisins à quelques mètres (DEC-220)
func _explosion_epave(v: Veh) -> void:
	var F: Dictionary = donnees().feu
	if rng.randf() > float(F.explosion_carburant):
		return
	var c: float = v.x + v.longueur * 0.5
	evt({"t": "explosion", "x": c, "y": 0.8, "taille": 3.4, "feu": true})
	var souffle := {"degats": float(F.degats), "penetration": 20.0, "classe": "mortier"}
	for o in convoi + ennemis:
		if o != v and o.statut != "epave" and absf(o.x + o.longueur * 0.5 - c) < float(F.rayon) + (v.longueur + o.longueur) * 0.25:
			_toucher_vehicule(null, souffle, o, "libre")


func _zone(v: Veh, visee: String) -> String:
	var Z: Dictionary = donnees().zones
	var ids := []
	var poids := []
	for id in v.pieces:
		if v.pieces[id].pv > 0.0:
			ids.append(id)
			poids.append(Z.poids[genre_piece(id)])
	if visee != "libre":
		var groupe := []
		for id in ids:
			if (visee == "roulement" and id == "roulement") or (visee == "armement" and id.begins_with("a")) or (visee == "chassis" and id == "chassis"):
				groupe.append(id)
		if not groupe.is_empty() and rng.randf() < Z.visee_chance:
			return groupe[rng.randi() % groupe.size()]
	var total := 0.0
	for p in poids:
		total += p
	var r := rng.randf() * total
	for i in ids.size():
		r -= poids[i]
		if r <= 0.0:
			return ids[i]
	return ids[ids.size() - 1]

func _toucher_vehicule(att, w: Dictionary, v: Veh, visee: String, zone_imposee := "") -> String:
	var D := donnees()
	var Z: Dictionary = D.zones
	var E: Dictionary = D.effets
	var zone := zone_imposee if (zone_imposee != "" and v.pieces[zone_imposee].pv > 0.0) else _zone(v, visee)
	var genre := genre_piece(zone)
	var arm: float = v.profil.blindage * Z.blindage_zone[genre]
	if genre == "cabine" and v.profil.ouvert:
		arm *= 0.1
	var d: float = w.degats * w.penetration / (w.penetration + arm)
	var EQ: Dictionary = D.equilibrage   # ennemis plus fragiles, convoi du joueur favorisé (DEC-113)
	if v.camp == "ennemi":
		d *= float(EQ.ennemi_degats_subis)
	var p: Dictionary = v.pieces[zone]
	var avant: float = p.pv
	p.pv = maxf(0.0, p.pv - d)
	if w.classe in ["canon", "mortier"] and zone != "chassis":
		v.pieces.chassis.pv = maxf(0.0, v.pieces.chassis.pv - d * 0.25)
	var dc := 0.0
	if genre == "cabine":
		dc = d * 0.9
	elif not v.piece_ok("cabine"):
		dc = d * E.cabine_hs_equipage
	if dc > 0.0:
		_blesser_equipage(v, dc)
	if zone == "roulement":
		_perdre_roues(v)
	if avant > 0.0 and p.pv <= 0.0 and zone != "chassis":
		evt({"t": "casse", "uid": v.uid, "piece": zone})
		if v.camp == "joueur":
			log_(Textes.t("tir.002", [v.nom, p.nom]), "alerte")
	if v.pieces.chassis.pv <= 0.0:
		_detruire(v)
	elif v.equipage_vivant() == 0 and v.actif():
		_neutraliser(v)
	return zone

# Roues arrachées (DEC-080) : plus les roues sont abîmées, plus il en tombe (jamais toutes) ; elles roulent sur la route
func _roues_voulues(v: Veh) -> int:
	if v.chenille:
		return 0
	var n: int = VehiculeDessin.donnees().vehicules.get(v.type, {}).get("roues", []).size()
	if n < 2:
		return 0
	return mini(n - 1, int(floor((1.0 - v.ratio("roulement")) * n * float(donnees().effets.get("roues_tombent", 0.6)))))


func _perdre_roues(v: Veh) -> void:
	var D: Dictionary = VehiculeDessin.donnees().vehicules.get(v.type, {})
	var roues: Array = D.get("roues", [])
	var voulu := _roues_voulues(v)
	while v.roues_perdues.size() < voulu:
		var libres := []
		for i in roues.size():
			if not v.roues_perdues.has(i):
				libres.append(i)
		var i: int = libres[rng.randi() % libres.size()]
		v.roues_perdues.append(i)
		var rx: float = float(roues[i].x)
		var L: float = float(D.longueur)
		evt({"t": "roue_perdue", "uid": v.uid, "x": v.x + (L - rx if v.camp == "ennemi" and v.mode != "poursuite" else rx), "r": float(roues[i].r), "sens": -1.0 if v.camp == "joueur" or v.mode == "poursuite" else 1.0})
		if v.camp == "joueur":
			log_(Textes.t("tir.003", [v.nom]), "alerte")


func _remonter_roues(v: Veh) -> void:   # roues remontées au fil de la réparation
	var voulu := _roues_voulues(v)
	while v.roues_perdues.size() > voulu:
		v.roues_perdues.pop_back()


func _blesser_equipage(v: Veh, d: float) -> void:
	var vivants := []   # équipage (indice >= 0) et soldats des bancs (indice -1 - j)
	for i in v.equipage.size():
		if v.equipage[i] > 0.0:
			vivants.append(i)
	for j in v.troupes.size():
		if v.troupes[j] > 0.0:
			vivants.append(-1 - j)
	if vivants.is_empty():
		return
	var i: int = vivants[rng.randi() % vivants.size()]
	if i < 0:
		var j := -1 - i
		v.troupes[j] = maxf(0.0, v.troupes[j] - d)
		if v.troupes[j] <= 0.0 and v.camp == "joueur":
			log_(Textes.t("tir.004", [v.nom]), "alerte")
		return
	v.equipage[i] = maxf(0.0, v.equipage[i] - d)
	if v.equipage[i] <= 0.0 and v.camp == "joueur":
		log_(Textes.t("tir.005", [v.nom]), "alerte")

func _toucher_batiment(w: Dictionary, b: Bat, visee: String) -> String:
	if b.statut == "neutralise":   # ruine : abri éventuel de la garnison
		var d0: float = w.degats * w.penetration / (w.penetration + b.blindage)
		if w.classe in ["canon", "mortier"]:
			b.pv = maxf(0.0, b.pv - d0)
			_blesser_garnison(b, d0 * 0.6)
		elif b.garnison_vivants() > 0 and rng.randf() < 0.4:
			_blesser_garnison(b, w.degats * 0.8)
		else:
			b.pv = maxf(0.0, b.pv - d0)
		if b.pv <= 0.0:
			for g in b.garnison:
				g.pv = 0.0
		return "structure"
	var d: float = w.degats * w.penetration / (w.penetration + b.blindage)
	var zone := "structure"
	if w.classe in ["canon", "mortier"]:
		b.pv = maxf(0.0, b.pv - d)
		_blesser_tireur(b, d * 0.6)   # l'éclat de l'obus blesse les tireurs
	elif b.tireurs_vivants() > 0 and (visee in ["libre", "armement"]) :
		_blesser_tireur(b, w.degats)
		zone = "tireur"
	else:
		b.pv = maxf(0.0, b.pv - d)
	if b.pv <= 0.0:
		for t in b.tireurs:
			t.pv = 0.0
	if b.actif() and (b.pv <= 0.0 or b.tireurs_vivants() == 0):
		b.statut = "neutralise"
		if b.type in ["camp_ami", "camp_fortifie"] and b.fac != "":
			rep_acte("camp_detruit", String(b.type), b.fac, Textes.t("rep.004", [b.nom]))
		ennemis_detruits += 1
		b.butin.composants = []
		log_(Textes.t("tir.006", [b.nom]), "ok")
		evt({"t": "epave", "uid": b.uid})
	return zone

func _blesser_garnison(b: Bat, d: float) -> void:
	for g in b.garnison:
		if g.pv > 0.0:
			g.pv = maxf(0.0, g.pv - d)
			if g.pv <= 0.0:
				log_(Textes.t("tir.007", [b.nom]), "alerte")
			return

func _blesser_tireur(b: Bat, d: float) -> void:
	for t in b.tireurs:
		if t.pv > 0.0:
			t.pv = maxf(0.0, t.pv - d)
			return

# Complète les bancs de troupes avec les recrues de la réserve (le bac à sable en fournit sans limite)
func _embarquer_troupes(v: Veh) -> void:
	var places := int(v.profil.get("places_troupes", 0))
	while v.troupes.size() > places:
		v.troupes.pop_back()
		reserve_survivants += 1
	while v.troupes.size() < places and (reserve_survivants > 0 or bac_a_sable):
		v.troupes.append(float(donnees().equipage_pv))
		if reserve_survivants > 0:
			reserve_survivants -= 1


# Pendant une réparation, tout l'équipage descend sauf le chef de char (DEC-064) : nombre de personnes dehors
func equipage_dehors(v: Veh) -> int:
	if not (v.reparation and ordres.marche == "halte"):
		return 0
	return maxi(0, v.equipage_vivant() - (1 if v.a_un_chef() else 0))


func _detruire(v: Veh) -> void:
	for pv in v.troupes:   # les soldats d'un véhicule détruit sautent à terre : ils rejoindront un autre véhicule
		if pv > 0.0:
			reserve_survivants += 1
	v.troupes = []
	v.statut = "epave"
	v.reparation = false
	for id in v.pieces:
		v.pieces[id].pv *= 0.5
	v.pieces.chassis.pv = 0.0
	for i in v.equipage.size():
		v.equipage[i] = 0.0
	v.butin = _butin_vehicule(v, 0.4)
	_sortir_du_combat(v)
	evt({"t": "epave", "uid": v.uid})
	v.feu = float(donnees().feu.epave_feu)
	v.feu_dps = 0.0
	_explosion_epave(v)
	if v.camp == "joueur":
		log_(Textes.t("tir.008", [v.nom]), "alerte")
	else:
		ennemis_detruits += 1
		log_(Textes.t("tir.009", [v.nom]), "ok")

func _neutraliser(v: Veh) -> void:
	v.statut = "abandonne"
	v.butin = _butin_vehicule(v, 0.8)
	_sortir_du_combat(v)
	evt({"t": "epave", "uid": v.uid})
	if v.camp == "joueur":
		log_(Textes.t("tir.010", [v.nom]), "alerte")
	else:
		ennemis_detruits += 1
		log_(Textes.t("tir.011", [v.nom]), "ok")

func _sortir_du_combat(v: Veh) -> void:
	v.x_prev = v.x
	convoi.erase(v)
	ennemis.erase(v)
	epaves.append(v)

func _butin_vehicule(v: Veh, facteur: float) -> Dictionary:
	var res := {
		"metal": round(v.profil.metal * facteur),
		"ammo": round(rng.randf_range(6.0, 18.0) * v.armes.size() * facteur),
	}
	res[carburant_de(v)] = round(rng.randf_range(0.3, 1.0) * v.profil.reservoir * facteur)
	var comps := []
	for id in v.pieces:
		if id == "chassis":
			continue
		var p: Dictionary = v.pieces[id]
		var etat: float = p.pv / p.max
		if etat >= 0.15:
			var classe := ""
			if id.begins_with("a"):
				classe = donnees().armes[v.profil.armes[int(id.substr(1))]].classe
			comps.append({"kind": genre_piece(id), "classe": classe, "nom": "%s (%s)" % [p.nom, v.nom], "etat": etat})
	return {"ressources": res, "composants": comps, "pieces": coques_donnees(v.type)}


# Coques de donneur livrées par une épave de ce type (DEC-067) : lues dans le catalogue, aucune liste dans le code
static func coques_donnees(type: String) -> Array:
	var res := []
	for id in Assemblage.catalogue().pieces:
		var f: Dictionary = Assemblage.piece(id)
		if f.get("famille", "") == "coque" and type in f.get("donneurs", []):
			res.append(id)
	return res


# --- Réparation ------------------------------------------------------------
func _piece_a_reparer(v: Veh) -> String:
	if v.rep_piece != "":
		var p0 = v.pieces.get(v.rep_piece)
		return v.rep_piece if p0 != null and p0.pv < p0.max - 0.5 else ""
	var ordre := ["roulement", "moteur"]
	for p in v.pieces:
		if p.begins_with("a"):
			ordre.append(p)
	ordre.append_array(["suspension", "cabine", "chassis"])
	for id in ordre:
		if v.pieces[id].pv < v.pieces[id].max - 0.5:
			return id
	return ""

func _reparer(dt: float) -> void:
	if ordres.marche != "halte":
		return
	var R: Dictionary = donnees().reparation
	for v in convoi + epaves:
		if not v.reparation:
			continue
		if not _mecanicien_possible(v):
			v.reparation = false
			continue
		v.rep_pret += dt
		if v.rep_pret < R.delai_depart:
			continue
		var id := _piece_a_reparer(v)
		if id == "":
			v.reparation = false
			v.rep_acc = 0.0
			v.rep_piece = ""
			log_(Textes.t("tir.012", [v.nom]), "ok")
			evt({"t": "repare", "uid": v.uid})
			continue
		var p: Dictionary = v.pieces[id]
		if p.pv <= 0.0:
			v.rep_acc += dt * (float(donnees().equipage_roles.mecanicien_vitesse) if int(v.profil.get("mecaniciens", 0)) > 0 else 1.0)
			if v.rep_acc < R.delai_piece_s:
				continue
			v.rep_acc = 0.0
			var idx := _composant_pour(v, id)
			if idx >= 0:
				var c: Dictionary = composants[idx]
				composants.remove_at(idx)
				p.pv = maxf(1.0, c.etat * p.max)
				log_(Textes.t("tir.013", [v.nom, p.nom]), "ok")
			elif stocks.metal >= R.metal_bricolage:
				stocks.metal -= R.metal_bricolage
				p.pv = R.etat_bricolage * p.max
				log_(Textes.t("tir.014", [v.nom, p.nom]), "info")
			else:
				v.reparation = false
				log_(Textes.t("tir.015", [v.nom, p.nom]), "alerte")
		else:
			var gain: float = R.pv_par_s * dt
			var cout: float = gain * R.metal_par_pv
			if stocks.metal < cout:
				v.reparation = false
				log_(Textes.t("tir.016", [v.nom]), "alerte")
			else:
				stocks.metal -= cout
				p.pv = minf(p.max, p.pv + gain)
		if id == "roulement":
			_remonter_roues(v)

func _composant_pour(v: Veh, id: String) -> int:
	var meilleur := -1
	var e_max := -1.0
	for i in composants.size():
		var c: Dictionary = composants[i]
		var ok := false
		if id.begins_with("a"):
			var classe: String = donnees().armes[v.profil.armes[int(id.substr(1))]].classe
			ok = c.kind == "arme" and c.classe == classe
		else:
			ok = c.kind == id
		if ok and c.etat > e_max:
			e_max = c.etat
			meilleur = i
	return meilleur
