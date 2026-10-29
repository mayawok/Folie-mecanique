# Logique du prototype : état de la partie et règles. Aucun affichage ici.
# Toutes les valeurs viennent de data/regles_proto.json.
#
# Temps réel (système 7, DEC-022) : le monde avance heure par heure.
# « t » est un horodatage Unix (secondes) toujours calé sur une heure pleine.
# À chaque connexion, les heures manquées sont rejouées dans l'ordre
# (rattrapage déterministe), dans la limite de 72 h.
class_name Jeu
extends RefCounted

const POSTES := ["repos", "puits", "cuisine", "atelier"]
const RISQUES := {"faible": "faible", "modere": "modéré", "eleve": "élevé", "critique": "critique"}
const ORDRES := {"eviter": "Éviter le combat", "repli": "Repli à la première perte", "bout": "Jusqu'au bout"}
const H := 3600
const SAUVEGARDE := "user://partie.json"

var R: Dictionary            # règles
var t := 0                   # heure simulée (Unix, heure pleine)
var t_debut := 0             # début de la partie
var derniere_action := 0     # dernière action du joueur (Unix, temps réel)
var decalage := 0            # avance de l'horloge pour les tests (bouton « +6 h »)
var stocks := {}             # ressource -> quantité
var survivants := []         # {nom, femme, poste, blesse_h, occupe_h, malade}
var vehicules := []          # {uid, type, pv, pv_max, etat ("ok"|"epave"), en_route}
var expeditions := []        # convois en cours, résolus à leur retour
var epuisement := {}         # lieu -> facteur de butin (1 = plein)
var etape := 0               # pénurie : 0 aucune, 1 productivité, 2 maladie, 3 agitation
var heures_penurie := 0
var heures_ok := 0
var heures_agitation := 0
var decision := {}           # révolte en attente d'une décision du joueur
var journal := []
var objectif_annonce := false
var _uid := 0


func _init() -> void:
	var f := FileAccess.open("res://data/regles_proto.json", FileAccess.READ)
	R = JSON.parse_string(f.get_as_text())
	if not charger():
		nouvelle_partie()


func maintenant() -> int:
	return int(Time.get_unix_time_from_system()) + decalage


func nouvelle_partie() -> void:
	decalage = 0
	t = maintenant() / H * H
	t_debut = t
	derniere_action = maintenant()
	etape = 0
	heures_penurie = 0
	heures_ok = 0
	heures_agitation = 0
	decision = {}
	objectif_annonce = false
	expeditions = []
	rapports = []
	stocks = R.depart.stocks.duplicate()
	survivants.clear()
	for s in R.depart.survivants:
		survivants.append(_survivant(s.nom, s.femme, s.poste))
	vehicules.clear()
	for ty in R.depart.vehicules:
		ajouter_vehicule(ty)
	for l in R.lieux:
		epuisement[l] = 1.0
	journal = []
	_journal(["Deux survivants, quelques jours de vivres. Il faudra sortir."])
	sauver()


func _survivant(nom: String, femme: bool, poste: String) -> Dictionary:
	return {"nom": nom, "femme": femme, "poste": poste, "blesse_h": 0, "occupe_h": 0, "malade": false}


func ajouter_vehicule(type: String) -> void:
	_uid += 1
	var pv: int = int(R.vehicules[type].pv)
	vehicules.append({"uid": _uid, "type": type, "pv": pv, "pv_max": pv, "etat": "ok", "en_route": false})


func stat(type: String, cle: String):
	return R.vehicules[type][cle]


# --- Horloge ----------------------------------------------------------------

# Numéro du jour : change à minuit, heure locale.
func jour(ts: int = -1) -> int:
	if ts < 0:
		ts = t
	return _jour_local(ts) - _jour_local(t_debut) + 1


func _jour_local(ts: int) -> int:
	return (ts + Time.get_time_zone_from_system().bias * 60) / 86400


