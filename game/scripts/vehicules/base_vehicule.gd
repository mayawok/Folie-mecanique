# Bases véhicule (Grille V2, proposition du 07/11) : un véhicule trouvé garde sa silhouette ; on le transforme par
# opérations limitées au lieu de redessiner son châssis : rallonge par crans (porte-à-faux avant, empattement, porte-à-faux
# arrière), essieux, moteur, boîte, module de plateau, blindage par zone. Le dessin libre reste au Mode créatif et au Kit.
# Fonctions pures et déterministes, testables sans écran. Données : res://data/bases.json (aucune liste écrite ici).
#
# Une base est une grille libre (ConstructionLibre) avec un bloc "base" persisté :
# {"id", "crans": {avant, milieu, arriere}, "renforts", "essieux_ajoutes", "boite", "etat_boite", "etat_chassis",
#  "module", "blindage": {zone: niveau}} ; chaque essieu et chaque moteur porte son "etat" (0 à 1).
# Les opérations rendent {"ok", "a", "raison", ...} : "a" est la nouvelle grille (l'entrée n'est jamais modifiée) ;
# "retire" liste les pièces à remettre en réserve ([{piece, etat}]) ; "cout" le métal.
class_name BaseVehicule
extends RefCounted

const ZONES := ["avant", "milieu", "arriere"]

static var _donnees := {}


static func donnees() -> Dictionary:
	if _donnees.is_empty():
		_donnees = JSON.parse_string(FileAccess.get_file_as_string("res://data/bases.json"))
	return _donnees


static func regles() -> Dictionary:
	return donnees().regles


static func ids() -> Array:
	return donnees().bases.keys()


static func fiche(id: String) -> Dictionary:
	return donnees().bases.get(id, {})


static func est_base(a: Dictionary) -> bool:
	return a.has("base")


static func id_de(a: Dictionary) -> String:
	return String(a.get("base", {}).get("id", ""))


static func _non(a: Dictionary, raison: String) -> Dictionary:
	return {"ok": false, "a": a, "raison": raison}


# --- P0 : créer une base depuis un véhicule historique converti ------------------------------------
static func creer(id: String) -> Dictionary:
	var f := fiche(id)
	if f.is_empty():
		return {}
	var h := String(f.historique)
	var src := Assemblage.de_type(h)
	if src.is_empty():
		return {}
	var a := ConstructionLibre.convertir(src, h)
	a.nom = String(f.nom)
	var eo: Dictionary = f.etat_origine
	a.base = {"id": id, "crans": {"avant": 0, "milieu": 0, "arriere": 0}, "renforts": 0, "essieux_ajoutes": 0,
		"boite": String(f.boite), "etat_boite": float(eo.boite), "etat_chassis": float(eo.chassis), "module": "", "blindage": {}}
	for e in a.essieux:
		e.etat = float(eo.essieux)
	for p in a.pieces:
		if String(Assemblage.piece(String(p.piece)).get("famille", "")) == "moteur":
			p.etat = float(eo.moteur)
	return a


static func bornes_x(a: Dictionary) -> Vector2i:   # première et dernière colonne du châssis
	var lo := 9999
	var hi := -9999
	for c in a.get("cases", []):
		lo = mini(lo, int(c[0]))
		hi = maxi(hi, int(c[0]))
	return Vector2i(lo, hi)


static func longueur_cases(a: Dictionary) -> int:
	var b := bornes_x(a)
	return 0 if b.x > b.y else b.y - b.x + 1


# --- Lieux, opérations, durées -------------------------------------------------------------------
static func operation(op_id: String) -> Dictionary:
	return regles().operations.get(op_id, {})


# Niveau du lieu : 0 camp sur la route, 1 garage de fortune ou atelier mobile, 2 atelier de checkpoint, 3 forge
static func niveau_effectif(contexte: Dictionary) -> int:
	var n := int(contexte.get("niveau", 0))
	if bool(contexte.get("atelier_mobile", false)):
		n = maxi(n, 1)
	return n


