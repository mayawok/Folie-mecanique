extends "res://scripts/combat/modele_camp.gd"
# Villes standard (DEC-140 à DEC-143). Couche du modèle de combat, entre le camp de réparation et CombatModele.
# Une ville = une enceinte plate de ~150 m avec une porte d'entrée (x0) et une porte de sortie (x1).
# Déroulé : le convoi freine seul devant la porte fermée, les gardes l'ouvrent, le convoi entre au pas (mouvement forcé)
# et s'arrête sur la place. Dedans : rien ne peut arriver (ni ennemis, ni tempête, ni rôdeurs) ; la ville est inscrite
# sur la carte (point de reprise). Pour repartir, le joueur choisit sa sortie (une direction = un secteur voisin) :
# le convoi roule jusqu'à la porte de sortie, elle s'ouvre, il sort vers la droite et la route suivante mène au secteur choisi.
# Valeurs et noms : game/data/villes.json. Dessin : ville_dessin.gd.

# Phases : approche, ouverture, entree, dedans, depart, ouverture_s, sortie, fin
# chargement et rassemblement : scènes de départ en mission (modele_mission.gd, DEC-145)
const PHASES_FORCEES := ["monte_charge", "trone", "ouverture", "entree", "depart", "ouverture_s", "sortie", "chargement", "rassemblement"]
const PHASES_PROTEGEES := ["monte_charge", "trone", "ouverture", "entree", "dedans", "depart", "ouverture_s", "sortie", "chargement", "rassemblement"]

static var _vdata := {}

var villes_on := false     # villes actives (nouvelle expédition) ; le Mode créatif les fait venir par le Kit
var ville := {}            # {} ou {nom, maire, secteur, x0, x1, phase, t, porte_e, porte_s, x_arret, dest, graine}
var _n_villes := 0


static func VD() -> Dictionary:
	if _vdata.is_empty():
		var f := FileAccess.open("res://data/villes.json", FileAccess.READ)
		_vdata = JSON.parse_string(f.get_as_text())
	return _vdata


func ville_active() -> bool:
	return not ville.is_empty()


func ville_phase() -> String:
	return String(ville.get("phase", ""))


func ville_repaire() -> bool:
	return String(ville.get("variante", "standard")) == "repaire"


func RP() -> Dictionary:
	return VD().variantes.repaire


func ville_pillee() -> bool:
	return String(ville.get("variante", "standard")) == "pillee"


func ville_dedans() -> bool:
	return ville_phase() == "dedans"


func ville_protegee() -> bool:
	return ville_phase() in PHASES_PROTEGEES


# Abords de la ville : pas de rencontre, de champ de mines ni de rôdeur (aucune ville ne tire sur nous pour l'instant)
func ville_calme() -> bool:
	if not ville_active() or ville_phase() == "fin":
		return false
	return float(ville.x0) - x_tete < float(VD().calme_m)


func ville_zone(x: float) -> bool:
	return ville_active() and x > float(ville.x0) - 150.0 and x < float(ville.x1) + 100.0


func _queue_x() -> float:
	var q := x_tete
	for v in convoi:
		q = minf(q, v.x)
	return q


# --- Apparition ----------------------------------------------------------------------------
# Pose une ville dont la porte d'entrée est en x0. Le nom est tiré au hasard la première fois, puis gardé par le secteur.
func ville_creer(x0: float, variante := "standard") -> bool:
	if ville_active() and ville_phase() != "fin":
		return false
	_ville_retirer()
	var D := VD()
	var s: Dictionary = monde.secteurs[monde.secteur]
	var r := RandomNumberGenerator.new()
	r.seed = graine * 97 + 13 * _n_villes + monde.secteur
	_n_villes += 1
	ville_nommer(monde.secteur, r)
	var L := float(D.longueur_m)
	ville = {"nom": s.ville, "maire": s.maire, "secteur": monde.secteur, "x0": x0, "x1": x0 + L, "phase": "approche", "t": 0.0,
		"porte_e": 0.0, "porte_s": 0.0, "x_arret": 0.0, "dest": -1, "graine": r.randi() % 100000, "annoncee": false, "variante": variante}
	if variante == "repaire":   # repaire du boss (DEC-166) : nom et chef propres
		ville.nom = String(RP().nom)
		ville.maire = String(RP().chef)
	if variante == "pillee":   # portes enfoncées, grandes ouvertes (DEC-151)
		ville.porte_e = 1.0
		ville.porte_s = 1.0
	_ville_installer()
	return true


