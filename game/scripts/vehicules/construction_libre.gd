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
const FAMILLES_PIECES := ["moteur", "cabine", "arme"]


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


static func _occupation(a: Dictionary, sauf := -1) -> Dictionary:   # cellule -> "case" | indice de pièce
	var occ := {}
	for c in _cases(a):
		occ[c] = "case"
	for p in _pieces(a):
		if p.i == sauf:
			continue
		for x in range(p.pos.x, p.pos.x + p.e.x):
			for y in range(p.pos.y, p.pos.y + p.e.y):
				occ[Vector2i(x, y)] = p.i
	return occ


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
	var occ := _occupation(a)
	var cands := []
	for dy in range(-4, 5):
		for dx in range(-6, 7):
			cands.append(cell + Vector2i(dx, dy))
	cands.sort_custom(func(p, q): return (p - cell).length_squared() < (q - cell).length_squared())
	for c in cands:
		if _libre(occ, c, e) and _portee(occ, c, e):
			var b := a.duplicate(true)
			b.pieces.append({"piece": piece_id, "pos": [c.x, c.y]})
			return b
	return {}


static func retirer(a: Dictionary, index: int) -> Dictionary:
	var b := a.duplicate(true)
	if index >= 0 and index < b.pieces.size():
		b.pieces.remove_at(index)
	return nettoyer(b)


static func piece_en(a: Dictionary, cell: Vector2i) -> int:
	var occ := _occupation(a)
	return int(occ[cell]) if occ.has(cell) and not (occ[cell] is String) else -1


# Retire ce qui ne tient plus : essieux sous une colonne vide, pièces qui ne reposent plus sur rien
static func nettoyer(a: Dictionary) -> Dictionary:
	var b := a.duplicate(true)
	b.essieux = b.get("essieux", []).filter(func(e): return y_essieu(b, int(e.x)) >= 0)
	var change := true
	while change:
		change = false
		for p in _pieces(b):
			var occ := _occupation(b, p.i)
			if not _libre(occ, p.pos, p.e) or not _portee(occ, p.pos, p.e):
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
		t += float(Assemblage.piece(String(e.piece)).get("metal", 0)) + float(Assemblage.piece(String(e.train)).get("metal", 0))
	return t


static func _defaut(liste: Array, code: String, texte: String, grave := false) -> void:
	liste.append({"code": code, "texte": texte, "grave": grave})


