# Construction libre sur la grille (DEC-043) : on peint le châssis case par case, on pose les essieux dessous,
# on choisit leur train (roues de trois tailles ou chenille), puis on pose moteurs, cabines et armes dessus.
# Tout est compatible : rien n'est interdit sauf l'absurde (pas de châssis, personne pour conduire).
# Les mauvais choix donnent de mauvais résultats pratiques, calculés ici : bascule, surcharge, roues en l'air,
# moteur trop faible, tir masqué, recul, instabilité. Fonctions pures et déterministes, testables sans écran.
#
# Format (persisté dans la sauvegarde) :
# {"libre": true, "nom": "…", "cases": [[x, y, "acier"|"blindage"|"origine"], …],
#  "essieux": [{"x": colonne, "piece": "essieu_leger", "train": "roue_moyenne"}, …],
#  "pieces": [{"piece": id, "pos": [x, y]}, …], "plaques": 0, "origine": {"chassis": id, "n": cases d'origine}}
# Coordonnées : cellules de 25 cm, y vers le haut. L'essieu se fixe sous la case la plus basse de sa colonne.
class_name ConstructionLibre
extends RefCounted

const C := 0.25          # côté d'une cellule (m)
const TOLERANCE := 0.5   # débattement de suspension (cellules) : une roue à moins de 12,5 cm du sol porte encore
const FAMILLES_PIECES := ["moteur", "radiateur", "poste", "cabine", "arme", "equipement", "coque", "greffe"]
const TRAVERSABLES := ["poutre", "tube"]   # un moteur peut traverser ces cases (cadre en échelle, treillis), DEC-080
const OPAC_ECORCHE := 0.3   # vue écorchée : coque transparente pour voir la mécanique (DEC-067)
const ROLES := ["tireur", "chargeur", "chef", "mecanicien", "infirmier", "passager"]   # le siège 1 est le conducteur (DEC-050)


static func R() -> Dictionary:
	return Assemblage.catalogue().regles.libre


static func taille() -> Vector2i:
	var g: Array = R().grille
	return Vector2i(int(g[0]), int(g[1]))


static func remorque(a: Dictionary) -> bool:   # remorque (DEC-080) : ni moteur ni conducteur, un timon pour l'atteler
	return bool(a.get("remorque", false))


# Déplace tout le véhicule de (dx, dy) cases (DEC-081) : cases, essieux, pièces, tôles. {} s'il sortirait de la grille.
static func deplacer(a: Dictionary, dx: int, dy: int) -> Dictionary:
	if dx == 0 and dy == 0:
		return a
	var G := taille()
	var b := a.duplicate(true)
	for c in b.get("cases", []):
		c[0] = int(c[0]) + dx
		c[1] = int(c[1]) + dy
		if c[0] < 0 or c[1] < 0 or c[0] >= G.x or c[1] >= G.y:
			return {}
	for e in b.get("essieux", []):
		e.x = int(e.x) + dx
		if e.has("y"):
			e.y = int(e.y) + dy
	for p in b.get("pieces", []):
		var em: Array = p.get("emprise", Assemblage.piece(String(p.piece)).get("emprise", [1, 1]))
		p.pos = [int(p.pos[0]) + dx, int(p.pos[1]) + dy]
		if p.pos[0] < 0 or p.pos[1] < 0 or p.pos[0] + int(em[0]) > G.x or p.pos[1] + int(em[1]) > G.y:
			return {}
	if b.has("berliet"):   # l'essieu avant fixe du Berliet suit le véhicule
		b.berliet.essieu_av = int(b.berliet.essieu_av) + dx
	if b.has("plateforme"):
		b.plateforme.x = int(b.plateforme.x) + dx
		b.plateforme.y = int(b.plateforme.y) + dy
	for t in b.get("toles", []):
		t[0] = int(t[0]) + dx
		t[2] = int(t[2]) + dx
		t[1] = int(t[1]) + dy
		t[3] = int(t[3]) + dy
		if t[0] < 0 or t[2] < 0 or t[1] < 0 or t[3] < 0 or t[0] > G.x or t[2] > G.x or t[1] > G.y or t[3] > G.y:
			return {}
	return b


# Fait d'une grille une remorque : moteurs et radiateurs démontés, timon posé à l'avant, contre le bas du châssis
static func en_remorque(a: Dictionary) -> Dictionary:
	var b := a.duplicate(true)
	b.pieces = b.get("pieces", []).filter(func(p): return not Assemblage.piece(String(p.piece)).get("famille", "") in ["moteur", "radiateur"])
	b.remorque = true
	if not _pieces(b).any(func(q): return int(q.fiche.get("timon", 0)) > 0):
		var xmax := -1
		var ymin := 99
		for c in _cases(b):
			xmax = maxi(xmax, c.x)
		for c in _cases(b):
			if c.x == xmax:
				ymin = mini(ymin, c.y)
		if xmax >= 0:
			var t := poser(b, "greffe_timon", Vector2i(xmax + 1, ymin))
			if not t.is_empty():
				b = t
	if not String(b.get("nom", "")).ends_with("(remorque)"):
		b.nom = String(b.get("nom", "Remorque")) + " (remorque)"
	return nettoyer(b)


static func est_libre(a: Dictionary) -> bool:
	return bool(a.get("libre", false))


static func nouvelle(nom := "Frankenstein") -> Dictionary:
	return {"libre": true, "nom": nom, "cases": [], "essieux": [], "pieces": [], "plaques": 0, "v": 2}   # v 2 : radiateur exigé (DEC-080)


# --- Plateformes de voiture (DEC-083) ---------------------------------------------------------
# Une voiture repose sur une plateforme (court, moyen, long) : châssis de poutres et deux ponts rigides.
# Hors mode créatif elle ne change pas ; carrosserie, moteur, arme, greffes et garde au sol s'échangent sur des emplacements.
static func _plateformes() -> Dictionary:
	return R().get("plateformes", {})


static func tailles_plateforme() -> Array:
	return ["court", "moyen", "long"]


static func plateforme_de(a: Dictionary) -> String:
	return String(a.get("plateforme", {}).get("taille", ""))


# Nouvelle voiture : complete = avec poste, radiateur, moteur et carrosserie par défaut ; sinon châssis et roues seuls
static func voiture(t: String, complete := true) -> Dictionary:
	var P := _plateformes()
	if not P.has(t):
		return {}
	var fp: Dictionary = P[t]
	var B: Dictionary = P.base
	var n := int(fp.longueur)
	var x0 := (taille().x - n) / 2
	var y0 := 5
	var a := nouvelle(String(fp.nom))
	a.plateforme = {"taille": t, "x": x0, "y": y0, "rehausse": 0}
	for x in range(x0, x0 + n):
		a.cases.append([x, y0, String(B.sorte)])
	for x in [x0 + int(B.essieu_arriere), x0 + n - 1 - int(B.essieu_avant_depuis_bout)]:
		a.essieux.append({"x": x, "piece": String(B.essieu), "train": String(B.roue), "y": y0 - int(B.hauteur_pont)})
	a = rehausser(a, int(B.get("rehausse_defaut", 0)))   # un peu plus haute que d'origine
	if complete:
		for id in [String(fp.carrosserie), String(B.radiateur), String(fp.moteur)]:
			var r := poser_emplacement(a, id, Vector2i(-1, -1))
			if not r.is_empty():
				a = r.a
		var b := poser(a, String(B.poste), Vector2i(x0 + n - 9, y0 + 1))
		if not b.is_empty():
			a = b
	return a


# Emplacements de la plateforme, en cases absolues : [{nom, rect, cible, famille | ids}]
static func emplacements(a: Dictionary) -> Array:
	if not a.has("plateforme"):
		return []
	var n := int(_plateformes()[plateforme_de(a)].longueur)
	var o := Vector2i(int(a.plateforme.x), int(a.plateforme.y))
	return [
		{"nom": "caisse", "rect": Rect2i(o, Vector2i(n, 5)), "cible": o, "famille": "coque"},
		{"nom": "capot", "rect": Rect2i(o + Vector2i(n - 6, 1), Vector2i(5, 4)), "cible": o + Vector2i(n - 1, 1), "famille": "moteur", "droite": true},
		{"nom": "calandre", "rect": Rect2i(o + Vector2i(n - 1, 1), Vector2i(1, 2)), "cible": o + Vector2i(n - 1, 1), "famille": "radiateur"},
		{"nom": "nez", "rect": Rect2i(o + Vector2i(n, -1), Vector2i(2, 4)), "cible": o + Vector2i(n, 0), "ids": ["greffe_pare_buffle"]},
		{"nom": "arriere", "rect": Rect2i(o + Vector2i(0, 1), Vector2i(6, 6)), "cible": o + Vector2i(1, 3), "famille": "arme", "affut": true},
		{"nom": "toit", "rect": Rect2i(o + Vector2i(n / 2 - 4, 4), Vector2i(8, 3)), "cible": o + Vector2i(n / 2 - 1, 5), "ids": ["greffe_piques", "greffe_drapeau"]}]


static func _accepte(a: Dictionary, s: Dictionary, id: String) -> bool:
	if s.has("ids"):
		return id in s.ids
	var f := Assemblage.piece(id)
	if String(f.get("famille", "")) != String(s.famille):
		return false
	return s.famille != "coque" or String(f.get("taille", "")) == plateforme_de(a)


# Pose une pièce sur l'emplacement qu'elle vise (cell = son coin ; (-1, -1) : le premier emplacement qui l'accepte).
# La pièce qui l'occupait est retirée (elle retourne à la réserve). {a, remplace} ou {} si aucun emplacement ne convient.
static func poser_emplacement(a: Dictionary, id: String, cell: Vector2i, extra := {}) -> Dictionary:
	if extra.has("coupe"):
		return {}   # morceau scié : posé librement
	var e := _emprise(id)
	for s in emplacements(a):
		if not _accepte(a, s, id):
			continue
		if cell.x >= 0 and not Rect2i(cell, e).intersects(s.rect):
			continue
		var b := a.duplicate(true)
		var ancien := ""
		var i: int = b.pieces.size() - 1
		while i >= 0:
			var pid := String(b.pieces[i].piece)
			var q: Dictionary = _pieces(b)[i]
			if _accepte(b, s, pid) and Rect2i(q.pos, q.e).intersects(s.rect):
				ancien = pid
				b.pieces.remove_at(i)
			i -= 1
		var cible: Vector2i = s.cible
		if s.get("droite", false):
			cible.x -= e.x
		var c := poser(b, id, cible, false, extra)
		if s.get("affut", false):   # arme sur affût soudé à la caisse : tenue sans appui, à hauteur de ceinture
			c = b.duplicate(true)
			c.pieces.append({"piece": id, "pos": [cible.x, cible.y], "affut": true})
			for k in extra:
				c.pieces[c.pieces.size() - 1][k] = extra[k]
			if not _libre(_occupation(c, c.pieces.size() - 1), cible, e):
				return {}
		if c.is_empty():
			return {}
		return {"a": c, "remplace": ancien}
	return {}


# Garde au sol (0 à rehausse_max crans de 25 cm) : les ponts descendent, la suspension qui convient est montée
static func rehausser(a: Dictionary, crans: int) -> Dictionary:
	if not a.has("plateforme"):
		return {}
	var B: Dictionary = _plateformes().base
	crans = clampi(crans, 0, int(B.rehausse_max))
	var h := int(B.hauteur_pont) + crans
	var b := a.duplicate(true)
	b.plateforme.rehausse = crans
	var ls := liaisons_pour(h)
	for e in b.essieux:
		if bool(Assemblage.piece(String(e.piece)).get("pont", false)):
			e.y = y_essieu(b, int(e.x)) - h
			e.liaison = ls[0] if not ls.is_empty() else ""
	return b


# Mode créatif : change la longueur de la plateforme. Les pièces des emplacements suivent (l'avant reste à l'avant) ;
# la carrosserie d'une autre taille est remplacée par celle de la nouvelle plateforme.
static func changer_plateforme(a: Dictionary, t: String) -> Dictionary:
	if not a.has("plateforme"):
		return voiture(t)
	var b := voiture(t, false)
	if b.is_empty():
		return {}
	b = rehausser(b, int(a.plateforme.get("rehausse", 0)))
	for k in ["nom", "nom_choisi", "peinture"]:
		if a.has(k):
			b[k] = a[k]
	var n0 := int(_plateformes()[plateforme_de(a)].longueur)
	var n1 := int(_plateformes()[t].longueur)
	var o0 := Vector2i(int(a.plateforme.x), int(a.plateforme.y))
	var o1 := Vector2i(int(b.plateforme.x), int(b.plateforme.y))
	var avec_caisse := false
	for p in _pieces(a):
		if _coque(p.fiche) and p.fiche.has("taille"):
			continue
		var rel: Vector2i = p.pos - o0
		if rel.x >= n0 / 2:
			rel.x += n1 - n0   # avant : reste à la même distance du nez
		var cell: Vector2i = o1 + rel
		var r := poser_emplacement(b, p.id, cell)
		if not r.is_empty():
			b = r.a
			continue
		var c := poser(b, p.id, cell, p.miroir)
		if not c.is_empty():
			b = c
	for p in _pieces(b):
		avec_caisse = avec_caisse or (_coque(p.fiche) and p.fiche.has("taille"))
	if not avec_caisse:
		var r2 := poser_emplacement(b, String(_plateformes()[t].carrosserie), Vector2i(-1, -1))
		if not r2.is_empty():
			b = r2.a
	return b


# --- Lecture de la grille --------------------------------------------------------------------
static func _cases(a: Dictionary) -> Dictionary:   # Vector2i -> sorte
	var res := {}
	for c in a.get("cases", []):
		res[Vector2i(int(c[0]), int(c[1]))] = String(c[2]) if c.size() > 2 else "acier"
	return res


static func _emprise(id: String) -> Vector2i:
	var e: Array = Assemblage.piece(id).get("emprise", [1, 1])
	return Vector2i(int(e[0]), int(e[1]))