# Nom (tiré au hasard, sans doublon) et maire de la ville d'un secteur, gardés ensuite par le secteur
func ville_nommer(sid: int, r: RandomNumberGenerator) -> String:
	var D := VD()
	var s: Dictionary = monde.secteurs[sid]
	if String(s.get("ville", "")) == "":
		var pris := {}
		for s2 in monde.secteurs:
			pris[String(s2.get("ville", ""))] = true
		var libres: Array = D.noms.filter(func(n): return not pris.has(n))
		if libres.is_empty():
			libres = D.noms
		s["ville"] = String(libres[r.randi() % libres.size()])
		s["maire"] = String(D.maires[r.randi() % D.maires.size()])
	return String(s.ville)


# Terrain plat dans l'enceinte ; rien de ce qui avait été semé sur la route ne reste dans la ville
func _ville_installer() -> void:
	var x0 := float(ville.x0)
	var x1 := float(ville.x1)
	Terrain.aplanir(x0 - 6.0, x1 + 6.0)
	batiments = batiments.filter(func(b): return b.x + b.longueur < x0 - 40.0 or b.x > x1 + 40.0)
	mines = mines.filter(func(mn): return float(mn.x) < x0 - 150.0 or float(mn.x) > x1 + 100.0)
	monde.pnj = monde.pnj.filter(func(p): return float(p.x) < x0 - 60.0 or float(p.x) > x1 + 40.0)
	_prochain_champ_x = maxf(_prochain_champ_x, x1 + 200.0)


func _ville_retirer() -> void:
	ville = {}
	Terrain.aplanir_effacer()


# Kit (Mode créatif) : une ville juste devant
func kit_ville(variante := "standard") -> bool:
	if not bac_a_sable:
		return false
	var xt := x_tete
	for v in convoi:
		xt = maxf(xt, v.x + v.longueur)
	var ok := ville_creer(xt + float(VD().kit_distance_m), variante)
	if ok:
		log_(Textes.t("ville.001", [ville.nom, int(float(ville.x0) - x_tete)]), "info")
	return ok


