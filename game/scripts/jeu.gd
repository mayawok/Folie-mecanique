# Logique du prototype : état de la partie et règles. Aucun affichage ici.
# Toutes les valeurs viennent de data/regles_proto.json.
class_name Jeu
extends RefCounted

const POSTES := ["repos", "puits", "cuisine", "atelier"]
const RISQUES := {"faible": "faible", "modere": "modéré", "eleve": "élevé", "critique": "critique"}
const ORDRES := {"eviter": "Éviter le combat", "repli": "Repli à la première perte", "bout": "Jusqu'au bout"}

var R: Dictionary            # règles
var jour := 1
var stocks := {}             # ressource -> quantité
var survivants := []         # {nom, femme, poste, blesse, occupe}
var vehicules := []          # {uid, type, pv, pv_max, etat ("ok" ou "epave")}
var penurie := false
var epuisement := {}         # lieu -> facteur de butin (1 = plein)
var journal := []
var objectif_annonce := false
var _uid := 0


func _init() -> void:
	var f := FileAccess.open("res://data/regles_proto.json", FileAccess.READ)
	R = JSON.parse_string(f.get_as_text())
	nouvelle_partie()


func nouvelle_partie() -> void:
	jour = 1
	penurie = false
	objectif_annonce = false
	stocks = R.depart.stocks.duplicate()
	survivants.clear()
	for s in R.depart.survivants:
		survivants.append({"nom": s.nom, "femme": s.femme, "poste": s.poste, "blesse": 0, "occupe": 0})
	vehicules.clear()
	for t in R.depart.vehicules:
		ajouter_vehicule(t)
	for l in R.lieux:
		epuisement[l] = 1.0
	journal = ["Jour 1. Deux survivants, quelques jours de vivres. Il faudra sortir."]


func ajouter_vehicule(type: String) -> void:
	_uid += 1
	var pv: int = int(R.vehicules[type].pv)
	vehicules.append({"uid": _uid, "type": type, "pv": pv, "pv_max": pv, "etat": "ok"})


func stat(type: String, cle: String):
	return R.vehicules[type][cle]


# --- Base -------------------------------------------------------------------

func disponible(s: Dictionary) -> bool:
	return s.blesse == 0 and s.occupe == 0


func autonomie(res: String) -> float:
	var conso: float = R.consommation_par_survivant.get(res, 0) * survivants.size()
	return INF if conso <= 0 else stocks[res] / conso


# Solde prévu sur une journée (production des postes - consommation).
# Sert à la flèche de tendance à côté de chaque barre de ressource.
func bilan(res: String) -> float:
	var mult: float = R.penurie.productivite if penurie else 1.0
	var b := 0.0
	for s in survivants:
		if disponible(s):
			b += R.postes[s.poste].get("produit", {}).get(res, 0) * mult
	b -= R.consommation_par_survivant.get(res, 0) * survivants.size()
	return b


func passer_journee() -> Array:
	var lignes := []
	var mult: float = R.penurie.productivite if penurie else 1.0
	var gains := {}
	for s in survivants:
		if not disponible(s):
			continue
		var poste: Dictionary = R.postes[s.poste]
		for res in poste.get("produit", {}):
			gains[res] = gains.get(res, 0.0) + poste.produit[res] * mult
		if s.poste == "atelier":
			lignes.append(_reparer(mult))
	for res in gains:
		_ajouter(res, gains[res])
	# Consommation
	var manque := false
	for res in R.consommation_par_survivant:
		var besoin: float = R.consommation_par_survivant[res] * survivants.size()
		if stocks[res] < besoin:
			manque = true
			stocks[res] = 0
		else:
			stocks[res] -= besoin
	if manque and not penurie:
		lignes.append("PÉNURIE : la communauté manque d'eau ou de nourriture. Productivité réduite de moitié.")
	elif not manque and penurie:
		lignes.append("Fin de la pénurie : retour à la normale.")
	penurie = manque
	for s in survivants:
		s.blesse = max(0, s.blesse - 1)
		s.occupe = max(0, s.occupe - 1)
	for l in epuisement:
		epuisement[l] = min(1.0, epuisement[l] + R.reconstitution_par_jour)
	jour += 1
	var resume := "Jour %d." % jour
	for res in gains:
		resume += " +%s %s." % [_fmt(gains[res]), R.ressources[res].nom.to_lower()]
	lignes.push_front(resume)
	if jour > R.objectif_jours and not objectif_annonce:
		objectif_annonce = true
		lignes.append("OBJECTIF ATTEINT : la communauté a tenu %d jours." % R.objectif_jours)
	_journal(lignes)
	return lignes