func heure_locale(ts: int = -1) -> int:
	if ts < 0:
		ts = t
	var biais: int = Time.get_time_zone_from_system().bias * 60
	return int(Time.get_datetime_dict_from_unix_time(ts + biais).hour)


func est_jour(ts: int = -1) -> bool:
	var h := heure_locale(ts)
	return h >= R.temps.jour_debut_h and h < R.temps.jour_fin_h


func horodatage(ts: int = -1) -> String:
	if ts < 0:
		ts = t
	return "J%d %02d h" % [jour(ts), heure_locale(ts)]


func signaler_action() -> void:
	derniere_action = maintenant()


func avancer_tests(heures: int) -> Dictionary:
	decalage += heures * H
	return rattraper()


# Rejoue les heures écoulées jusqu'à maintenant. Renvoie un bilan si au moins
# une heure (réglable) s'est écoulée : sert au rapport de retour.
func rattraper() -> Dictionary:
	var fin := maintenant() / H * H
	var heures := (fin - t) / H
	if heures <= 0:
		return {}
	var lignes := []
	var max_h: int = int(R.temps.rattrapage_max_h)
	if heures > max_h:
		t = fin - max_h * H
		lignes.append("Absence de plus de %d h : le monde a attendu ton retour." % max_h)
		heures = max_h
	var avant := stocks.duplicate()
	var n_journal := journal.size()
	for i in heures:
		_heure()
	sauver()
	if heures < R.temps.rapport_min_h:
		return {}
	lignes.append_array(journal.slice(n_journal))
	return {"heures": heures, "avant": avant, "apres": stocks.duplicate(), "lignes": lignes}


# --- Une heure de jeu ---------------------------------------------------------

func _heure() -> void:
	var T: Dictionary = R.temps
	var P: Dictionary = R.penurie
	t += H
	var absent: bool = (t - derniere_action) > T.absence_seuil_h * H
	var present: bool = (t - derniere_action) <= T.presence_h * H
	# Production des postes
	var mult: float = P.productivite if etape >= 1 else 1.0
	for s in survivants:
		if not disponible(s):
			continue
		var poste: Dictionary = R.postes[s.poste]
		for res in poste.get("produit", {}):
			_ajouter(res, poste.produit[res] * mult / 24.0)
	# Consommation (eau accrue le jour, réduite pendant une longue absence)
	var manque := false
	for res in R.consommation_par_survivant:
		var besoin: float = R.consommation_par_survivant[res] * survivants.size() / 24.0
		if res == "water_l" and est_jour():
			besoin *= T.eau_jour
		if absent:
			besoin *= T.absence_conso
		if stocks[res] + 0.0001 < besoin:
			manque = true
			stocks[res] = 0.0
		else:
			stocks[res] = max(0.0, stocks[res] - besoin)
	_penurie(manque, present)
	# Survivants : blessures, maladies, absences
	for s in survivants:
		s.blesse_h = max(0, s.blesse_h - 1)
		s.occupe_h = max(0, s.occupe_h - 1)
		if s.blesse_h == 0 and s.malade:
			s.malade = false
			_journal(["%s est guéri(e)." % s.nom])
	# Lieux qui se reconstituent
	for l in epuisement:
		epuisement[l] = min(1.0, epuisement[l] + R.reconstitution_par_jour / 24.0)
	# Atelier : une séance par jour
	if heure_locale() == int(T.heure_atelier):
		for s in survivants:
			if disponible(s) and s.poste == "atelier":
				_journal([_reparer(mult)])
	# Retours d'expédition
	for e in expeditions.duplicate():
		if e.retour <= t:
			expeditions.erase(e)
			_retour(e)
	if jour() > R.objectif_jours and not objectif_annonce:
		objectif_annonce = true
		_journal(["OBJECTIF ATTEINT : la communauté a tenu %d jours." % R.objectif_jours])