static func permis(op_id: String, contexte := {}) -> Dictionary:
	var op := operation(op_id)
	if op.is_empty():
		return {"ok": false, "raison": "opération inconnue"}
	var requis := int(op.niveau)
	if niveau_effectif(contexte) < requis:
		return {"ok": false, "raison": "%s : il faut %s" % [String(op.nom), String(regles().niveaux_lieu[str(requis)])]}
	return {"ok": true, "raison": ""}


# Durée en secondes de jeu : atelier de checkpoint (niveau 2+) deux fois plus vite, atelier mobile ×0,6 en route,
# chaque mécanicien supplémentaire raccourcit (plancher ×0,4). Une rallonge dure autant de fois que de crans.
static func duree_s(op_id: String, contexte := {}, mecaniciens := 1, crans := 1) -> float:
	var op := operation(op_id)
	if op.is_empty():
		return 0.0
	var D: Dictionary = regles().duree
	var t := float(op.duree_s)
	if op_id == "rallonger":
		t *= float(maxi(1, crans))
	if int(contexte.get("niveau", 0)) >= 2:
		t *= float(D.lieu_2_ou_plus)
	elif bool(contexte.get("atelier_mobile", false)):
		t *= float(regles().modules.atelier_mobile.duree_camp_mult)
	var m := maxi(1, mecaniciens)
	return t * maxf(float(D.plancher_mecaniciens), 1.0 / (1.0 + float(D.mecanicien_supplementaire) * float(m - 1)))


# --- P1 : rallonge par crans (porte-à-faux avant, empattement, porte-à-faux arrière) ----------------
static func _coupe_possible(a: Dictionary, cut: int) -> bool:   # aucune pièce (hors coque, qui s'allonge) ni tôle à cheval
	for p in ConstructionLibre._pieces(a):
		if p.pos.x < cut and p.pos.x + p.e.x > cut and not ConstructionLibre._coque(p.fiche):
			return false
	for t in a.get("toles", []):
		var mn := mini(int(t[0]), int(t[2]))
		var mx := maxi(int(t[0]), int(t[2]))
		if mn < cut and mx > cut:
			return false
	return true


# Colonne de coupe de l'empattement : dans l'écart entre deux essieux (le plus grand par défaut), au plus près du milieu,
# là où aucune pièce n'est à cheval. -1 si impossible.
static func _coupe_milieu(a: Dictionary, ecart: int) -> int:
	var xs := []
	for e in a.get("essieux", []):
		xs.append(int(e.x))
	xs.sort()
	if xs.size() < 2:
		return -1
	var i := ecart
	if i < 0 or i > xs.size() - 2:
		i = 0
		var meilleur := -1
		for k in range(xs.size() - 1):
			var w: int = int(xs[k + 1]) - int(xs[k])
			if w >= meilleur:
				meilleur = w
				i = k
	var lo: int = int(xs[i]) + 1
	var hi: int = int(xs[i + 1])
	var mid := float(lo + hi) * 0.5
	var cols := {}
	for c in a.get("cases", []):
		cols[int(c[0])] = true
	var cands := []
	for x in range(lo, hi + 1):
		if cols.has(x) and cols.has(x - 1):
			cands.append(x)
	cands.sort_custom(func(p, q): return absf(float(p) - mid) < absf(float(q) - mid))
	for x in cands:
		if _coupe_possible(a, int(x)):
			return int(x)
	return -1


# Insère n colonnes à la colonne cut : tout ce qui est à partir de cut avance de n ; les colonnes neuves copient la colonne source ;
# une coque à cheval sur la coupe s'allonge (marque "etire").
static func _inserer(a: Dictionary, cut: int, n: int, source: int) -> Dictionary:
	var b := a.duplicate(true)
	var copie := []
	for c in b.cases:
		if int(c[0]) == source:
			copie.append([int(c[1]), String(c[2])])
	for c in b.cases:
		if int(c[0]) >= cut:
			c[0] = int(c[0]) + n
	for k in n:
		for q in copie:
			b.cases.append([cut + k, int(q[0]), String(q[1])])
	for e in b.essieux:
		if int(e.x) >= cut:
			e.x = int(e.x) + n
	for p in ConstructionLibre._pieces(a):
		var brut: Dictionary = b.pieces[int(p.i)]
		if p.pos.x >= cut:
			brut.pos = [int(brut.pos[0]) + n, int(brut.pos[1])]
		elif p.pos.x + p.e.x > cut:
			brut.emprise = [int(p.e.x) + n, int(p.e.y)]
			brut.etire = int(brut.get("etire", 0)) + n
	for t in b.get("toles", []):
		if mini(int(t[0]), int(t[2])) >= cut:
			t[0] = int(t[0]) + n
			t[2] = int(t[2]) + n
	return b