func _reparer(mult: float) -> String:
	var at: Dictionary = R.postes.atelier
	for v in vehicules:
		var nom: String = stat(v.type, "nom")
		if v.etat == "epave":
			var cout: Dictionary = at.epave_cout
			for res in cout:
				if stocks[res] < cout[res]:
					return "Atelier : l'épave du %s attend %d métal et %d matériaux." % [nom, cout.metal, cout.materials]
			for res in cout:
				stocks[res] -= cout[res]
			v.etat = "ok"
			v.pv = int(v.pv_max * 0.3)
			return "Atelier : l'épave du %s est remise en route." % nom
		if v.pv < v.pv_max:
			var pv: int = min(int(at.reparation_pv * mult), v.pv_max - v.pv)
			var metal: int = ceili(pv / 10.0 * at.metal_par_10pv)
			if stocks.metal < metal:
				pv = int(stocks.metal / at.metal_par_10pv * 10)
				metal = int(stocks.metal)
			if pv <= 0:
				return "Atelier : plus de métal pour réparer."
			stocks.metal -= metal
			v.pv += pv
			return "Atelier : %s réparé de %d PV." % [nom, pv]
	return "Atelier : rien à réparer."


# --- Expéditions ------------------------------------------------------------

func vehicules_prets() -> Array:
	return vehicules.filter(func(v): return v.etat == "ok")


func equipage_pour(n: int) -> Array:
	# Les survivants au repos partent en premier.
	var dispo := survivants.filter(disponible)
	dispo.sort_custom(func(a, b): return a.poste == "repos" and b.poste != "repos")
	return dispo.slice(0, n)


func ordonner(convoi: Array) -> Array:
	# Ordre du convoi : les plus blindés devant (tête = indice 0).
	var c := convoi.duplicate()
	c.sort_custom(func(a, b): return stat(a.type, "blindage") > stat(b.type, "blindage"))
	return c


func briefing(lieu_id: String, convoi: Array) -> Dictionary:
	var l: Dictionary = R.lieux[lieu_id]
	var h: float = l.heures * 2.0
	var b := {"carburant": 0.0, "eau": 0, "vivres": 0, "erreurs": [], "raisons": [], "equipage": []}
	for v in convoi:
		b.carburant += stat(v.type, "conso_l_h") * h * l.terrain
	b.carburant = ceili(b.carburant)
	b.carburant_conseille = ceili(b.carburant * (1.0 + R.marge_carburant))
	var eq := equipage_pour(convoi.size())
	b.equipage = eq.map(func(s): return s.nom)
	b.eau = ceili(R.consommation_par_survivant.water_l * convoi.size() * h / 24.0)
	b.vivres = ceili(R.consommation_par_survivant.food * convoi.size() * h / 24.0)
	b.capacite = convoi.reduce(func(acc, v): return acc + stat(v.type, "capacite"), 0)
	b.risque = RISQUES[l.risque]
	b.raisons.append("lieu : risque %s (pillards %d %%)" % [RISQUES[l.risque], int(l.chance_pillards * 100)])
	if convoi.all(func(v): return stat(v.type, "blindage") < 5):
		b.raisons.append("aucun véhicule blindé")
	if stocks.ammo < 20:
		b.raisons.append("munitions faibles")
	if convoi.is_empty():
		b.erreurs.append("Choisir au moins un véhicule.")
	if eq.size() < convoi.size():
		b.erreurs.append("Pas assez de survivants disponibles (1 par véhicule).")
	if stocks.fuel_l < b.carburant:
		b.erreurs.append("Carburant insuffisant.")
	elif stocks.fuel_l < b.carburant_conseille:
		b.raisons.append("carburant sans marge de sécurité")
	if stocks.water_l < b.eau or stocks.food < b.vivres:
		b.erreurs.append("Vivres insuffisants pour le trajet.")
	b.ok = b.erreurs.is_empty()
	return b


