# Modèle du mode convoi : un convoi contrôlable avance de profil, affronte des ennemis
class_name CombatModele
extends "res://scripts/combat/modele_terrain.gd"


# --- État de la partie -----------------------------------------------------
func _init(g := 1) -> void:
	graine = g
	rng.seed = g
	var D := donnees()
	stocks = D.stocks_depart.duplicate()
	for t in D.depart:
		convoi.append(creer_vehicule(t, "joueur", 0.0))
	var bord := 0.0
	for v in convoi:
		bord += v.longueur + D.ecart_convoi
	x_tete = bord - D.ecart_convoi
	_replacer(true)
	x_tete_prev = x_tete
	for v in convoi:
		v.x_prev = v.x
	monde = MondeJeu.new(self)
	log_("Une Jeep et deux survivants. Avancez pour trouver de quoi vous équiper.", "info")


# --- Ordres ----------------------------------------------------------------
func ordre_marche(m: String) -> void:
	if m in ["avancer", "halte", "recul"] and ordres.marche != m:
		ordres.marche = m
		if m != "halte":
			for v in convoi:
				v.reparation = false
			fouille_en_cours = {}

func ordre_cible(c: String) -> void:
	if c in ["proche", "vehicules", "batiments"]:
		ordres.cible = c

func ordre_visee(z: String) -> void:
	if z in ["libre", "roulement", "armement", "chassis"]:
		ordres.visee = z

func ordre_fouille(f: String) -> void:
	if f in ["auto", "arret"]:
		ordres.fouille = f

func ordre_tir(uid: int, actif: bool) -> void:
	var v = trouver(uid)
	if v is Veh and v.camp == "joueur":
		v.tir = actif

func ordre_reparer(uid: int, actif: bool, piece := "") -> bool:
	var v = trouver(uid)
	if not (v is Veh) or not (convoi.has(v) or v.recuperable()):
		return false
	if not actif:
		v.reparation = false
		return true
	if ordres.marche != "halte":
		log_("Réparation impossible en mouvement : ordonnez Halte.", "alerte")
		return false
	if not _mecanicien_possible(v):
		log_("Aucun mécanicien à portée : approchez le convoi.", "alerte")
		return false
	v.reparation = true
	v.rep_piece = piece
	v.rep_pret = 0.0
	v.rep_acc = 0.0
	return true

func peut_rejoindre(v: Veh) -> bool:
	return v.recuperable() and v.piece_ok("chassis") and v.piece_ok("roulement") and v.piece_ok("moteur") \
		and ordres.marche == "halte" and _mecanicien_possible(v)

func rejoindre(uid: int) -> bool:
	var v = trouver(uid)
	if not (v is Veh) or not peut_rejoindre(v):
		return false
	epaves.erase(v)
	v.statut = "actif"
	v.camp = "joueur"
	v.reparation = false
	v.tir = true
	v.butin_pris = true
	v.equipage = [float(donnees().equipage_pv)]
	while reserve_survivants > 0 and v.equipage.size() < int(v.profil.equipage):
		v.equipage.append(float(donnees().equipage_pv))
		reserve_survivants -= 1
	v.x_prev = v.x
	for a in v.armes:
		a.cd = 1.0
	convoi.append(v)
	_replacer()
	log_("%s rejoint le convoi." % v.nom, "ok")
	evt({"t": "rejoint", "uid": v.uid})
	return true

func _dire_lore() -> void:
	if not _lore_dit:
		_lore_dit = true
		log_("On ne revoit jamais ceux qui s'éloignent.", "info")

func liste_survivants() -> Array:
	var res := []
	for v in convoi:
		_aligner_noms(v)
		for i in v.equipage.size():
			res.append({"nom": v.noms[i], "pv": v.equipage[i], "lieu": v.nom, "veh_uid": v.uid, "idx": i})
	for b in batiments:
		for g in b.garnison:
			res.append({"nom": g.get("nom", "Survivant"), "pv": g.pv, "lieu": b.nom, "veh_uid": -1, "idx": -1})
	for t in transits:
		for k in t.pvs.size():
			res.append({"nom": t.noms[k], "pv": t.pvs[k], "lieu": "en chemin", "veh_uid": -1, "idx": -1})
	return res

func etat_sante(pv: float) -> String:
	var q: float = pv / float(donnees().equipage_pv)
	if pv <= 0.0:
		return "Hors de combat"
	if q > 0.8:
		return "En forme"
	if q > 0.4:
		return "Blessé"
	return "Gravement blessé"

