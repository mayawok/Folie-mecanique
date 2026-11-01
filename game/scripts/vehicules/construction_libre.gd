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
const FAMILLES_PIECES := ["moteur", "poste", "cabine", "arme", "equipement"]
const ROLES := ["tireur", "chargeur", "chef", "mecanicien", "infirmier", "passager"]   # le siège 1 est le conducteur (DEC-050)


static func R() -> Dictionary:
	return Assemblage.catalogue().regles.libre


static func taille() -> Vector2i:
	var g: Array = R().grille
	return Vector2i(int(g[0]), int(g[1]))


static func est_libre(a: Dictionary) -> bool:
	return bool(a.get("libre", false))


static func nouvelle(nom := "Frankenstein") -> Dictionary:
	return {"libre": true, "nom": nom, "cases": [], "essieux": [], "pieces": [], "plaques": 0}


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
		res.append({"i": i, "id": String(p.piece), "fiche": Assemblage.piece(String(p.piece)),
			"pos": Vector2i(int(p.pos[0]), int(p.pos[1])), "e": _emprise(String(p.piece))})
		i += 1
	return res


static func _habillage(fiche: Dictionary) -> bool:   # carrosserie : posée au-dessus des sièges, sans les remplacer (DEC-062)
	return bool(fiche.get("habillage", false))


static func _siege(fiche: Dictionary) -> bool:
	return int(fiche.get("sieges", 0)) > 0


static func _occupation(a: Dictionary, sauf := -1) -> Dictionary:   # cellule -> "case" | indice de pièce (hors carrosseries)
	var occ := {}
	for c in _cases(a):
		occ[c] = "case"
	for p in _pieces(a):
		if p.i == sauf or _habillage(p.fiche):
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
		return _portee(_union(occ, hab), p.pos, p.e)
	var libre := _libre(occ, p.pos, p.e)
	if libre and not _siege(p.fiche):
		for x in range(p.pos.x, p.pos.x + p.e.x):
			for y in range(p.pos.y, p.pos.y + p.e.y):
				if hab.has(Vector2i(x, y)):
					libre = false
	return libre and _portee(_union(occ, hab), p.pos, p.e)


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
		res.append({"x": x, "piece": String(e.piece), "train": String(e.train), "y": float(y_essieu(a, x)),
			"r": float(ft.get("diametre_cases", 2)) * 0.5, "fiche_e": Assemblage.piece(String(e.piece)), "fiche_t": ft})
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
static func poser_essieu(a: Dictionary, x: int, essieu_id: String, train_id: String) -> Dictionary:
	if y_essieu(a, x) < 0:
		return {}
	var b := retirer_essieu(a, x)
	b.essieux.append({"x": x, "piece": essieu_id, "train": train_id})
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
static func poser(a: Dictionary, piece_id: String, cell: Vector2i) -> Dictionary:
	var f := Assemblage.piece(piece_id)
	if f.is_empty() or not f.get("famille", "") in FAMILLES_PIECES:
		return {}
	var e := _emprise(piece_id)
	var cands := []
	for dy in range(-4, 5):
		for dx in range(-6, 7):
			cands.append(cell + Vector2i(dx, dy))
	cands.sort_custom(func(p, q): return (p - cell).length_squared() < (q - cell).length_squared())
	var n: int = a.get("pieces", []).size()
	for c in cands:
		var b := a.duplicate(true)
		b.pieces.append({"piece": piece_id, "pos": [c.x, c.y]})
		if _valide(b, {"i": n, "fiche": f, "pos": c, "e": e}):
			return b
	return {}


static func retirer(a: Dictionary, index: int) -> Dictionary:
	var b := a.duplicate(true)
	if index >= 0 and index < b.pieces.size():
		b.pieces.remove_at(index)
	return nettoyer(b)


