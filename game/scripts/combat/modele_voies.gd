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
#  - Formation de combat (DEC-251) : dès qu'un ennemi est à portée, les véhicules légers armés quittent la ligne et se
#    postent sur les flancs du camion principal (Berliet) ; à la fin du combat ils reprennent leur place dans la ligne.
#    Pas d'ordre manuel de changement de voie pour le moment.
#  - Contournement (DEC-252) : un barrage ennemi ou une épave ennemie sur la route arrête le convoi ; après quelques
#    secondes il recule, puis repart par la voie libre la plus proche (droite d'abord) et reprend la voie du milieu
#    une fois l'obstacle dépassé. Pendant la manœuvre, les gardes de flanc rejoignent la ligne.
#  - Camion principal hors service : il reste en tête, le convoi ne repart pas ; réparé (et équipé), il se remet en service.
#  - Bâtiments : jamais sur la route, toujours derrière (fond) ou devant.
# Valeurs : bloc « voies » de combat_proto.json.
extends "res://scripts/combat/modele_choc.gd"

var _cote := {}     # uid -> côté choisi (-1 ou 1) pour contourner ou aborder
var en_combat := false   # un ennemi est à portée : formation de combat (DEC-251)
var _combat_calme := 0.0 # secondes écoulées depuis que plus rien n'est à portée
var _protege_uid := 0    # camion protégé par les gardes de flanc
var _contour := ""        # contournement d'un obstacle : "" | "recul" | "passage" (DEC-252)
var _contour_voie := 0    # voie choisie pour passer
var _contour_obs = null   # obstacle contourné
var _contour_x0 := 0.0    # position de la tête au début du recul
var _contour_t := 0.0     # durée de la manœuvre
var _arret_t := 0.0       # temps passé à l'arrêt devant l'obstacle
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
			if c == null:
				return _cote_de(e)
			var cl := roundi(c.voie_f)
			var libres: Array = []
			for l in [cl - 1, cl + 1]:
				if l >= -1 and l <= 1:
					libres.append(l)
			var pref := _cote_de(e)
			if not libres.has(pref):
				pref = libres[0]
			if _cote_bouche(c, pref, e) and libres.size() > 1 and not _cote_bouche(c, libres[1] if libres[0] == pref else libres[0], e):
				pref = libres[1] if libres[0] == pref else libres[0]
			_cote[e.uid] = pref
			return pref
	return 0   # approche, barrage, convoi, harcele : au milieu


# Un de nos véhicules roule sur cette voie, à hauteur de la cible
func _cote_bouche(c: Veh, voie: int, sauf: Veh) -> bool:
	for v in convoi:
		if v != c and v != sauf and v.actif() and absf(v.voie_f - voie) < 0.5 and v.x < c.x + c.longueur and v.x + v.longueur > c.x:
			return true
	return false


# Le poursuivant dont le côté est bouché reste derrière la ligne, sans se superposer à sa cible
func _x_poursuite(e: Veh, c: Veh) -> float:
	var voie := roundi(e.voie)
	if voie != 0 and _cote_bouche(c, voie, e):
		return c.x - e.longueur - float(VO().garde_attente)
	return c.x + (c.longueur - e.longueur) * 0.5


# On ne vise que les véhicules de la ligne : ceux postés sur un flanc ne sont pas des cibles d'approche
func _cible_poursuite(e: Veh):
	var meilleur = null
	for v in convoi:
		if v.actif() and not v.camoufle and v.garage == 0 and v.en_ligne():
			if meilleur == null or absf(v.x - e.x) < absf(meilleur.x - e.x):
				meilleur = v
	return meilleur if meilleur != null else super._cible_poursuite(e)


func _voie_joueur(v: Veh, t) -> int:
	var V := VO()
	if v.garde != 0:
		if not v.retour:
			return v.garde   # posté sur son flanc
		return v.garde if absf(v.x - v.x_cible) > 1.5 else (_contour_voie if _contour == "passage" else 0)   # il revient : il change de voie une fois à sa place
	if v.remorque():
		var tr = tracteur_de(v)
		if tr != null:
			return tr.voie   # la remorque suit son tracteur
	if _contour == "passage":
		return _contour_voie   # tout le convoi passe par la voie d'à côté
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
	_percutes_gardes()
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


func _garde_devant(e: Veh):
	for g in convoi:
		if g.garde != 0 and g.actif() and g.garage == 0 and meme_voie(e, g):
			var ecart: float = g.x - (e.x + e.longueur)
			if ecart > -0.5 and ecart < float(AB().ecart_saut):
				return g
	return null