func lancer(lieu_id: String, convoi: Array, ordre: String) -> Dictionary:
	var l: Dictionary = R.lieux[lieu_id]
	var b := briefing(lieu_id, convoi)
	if not b.ok:
		return {"titre": "Départ impossible", "lignes": b.erreurs, "butin": {}, "pillards": [], "convoi": [], "issue": "annule"}
	var rng := RandomNumberGenerator.new()
	rng.seed = jour * 7919 + hash(lieu_id) + convoi.size()   # même situation = même résultat
	convoi = ordonner(convoi)
	var rap := {"titre": "Expédition : " + l.nom, "lignes": [], "butin": {}, "pillards": [], "convoi": []}
	var L: Array = rap.lignes
	stocks.fuel_l -= b.carburant
	stocks.water_l -= b.eau
	stocks.food -= b.vivres
	var equipage := equipage_pour(convoi.size())
	var jours := 1 if l.heures * 2 < 24 else 2
	for i in convoi.size():
		equipage[i].occupe = jours
		convoi[i].equipage = equipage[i]
	L.append("Départ : %s. Consommé %d L de carburant, %d L d'eau, %d rations." % [
		", ".join(convoi.map(func(v): return stat(v.type, "nom"))), b.carburant, b.eau, b.vivres])
	for ev in R.evenements_trajet:
		if rng.randf() < ev.chance:
			L.append(ev.texte)
			for res in ev.get("perte", {}):
				stocks[res] = max(0, stocks[res] - ev.perte[res])
			for res in ev.get("gain", {}):
				_ajouter(res, ev.gain[res])
	var issue := "victoire"
	if rng.randf() < l.chance_pillards:
		var vit: float = convoi.map(func(v): return stat(v.type, "vitesse")).min()
		if ordre == "eviter" and rng.randf() < R.combat.evitement_reussite * vit:
			L.append("Des pillards repérés au loin : le convoi les contourne.")
		else:
			issue = _combat(convoi, R.pillards[l.risque], ordre, rng, rap)
	else:
		L.append("Trajet sans rencontre.")
	if issue == "victoire":
		# Capacité de chargement des véhicules revenus
		var cap := 0.0
		for v in convoi:
			if v.get("issue", "ok") == "ok":
				cap += stat(v.type, "capacite")
		_butin(lieu_id, cap, rng, rap)
		_recrue(l, rng, L)
	elif issue == "repli":
		L.append("Le convoi rentre les mains vides.")
	for v in convoi:
		rap.convoi.append({"type": v.type, "etat": v.get("issue", "ok")})
		v.erase("equipage")
		v.erase("issue")
	rap.issue = issue
	_journal([rap.titre + " : " + {"victoire": "réussite", "repli": "repli", "defaite": "convoi perdu"}[issue] + "."])
	return rap


# --- Expédition à pied ------------------------------------------------------
# Sans véhicule : aucun carburant, trajet 3 fois plus long, peu de butin.
# Les marcheurs se cachent des pillards ; s'ils sont surpris, ils sont blessés
# et abandonnent le butin, mais personne ne meurt.

func duree_pied(lieu_id: String) -> float:
	return R.lieux[lieu_id].heures * 2.0 * R.a_pied.facteur_duree


func briefing_pied(lieu_id: String, n: int) -> Dictionary:
	var l: Dictionary = R.lieux[lieu_id]
	var P: Dictionary = R.a_pied
	var h := duree_pied(lieu_id)
	var b := {"heures": h, "jours": max(1, ceili(h / 24.0)), "erreurs": [], "raisons": []}
	var eq := equipage_pour(n)
	b.equipage = eq.map(func(s): return s.nom)
	b.eau = ceili(R.consommation_par_survivant.water_l * n * h / 24.0)
	b.vivres = ceili(R.consommation_par_survivant.food * n * h / 24.0)
	b.capacite = n * P.capacite_par_survivant
	b.risque = RISQUES[l.risque]
	b.raisons.append("à pied, les marcheurs se cachent des pillards (%d %% de réussite)" % int(P.discretion * 100))
	if l.heures > P.heures_max:
		b.erreurs.append("Trop loin à pied (%d h de route au maximum)." % P.heures_max)
	if n < 1:
		b.erreurs.append("Envoyer au moins un survivant.")
	elif eq.size() < n:
		b.erreurs.append("Pas assez de survivants disponibles.")
	if stocks.water_l < b.eau or stocks.food < b.vivres:
		b.erreurs.append("Vivres insuffisants pour le trajet.")
	b.ok = b.erreurs.is_empty()
	return b


