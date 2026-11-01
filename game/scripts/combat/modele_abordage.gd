# Poursuites et abordages (DEC-077) : des véhicules ennemis arrivent par l'arrière, dans le même sens que le convoi,
# se calent à côté d'un de nos véhicules et lancent des pillards qui sautent à bord :
#  - « lame » : il se bat au corps à corps avec l'équipage jusqu'à ce que l'un des deux tombe ;
#  - « bombe » : il explose au contact (lance explosive), contre la cabine ou le moteur.
# Valeurs : bloc « abordage » de combat_proto.json ; rencontres de mode « poursuite ».
extends "res://scripts/combat/modele_meteo.gd"

var abordeurs: Array = []   # {uid, type, de, vers, etat: "saut"|"bord", t, x0, pv, cd}
var _pours := {}            # uid du poursuivant -> {restants, types, cd}
var _uid_ab := 0


func AB() -> Dictionary:
	return donnees().abordage


func preparer_poursuivant(e: Veh, choix: Dictionary) -> void:
	e.mode = "poursuite"
	_pours[e.uid] = {"restants": int(choix.get("abordeurs", AB().abordeurs_defaut)), "types": choix.get("types", ["lame"]), "cd": float(AB().premier_saut)}


# Le poursuivant se cale à hauteur du dernier véhicule visible du convoi (le plus exposé)
func _cible_poursuite(e: Veh):
	var meilleur = null
	for v in convoi:
		if v.actif() and not v.camoufle and v.garage == 0:
			if meilleur == null or absf(v.x - e.x) < absf(meilleur.x - e.x):
				meilleur = v
	return meilleur


func _ia_poursuite(dt: float) -> void:
	for e in ennemis:
		if not e.actif() or e.mode != "poursuite" or not e.mobile():
			continue
		var c = _cible_poursuite(e)
		if c == null:
			continue
		var voulu: float = c.x + (c.longueur - e.longueur) * 0.5
		var d: float = voulu - e.x
		var vmax: float = maxf(e.vitesse() * float(AB().vitesse_poursuite), absf(vitesse_convoi) + float(AB().avance_poursuite))   # pied au plancher : ils gagnent toujours du terrain
		var v := clampf(vitesse_convoi + d * 0.8, -vmax * 0.5, vmax)
		e.x += v * dt
		e.vitesse_act = v
		var P: Dictionary = _pours.get(e.uid, {"restants": int(AB().abordeurs_defaut), "types": ["lame"], "cd": 0.0})
		_pours[e.uid] = P
		P.cd = maxf(0.0, float(P.cd) - dt)
		if absf(d) < float(AB().ecart_saut) and int(P.restants) > 0 and P.cd <= 0.0 and e.equipage_vivant() > 1:
			var types: Array = P.types
			var type: String = types[rng.randi() % types.size()]
			_uid_ab += 1
			abordeurs.append({"uid": _uid_ab, "type": type, "de": e.uid, "vers": c.uid, "etat": "saut", "t": 0.0,
				"x0": e.x + e.longueur * 0.5, "x": e.x + e.longueur * 0.5, "pv": float(AB().pv_abordeur), "cd": 0.0})
			P.restants = int(P.restants) - 1
			P.cd = float(AB().delai_saut)
			log_("Abordage ! Un pillard saute sur %s%s." % [c.nom, " avec une lance explosive" if type == "bombe" else ""], "alerte")


func _veh_uid(uid: int):
	for v in convoi + ennemis:
		if v.uid == uid:
			return v
	return null


func _abordages(dt: float) -> void:
	var A := AB()
	for ab in abordeurs.duplicate():
		var v = _veh_uid(int(ab.vers))
		if v == null or not v.actif():
			abordeurs.erase(ab)   # le véhicule visé n'est plus là : le pillard tombe sur la route
			continue
		var xc: float = v.x + v.longueur * 0.5
		if ab.etat == "saut":
			ab.t = minf(1.0, float(ab.t) + dt / float(A.duree_saut))
			ab.x = lerpf(float(ab.x0), xc, float(ab.t))
			if ab.t >= 1.0:
				if ab.type == "bombe":
					_exploser(ab, v)
					abordeurs.erase(ab)
				else:
					ab.etat = "bord"
			continue
		ab.x = xc - v.longueur * 0.25   # sur le toit, à l'arrière
		var defenseurs: int = v.equipage_vivant()
		ab.pv = float(ab.pv) - float(A.defense_par_membre) * defenseurs * dt
		ab.cd = float(ab.cd) - dt
		if ab.cd <= 0.0:
			ab.cd = float(A.cadence_lame)
			_blesser_equipage(v, float(A.degats_lame))
			if v.equipage_vivant() == 0 and v.actif():
				_neutraliser(v)
		if float(ab.pv) <= 0.0:
			abordeurs.erase(ab)
			log_("%s : le pillard est repoussé." % v.nom, "ok")


func _exploser(ab: Dictionary, v: Veh) -> void:
	var A := AB()
	var w := {"degats": float(A.bombe_degats), "penetration": float(A.bombe_penetration), "classe": "bombe"}
	var zone := "cabine" if v.pieces.has("cabine") and rng.randf() < 0.5 else "moteur"
	_toucher_vehicule(null, w, v, "", zone if v.pieces.has(zone) else "")
	_blesser_equipage(v, float(A.bombe_equipage))
	evt({"t": "impact", "x": float(ab.x), "y": 1.4, "touche": true, "reel": true, "classe": "canon", "ricoche": false, "uid": v.uid, "sur_joueur": v.camp == "joueur"})
	log_("%s : la lance explosive a sauté contre le véhicule." % v.nom, "alerte")