# Un poursuivant bloqué derrière un garde de flanc lui rentre dans l'arrière (corps à corps, DEC-255)
func _percutes_gardes() -> void:
	var ct := float(CH().contact)
	for g in convoi:
		if g.garde == 0 or not g.actif() or g.garage != 0:
			continue
		for e in ennemis:
			if not e.actif() or e.allie or e.mode != "poursuite" or not meme_voie(e, g):
				continue
			var ecart: float = g.x - (e.x + e.longueur)
			if ecart > ct or ecart < -g.longueur * 0.5 or float(_cd_choc.get(e.uid, 0.0)) > 0.0 or not eperonne(e):
				continue
			_choc(e, g, absf(e.vitesse_act - vitesse_convoi) + float(CH().elan), "avant", "arriere", false)


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
	evt({"t": "choc", "x": xc, "fort": vers_a + vers_b > float(C.fort), "voie": (a.voie_f + b.voie_f) * 0.5, "lat": true})


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


# --- Formation de combat (DEC-251) -----------------------------------------------------------------------
# Distance entre un ennemi et la colonne du convoi (0 s'il est à hauteur)
func _distance_colonne(x: float, longueur: float) -> float:
	var q = _queue()
	var t = _tete()
	if q == null or t == null:
		return INF
	return maxf(0.0, maxf(x - (t.x + t.longueur), q.x - (x + longueur)))


func _menace_proche(limite: float) -> bool:
	for e in ennemis:
		if e.actif() and not e.allie and _distance_colonne(e.x, e.longueur) < limite:
			return true
	for b in batiments:
		if b.actif() and (b.tireurs_vivants() + b.garnison_vivants() > 0 or b.arme_fixe != "") and _distance_colonne(b.x, b.longueur) < limite * 0.8:
			return true
	for p in monde.pietons:
		if p.actif() and p.camp == "ennemi" and not p.animal and _distance_colonne(p.x, 1.0) < limite * 0.7:
			return true
	return false


func _formation(dt: float) -> void:
	var V := VO()
	var avant := en_combat
	var calme: bool = ville_protegee() or ville_calme() or mission_active()
	if calme:
		en_combat = false
	elif not en_combat:
		if _menace_proche(float(V.combat_entree)):
			en_combat = true
			_combat_calme = 0.0
	else:
		if _menace_proche(float(V.combat_sortie)):
			_combat_calme = 0.0
		else:
			_combat_calme += dt
			if _combat_calme >= float(V.combat_delai_sortie):
				en_combat = false
	if en_combat != avant:
		evt({"t": "combat", "etat": "debut" if en_combat else "fin"})
		log_(Textes.t("formation.001" if en_combat else "formation.002"), "alerte" if en_combat else "ok")
	if en_combat and _contour == "":
		_assigner_gardes()
	else:
		for v in convoi:   # fin du combat : retour dans la ligne, en restant sur le flanc jusqu'à sa place
			if v.garde != 0 and not v.retour:
				v.retour = true
	for v in convoi:
		if v.garde != 0:
			if not v.actif() or v.garage != 0:
				v.garde = 0
				v.retour = false
			elif v.retour and absf(v.x - v.x_cible) < 1.5 and absf(v.voie_f) < 0.5:
				v.garde = 0
				v.retour = false


# Le camion principal est le protégé ; à défaut, le plus lourd de la ligne
func _protege():
	var meilleur = null
	for v in convoi:
		if not v.actif() or v.garage != 0 or v.camoufle or v.remorque() or not v.en_ligne():
			continue
		if v.principal:
			return v
		if meilleur == null or float(v.profil.get("poids_kg", 0.0)) > float(meilleur.profil.get("poids_kg", 0.0)):
			meilleur = v
	return meilleur


func _places_flanc(p: Veh) -> int:
	return maxi(1, int(floorf(p.longueur / 3.5)))


func _assigner_gardes() -> void:
	var p = _protege()
	if p == null:
		return
	_protege_uid = p.uid
	var V := VO()
	var cap := _places_flanc(p)
	var occupees := {-1: [], 1: []}
	for v in convoi:
		if v.garde != 0 and v.retour:
			v.retour = false   # le combat reprend
		if v.garde != 0 and v.actif():
			occupees[v.garde].append(v.garde_slot)
	var poids_max: float = float(p.profil.get("poids_kg", 1500.0)) * float(V.garde_poids_max)
	var candidats: Array = []
	for v in convoi:
		if v == p or v.garde != 0 or not v.actif() or not v.mobile() or v.garage != 0 or v.camoufle or v.remorque():
			continue
		if v.armes.is_empty() or float(v.profil.get("poids_kg", 1500.0)) > poids_max:
			continue
		candidats.append(v)
	candidats.sort_custom(func(a, b): return absf(a.x - p.x) < absf(b.x - p.x))
	# côté le plus menacé en premier
	var menace := {-1: 0, 1: 0}
	for e in ennemis:
		if e.actif() and not e.allie and e.mode in ["poursuite", "harcele", "contourne"]:
			var cd := _cote_de(e)
			if cd != 0:
				menace[cd] += 1
	for v in candidats:
		var cote := -1 if (occupees[-1].size() < occupees[1].size() or (occupees[-1].size() == occupees[1].size() and menace[-1] >= menace[1])) else 1
		if occupees[cote].size() >= cap:
			cote = -cote
		if occupees[cote].size() >= cap:
			break   # tous les flancs sont gardés
		var slot := 0
		while occupees[cote].has(slot):
			slot += 1
		occupees[cote].append(slot)
		v.garde = cote
		v.garde_slot = slot
		v.retour = false