static func piece_en(a: Dictionary, cell: Vector2i) -> int:
	var occ := _occupation(a)
	if occ.has(cell) and not (occ[cell] is String):
		return int(occ[cell])
	var hab := _occ_hab(a)   # sinon la carrosserie qui recouvre cette cellule
	return int(hab[cell]) if hab.has(cell) else -1


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
	if not roles_de(a).has("conducteur"):
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
	for p in pieces:
		masses.append([float(p.fiche.get("poids_kg", 0)), p.pos.x + p.e.x * 0.5, p.pos.y + p.e.y * 0.5])
		metal += float(p.fiche.get("metal", 0))
		corps_bas = minf(corps_bas, float(p.pos.y))
	for e in essieux:
		masses.append([float(e.fiche_e.poids_kg) + float(e.fiche_t.poids_kg), e.x + 0.5, e.y])
		pv.suspension += float(e.fiche_e.pv)
		pv.roulement += float(e.fiche_t.pv)
		metal += (float(e.fiche_e.metal) + float(e.fiche_t.metal)) * 0.5
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
	for e in essieux:
		e.touche = e.y - e.r - sol <= TOLERANCE + 0.001
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
					var cap := minf(float(e.fiche_e.charge_kg), float(e.fiche_t.charge_kg))
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
	var troupes := places_troupes(a)
	ouvert = _sieges_exposes(a)
	# Plusieurs moteurs couplés (DEC-047) : rendement en baisse, consommation qui explose
	if n_moteurs > 1:
		var MM: Dictionary = RL.get("moteurs_multiples", {"rendement": 0.85, "conso_k": 0.6})
		puissance *= pow(float(MM.rendement), n_moteurs - 1)
		conso *= 1.0 + float(MM.conso_k) * pow(n_moteurs - 1, 2)
		_defaut(defauts, "moteurs", "%d moteurs couplés : rendement ×%.2f, consommation ×%.1f" % [n_moteurs,
			pow(float(MM.rendement), n_moteurs - 1), 1.0 + float(MM.conso_k) * pow(n_moteurs - 1, 2)], n_moteurs > 2)
	# Phares (DEC-048) : la dynamo prend un peu de puissance au moteur
	puissance = maxf(0.0, puissance - ch_phares)
	var tonnes := M / 1000.0
	var ch_t := puissance / maxf(tonnes, 0.001)
	if immobile == "":
		if puissance <= 0.0:
			immobile = "pas de moteur"
		elif ch_t < float(RL.ch_par_tonne_min):
			immobile = "moteur bien trop faible (%.1f ch/t)" % ch_t
		elif ch_t < float(RL.ch_par_tonne_requis):
			f_vit *= ch_t / float(RL.ch_par_tonne_requis)
			_defaut(defauts, "puissance", "Moteur faible pour le poids (%.0f ch/t) : lent en côte" % ch_t)
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
	precision *= f_recul
	for k in pv:
		pv[k] = maxf(1.0, pv[k])
	if immobile != "":
		_defaut(defauts, "immobile", "Ne roule pas : " + immobile, true)
	var v := 0.0 if immobile != "" else vitesse * sable * f_vit
	var roles := roles_de(a)
	var stats := {"blindage": blindage_somme / maxf(1.0, cases.size()) + plaques * float(PL.blindage),
		"reservoir": float(RL.reservoir_base) + float(RL.reservoir_par_case) * cases.size(), "metal": int(round(metal)),
		"equipage": sieges, "places_troupes": troupes, "ouvert": ouvert, "armes": armes, "conso": conso, "pv": pv, "poids_kg": M, "vitesse": v,
		"precision": precision, "immobile": immobile, "phares": phares, "moteurs": n_moteurs, "roles": roles,
		"chargeurs": roles.count("chargeur"), "chef": roles.has("chef"), "mecaniciens": roles.count("mecanicien"),
		"infirmiers": roles.count("infirmier")}
	if a.has("origine"):
		var ch := Assemblage.piece(String(a.origine.chassis))
		stats.reservoir = maxf(stats.reservoir, float(ch.get("reservoir", 0)))
		if ch.has("standoff"):
			stats.standoff = ch.standoff
	var detail := {"poids_kg": M, "puissance": puissance, "ch_t": ch_t, "cg": Vector2(xg, yg), "sol": sol, "garde_m": garde,
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
	for p in _pieces(a):
		if _habillage(p.fiche) and not bool(p.fiche.get("ouvert", false)):
			for x in range(p.pos.x, p.pos.x + p.e.x):
				for y in range(p.pos.y, p.pos.y + p.e.y):
					couvert[Vector2i(x, y)] = true
	for p in _pieces(a):
		var f: Dictionary = p.fiche
		if _habillage(f) or int(f.get("sieges", 0)) <= 0:
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
	return b


# --- Dessin (fiche au format de formes_vehicules.json) -------------------------------------------
static func _poly_cercle(cx: float, cy: float, r: float, n := 14) -> Array:
	var pts := []
	for k in n:
		var t := TAU * float(k) / float(n)
		pts.append([cx + r * cos(t), cy + r * sin(t)])
	return pts


static func forme(a: Dictionary) -> Dictionary:
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
	if x0 == INF:
		x0 = 0.0
		x1 = 4.0
	var X := func(x: float) -> float: return (x - x0) * C
	var Y := func(y: float) -> float: return (y - sol) * C
	var formes := []
	for c in cases:
		var col := "sombre" if cases[c] == "blindage" else "caisse"
		formes.append({"pts": [[X.call(c.x), Y.call(c.y)], [X.call(c.x + 1.0), Y.call(c.y)], [X.call(c.x + 1.0), Y.call(c.y + 1.0)], [X.call(c.x), Y.call(c.y + 1.0)]], "c": col, "z": 0})
	var roues := []
	var chenille := {}
	var pistes := {}
	for e in essieux:
		var cx: float = X.call(e.x + 0.5)
		var r: float = e.r * C
		formes.append({"ligne": [[cx, Y.call(e.y)], [cx, Y.call(e.y) - 0.08]], "ep": 0.06, "c": "metal", "z": 1})
		if e.get("piste", -1) >= 0 and e.get("touche", false):
			if not pistes.has(e.piste):
				pistes[e.piste] = []
			pistes[e.piste].append(cx)
		elif e.get("touche", false):
			roues.append({"x": cx, "r": r})
		else:   # roue qui ne repose pas au sol : dessinée à sa vraie hauteur
			formes.append({"pts": _poly_cercle(cx, Y.call(e.y), r), "c": "sombre", "z": 2})
			formes.append({"pts": _poly_cercle(cx, Y.call(e.y), r * 0.45, 8), "c": "metal", "z": 2})
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
		if _habillage(p.fiche):
			var st := String(p.fiche.get("style", "voiture"))
			if STYLE_SPRITE.has(st):
				_sprite(formes, STYLE_SPRITE[st], r, 2 if st != "ouverte" else -1)   # la carrosserie recouvre les sièges
			else:
				_formes_cabine(formes, st, r)
			continue
		match p.fiche.get("famille", ""):
			"moteur":
				var surface: int = int(p.e.x) * int(p.e.y)
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
	var res := {"x0": x0, "sol": sol, "nom": String(a.get("nom", "Frankenstein")), "longueur": maxf(0.5, (x1 - x0) * C), "hauteur": maxf(0.5, (y1 - sol) * C),
		"teinte": "joueur", "moteur": moteur, "course": 0.09, "fiche": "Véhicule construit sur la grille.",
		"roues": roues, "formes": formes, "armes": armes, "equipage": equipage, "libre": true}
	if not chenille.is_empty():
		res.chenille = chenille
	return res


# --- Visuels dessinés (planches ChatGPT, DEC-066) ------------------------------------------------
const STYLE_SPRITE := {"camion": "cabine_camion", "voiture": "cabine_berline", "blindee": "cabine_blindee", "ouverte": "cabine_jeep"}


# Rectangle [x, y_bas, l, h] d'un visuel dans la pièce r : remplit la pièce si les proportions sont proches, sinon contenu (centré, posé en bas)
static func _rect_sprite(id: String, r: Rect2, remplir: bool) -> Array:
	var t: Texture2D = load("res://assets/grille/%s.png" % id)
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