# Défauts qui empêchent de construire (vide = on peut construire, même si le véhicule roule mal)
static func erreurs(a: Dictionary) -> Array:
	var err := []
	if _cases(a).is_empty():
		_defaut(err, "chassis", "Peignez au moins une case de châssis", true)
	var sieges := 0
	for p in _pieces(a):
		if p.fiche.get("famille", "") == "cabine":
			sieges += int(p.fiche.sieges)
	if sieges < 1:
		_defaut(err, "cabine", "Aucun siège : personne pour conduire", true)
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
	for p in pieces:
		match p.fiche.get("famille", ""):
			"moteur":
				puissance += float(p.fiche.puissance_ch)
				conso += float(p.fiche.conso)
				pv.moteur += float(p.fiche.pv)
			"cabine":
				sieges += int(p.fiche.sieges)
				ouvert = ouvert or bool(p.fiche.ouvert)
				pv.cabine += float(p.fiche.pv)
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
			_defaut(defauts, "servant", "%s : pas de place pour un servant" % w.fiche.nom)
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
	var stats := {"blindage": blindage_somme / maxf(1.0, cases.size()) + plaques * float(PL.blindage),
		"reservoir": float(RL.reservoir_base) + float(RL.reservoir_par_case) * cases.size(), "metal": int(round(metal)),
		"equipage": sieges, "ouvert": ouvert, "armes": armes, "conso": conso, "pv": pv, "poids_kg": M, "vitesse": v,
		"precision": precision, "immobile": immobile}
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
	var occ := _occupation(a)
	var sieges := 0
	for p in _pieces(a):
		if p.fiche.get("famille", "") == "cabine":
			sieges += int(p.fiche.sieges)
	var places := maxi(1, sieges - 1) if sieges > 0 else 0
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
	for w in res:
		if not w.masquee and places > 0:
			w.servie = true
			places -= 1
	var servies := res.filter(func(w): return w.servie)
	servies.append_array(res.filter(func(w): return not w.servie))
	return servies


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
	for p in _pieces(a):
		var r := Rect2(X.call(p.pos.x), Y.call(p.pos.y), p.e.x * C, p.e.y * C)
		match p.fiche.get("famille", ""):
			"moteur":
				formes.append({"pts": [[r.position.x, r.position.y], [r.end.x, r.position.y], [r.end.x, r.position.y + r.size.y * 0.8],
					[r.position.x + r.size.x * 0.85, r.end.y], [r.position.x + r.size.x * 0.1, r.end.y], [r.position.x, r.position.y + r.size.y * 0.7]], "c": "caisse", "z": 1})
				formes.append({"ligne": [[r.position.x + r.size.x * 0.2, r.position.y + r.size.y * 0.5], [r.end.x - r.size.x * 0.2, r.position.y + r.size.y * 0.5]], "ep": 0.04, "c": "metal", "z": 2})
			"cabine":
				if bool(p.fiche.get("ouvert", false)):
					formes.append({"pts": [[r.position.x, r.position.y], [r.end.x, r.position.y], [r.end.x, r.position.y + r.size.y * 0.45], [r.position.x, r.position.y + r.size.y * 0.45]], "c": "caisse", "z": 1})
					var n := int(p.fiche.get("sieges", 1))
					for k in n:
						var fx := 0.5 if n == 1 else 0.2 + 0.6 * float(k) / float(n - 1)
						equipage.append({"x": r.position.x + r.size.x * fx, "y": r.position.y + r.size.y * 0.4,
							"role": "conducteur" if k == 0 else ("tireur" if k == 1 else "passager")})
				else:
					formes.append({"pts": [[r.position.x, r.position.y], [r.end.x, r.position.y], [r.position.x + r.size.x * 0.95, r.position.y + r.size.y * 0.9],
						[r.position.x + r.size.x * 0.8, r.end.y], [r.position.x + r.size.x * 0.15, r.end.y], [r.position.x, r.position.y + r.size.y * 0.85]], "c": "caisse", "z": 1})
					formes.append({"pts": [[r.position.x + r.size.x * 0.3, r.position.y + r.size.y * 0.5], [r.position.x + r.size.x * 0.8, r.position.y + r.size.y * 0.5],
						[r.position.x + r.size.x * 0.76, r.position.y + r.size.y * 0.82], [r.position.x + r.size.x * 0.34, r.position.y + r.size.y * 0.82]], "c": "vitre", "z": 2})
					equipage.append({"x": r.position.x + r.size.x * 0.5, "y": r.end.y, "role": "chef", "h": 0.26})
	for w in armes_ordonnees(a):
		var p: Dictionary = w.place
		var r := Rect2(X.call(p.pos.x), Y.call(p.pos.y), p.e.x * C, p.e.y * C)
		var wid := String(p.fiche.arme)
		if wid == "mortier":
			formes.append({"pts": [[r.position.x, r.position.y], [r.end.x, r.position.y], [r.end.x - 0.05, r.position.y + 0.08], [r.position.x + 0.05, r.position.y + 0.08]], "c": "metal", "z": 1})
			armes.append({"type": "mortier", "x": r.get_center().x - 0.1, "y": r.position.y + 0.08, "long": maxf(0.6, r.size.y * 1.1), "ep": 0.1})
		elif wid.begins_with("mitrailleuse"):
			armes.append({"type": "mitrailleuse", "x": r.position.x + 0.2, "y": r.position.y, "pied": maxf(0.12, r.size.y - 0.1), "long": maxf(1.0, r.size.x * 1.2), "ep": 0.05})
		else:
			var tw := minf(r.size.x * 0.45, 2.0)
			formes.append({"pts": [[r.position.x, r.position.y], [r.position.x + tw, r.position.y], [r.position.x + tw * 0.9, r.end.y],
				[r.position.x + tw * 0.2, r.end.y], [r.position.x, r.position.y + r.size.y * 0.6]], "c": "caisse", "z": 1})
			var ep := 0.07 if wid.contains("leger") else (0.12 if wid.contains("88") else 0.1)
			armes.append({"type": "canon", "x": r.position.x + tw - 0.05, "y": r.position.y + r.size.y * 0.55, "long": r.size.x - tw + 0.35, "ep": ep})
	var plaques := int(a.get("plaques", 0))
	for k in plaques:
		formes.append({"ligne": [[X.call(x1) - 0.05 - 0.07 * k, Y.call(sol + 1.0)], [X.call(x1) - 0.05 - 0.07 * k, Y.call(sol + 4.0)]], "ep": 0.05, "c": "metal", "z": 2})
	var M: float = an.stats.get("poids_kg", 1000.0) if an.ok else 1000.0
	var moteur := ("char" if M > 20000.0 else "char_leger") if not chenille.is_empty() else ("voiture" if M < 1800.0 else "camion")
	var res := {"nom": String(a.get("nom", "Frankenstein")), "longueur": maxf(0.5, (x1 - x0) * C), "hauteur": maxf(0.5, (y1 - sol) * C),
		"teinte": "joueur", "moteur": moteur, "course": 0.09, "fiche": "Véhicule construit sur la grille.",
		"roues": roues, "formes": formes, "armes": armes, "equipage": equipage}
	if not chenille.is_empty():
		res.chenille = chenille
	return res


static func signature(a: Dictionary) -> String:
	var cs := []
	for c in a.get("cases", []):
		cs.append("%d,%d,%s" % [int(c[0]), int(c[1]), String(c[2]) if c.size() > 2 else "acier"])
	cs.sort()
	var es := []
	for e in a.get("essieux", []):
		es.append("%d:%s:%s" % [int(e.x), e.piece, e.train])
	es.sort()
	var ps := []
	for p in a.get("pieces", []):
		ps.append("%s@%d,%d" % [p.piece, int(p.pos[0]), int(p.pos[1])])
	ps.sort()
	return "L|%s|%s|%s|%s|%d|%s" % [a.get("nom", ""), ";".join(cs), ";".join(es), ";".join(ps), int(a.get("plaques", 0)), String(a.get("origine", {}).get("chassis", ""))]