# --- Pas de simulation -----------------------------------------------------------------------
func _ville(dt: float) -> void:
	if not ville_active():
		return
	var D := VD()
	var x0 := float(ville.x0)
	var x1 := float(ville.x1)
	if ville_protegee():
		_ville_securiser()
	match ville_phase():
		"approche":
			if not ville.annoncee and x0 - x_tete < float(D.annonce_m):
				ville.annoncee = true
				if ville_pillee():
					log_(Textes.t("ville.002", [ville.nom]), "alerte")
				else:
					log_(Textes.t("ville.003", [ville.nom]), "ok")
				evt({"t": "ville", "etat": "annonce"})
			if ville_pillee() and x_tete >= x0 - 6.0:   # personne pour ouvrir : on entre au pas (DEC-151)
				ville.phase = "entree"
				ordres.marche = "halte"
				ville.x_arret = x0 + maxf(float(D.arret_dans_ville_m), 8.0 + x_tete - _queue_x())
				_ville_securiser()
			if x_tete >= x0 - float(D.arret_avant_porte_m) - 0.05:
				ville.phase = "ouverture"
				ville.t = 0.0
				ordres.marche = "halte"
				_ville_securiser()
				log_(Textes.t("ville.004", [ville.nom]), "info")
				evt({"t": "ville", "etat": "porte"})
		"ouverture":
			ville.t += dt
			ville.porte_e = clampf(float(ville.t) / float(D.porte_s), 0.0, 1.0)
			if float(ville.t) >= float(D.porte_s):
				ville.phase = "entree"
				ville.x_arret = x0 + maxf(float(D.arret_dans_ville_m), 8.0 + x_tete - _queue_x())
		"entree":
			if _queue_x() > x0 + 3.0 and not ville_pillee():
				ville.porte_e = maxf(0.0, float(ville.porte_e) - dt / float(D.porte_s))   # la porte se referme derrière nous
			if x_tete >= float(ville.x_arret) - 0.05 and (float(ville.porte_e) <= 0.0 or ville_pillee()):
				if ville_repaire():   # le Berliet monte sur le monte-charge (DEC-166)
					ville.phase = "monte_charge"
					ville.t = 0.0
					log_(Textes.t("ville.005"), "alerte")
					evt({"t": "ville", "etat": "monte_charge"})
				else:
					ville.phase = "dedans"
					_ville_arrivee()
		"monte_charge":
			ville.t += dt
			if float(ville.t) >= float(RP().monte_charge_s):
				ville.phase = "trone"
				ville.t = 0.0
		"trone":
			ville.t += dt
			if float(ville.t) >= float(RP().trone_s):
				_repaire_arene()
		"arene":
			if ennemis.filter(func(e): return e.actif() and e.get_meta("arene", false)).is_empty():
				var R: Dictionary = RP().recompense
				for k in R:
					stocks[k] = float(stocks.get(k, 0.0)) + float(R[k])
				log_(Textes.t("ville.006"), "ok")
				ville.phase = "dedans"
				ville.vaincu = true
				evt({"t": "ville", "etat": "victoire"})
		"depart":
			if ville_pillee() and x_tete >= x1 - float(D.arret_avant_porte_m) - 0.05:
				ville.phase = "sortie"   # porte de sortie enfoncée : on file
			elif x_tete >= x1 - float(D.arret_avant_porte_m) - 0.05:
				ville.phase = "ouverture_s"
				ville.t = 0.0
				log_(Textes.t("ville.007"), "info")
				evt({"t": "ville", "etat": "porte"})
		"ouverture_s":
			ville.t += dt
			ville.porte_s = clampf(float(ville.t) / float(D.porte_s), 0.0, 1.0)
			if float(ville.t) >= float(D.porte_s):
				ville.phase = "sortie"
		"sortie":
			if _queue_x() > x1 + 4.0:
				ville.phase = "fin"
				ordres.marche = "avancer"
				log_(Textes.t("ville.008", [ville.nom]), "info")
				evt({"t": "ville", "etat": "sortie"})
		"fin":
			if not ville_pillee():
				ville.porte_s = maxf(0.0, float(ville.porte_s) - dt / float(D.porte_s))
			if x_tete > x1 + 260.0 or x_tete < x0 - 400.0:
				_ville_retirer()


# Arène du repaire : le Baron et sa garde surgissent devant le convoi ; le convoi peut manœuvrer et combattre
func _repaire_arene() -> void:
	var A: Dictionary = RP().arene
	ville.phase = "arene"
	ordres.marche = "halte"
	var x := x_tete + float(A.distance_m)
	var i := 0
	for t in A.vehicules:
		var e = creer_vehicule(String(t), "ennemi", x + i * 9.0)
		if e == null:
			continue
		e.set_meta("arene", true)
		if i == 0:   # le Baron : son char, plus solide
			e.nom = "Char du Baron"
			for pid in e.pieces:
				e.pieces[pid].max = float(e.pieces[pid].max) * float(A.pv_boss)
				e.pieces[pid].pv = e.pieces[pid].max
		ennemis.append(e)
		i += 1
	log_(Textes.t("ville.009"), "alerte")
	evt({"t": "ville", "etat": "arene"})


# Hauteur du monte-charge en mètres (0 en bas, hauteur_m à l'étage du trône), lue par la vue
func repaire_levee() -> float:
	match ville_phase():
		"monte_charge":
			var k := clampf(float(ville.t) / float(RP().monte_charge_s), 0.0, 1.0)
			return float(RP().hauteur_m) * k * k * (3.0 - 2.0 * k)
		"trone":
			return float(RP().hauteur_m)
	return 0.0