static func _pieces(a: Dictionary) -> Array:   # [{i, id, fiche, pos, e}]
	var res := []
	var i := 0
	for p in a.get("pieces", []):
		var e := _emprise(String(p.piece))
		var coupe: Array = p.get("coupe", [0.0, 1.0, 0.0, 1.0])   # morceau gardé à la scie : [gauche, droite, bas, haut] de l'image (DEC-072)
		if p.has("emprise"):
			e = Vector2i(int(p.emprise[0]), int(p.emprise[1]))
		res.append({"i": i, "id": String(p.piece), "fiche": Assemblage.piece(String(p.piece)),
			"pos": Vector2i(int(p.pos[0]), int(p.pos[1])), "e": e, "miroir": bool(p.get("miroir", false)),
			"coupe": coupe, "k": (float(coupe[1]) - float(coupe[0])) * (float(coupe[3]) - float(coupe[2])), "affut": bool(p.get("affut", false))})
		i += 1
	return res


static func _habillage(fiche: Dictionary) -> bool:   # carrosserie : posée au-dessus des sièges, sans les remplacer (DEC-062)
	return bool(fiche.get("habillage", false))


# Coque de donneur (DEC-067) : plan carrosserie, posée par-dessus tout le reste sans occuper de case mécanique
static func _coque(fiche: Dictionary) -> bool:
	return fiche.get("famille", "") == "coque"


static func _siege(fiche: Dictionary) -> bool:
	return int(fiche.get("sieges", 0)) > 0


static func _occupation(a: Dictionary, sauf := -1) -> Dictionary:   # cellule -> "case" | indice de pièce (hors carrosseries)
	var occ := {}
	for c in _cases(a):
		occ[c] = "case"
	for p in _pieces(a):
		if p.i == sauf or _habillage(p.fiche) or _coque(p.fiche):
			continue
		for x in range(p.pos.x, p.pos.x + p.e.x):
			for y in range(p.pos.y, p.pos.y + p.e.y):
				occ[Vector2i(x, y)] = p.i
	return occ


static func _occ_hab(a: Dictionary, sauf := -1) -> Dictionary:   # cellule -> indice de carrosserie
	var occ := {}
	for p in _pieces(a):
		if p.i == sauf or not _habillage(p.fiche):
			continue
		for x in range(p.pos.x, p.pos.x + p.e.x):
			for y in range(p.pos.y, p.pos.y + p.e.y):
				occ[Vector2i(x, y)] = p.i
	return occ


static func _occ_coque(a: Dictionary, sauf := -1) -> Dictionary:   # cellule -> indice de coque
	var occ := {}
	for p in _pieces(a):
		if p.i == sauf or not _coque(p.fiche):
			continue
		for x in range(p.pos.x, p.pos.x + p.e.x):
			for y in range(p.pos.y, p.pos.y + p.e.y):
				occ[Vector2i(x, y)] = p.i
	return occ


# Occupation complète (pièces et carrosseries), pour savoir si un tir est masqué
static func _occ_totale(a: Dictionary) -> Dictionary:
	var occ := _occupation(a)
	var hab := _occ_hab(a)
	for c in hab:
		occ[c] = hab[c]
	return occ


# Une pièce posée est-elle valide ? Une carrosserie peut recouvrir des sièges ; les autres pièces ne chevauchent rien.
static func _valide(a: Dictionary, p: Dictionary) -> bool:
	var occ := _occupation(a, p.i)
	var hab := _occ_hab(a, p.i)
	var coq := _occ_coque(a, p.i)
	var toits := {}   # une pièce ne repose que sur le toit d'une coque (pas d'appui circulaire)
	for c in coq:
		if not coq.has(c + Vector2i(0, 1)):
			toits[c] = coq[c]
	var occ_sup := occ.duplicate()   # une greffe ne porte rien : aucune pièce ne repose dessus
	for c in occ:
		if occ[c] is int and _greffe(_pieces(a)[int(occ[c])].fiche):
			occ_sup.erase(c)
	if p.get("affut", false) and a.has("plateforme"):   # arme sur l'affût arrière d'une voiture (DEC-083)
		return _libre(occ, p.pos, p.e)
	if _greffe(p.fiche):   # accrochée à l'extérieur : libre, et collée (côté, dessus ou dessous) au châssis ou à une pièce
		if not _libre(occ, p.pos, p.e) or not _libre(coq, p.pos, p.e):
			return false
		for x in range(p.pos.x, p.pos.x + p.e.x):
			for y in range(p.pos.y, p.pos.y + p.e.y):
				if hab.has(Vector2i(x, y)):
					return false
		return _colle(_union(occ_sup, coq), p.pos, p.e)   # collée au châssis, à une pièce ou à une carrosserie
	if _coque(p.fiche):   # peut chevaucher d'autres coques (pour les découper, DEC-080) ; tenue si elle recouvre le châssis ou une pièce, ou repose dessus
		var tout := _union(_union(occ_sup, hab), coq)
		for x in range(p.pos.x, p.pos.x + p.e.x):
			for y in range(p.pos.y, p.pos.y + p.e.y):
				if occ.has(Vector2i(x, y)) and occ[Vector2i(x, y)] is String:   # recouvre le châssis
					return true
		return _portee(tout, p.pos, p.e)
	if _habillage(p.fiche):
		if not _libre(hab, p.pos, p.e):
			return false
		for x in range(p.pos.x, p.pos.x + p.e.x):   # pas de chevauchement avec autre chose qu'un siège ou le châssis
			for y in range(p.pos.y, p.pos.y + p.e.y):
				var c := Vector2i(x, y)
				if occ.has(c) and occ[c] is String:
					return false
				if occ.has(c) and not _siege(_pieces(a)[int(occ[c])].fiche):
					return false
		return _portee(_union(_union(occ_sup, hab), toits), p.pos, p.e)
	if p.fiche.get("famille", "") == "moteur":   # un moteur traverse les poutres et les tubes du châssis (DEC-080)
		var cs := _cases(a)
		var traverse := false
		for x in range(p.pos.x, p.pos.x + p.e.x):
			for y in range(p.pos.y, p.pos.y + p.e.y):
				var c := Vector2i(x, y)
				if cs.has(c) and String(cs[c]) in TRAVERSABLES:
					occ.erase(c)
					traverse = true
		if traverse and _libre(occ, p.pos, p.e):
			for x in range(p.pos.x, p.pos.x + p.e.x):
				for y in range(p.pos.y, p.pos.y + p.e.y):
					if hab.has(Vector2i(x, y)):
						return false
			return true
	var libre := _libre(occ, p.pos, p.e)
	if libre and not _siege(p.fiche):
		for x in range(p.pos.x, p.pos.x + p.e.x):
			for y in range(p.pos.y, p.pos.y + p.e.y):
				if hab.has(Vector2i(x, y)):
					libre = false
	return libre and _portee(_union(_union(occ_sup, hab), toits), p.pos, p.e)   # une pièce peut reposer sur une coque (arme sur le toit)


# --- Tôles tracées (DEC-080) : [[x0, y0, x1, y1]] en coins de cases ----------------------------
static func toles_de(a: Dictionary) -> Array:   # [{a, b, long (cases), facteur, milieu}]
	var TL: Dictionary = R().get("toles", {"facteur_max": 2.5})
	var res := []
	for t in a.get("toles", []):
		var pa := Vector2(float(t[0]), float(t[1]))
		var pb := Vector2(float(t[2]), float(t[3]))
		var d := (pb - pa).abs()
		var theta := atan2(d.x, d.y)   # 0 : tôle verticale, face aux tirs
		var f := 1.0 if theta > deg_to_rad(75.0) else minf(float(TL.facteur_max), 1.0 / cos(theta))
		res.append({"a": pa, "b": pb, "long": pa.distance_to(pb), "facteur": f, "milieu": (pa + pb) * 0.5})
	return res


# Un coin de case est-il accroché au véhicule (case, pièce, carrosserie) ou au bout d'une autre tôle ?
static func coin_accroche(a: Dictionary, q: Vector2i) -> bool:
	var occ := _union(_occ_totale(a), _occ_coque(a))
	for d in [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(-1, -1)]:
		if occ.has(q + d):
			return true
	for t in a.get("toles", []):
		if Vector2i(int(t[0]), int(t[1])) == q or Vector2i(int(t[2]), int(t[3])) == q:
			return true
	return false


# Trace une tôle d'un coin à l'autre ; {} si elle ne s'accroche à rien ou existe déjà
static func poser_tole(a: Dictionary, q0: Vector2i, q1: Vector2i) -> Dictionary:
	var G := taille()
	if q0 == q1 or q0.x < 0 or q0.y < 0 or q1.x < 0 or q1.y < 0 or q0.x > G.x or q1.x > G.x or q0.y > G.y or q1.y > G.y:
		return {}
	if not (coin_accroche(a, q0) or coin_accroche(a, q1)):
		return {}
	for t in a.get("toles", []):
		var u := [Vector2i(int(t[0]), int(t[1])), Vector2i(int(t[2]), int(t[3]))]
		if (u[0] == q0 and u[1] == q1) or (u[0] == q1 and u[1] == q0):
			return {}
	var b := a.duplicate(true)
	if not b.has("toles"):
		b.toles = []
	b.toles.append([q0.x, q0.y, q1.x, q1.y])
	return b


# Tôle la plus proche d'un point (en cases), à moins de `dist` ; -1 sinon
static func tole_en(a: Dictionary, p: Vector2, dist := 0.45) -> int:
	var best := -1
	var dm := dist
	var ts: Array = a.get("toles", [])
	for i in ts.size():
		var t: Array = ts[i]
		var q := Geometry2D.get_closest_point_to_segment(p, Vector2(float(t[0]), float(t[1])), Vector2(float(t[2]), float(t[3])))
		if q.distance_to(p) < dm:
			dm = q.distance_to(p)
			best = i
	return best


static func retirer_tole(a: Dictionary, i: int) -> Dictionary:
	var b := a.duplicate(true)
	if i >= 0 and i < b.get("toles", []).size():
		b.toles.remove_at(i)
	return b


# Formes fermées par des tôles : pour chaque tôle, le plus court chemin qui relie ses deux bouts sans elle
static func toles_fermees(a: Dictionary) -> Array:   # [PackedVector2Array] en cases
	var ts: Array = a.get("toles", [])
	var voisins := {}
	for t in ts:
		var u := Vector2i(int(t[0]), int(t[1]))
		var v := Vector2i(int(t[2]), int(t[3]))
		if not voisins.has(u):
			voisins[u] = []
		if not voisins.has(v):
			voisins[v] = []
		voisins[u].append(v)
		voisins[v].append(u)
	var vus := {}
	var res := []
	for t in ts:
		var u := Vector2i(int(t[0]), int(t[1]))
		var v := Vector2i(int(t[2]), int(t[3]))
		var prec := {u: u}
		var file := [u]
		while not file.is_empty() and not prec.has(v):
			var c: Vector2i = file.pop_front()
			for n in voisins[c]:
				if (c == u and n == v) or prec.has(n):
					continue
				prec[n] = c
				file.append(n)
		if not prec.has(v):
			continue
		var chemin := [v]
		while chemin.back() != u:
			chemin.append(prec[chemin.back()])
		if chemin.size() < 3:
			continue
		var cle := chemin.duplicate()
		cle.sort()
		if vus.has(str(cle)):
			continue
		vus[str(cle)] = true
		var poly := PackedVector2Array()
		for q in chemin:
			poly.append(Vector2(q))
		res.append(poly)
	return res


# Refroidissement (DEC-080) : puissance des moteurs à eau, capacité des radiateurs à 2 cases au plus d'un tel moteur
static func refroidissement(a: Dictionary) -> Dictionary:
	var moteurs := []
	var besoin := 0.0
	for p in _pieces(a):
		if p.fiche.get("famille", "") == "moteur" and not bool(p.fiche.get("refroidi_air", false)):
			moteurs.append(Rect2i(p.pos, p.e))
			besoin += float(p.fiche.get("puissance_ch", 0)) * (1.3 if bool(p.fiche.get("a_nu", false)) else 1.0)   # moteur à nu : chauffe plus (DEC-083)
	var cap := 0.0
	var loin := 0
	for p in _pieces(a):
		if p.fiche.get("famille", "") != "radiateur":
			continue
		var r := Rect2i(p.pos, p.e).grow(2)
		if moteurs.any(func(m): return r.intersects(m)):
			cap += float(p.fiche.get("refroidit_ch", 0))
		else:
			loin += 1
	return {"besoin": besoin, "capacite": cap, "loin": loin}


static func _greffe(fiche: Dictionary) -> bool:
	return fiche.get("famille", "") == "greffe"


# Une cellule voisine (4 côtés) du rectangle est-elle occupée ?
static func _colle(occ: Dictionary, pos: Vector2i, e: Vector2i) -> bool:
	for x in range(pos.x, pos.x + e.x):
		if occ.has(Vector2i(x, pos.y - 1)) or occ.has(Vector2i(x, pos.y + e.y)):
			return true
	for y in range(pos.y, pos.y + e.y):
		if occ.has(Vector2i(pos.x - 1, y)) or occ.has(Vector2i(pos.x + e.x, y)):
			return true
	return false


static func _union(a: Dictionary, b: Dictionary) -> Dictionary:
	var r := a.duplicate()
	for c in b:
		if not r.has(c):
			r[c] = b[c]
	return r


# Hauteur de l'essieu d'une colonne : bas de la case la plus basse (-1 si la colonne est vide)
static func y_essieu(a: Dictionary, x: int) -> int:
	var y := -1
	for c in _cases(a):
		if c.x == x and (y < 0 or c.y < y):
			y = c.y
	return y


