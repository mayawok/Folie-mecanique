# Dessin des véhicules assemblés (grille G4, DEC-036).
# Un véhicule monté à la main n'a pas de fiche dans formes_vehicules.json : on en fabrique une à partir de ses pièces
# (position et emprise sur la grille de 25 cm) et on l'enregistre sous une clé « asm_… » à côté des véhicules historiques.
# Le reste du jeu (dessin, ancrages des tirs, équipage) lit alors cette fiche comme n'importe quelle autre.
# Fonctions pures et déterministes : même assemblage, même fiche, même clé.
class_name FormeAssemblage
extends RefCounted

const C := 0.25   # côté d'une cellule (m)


# Signature d'un assemblage : châssis, pièces triées avec leur position, plaques
static func signature(a: Dictionary) -> String:
	var morceaux := []
	for p in a.get("pieces", []):
		morceaux.append("%s@%d,%d" % [p.piece, int(p.pos[0]), int(p.pos[1])])
	morceaux.sort()
	return "%s|%s|%d" % [a.get("chassis", ""), ",".join(morceaux), int(a.get("plaques", 0))]


# Type de dessin d'un assemblage : règles d'apparence (BMW), véhicule historique identique, sinon fiche fabriquée
static func type_dessin(a: Dictionary) -> String:
	var c := Assemblage.compter(Assemblage.ids(a))
	for r in Assemblage.catalogue().regles.get("apparences", []):
		if r.requiert.all(func(id): return c.has(id)):
			return r.type
	var sig := signature(a)
	for t in Assemblage.historiques():
		if signature(Assemblage.historiques()[t]) == sig and VehiculeDessin.existe(t):
			return t
	return enregistrer(a)


# Fabrique la fiche, l'enregistre (une fois) et renvoie sa clé
static func enregistrer(a: Dictionary) -> String:
	var cle := "asm_%x" % hash(signature(a))
	if not VehiculeDessin.existe(cle):
		VehiculeDessin.donnees().vehicules[cle] = forme(a)
	return cle


static func _rect(p: Dictionary) -> Rect2:
	var e: Array = p.fiche.emprise
	return Rect2(p.pos.x * C, p.pos.y * C, float(e[0]) * C, float(e[1]) * C)


static func _pts(l: Array) -> Array:
	return l


