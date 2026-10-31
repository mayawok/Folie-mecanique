# Véhicules en pièces (DEC-029, étape G1 de docs/design/GRILLE.md).
# Un assemblage = un châssis + des pièces placées sur sa grille (cellules de 25 cm), + des plaques de blindage.
# Les statistiques de combat sont CALCULÉES à partir des pièces, jamais saisies à la main.
# Données : res://data/pieces.json (catalogue) et res://data/assemblages.json (véhicules historiques).
# Aucune logique de dessin ni d'état de partie ici : fonctions pures, testables sans écran.
class_name Assemblage
extends RefCounted

const FAMILLES_PV := ["chassis", "roulement", "suspension", "moteur", "cabine"]
const NOMS_FAMILLES := {"chassis": "un châssis", "roulement": "des roues", "suspension": "une suspension", "moteur": "un moteur",
	"cabine": "un siège", "arme": "une arme", "attelage": "un attelage"}

static var _pieces := {}
static var _assemblages := {}


static func catalogue() -> Dictionary:
	if _pieces.is_empty():
		_pieces = JSON.parse_string(FileAccess.get_file_as_string("res://data/pieces.json"))
	return _pieces


static func historiques() -> Dictionary:
	if _assemblages.is_empty():
		_assemblages = JSON.parse_string(FileAccess.get_file_as_string("res://data/assemblages.json")).assemblages
	return _assemblages


static func piece(id: String) -> Dictionary:
	return catalogue().pieces.get(id, {})


# Assemblage historique (copie modifiable) ; vide si le type n'existe pas.
static func de_type(type: String) -> Dictionary:
	return historiques().get(type, {}).duplicate(true)


# Pièces placées, avec leur fiche : [{id, fiche, pos}]
static func _places(a: Dictionary) -> Array:
	var res := []
	for p in a.get("pieces", []):
		var f := piece(p.piece)
		res.append({"id": p.piece, "fiche": f, "pos": Vector2i(int(p.pos[0]), int(p.pos[1]))})
	return res


static func _famille(a: Dictionary, fam: String) -> Array:
	return _places(a).filter(func(p): return p.fiche.get("famille", "") == fam)


static func poids(a: Dictionary) -> float:
	var R: Dictionary = catalogue().regles
	var t := float(piece(a.get("chassis", "")).get("poids_kg", 0.0))
	for p in _places(a):
		t += float(p.fiche.get("poids_kg", 0.0))
	return t + int(a.get("plaques", 0)) * float(R.plaque.poids_kg)


static func charge_admissible(a: Dictionary) -> float:
	var c := 0.0
	for p in _famille(a, "roulement"):
		c += float(p.fiche.charge_kg)
	return c


static func puissance(a: Dictionary) -> float:
	var c := 0.0
	for p in _famille(a, "moteur"):
		c += float(p.fiche.puissance_ch)
	return c


# Liste des défauts qui empêchent le véhicule de rouler (vide = valide). Chaque défaut : {code, texte}.
static func valider(a: Dictionary) -> Array:
	var R: Dictionary = catalogue().regles
	var err := []
	var ch := piece(a.get("chassis", ""))
	if ch.is_empty() or ch.famille != "chassis":
		return [{"code": "chassis", "texte": "Aucun châssis"}]
	var gw := int(ch.grille[0])
	var gh := int(ch.grille[1])
	var occupe := {}   # couche -> {Vector2i: id}
	for p in _places(a):
		if p.fiche.is_empty():
			err.append({"code": "inconnue", "texte": "Pièce inconnue : %s" % p.id})
			continue
		var fam: String = p.fiche.famille
		var e := Vector2i(int(p.fiche.emprise[0]), int(p.fiche.emprise[1]))
		var pos: Vector2i = p.pos
		if pos.x < 0 or pos.y < 0 or pos.x + e.x > gw or pos.y + e.y > gh:
			err.append({"code": "hors_grille", "texte": "%s dépasse du châssis" % p.fiche.nom})
			continue
		if fam == "roulement" and pos.y != 0:
			err.append({"code": "roulement_haut", "texte": "%s doit toucher le sol" % p.fiche.nom})
		if fam == "arme" and pos.y + e.y < gh / 2:
			err.append({"code": "arme_basse", "texte": "%s doit être en haut" % p.fiche.nom})
		var couche: String = p.fiche.get("couche", R.couches.get(fam, fam))
		for req in p.fiche.get("requiert", []):
			if _famille(a, req).is_empty():
				err.append({"code": "requiert", "texte": "%s demande : %s" % [p.fiche.nom, NOMS_FAMILLES.get(req, req)]})
		if not occupe.has(couche):
			occupe[couche] = {}
		var chevauche := ""
		for x in range(pos.x, pos.x + e.x):
			for y in range(pos.y, pos.y + e.y):
				var c := Vector2i(x, y)
				if occupe[couche].has(c) and chevauche == "":
					chevauche = occupe[couche][c]
				occupe[couche][c] = p.fiche.nom
		if chevauche != "":
			err.append({"code": "chevauchement", "texte": "%s chevauche %s" % [p.fiche.nom, chevauche]})
	if _famille(a, "roulement").is_empty():
		err.append({"code": "roulement", "texte": "Pas de roues ni de chenilles"})
	if _famille(a, "moteur").size() != 1:
		err.append({"code": "moteur", "texte": "Il faut un moteur, et un seul"})
	if _famille(a, "suspension").is_empty():
		err.append({"code": "suspension", "texte": "Pas de suspension"})
	var sieges := 0
	for p in _famille(a, "cabine"):
		sieges += int(p.fiche.sieges)
	if sieges < 1:
		err.append({"code": "cabine", "texte": "Aucun siège"})
	var charge := charge_admissible(a)
	if charge > 0.0 and poids(a) > charge * float(R.surcharge_max):
		err.append({"code": "surcharge", "texte": "Trop lourd pour le train de roulement"})
	return err


