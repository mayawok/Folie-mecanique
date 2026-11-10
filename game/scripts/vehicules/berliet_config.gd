# Berliet GDR dessiné à partir de l'art (planches ChatGPT découpées, données game/data/berliet.json).
# Module pur, sans écran : configuration du camion (châssis, pneus avant et arrière, échappement, réservoir, module arrière),
# calques à dessiner, ancrages de l'équipage et valeurs de jeu provisoires. Le dessin est dans BerlietDessin.
# Repère « u » : 1 pixel du châssis long de la planche ; ppm_art u par mètre ; y vers le bas, sol à y = sol.
class_name BerlietConfig
extends RefCounted

const CHEMIN := "res://data/berliet.json"
const CLES := ["chassis", "pneu_av", "pneu_ar", "echappement", "reservoir", "module", "lame"]

static var _d := {}


static func donnees() -> Dictionary:
	if _d.is_empty():
		var f := FileAccess.open(CHEMIN, FileAccess.READ)
		_d = JSON.parse_string(f.get_as_text())
	return _d


static func defaut() -> Dictionary:
	var c: Dictionary = donnees().defaut.duplicate()
	c.echappement = int(c.echappement)
	c.reservoir = int(c.reservoir)
	c.lame = int(c.get("lame", 0))
	return c


# Choix possibles pour une clé de configuration : identifiants (chaînes) ou numéros de niveau (entiers)
static func options(cle: String) -> Array:
	var D := donnees()
	match cle:
		"chassis":
			return D.chassis.keys()
		"pneu_av", "pneu_ar":
			return D.roues.pneus.keys()
		"echappement":
			return range(D.echappement.niveaux.size())
		"reservoir":
			return range(D.reservoir.niveaux.size())
		"module":
			return D.modules.keys()
		"lame":
			return range(D.lame.niveaux.size())
	return []


# Libellé affiché d'un choix
static func libelle(cle: String, v) -> String:
	var D := donnees()
	match cle:
		"chassis":
			return String(D.chassis[v].nom)
		"pneu_av", "pneu_ar":
			return String(D.roues.pneus[v].nom)
		"echappement":
			return "%d. %s" % [int(v) + 1, D.echappement.niveaux[int(v)].nom]
		"reservoir":
			return "%d. %s" % [int(v) + 1, D.reservoir.niveaux[int(v)].nom]
		"module":
			return String(D.modules[v].nom)
		"lame":
			return "%d. %s" % [int(v), D.lame.niveaux[int(v)].nom] if int(v) > 0 else String(D.lame.niveaux[0].nom)
	return str(v)


# Change un réglage ; une valeur inconnue est refusée (la configuration reste inchangée). Renvoie vrai si accepté.
static func regler(c: Dictionary, cle: String, v) -> bool:
	if cle not in CLES:
		return false
	var ok := false
	for o in options(cle):
		if str(o) == str(v):
			ok = true
			v = o
	if not ok:
		return false
	c[cle] = v
	return true


static func valide(c: Dictionary) -> bool:
	for k in CLES:
		if not c.has(k) and k == "lame":
			continue   # anciennes sauvegardes : pas de lame
		if not c.has(k):
			return false
		var trouve := false
		for o in options(k):
			if str(o) == str(c[k]):
				trouve = true
		if not trouve:
			return false
	return true


static func ppm_art() -> float:
	return float(donnees().ppm_art)


static func sol() -> float:
	return float(donnees().sol)


static func reduction() -> float:
	return float(donnees().get("reduction", 1.0))


static func image(nom: String) -> String:
	return "vehicules/berliet/" + nom


static func chassis(c: Dictionary) -> Dictionary:
	return donnees().chassis[String(c.chassis)]