static func _essieux(a: Dictionary) -> Array:   # triés par x : [{x, piece, train, y, r, fiche_e, fiche_t}]
	var res := []
	for e in a.get("essieux", []):
		if String(e.get("train", "")) == "":
			continue   # essieu posé, roue pas encore montée (DEC-051)
		var x := int(e.x)
		var ft := Assemblage.piece(String(e.train))
		var fe := Assemblage.piece(String(e.piece))
		if bool(fe.get("pont", false)) and not liaison_ok(a, e):
			continue   # pont rigide non relié (ou liaison de mauvaise longueur) : il ne porte rien (DEC-070, DEC-075)
		var fl := Assemblage.piece(String(e.get("liaison", ""))) if bool(fe.get("pont", false)) else {}
		var h := float(ecart_pont(a, e)) if bool(fe.get("pont", false)) else 0.0   # le pont est placé en l'air sous le châssis
		res.append({"x": x, "piece": String(e.piece), "train": String(e.train), "y": float(y_essieu(a, x)) - h, "h": h,
			"r": float(ft.get("diametre_cases", 2)) * 0.5, "fiche_e": fe, "fiche_t": ft, "fiche_l": fl})
	res.sort_custom(func(p, q): return p.x < q.x)
	return res


# --- Édition (l'écran n'appelle que ces fonctions) ---------------------------------------------
static func _dans(cell: Vector2i) -> bool:
	var g := taille()
	return cell.x >= 0 and cell.y >= 0 and cell.x < g.x and cell.y < g.y


# Peint (sorte = "acier" | "blindage") ou efface (sorte = "") une case. Une case occupée par une pièce ne se peint pas.
static func peindre(a: Dictionary, cell: Vector2i, sorte: String) -> Dictionary:
	if not _dans(cell):
		return a
	var occ := _occupation(a)
	if sorte != "" and occ.has(cell) and not (occ[cell] is String):
		if not (sorte in TRAVERSABLES and _pieces(a)[int(occ[cell])].fiche.get("famille", "") == "moteur"):
			return a
	var b := a.duplicate(true)
	var garde := []
	for c in b.cases:
		if Vector2i(int(c[0]), int(c[1])) != cell:
			garde.append(c)
	if sorte != "":
		garde.append([cell.x, cell.y, sorte])
	b.cases = garde
	return nettoyer(b)


# Pose (ou remplace) l'essieu d'une colonne. La colonne doit contenir au moins une case.
# y (ponts rigides seulement) : rangée du centre du pont, placé en l'air sous le châssis ; par défaut contre le châssis
static func poser_essieu(a: Dictionary, x: int, essieu_id: String, train_id: String, y := -1) -> Dictionary:
	if y_essieu(a, x) < 0:
		return {}
	var avant := essieu_en(a, x)
	var b := retirer_essieu(a, x)
	b.essieux.append({"x": x, "piece": essieu_id, "train": train_id})
	if bool(Assemblage.piece(essieu_id).get("pont", false)):
		var yp := y if y >= 0 else int(avant.get("y", y_essieu(a, x)))
		b.essieux[b.essieux.size() - 1].y = clampi(yp, 0, y_essieu(a, x))
		if String(avant.get("liaison", "")) != "":
			b.essieux[b.essieux.size() - 1].liaison = avant.liaison
	return b


# Monte (train_id) ou démonte ("") la roue ou la chenille de l'essieu de la colonne x. {} s'il n'y a pas d'essieu.
static func monter_train(a: Dictionary, x: int, train_id: String) -> Dictionary:
	if essieu_en(a, x).is_empty():
		return {}
	var b := a.duplicate(true)
	for e in b.essieux:
		if int(e.x) == x:
			e.train = train_id
	return b


# Modèles d'une famille du catalogue (hors pièces retirées) : aucune liste de modèles écrite dans le code
static func _famille_ids(fam: String) -> Array:
	return Assemblage.catalogue().pieces.keys().filter(func(id): return Assemblage.piece(id).get("famille", "") == fam and not Assemblage.piece(id).get("retire", false))


# Écart (en cases) entre le dessous du châssis et le pont rigide placé en l'air (DEC-075)
static func ecart_pont(a: Dictionary, e: Dictionary) -> int:
	return maxi(0, y_essieu(a, int(e.x)) - int(e.get("y", y_essieu(a, int(e.x)))))


# La liaison du pont couvre-t-elle son écart avec le châssis ?
static func liaison_ok(a: Dictionary, e: Dictionary) -> bool:
	var fl := Assemblage.piece(String(e.get("liaison", "")))
	if fl.is_empty():
		return false
	var h := ecart_pont(a, e)
	return h >= int(fl.get("hauteur_min", 0)) and h <= int(fl.get("hauteur_max", 0))


# Liaisons qui conviennent à un écart donné (la plus courte d'abord)
static func liaisons_pour(h: int) -> Array:
	var res := _famille_ids("liaison").filter(func(id): return h >= int(Assemblage.piece(id).get("hauteur_min", 0)) and h <= int(Assemblage.piece(id).get("hauteur_max", 0)))
	res.sort_custom(func(p, q): return int(Assemblage.piece(p).hauteur_min) < int(Assemblage.piece(q).hauteur_min))
	return res


# Relie (liaison_id) ou détache ("") le pont rigide de la colonne x. {} s'il n'y a pas de pont,
# ou si la liaison ne couvre pas l'écart entre le pont et le châssis (DEC-075).
static func relier(a: Dictionary, x: int, liaison_id: String) -> Dictionary:
	var ex := essieu_en(a, x)
	if ex.is_empty() or not bool(Assemblage.piece(String(ex.piece)).get("pont", false)):
		return {}
	if liaison_id != "":
		var t := ex.duplicate()
		t.liaison = liaison_id
		if not liaison_ok(a, t):
			return {}
	var b := a.duplicate(true)
	for e in b.essieux:
		if int(e.x) == x:
			e.liaison = liaison_id
	return b


# Ponts rigides sans liaison (défaut grave : rien ne les tient au châssis)
static func ponts_libres(a: Dictionary) -> Array:
	return a.get("essieux", []).filter(func(e): return bool(Assemblage.piece(String(e.piece)).get("pont", false)) and not liaison_ok(a, e))


# Essieux sans roue (affichage et défaut)
static func essieux_nus(a: Dictionary) -> Array:
	return a.get("essieux", []).filter(func(e): return String(e.get("train", "")) == "")


static func retirer_essieu(a: Dictionary, x: int) -> Dictionary:
	var b := a.duplicate(true)
	b.essieux = b.get("essieux", []).filter(func(e): return int(e.x) != x)
	return b


static func essieu_en(a: Dictionary, x: int) -> Dictionary:
	for e in a.get("essieux", []):
		if int(e.x) == x:
			return e
	return {}


# Une pièce est portée si une cellule sous sa rangée basse est une case ou une autre pièce
static func _portee(occ: Dictionary, pos: Vector2i, e: Vector2i) -> bool:
	for x in range(pos.x, pos.x + e.x):
		if occ.has(Vector2i(x, pos.y - 1)):
			return true
	return false


static func _libre(occ: Dictionary, pos: Vector2i, e: Vector2i) -> bool:
	if not _dans(pos) or not _dans(pos + e - Vector2i.ONE):
		return false
	for x in range(pos.x, pos.x + e.x):
		for y in range(pos.y, pos.y + e.y):
			if occ.has(Vector2i(x, y)):
				return false
	return true


# Pose une pièce près d'une cellule (coin bas gauche) : elle glisse vers la place libre et portée la plus proche.
# Renvoie {} si rien ne convient (la pièce reste dans le bac).
# extra : champs d'un morceau scié repris au doigt (coupe, emprise, lot), conservés à la pose
static func poser(a: Dictionary, piece_id: String, cell: Vector2i, miroir := false, extra := {}) -> Dictionary:
	var f := Assemblage.piece(piece_id)
	if f.is_empty() or not f.get("famille", "") in FAMILLES_PIECES:
		return {}
	var e := _emprise(piece_id)
	if extra.has("emprise"):
		e = Vector2i(int(extra.emprise[0]), int(extra.emprise[1]))
	var cands := []
	for dy in range(-4, 5):
		for dx in range(-6, 7):
			cands.append(cell + Vector2i(dx, dy))
	cands.sort_custom(func(p, q): return (p - cell).length_squared() < (q - cell).length_squared())
	var n: int = a.get("pieces", []).size()
	for c in cands:
		var b := a.duplicate(true)
		b.pieces.append({"piece": piece_id, "pos": [c.x, c.y]})
		if miroir:
			b.pieces[n].miroir = true
		for k in extra:
			b.pieces[n][k] = extra[k]
		if _valide(b, {"i": n, "fiche": f, "pos": c, "e": e}):
			return b
	return {}


# Scie une coque posée (DEC-072) à la cellule touchée : sens "v" (trait vertical) ou "h" (horizontal).
# Les deux morceaux restent posés côte à côte ; ils forment un même lot (une seule coque de la réserve). {} si impossible.
static func scier(a: Dictionary, index: int, cell: Vector2i, sens: String) -> Dictionary:
	var ps := _pieces(a)
	if index < 0 or index >= ps.size() or not _coque(ps[index].fiche):
		return {}
	var p: Dictionary = ps[index]
	var g := float(p.coupe[0])
	var d := float(p.coupe[1])
	var bas := float(p.coupe[2])
	var h := float(p.coupe[3])
	var lot := 0
	for q in a.pieces:
		lot = maxi(lot, int(q.get("lot", 0)))
	lot = int(a.pieces[index].get("lot", lot + 1))
	var base: Dictionary = a.pieces[index].duplicate(true)
	base.lot = lot
	var m1 := base.duplicate(true)
	var m2 := base.duplicate(true)
	if sens == "v":
		var k: int = cell.x - int(p.pos.x)
		if k < 1 or k > p.e.x - 1:
			return {}
		var f: float = float(k) / float(p.e.x)
		var u: float = (d - f * (d - g)) if p.miroir else (g + f * (d - g))   # retournée : la gauche à l'écran est la droite de l'image
		m1.coupe = [u, d, bas, h] if p.miroir else [g, u, bas, h]
		m2.coupe = [g, u, bas, h] if p.miroir else [u, d, bas, h]
		m1.emprise = [k, p.e.y]
		m2.emprise = [p.e.x - k, p.e.y]
		m2.pos = [p.pos.x + k, p.pos.y]
	else:
		var k: int = cell.y - int(p.pos.y)
		if k < 1 or k > p.e.y - 1:
			return {}
		var v: float = bas + float(k) / float(p.e.y) * (h - bas)
		m1.coupe = [g, d, bas, v]
		m2.coupe = [g, d, v, h]
		m1.emprise = [p.e.x, k]
		m2.emprise = [p.e.x, p.e.y - k]
		m2.pos = [p.pos.x, p.pos.y + k]
	var b := a.duplicate(true)
	b.pieces[index] = m1
	b.pieces.append(m2)
	return nettoyer(b)


# Nombre de pièces de la réserve utilisées par la grille pour un modèle : les morceaux d'une même coque sciée comptent une fois
static func utilisees(a: Dictionary, id: String) -> int:
	var lots := {}
	var n := 0
	for p in a.get("pieces", []):
		if String(p.piece) != id:
			continue
		if p.has("lot"):
			if lots.has(int(p.lot)):
				continue
			lots[int(p.lot)] = true
		n += 1
	return n


static func retirer(a: Dictionary, index: int) -> Dictionary:
	var b := a.duplicate(true)
	if index >= 0 and index < b.pieces.size():
		b.pieces.remove_at(index)
	return nettoyer(b)


static func piece_en(a: Dictionary, cell: Vector2i, coque_dabord := false) -> int:
	var coq := _occ_coque(a)
	if coque_dabord and coq.has(cell):
		return int(coq[cell])
	var occ := _occupation(a)
	if occ.has(cell) and not (occ[cell] is String):
		return int(occ[cell])
	var hab := _occ_hab(a)   # sinon la carrosserie qui recouvre cette cellule
	if hab.has(cell):
		return int(hab[cell])
	return int(coq[cell]) if coq.has(cell) else -1


# Retire ce qui ne tient plus : essieux sous une colonne vide, pièces qui ne reposent plus sur rien
static func nettoyer(a: Dictionary) -> Dictionary:
	var b := a.duplicate(true)
	b.essieux = b.get("essieux", []).filter(func(e): return y_essieu(b, int(e.x)) >= 0)
	var change := true
	while change:
		change = false
		for p in _pieces(b):
			if not _valide(b, p):
				b.pieces.remove_at(p.i)
				change = true
				break
	return b


# --- Analyse physique --------------------------------------------------------------------------
static func _sorte(a: Dictionary, s: String) -> Dictionary:
	if s == "origine" and a.has("origine"):
		var ch := Assemblage.piece(String(a.origine.chassis))
		var n := maxf(1.0, float(a.origine.n))
		return {"poids_kg": float(ch.poids_kg) / n, "pv": float(ch.pv) / n, "blindage": float(ch.blindage), "metal": float(ch.metal) / n}
	return R().cases.get(s, R().cases.acier)


# Coût en métal de ce qui se fabrique : cases, essieux, trains (les pièces mécaniques viennent de la réserve)
static func cout_metal(a: Dictionary) -> float:
	var t := 0.0
	var cases := _cases(a)
	for c in cases:
		if cases[c] != "origine":
			t += float(_sorte(a, cases[c]).metal)
	for tl in toles_de(a):
		t += float(R().get("toles", {"metal_case": 0.75}).metal_case) * float(tl.long)
	for e in a.get("essieux", []):
		t += float(Assemblage.piece(String(e.piece)).get("metal", 0))
		if String(e.get("train", "")) != "":
			t += float(Assemblage.piece(String(e.train)).get("metal", 0))
	for p in a.get("pieces", []):   # postes, bancs et cabines se fabriquent au métal (DEC-062)
		var f := Assemblage.piece(String(p.piece))
		if bool(f.get("fabrique", false)):
			t += float(f.get("metal", 0))
	return t


static func _defaut(liste: Array, code: String, texte: String, grave := false) -> void:
	liste.append({"code": code, "texte": texte, "grave": grave})


# Défauts qui empêchent de construire (vide = on peut construire, même si le véhicule roule mal)
static func erreurs(a: Dictionary) -> Array:
	var err := []
	if _cases(a).is_empty():
		_defaut(err, "chassis", "Peignez au moins une case de châssis", true)
	if not roles_de(a).has("conducteur") and not remorque(a):
		_defaut(err, "cabine", "Aucun poste de conduite : personne pour conduire", true)
	return err


