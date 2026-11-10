# Réputation par faction (DEC-184, DEC-187, DEC-217) : une valeur de -100 à 100 par faction de la carte, des paliers
# (hostile, méfiant, neutre, amical, allié), des rivalités entre factions, et les effets sur les prix, les missions,
# l'accueil en ville et les camps rencontrés sur la route. Valeurs : data/reputation.json.
# Couche basse de la chaîne du modèle : tout ce qui est au-dessus peut l'utiliser.
extends "res://scripts/combat/modele_base.gd"

static var _rep_data := {}
var reputation := {}   # id de faction -> valeur (les factions jamais touchées gardent leur valeur de départ)


static func REPU() -> Dictionary:
	if _rep_data.is_empty():
		var f := FileAccess.open("res://data/reputation.json", FileAccess.READ)
		_rep_data = JSON.parse_string(f.get_as_text())
	return _rep_data


func rep_valeur(fac: String) -> float:
	return float(reputation.get(fac, float(REPU().depart.get(fac, 0.0))))


# Palier d'une valeur : le premier dont le plafond n'est pas dépassé
static func rep_palier_de(v: float) -> Dictionary:
	for p in REPU().paliers:
		if v <= float(p.max):
			return p
	return REPU().paliers.back()


func rep_palier(fac: String) -> Dictionary:
	return rep_palier_de(rep_valeur(fac))


# Attitude pour le monde : 1 ami, 2 neutre, 3 hostile (MondeJeu.ATTITUDE)
func rep_attitude(fac: String) -> int:
	return int(rep_palier(fac).attitude)


func rep_factions() -> Array:
	return CarteMonde.donnees().factions.keys()


func rep_nom(fac: String) -> String:
	return String(CarteMonde.donnees().factions.get(fac, {}).get("nom", Textes.t("rep.001")))


# Change la réputation d'une faction ; les rivales réagissent (moitié, en sens inverse). Renvoie le changement réel.
func rep_changer(fac: String, delta: float, raison := "", contrecoup := true) -> float:
	if fac == "" or not CarteMonde.donnees().factions.has(fac) or delta == 0.0:
		return 0.0
	var avant := rep_valeur(fac)
	var p0: String = String(rep_palier(fac).id)
	var apres := clampf(avant + delta, -100.0, 100.0)
	reputation[fac] = apres
	if raison != "":
		log_(Textes.t("rep.002", [rep_nom(fac), "%+d" % int(round(apres - avant)), raison]), "ok" if delta > 0.0 else "alerte")
	var p1: Dictionary = rep_palier(fac)
	if String(p1.id) != p0:
		log_(Textes.t("rep.003", [rep_nom(fac), String(p1.nom)]), "ok" if float(delta) > 0.0 else "alerte")
		evt({"t": "reputation", "fac": fac, "palier": String(p1.id)})
	if contrecoup:
		for paire in REPU().rivales:
			var autre := ""
			if String(paire[0]) == fac:
				autre = String(paire[1])
			elif String(paire[1]) == fac:
				autre = String(paire[0])
			if autre != "":
				rep_changer(autre, -delta * float(REPU().contrecoup), "", false)
	monde.maj_attitudes()
	return apres - avant


func rep_acte(acte: String, cle: String, fac: String, raison := "") -> void:
	var A: Dictionary = REPU().actes.get(acte, {})
	if A.has(cle):
		rep_changer(fac, float(A[cle]), raison)


# Faction du secteur où se trouve le convoi
func rep_faction_ici() -> String:
	return String(monde.secteurs[monde.secteur].get("fac", ""))


# Faction qui attaque dans ce secteur : la faction locale si elle ne nous aime pas, sinon des pillards sans bannière (DEC-221)
func rep_faction_ennemie() -> String:
	var fac := rep_faction_ici()
	if fac == "":
		return "bandits"
	return fac if String(rep_palier(fac).id) in ["hostile", "mefiant", "neutre"] else "bandits"


func rep_prix_mult(fac: String) -> float:
	return float(rep_palier(fac).prix)


func rep_accueil(fac: String) -> String:
	return String(rep_palier(fac).accueil)


func rep_missions_ok(fac: String) -> bool:
	return bool(rep_palier(fac).missions)


func rep_recompense_mult(fac: String) -> float:
	return float(rep_palier(fac).recompense)


func rep_sauver() -> Dictionary:
	return reputation.duplicate()


func rep_charger(d: Dictionary) -> void:
	reputation = {}
	for k in d:
		reputation[String(k)] = float(d[k])
	monde.maj_attitudes()
