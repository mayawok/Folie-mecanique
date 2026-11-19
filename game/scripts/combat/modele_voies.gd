# Trois voies de profondeur (DEC-250) : -1 fond (gauche du sens de marche), 0 route, 1 devant (droite).
# Tout le monde peut changer de voie ; on roule surtout au milieu.
#  - Notre convoi : au milieu ; serre à droite (devant) pour croiser un convoi allié ; double par la gauche (fond)
#    un convoi plus lent si l'ordre de conduite est « éviter » ; la tête va chercher sur sa voie un ennemi d'en face
#    si l'ordre est « éperonner ».
#  - Ennemis : béliers, barrages et harceleurs au milieu ; ceux qui contournent ou poursuivent passent sur un côté,
#    de préférence là où aucun de nos véhicules ne bouche la voie ; les convois croisés pacifiques au fond.
#  - Effets : choc de face ou par l'arrière seulement sur la même voie (modele_choc) ; abordage seulement depuis la
#    voie d'à côté (modele_abordage) ; coup de flanc entre voies voisines (une moto légère peut finir dans le fossé) ;
#    une cible cachée derrière un gros véhicule de la voie du milieu est plus dure à toucher.
# Valeurs : bloc « voies » de combat_proto.json.
extends "res://scripts/combat/modele_choc.gd"

var _cote := {}     # uid -> côté choisi (-1 ou 1) pour contourner ou aborder
var _percute := {} # uid -> poursuivant qui nous a déjà embouti par l'arrière
var _place := {}    # uid -> vrai une fois posé sur sa voie (apparition loin de nous : directement sur la bonne voie)


func VO() -> Dictionary:
	return donnees().voies


func _voies(dt: float) -> void:
	var V := VO()
	var t = _tete()
	for e in ennemis:
		if e.actif():
			e.voie = _voie_ennemi(e, t)
	for v in convoi:
		if v.actif() and v.garage == 0:
			v.voie = _voie_joueur(v, t)
	var pas := dt / float(V.duree_changement)
	for v in convoi + ennemis:
		if not v.actif() or not v.mobile():
			continue
		if not _place.has(v.uid):
			_place[v.uid] = true
			if v.camp == "ennemi" and t != null and ecart(v.x, v.longueur, t.x, t.longueur) > float(V.placement):
				v.voie_f = float(v.voie)   # il arrive de loin : déjà sur sa voie
				continue
		var cible := float(v.voie)
		if absf(cible - v.voie_f) > 0.01 and _voie_occupee(v, v.voie):
			cible = float(roundi(v.voie_f))   # la place est prise : il reste (ou revient) sur sa voie
		v.voie_f = move_toward(v.voie_f, cible, pas)


# Un autre véhicule roule déjà sur cette voie, à hauteur (marge en m de chaque côté)
func _voie_occupee(v: Veh, voie: int) -> bool:
	var mg := float(VO().marge_occupee)
	for w in convoi + ennemis:
		if w == v or not w.actif() or w.garage != 0:
			continue
		if absf(w.voie_f - voie) < 0.5 and w.x < v.x + v.longueur + mg and w.x + w.longueur > v.x - mg:
			return true
	return false


func _cote_de(e: Veh) -> int:
	if not _cote.has(e.uid):
		_cote[e.uid] = -1 if rng.randf() < 0.5 else 1
	return int(_cote[e.uid])


func _voie_ennemi(e: Veh, t) -> int:
	if e.allie:
		return -1   # le convoi allié tient sa droite : pour nous, la voie du fond
	match String(e.mode):
		"face":
			return (t.voie if t != null else 0) if eperonne(e) else -1
		"contourne":
			return _cote_de(e)
		"poursuite":   # il se cale sur un côté de sa cible ; si nos véhicules bouchent ce côté, il essaie l'autre
			if float(_cd_choc.get(e.uid, 0.0)) > 0.0:
				_percute[e.uid] = true
			var q = _queue()
			if eperonne(e) and not _percute.has(e.uid) and q != null and e.x < q.x:
				return 0   # celui qui veut éperonner nous emboutit d'abord par l'arrière, puis remonte sur le flanc
			var c = _cible_poursuite(e)
			var cote := _cote_de(e)
			if c != null and _cote_bouche(c, cote, e) and not _cote_bouche(c, -cote, e):
				_cote[e.uid] = -cote
				cote = -cote
			return cote
	return 0   # approche, barrage, convoi, harcele : au milieu


# Un de nos véhicules roule sur ce côté, à hauteur de la cible
func _cote_bouche(c: Veh, cote: int, sauf: Veh) -> bool:
	for v in convoi:
		if v != c and v != sauf and v.actif() and absf(v.voie_f - cote) < 0.5 and v.x < c.x + c.longueur and v.x + v.longueur > c.x:
			return true
	return false