func repaire_replique() -> String:
	if ville_phase() != "trone":
		return ""
	var R: Array = RP().repliques
	return String(R[clampi(int(float(ville.t) / (float(RP().trone_s) / R.size())), 0, R.size() - 1)])


# Dans l'enceinte : rien ne peut arriver
func _ville_securiser() -> void:
	ennemis = ennemis.filter(func(e): return not e.actif())
	abordeurs.clear()
	tempete = {}
	monde.pietons = monde.pietons.filter(func(p): return p.camp == "joueur")


func _ville_arrivee() -> void:
	var s: Dictionary = monde.secteurs[int(ville.secteur)]
	var neuve := not bool(s.get("ville_connue", false))
	s["ville_connue"] = true
	if neuve:
		log_(Textes.t("ville.010", [ville.nom]), "ok")
	if ville_pillee():
		log_(Textes.t("ville.011", [ville.nom]), "alerte")
	else:
		log_(Textes.t("ville.012", [ville.nom]), "ok")
	evt({"t": "ville", "etat": "dedans", "nouvelle": neuve})
	_mission_arrivee()


# Redéfinie par modele_mission.gd : livraison à l'arrivée
func _mission_arrivee() -> void:
	pass


# Vitesse du convoi imposée par la ville (appelée par _marche) : vit = vitesse voulue, vmax = vitesse possible
func _ville_vitesse(vit: float, vmax: float) -> float:
	if not ville_active():
		return vit
	var D := VD()
	var lente := float(D.vitesse_forcee)
	var mini := float(D.vitesse_mini_freinage)
	match ville_phase():
		"approche":
			if ville_pillee():   # pas d'arrêt : on ralentit en approchant de la porte enfoncée
				var k2 := clampf((float(ville.x0) - x_tete) / float(D.variantes.pillee.ralenti_entree_m), 0.0, 1.0)
				return minf(vit, maxf(lente, vmax * k2)) if vit > 0.0 else vit
			var stop := float(ville.x0) - float(D.arret_avant_porte_m)
			if vit > 0.0:
				var k := clampf((stop - x_tete) / float(D.freinage_m), 0.0, 1.0)   # on freine doucement
				return minf(vit, maxf(mini, vmax * k)) if x_tete < stop else 0.0
			return vit
		"ouverture", "ouverture_s", "dedans", "chargement", "rassemblement":
			blocage = "" if ville_dedans() else ("Préparatifs du départ." if ville_phase() in ["chargement", "rassemblement"] else "Ouverture de la porte.")
			return 0.0
		"monte_charge", "trone":
			blocage = Textes.t("ville.013")
			return 0.0
		"arene":   # on manœuvre librement entre les murs de l'arène
			if (vit > 0.0 and x_tete >= float(ville.x1) - 5.0) or (vit < 0.0 and _queue_x() <= float(ville.x0) + 2.0):
				return 0.0
			return vit
		"entree":
			blocage = Textes.t("ville.014", [ville.nom])
			return _rouler_vers(float(ville.x_arret), lente, mini)
		"depart":
			blocage = Textes.t("ville.015")
			if ville_pillee():   # poursuite : on accélère dans la ville (DEC-151)
				return minf(vmax, float(D.variantes.pillee.vitesse_poursuite))
			return _rouler_vers(float(ville.x1) - float(D.arret_avant_porte_m), lente, mini)
		"sortie":
			blocage = Textes.t("ville.016", [ville.nom])
			return minf(vmax, float(D.variantes.pillee.vitesse_poursuite)) if ville_pillee() else lente
		"fin":
			if vit < 0.0 and _queue_x() <= float(ville.x1) + 4.0 and not ville_pillee():
				return 0.0   # porte refermée derrière nous
	return vit