func _placer_gardes() -> void:
	if _protege_uid == 0:
		return   # aucune formation en cours (et le modèle n'est pas encore complètement construit)
	var p = trouver(_protege_uid)
	for v in convoi:
		if v.en_ligne():
			continue
		if p == null or not p.actif():
			v.garde = 0
			continue
		var cap := _places_flanc(p)
		v.x_cible = p.x_cible + p.longueur * (float(v.garde_slot) + 0.5) / float(cap) - v.longueur * 0.5


# --- Contournement d'un obstacle (DEC-252) ----------------------------------------------------------------
func _contourne(e: Veh) -> bool:
	return _contour == "passage" and e.mode == "barrage"


# Barrage ennemi ou épave ennemie sur la voie du milieu, devant la tête du convoi
func _obstacle_devant():
	var meilleur = null
	var cands: Array = []
	for e in ennemis:
		if e.actif() and not e.allie and e.mode == "barrage" and roundi(e.voie_f) == 0:
			cands.append(e)
	for w in epaves:
		if w.camp == "ennemi" and roundi(w.voie_f) == 0:
			cands.append(w)
	for o in cands:
		if o.x + o.longueur < x_tete - 0.5:
			continue   # déjà dépassé
		if meilleur == null or o.x < meilleur.x:
			meilleur = o
	return meilleur


# La voie est libre autour de l'obstacle (aucun ennemi ni épave à hauteur, marge de chaque côté)
func _voie_degagee(l: int, o: Veh) -> bool:
	var lib := float(VO().contour_libre)
	for w in ennemis + epaves:
		if w == o or w.camp == "joueur":
			continue
		if absf(w.voie_f - l) < 0.6 and w.x < o.x + o.longueur + lib and w.x + w.longueur > o.x - lib:
			return false
	return true


func _contour_fin() -> void:
	_contour = ""
	_contour_obs = null
	_contour_t = 0.0
	_arret_t = 0.0


func _contour_vitesse(vit: float, P: Dictionary, dt: float) -> float:
	var V := VO()
	if ordres.marche != "avancer" or _tete() == null:
		return vit
	match _contour:
		"":
			var o = _obstacle_devant()
			if o == null:
				_arret_t = 0.0
				return vit
			var d: float = o.x - x_tete
			if o.statut != "actif" and vit > 0.0 and d < float(V.contour_anticipation):
				var frein := Transmission.frein_dispo(float(P.adh), float(P.masse_f))
				vit = minf(vit, Transmission.vitesse_sure(maxf(d - 1.6, 0.0), frein))   # une épave arrête aussi le convoi
			if d < 4.0 and absf(vitesse_convoi) < 0.3:
				_arret_t += dt
			else:
				_arret_t = 0.0
			if _arret_t >= float(V.contour_delai):
				for l in [1, -1]:
					if _voie_degagee(l, o):
						_contour = "recul"
						_contour_voie = l
						_contour_obs = o
						_contour_x0 = x_tete
						_contour_t = 0.0
						log_(Textes.t("voie.004"), "info")
						break
				_arret_t = 0.0
				if _contour == "":
					blocage = Textes.t("voie.005")
		"recul":
			_contour_t += dt
			var o2 = _contour_obs
			if o2 == null or not (ennemis.has(o2) or epaves.has(o2)) or _contour_t > float(V.contour_max_s):
				_contour_fin()
				return vit
			if _contour_x0 - x_tete >= float(V.contour_recul):
				_contour = "passage"
				_contour_t = 0.0
			else:
				blocage = ""
				return -float(V.contour_recul_vitesse)
			return vit
		"passage":
			_contour_t += dt
			var q = _queue()
			var o3 = _contour_obs
			if o3 == null or q == null or _contour_t > float(V.contour_max_s) or q.x > o3.x + o3.longueur + float(V.contour_marge):
				_contour_fin()
				return vit
			if _contour_t < float(V.duree_changement) + 0.3:
				return minf(vit, 1.5)   # on s'engage doucement le temps de changer de voie
	return vit


# Camion principal réparé : il se remet en service (équipage pris dans la réserve si besoin) (DEC-252)
func _principal_remis() -> void:
	for v in convoi:
		if not v.principal or v.camp != "joueur" or v.actif() or v.garage != 0:
			continue
		if not (v.piece_ok("chassis") and v.piece_ok("roulement") and v.piece_ok("moteur")):
			continue
		if v.equipage_vivant() == 0:
			if reserve_survivants <= 0:
				continue
			reserve_survivants -= 1
			v.equipage = [float(donnees().equipage_pv)]
		v.statut = "actif"
		v.reparation = false
		log_(Textes.t("voie.007", [v.nom]), "ok")