# Analyse complète : {erreurs, ok, stats, defauts, detail}
static func analyser(a: Dictionary) -> Dictionary:
	var err := erreurs(a)
	if not err.is_empty():
		return {"erreurs": err, "ok": false, "stats": {}, "defauts": err, "detail": {}}
	var RL := R()
	var cases := _cases(a)
	var pieces := _pieces(a)
	var essieux := _essieux(a)
	var defauts := []
	var masses := []   # [m, x, y] en cellules
	var pv := {"chassis": 0.0, "roulement": 0.0, "suspension": 0.0, "moteur": 0.0, "cabine": 0.0}
	var blindage_somme := 0.0
	var metal := 0.0
	var corps_bas := INF
	for c in cases:
		var s := _sorte(a, cases[c])
		masses.append([float(s.poids_kg), c.x + 0.5, c.y + 0.5])
		pv.chassis += float(s.pv)
		blindage_somme += float(s.blindage)
		metal += float(s.metal)
		corps_bas = minf(corps_bas, float(c.y))
	var debattement := 0.0   # moyenne des liaisons (essieu simple : 0,2) ; améliore la précision en roulant
	var blindage_greffes := 0.0   # greffes (DEC-079) : pare-buffle, piques, bidons
	var piques := 0
	var reservoir_plus := 0.0
	var blindage_coques := 0.0   # coques : blindage au prorata des cases de châssis recouvertes (DEC-067)
	for p in pieces:
		masses.append([float(p.fiche.get("poids_kg", 0)) * p.k, p.pos.x + p.e.x * 0.5, p.pos.y + p.e.y * 0.5])
		if _coque(p.fiche):
			pv.chassis += float(p.fiche.get("pv", 0)) * p.k
			var dessous := 0
			for c in cases:
				if c.x >= p.pos.x and c.x < p.pos.x + p.e.x and c.y >= p.pos.y and c.y < p.pos.y + p.e.y:
					dessous += 1
			blindage_coques += float(p.fiche.get("blindage", 0)) * dessous / maxf(1.0, cases.size())
		metal += float(p.fiche.get("metal", 0)) * p.k
		if _greffe(p.fiche):
			pv.chassis += float(p.fiche.get("pv", 0))
			blindage_greffes += float(p.fiche.get("blindage_plus", 0))
			piques += int(p.fiche.get("piques", 0))
			reservoir_plus += float(p.fiche.get("reservoir_plus", 0))
		corps_bas = minf(corps_bas, float(p.pos.y))
	for e in essieux:
		masses.append([float(e.fiche_e.poids_kg) + float(e.fiche_t.poids_kg) + float(e.fiche_l.get("poids_kg", 0)), e.x + 0.5, e.y])
		pv.suspension += float(e.fiche_e.pv) + float(e.fiche_l.get("pv", 0))
		metal += float(e.fiche_l.get("metal", 0))
		debattement += float(e.fiche_l.get("debattement", 0.2))
		pv.roulement += float(e.fiche_t.pv)
		metal += (float(e.fiche_e.metal) + float(e.fiche_t.metal)) * 0.5
	if not essieux.is_empty():
		debattement /= essieux.size()
	for e in ponts_libres(a):
		masses.append([float(Assemblage.piece(String(e.piece)).poids_kg), int(e.x) + 0.5, float(e.get("y", y_essieu(a, int(e.x))))])
		var txt := "sans liaison" if String(e.get("liaison", "")) == "" else "mal relié (liaison trop courte ou trop longue pour %d cm)" % (ecart_pont(a, e) * 25)
		_defaut(defauts, "pont_libre", "Pont rigide %s (colonne %d) : il ne porte rien, reliez-le au châssis (onglet Suspension)" % [txt, int(e.x)], true)
	for e in essieux_nus(a):
		var fe := Assemblage.piece(String(e.piece))
		masses.append([float(fe.poids_kg), int(e.x) + 0.5, float(y_essieu(a, int(e.x)))])
		_defaut(defauts, "sans_roue", "Essieu sans roue (colonne %d) : montez une roue ou une chenille" % int(e.x))
	var plaques := int(a.get("plaques", 0))
	var PL: Dictionary = Assemblage.catalogue().regles.plaque
	var x_avant := 0.0
	for c in cases:
		x_avant = maxf(x_avant, c.x + 1.0)
	if plaques > 0:
		masses.append([plaques * float(PL.poids_kg), x_avant - 0.5, corps_bas + 2.0])
	# Tôles de blindage tracées d'un point à un autre (DEC-080) : une tôle inclinée compte plus épaisse
	var TL: Dictionary = RL.get("toles", {"poids_kg_case": 35, "pv_case": 5, "metal_case": 0.75, "blindage_case": 1.5, "facteur_max": 2.5})
	var blindage_toles := 0.0
	for t in toles_de(a):
		masses.append([float(TL.poids_kg_case) * t.long, t.milieu.x, t.milieu.y])
		pv.chassis += float(TL.pv_case) * t.long
		metal += float(TL.metal_case) * t.long
		blindage_toles += float(TL.blindage_case) * t.long * t.facteur
	var blindage_base := 0.0
	if a.has("base"):   # Grille V2 : renforts, module de plateau et blindage par zones (BaseVehicule) comptent dans la masse et les stats
		var bb := BaseVehicule.bornes_x(a)
		masses.append([BaseVehicule.poids_supplementaire(a), (float(bb.x) + float(bb.y) + 1.0) * 0.5, corps_bas + 1.5])
		blindage_base = float(BaseVehicule.effets_blindage(a).moyenne)
		reservoir_plus += float(BaseVehicule.effets_module(a).reservoir_plus)
	var M := 0.0
	var xg := 0.0
	var yg := 0.0
	for m in masses:
		M += m[0]
		xg += m[0] * m[1]
		yg += m[0] * m[2]
	xg /= maxf(M, 0.001)
	yg /= maxf(M, 0.001)
	# Sol : le point le plus bas, roue ou caisse ; une roue porte si elle est à moins d'un débattement du sol
	var sol := corps_bas
	for e in essieux:
		sol = minf(sol, e.y - e.r)
	# Véhicule penché (DEC-081) : il repose sur le segment de roues qui porte son centre de gravité ;
	# les roues de tailles ou de hauteurs différentes donnent une assiette (pente de la ligne de sol dans le repère du véhicule)
	var assiette := 0.0
	var pivot := Vector2(0.0, sol)   # point de contact du côté arrière du segment porteur (cases)
	var base_sol := func(_x: float) -> float: return sol
	var pts := []   # [x, bas] de chaque roue
	for e in essieux:
		pts.append([float(e.x) + 0.5, float(e.y) - float(e.r)])
	pts.sort_custom(func(p, q): return p[0] < q[0])
	var meilleur := []
	for i in pts.size():
		for j in range(i + 1, pts.size()):
			if pts[j][0] - pts[i][0] < 0.01:
				continue
			var pente_ij: float = (pts[j][1] - pts[i][1]) / (pts[j][0] - pts[i][0])
			var porte: bool = xg >= float(pts[i][0]) - 0.05 and xg <= float(pts[j][0]) + 0.05
			var sous: bool = true
			for q in pts:
				if q[1] < pts[i][1] + pente_ij * (q[0] - pts[i][0]) - 0.001:
					sous = false
					break
			if sous and porte and (meilleur.is_empty() or absf(pente_ij) < absf(float(meilleur[2]))):
				meilleur = [i, j, pente_ij]
	if not meilleur.is_empty() and absf(float(meilleur[2])) > 0.001:
		var pi: Array = pts[int(meilleur[0])]
		assiette = float(meilleur[2])
		pivot = Vector2(pi[0], pi[1])
		var s0: float = pi[1]
		var s1: float = assiette
		var x0p: float = pi[0]
		base_sol = func(x: float) -> float: return s0 + s1 * (x - x0p)
	for e in essieux:
		e.touche = e.y - e.r - float(base_sol.call(float(e.x) + 0.5)) <= TOLERANCE + 0.001
	# Chenilles : il faut au moins deux galets voisins pour tendre une chenille
	var i := 0
	while i < essieux.size():
		if essieux[i].fiche_t.get("type", "") == "chenilles":
			var j := i
			while j + 1 < essieux.size() and essieux[j + 1].fiche_t.get("type", "") == "chenilles":
				j += 1
			for k in range(i, j + 1):
				essieux[k].piste = i if j > i else -1
			if j == i:
				essieux[i].touche = false
				_defaut(defauts, "chenille_seule", "Chenille sur un seul galet : elle ne tient pas")
			i = j + 1
		else:
			essieux[i].piste = -1
			i += 1
	var en_air := essieux.filter(func(e): return not e.touche).size()
	if en_air > 0 and not defauts.any(func(d): return d.code == "chenille_seule"):
		_defaut(defauts, "roue_air", "%d roue%s en l'air : elle%s ne porte%s rien" % [en_air, "s" if en_air > 1 else "", "s" if en_air > 1 else "", "nt" if en_air > 1 else ""])
	# Roues qui se touchent (hors chenille)
	for k in range(essieux.size() - 1):
		var p0: Dictionary = essieux[k]
		var p1: Dictionary = essieux[k + 1]
		if p0.piste >= 0 and p0.piste == p1.piste:
			continue
		if float(p1.x - p0.x) < p0.r + p1.r - 0.01:
			_defaut(defauts, "frottent", "Des roues se touchent : elles frottent et s'usent")
			break
	var garde := (corps_bas - sol) * C
	var vitesse := INF
	var immobile := ""
	var f_vit := 1.0
	var sable := 1.0
	var appuis := essieux.filter(func(e): return e.touche)
	for e in appuis:
		vitesse = minf(vitesse, float(e.fiche_t.vitesse_max))
		sable = minf(sable, float(e.fiche_t.sable))
	if corps_bas - sol <= 0.001:
		if appuis.is_empty():
			immobile = "le châssis repose sur le sol" if essieux.is_empty() else "le châssis touche le sol avant les roues"
		else:
			f_vit *= 0.15
			_defaut(defauts, "traine", "Le châssis frotte le sol : très lent", true)
	elif garde < float(RL.garde_min_m):
		f_vit *= 0.85
		_defaut(defauts, "garde", "Garde au sol faible (%d cm) : on accroche les bosses" % int(round(garde * 100.0)))
	# Assiette : un peu penché passe, très penché se renverse (DEC-081)
	var angle_deg := rad_to_deg(atan(assiette))
	if absf(angle_deg) > 0.5 and immobile == "":
		var INC: Dictionary = RL.get("inclinaison", {"max_deg": 30.0, "vitesse_par_deg": 0.012, "precision_par_deg": 0.008})
		if absf(angle_deg) > float(INC.max_deg):
			immobile = "trop penché (%d°) : il se renverse" % int(round(absf(angle_deg)))
		else:
			f_vit *= maxf(0.4, 1.0 - float(INC.vitesse_par_deg) * absf(angle_deg))
			_defaut(defauts, "penche", "Véhicule penché de %d° (%s) : plus lent, tir moins précis" % [int(round(absf(angle_deg))), "nez en bas" if angle_deg > 0.0 else "nez en haut"])
	# Répartition du poids : poutre rigide sur appuis élastiques égaux
	var charges := []
	var surcharge := 0.0
	if immobile == "":
		if appuis.is_empty():
			immobile = "aucune roue ne touche le sol"
		elif appuis.size() == 1:
			immobile = "un seul essieu au sol : il bascule"
		else:
			var xs: Array = appuis.map(func(e): return e.x + 0.5)
			if xg < float(xs.front()) - 0.05:
				immobile = "il bascule vers l'arrière (centre de gravité derrière les roues)"
			elif xg > float(xs.back()) + 0.05:
				immobile = "il bascule vers l'avant (centre de gravité devant les roues)"
			else:
				var xm := 0.0
				for x in xs:
					xm += x
				xm /= xs.size()
				var S := 0.0
				for x in xs:
					S += (x - xm) * (x - xm)
				var somme := 0.0
				for x in xs:
					var L := maxf(0.0, M * (1.0 / xs.size() + (x - xm) * (xg - xm) / maxf(S, 0.001)))
					charges.append(L)
					somme += L
				for k in charges.size():
					charges[k] = charges[k] * M / maxf(somme, 0.001)
					var e: Dictionary = appuis[k]
					var cap := minf(minf(float(e.fiche_e.charge_kg), float(e.fiche_t.charge_kg)), float(e.fiche_l.get("charge_kg", INF)))
					e.charge = charges[k]
					e.capacite = cap
					surcharge = maxf(surcharge, charges[k] / cap)
				if surcharge > float(RL.surcharge_casse):
					immobile = "un essieu casse sous la charge (×%.1f)" % surcharge
				elif surcharge > 1.0:
					f_vit /= surcharge * surcharge
					_defaut(defauts, "surcharge", "Surcharge ×%.1f sur un essieu : lent, s'use vite" % surcharge)
	# Moteurs
	var puissance := 0.0
	var conso := 0.0
	var sieges := 0
	var ouvert := false
	var n_moteurs := 0
	var phares := 0
	var ch_phares := 0.0
	for p in pieces:
		match p.fiche.get("famille", ""):
			"moteur":
				puissance += float(p.fiche.puissance_ch)
				conso += float(p.fiche.conso)
				pv.moteur += float(p.fiche.pv)
				n_moteurs += 1
			"equipement":
				if p.id == "phares":
					phares += 1
					ch_phares += float(p.fiche.get("puissance_ch", 0))
			"cabine", "poste":
				pv.cabine += float(p.fiche.pv)
	sieges = sieges_de(a)
	var troupes := places_troupes(a) + (int(BaseVehicule.effets_module(a).places_troupes) if a.has("base") else 0)
	ouvert = _sieges_exposes(a)
	# Plusieurs moteurs couplés (DEC-047) : rendement en baisse, consommation qui explose
	if n_moteurs > 1:
		var MM: Dictionary = RL.get("moteurs_multiples", {"rendement": 0.85, "conso_k": 0.6})
		puissance *= pow(float(MM.rendement), n_moteurs - 1)
		conso *= 1.0 + float(MM.conso_k) * pow(n_moteurs - 1, 2)
		_defaut(defauts, "moteurs", "%d moteurs couplés : rendement ×%.2f, consommation ×%.1f" % [n_moteurs,
			pow(float(MM.rendement), n_moteurs - 1), 1.0 + float(MM.conso_k) * pow(n_moteurs - 1, 2)], n_moteurs > 2)
	# Gazogène (DEC-158) : le moteur brûle le gaz de bois ou de charbon ; il perd de la puissance mais consomme peu de carburant.
	# Pour l'instant monté sur tous les moteurs ; la règle « essence seulement » viendra avec les deux carburants (DEC-094).
	var gazo: Array = pieces.filter(func(q): return q.fiche.has("gazogene"))
	var gazogene := not gazo.is_empty() and n_moteurs > 0
	if gazogene:
		var G: Dictionary = gazo[0].fiche.gazogene
		puissance *= float(G.puissance)
		conso *= float(G.conso)
		_defaut(defauts, "gazogene", "Gazogène : puissance ×%.2f, carburant ×%.2f (brûle du bois ou du charbon)" % [float(G.puissance), float(G.conso)], false)
	# Phares (DEC-048) : la dynamo prend un peu de puissance au moteur
	puissance = maxf(0.0, puissance - ch_phares)
	var tonnes := M / 1000.0
	var ch_t := puissance / maxf(tonnes, 0.001)
	var est_remorque := remorque(a)
	if est_remorque:   # remorque (DEC-080) : tirée par un autre véhicule ; un moteur posé dessus n'est qu'un poids mort
		conso = 0.0
		if n_moteurs > 0:
			_defaut(defauts, "remorque_moteur", "Remorque : le moteur ne sert à rien, c'est du poids mort")
		if not pieces.any(func(q): return int(q.fiche.get("timon", 0)) > 0):
			immobile = "pas de timon pour l'atteler (onglet Options)"
	elif immobile == "":
		if puissance <= 0.0:
			immobile = "pas de moteur"
		elif ch_t < float(RL.ch_par_tonne_min):
			immobile = "moteur bien trop faible (%.1f ch/t)" % ch_t
		elif ch_t < float(RL.ch_par_tonne_requis):
			f_vit *= ch_t / float(RL.ch_par_tonne_requis)
			_defaut(defauts, "puissance", "Moteur faible pour le poids (%.0f ch/t) : lent en côte" % ch_t)
	# Radiateur (DEC-080) : obligatoire pour un moteur refroidi par eau, à 2 cases au plus du moteur
	var refr := refroidissement(a)
	if immobile == "" and not est_remorque and int(a.get("v", 1)) >= 2 and not a.has("origine") and float(refr.besoin) > 0.0:
		if float(refr.capacite) <= 0.0:
			immobile = "pas de radiateur : le moteur chauffe et cale" if int(refr.loin) == 0 else "radiateur trop loin du moteur (2 cases au plus)"
		elif float(refr.capacite) < float(refr.besoin):
			f_vit *= maxf(0.4, float(refr.capacite) / float(refr.besoin))
			_defaut(defauts, "radiateur", "Radiateur trop petit (%d ch pour %d ch) : le moteur chauffe, lent" % [int(refr.capacite), int(refr.besoin)])
	if defauts.any(func(d): return d.code == "frottent"):
		f_vit *= 0.5
	# Stabilité : demi-empattement rapporté à la hauteur du centre de gravité
	var precision := 1.0
	var stab := INF
	if immobile == "" and appuis.size() >= 2:
		var h := maxf(0.5, yg - sol)
		stab = minf(xg - (appuis.front().x + 0.5), (appuis.back().x + 0.5) - xg) / h
		if stab < float(RL.stabilite_critique):
			f_vit *= 0.6
			precision *= 0.6
			_defaut(defauts, "instable", "Très instable : se couche dans les virages et au tir", true)
		elif stab < float(RL.stabilite_instable):
			precision *= 0.85
			_defaut(defauts, "instable", "Instable : centre de gravité haut ou trop près d'un essieu")
	# Armes : servies (un servant par arme en plus du conducteur), masquées, recul
	var armes := []
	var f_recul := 1.0
	for w in armes_ordonnees(a):
		if w.masquee:
			_defaut(defauts, "masquee", "%s : tir masqué par une pièce ou le châssis" % w.fiche.nom, true)
		elif not w.servie:
			_defaut(defauts, "servant", "%s : aucun tireur, elle ne tirera pas" % w.fiche.nom, true)
		else:
			armes.append(String(w.fiche.arme))
			var req := float(RL.recul_t.get(String(w.fiche.arme), 0.0))
			if req > 0.0 and tonnes < req:
				f_recul = minf(f_recul, clampf(sqrt(tonnes / req), 0.3, 1.0))
				_defaut(defauts, "recul", "%s : trop lourd pour %.1f t, le recul secoue le véhicule" % [w.fiche.nom, tonnes])
	precision *= f_recul * (0.92 + 0.16 * debattement)
	if absf(angle_deg) > 0.5:
		precision *= maxf(0.5, 1.0 - float(RL.get("inclinaison", {"precision_par_deg": 0.008}).precision_par_deg) * absf(angle_deg))
	for k in pv:
		pv[k] = maxf(1.0, pv[k])
	if immobile != "":
		_defaut(defauts, "immobile", "Ne roule pas : " + immobile, true)
	var classe := ""   # classe Intercepteur (DEC-083) : petite voiture rapide, une arme au plus, à l'arrière
	var IC: Dictionary = RL.get("plateformes", {}).get("intercepteur", {})
	if not IC.is_empty() and immobile == "" and not remorque(a) and essieux.size() == 2 and n_moteurs == 1:
		var arm := _pieces(a).filter(func(p): return p.fiche.get("famille", "") == "arme")
		var xs := cases.keys().map(func(c): return c.x)
		var milieu := (float(xs.min()) + float(xs.max()) + 1.0) * 0.5
		var roues_ok: bool = essieux.all(func(e): return String(e.fiche_t.get("type", "roues")) == "roues")
		var petit: bool = _pieces(a).any(func(p): return p.fiche.get("famille", "") == "moteur" and float(p.fiche.get("puissance_ch", 0)) <= float(IC.puissance_max_ch))
		if roues_ok and petit and M <= float(IC.poids_max_kg) and arm.size() <= 1 and arm.all(func(p): return float(p.pos.x) + p.e.x * 0.5 <= milieu):
			classe = "intercepteur"   # nerveux : chaque ch par tonne au-delà du requis compte, jusqu'à un plafond
			var exces := maxf(0.0, ch_t / float(RL.ch_par_tonne_requis) - 1.0)
			f_vit *= float(IC.bonus_vitesse) + minf(float(IC.bonus_puissance_max), exces * float(IC.bonus_par_exces))
	var v := 0.0 if immobile != "" else vitesse * sable * f_vit
	var roles := roles_de(a)
	var stats := {"blindage": blindage_somme / maxf(1.0, cases.size()) + plaques * float(PL.blindage) + blindage_coques + blindage_greffes + blindage_toles + blindage_base, "remorque": remorque(a),
		"reservoir": float(RL.reservoir_base) + float(RL.reservoir_par_case) * cases.size() + reservoir_plus, "piques": piques, "metal": int(round(metal)),
		"equipage": sieges, "places_troupes": troupes, "ouvert": ouvert, "armes": armes, "conso": conso, "gazogene": gazogene, "pv": pv, "poids_kg": M, "vitesse": v,
		"precision": precision, "immobile": immobile, "phares": phares, "classe": classe, "moteurs": n_moteurs, "roles": roles,
		"chargeurs": roles.count("chargeur"), "chef": roles.has("chef"), "mecaniciens": roles.count("mecanicien"),
		"infirmiers": roles.count("infirmier")}
	if a.has("origine"):
		var ch := Assemblage.piece(String(a.origine.chassis))
		stats.reservoir = maxf(stats.reservoir, float(ch.get("reservoir", 0)))
		if ch.has("standoff"):
			stats.standoff = ch.standoff
	var detail := {"poids_kg": M, "puissance": puissance, "ch_t": ch_t, "cg": Vector2(xg, yg), "sol": sol, "garde_m": garde, "assiette": assiette, "pivot": pivot,
		"essieux": essieux, "stabilite": stab, "surcharge": surcharge, "sable": sable}
	return {"erreurs": [], "ok": true, "stats": stats, "defauts": defauts, "detail": detail}