func _penurie(manque: bool, present: bool) -> void:
	var P: Dictionary = R.penurie
	if manque:
		heures_ok = 0
		heures_penurie += 1
		if etape == 0:
			etape = 1
			_journal(["PÉNURIE : plus d'eau ou de nourriture. Productivité réduite de moitié."])
		if etape == 1 and heures_penurie >= P.etape2_h:
			etape = 2
			_tomber_malade()
		# L'agitation attend le joueur : jamais pendant son absence.
		if etape == 2 and heures_penurie >= P.etape3_h and present:
			etape = 3
			heures_agitation = int(P.agitation_h)
			_journal(["AGITATION : la faim et la soif poussent certains à la révolte."])
		if etape == 3 and present:
			heures_agitation += 1
			if heures_agitation >= P.agitation_h and decision.is_empty():
				heures_agitation = 0
				_revolte()
	elif etape > 0:
		heures_ok += 1
		if heures_ok >= P.recul_h:
			heures_ok = 0
			etape -= 1
			heures_penurie = 0 if etape == 0 else int([0, 0, P.etape2_h, P.etape3_h][etape])
			if etape == 0:
				_journal(["Fin de la pénurie : retour à la normale."])
			else:
				_journal(["La situation s'améliore (pénurie : étape %d)." % etape])


func _tomber_malade() -> void:
	var dispo := survivants.filter(func(s): return s.occupe_h == 0 and s.blesse_h == 0)
	if dispo.is_empty():
		return
	var s: Dictionary = dispo[(t / H) % dispo.size()]
	s.malade = true
	s.blesse_h = int(R.penurie.maladie_h)
	_journal(["MALADIE : %s, affaibli(e) par les privations, ne peut plus travailler." % s.nom])


func _revolte() -> void:
	var dispo := survivants.filter(func(s): return s.occupe_h == 0)
	if dispo.size() < 2:
		return
	var s: Dictionary = dispo[(t / H) % dispo.size()]
	decision = {"nom": s.nom}
	_journal(["RÉVOLTE : %s refuse de travailler et menace de partir avec des vivres." % s.nom])


# Choix du joueur face à un révolté : "pardonner", "partir" ou "executer".
func decider(choix: String) -> String:
	if decision.is_empty():
		return ""
	var s = null
	for x in survivants:
		if x.nom == decision.nom:
			s = x
	decision = {}
	var txt := ""
	if s == null:
		return txt
	match choix:
		"pardonner":
			txt = "%s reste. Rien n'est réglé : la colère couve toujours." % s.nom
		"partir":
			survivants.erase(s)
			stocks.food = max(0.0, stocks.food - 1)
			txt = "%s quitte la communauté en emportant une ration." % s.nom
		"executer":
			survivants.erase(s)
			heures_agitation = -24   # le calme revient pour un temps
			txt = "%s est exécuté(e). Un silence pesant tombe sur la base." % s.nom
	signaler_action()
	_journal([txt])
	sauver()
	return txt


# --- Base -------------------------------------------------------------------

func disponible(s: Dictionary) -> bool:
	return s.blesse_h == 0 and s.occupe_h == 0


func conso_jour(res: String) -> float:
	var c: float = R.consommation_par_survivant.get(res, 0) * survivants.size()
	if res == "water_l":
		var hj: float = R.temps.jour_fin_h - R.temps.jour_debut_h
		c *= (hj * R.temps.eau_jour + 24.0 - hj) / 24.0
	return c


func autonomie(res: String) -> float:
	var c := conso_jour(res)
	return INF if c <= 0 else stocks[res] / c


# Solde prévu sur une journée (production des postes - consommation).
# Sert à la flèche de tendance à côté de chaque barre de ressource.
func bilan(res: String) -> float:
	var mult: float = R.penurie.productivite if etape >= 1 else 1.0
	var b := 0.0
	for s in survivants:
		if disponible(s):
			b += R.postes[s.poste].get("produit", {}).get(res, 0) * mult
	return b - conso_jour(res)


func affecter(s: Dictionary, poste: String) -> void:
	s.poste = poste
	signaler_action()
	sauver()