func affecter(de_uid: int, idx: int, vers_uid: int) -> bool:
	var a = trouver(de_uid)
	var b = trouver(vers_uid)
	if not (a is Veh and b is Veh) or not convoi.has(a) or not convoi.has(b) or a == b:
		return false
	if ordres.marche != "halte":
		log_("Arrêtez le convoi pour changer d'affectation.", "alerte")
		return false
	_aligner_noms(a)
	_aligner_noms(b)
	if idx < 0 or idx >= a.equipage.size() or a.equipage[idx] <= 0.0:
		return false
	if b.equipage.size() >= int(b.profil.equipage) or not b.actif():
		log_("%s n'a pas de place libre." % b.nom, "alerte")
		return false
	var pv: float = a.equipage[idx]
	var nom: String = a.noms[idx]
	a.equipage.remove_at(idx)
	a.noms.remove_at(idx)
	b.equipage.append(pv)
	b.noms.append(nom)
	log_("%s passe dans %s." % [nom, b.nom], "info")
	return true


# --- Demi-tour : le convoi repart dans l'autre sens ---------------------------------
func ordre_demi_tour() -> bool:
	if menace() or not transits.is_empty() or monde.en_transit() and false:
		log_("Demi-tour impossible : des ennemis sont trop proches.", "alerte")
		return false
	for v in convoi:
		if v.garage != 0:
			log_("Sortez les véhicules du garage avant le demi-tour.", "alerte")
			return false
	var arriere := INF
	for v in convoi:
		arriere = minf(arriere, v.x)
	var c: float = (arriere + x_tete) * 0.5
	for e in ennemis + epaves:
		e.x = 2.0 * c - (e.x + e.longueur)
		e.x_prev = e.x
	for b in batiments:
		b.x = 2.0 * c - (b.x + b.longueur)
	for mn in mines:
		mn.x = 2.0 * c - mn.x
	for p in monde.pietons:
		p.x = 2.0 * c - (p.x + p.longueur)
		p.x_prev = p.x
		p.dir = -p.dir
	for pn in monde.pnj:
		pn.x = 2.0 * c - pn.x
	convoi.reverse()
	x_tete = 2.0 * c - arriere
	_replacer(true)
	x_tete_prev = x_tete
	for v in convoi:
		v.x_prev = v.x
	ennemis = ennemis.filter(func(e): return e.x > x_tete - 30.0)   # ceux qu'on laisse derrière ne reviennent pas
	projectiles.clear()
	fouille_demandee = 0
	fouille_en_cours = {}
	_prochain_x = x_tete + 150.0
	monde.x_entree = x_tete
	ordres.marche = "halte"
	log_("Demi-tour : le convoi repart dans l'autre sens.", "info")
	evt({"t": "demitour"})
	return true


# --- Sauvegarde : le convoi et ses réserves (pas les rencontres autour) -----------------
func sauver() -> Dictionary:
	var vehs := []
	for v in convoi:
		_aligner_noms(v)
		var eq: Array = v.equipage.duplicate()
		var nm: Array = v.noms.duplicate()
		for b in batiments:
			for g in b.garnison:
				if g.veh == v.uid:
					eq.append(g.pv)
					nm.append(g.get("nom", "Survivant"))
		for t in transits:
			if t.veh == v.uid:
				eq.append_array(t.pvs)
				nm.append_array(t.noms)
		var pcs := {}
		for pid in v.pieces:
			pcs[pid] = v.pieces[pid].pv
		vehs.append({"type": v.type, "pieces": pcs, "equipage": eq, "noms": nm, "statut": v.statut, "tir": v.tir})
	var w := monde
	return {"v": 1, "graine": graine, "temps": temps, "x_tete": x_tete, "stocks": stocks.duplicate(), "composants": composants.duplicate(true),
		"distance_max": distance_max, "tues": ennemis_detruits, "n_rencontres": _n_rencontres, "n_noms": _n_noms, "lore": _lore_dit,
		"reserve": reserve_survivants, "rng": str(rng.state), "convoi": vehs,
		"monde": {"secteur": w.secteur, "x_entree": w.x_entree, "trajet": w.trajet.duplicate(), "heure": w.heure, "jour": w.jour, "quete": w.quete.duplicate(true)}}