# zone : "avant" (porte-à-faux avant), "milieu" (empattement, entre deux essieux : ecart = rang de l'écart, -1 = le plus grand),
# "arriere" (porte-à-faux arrière). Garage seulement (voir permis("rallonger")).
static func rallonger(a: Dictionary, zone: String, crans: int, ecart := -1) -> Dictionary:
	if not est_base(a):
		return _non(a, "ce véhicule n'est pas une base")
	if not zone in ZONES or crans < 1:
		return _non(a, "zone ou nombre de crans invalide")
	var f := fiche(id_de(a))
	var deja := int(a.base.crans[zone])
	var plafond := int(f.rallonge_max[zone])
	if deja + crans > plafond:
		return _non(a, "rallonge maximale de cette base : %d cran(s) en %s" % [plafond, zone])
	var n := crans * int(regles().cran_cases)
	var bx := bornes_x(a)
	if bx.x > bx.y:
		return _non(a, "pas de châssis")
	if bx.y + n >= ConstructionLibre.taille().x:
		return _non(a, "la grille n'a plus de place")
	var cut := 0
	var source := 0
	if zone == "avant":
		cut = bx.y + 1
		source = bx.y
	elif zone == "arriere":
		cut = bx.x
		source = bx.x
	else:
		cut = _coupe_milieu(a, ecart)
		if cut < 0:
			return _non(a, "pas de coupe possible entre les essieux (une pièce est à cheval)")
		source = cut - 1
	if zone != "milieu" and not _coupe_possible(a, cut):
		return _non(a, "une pièce est à cheval sur la coupe")
	var b := _inserer(a, cut, n, source)
	b.base.crans[zone] = deja + crans
	var metal := float(crans) * float(operation("rallonger").metal_par_cran)
	return {"ok": true, "a": b, "raison": "", "cout": {"metal": metal}}


static func renforcer(a: Dictionary) -> Dictionary:
	if not est_base(a):
		return _non(a, "ce véhicule n'est pas une base")
	var RF: Dictionary = regles().renfort
	if int(a.base.renforts) >= int(RF.max):
		return _non(a, "renforts au maximum (%d)" % int(RF.max))
	var b := a.duplicate(true)
	b.base.renforts = int(b.base.renforts) + 1
	b.base.etat_chassis = minf(1.0, float(b.base.etat_chassis) + float(RF.etat_gain))   # le renfort soudé remet le châssis en état
	return {"ok": true, "a": b, "raison": "", "cout": {"metal": float(RF.metal)}}


# --- P1 : essieux, roues, moteur, boîte -----------------------------------------------------------
static func ajouter_essieu(a: Dictionary, x: int, essieu_id: String, train_id: String, etat := 1.0) -> Dictionary:
	if not est_base(a):
		return _non(a, "ce véhicule n'est pas une base")
	var f := fiche(id_de(a))
	if a.essieux.size() >= int(f.essieux_max):
		return _non(a, "nombre maximal d'essieux atteint (%d)" % int(f.essieux_max))
	if not ConstructionLibre.essieu_en(a, x).is_empty():
		return _non(a, "il y a déjà un essieu à cette colonne")
	if String(Assemblage.piece(essieu_id).get("famille", "")) != "essieu":
		return _non(a, "ce n'est pas un essieu")
	var b := ConstructionLibre.poser_essieu(a, x, essieu_id, train_id)
	if b.is_empty():
		return _non(a, "pas de châssis à cette colonne")
	for e in b.essieux:
		if int(e.x) == x:
			e.etat = etat
	b.base.essieux_ajoutes = int(b.base.essieux_ajoutes) + 1
	return {"ok": true, "a": b, "raison": "", "cout": {"metal": 0.0}}