func _voie_joueur(v: Veh, t) -> int:
	var V := VO()
	if v.remorque():
		var tr = tracteur_de(v)
		if tr != null:
			return tr.voie   # la remorque suit son tracteur
	for e in ennemis:
		if not e.actif():
			continue
		if e.allie and e.mode == "face" and e.x > v.x - 5.0 and e.x < v.x + v.longueur + float(V.croisement_avant):
			return 1   # on serre à droite pour croiser un allié
	if conduite() == "eviter":
		for e in ennemis:
			if e.actif() and not e.allie and e.mode == "convoi" and e.x + e.longueur > v.x - 2.0 and e.x - (v.x + v.longueur) < float(V.depassement_avant):
				return -1   # on double par la gauche
	elif v == t and ordres.marche == "avancer":
		for e in ennemis:
			if e.actif() and not e.allie and e.mode == "face" and e.x > v.x and e.x - (v.x + v.longueur) < float(V.croisement_avant):
				return roundi(e.voie_f)   # la tête va le chercher sur sa voie
	return 0


# --- Coups de flanc entre voies voisines -------------------------------------------------------------------
func _coups_lateraux(dt: float) -> void:
	var V := VO()
	for a in convoi:
		if not a.actif() or not a.mobile() or a.garage != 0:
			continue
		for e in ennemis:
			if not e.actif() or e.allie or not e.mobile():
				continue
			if absf(absf(a.voie_f - e.voie_f) - 1.0) > 0.15:
				continue   # pas sur des voies voisines
			var rec: float = minf(a.x + a.longueur, e.x + e.longueur) - maxf(a.x, e.x)
			if rec < float(V.coup_recouvrement) * minf(a.longueur, e.longueur):
				continue   # pas à hauteur
			if float(_cd_choc.get(a.uid, 0.0)) > 0.0 or float(_cd_choc.get(e.uid, 0.0)) > 0.0:
				continue
			var proba := float(V.coup_proba_s) * dt
			if conduite() == "eperonner" and rng.randf() < proba:
				_coup_lateral(a, e, true)
			elif eperonne(e) and rng.randf() < proba:
				_coup_lateral(e, a, false)


# a donne un coup de volant dans b, sur la voie d'à côté
func _coup_lateral(a: Veh, b: Veh, par_joueur: bool) -> void:
	var C := CH()
	var V := VO()
	_cd_choc[a.uid] = float(C.delai)
	_cd_choc[b.uid] = float(C.delai)
	var ma := float(a.profil.get("poids_kg", 1500.0)) / 1000.0
	var mb := float(b.profil.get("poids_kg", 1500.0)) / 1000.0
	var xc: float = (maxf(a.x, b.x) + minf(a.x + a.longueur, b.x + b.longueur)) * 0.5
	var sens: float = signf(b.voie_f - a.voie_f)
	b.voie_f = clampf(b.voie_f + sens * float(V.coup_ecart_voie), -1.4, 1.4)   # il est déporté, puis revient sur sa voie
	if b.camp == "ennemi" and est_moto(b) and ma >= mb * float(V.chute_rapport_masse) and rng.randf() < float(V.chute_moto):
		log_(Textes.t("voie.003", [a.nom, b.nom]), "info")
		_detruire(b)   # la moto part dans le fossé
		evt({"t": "choc", "x": xc, "fort": true})
		return
	var k := float(C.k) * float(V.coup_facteur) * float(V.coup_elan)
	var vers_b := k * ma
	var vers_a := k * mb * float(C.part_frappeur)
	_degats_choc(b, vers_b, "arriere")   # le flanc : roues et train roulant
	_degats_choc(a, vers_a, "arriere")
	if par_joueur:
		log_(Textes.t("voie.001", [a.nom, b.nom, int(vers_b)]), "info")
	else:
		log_(Textes.t("voie.002", [a.nom, b.nom]), "alerte")
	evt({"t": "choc", "x": xc, "fort": vers_a + vers_b > float(C.fort)})


# --- Couvert ---------------------------------------------------------------------------------------------
# Le tireur et sa cible sont sur les deux voies extrêmes, et un véhicule assez haut de la voie du milieu cache la cible.
func _facteur_couvert(att, cible) -> float:
	if not (cible is Veh):
		return 1.0
	var la: float = att.voie_f if att is Veh else 0.0
	if absf(la - cible.voie_f) < 1.5:
		return 1.0
	var V := VO()
	var hc := float(VehiculeDessin.donnees().vehicules[cible.type].hauteur)
	for w in convoi + ennemis + epaves:
		if w == att or w == cible or absf(w.voie_f) > 0.5 or w.garage != 0:
			continue
		var rec: float = minf(w.x + w.longueur, cible.x + cible.longueur) - maxf(w.x, cible.x)
		if rec >= float(V.couvert_recouvrement) * cible.longueur and float(VehiculeDessin.donnees().vehicules[w.type].hauteur) >= float(V.couvert_hauteur) * hc:
			return float(V.couvert_facteur)
	return 1.0