# Statistiques au format des profils de combat (vitesse, blindage, conso, reservoir, metal, equipage,
# ouvert, armes, pv, standoff). Appeler seulement sur un assemblage valide.
static func statistiques(a: Dictionary) -> Dictionary:
	var R: Dictionary = catalogue().regles
	var ch := piece(a.chassis)
	var plaques := int(a.get("plaques", 0))
	var p := {"blindage": float(ch.blindage) + plaques * float(R.plaque.blindage), "reservoir": float(ch.reservoir),
		"metal": int(ch.metal) + plaques * int(R.plaque.metal), "equipage": 0, "ouvert": false, "armes": [],
		"conso": 0.0, "pv": {"chassis": float(ch.pv)}, "poids_kg": poids(a)}
	if ch.has("standoff"):
		p.standoff = ch.standoff
	var vmax := INF
	for pl in _places(a):
		var f: Dictionary = pl.fiche
		p.metal += int(f.get("metal", 0))
		match f.famille:
			"roulement":
				vmax = minf(vmax, float(f.vitesse_max))
				p.pv.roulement = p.pv.get("roulement", 0.0) + float(f.pv)
			"moteur":
				p.conso += float(f.conso)
				p.pv.moteur = p.pv.get("moteur", 0.0) + float(f.pv)
			"suspension":
				p.pv.suspension = p.pv.get("suspension", 0.0) + float(f.pv)
			"cabine":
				p.equipage += int(f.sieges)
				p.ouvert = p.ouvert or bool(f.ouvert)
				p.pv.cabine = p.pv.get("cabine", 0.0) + float(f.pv)
			"arme":
				p.armes.append(f.arme)
			_:
				if f.famille in R.get("pv_chassis", []):
					p.pv.chassis += float(f.pv)
	for id in FAMILLES_PV:
		if not p.pv.has(id):
			p.pv[id] = 1.0
	# Vitesse : plafond du train de roulement, réduite si le moteur est trop faible ou le véhicule surchargé
	var tonnes: float = p.poids_kg / 1000.0
	var f_puissance := minf(1.0, (puissance(a) / maxf(tonnes, 0.001)) / float(R.ch_par_tonne_requis))
	var charge := charge_admissible(a)
	var f_charge: float = 1.0 if p.poids_kg <= charge else pow(charge / p.poids_kg, 2.0)
	p.vitesse = (vmax if vmax != INF else 0.0) * f_puissance * f_charge
	return p


# Profil de combat d'un véhicule historique, calculé depuis ses pièces ; vide si le type n'a pas d'assemblage.
static func profil(type: String) -> Dictionary:
	var a := de_type(type)
	return {} if a.is_empty() else statistiques(a)


# Démontage (prépare G2) : pièces récupérées avec leur état, plus le métal du châssis.
static func demonter(a: Dictionary, etats := {}) -> Dictionary:
	var res := {"pieces": [], "metal": int(piece(a.chassis).metal)}
	for p in a.get("pieces", []):
		var fam: String = piece(p.piece).get("famille", "")
		res.pieces.append({"piece": p.piece, "etat": float(etats.get(fam, 1.0))})
	return res


# Liste des identifiants de pièces d'un assemblage, châssis compris (avec répétitions).
static func ids(a: Dictionary) -> Array:
	var res := [] if a.get("chassis", "") == "" else [a.chassis]
	for p in a.get("pieces", []):
		res.append(p.piece)
	return res


static func compter(liste: Array) -> Dictionary:
	var c := {}
	for id in liste:
		c[id] = int(c.get(id, 0)) + 1
	return c


# Apparence (dessin) d'un assemblage : première règle dont toutes les pièces sont présentes.
# En attendant le dessin pièce par pièce (G4), un assemblage inconnu prend le dessin le plus proche.
static func apparence(a: Dictionary) -> String:
	var c := compter(ids(a))
	for r in catalogue().regles.get("apparences", []):
		if r.requiert.all(func(id): return c.has(id)):
			return r.type
	for t in historiques():
		if historiques()[t].chassis == a.get("chassis", ""):
			return t
	return ""


# Pièces d'un plan qui manquent (multiensemble) par rapport à une liste de pièces disponibles.
static func manquantes(plan: Dictionary, dispo: Array) -> Array:
	var c := compter(dispo)
	var res := []
	for id in ids(plan):
		if int(c.get(id, 0)) > 0:
			c[id] -= 1
		else:
			res.append(id)
	return res