static func changer_essieu(a: Dictionary, x: int, essieu_id: String, train_id: String, etat := 1.0) -> Dictionary:
	var ancien := ConstructionLibre.essieu_en(a, x)
	if ancien.is_empty():
		return _non(a, "aucun essieu à cette colonne")
	if String(Assemblage.piece(essieu_id).get("famille", "")) != "essieu":
		return _non(a, "ce n'est pas un essieu")
	var b := ConstructionLibre.poser_essieu(a, x, essieu_id, train_id)
	if b.is_empty():
		return _non(a, "essieu impossible à cette colonne")
	for e in b.essieux:
		if int(e.x) == x:
			e.etat = etat
	var retire := [{"piece": String(ancien.piece), "etat": float(ancien.get("etat", 0.5))}]
	if String(ancien.get("train", "")) != "" and String(ancien.train) != train_id:
		retire.append({"piece": String(ancien.train), "etat": float(ancien.get("etat", 0.5))})
	return {"ok": true, "a": b, "raison": "", "retire": retire}


static func changer_roue(a: Dictionary, x: int, train_id: String, etat := 1.0) -> Dictionary:
	var ancien := ConstructionLibre.essieu_en(a, x)
	if ancien.is_empty():
		return _non(a, "aucun essieu à cette colonne")
	var b := ConstructionLibre.monter_train(a, x, train_id)
	if b.is_empty():
		return _non(a, "roue impossible")
	var retire := []
	if String(ancien.get("train", "")) != "":
		retire.append({"piece": String(ancien.train), "etat": float(ancien.get("etat", 0.5))})
	return {"ok": true, "a": b, "raison": "", "retire": retire}


static func changer_moteur(a: Dictionary, nouveau_id: String, etat := 1.0) -> Dictionary:
	if String(Assemblage.piece(nouveau_id).get("famille", "")) != "moteur":
		return _non(a, "ce n'est pas un moteur")
	var idx := -1
	for i in a.pieces.size():
		if String(Assemblage.piece(String(a.pieces[i].piece)).get("famille", "")) == "moteur":
			idx = i
			break
	if idx < 0:
		return _non(a, "aucun moteur à remplacer")
	var vieux: Dictionary = a.pieces[idx]
	var pos := Vector2i(int(vieux.pos[0]), int(vieux.pos[1]))
	var b := a.duplicate(true)
	b.pieces.remove_at(idx)
	var c := ConstructionLibre.poser(b, nouveau_id, pos)
	if c.is_empty():
		return _non(a, "ce moteur ne rentre pas à cet emplacement")
	c.pieces[c.pieces.size() - 1].etat = etat
	return {"ok": true, "a": c, "raison": "", "retire": [{"piece": String(vieux.piece), "etat": float(vieux.get("etat", 0.5))}]}


static func changer_boite(a: Dictionary, boite_id: String, etat := 1.0) -> Dictionary:
	if not est_base(a):
		return _non(a, "ce véhicule n'est pas une base")
	if not regles().boites.has(boite_id):
		return _non(a, "boîte inconnue")
	var b := a.duplicate(true)
	var retire := [{"piece": String(b.base.boite), "etat": float(b.base.etat_boite)}]
	b.base.boite = boite_id
	b.base.etat_boite = etat
	return {"ok": true, "a": b, "raison": "", "retire": retire}


# --- P2 : modules de plateau, blindage par zone, rôles ----------------------------------------------
static func plateau_cases(a: Dictionary) -> int:   # longueur du plateau : base + cran de l'empattement et du porte-à-faux arrière
	var f := fiche(id_de(a))
	var cr: Dictionary = a.base.crans
	return int(f.plateau_cases) + int(regles().cran_cases) * (int(cr.milieu) + int(cr.arriere))