static func depuis_sauvegarde(d: Dictionary) -> CombatModele:
	var m := CombatModele.new(int(d.graine))
	m.convoi.clear()
	m.temps = float(d.temps)
	m.x_tete = float(d.x_tete)
	for k in d.stocks:
		m.stocks[k] = float(d.stocks[k])
	m.composants = d.composants
	m.distance_max = float(d.distance_max)
	m.ennemis_detruits = int(d.tues)
	m._n_rencontres = int(d.n_rencontres)
	m._n_noms = int(d.n_noms)
	m._lore_dit = bool(d.lore)
	m.reserve_survivants = int(d.reserve)
	for e in d.convoi:
		var v := m.creer_vehicule(e.type, "joueur", 0.0)
		for pid in e.pieces:
			if v.pieces.has(pid):
				v.pieces[pid].pv = float(e.pieces[pid])
		v.equipage = []
		for pv in e.equipage:
			v.equipage.append(float(pv))
		v.noms = e.noms.duplicate()
		v.statut = e.statut
		v.tir = bool(e.tir)
		m.convoi.append(v)
	m.ordres.marche = "halte"
	m._replacer(true)
	m.x_tete_prev = m.x_tete
	for v in m.convoi:
		v.x_prev = v.x
	m._prochain_x = m.x_tete + 80.0
	m.rng.state = int(d.rng)
	var w: Dictionary = d.monde
	m.monde.secteur = int(w.secteur)
	m.monde.x_entree = float(w.x_entree)
	m.monde.heure = float(w.heure)
	m.monde.jour = int(w.jour)
	m.monde.trajet = {}
	if not w.trajet.is_empty():
		m.monde.trajet = {"dest": int(w.trajet.dest), "reste": float(w.trajet.reste), "total": float(w.trajet.total)}
		m._prochain_x = INF
	m.monde.quete = {}
	if not w.quete.is_empty():
		m.monde.quete = {"titre": w.quete.titre, "abattre": int(w.quete.abattre), "depart": int(w.quete.depart), "recompense": w.quete.recompense}
	m.journal.clear()
	m.log_("Partie reprise.", "ok")
	return m

func monter(uid: int) -> void:
	_deplacer_rang(uid, -1)

func descendre(uid: int) -> void:
	_deplacer_rang(uid, 1)

func _deplacer_rang(uid: int, sens: int) -> void:
	for i in convoi.size():
		if convoi[i].uid == uid:
			var j := i + sens
			if j >= 0 and j < convoi.size():
				var t = convoi[i]
				convoi[i] = convoi[j]
				convoi[j] = t
			return

func abandonner(uid: int) -> void:
	_dire_lore()
	for i in convoi.size():
		var v: Veh = convoi[i]
		if v.uid == uid:
			if convoi.size() <= 1:
				log_("Impossible d'abandonner le dernier véhicule.", "alerte")
				return
			convoi.remove_at(i)
			v.x_prev = v.x
			v.statut = "abandonne"
			v.reparation = false
			v.butin = _butin_vehicule(v, 0.9)
			epaves.append(v)
			log_("%s abandonné : ses pièces peuvent être récupérées." % v.nom, "alerte")
			return


# --- Pas de simulation -----------------------------------------------------
func avancer(dt := DT) -> void:
	if fini:
		return
	temps += dt
	x_tete_prev = x_tete
	for v in convoi + ennemis:
		v.x_prev = v.x
	_marche(dt)
	_ia_ennemis(dt)
	for v in convoi.duplicate():
		if v.actif():
			_armes_vehicule(v, dt)
	for e in ennemis.duplicate():
		if e.actif():
			_armes_vehicule(e, dt)
	for b in batiments:
		if b.actif():
			_armes_batiment(b, dt)
	_armes_garnison(dt)
	_projectiles(dt)
	_mines(dt)
	_transits(dt)
	monde.avancer(dt)
	_garage(dt)
	_camouflage(dt)
	_reparer(dt)
	_fouiller(dt)
	_rencontres()
	_nettoyer()
	distance_max = maxf(distance_max, x_tete)
	var vivants := 0
	for v in convoi:
		if v.actif():
			vivants += 1
	if vivants == 0:
		fini = true
		log_("Le convoi est anéanti. Distance parcourue : %d m." % int(distance_max), "alerte")

func _marche(dt: float) -> void:
	var vit := 0.0
	blocage = ""
	var actifs: Array = convoi.filter(func(v): return v.actif())
	if ordres.marche != "halte" and not actifs.is_empty():
		var vmax := INF
		var immobilise := false
		var sans_equipage := false
		var cache := false
		var au_garage := false
		for v in actifs:
			vmax = minf(vmax, v.vitesse())
			immobilise = immobilise or not v.mobile()
			sans_equipage = sans_equipage or v.equipage_vivant() == 0
			cache = cache or v.camo_voulu
			au_garage = au_garage or v.garage != 0
		if not transits.is_empty():
			blocage = "Équipages en déplacement."
		elif sans_equipage:
			blocage = "Un véhicule n'a plus d'équipage : rembarquez-le avant de repartir."
		elif not monde.dialogue.is_empty():
			blocage = "Un voyageur vous parle."
		elif au_garage:
			blocage = "Un véhicule est au garage : sortez-le avant de repartir."
		elif cache:
			blocage = "Un véhicule est camouflé : découvrez-le avant de repartir."
		elif immobilise:
			blocage = "Un véhicule est immobilisé : réparez-le ou abandonnez-le."
		elif stocks.fuel_l <= 0.0:
			blocage = "Panne sèche : plus de carburant."
		elif not fouille_en_cours.is_empty():
			blocage = "Fouille en cours."
		else:
			var pente: float = Terrain.pente(x_tete)
			vmax *= clampf(1.0 - 2.4 * pente, 0.55, 1.3)   # montée : plus lent ; descente : plus vite
			vit = vmax if ordres.marche == "avancer" else -0.6 * vmax
			if vit > 0.0:
				for e in ennemis:
					if e.actif() and e.x - x_tete < 1.6 and e.x + e.longueur > x_tete - 8.0:
						vit = 0.0
						blocage = "La route est barrée par un véhicule ennemi."
						break
	x_tete += vit * dt
	vitesse_convoi = vit
	if vit != 0.0:
		var litres := 0.0
		for v in actifs:
			litres += v.profil.conso / 100.0 * absf(vit) * dt
		stocks.fuel_l = maxf(0.0, stocks.fuel_l - litres)
	_replacer()
	for v in convoi:
		v.x = move_toward(v.x, v.x_cible, (absf(vit) + 6.0) * dt)
		v.vitesse_act = vit