func _reparer(mult: float) -> String:
	var at: Dictionary = R.postes.atelier
	for v in vehicules:
		if v.en_route:
			continue
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
# Départ : carburant et vivres réservés, équipage et véhicules partis.
# Le trajet est résolu au retour, X heures plus tard (même en absence).

func vehicules_prets() -> Array:
	return vehicules.filter(func(v): return v.etat == "ok" and not v.en_route)


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
	var b := {"heures": h, "carburant": 0.0, "eau": 0, "vivres": 0, "erreurs": [], "raisons": [], "equipage": []}
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
	b.raisons.append("arrivée de %s : pillards %s" % ["jour" if est_jour(t + int(l.heures * H)) else "nuit",
		"plus fréquents" if est_jour(t + int(l.heures * H)) else "plus rares"])
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
	var b := briefing(lieu_id, convoi)
	if not b.ok:
		return {"ok": false, "erreurs": b.erreurs}
	convoi = ordonner(convoi)
	var eq := equipage_pour(convoi.size())
	stocks.fuel_l -= b.carburant
	stocks.water_l -= b.eau
	stocks.food -= b.vivres
	var e := {"lieu": lieu_id, "pied": false, "ordre": ordre, "depart": t, "retour": t + int(ceil(b.heures)) * H,
		"vehicules": [], "equipage": [], "conso": [b.carburant, b.eau, b.vivres]}
	for i in convoi.size():
		convoi[i].en_route = true
		e.vehicules.append(convoi[i].uid)
		e.equipage.append(eq[i].nom)
		eq[i].occupe_h = int(ceil(b.heures))
	return _partir(e)


func _partir(e: Dictionary) -> Dictionary:
	expeditions.append(e)
	var l: Dictionary = R.lieux[e.lieu]
	_journal(["Départ %s vers %s (%s). Retour prévu %s." % ["à pied" if e.pied else "du convoi", l.nom,
		", ".join(e.equipage), horodatage(e.retour)]])
	signaler_action()
	sauver()
	return {"ok": true}


# Fin d'une expédition : trajet, combat éventuel, butin. Le rapport est rangé
# dans « rapports » pour être montré au joueur.
var rapports := []

func _retour(e: Dictionary) -> void:
	var rap: Dictionary = _resoudre_pied(e) if e.pied else _resoudre(e)
	rap.heure = horodatage(e.retour)
	rapports.append(rap)
	_journal([rap.titre + " : " + {"victoire": "réussite", "repli": "repli", "defaite": "convoi perdu"}[rap.issue] + "."])


func _equipe(e: Dictionary) -> Array:
	var r := []
	for n in e.equipage:
		for s in survivants:
			if s.nom == n:
				r.append(s)
	return r


