class_name TransformationBase
# Écran de transformation d'une base (DEV-016) : le catalogue d'actions par onglet, calculé sans interface.
# Chaque entrée dit si l'action est possible, pourquoi sinon (vignette grisée), ce qu'elle coûte et sa durée.
# contexte : {niveau, atelier_mobile, mecaniciens, metal, reserve: [{piece, etat}]}
# Les opérations lourdes (rallonge, essieu ajouté, renfort) exigent un atelier de checkpoint (DEC-121 à 125).

const ONGLETS := [["base", "Base"], ["structure", "Structure"], ["plateau", "Plateau"], ["blindage", "Blindage et options"]]


static func _entree(onglet: String, id: String, nom: String, op: String, args: Dictionary, a: Dictionary, ctx: Dictionary, crans := 1) -> Dictionary:
	var e := {"onglet": onglet, "id": id, "nom": nom, "op": op, "args": args, "ok": true, "raison": "", "metal": 0.0, "duree_s": 0.0}
	var p := BaseVehicule.permis(op, ctx)
	if not bool(p.ok):
		e.ok = false
		e.raison = String(p.raison)
	else:
		var r := appliquer(a, e)
		if not bool(r.ok):
			e.ok = false
			e.raison = String(r.raison)
		else:
			e.metal = float(r.get("cout", {}).get("metal", 0.0))
			if e.metal > float(ctx.get("metal", 0.0)) and not bool(ctx.get("bac_a_sable", false)):
				e.ok = false
				e.raison = "il faut %d métal (vous en avez %d)" % [int(ceil(e.metal)), int(ctx.get("metal", 0.0))]
	e.duree_s = BaseVehicule.duree_s(op, ctx, int(ctx.get("mecaniciens", 1)), crans)
	return e


# Applique une entrée à la grille a : {ok, a, raison, cout, retire}
static func appliquer(a: Dictionary, e: Dictionary) -> Dictionary:
	var g: Dictionary = e.args
	match String(e.op):
		"rallonger":
			return BaseVehicule.rallonger(a, String(g.zone), int(g.get("crans", 1)))
		"renforcer":
			return BaseVehicule.renforcer(a)
		"ajouter_essieu":
			return BaseVehicule.ajouter_essieu(a, int(g.x), String(g.essieu), String(g.train))
		"changer_moteur":
			return BaseVehicule.changer_moteur(a, String(g.moteur))
		"changer_boite":
			return BaseVehicule.changer_boite(a, String(g.boite))
		"poser_module":
			return BaseVehicule.poser_module(a, String(g.module))
		"blinder_zone":
			return BaseVehicule.blinder_zone(a, String(g.zone), String(g.niveau))
	return {"ok": false, "a": a, "raison": "action inconnue"}


static func _de_famille(reserve: Array, famille: String) -> Array:
	var res := []
	for r in reserve:
		if String(Assemblage.piece(String(r.piece)).get("famille", "")) == famille:
			res.append(r)
	return res


# Colonne libre où poser un essieu ajouté : la plus proche du milieu de l'empattement où la pose est possible.
static func colonne_essieu(a: Dictionary, essieu_id: String, train_id: String) -> int:
	var bx := BaseVehicule.bornes_x(a)
	var milieu := (bx.x + bx.y) / 2
	for d in range(0, bx.y - bx.x + 1):
		for s in [1, -1]:
			var x: int = milieu + d * s
			if x < bx.x or x > bx.y:
				continue
			if bool(BaseVehicule.ajouter_essieu(a, x, essieu_id, train_id).ok):
				return x
	return -1


static func entrees(a: Dictionary, ctx: Dictionary) -> Array:
	var res := []
	if not BaseVehicule.est_base(a):
		return res
	var f := BaseVehicule.fiche(BaseVehicule.id_de(a))
	var R := BaseVehicule.regles()
	var reserve: Array = ctx.get("reserve", [])
	# Base : moteur, boîte
	for r in _de_famille(reserve, "moteur"):
		var n := String(Assemblage.piece(String(r.piece)).get("nom", r.piece))
		res.append(_entree("base", "moteur_" + String(r.piece), "Moteur : " + n, "changer_moteur", {"moteur": String(r.piece)}, a, ctx))
	for bid in R.boites:
		if bid == String(a.base.boite):
			continue
		res.append(_entree("base", "boite_" + String(bid), "Boîte : " + String(R.boites[bid].get("nom", bid)), "changer_boite", {"boite": String(bid)}, a, ctx))
	# Structure : rallonge par zone, renfort, essieu ajouté
	for z in BaseVehicule.ZONES:
		var nom := {"avant": "Porte-à-faux avant", "milieu": "Empattement", "arriere": "Porte-à-faux arrière"}[z] as String
		res.append(_entree("structure", "rallonge_" + String(z), "%s +1 cran (%d/%d)" % [nom, int(a.base.crans[z]), int(f.rallonge_max[z])], "rallonger", {"zone": z, "crans": 1}, a, ctx))
	res.append(_entree("structure", "renfort", "Renforcer le châssis (%d/%d)" % [int(a.base.renforts), int(R.renfort.max)], "renforcer", {}, a, ctx))
	var essieux := _de_famille(reserve, "essieu")
	var trains := _de_famille(reserve, "train")
	if essieux.is_empty() or trains.is_empty():
		var vide := _entree("structure", "essieu_ajoute", "Ajouter un essieu", "ajouter_essieu", {"x": 0, "essieu": "", "train": ""}, a, ctx)
		vide.ok = false
		vide.raison = "il faut un essieu et un train de roues en réserve"
		res.append(vide)
	else:
		var ei := String(essieux[0].piece)
		var ti := String(trains[0].piece)
		var x := colonne_essieu(a, ei, ti)
		res.append(_entree("structure", "essieu_ajoute", "Ajouter un essieu (%d/%d)" % [a.essieux.size(), int(f.essieux_max)], "ajouter_essieu", {"x": maxi(x, 0), "essieu": ei, "train": ti}, a, ctx))
	# Plateau
	for mid in f.modules:
		var m: Dictionary = R.modules[mid]
		var e := _entree("plateau", "module_" + String(mid), String(m.nom), "poser_module", {"module": mid}, a, ctx)
		e.actif = String(a.base.module) == String(mid)
		if e.actif:
			e.ok = false
			e.raison = "déjà monté"
		res.append(e)
	# Blindage : zone × niveau
	for z in R.blindage.zones:
		for nid in R.blindage.niveaux:
			var e := _entree("blindage", "blindage_%s_%s" % [z, nid], "%s : %s" % [String(z).capitalize(), String(R.blindage.niveaux[nid].nom)], "blinder_zone", {"zone": z, "niveau": nid}, a, ctx)
			e.actif = String(a.base.blindage.get(z, "aucun")) == String(nid)
			if e.actif:
				e.ok = false
				e.raison = "déjà en place"
			res.append(e)
	return res


static func de_onglet(liste: Array, onglet: String) -> Array:
	return liste.filter(func(e): return String(e.onglet) == onglet)