func _rouler_vers(cible: float, lente: float, mini: float) -> float:
	var reste := cible - x_tete
	if reste <= 0.0:
		return 0.0
	return minf(reste / DT, maxf(mini, lente * clampf(reste / 10.0, 0.0, 1.0)))


# Ordres de marche ignorés pendant les mouvements forcés et dans la ville
func ville_bloque_marche() -> bool:
	if ville_phase() in PHASES_FORCEES:
		return true
	if ville_dedans():
		log_(Textes.t("ville.017", [ville.nom]), "info")
		return true
	return false


# --- Sorties ---------------------------------------------------------------------------------
const CARDINAUX := ["l'est", "le sud-est", "le sud", "le sud-ouest", "l'ouest", "le nord-ouest", "le nord", "le nord-est"]

# Les secteurs voisins les plus proches : [{id, porte, secteur, ville, niveau, distance_m}]
func ville_sorties() -> Array:
	var ici: Vector2 = monde.secteurs[monde.secteur].pos
	var autres: Array = monde.secteurs.filter(func(s): return int(s.id) != monde.secteur)
	autres.sort_custom(func(a, b): return ici.distance_to(a.pos) < ici.distance_to(b.pos))
	var res := []
	for s in autres.slice(0, int(VD().sorties)):
		var d: Vector2 = s.pos - ici
		var oct := int(round(fposmod(atan2(d.y, d.x), TAU) / (TAU / 8.0))) % 8   # y de la carte vers le bas = sud
		var connue := bool(s.get("ville_connue", false))
		res.append({"id": int(s.id), "porte": "Porte vers " + CARDINAUX[oct], "secteur": s.nom, "ville": String(s.get("ville", "")) if connue else "",
			"niveau": int(s.niveau), "distance_m": int(250.0 + ici.distance_to(s.pos) * 900.0)})
	# Demi-tour (DEC-168) : la porte qui ramène vers l'ancienne destination est toujours proposée
	var p: int = monde.secteur_prec
	if p >= 0 and p != monde.secteur and res.filter(func(e): return int(e.id) == p).is_empty():
		var s0: Dictionary = monde.secteurs[p]
		res.append({"id": p, "porte": "Porte du retour", "secteur": s0.nom, "ville": String(s0.get("ville", "")) if bool(s0.get("ville_connue", false)) else "",
			"niveau": int(s0.niveau), "distance_m": int(250.0 + ici.distance_to(s0.pos) * 900.0)})
	for e in res:
		e["retour"] = int(e.id) == p
	return res


func ville_partir(dest: int) -> bool:
	if not ville_dedans():
		return false
	if not monde.choisir_destination(dest):
		return false
	ville.dest = dest
	ville.phase = "depart"
	log_(Textes.t("ville.018"), "info")
	evt({"t": "ville", "etat": "depart"})
	return true


# --- Services --------------------------------------------------------------------------------
func ville_cout_reparation() -> int:
	var manque := 0.0
	for v in convoi:
		for pid in v.pieces:
			manque += maxf(0.0, float(v.pieces[pid].max) - float(v.pieces[pid].pv))
	return int(ceil(manque * float(VD().reparation_metal_par_pv)))


func ville_a_reparer() -> bool:
	for v in convoi:
		if not v.roues_perdues.is_empty():
			return true
		for pid in v.pieces:
			if float(v.pieces[pid].pv) < float(v.pieces[pid].max):
				return true
	return false


# Le mécanicien remet tout le convoi en état, contre du métal
func ville_reparer() -> bool:
	if not ville_dedans() or not ville_a_reparer():
		return false
	var cout := ville_cout_reparation()
	if not bac_a_sable and stocks.metal < cout:
		log_(Textes.t("ville.019", [cout]), "alerte")
		return false
	if not bac_a_sable:
		stocks.metal -= cout
	for v in convoi:
		for pid in v.pieces:
			v.pieces[pid].pv = v.pieces[pid].max
		v.roues_perdues.clear()
	log_(Textes.t("ville.020", [(0 if bac_a_sable else cout)]), "ok")
	evt({"t": "repare"})
	return true