static func statistiques(a: Dictionary) -> Dictionary:
	return analyser(a).stats


# Armes dans l'ordre du profil de combat : servies d'abord (même ordre pour le dessin et le combat)
static func armes_ordonnees(a: Dictionary) -> Array:
	var occ := _occ_totale(a)
	var tireurs := roles_de(a).count("tireur")
	var res := []
	for p in _pieces(a):
		if p.fiche.get("famille", "") != "arme":
			continue
		var masquee := false
		if String(p.fiche.arme) == "mortier":
			for x in range(p.pos.x, p.pos.x + p.e.x):
				masquee = masquee or occ.has(Vector2i(x, p.pos.y + p.e.y))
		else:
			var y: int = p.pos.y + p.e.y - 1
			masquee = occ.has(Vector2i(p.pos.x + p.e.x, y))
		res.append({"place": p, "fiche": p.fiche, "masquee": masquee, "servie": false})
	# Un tireur sert un canon (ou un mortier) et une mitrailleuse coaxiale, sinon une seule arme (DEC-050)
	var coax := 0
	for w in res:
		if not w.masquee and _gros_calibre(w) and tireurs > 0:
			w.servie = true
			tireurs -= 1
			if String(w.fiche.arme) != "mortier":
				coax += 1
	for w in res:
		if not w.masquee and not _gros_calibre(w):
			if coax > 0:
				w.servie = true
				coax -= 1
			elif tireurs > 0:
				w.servie = true
				tireurs -= 1
	var servies := res.filter(func(w): return w.servie)
	servies.append_array(res.filter(func(w): return not w.servie))
	return servies


static func _gros_calibre(w: Dictionary) -> bool:
	var id := String(w.fiche.arme)
	return id.begins_with("canon") or id == "mortier"


# Sièges d'équipage (hors bancs de troupes), dans l'ordre de pose : [{piece, role, fixe, k}].
# Poste de conduite : conducteur ; poste de commandement : chef ; les autres sièges ont un rôle au choix (a.roles[k]),
# par défaut tireur. Sans poste de conduite, le premier siège libre conduit (anciens véhicules, DEC-062).
static func sieges_equipage(a: Dictionary) -> Array:
	var choix: Array = a.get("roles", [])
	var res := []
	var poste_conduite := false
	for p in _pieces(a):
		poste_conduite = poste_conduite or p.fiche.get("poste", "") == "conduite"
	var k := 0
	for p in _pieces(a):
		var f: Dictionary = p.fiche
		var n := int(f.get("sieges", 0))
		if n <= 0 or f.get("poste", "") == "banc":
			continue
		if f.get("poste", "") == "conduite":
			res.append({"piece": p.i, "role": "conducteur", "fixe": true, "k": -1})
		elif f.get("poste", "") == "commande":
			res.append({"piece": p.i, "role": "chef", "fixe": true, "k": -1})
		else:
			for _s in n:
				var role := "tireur"
				if k < choix.size() and String(choix[k]) in ROLES:
					role = String(choix[k])
				var fixe := false
				if not poste_conduite and k == 0:
					role = "conducteur"
					fixe = true
				res.append({"piece": p.i, "role": role, "fixe": fixe, "k": k})
				k += 1
	return res


static func sieges_de(a: Dictionary) -> int:
	return sieges_equipage(a).size()


static func roles_de(a: Dictionary) -> Array:
	return sieges_equipage(a).map(func(s): return s.role)


# Places des bancs de troupes
static func places_troupes(a: Dictionary) -> int:
	var n := 0
	for p in _pieces(a):
		if p.fiche.get("poste", "") == "banc":
			n += int(p.fiche.sieges)
	return n


# Un siège est à couvert si une carrosserie fermée recouvre toute sa rangée du bas ; sinon l'équipage est exposé
static func _sieges_exposes(a: Dictionary) -> bool:
	var couvert := {}
	var toits := {}   # colonnes coiffées par le toit d'une coque fermée (un morceau scié sans toit n'abrite que sous un toit)
	for p in _pieces(a):
		if _coque(p.fiche) and bool(p.fiche.get("couvert", false)) and float(p.coupe[3]) >= 0.999:
			for x in range(p.pos.x, p.pos.x + p.e.x):
				toits[x] = true
	for p in _pieces(a):
		var coque_ok: bool = _coque(p.fiche) and bool(p.fiche.get("couvert", false))
		if (_habillage(p.fiche) and not bool(p.fiche.get("ouvert", false))) or coque_ok:
			for x in range(p.pos.x, p.pos.x + p.e.x):
				for y in range(p.pos.y, p.pos.y + p.e.y):
					if not coque_ok or toits.has(x):
						couvert[Vector2i(x, y)] = true
	for poly in toles_fermees(a):   # forme fermée par des tôles : abrite ce qu'elle entoure (DEC-080)
		var bb := Rect2(poly[0], Vector2.ZERO)
		for q in poly:
			bb = bb.expand(q)
		for x in range(int(bb.position.x), int(bb.end.x)):
			for y in range(int(bb.position.y), int(bb.end.y)):
				if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), poly):
					couvert[Vector2i(x, y)] = true
	for p in _pieces(a):
		var f: Dictionary = p.fiche
		if _habillage(f) or _coque(f) or int(f.get("sieges", 0)) <= 0:
			continue
		if f.get("famille", "") == "cabine" and not bool(f.get("ouvert", false)):
			continue   # cabine complète fermée
		var ok := true
		for x in range(p.pos.x, p.pos.x + p.e.x):
			ok = ok and couvert.has(Vector2i(x, p.pos.y))
		if not ok:
			return true
	return false


