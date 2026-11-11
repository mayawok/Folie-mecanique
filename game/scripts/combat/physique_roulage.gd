# Physique des pneus et des suspensions (DEC-230, docs/design/PHYSIQUE.md). Module pur, sans écran, déterministe.
# Croise ce que porte le véhicule (profil["physique"] : pneu, débattement, charge par essieu) avec la surface du sol
# (data/surfaces.json) et rend des facteurs que le modèle de combat applique : vitesse, précision, consommation, crevaison.
class_name PhysiqueRoulage
extends RefCounted

static var _data := {}
static var surface_forcee := ""   # Kit et tests : impose la surface (vide = celle de la zone de décor)

const NEUTRE := {"surface": "terre", "pression": 0.0, "adherence": 1.0, "roulement": 1.0, "chocs": 0.0, "enlise": false,
	"vitesse": 1.0, "precision": 1.0, "conso": 1.0, "crevaison_m": 0.0}


static func donnees() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open("res://data/surfaces.json", FileAccess.READ)
		_data = JSON.parse_string(f.get_as_text())
	return _data


static func surfaces() -> Array:
	return donnees().surfaces.keys()


# Surface sous les roues : forcée, sinon celle de la zone de décor (sable, terre, cailloux, eau, neige, boue)
static func surface_courante() -> String:
	if surface_forcee != "" and donnees().surfaces.has(surface_forcee):
		return surface_forcee
	var z := String(Terrain.zone)
	return z if donnees().surfaces.has(z) else "terre"


static func pneu(id: String) -> Dictionary:
	var P: Dictionary = donnees().pneus
	return P[id] if P.has(id) else P[String(donnees().pneu_defaut)]


# Identifiant de pneu d'une pièce de train de la grille (roue_moyenne, chenille…) ; les roues de moto sont regroupées
static func pneu_de_piece(id: String) -> String:
	if donnees().pneus.has(id):
		return id
	if id.ends_with("_r75"):
		return "roue_moto"
	return String(donnees().pneu_defaut)


# Ce que fait ce profil de véhicule sur cette surface. Un profil sans bloc « physique » reste neutre.
static func evaluer(profil: Dictionary, surface := "") -> Dictionary:
	var ph: Dictionary = profil.get("physique", {})
	if ph.is_empty():
		return NEUTRE
	var D := donnees()
	var s := surface if surface != "" else surface_courante()
	if not D.surfaces.has(s):
		s = "terre"
	var sf: Dictionary = D.surfaces[s]
	var p := pneu(String(ph.get("pneu", "")))
	var charge_roue := float(ph.get("charge_essieu", 0.0)) * 0.5
	var pression := charge_roue / maxf(1.0, float(p.charge_ref))
	var exces := maxf(0.0, pression / float(sf.portance) - 1.0)
	var adh := float(p.adh.get(s, 1.0)) * (1.0 - minf(0.8, exces * 0.8))
	var roul := float(p.roulement) * float(sf.roulement)
	var vit := float(profil.get("vitesse", 0.0))
	var deb := maxf(0.05, float(ph.get("debattement", 0.2)))
	var chocs := float(sf.rugosite) * (vit / 10.0) / (deb / 0.2)
	var f_adh := clampf(adh, 0.2, 1.0)
	var f_roul := clampf(1.15 - 0.15 * roul, 0.6, 1.0)
	var f_chocs := 1.0 if chocs <= 0.7 else clampf(pow(0.7 / chocs, 0.6), 0.55, 1.0)   # le conducteur lève le pied sur sol cassé
	return {
		"surface": s,
		"pression": pression,
		"adherence": adh,
		"roulement": roul,
		"chocs": chocs,
		"enlise": adh < float(D.seuil_enlisement),
		"vitesse": f_adh * f_roul * f_chocs,
		"precision": clampf(1.0 / (1.0 + 0.35 * maxf(0.0, chocs - 0.6)), 0.5, 1.0),
		"conso": pow(clampf(roul, 1.0, 2.5), 0.7),
		"crevaison_m": 0.00005 * float(p.crevaison) * float(sf.crevaison) * (1.0 + 3.0 * exces),
	}


static func facteur_vitesse(profil: Dictionary) -> float:
	return float(evaluer(profil).vitesse)


static func facteur_precision(profil: Dictionary) -> float:
	return float(evaluer(profil).precision)


static func facteur_conso(profil: Dictionary) -> float:
	return float(evaluer(profil).conso)


# Lignes lisibles pour le panneau Physique du Kit
static func resume(profil: Dictionary, surface := "") -> String:
	var e := evaluer(profil, surface)
	var ph: Dictionary = profil.get("physique", {})
	if ph.is_empty():
		return "pas de données de roulage"
	return "%s | pneu %s | pression %.2f | adhérence %.2f | chocs %.2f | vitesse ×%.2f | précision ×%.2f | conso ×%.2f%s" % [
		D_nom(String(e.surface)), String(pneu(String(ph.get("pneu", ""))).nom), float(e.pression), float(e.adherence), float(e.chocs),
		float(e.vitesse), float(e.precision), float(e.conso), " | ENLISÉ" if bool(e.enlise) else ""]


static func D_nom(s: String) -> String:
	return String(donnees().surfaces[s].nom)