static func forme(a: Dictionary) -> Dictionary:
	var g := Assemblage.taille_grille(a)
	var L := g.x * C
	var H := g.y * C
	var places: Array = Assemblage._places(a).filter(func(p): return not p.fiche.is_empty() and p.fiche.has("emprise"))
	# Hauteur du train de roulement : fixe l'épaisseur de la caisse au-dessus du sol
	var hr := 0.5
	for p in places:
		if p.fiche.famille == "roulement":
			hr = maxf(hr, _rect(p).size.y)
	var y_dalle := hr * 0.6
	var formes := [{"pts": [[0.1, y_dalle], [L - 0.1, y_dalle], [L, y_dalle + 0.14], [L, y_dalle + 0.3], [0.0, y_dalle + 0.3], [0.0, y_dalle + 0.14]], "c": "sombre", "z": 0}]
	var roues := []
	var armes := []
	var equipage := []
	var chenille := {}
	var poids := Assemblage.poids(a)
	# Coque : monte jusqu'au sommet du moteur et de la cabine pour un char, reste basse pour un véhicule à roues
	var chenilles := places.any(func(p): return p.fiche.famille == "roulement" and p.fiche.get("type", "roues") == "chenilles")
	var sommet := y_dalle + 0.3
	for p in places:
		if p.fiche.famille in ["moteur", "cabine"]:
			sommet = maxf(sommet, _rect(p).end.y)
	var y_coque := sommet if chenilles else minf(sommet, y_dalle + 0.45)
	formes.append({"pts": [[0.05, y_dalle], [L - 0.05, y_dalle], [L, y_dalle + 0.25], [L - 0.55, y_coque], [0.35, y_coque], [0.0, y_coque - 0.2]], "c": "caisse", "z": 0})
	# Tourelles : un bloc sous chaque canon, du sommet de la coque au-dessus du tube
	var tourelles := []   # {x0, x1, haut}
	for p in places:
		if p.fiche.famille == "arme" and not String(p.fiche.get("arme", "mitrailleuse")).begins_with("mitrailleuse"):
			var r := _rect(p)
			var tw := minf(r.size.x * 0.55, 2.2)
			var haut := r.end.y + 0.12
			tourelles.append({"x0": r.position.x, "x1": r.position.x + tw, "haut": haut, "tube_y": clampf(r.position.y + r.size.y * 0.5, y_coque + 0.2, haut - 0.1)})
			formes.append({"pts": [[r.position.x, y_coque - 0.05], [r.position.x + tw, y_coque - 0.05], [r.position.x + tw * 0.85, haut - 0.2],
				[r.position.x + tw * 0.65, haut], [r.position.x + tw * 0.25, haut], [r.position.x + 0.05, haut - 0.3]], "c": "caisse", "z": 1})
	for p in places:
		var r := _rect(p)
		var f: Dictionary = p.fiche
		match f.famille:
			"roulement":
				if f.get("type", "roues") == "chenilles":
					if chenille.is_empty():
						chenille = _chenille(r)
				else:
					var rad := minf(r.size.y * 0.5, r.size.x * 0.25)
					var xs := [r.position.x + rad, r.end.x - rad]
					if r.size.x > 5.2:
						xs.insert(1, r.position.x + r.size.x * 0.5)
					for x in xs:
						roues.append({"x": x, "r": rad})
						formes.append({"arc": [x, rad, rad + 0.07, 10, 170, 0.06], "c": "sombre", "z": 2})
			"suspension":
				formes.append({"ligne": [[r.position.x, r.position.y + r.size.y * 0.5], [r.end.x, r.position.y + r.size.y * 0.5]], "ep": 0.05, "c": "metal", "z": 1})
			"moteur":
				formes.append({"pts": [[r.position.x, r.position.y], [r.end.x, r.position.y], [r.end.x, r.position.y + r.size.y * 0.8],
					[r.position.x + r.size.x * 0.85, r.end.y], [r.position.x + r.size.x * 0.1, r.end.y], [r.position.x, r.position.y + r.size.y * 0.7]], "c": "caisse", "z": 1})
				formes.append({"ligne": [[r.end.x, r.position.y + r.size.y * 0.1], [r.end.x, r.position.y + r.size.y * 0.7]], "ep": 0.05, "c": "metal", "z": 2})
			"cabine":
				var ouvert: bool = f.get("ouvert", false)
				if ouvert:
					formes.append({"pts": [[r.position.x, r.position.y], [r.end.x, r.position.y], [r.end.x, r.position.y + r.size.y * 0.5], [r.position.x, r.position.y + r.size.y * 0.5]], "c": "caisse", "z": 1})
					formes.append({"ligne": [[r.end.x - r.size.x * 0.08, r.position.y + r.size.y * 0.5], [r.end.x - r.size.x * 0.2, r.end.y]], "ep": 0.03, "c": "metal", "z": 2})
					var n := int(f.get("sieges", 1))
					for k in n:
						var fx := 0.5 if n == 1 else 0.22 + 0.56 * float(k) / float(n - 1)
						equipage.append({"x": r.position.x + r.size.x * fx, "y": r.position.y + r.size.y * 0.42,
							"role": "conducteur" if k == 0 else ("tireur" if k == 1 else "passager")})
				else:
					formes.append({"pts": [[r.position.x, r.position.y], [r.end.x, r.position.y], [r.position.x + r.size.x * 0.97, r.position.y + r.size.y * 0.9],
						[r.position.x + r.size.x * 0.8, r.end.y], [r.position.x + r.size.x * 0.15, r.end.y], [r.position.x, r.position.y + r.size.y * 0.85]], "c": "caisse", "z": 1})
					formes.append({"pts": [[r.position.x + r.size.x * 0.25, r.position.y + r.size.y * 0.55], [r.position.x + r.size.x * 0.8, r.position.y + r.size.y * 0.55],
						[r.position.x + r.size.x * 0.75, r.position.y + r.size.y * 0.85], [r.position.x + r.size.x * 0.3, r.position.y + r.size.y * 0.85]], "c": "vitre", "z": 2})
					equipage.append({"x": r.position.x + r.size.x * 0.5, "y": r.end.y, "role": "chef", "h": 0.26, "_cabine": true})
			"arme":
				var wid := String(f.get("arme", "mitrailleuse"))
				if wid.begins_with("mitrailleuse"):
					var mx := clampf(r.position.x + r.size.x * 0.35, 0.3, L - 0.5)
					var appui := y_coque
					for t in tourelles:
						if mx >= t.x0 and mx <= t.x1:
							appui = maxf(appui, t.haut)
					armes.append({"type": "mitrailleuse", "x": mx, "y": appui, "pied": clampf(r.position.y + 0.05 - appui, 0.12, 0.5), "long": maxf(1.0, r.size.x * 1.4), "ep": 0.05})
				else:
					var ep := 0.07 if wid.contains("leger") or wid.contains("37") else (0.12 if wid.contains("88") else 0.1)
					var t0: Dictionary = tourelles.filter(func(t): return is_equal_approx(t.x0, r.position.x))[0]
					armes.append({"type": "canon", "x": t0.x1 - 0.05, "y": t0.tube_y, "long": r.size.x * 0.8, "ep": ep})
	if not tourelles.is_empty():   # le chef de char sort de la tourelle
		var t1: Dictionary = tourelles[0]
		for e in equipage:
			if e.has("_cabine"):
				e.x = (t1.x0 + t1.x1) * 0.5
				e.y = t1.haut
	for e in equipage:
		e.erase("_cabine")
	for k in int(a.get("plaques", 0)):   # plaques de blindage : soudées sur l'avant de la caisse
		formes.append({"ligne": [[L - 0.05 - 0.07 * k, y_dalle], [L - 0.05 - 0.07 * k, y_dalle + 0.9]], "ep": 0.05, "c": "metal", "z": 2})
	var moteur := "char" if not chenille.is_empty() and poids > 20000.0 else ("char_leger" if not chenille.is_empty() else ("voiture" if poids < 1800.0 else "camion"))
	var res := {"nom": a.get("nom", "Assemblage"), "longueur": L, "hauteur": H, "teinte": "joueur", "moteur": moteur, "course": 0.09,
		"fiche": "Véhicule assemblé à la main.", "roues": roues, "formes": formes, "armes": armes, "equipage": equipage}
	if not chenille.is_empty():
		res["chenille"] = chenille
	return res


# Chenilles sur un train de roulement : barbotin à l'avant, tendeur à l'arrière, galets régulièrement espacés
static func _chenille(r: Rect2) -> Dictionary:
	var hr := r.size.y
	var rg := 0.24 * clampf(hr / 0.9, 0.6, 1.4)
	var ep := 0.08
	var x0 := r.position.x + hr * 1.1
	var x1 := r.end.x - hr * 1.1
	var n := maxi(2, int((x1 - x0) / 0.9) + 1)
	var galets := []
	for i in n:
		galets.append(x0 + (x1 - x0) * float(i) / float(n - 1))
	return {"barbotin": [r.end.x - hr * 0.5, hr * 0.72, hr * 0.33], "tendeur": [r.position.x + hr * 0.45, hr * 0.55, hr * 0.3],
		"galets": galets, "r_galet": rg, "rouleaux": [], "ep": ep}
