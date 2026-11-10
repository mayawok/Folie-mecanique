# Chocs entre véhicules (DEC-215) : éperonner par l'avant (choc frontal), par l'arrière (« rear-ended »),
# doubler ou croiser par la voie d'à côté.
#  - Ordre « conduite » du convoi : « eviter » (on double et on croise sans toucher) ou « eperonner » (on fonce dedans).
#  - Les ennemis décident à leur apparition s'ils éperonnent (proba du bloc « choc »).
#  - Une moto visée a 2 chances sur 3 de se jeter sur la voie d'à côté et d'éviter le choc.
#  - Dégâts : masse de l'autre × vitesse relative × lame avant (Berliet, DEC-212) ; avant = moteur, arrière = roues.
# Valeurs : bloc « choc » de combat_proto.json.
extends "res://scripts/combat/modele_abordage.gd"

var _intention := {}   # uid ennemi -> vrai s'il éperonne
var _cd_choc := {}     # uid -> délai avant un nouveau choc (s)


func CH() -> Dictionary:
	return donnees().choc


func conduite() -> String:
	return String(ordres.get("conduite", "eviter"))


func ordre_conduite(c: String) -> void:
	if c in ["eviter", "eperonner"]:
		ordres.conduite = c
		log_(Textes.t("choc.001" if c == "eperonner" else "choc.002"), "info")


# Le véhicule roule sur la voie d'à côté (il ne barre pas notre route) : poursuivants, convois croisés, convois doublés
func voie_libre(e: Veh) -> bool:
	return e.mode in ["poursuite", "face"] or (e.mode == "convoi" and conduite() == "eviter")


func est_moto(v: Veh) -> bool:
	# deux-roues : 2 roues de profil ET court (une voiture aussi n'a que 2 roues de profil)
	var D: Dictionary = VehiculeDessin.donnees().vehicules.get(v.type, {})
	return D.get("roues", [1, 2, 3]).size() <= 2 and float(D.get("longueur", 9.0)) < 3.0


func eperonne(e: Veh) -> bool:
	if e.allie:
		return false
	if not _intention.has(e.uid):
		_intention[e.uid] = rng.randf() < float(CH().proba_ennemi)
	return bool(_intention[e.uid])


func _tete():
	var t = null
	for v in convoi:
		if v.actif() and v.garage == 0 and (t == null or v.x + v.longueur > t.x + t.longueur):
			t = v
	return t


func _queue():
	var q = null
	for v in convoi:
		if v.actif() and v.garage == 0 and (q == null or v.x < q.x):
			q = v
	return q


func _chocs(dt: float) -> void:
	for k in _cd_choc.keys():
		_cd_choc[k] = float(_cd_choc[k]) - dt
	var C := CH()
	var t = _tete()
	var q = _queue()
	if t == null:
		return
	var ct := float(C.contact)
	_saluts()
	for e in ennemis:
		if not e.actif() or e.allie or float(_cd_choc.get(e.uid, 0.0)) > 0.0:
			continue
		var avant: float = t.x + t.longueur
		# 1) Devant nous : on rentre dedans (ordre), ou un véhicule d'en face nous fonce dessus
		if e.x - avant < ct and e.x + e.longueur > t.x and e.x > t.x:
			var nous: bool = conduite() == "eperonner" and ordres.marche == "avancer"
			match String(e.mode):
				"face":   # convoi qui nous croise : choc frontal si l'un des deux le veut
					if nous or eperonne(e):
						_choc(t, e, absf(vitesse_convoi) + e.vitesse_act + float(C.elan), "avant", "avant", nous)
				"convoi":   # convoi devant dans notre sens : on l'emboutit par l'arrière (sinon on double)
					if nous:
						_choc(t, e, maxf(t.vitesse() - e.vitesse_act, 0.0) + float(C.elan), "avant", "arriere", true)
				"approche", "barrage":   # véhicule en travers de la route
					if nous:
						_choc(t, e, t.vitesse() * 0.6 + float(C.elan), "avant", "avant", true)
			continue
		if q == null:
			continue
		# 2) Derrière nous : un poursuivant nous emboutit, ou on recule dans un ennemi
		if e.x < q.x and e.x + e.longueur > q.x - ct:
			if e.mode == "poursuite" and eperonne(e) and e.vitesse_act > vitesse_convoi:
				_choc(e, q, e.vitesse_act - vitesse_convoi + float(C.elan), "avant", "arriere", false)
			elif conduite() == "eperonner" and ordres.marche == "recul":
				_choc(q, e, absf(vitesse_convoi) + float(C.elan), "arriere", "avant", true)