# Nombre de tireurs nécessaires pour servir toutes les armes non masquées
static func tireurs_requis(a: Dictionary) -> int:
	var canons := 0
	var mortiers := 0
	var mg := 0
	for p in _pieces(a):
		if p.fiche.get("famille", "") == "arme":
			if String(p.fiche.arme) == "mortier":
				mortiers += 1
			elif _gros_calibre({"fiche": p.fiche}):
				canons += 1
			else:
				mg += 1
	return canons + mortiers + maxi(0, mg - canons)   # une mitrailleuse coaxiale par canon, pas sur un mortier


# Nom proposé d'après la construction (le joueur peut le changer)
static func nom_propose(a: Dictionary) -> String:
	var an := analyser(a)
	if not an.ok:
		return "Frankenstein"
	var s: Dictionary = an.stats
	var t := float(s.poids_kg) / 1000.0
	var chenilles := false
	for e in _essieux(a):
		chenilles = chenilles or e.fiche_t.get("type", "") == "chenilles"
	var armes: Array = s.armes
	var canon := armes.any(func(w): return String(w).begins_with("canon"))
	var base := ""
	if int(s.moteurs) > 2 or t > 45.0:
		base = "Mastodonte"
	elif chenilles and canon:
		base = "Char lourd" if t > 25.0 else "Char"
	elif chenilles and armes.has("mortier"):
		base = "Porte-mortier chenillé"
	elif chenilles:
		base = "Chenillette" if t < 8.0 else "Porte-chenilles"
	elif canon:
		base = "Auto-canon"
	elif armes.has("mortier"):
		base = "Porte-mortier"
	elif armes.has("lance_flammes"):
		base = "Brûleur"
	elif not armes.is_empty():
		base = "Auto-mitrailleuse" if t < 4.0 else "Camion armé"
	else:
		base = "Éclaireur" if t < 2.0 else "Camion"
	var surnoms := ["la Bricole", "le Rafistolé", "la Ferraille", "le Boiteux", "la Chimère", "le Sanglier", "la Rouille", "le Grognard", "la Teigne", "le Cafard"]
	return "%s « %s »" % [base, surnoms[absi(hash(signature_forme(a))) % surnoms.size()]]


static func signature_forme(a: Dictionary) -> String:
	var b := a.duplicate(true)
	b.nom = ""
	return signature(b)


# --- Conversion d'un véhicule historique (pour ouvrir sa grille) ---------------------------------
static func convertir(a: Dictionary, type: String) -> Dictionary:
	if est_libre(a):
		return a.duplicate(true)
	var b := nouvelle(String(a.get("nom", "")))
	var VD: Dictionary = VehiculeDessin.donnees().vehicules
	var D: Dictionary = VD.get(type, {})
	if D.is_empty() and a.has("chassis"):
		D = VD.get(Assemblage.apparence(a), {})
	b.nom = String(D.get("nom", a.get("nom", "Véhicule")))
	var x0 := 2
	var roues := []   # [{x, train}]
	for r in D.get("roues", []):
		var rr := float(r.r)
		roues.append({"x": x0 + int(floor(float(r.x) / C)), "train": "roue_petite" if rr < 0.31 else ("roue_moyenne" if rr < 0.44 else "roue_grande")})
	if D.has("chenille"):
		for gx in D.chenille.galets:
			roues.append({"x": x0 + int(floor(float(gx) / C)), "train": "chenille"})
	var vues := {}
	var uniques := []
	for r in roues:
		if not vues.has(r.x):
			vues[r.x] = true
			uniques.append(r)
	var poids_hist := Assemblage.poids(a)
	var L := maxi(4, int(ceil(float(D.get("longueur", 4.0)) / C)))
	var y_haut := 0
	for r in uniques:
		y_haut = maxi(y_haut, int(ceil(float(Assemblage.piece(r.train).diametre_cases) * 0.5)))
	var rangs := 1 if poids_hist < 1500.0 else 2
	var cases := []
	for x in range(x0, mini(taille().x, x0 + L)):
		for y in range(y_haut, y_haut + rangs):
			cases.append([x, y, "origine"])
	for r in uniques:   # petites roues : la caisse descend jusqu'à leur essieu
		var yr := int(ceil(float(Assemblage.piece(r.train).diametre_cases) * 0.5))
		for y in range(yr, y_haut):
			cases.append([r.x, y, "origine"])
	b.cases = cases
	b.origine = {"chassis": String(a.get("chassis", "")), "n": cases.size()}
	var charge := poids_hist * 1.15 / maxf(1.0, uniques.size())
	for r in uniques:
		var cap_t := float(Assemblage.piece(r.train).charge_kg)
		var e := "essieu_leger" if charge <= 1200.0 else ("essieu_lourd" if charge <= 5000.0 else "essieu_char")
		var t: String = r.train
		if cap_t < charge and t != "chenille":
			t = "roue_grande"
		b.essieux.append({"x": r.x, "piece": e, "train": t})
	# Pièces mécaniques : même ordre de hauteur qu'à l'origine, posées sur la caisse
	var haut := y_haut + rangs
	var hist := []
	var y_min := 1000
	for p in a.get("pieces", []):
		var f := Assemblage.piece(String(p.piece))
		if f.get("famille", "") in FAMILLES_PIECES and f.has("emprise"):
			hist.append(p)
			y_min = mini(y_min, int(p.pos[1]))
	var ordre := {"cabine": 0, "moteur": 1, "arme": 2}
	hist.sort_custom(func(p, q): return ordre[Assemblage.piece(String(p.piece)).famille] < ordre[Assemblage.piece(String(q.piece)).famille])
	for p in hist:
		var cible := Vector2i(x0 + int(p.pos[0]), haut + int(p.pos[1]) - y_min)
		var c := poser(b, String(p.piece), cible)
		if c.is_empty():
			c = poser(b, String(p.piece), Vector2i(cible.x, haut))
		if not c.is_empty():
			b = c
	b.plaques = int(a.get("plaques", 0))
	# Berliet GDR (DEC-167) : châssis, cabine et sièges, essieu avant fixes ; le reste se personnalise
	if String(a.get("chassis", "")) == "chassis_berliet_gdr":
		# Place derrière le camion pour ajouter des modules et des remorques : on avance le véhicule dans la grille (DEC-167)
		var xmax_c := 0
		for c in b.get("cases", []):
			xmax_c = maxi(xmax_c, int(c[0]))
		for q in b.get("pieces", []):
			xmax_c = maxi(xmax_c, int(q.pos[0]) + int(q.get("emprise", Assemblage.piece(String(q.piece)).get("emprise", [1, 1]))[0]))
		var decal := clampi(taille().x - 3 - xmax_c, 0, 14)
		if decal > 0:
			var bd := deplacer(b, decal, 0)
			if not bd.is_empty():
				b = bd
		var xav := -1
		for e in b.essieux:
			xav = maxi(xav, int(e.x))   # l'avant est à droite : c'est l'essieu le plus à droite
		var fixes := []
		for p in b.pieces:
			if Assemblage.piece(String(p.piece)).get("famille", "") == "cabine":
				fixes.append(String(p.piece))
		b.berliet = {"essieu_av": xav, "fixes": fixes}
	return b


# Berliet (DEC-167) : la pièce, la case ou l'essieu est-il fixe ? (hors mode créatif)
static func fixe_berliet(a: Dictionary, quoi: String, val) -> bool:
	if not a.has("berliet"):
		return false
	match quoi:
		"piece":
			return String(val) in a.berliet.fixes
		"essieu":
			return int(val) == int(a.berliet.essieu_av)
		"cases":   # toutes les cases d'origine doivent rester
			var n := 0
			for c in val:
				if String(c[2]) == "origine":
					n += 1
			return n < int(a.origine.n)
	return false


# --- Dessin (fiche au format de formes_vehicules.json) -------------------------------------------
static func _poly_cercle(cx: float, cy: float, r: float, n := 14) -> Array:
	var pts := []
	for k in n:
		var t := TAU * float(k) / float(n)
		pts.append([cx + r * cos(t), cy + r * sin(t)])
	return pts