func lancer_pied(lieu_id: String, n: int) -> Dictionary:
	var l: Dictionary = R.lieux[lieu_id]
	var P: Dictionary = R.a_pied
	var b := briefing_pied(lieu_id, n)
	if not b.ok:
		return {"titre": "Départ impossible", "lignes": b.erreurs, "butin": {}, "pillards": [], "convoi": [], "issue": "annule"}
	var rng := RandomNumberGenerator.new()
	rng.seed = jour * 7919 + hash(lieu_id) + n * 31 + 17
	var rap := {"titre": "À pied : " + l.nom, "lignes": [], "butin": {}, "pillards": [], "convoi": [], "marcheurs": []}
	var L: Array = rap.lignes
	stocks.water_l -= b.eau
	stocks.food -= b.vivres
	var groupe := equipage_pour(n)
	for s in groupe:
		s.occupe = b.jours
		rap.marcheurs.append({"femme": s.femme, "nom": s.nom})
	L.append("Départ à pied : %s. %d h de marche aller-retour, %d L d'eau, %d rations." % [
		", ".join(b.equipage), int(b.heures), b.eau, b.vivres])
	var issue := "victoire"
	if rng.randf() < l.chance_pillards:
		if rng.randf() < P.discretion:
			L.append("Des pillards passent tout près : le groupe reste caché jusqu'à leur départ.")
		else:
			issue = "repli"
			L.append("Le groupe est surpris par des pillards et s'enfuit en abandonnant tout.")
			for s in groupe:
				s.blesse = int(P.jours_blessure)
				L.append("%s est blessé(e) (%d jours)." % [s.nom, P.jours_blessure])
	else:
		L.append("Marche sans rencontre.")
	if issue == "victoire":
		_butin(lieu_id, b.capacite, rng, rap)
		_recrue(l, rng, L)
	rap.issue = issue
	_journal([rap.titre + " : " + ("réussite" if issue == "victoire" else "groupe surpris, butin perdu") + "."])
	return rap


func _recrue(l: Dictionary, rng: RandomNumberGenerator, L: Array) -> void:
	if rng.randf() < l.chance_recrue:
		var nom: String = R.noms_recrues[rng.randi() % R.noms_recrues.size()]
		survivants.append({"nom": nom, "femme": rng.randf() < 0.5, "poste": "repos", "blesse": 0, "occupe": 0})
		L.append("RECRUE : %s, survivant(e) isolé(e), rejoint la communauté." % nom)


func _combat(convoi: Array, profil: Array, ordre: String, rng: RandomNumberGenerator, rap: Dictionary) -> String:
	var C: Dictionary = R.combat
	var L: Array = rap.lignes
	var nous := []
	for v in convoi:
		nous.append({"nom": stat(v.type, "nom"), "type": v.type, "pv": float(v.pv), "roul": true, "arm": true, "ref": v})
	var eux := []
	for t in profil:
		eux.append({"nom": stat(t, "nom"), "type": t, "pv": float(stat(t, "pv")), "roul": true, "arm": true, "ref": null})
	L.append("PILLARDS : %d véhicule(s) en travers de la route. Ordre : %s." % [eux.size(), ORDRES[ordre]])
	var issue := ""
	for tour in range(1, int(C.tours_max) + 1):
		var a_sec := not _salve(nous, eux, rng, L, true)
		_salve(eux, nous, rng, L, false)
		var vivants_eux := eux.filter(func(u): return u.pv > 0)
		var vivants_nous := nous.filter(func(u): return u.pv > 0)
		if vivants_eux.is_empty():
			L.append("Tour %d : les pillards sont anéantis." % tour)
			issue = "victoire"
		elif vivants_nous.is_empty():
			L.append("Tour %d : tout le convoi est perdu." % tour)
			issue = "defaite"
		elif a_sec:
			L.append("Tour %d : plus de munitions, le convoi cesse le feu et se replie." % tour)
			issue = "repli"
		elif ordre == "repli" and vivants_nous.size() < nous.size():
			L.append("Tour %d : première perte, repli ordonné." % tour)
			issue = "repli"
		if issue != "":
			break
	if issue == "":
		L.append("Les pillards décrochent après %d tours." % C.tours_max)
		issue = "victoire"
	for u in eux:
		rap.pillards.append({"type": u.type, "etat": "detruit" if u.pv <= 0 else "ok"})
	# Conséquences sur nos véhicules et équipages
	for u in nous:
		var v: Dictionary = u.ref
		v.pv = max(0, int(u.pv))
		var perdu: bool = u.pv <= 0 or (issue != "victoire" and not u.roul)
		if u.pv <= 0 and issue == "victoire":
			v.etat = "epave"
			v.issue = "epave"
			L.append("%s : épave remorquée jusqu'à la base." % u.nom)
		elif perdu:
			v.issue = "perdu"
			vehicules.erase(v)
			L.append("%s : abandonné sur place." % u.nom)
		if u.pv <= 0 or perdu:
			var s: Dictionary = v.equipage
			if issue == "defaite":
				survivants.erase(s)
				L.append("%s n'est pas revenu(e)." % s.nom)
			else:
				s.blesse = int(C.jours_blessure)
				L.append("%s est blessé(e) (%d jours)." % [s.nom, C.jours_blessure])
	if issue == "victoire" and eux.any(func(u): return u.pv <= 0):
		for res in C.butin_pillards:
			var q := rng.randi_range(int(C.butin_pillards[res][0]), int(C.butin_pillards[res][1]))
			rap.butin[res] = rap.butin.get(res, 0) + q
	return issue