# a frappe b. cote_a / cote_b : « avant » ou « arriere ». par_joueur : c'est notre convoi qui a voulu le choc.
func _choc(a: Veh, b: Veh, vrel: float, cote_a: String, cote_b: String, par_joueur: bool) -> void:
	var C := CH()
	if vrel < float(C.vitesse_min):
		return
	_cd_choc[a.uid] = float(C.delai)
	_cd_choc[b.uid] = float(C.delai)
	var xc: float = (a.x + a.longueur) if cote_a == "avant" else a.x
	if a.camp == "ennemi":
		xc = (b.x + b.longueur) if cote_b == "avant" else b.x
	# La moto visée se jette sur la voie d'à côté (2 chances sur 3)
	if est_moto(b) and rng.randf() < float(C.esquive_moto):
		log_(Textes.t("choc.003", [b.nom]), "info")
		if b.camp == "ennemi" and b.mode in ["approche", "barrage", "convoi"]:
			b.mode = "face" if b.mode != "convoi" else "convoi"   # elle file sur l'autre voie
		elif b.camp == "ennemi":
			b.x -= float(C.recul)
		evt({"t": "esquive", "uid": b.uid, "x": xc})
		return
	var lame_a := float(a.profil.get("lame_choc", 1.0)) if cote_a == "avant" else 1.0
	var lame_b := float(b.profil.get("lame_choc", 1.0)) if cote_b == "avant" else 1.0
	var ma := float(a.profil.get("poids_kg", 1500.0)) / 1000.0
	var mb := float(b.profil.get("poids_kg", 1500.0)) / 1000.0
	var k := float(C.k)
	var vers_b := k * ma * vrel * lame_a / lame_b
	var vers_a := k * mb * vrel * lame_b / lame_a * float(C.part_frappeur)
	_degats_choc(b, vers_b, cote_b)
	_degats_choc(a, vers_a, cote_a)
	# Le plus léger est repoussé
	var recul := float(C.recul) * clampf(ma / maxf(0.2, mb), 0.3, 3.0)
	if b.camp == "ennemi":
		b.x += recul if b.x > a.x else -recul
	elif a.camp == "ennemi":
		a.x += -float(C.recul) if a.x < b.x else float(C.recul)
	var nous_b := b.camp == "joueur"
	var nom_ennemi: String = a.nom if nous_b else b.nom
	var nom_nous: String = b.nom if nous_b else a.nom
	if par_joueur:
		log_(Textes.t("choc.004", [nom_nous, nom_ennemi, int(vers_b)]), "info")
	elif cote_b == "arriere":
		log_(Textes.t("choc.005", [nom_ennemi, nom_nous]), "alerte")
	else:
		log_(Textes.t("choc.006", [nom_ennemi, nom_nous]), "alerte")
	evt({"t": "choc", "x": xc, "fort": vers_b + vers_a > float(C.fort)})


func _degats_choc(v: Veh, d: float, cote: String) -> void:
	if d <= 0.0 or not v.actif():
		return
	var zone := "moteur" if cote == "avant" else "roulement"
	if not v.pieces.has(zone) or float(v.pieces[zone].pv) <= 0.0:
		zone = "chassis"
	if cote == "avant":   # lame avant (DEC-212) : elle encaisse une partie du choc
		d = maxf(0.0, d - float(v.profil.get("lame_pv", 0)) * float(CH().lame_absorbe))
	_toucher_vehicule(null, {"degats": d, "penetration": float(CH().penetration), "classe": "choc"}, v, "libre", zone)
	_blesser_equipage(v, d * float(CH().equipage))


# Convoi d'en face (Kit) : il roule vers nous sur l'autre voie et nous croise
func _ia_face(dt: float) -> void:
	for e in ennemis:
		if e.actif() and e.mode == "face" and e.mobile():
			e.x -= e.vitesse() * dt
			e.vitesse_act = e.vitesse()


# --- Convois croisés sur la route (DEC-187, DEC-218) -------------------------------------------------
# Selon la réputation de la faction du secteur : un convoi allié (marchands, il ne tire pas, il vous salue et peut vous
# passer un bidon), un convoi hostile (armé, il fonce sur vous) ou rien de particulier. Valeurs : bloc « route » de combat_proto.json.
func RT() -> Dictionary:
	return donnees().route


func rencontre_convoi(r: RandomNumberGenerator, x: float) -> bool:
	if monde.niveau_a(x) < 1 or r.randf() > float(RT().proba_convoi):
		return false
	var fac := rep_faction_ici()
	var pal := String(rep_palier(fac).id)
	var allie_p: float = {"allie": 0.85, "amical": 0.7, "neutre": 0.3, "mefiant": 0.1, "hostile": 0.0}[pal]
	var est_allie := r.randf() < float(allie_p)
	var types: Array = RT().types_allie if est_allie else RT().types_hostile
	var xe := x
	for t in types:
		var e := creer_vehicule(String(t), "ennemi", xe)
		e.mode = "face"
		e.allie = est_allie
		if est_allie:
			e.armes = []
		else:
			_intention[e.uid] = true
		e.profil["fac"] = fac
		ennemis.append(e)
		xe += e.longueur + 6.0
	var nom := rep_nom(fac)
	log_(Textes.t("route.001" if est_allie else "route.002", [nom]), "info" if est_allie else "alerte")
	evt({"t": "contact", "ennemi": not est_allie})
	return true


# Le convoi allié nous a croisés : salut, réputation, et un bidon s'il nous apprécie
func _saluts() -> void:
	var q = _queue()
	if q == null:
		return
	for e in ennemis:
		if e.allie and e.actif() and not e.salue and e.x + e.longueur < q.x:
			e.salue = true
			var fac := String(e.profil.get("fac", ""))
			rep_changer(fac, float(RT().salut_rep), "")
			var pal := String(rep_palier(fac).id)
			if pal in ["amical", "allie"]:
				var t := "gazole" if rng.randf() < 0.5 else "essence"
				stocks[t] = float(stocks.get(t, 0.0)) + float(RT().cadeau_l)
				log_(Textes.t("route.003", [rep_nom(fac), int(RT().cadeau_l), Textes.t("carb." + t)]), "ok")
			else:
				log_(Textes.t("route.004", [rep_nom(fac)]), "info")