func _ia_ennemis(dt: float) -> void:
	for e in ennemis:
		e.vitesse_act = 0.0
		if e.actif() and e.mode == "approche" and e.mobile():
			var stand: float = e.profil.get("standoff", 32.0)
			if e.x - x_tete > stand:
				e.x -= e.vitesse() * dt
				e.vitesse_act = e.vitesse()


# --- Rencontres ------------------------------------------------------------
func _rencontres() -> void:
	if x_tete + 120.0 < _prochain_x or ennemis.size() >= 5 or monde.en_transit():
		return
	var R: Dictionary = donnees().rencontres
	_n_rencontres += 1
	var r := RandomNumberGenerator.new()
	r.seed = graine * 7919 + _n_rencontres
	var niveau: int = monde.niveau_a(_prochain_x)
	var liste := []
	var total := 0.0
	for e in R.liste:
		if niveau >= e.niveau_min and niveau <= e.niveau_max:
			liste.append(e)
			total += e.poids
	var tirage := r.randf() * total
	var choix: Dictionary = liste[liste.size() - 1]
	for e in liste:
		tirage -= e.poids
		if tirage <= 0.0:
			choix = e
			break
	if _n_rencontres == 1 and R.has("premiere"):
		choix = R.premiere
	var x := x_tete + 120.0
	var debut := x
	for t in choix.get("vehicules", []):
		var e := creer_vehicule(t, "ennemi", x)
		e.mode = choix.get("mode", "approche")
		ennemis.append(e)
		x += e.longueur + r.randf_range(5.0, 12.0)
	for bt in choix.get("batiments", []):
		var b := creer_batiment(bt, x + r.randf_range(4.0, 14.0))
		batiments.append(b)
		x = b.x + b.longueur
	for t in choix.get("trouvailles", []):
		var f := creer_vehicule(t, "joueur", x)
		f.statut = "trouvee"
		f.equipage = []
		f.noms = []
		var casses := 0
		for id in f.pieces:
			if id != "chassis" and r.randf() < 0.5:
				var q := 0.0 if r.randf() < 0.5 else r.randf_range(0.1, 0.7)
				f.pieces[id].pv = f.pieces[id].max * q
				casses += 1
		if casses == 0:
			f.pieces.roulement.pv = 0.0
		f.butin = _butin_vehicule(f, 0.6)
		epaves.append(f)
		x += f.longueur + 6.0
	if choix.has("ruine"):
		var b := creer_batiment(choix.ruine, x + r.randf_range(2.0, 10.0))
		b.statut = "neutralise"
		b.pv = b.pv_max * 0.35
		for t in b.tireurs:
			t.pv = 0.0
		b.butin.ressources["survivants"] = 1 if (choix.get("survivant", false) or r.randf() < 0.4) else 0
		batiments.append(b)
		x = b.x + b.longueur
	x = monde.generer(choix, x, r)
	var hostile := not ennemis.is_empty() or batiments.any(func(b): return b.actif()) or monde.vivants() > 0
	evt({"t": "contact", "ennemi": hostile})
	log_("%s à %d m." % ["Contact" if hostile else "Du nouveau", int(debut - x_tete)], "info")
	_prochain_x = x + r.randf_range(R.intervalle[0], R.intervalle[1])

func _nettoyer() -> void:
	var limite := x_tete - 260.0
	epaves = epaves.filter(func(v): return v.x + v.longueur > limite)
	batiments = batiments.filter(func(b): return b.x + b.longueur > limite)
	mines = mines.filter(func(mn): return mn.x > limite)
	monde.nettoyer(limite)