# Une salve : chaque véhicule armé tire sur la tête de la file adverse.
# Renvoie false si le joueur n'a plus de munitions.
func _salve(tireurs: Array, cibles: Array, rng: RandomNumberGenerator, L: Array, joueur: bool) -> bool:
	var C: Dictionary = R.combat
	for t in tireurs:
		if t.pv <= 0 or not t.arm:
			continue
		var vivantes := cibles.filter(func(u): return u.pv > 0)
		if vivantes.is_empty():
			return true
		if joueur:
			if stocks.ammo < C.munitions_par_tir:
				return false
			stocks.ammo -= C.munitions_par_tir
		var cible: Dictionary = vivantes[0]
		if rng.randf() >= stat(t.type, "precision"):
			continue
		var deg: float = max(1.0, stat(t.type, "feu") * rng.randf_range(0.8, 1.2) - stat(cible.type, "blindage") * 0.5)
		cible.pv -= deg
		if cible.pv <= 0:
			L.append("%s détruit%s." % [cible.nom, "" if joueur else " par les pillards"])
		elif rng.randf() < C.chance_roulement_touche and cible.roul:
			cible.roul = false
			L.append("%s : roulement touché, immobilisé." % cible.nom)
		elif rng.randf() < C.chance_armement_touche and cible.arm:
			cible.arm = false
			L.append("%s : armement touché, ne tire plus." % cible.nom)
	return true


func _butin(lieu_id: String, cap: float, rng: RandomNumberGenerator, rap: Dictionary) -> void:
	var l: Dictionary = R.lieux[lieu_id]
	var f: float = epuisement[lieu_id]
	for res in l.butin:
		var q := int(rng.randi_range(int(l.butin[res][0]), int(l.butin[res][1])) * f)
		rap.butin[res] = rap.butin.get(res, 0) + q
	var poids: float = 0.0
	for res in rap.butin:
		poids += rap.butin[res] * R.ressources[res].poids
	if poids > cap and poids > 0:
		var k := cap / poids
		for res in rap.butin:
			rap.butin[res] = int(rap.butin[res] * k)
		rap.lignes.append("Chargement plein : une partie du butin reste sur place.")
	var txt := []
	for res in rap.butin:
		_ajouter(res, rap.butin[res])
		txt.append("%d %s" % [rap.butin[res], R.ressources[res].nom.to_lower()])
	rap.lignes.append("BUTIN : " + (", ".join(txt) if txt else "rien") + ".")
	if f < 0.7:
		rap.lignes.append("Le lieu a déjà été fouillé : butin réduit.")
	epuisement[lieu_id] = f * 0.5


# --- Outils -----------------------------------------------------------------

func _ajouter(res: String, q: float) -> void:
	stocks[res] = min(float(R.ressources[res].capacite), stocks[res] + q)


func _journal(lignes: Array) -> void:
	journal.append_array(lignes)
	while journal.size() > 40:
		journal.pop_front()


func perdu() -> bool:
	return survivants.is_empty()


static func _fmt(x: float) -> String:
	return str(int(x)) if is_equal_approx(x, round(x)) else "%.1f" % x