static func forme(a: Dictionary, ecorche := false) -> Dictionary:
	var an := analyser(a)
	var cases := _cases(a)
	var essieux: Array = an.detail.get("essieux", _essieux(a))
	var sol: float = an.detail.get("sol", 0.0)
	var x0 := INF
	var x1 := -INF
	var y1 := 0.0
	for c in cases:
		x0 = minf(x0, c.x)
		x1 = maxf(x1, c.x + 1.0)
		y1 = maxf(y1, c.y + 1.0)
	for p in _pieces(a):
		x0 = minf(x0, p.pos.x)
		x1 = maxf(x1, p.pos.x + p.e.x)
		y1 = maxf(y1, p.pos.y + p.e.y)
	for e in essieux:
		x0 = minf(x0, e.x + 0.5 - e.r)
		x1 = maxf(x1, e.x + 0.5 + e.r)
	for t in a.get("toles", []):
		x0 = minf(x0, minf(float(t[0]), float(t[2])))
		x1 = maxf(x1, maxf(float(t[0]), float(t[2])))
		y1 = maxf(y1, maxf(float(t[1]), float(t[3])))
	if x0 == INF:
		x0 = 0.0
		x1 = 4.0
	var X := func(x: float) -> float: return (x - x0) * C
	var Y := func(y: float) -> float: return (y - sol) * C
	var formes := []
	for c in cases:
		if cases[c] == "tube":   # châssis tubulaire : treillis de tubes soudés (DEC-074)
			var xa: float = X.call(c.x)
			var xb: float = X.call(c.x + 1.0)
			var ya: float = Y.call(c.y)
			var yb: float = Y.call(c.y + 1.0)
			for l in [[[xa, ya + 0.02], [xb, ya + 0.02]], [[xa, yb - 0.02], [xb, yb - 0.02]], [[xa, ya], [xb, yb]] if (c.x + c.y) % 2 == 0 else [[xa, yb], [xb, ya]]]:
				formes.append({"ligne": l, "ep": 0.035, "c": "metal", "z": 0})
			continue
		if cases[c] == "poutre":   # poutre en I : âme sombre, semelles claires (DEC-080)
			var pa: float = X.call(c.x)
			var pb: float = X.call(c.x + 1.0)
			var pya: float = Y.call(c.y)
			var pyb: float = Y.call(c.y + 1.0)
			formes.append({"pts": [[pa, pya + 0.07], [pb, pya + 0.07], [pb, pyb - 0.07], [pa, pyb - 0.07]], "c": "sombre", "z": 0})
			formes.append({"pts": [[pa, pya], [pb, pya], [pb, pya + 0.06], [pa, pya + 0.06]], "c": "#5A5A52", "z": 0})
			formes.append({"pts": [[pa, pyb - 0.06], [pb, pyb - 0.06], [pb, pyb], [pa, pyb]], "c": "#5A5A52", "z": 0})
			continue
		var col := "sombre" if cases[c] == "blindage" else "caisse"
		formes.append({"pts": [[X.call(c.x), Y.call(c.y)], [X.call(c.x + 1.0), Y.call(c.y)], [X.call(c.x + 1.0), Y.call(c.y + 1.0)], [X.call(c.x), Y.call(c.y + 1.0)]], "c": col, "z": 0})
	var roues := []
	var chenille := {}
	var pistes := {}
	for e in essieux:
		var cx: float = X.call(e.x + 0.5)
		var r: float = e.r * C
		formes.append({"ligne": [[cx, Y.call(e.y)], [cx, Y.call(e.y) - 0.08]], "ep": 0.06, "c": "metal", "z": 1})
		if not e.fiche_l.is_empty():
			_formes_liaison(formes, String(e.fiche_l.get("dessin", "lames")), cx, Y.call(e.y + e.h), Y.call(e.y), cx < X.call((x0 + x1) * 0.5))
		if e.get("piste", -1) >= 0 and e.get("touche", false):
			if not pistes.has(e.piste):
				pistes[e.piste] = []
			pistes[e.piste].append(cx)
		elif e.get("touche", false):
			roues.append({"x": cx, "r": r, "yb": Y.call(e.y)})
		else:   # roue qui ne repose pas au sol : dessinée à sa vraie hauteur
			formes.append({"pts": _poly_cercle(cx, Y.call(e.y), r), "c": "sombre", "z": 2})
			formes.append({"pts": _poly_cercle(cx, Y.call(e.y), r * 0.45, 8), "c": "metal", "z": 2})
	for e in ponts_libres(a):   # pont pas encore relié : dessiné en l'air, là où il a été placé (DEC-075)
		var cxl: float = X.call(int(e.x) + 0.5)
		var yl: float = Y.call(float(e.get("y", y_essieu(a, int(e.x)))))
		var ftl := Assemblage.piece(String(e.get("train", "")))
		if not ftl.is_empty():
			formes.append({"pts": _poly_cercle(cxl, yl, float(ftl.get("diametre_cases", 2)) * 0.5 * C), "c": "pneu", "z": 2})
			formes.append({"pts": _poly_cercle(cxl, yl, float(ftl.get("diametre_cases", 2)) * 0.22 * C, 10), "c": "metal", "z": 2})
		formes.append({"pts": _poly_cercle(cxl, yl, 0.11, 8), "c": "sombre", "z": 2})
	for k in pistes:
		var gal: Array = pistes[k]
		var rg := 0.375 - 0.08
		if chenille.is_empty():
			chenille = {"barbotin": [gal.back() + 0.25, 0.42, 0.25], "tendeur": [gal.front() - 0.25, 0.38, 0.22],
				"galets": gal, "r_galet": rg, "rouleaux": [], "ep": 0.08}
		else:
			for gx in gal:
				roues.append({"x": gx, "r": 0.375})
	var armes := []
	var equipage := []
	var roles_par_piece := {}   # indice de pièce -> rôles de ses sièges d'équipage
	for sg in sieges_equipage(a):
		if not roles_par_piece.has(sg.piece):
			roles_par_piece[sg.piece] = []
		roles_par_piece[sg.piece].append(sg.role)
	for p in _pieces(a):
		var r := Rect2(X.call(p.pos.x), Y.call(p.pos.y), p.e.x * C, p.e.y * C)
		if _coque(p.fiche):   # au-dessus de tout, sous les armes ; transparente en vue écorchée
			formes.append({"sprite": String(p.fiche.image), "r": [r.position.x, r.position.y, r.size.x, r.size.y], "z": 3,
				"miroir": p.miroir, "opac": OPAC_ECORCHE if ecorche else 1.0,
				"uv": [p.coupe[0], 1.0 - float(p.coupe[3]), p.coupe[1], 1.0 - float(p.coupe[2])]})   # morceau d'image (v vers le bas)
			continue
		if _habillage(p.fiche):
			var st := String(p.fiche.get("style", "voiture"))
			if STYLE_SPRITE.has(st):
				_sprite(formes, STYLE_SPRITE[st], r, 2 if st != "ouverte" else -1)   # la carrosserie recouvre les sièges
			else:
				_formes_cabine(formes, st, r)
			continue
		match p.fiche.get("famille", ""):
			"greffe":
				_formes_greffe(formes, String(p.fiche.get("dessin", "")), r)
			"radiateur":   # cadre et faisceau à ailettes (DEC-080)
				formes.append({"pts": [[r.position.x, r.position.y], [r.end.x, r.position.y], [r.end.x, r.end.y], [r.position.x, r.end.y]], "c": "#2E2C28", "z": 2})
				var nf := maxi(3, int(r.size.x / 0.05))
				for k in nf:
					var fx := r.position.x + 0.04 + (r.size.x - 0.08) * (float(k) + 0.5) / nf
					formes.append({"ligne": [[fx, r.position.y + 0.05], [fx, r.end.y - 0.05]], "ep": 0.018, "c": "#8C867A", "z": 2})
				formes.append({"pts": _poly_cercle(r.position.x + r.size.x * 0.5, r.end.y - 0.03, 0.04, 8), "c": "#8C867A", "z": 2})
			"moteur":
				var surface: int = int(p.e.x) * int(p.e.y)
				if bool(p.fiche.get("a_nu", false)):   # moteur à nu (DEC-083) : bloc en bas, compresseur et pipes qui sortent du capot
					var rb := Rect2(r.position, Vector2(r.size.x, r.size.y * 0.55))
					_sprite(formes, "moteur_leger", rb, 1)
					var yb := rb.end.y
					var w := r.size.x
					var xn := r.position.x
					formes.append({"pts": [[xn + w * 0.2, yb - 0.02], [xn + w * 0.8, yb - 0.02], [xn + w * 0.76, yb + r.size.y * 0.28], [xn + w * 0.24, yb + r.size.y * 0.28]], "c": "#3A3631", "z": 4})
					for k in 4:
						var fx := xn + w * (0.28 + 0.15 * k)
						formes.append({"ligne": [[fx, yb + 0.02], [fx, yb + r.size.y * 0.26]], "ep": 0.02, "c": "#8C867A", "z": 4})
					formes.append({"pts": [[xn + w * 0.42, yb + r.size.y * 0.28], [xn + w * 0.62, yb + r.size.y * 0.28], [xn + w * 0.66, r.end.y], [xn + w * 0.38, r.end.y]], "c": "#B8B2A6", "z": 4})
					formes.append({"pts": _poly_cercle(xn + w * 0.86, yb + r.size.y * 0.12, w * 0.08, 10), "c": "#8C867A", "z": 4})
					for k in 3:
						var py := yb - r.size.y * (0.1 + 0.12 * k)
						formes.append({"ligne": [[xn + w * 0.15, py], [xn - w * 0.25, py - 0.06]], "ep": 0.035, "c": "#B8B2A6", "z": 4})
				else:
					_sprite(formes, "moteur_leger" if surface <= 8 else ("moteur_moyen" if surface <= 18 else "moteur_lourd"), r, 1)
			"cabine":
				var style := String(p.fiche.get("style", "ouverte" if bool(p.fiche.get("ouvert", false)) else "voiture"))
				if STYLE_SPRITE.has(style):
					_sprite(formes, STYLE_SPRITE[style], r, -1 if style == "ouverte" else 2)   # jeep : l'équipage s'assoit dans le visuel
				else:
					_formes_cabine(formes, style, r)
				var n := int(p.fiche.get("sieges", 0))
				for k in n:   # cabine complète d'un véhicule historique : ses sièges sont dedans
					var fx := 0.5 if n == 1 else 0.2 + 0.6 * float(k) / float(n - 1)
					var role := String(roles_par_piece.get(p.i, [])[k]) if roles_par_piece.get(p.i, []).size() > k else "tireur"
					if style == "blindee":   # le chef dépasse de la trappe
						if k == 0:
							equipage.append({"x": r.position.x + r.size.x * 0.5, "y": r.end.y, "role": "chef", "h": 0.26})
					else:
						equipage.append({"x": r.position.x + r.size.x * fx, "y": r.position.y + 0.28, "role": role})
			"poste":
				_formes_poste(formes, p.fiche, r)
				var rl: Array = roles_par_piece.get(p.i, [])
				if p.fiche.get("poste", "") == "banc":
					var sens := float(p.fiche.get("sens", 1))
					for k in int(p.fiche.sieges):
						equipage.append({"x": r.position.x + r.size.x * (0.14 + 0.24 * float(k)), "y": r.position.y + 0.28, "role": "troupe", "dir": sens})
				else:
					var role := String(rl[0]) if not rl.is_empty() else "tireur"
					var haut: bool = p.fiche.get("poste", "") == "commande"
					equipage.append({"x": r.position.x + r.size.x * 0.40, "y": r.position.y + (0.46 if haut else 0.27), "role": role, "h": 0.58 if haut else 0.55})
	for w in armes_ordonnees(a):
		var p: Dictionary = w.place
		var r := Rect2(X.call(p.pos.x), Y.call(p.pos.y), p.e.x * C, p.e.y * C)
		var wid := String(p.fiche.arme)
		if wid == "mortier":
			var rs := _rect_sprite("arme_mortier", r, false)
			armes.append({"type": "mortier", "x": rs[0] + rs[2] * 0.5, "y": rs[1], "long": rs[3] * 1.15, "ep": 0.1, "sprite": "arme_mortier", "r": rs,
				"bout": [rs[0] + rs[2] * 0.3, rs[1] + rs[3]]})
		elif wid.begins_with("mitrailleuse") or wid == "lance_flammes":
			var sid := "arme_lance_flammes" if wid == "lance_flammes" else "arme_mitrailleuse"
			var rs := _rect_sprite(sid, r, false)
			armes.append({"type": "mitrailleuse", "x": r.position.x + 0.2, "y": r.position.y, "pied": maxf(0.12, r.size.y - 0.1), "long": maxf(1.0, r.size.x * 1.2), "ep": 0.05,
				"sprite": sid, "r": rs, "bout": [rs[0] + rs[2], rs[1] + rs[3] * 0.62]})
		else:
			var sid := "arme_canon_37" if wid.contains("leger") else ("arme_canon_88" if wid.contains("88") else "arme_canon_75")
			var rs := _rect_sprite(sid, r, false)
			armes.append({"type": "canon", "x": r.position.x, "y": rs[1] + rs[3] * 0.55, "long": rs[2], "ep": 0.1, "frein": false,
				"sprite": sid, "r": rs, "bout": [rs[0] + rs[2], rs[1] + rs[3] * 0.55]})
	var plaques := int(a.get("plaques", 0))
	for k in plaques:
		formes.append({"ligne": [[X.call(x1) - 0.05 - 0.07 * k, Y.call(sol + 1.0)], [X.call(x1) - 0.05 - 0.07 * k, Y.call(sol + 4.0)]], "ep": 0.05, "c": "metal", "z": 2})
	var M: float = an.stats.get("poids_kg", 1000.0) if an.ok else 1000.0
	var moteur := ("char" if M > 20000.0 else "char_leger") if not chenille.is_empty() else ("voiture" if M < 1800.0 else "camion")
	for p in _pieces(a):
		if p.id == "phares":
			var rp := Rect2(X.call(p.pos.x), Y.call(p.pos.y), p.e.x * C, p.e.y * C)
			_sprite(formes, "phares", rp, 2, false)
	# Tôles (DEC-080) : une forme fermée prend l'aspect d'une caisse blindée rivetée ; transparente en vue écorchée
	var XY := func(q: Vector2) -> Array: return [X.call(q.x), Y.call(q.y)]
	for poly in toles_fermees(a):
		var fond := "#4C5236" if String(a.get("peinture", "")) == "" else "#" + Color(String(a.peinture)).darkened(0.3).to_html(false)
		formes.append({"pts": Array(poly).map(func(q): return XY.call(q)), "c": fond + ("55" if ecorche else ""), "z": 3})
		var ctr := Vector2.ZERO
		for q in poly:
			ctr += q
		ctr /= poly.size()
		for i in poly.size():
			var qa: Vector2 = poly[i]
			var qb: Vector2 = poly[(i + 1) % poly.size()]
			var n := maxi(1, int(qa.distance_to(qb) * 1.5))
			for k in n:   # rivets le long du bord, un peu à l'intérieur
				var q := qa.lerp(qb, (float(k) + 0.5) / n)
				q = q.lerp(ctr, 0.18 / maxf(0.5, q.distance_to(ctr)))
				formes.append({"pts": _poly_cercle(X.call(q.x), Y.call(q.y), 0.022, 6), "c": "#9A9A88" + ("55" if ecorche else ""), "z": 3})
	for t in toles_de(a):
		formes.append({"ligne": [XY.call(t.a), XY.call(t.b)], "ep": 0.06, "c": "#3A3F2C", "z": 3})
	var res := {"x0": x0, "sol": sol, "nom": String(a.get("nom", "Frankenstein")), "longueur": maxf(0.5, (x1 - x0) * C), "hauteur": maxf(0.5, (y1 - sol) * C),
		"teinte": "joueur", "moteur": moteur, "course": 0.09, "fiche": "Véhicule construit sur la grille.",
		"roues": roues, "formes": formes, "armes": armes, "equipage": equipage, "libre": true}
	if chenille.is_empty() and absf(float(an.detail.get("assiette", 0.0))) > 0.0005:   # véhicule penché (DEC-081)
		res.assiette = float(an.detail.assiette)
		res.pivot = [X.call(an.detail.pivot.x), Y.call(an.detail.pivot.y)]
	if String(a.get("peinture", "")) != "":   # peinture de bande (DEC-080) : ton de tout le véhicule
		res.peinture = String(a.peinture)
	if remorque(a):
		res.remorque = true
	if not chenille.is_empty():
		res.chenille = chenille
	if a.has("base"):   # base véhicule (Grille V2) : visuels étirés par la rallonge
		res = BaseVehicule.habiller(a, res)
	return res


# --- Visuels dessinés (planches ChatGPT, DEC-066) ------------------------------------------------
const STYLE_SPRITE := {"camion": "cabine_camion", "voiture": "cabine_berline", "blindee": "cabine_blindee", "ouverte": "cabine_jeep"}


# Rectangle [x, y_bas, l, h] d'un visuel dans la pièce r : remplit la pièce si les proportions sont proches, sinon contenu (centré, posé en bas)
static func _rect_sprite(id: String, r: Rect2, remplir: bool) -> Array:
	var t: Texture2D = VehiculeDessin._tex(id)
	var k := t.get_size().x / t.get_size().y
	var w := r.size.x
	var h := r.size.y
	if not remplir or absf(k / (w / h) - 1.0) > 0.35:
		if w / h > k:
			w = h * k
		else:
			h = w / k
	return [r.position.x + (r.size.x - w) * 0.5, r.position.y, w, h]


static func _sprite(formes: Array, id: String, r: Rect2, z: int, remplir := true) -> void:
	formes.append({"sprite": id, "r": _rect_sprite(id, r, remplir), "z": z})


# Liaison d'un pont rigide (DEC-070) : y_ch = dessous du châssis, y_p = centre du pont (m) ; vers_c = le centre du véhicule est à droite
static func _formes_liaison(formes: Array, dessin: String, cx: float, y_ch: float, y_p: float, vers_c: bool) -> void:
	var s := 1.0 if vers_c else -1.0
	formes.append({"pts": _poly_cercle(cx, y_p, 0.11, 8), "c": "sombre", "z": 1})   # carter du pont
	match dessin:
		"lames":   # paquet de lames sous le châssis, jumelles aux extrémités
			for k in 3:
				var yk := y_p + 0.05 + k * 0.035
				formes.append({"ligne": [[cx - 0.55, y_ch - 0.02], [cx, yk]], "ep": 0.03, "c": "metal", "z": 1})
				formes.append({"ligne": [[cx, yk], [cx + 0.55, y_ch - 0.02]], "ep": 0.03, "c": "metal", "z": 1})
		_:   # tirants vers le centre du véhicule, ressort hélicoïdal et amortisseur
			var long := 0.9 if dessin == "tirants" else 1.4
			formes.append({"ligne": [[cx, y_p], [cx + s * long, y_ch]], "ep": 0.05, "c": "metal", "z": 1})
			formes.append({"ligne": [[cx, y_p - 0.06], [cx + s * long * 0.8, y_ch - 0.04]], "ep": 0.035, "c": "metal", "z": 1})
			var n := 7 if dessin == "tirants" else 11
			var xr := cx - s * 0.12
			for k in n:
				var ya := lerpf(y_p, y_ch, float(k) / n)
				var yb := lerpf(y_p, y_ch, float(k + 1) / n)
				formes.append({"ligne": [[xr - 0.07, ya], [xr + 0.07, yb]], "ep": 0.03, "c": "#8A4A2A", "z": 1})
			if dessin == "rehausse":
				formes.append({"ligne": [[cx + s * 0.14, y_p], [cx + s * 0.22, y_ch]], "ep": 0.045, "c": "sombre", "z": 1})