static func poser_module(a: Dictionary, module_id: String) -> Dictionary:
	if not est_base(a):
		return _non(a, "ce véhicule n'est pas une base")
	var f := fiche(id_de(a))
	var M: Dictionary = regles().modules
	if not M.has(module_id) or not module_id in f.modules:
		return _non(a, "ce module ne se monte pas sur cette base")
	var m: Dictionary = M[module_id]
	if plateau_cases(a) < int(m.cases_min):
		return _non(a, "plateau trop court : %d cases, il en faut %d" % [plateau_cases(a), int(m.cases_min)])
	var b := a.duplicate(true)
	var ancien := String(b.base.module)
	b.base.module = module_id
	var retire := []
	if ancien != "":
		retire.append({"piece": ancien, "etat": 1.0})
	return {"ok": true, "a": b, "raison": "", "retire": retire}


static func effets_module(a: Dictionary) -> Dictionary:
	var id := String(a.get("base", {}).get("module", ""))
	var m: Dictionary = regles().modules.get(id, {})
	return {"id": id, "poids_kg": float(m.get("poids_kg", 0)), "reservoir_plus": float(m.get("reservoir_plus", 0)),
		"places_troupes": int(m.get("places_troupes", 0)), "places_captifs": int(m.get("places_captifs", 0)),
		"cargo_kg": float(m.get("cargo_kg", 0)), "atelier_niveau": int(m.get("atelier_niveau", 0)),
		"duree_camp_mult": float(m.get("duree_camp_mult", 1.0)), "soin": bool(m.get("soin", false)),
		"affuts": int(m.get("affuts", 0)), "couvert": bool(m.get("couvert", false)), "role": String(m.get("role", ""))}


static func blinder_zone(a: Dictionary, zone: String, niveau_id: String) -> Dictionary:
	if not est_base(a):
		return _non(a, "ce véhicule n'est pas une base")
	var B: Dictionary = regles().blindage
	if not zone in B.zones or not B.niveaux.has(niveau_id):
		return _non(a, "zone ou niveau de blindage inconnu")
	var b := a.duplicate(true)
	if niveau_id == "aucun":
		b.base.blindage.erase(zone)
	else:
		b.base.blindage[zone] = niveau_id
	return {"ok": true, "a": b, "raison": "", "cout": {"metal": float(B.niveaux[niveau_id].metal)}}


static func effets_blindage(a: Dictionary) -> Dictionary:
	var B: Dictionary = regles().blindage
	var poids := 0.0
	var par_zone := {}
	var somme := 0.0
	for z in B.zones:
		var niv: Dictionary = B.niveaux[String(a.get("base", {}).get("blindage", {}).get(z, "aucun"))]
		poids += float(niv.poids_kg)
		par_zone[z] = float(niv.blindage)
		somme += float(niv.blindage)
	return {"poids_kg": poids, "par_zone": par_zone, "moyenne": somme / float(B.zones.size())}


# Poids que ConstructionLibre.analyser ne compte pas encore : renforts, module, blindage par zone (à ajouter à la masse)
static func poids_supplementaire(a: Dictionary) -> float:
	if not est_base(a):
		return 0.0
	return float(a.base.renforts) * float(regles().renfort.poids_kg) + float(effets_module(a).poids_kg) + float(effets_blindage(a).poids_kg)


static func roles(a: Dictionary) -> Array:
	var r := []
	var role := String(effets_module(a).role)
	if role != "":
		r.append(role)
	if float(effets_blindage(a).moyenne) >= 2.5:
		r.append("blinde")
	return r


# Composition d'un convoi (liste de grilles-bases) : rôles présents, atelier mobile, rôles qui manquent
static func composition(convoi: Array) -> Dictionary:
	var compte := {}
	var atelier := false
	for a in convoi:
		if not est_base(a):
			continue
		for r in roles(a):
			compte[r] = int(compte.get(r, 0)) + 1
		atelier = atelier or int(effets_module(a).atelier_niveau) >= 1
	var manques := []
	for r in ["ravitailleur", "atelier", "infirmerie", "cargo", "canon"]:
		if not compte.has(r):
			manques.append(r)
	return {"roles": compte, "atelier_mobile": atelier, "manques": manques}