func _resoudre(e: Dictionary) -> Dictionary:
	var l: Dictionary = R.lieux[e.lieu]
	var rng := RandomNumberGenerator.new()
	rng.seed = e.depart / H * 7919 + hash(e.lieu) + e.vehicules.size()   # même départ = même résultat
	var convoi := []
	for uid in e.vehicules:
		for v in vehicules:
			if v.uid == uid:
				convoi.append(v)
	var eq := _equipe(e)
	for i in convoi.size():
		convoi[i].en_route = false
		convoi[i].equipage = eq[i] if i < eq.size() else {}
	var rap := {"titre": "Expédition : " + l.nom, "lignes": [], "butin": {}, "pillards": [], "convoi": []}
	var L: Array = rap.lignes
	L.append("Convoi : %s. Consommé %d L de carburant, %d L d'eau, %d rations." % [
		", ".join(convoi.map(func(v): return stat(v.type, "nom"))), e.conso[0], e.conso[1], e.conso[2]])
	for ev in R.evenements_trajet:
		if rng.randf() < ev.chance:
			L.append(ev.texte)
			for res in ev.get("perte", {}):
				stocks[res] = max(0, stocks[res] - ev.perte[res])
			for res in ev.get("gain", {}):
				_ajouter(res, ev.gain[res])
	var issue := "victoire"
	var arrivee: int = e.depart + int(l.heures * H)
	var chance: float = l.chance_pillards * (R.temps.pillards_jour if est_jour(arrivee) else R.temps.pillards_nuit)
	if rng.randf() < chance:
		var vit: float = convoi.map(func(v): return stat(v.type, "vitesse")).min()
		if e.ordre == "eviter" and rng.randf() < R.combat.evitement_reussite * vit:
			L.append("Des pillards repérés au loin : le convoi les contourne.")
		else:
			issue = _combat(convoi, R.pillards[l.risque], e.ordre, rng, rap)
	else:
		L.append("Trajet sans rencontre.")
	if issue == "victoire":
		var cap := 0.0
		for v in convoi:
			if v.get("issue", "ok") == "ok":
				cap += stat(v.type, "capacite")
		_butin(e.lieu, cap, rng, rap)
		_recrue(l, rng, L)
	elif issue == "repli":
		L.append("Le convoi rentre les mains vides.")
	for v in convoi:
		rap.convoi.append({"type": v.type, "etat": v.get("issue", "ok")})
		v.erase("equipage")
		v.erase("issue")
	rap.issue = issue
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
	var b := {"heures": h, "erreurs": [], "raisons": []}
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
	var b := briefing_pied(lieu_id, n)
	if not b.ok:
		return {"ok": false, "erreurs": b.erreurs}
	stocks.water_l -= b.eau
	stocks.food -= b.vivres
	var e := {"lieu": lieu_id, "pied": true, "depart": t, "retour": t + int(ceil(b.heures)) * H,
		"vehicules": [], "equipage": [], "conso": [0, b.eau, b.vivres]}
	for s in equipage_pour(n):
		s.occupe_h = int(ceil(b.heures))
		e.equipage.append(s.nom)
	return _partir(e)


func _resoudre_pied(e: Dictionary) -> Dictionary:
	var l: Dictionary = R.lieux[e.lieu]
	var P: Dictionary = R.a_pied
	var rng := RandomNumberGenerator.new()
	rng.seed = e.depart / H * 7919 + hash(e.lieu) + e.equipage.size() * 31 + 17
	var groupe := _equipe(e)
	var rap := {"titre": "À pied : " + l.nom, "lignes": [], "butin": {}, "pillards": [], "convoi": [], "marcheurs": []}
	var L: Array = rap.lignes
	for s in groupe:
		rap.marcheurs.append({"femme": s.femme, "nom": s.nom})
	L.append("Groupe : %s. %d L d'eau et %d rations emportés." % [", ".join(e.equipage), e.conso[1], e.conso[2]])
	var issue := "victoire"
	var arrivee: int = e.depart + int(l.heures * P.facteur_duree * H)
	var chance: float = l.chance_pillards * (R.temps.pillards_jour if est_jour(arrivee) else R.temps.pillards_nuit)
	if rng.randf() < chance:
		if rng.randf() < P.discretion:
			L.append("Des pillards passent tout près : le groupe reste caché jusqu'à leur départ.")
		else:
			issue = "repli"
			L.append("Le groupe est surpris par des pillards et s'enfuit en abandonnant tout.")
			for s in groupe:
				s.blesse_h = int(P.jours_blessure) * 24
				L.append("%s est blessé(e) (%d jours)." % [s.nom, P.jours_blessure])
	else:
		L.append("Marche sans rencontre.")
	if issue == "victoire":
		_butin(e.lieu, e.equipage.size() * P.capacite_par_survivant, rng, rap)
		_recrue(l, rng, L)
	rap.issue = issue
	return rap


func _recrue(l: Dictionary, rng: RandomNumberGenerator, L: Array) -> void:
	if rng.randf() < l.chance_recrue:
		var pris := survivants.map(func(s): return s.nom)
		var libres: Array = R.noms_recrues.filter(func(n): return not pris.has(n))
		if libres.is_empty():
			return
		var nom: String = libres[rng.randi() % libres.size()]
		survivants.append(_survivant(nom, rng.randf() < 0.5, "repos"))
		L.append("RECRUE : %s, survivant(e) isolé(e), rejoint la communauté." % nom)