# Greffes (DEC-079) : formes dessinées dans le rectangle r de la pièce (mètres, y vers le haut)
static func _formes_greffe(formes: Array, dessin: String, r: Rect2) -> void:
	var x0 := r.position.x
	var y0 := r.position.y
	var w := r.size.x
	var h := r.size.y
	match dessin:
		"pare_buffle":   # cadre de barres, plus incliné vers l'avant
			formes.append({"ligne": [[x0 + w * 0.1, y0 + h * 0.05], [x0 + w * 0.9, y0 + h * 0.25]], "ep": 0.07, "c": "#B9B2A0", "z": 3})
			formes.append({"ligne": [[x0 + w * 0.1, y0 + h * 0.95], [x0 + w * 0.9, y0 + h * 0.75]], "ep": 0.07, "c": "#B9B2A0", "z": 3})
			formes.append({"ligne": [[x0 + w * 0.9, y0 + h * 0.25], [x0 + w * 0.9, y0 + h * 0.75]], "ep": 0.08, "c": "#B9B2A0", "z": 3})
			formes.append({"ligne": [[x0 + w * 0.5, y0 + h * 0.15], [x0 + w * 0.5, y0 + h * 0.85]], "ep": 0.04, "c": "sombre", "z": 3})
		"piques":   # rangée de pointes
			var n := maxi(2, int(round(w / 0.17)))
			formes.append({"ligne": [[x0, y0 + 0.03], [x0 + w, y0 + 0.03]], "ep": 0.05, "c": "sombre", "z": 3})
			for k in n:
				var cx := x0 + (float(k) + 0.5) * w / n
				formes.append({"pts": [[cx - 0.05, y0 + 0.05], [cx + 0.05, y0 + 0.05], [cx, y0 + h * 0.95]], "c": "#B9B2A0", "z": 3})
		"bidons":   # deux jerrycans
			for k in 2:
				var bx := x0 + w * (0.06 + 0.46 * k)
				var bw := w * 0.42
				formes.append({"pts": [[bx, y0], [bx + bw, y0], [bx + bw, y0 + h * 0.8], [bx + bw * 0.7, y0 + h * 0.95], [bx, y0 + h * 0.95]], "c": "#6E7038" if k == 0 else "#8A4A2A", "z": 3})
				formes.append({"ligne": [[bx + bw * 0.15, y0 + h * 0.5], [bx + bw * 0.85, y0 + h * 0.5]], "ep": 0.02, "c": "sombre", "z": 3})
		"timon":   # barre triangulée et anneau d'attelage
			formes.append({"ligne": [[x0, y0 + h * 0.9], [x0 + w * 0.92, y0 + h * 0.4]], "ep": 0.05, "c": "#B9B2A0", "z": 3})
			formes.append({"ligne": [[x0, y0 + h * 0.1], [x0 + w * 0.92, y0 + h * 0.4]], "ep": 0.05, "c": "#B9B2A0", "z": 3})
			formes.append({"pts": _poly_cercle(x0 + w * 0.95, y0 + h * 0.4, 0.06, 8), "c": "sombre", "z": 3})
		"gazogene":   # cuve cylindrique du gazogène, couvercle, tuyau et filtre (DEC-158)
			formes.append({"pts": [[x0 + w * 0.08, y0], [x0 + w * 0.62, y0], [x0 + w * 0.62, y0 + h * 0.88], [x0 + w * 0.08, y0 + h * 0.88]], "c": "#4A4A44", "z": 3})
			formes.append({"pts": [[x0 + w * 0.02, y0 + h * 0.88], [x0 + w * 0.68, y0 + h * 0.88], [x0 + w * 0.6, y0 + h], [x0 + w * 0.1, y0 + h]], "c": "#2E2E2A", "z": 3})
			for k in 3:
				formes.append({"ligne": [[x0 + w * 0.08, y0 + h * (0.25 + 0.22 * k)], [x0 + w * 0.62, y0 + h * (0.25 + 0.22 * k)]], "ep": 0.02, "c": "#7A3A1E", "z": 3})
			formes.append({"ligne": [[x0 + w * 0.62, y0 + h * 0.7], [x0 + w * 0.95, y0 + h * 0.7], [x0 + w * 0.95, y0 + h * 0.15]], "ep": 0.05, "c": "#8A8A80", "z": 3})
			formes.append({"pts": [[x0 + w * 0.78, y0], [x0 + w * 1.0, y0], [x0 + w * 1.0, y0 + h * 0.3], [x0 + w * 0.78, y0 + h * 0.3]], "c": "#6A5238", "z": 3})
		"drapeau":   # mât et fanion
			formes.append({"ligne": [[x0 + w * 0.2, y0], [x0 + w * 0.2, y0 + h]], "ep": 0.03, "c": "#B9B2A0", "z": 3})
			formes.append({"pts": [[x0 + w * 0.2, y0 + h], [x0 + w * 1.0, y0 + h * 0.82], [x0 + w * 0.2, y0 + h * 0.62]], "c": "#9A2F2F", "z": 3})


# --- Formes simples des cabines et des postes (DEC-062) -----------------------------------------
static func _pt(r: Rect2, fx: float, fy: float) -> Array:   # fraction de la pièce -> mètres (y vers le haut)
	return [r.position.x + fx * r.size.x, r.position.y + fy * r.size.y]


static func _poly(r: Rect2, pts: Array) -> Array:
	return pts.map(func(q): return _pt(r, q[0], q[1]))


# Cadre autour d'une ouverture : une bande par côté entre le contour et l'ouverture (même nombre de sommets)
static func _cadre(formes: Array, ext: Array, int_: Array, couleur: String) -> void:
	for i in ext.size():
		var j := (i + 1) % ext.size()
		formes.append({"pts": [ext[i], ext[j], int_[j], int_[i]], "c": couleur, "z": 1})


# Cabine vue de profil, tournée vers la droite. Le fond sombre passe derrière l'équipage (z -1), la vitre
# (z 2) est translucide : on voit les occupants à travers. Styles : camion, voiture, blindee, bricolee, ouverte.
static func _formes_cabine(formes: Array, style: String, r: Rect2) -> void:
	var vitre := "#2E3A40B8"
	var bas := []
	var ext := []
	var inte := []
	var fond := []
	match style:
		"camion":
			bas = [[0, 0], [1, 0], [1, 0.36], [0, 0.36]]
			ext = [[0.0, 0.36], [1.0, 0.36], [0.90, 1.0], [0.02, 1.0], [0.0, 0.94]]
			inte = [[0.10, 0.42], [0.92, 0.42], [0.85, 0.88], [0.10, 0.88], [0.10, 0.88]]
			fond = [[0, 0], [1, 0], [1, 0.36], [0.90, 1.0], [0.02, 1.0], [0, 0.94]]
		"voiture":
			bas = [[0, 0], [1, 0], [1, 0.30], [0.92, 0.40], [0.0, 0.40], [0.0, 0.12]]
			ext = [[0.14, 0.40], [0.72, 0.40], [0.54, 0.92], [0.28, 0.92]]
			inte = [[0.19, 0.44], [0.67, 0.44], [0.52, 0.86], [0.30, 0.86]]
			fond = [[0, 0], [1, 0], [1, 0.30], [0.92, 0.40], [0.72, 0.40], [0.54, 0.92], [0.28, 0.92], [0.14, 0.40], [0.0, 0.40]]
		"blindee":
			bas = [[0, 0], [1, 0], [1, 0.45], [0, 0.45]]
			ext = [[0.0, 0.45], [1.0, 0.45], [0.84, 0.88], [0.12, 0.96], [0.0, 0.80]]
			inte = [[0.22, 0.62], [0.80, 0.62], [0.76, 0.70], [0.24, 0.74], [0.22, 0.72]]
			fond = [[0, 0], [1, 0], [1, 0.45], [0.84, 0.88], [0.12, 0.96], [0.0, 0.80]]
			formes.append({"pts": _poly(r, [[0.40, 0.92], [0.62, 0.89], [0.60, 1.0], [0.42, 1.0]]), "c": "metal", "z": 2})
		"bricolee":
			bas = [[0, 0], [1, 0], [1, 0.30], [0, 0.30]]
			ext = [[0.0, 0.30], [1.0, 0.30], [0.95, 0.76], [0.80, 1.0], [0.12, 0.92], [0.0, 0.70]]
			inte = [[0.12, 0.38], [0.82, 0.38], [0.84, 0.68], [0.74, 0.84], [0.18, 0.80], [0.12, 0.70]]
			fond = [[0, 0], [1, 0], [1, 0.30], [0.95, 0.76], [0.80, 1.0], [0.12, 0.92], [0.0, 0.70]]
			formes.append({"ligne": [_pt(r, 0.10, 0.95), _pt(r, 0.10, 1.2), _pt(r, 0.86, 1.2), _pt(r, 0.86, 0.95)], "ep": 0.03, "c": "metal", "z": 2})
			formes.append({"ligne": [_pt(r, 0.45, 0.30), _pt(r, 0.45, 0.0)], "ep": 0.02, "c": "metal", "z": 2})
		_:   # ouverte : portière basse et cadre de pare-brise
			bas = [[0, 0], [1, 0], [1, 0.45], [0, 0.45]]
			ext = [[0.82, 0.45], [0.98, 0.45], [0.88, 1.0], [0.80, 1.0]]
			inte = [[0.85, 0.52], [0.94, 0.52], [0.86, 0.94], [0.83, 0.94]]
	if not fond.is_empty():
		formes.append({"pts": _poly(r, fond), "c": "sombre", "z": -1})
	formes.append({"pts": _poly(r, bas), "c": "caisse", "z": 1})
	if not ext.is_empty():
		var E := _poly(r, ext)
		var I := _poly(r, inte)
		_cadre(formes, E, I, "caisse")
		formes.append({"pts": I, "c": vitre, "z": 2})
	if style == "camion" or style == "voiture":
		var fx := 0.46 if style == "camion" else 0.44
		formes.append({"ligne": [_pt(r, fx, 0.36 if style == "camion" else 0.40), _pt(r, fx, 0.04)], "ep": 0.02, "c": "sombre", "z": 2})
		formes.append({"ligne": [_pt(r, fx + 0.08, 0.30), _pt(r, fx + 0.14, 0.30)], "ep": 0.025, "c": "metal", "z": 2})


# Postes : siège, volant, banc (formes simples, tournées vers la droite ; le banc arrière est inversé)
static func _formes_poste(formes: Array, f: Dictionary, r: Rect2) -> void:
	var w := r.size.x
	var X := func(fx: float) -> float: return r.position.x + fx * w
	var Y := func(m: float) -> float: return r.position.y + m
	match String(f.get("poste", "")):
		"banc":
			var sens := float(f.get("sens", 1))
			var dos := 0.0 if sens > 0.0 else 1.0
			formes.append({"pts": [[X.call(0.02), Y.call(0.20)], [X.call(0.98), Y.call(0.20)], [X.call(0.98), Y.call(0.27)], [X.call(0.02), Y.call(0.27)]], "c": "bois", "z": 2})
			for fx in [0.10, 0.90]:
				formes.append({"ligne": [[X.call(fx), Y.call(0.20)], [X.call(fx), Y.call(0.0)]], "ep": 0.03, "c": "metal", "z": 2})
			formes.append({"ligne": [[X.call(dos), Y.call(0.27)], [X.call(dos), Y.call(0.50)]], "ep": 0.04, "c": "bois", "z": 2})
		"commande":
			formes.append({"ligne": [[X.call(0.40), Y.call(0.0)], [X.call(0.40), Y.call(0.38)]], "ep": 0.05, "c": "metal", "z": 2})
			formes.append({"pts": [[X.call(0.08), Y.call(0.38)], [X.call(0.72), Y.call(0.38)], [X.call(0.72), Y.call(0.45)], [X.call(0.08), Y.call(0.45)]], "c": "sombre", "z": 2})
			formes.append({"pts": [[X.call(0.04), Y.call(0.45)], [X.call(0.18), Y.call(0.45)], [X.call(0.14), Y.call(0.74)], [X.call(0.02), Y.call(0.74)]], "c": "sombre", "z": 2})
			formes.append({"ligne": [[X.call(0.84), Y.call(0.40)], [X.call(0.84), Y.call(0.80)]], "ep": 0.03, "c": "metal", "z": 2})   # périscope
			formes.append({"ligne": [[X.call(0.80), Y.call(0.80)], [X.call(0.96), Y.call(0.80)]], "ep": 0.04, "c": "metal", "z": 2})
		_:
			formes.append({"ligne": [[X.call(0.40), Y.call(0.0)], [X.call(0.40), Y.call(0.19)]], "ep": 0.05, "c": "metal", "z": 2})
			formes.append({"pts": [[X.call(0.08), Y.call(0.19)], [X.call(0.72), Y.call(0.19)], [X.call(0.72), Y.call(0.26)], [X.call(0.08), Y.call(0.26)]], "c": "sombre", "z": 2})
			formes.append({"pts": [[X.call(0.04), Y.call(0.26)], [X.call(0.18), Y.call(0.26)], [X.call(0.14), Y.call(0.50)], [X.call(0.02), Y.call(0.50)]], "c": "sombre", "z": 2})
			if String(f.get("poste", "")) == "conduite":   # tableau de bord et volant
				formes.append({"pts": [[X.call(0.80), Y.call(0.10)], [X.call(1.0), Y.call(0.10)], [X.call(1.0), Y.call(0.38)], [X.call(0.86), Y.call(0.38)]], "c": "metal", "z": 2})
				formes.append({"ligne": [[X.call(0.82), Y.call(0.36)], [X.call(0.66), Y.call(0.46)]], "ep": 0.03, "c": "metal", "z": 2})


static func signature(a: Dictionary) -> String:
	var cs := []
	for c in a.get("cases", []):
		cs.append("%d,%d,%s" % [int(c[0]), int(c[1]), String(c[2]) if c.size() > 2 else "acier"])
	cs.sort()
	var es := []
	for e in a.get("essieux", []):
		es.append("%d:%s:%s" % [int(e.x), e.piece, e.get("train", "")])
	es.sort()
	var ps := []
	for p in a.get("pieces", []):
		ps.append("%s@%d,%d" % [p.piece, int(p.pos[0]), int(p.pos[1])])
	ps.sort()
	return "L|%s|%s|%s|%s|%d|%s" % [a.get("nom", ""), ";".join(cs), ";".join(es), ";".join(ps), int(a.get("plaques", 0)), String(a.get("origine", {}).get("chassis", ""))]
