# Carte du monde de conception (DEC-154) : villes-étapes, routes et lieux d'intérêt posés sur la carte de France déformée.
# Données : game/data/carte_monde.json (positions de 0 à 1 sur l'image). Logique pure, sans écran, testable.
# Ajouter une ville, un lieu, une route ou un type de lieu = une entrée dans le JSON, sans code.
class_name CarteMonde
extends RefCounted

static var _data := {}
static var _index := {}


static func donnees() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open("res://data/carte_monde.json", FileAccess.READ)
		_data = JSON.parse_string(f.get_as_text())
		_index = {}
		for l in _data.lieux:
			_index[String(l.id)] = l
	return _data


static func lieux() -> Array:
	return donnees().lieux


static func villes() -> Array:
	return lieux().filter(func(l): return String(l.type) == "ville")


static func routes() -> Array:
	return donnees().routes


static func lieu(id: String) -> Dictionary:
	donnees()
	return _index.get(id, {})


static func pos(id: String) -> Vector2:
	var l := lieu(id)
	if l.is_empty():
		return Vector2.ZERO
	return Vector2(float(l.pos[0]), float(l.pos[1]))


# Longueur d'une route en kilomètres de carte (échelle : largeur de l'image = echelle_km)
static func longueur_km(r: Dictionary) -> float:
	return pos(String(r.a)).distance_to(pos(String(r.b))) * float(donnees().get("echelle_km", 1000))


# Routes qui partent d'une ville : [{id, route}]
static func voisins(id: String) -> Array:
	var res := []
	for r in routes():
		if String(r.a) == id:
			res.append({"id": String(r.b), "route": r})
		elif String(r.b) == id:
			res.append({"id": String(r.a), "route": r})
	return res


# Plus court chemin par les routes (Dijkstra sur les longueurs) : liste d'ids de a à b, vide si impossible
static func chemin(a: String, b: String) -> Array:
	if lieu(a).is_empty() or lieu(b).is_empty():
		return []
	var dist := {a: 0.0}
	var prec := {}
	var ouverts := [a]
	var faits := {}
	while not ouverts.is_empty():
		var u: String = ouverts[0]
		for o in ouverts:
			if float(dist[o]) < float(dist[u]):
				u = o
		ouverts.erase(u)
		if u == b:
			break
		faits[u] = true
		for v in voisins(u):
			var w: String = v.id
			if faits.has(w):
				continue
			var d := float(dist[u]) + longueur_km(v.route)
			if not dist.has(w) or d < float(dist[w]):
				dist[w] = d
				prec[w] = u
				if not ouverts.has(w):
					ouverts.append(w)
	if not dist.has(b):
		return []
	var res := [b]
	while res[0] != a:
		res.push_front(prec[res[0]])
	return res


# Route entre deux villes voisines, {} sinon
static func route_entre(a: String, b: String) -> Dictionary:
	for r in routes():
		if (String(r.a) == a and String(r.b) == b) or (String(r.a) == b and String(r.b) == a):
			return r
	return {}


# Lieu le plus proche d'un point de la carte (0 à 1), à moins de rayon ; "" sinon
static func lieu_proche(p: Vector2, rayon: float) -> String:
	var meilleur := ""
	var d_min := rayon
	for l in lieux():
		var d := Vector2(float(l.pos[0]), float(l.pos[1])).distance_to(p)
		# les villes gagnent à distance égale (plus grosses à l'écran)
		if String(l.type) == "ville":
			d *= 0.7
		if d < d_min:
			d_min = d
			meilleur = String(l.id)
	return meilleur