func _combat(convoi: Array, profil: Array, ordre: String, rng: RandomNumberGenerator, rap: Dictionary) -> String:
	var C: Dictionary = R.combat
	var L: Array = rap.lignes
	var nous := []
	for v in convoi:
		nous.append({"nom": stat(v.type, "nom"), "type": v.type, "pv": float(v.pv), "roul": true, "arm": true, "ref": v})
	var eux := []
	for ty in profil:
		eux.append({"nom": stat(ty, "nom"), "type": ty, "pv": float(stat(ty, "pv")), "roul": true, "arm": true, "ref": null})
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
		if (u.pv <= 0 or perdu) and not v.equipage.is_empty():
			var s: Dictionary = v.equipage
			if issue == "defaite":
				survivants.erase(s)
				L.append("%s n'est pas revenu(e)." % s.nom)
			else:
				s.blesse_h = int(C.jours_blessure) * 24
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
	for ti in tireurs:
		if ti.pv <= 0 or not ti.arm:
			continue
		var vivantes := cibles.filter(func(u): return u.pv > 0)
		if vivantes.is_empty():
			return true
		if joueur:
			if stocks.ammo < C.munitions_par_tir:
				return false
			stocks.ammo -= C.munitions_par_tir
		var cible: Dictionary = vivantes[0]
		if rng.randf() >= stat(ti.type, "precision"):
			continue
		var deg: float = max(1.0, stat(ti.type, "feu") * rng.randf_range(0.8, 1.2) - stat(cible.type, "blindage") * 0.5)
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


# --- Sauvegarde -------------------------------------------------------------
# Un fichier JSON sur l'appareil (sur le Web : stockage du navigateur).

const CHAMPS := ["t", "t_debut", "derniere_action", "decalage", "stocks", "survivants", "vehicules",
	"expeditions", "epuisement", "etape", "heures_penurie", "heures_ok", "heures_agitation",
	"decision", "journal", "objectif_annonce", "_uid", "rapports"]

func sauver() -> void:
	var d := {"version": 1}
	for c in CHAMPS:
		d[c] = get(c)
	var f := FileAccess.open(SAUVEGARDE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))


func charger() -> bool:
	if not FileAccess.file_exists(SAUVEGARDE):
		return false
	var d = JSON.parse_string(FileAccess.get_file_as_string(SAUVEGARDE))
	if typeof(d) != TYPE_DICTIONARY or d.get("version", 0) != 1:
		return false
	for c in CHAMPS:
		if d.has(c):
			set(c, d[c])
	# Le JSON relit les nombres en décimaux : on remet les entiers.
	for c in ["t", "t_debut", "derniere_action", "decalage", "etape", "heures_penurie", "heures_ok", "heures_agitation", "_uid"]:
		set(c, int(get(c)))
	for s in survivants:
		s.blesse_h = int(s.blesse_h)
		s.occupe_h = int(s.occupe_h)
	for v in vehicules:
		v.uid = int(v.uid)
		v.pv = int(v.pv)
		v.pv_max = int(v.pv_max)
	for e in expeditions:
		e.depart = int(e.depart)
		e.retour = int(e.retour)
		e.vehicules = e.vehicules.map(func(u): return int(u))
	return true


func effacer_partie() -> void:
	DirAccess.remove_absolute(SAUVEGARDE)
	nouvelle_partie()


# --- Outils -----------------------------------------------------------------

func _ajouter(res: String, q: float) -> void:
	stocks[res] = min(float(R.ressources[res].capacite), stocks[res] + q)


func _journal(lignes: Array) -> void:
	for l in lignes:
		journal.append("%s · %s" % [horodatage(), l])
	while journal.size() > 40:
		journal.pop_front()


func perdu() -> bool:
	return survivants.is_empty()