# Calques d'images dans l'ordre de dessin. Chaque calque : {id, image, x, y, e, ancre} ; e = u par pixel de l'IMAGE du jeu,
# ancre : "hg" (x, y = coin haut-gauche), "bd" (x, y = coin bas-droit), "centre" (roues), "trappe" (pivot en pixels d'image).
static func calques(c: Dictionary) -> Array:
	var D := donnees()
	var r := reduction()
	var C := chassis(c)
	var res := []
	res.append({"id": "chassis", "image": image(C.image), "x": float(C.x), "y": float(C.y), "e": float(C.echelle) / r, "ancre": "hg"})
	var R: Dictionary = D.reservoir
	res.append({"id": "reservoir", "image": image(R.niveaux[int(c.reservoir)].image), "x": float(R.x), "y": float(R.haut),
		"e": float(R.echelle) / r, "ancre": "hg"})
	var E: Dictionary = D.echappement
	res.append({"id": "echappement", "image": image(E.niveaux[int(c.echappement)].image), "x": float(E.droite), "y": float(E.bas),
		"e": float(E.echelle) / r, "ancre": "bd"})
	res.append({"id": "module"})   # dessiné par le code (BerlietDessin), entre l'échappement et les roues
	for m in moyeux(c):
		res.append({"id": "roue", "image": m.image, "x": m.x, "y": m.y, "e": m.e, "ancre": "centre"})
	var K: Dictionary = D.cabine
	res.append({"id": "lame"})   # dessinée par le code (BerlietDessin), sous la cabine, devant le pare-chocs
	res.append({"id": "cabine", "image": image(K.image), "x": float(K.x), "y": float(K.y), "e": float(K.echelle) / r, "ancre": "hg"})
	var T: Dictionary = D.trappe
	res.append({"id": "trappe", "image": image(T.image), "x": float(T.x), "y": float(T.y), "e": float(T.echelle) / r, "ancre": "trappe",
		"pivot": Vector2(float(T.pivot[0]), float(T.pivot[1])) * r, "ouverture": deg_to_rad(float(T.ouverture_deg))})
	return res


# Moyeux du châssis choisi, avec l'image de la roue (pneu avant ou arrière) : [{x, y, cote, image, e}]
static func moyeux(c: Dictionary) -> Array:
	var D := donnees()
	var res := []
	for m in chassis(c).moyeux:
		var cote := String(m[2])
		var pneu: Dictionary = D.roues.pneus[String(c.pneu_av if cote == "av" else c.pneu_ar)]
		res.append({"x": float(m[0]), "y": float(m[1]), "cote": cote, "image": image(String(pneu[cote])),
			"e": float(D.roues["echelle_" + cote]) / reduction()})
	return res


# Plateau arrière où se pose le module : [x0, x1] en u, et hauteur du dessus des longerons (rail, y en u)
static func plateau(c: Dictionary) -> Vector2:
	var p: Array = chassis(c).plateau
	return Vector2(float(p[0]), float(p[1]))


static func rail(c: Dictionary) -> float:
	return float(chassis(c).rail)


# Arrière du camion (u) : début du châssis
static func x_arriere(c: Dictionary) -> float:
	return float(chassis(c).x)


static func longueur_m(c: Dictionary) -> float:
	# les deux châssis finissent au même endroit (calés sur l'essieu avant) : pare-chocs avant à 2154 u
	return (2154.0 + lame(c).avancee - x_arriere(c)) / ppm_art()


# Lame avant choisie (DEC-212) : {nom, avancee, haut, poids_kg, pv, choc, vitesse}
static func lame(c: Dictionary) -> Dictionary:
	var n: Array = donnees().lame.niveaux
	return n[clampi(int(c.get("lame", 0)), 0, n.size() - 1)]


# Ancrages de l'équipage en mètres dans le repère du camion (x depuis u = 0, y vers le haut depuis le sol)
static func ancrages_m(c: Dictionary) -> Dictionary:
	var A: Dictionary = donnees().ancrages
	var p := ppm_art()
	var roues := []
	for m in moyeux(c):
		if m.cote == "ar":
			roues.append(float(m.x) / p)
	return {
		"porte_avant": float(A.porte_avant) / p,
		"porte_arriere": float(A.porte_arriere) / p,
		"toit_x": float(A.toit[0]) / p,
		"toit_y": (sol() - float(A.toit[1])) / p,
		"moteur": float(A.moteur) / p,
		"feu": (x_arriere(c) + float(A.feu)) / p,
		"roues_ar": roues,
		"arriere": x_arriere(c) / p,
	}


# Valeurs de jeu provisoires (non branchées sur le combat) : charge, carburant, bonus moteur, adhérence
static func valeurs(c: Dictionary) -> Dictionary:
	var D := donnees()
	var pa: Dictionary = D.roues.pneus[String(c.pneu_av)]
	var pr: Dictionary = D.roues.pneus[String(c.pneu_ar)]
	return {
		"charge_t": float(chassis(c).charge_t),
		"gazole_l": int(D.reservoir.niveaux[int(c.reservoir)].litres),
		"bonus_puissance": float(D.echappement.niveaux[int(c.echappement)].bonus_puissance),
		"vitesse_route": minf(float(pa.vitesse_route), float(pr.vitesse_route)),
		"tout_terrain": (float(pa.tout_terrain) + 2.0 * float(pr.tout_terrain)) / 3.0,
		"pv_roues": (float(pa.pv) + float(pr.pv)) / 2.0,
		"lame_choc": float(lame(c).choc),
		"lame_pv": int(lame(c).pv),
		"lame_poids_kg": int(lame(c).poids_kg),
		"lame_vitesse": float(lame(c).vitesse),
	}