# Marché : un lot d'eau ou de vivres contre du métal (DEC-148)
func ville_prix_lot(k: String) -> int:
	var Mc: Dictionary = VD().marche
	return int(Mc.lot) * int(Mc.prix_metal[k])


func ville_acheter(k: String) -> bool:
	if not ville_dedans() or not VD().marche.prix_metal.has(k):
		return false
	var prix := ville_prix_lot(k)
	if not bac_a_sable and stocks.metal < prix:
		log_(Textes.t("ville.021", [prix]), "alerte")
		return false
	if not bac_a_sable:
		stocks.metal -= prix
	stocks[k] = float(stocks.get(k, 0.0)) + float(VD().marche.lot)
	log_(Textes.t("ville.022", [int(VD().marche.lot), Textes.t("lot." + k), prix]), "ok")
	return true


func ville_texte_maire() -> String:
	return "M. %s, maire de %s, vous reçoit dans son bureau, sous le portrait jauni d'un président dont plus personne ne se souvient.\n\n« Ici, la porte ouvre à qui ne tire pas. Restez le temps qu'il faut. Pour le travail, revenez plus tard : je n'ai rien pour vous aujourd'hui. »" % [ville.maire, ville.nom]


# --- Sauvegarde ------------------------------------------------------------------------------
func ville_sauver() -> Dictionary:
	var connues := {}
	for s in monde.secteurs:
		if String(s.get("ville", "")) != "":
			connues[str(s.id)] = {"ville": s.ville, "maire": s.get("maire", ""), "connue": bool(s.get("ville_connue", false))}
	return {"on": villes_on, "n": _n_villes, "ville": ville.duplicate(), "secteurs": connues}


func ville_charger(d: Dictionary) -> void:
	villes_on = bool(d.get("on", false))
	_n_villes = int(d.get("n", 0))
	var sc: Dictionary = d.get("secteurs", {})
	for k in sc:
		var s: Dictionary = monde.secteurs[int(k)]
		s["ville"] = String(sc[k].ville)
		s["maire"] = String(sc[k].maire)
		s["ville_connue"] = bool(sc[k].connue)
	var v: Dictionary = d.get("ville", {})
	if not v.is_empty():
		ville = v.duplicate()
		for k in ["x0", "x1", "t", "porte_e", "porte_s", "x_arret"]:
			ville[k] = float(ville[k])
		for k in ["secteur", "dest", "graine"]:
			ville[k] = int(ville[k])
		Terrain.aplanir(float(ville.x0) - 6.0, float(ville.x1) + 6.0)


# --- Dépôt contre reçu (DEC-157, DEV-027) ----------------------------------------------------------------
# On laisse des ressources dans une ville contre un reçu papier ; on les retire dans n'importe quelle ville :
# intégralement là où on les a laissées, avec 10 % de perte ailleurs (valeur : villes.json → depot.perte).
var recus: Array = []   # [{"secteur": id, "ville": nom, "res": {stock: qté}}]

func ville_deposer(res: Dictionary) -> bool:
	if not ville_dedans() or res.is_empty():
		return false
	for k in res:
		if float(stocks.get(k, 0.0)) < float(res[k]) or float(res[k]) <= 0.0:
			return false
	for k in res:
		stocks[k] = float(stocks[k]) - float(res[k])
	recus.append({"secteur": monde.secteur, "ville": String(ville.nom), "res": res.duplicate()})
	log_(Textes.t("ville.023", [ville.nom]), "ok")
	return true


func ville_retirer() -> bool:
	if not ville_dedans() or recus.is_empty():
		return false
	var perte := float(VD().get("depot", {}).get("perte", 0.10))
	for r in recus:
		var f := 1.0 if int(r.secteur) == monde.secteur else 1.0 - perte
		for k in r.res:
			stocks[k] = float(stocks.get(k, 0.0)) + floorf(float(r.res[k]) * f)
	log_(Textes.t("ville.024", [recus.size(), int(perte * 100.0)]), "ok")
	recus.clear()
	return true