# --- Dessin (DEV-017) : la base garde ses visuels, la rallonge les étire ou les répète ---------------------------
# Une base dont la fiche porte un bloc "dessin" remplace le dessin vectoriel de sa grille par ses images. Chaque image est découpée
# en tranches ; les bandes d'une zone (avant, milieu, arriere) absorbent la rallonge de cette zone, les pièces à droite d'une coupe
# avancent. Les roues, armes et équipage restent ceux de la grille. Pur et déterministe.
static func _tranches(p: Dictionary, n: Dictionary) -> Array:   # [{u0, u1, larg (cases), bande}]
	var w0 := float(p.box[2])
	var bandes := []
	var bd: Dictionary = p.get("bandes", {})
	for z in bd:
		bandes.append([float(bd[z][0]), float(bd[z][1]), float(n.get(z, 0.0))])
	bandes.sort_custom(func(s, t): return s[0] < t[0])
	var res := []
	var u := 0.0
	for b in bandes:
		if float(b[0]) > u:
			res.append({"u0": u, "u1": float(b[0]), "larg": (float(b[0]) - u) * w0, "bande": false})
		res.append({"u0": float(b[0]), "u1": float(b[1]), "larg": (float(b[1]) - float(b[0])) * w0 + float(b[2]), "bande": true, "nat": (float(b[1]) - float(b[0])) * w0})
		u = float(b[1])
	if u < 1.0:
		res.append({"u0": u, "u1": 1.0, "larg": (1.0 - u) * w0, "bande": false})
	return res


static func habiller(a: Dictionary, res: Dictionary) -> Dictionary:
	var f := fiche(id_de(a))
	if f.is_empty() or not f.has("dessin"):
		return res
	var ess := ConstructionLibre._essieux(a)
	if ess.is_empty():
		return res
	var D: Dictionary = f.dessin
	var C := ConstructionLibre.C
	var cr: Dictionary = a.base.crans
	var cran := float(regles().cran_cases)
	var n := {"arriere": float(cr.arriere) * cran, "milieu": float(cr.milieu) * cran, "avant": float(cr.avant) * cran}
	var cuts: Dictionary = D.coupes
	var e_de := func(p: float) -> float:   # position étendue : chaque coupe située avant p la décale de sa rallonge
		var s := p
		for z in n:
			if float(cuts[z]) < p:
				s += float(n[z])
		return s
	var ancre := (float(ess[0].x) + 0.5 - float(res.x0)) * C
	var origine := ancre - float(e_de.call(float(D.ancrage))) * C
	var formes := []
	var gauche_min := INF
	var droite_max := -INF
	var haut_max := 0.0
	for p in D.parties:
		var box: Array = p.box
		var xm := origine + float(e_de.call(float(box[0]))) * C
		var y_m := float(box[1]) * C
		var h_m := float(box[3]) * C
		haut_max = maxf(haut_max, y_m + h_m)
		gauche_min = minf(gauche_min, xm)
		var tr: Array = [{"u0": 0.0, "u1": 1.0, "larg": float(box[2]), "bande": false}] if bool(p.get("rigide", false)) else _tranches(p, n)
		for s in tr:
			var w_m := float(s.larg) * C
			if bool(s.bande) and String(p.get("mode", "etirer")) == "repeter" and float(s.nat) > 0.01:
				var pas := float(s.nat) * C
				var fait := 0.0
				while fait < w_m - 0.0001:
					var seg := minf(pas, w_m - fait)
					var u1 := float(s.u0) + (float(s.u1) - float(s.u0)) * seg / pas
					formes.append({"sprite": String(p.image), "r": [xm + fait, y_m, seg, h_m], "z": int(p.z), "uv": [float(s.u0), 0.0, u1, 1.0]})
					fait += seg
			else:
				formes.append({"sprite": String(p.image), "r": [xm, y_m, w_m, h_m], "z": int(p.z), "uv": [float(s.u0), 0.0, float(s.u1), 1.0]})
			xm += w_m
		droite_max = maxf(droite_max, xm)
	var gardees := []
	for fm in res.formes:   # on garde les formes du premier plan (coques, tôles) ; le corps vectoriel est remplacé par les visuels
		if int(fm.get("z", 1)) >= 3:
			gardees.append(fm)
	res.formes = formes + gardees
	res.longueur = maxf(float(res.longueur), droite_max - minf(0.0, gauche_min))
	res.hauteur = maxf(float(res.hauteur), haut_max)
	res.art_base = true
	return res
