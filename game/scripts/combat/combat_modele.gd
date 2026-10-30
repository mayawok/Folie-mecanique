# Modèle du mode convoi : un convoi contrôlable avance de profil, affronte des ennemis
# (véhicules, bâtiments) et récupère leur butin. Aucune logique de dessin ici.
# Déterministe : mêmes graine et mêmes ordres = même partie (DEC-018).
# Valeurs dans res://data/combat_proto.json. Mètres : x croît vers la droite (avant du convoi).
class_name CombatModele
extends RefCounted

const DT := 0.1
const PIECES_BASE := ["chassis", "roulement", "suspension", "moteur", "cabine"]
const NOMS := {"chassis": "Châssis", "roulement": "Roues", "suspension": "Suspension", "moteur": "Moteur", "cabine": "Cabine"}

static var _data := {}


static func donnees() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open("res://data/combat_proto.json", FileAccess.READ)
		_data = JSON.parse_string(f.get_as_text())
	return _data


# Espace libre entre deux objets alignés (0 si recouvrement)
static func ecart(ax: float, al: float, bx: float, bl: float) -> float:
	return maxf(0.0, maxf(bx - (ax + al), ax - (bx + bl)))


static func genre_piece(id: String) -> String:
	return "arme" if id.begins_with("a") else id


# --- Entités ---------------------------------------------------------------

class Veh extends RefCounted:
	var uid := 0
	var type := ""
	var nom := ""
	var camp := "joueur"          # joueur | ennemi
	var profil: Dictionary
	var x := 0.0                  # bord arrière (gauche), mètres
	var longueur := 4.0
	var chenille := false
	var pieces := {}              # id -> {id, nom, pv, max}
	var armes: Array = []         # {piece, id, cd}
	var equipage: Array = []      # pv de chaque membre
	var statut := "actif"         # actif | abandonne | epave
	var mode := "approche"        # ennemis : approche | barrage
	var tir := true               # joueur : feu libre ou cessez-le-feu
	var reparation := false
	var rep_acc := 0.0
	var rep_pret := 0.0           # délai avant l'arrivée du mécanicien
	var rep_piece := ""           # pièce à réparer (vide = automatique)
	var x_prev := 0.0             # position au pas précédent (affichage fluide)
	var x_cible := 0.0
	var vitesse_act := 0.0
	var butin := {}
	var butin_pris := false

	func actif() -> bool:
		return statut == "actif"

	# Véhicule laissé sur place mais entier : réparable et récupérable
	func recuperable() -> bool:
		return statut == "abandonne" or statut == "trouvee"

	func piece_ok(id: String) -> bool:
		return pieces.has(id) and pieces[id].pv > 0.0

	func ratio(id: String) -> float:
		return pieces[id].pv / pieces[id].max if pieces.has(id) else 0.0

	func equipage_vivant() -> int:
		var n := 0
		for pv in equipage:
			if pv > 0.0:
				n += 1
		return n

	func mobile() -> bool:
		return actif() and piece_ok("roulement") and piece_ok("moteur")

	func facteur_vitesse() -> float:
		var E: Dictionary = CombatModele.donnees().effets
		var f := 1.0
		if ratio("roulement") < E.seuil_bas:
			f *= E.roulement_bas
		if ratio("moteur") < E.seuil_bas:
			f *= E.moteur_bas
		if not piece_ok("suspension"):
			f *= E.suspension_hs_vitesse
		elif ratio("suspension") < E.seuil_bas:
			f *= E.suspension_bas
		return f

	func vitesse() -> float:
		return profil.vitesse * facteur_vitesse()

	func facteur_precision() -> float:
		var E: Dictionary = CombatModele.donnees().effets
		var f := 1.0
		if not piece_ok("suspension"):
			f *= E.suspension_hs_precision
		elif ratio("suspension") < E.seuil_bas:
			f *= E.suspension_bas_precision
		if not piece_ok("cabine"):
			f *= E.cabine_hs_precision
		return f

	func bord_avant() -> float:
		return x + longueur if camp == "joueur" else x


class Bat extends RefCounted:
	var uid := 0
	var type := ""
	var nom := ""
	var x := 0.0
	var longueur := 8.0           # largeur du bâtiment (même nom que Veh pour les calculs d'écart)
	var hauteur := 4.0
	var pv := 100.0
	var pv_max := 100.0
	var blindage := 5.0
	var tireurs: Array = []       # {pv, cd}
	var arme_fixe := ""
	var cd_fixe := 0.0
	var statut := "actif"         # actif | neutralise
	var butin := {}
	var butin_pris := false

	func actif() -> bool:
		return statut == "actif"

	func tireurs_vivants() -> int:
		var n := 0
		for t in tireurs:
			if t.pv > 0.0:
				n += 1
		return n


# --- État de la partie -----------------------------------------------------

var graine := 1
var rng := RandomNumberGenerator.new()
var temps := 0.0
var fini := false
var convoi: Array = []            # Veh, indice 0 = tête
var ennemis: Array = []
var batiments: Array = []
var epaves: Array = []            # véhicules hors combat, fouillables
var stocks := {"ammo": 0.0, "fuel_l": 0.0, "metal": 0.0}
var composants: Array = []        # {kind, classe, nom, etat}
var ordres := {"marche": "halte", "cible": "proche", "visee": "libre", "fouille": "auto"}
var x_tete := 0.0                 # bord avant du premier véhicule
var x_tete_prev := 0.0
var vitesse_convoi := 0.0
var blocage := ""                 # raison pour laquelle le convoi n'avance pas
var fouille_en_cours := {}
var journal: Array = []           # {t, txt, ton}
var evenements: Array = []        # effets pour la vue : tir, casse, epave, fouille
var distance_max := 0.0
var ennemis_detruits := 0
var _uid := 1
var _prochain_x := 130.0
var _n_rencontres := 0
var _alerte_muni := false
var reserve_survivants := 0      # recrues sans place : elles monteront dans le prochain véhicule


func _init(g := 1) -> void:
	graine = g
	rng.seed = g
	var D := donnees()
	stocks = D.stocks_depart.duplicate()
	for t in D.depart:
		convoi.append(creer_vehicule(t, "joueur", 0.0))
	var bord := 0.0
	for v in convoi:
		bord += v.longueur + D.ecart_convoi
	x_tete = bord - D.ecart_convoi
	_replacer(true)
	x_tete_prev = x_tete
	for v in convoi:
		v.x_prev = v.x
	log_("Une Jeep et deux survivants. Avancez pour trouver de quoi vous équiper.", "info")


func log_(txt: String, ton := "info") -> void:
	journal.append({"t": temps, "txt": txt, "ton": ton})
	if journal.size() > 60:
		journal.pop_front()


func evt(e: Dictionary) -> void:
	evenements.append(e)
	if evenements.size() > 300:
		evenements = evenements.slice(100)


func vider_evenements() -> Array:
	var e := evenements
	evenements = []
	return e


# --- Création --------------------------------------------------------------

func creer_vehicule(type: String, camp: String, x: float) -> Veh:
	var D := donnees()
	var p: Dictionary = D.vehicules[type]
	var forme: Dictionary = VehiculeDessin.donnees().vehicules[type]
	var v := Veh.new()
	v.uid = _uid
	_uid += 1
	v.type = type
	v.camp = camp
	v.profil = p
	v.nom = forme.nom
	v.longueur = float(forme.longueur)
	v.chenille = forme.has("chenille")
	v.x = x
	v.x_prev = x
	for id in PIECES_BASE:
		var pv := float(p.pv[id])
		v.pieces[id] = {"id": id, "nom": NOMS[id], "pv": pv, "max": pv}
	if v.chenille:
		v.pieces.roulement.nom = "Chenilles"
	for i in p.armes.size():
		var wid: String = p.armes[i]
		var w: Dictionary = D.armes[wid]
		var pid := "a%d" % i
		v.pieces[pid] = {"id": pid, "nom": w.nom, "pv": float(w.pv), "max": float(w.pv)}
		v.armes.append({"piece": pid, "id": wid, "cd": rng.randf_range(0.4, float(w.cadence))})
	for i in int(p.equipage):
		v.equipage.append(float(D.equipage_pv))
	return v


func creer_batiment(type: String, x: float) -> Bat:
	var d: Dictionary = donnees().batiments[type]
	var b := Bat.new()
	b.uid = _uid
	_uid += 1
	b.type = type
	b.nom = d.nom
	b.x = x
	b.longueur = d.largeur
	b.hauteur = d.hauteur
	b.pv = float(d.pv)
	b.pv_max = float(d.pv)
	b.blindage = float(d.blindage)
	b.arme_fixe = d.get("arme", "")
	for i in int(d.tireurs):
		b.tireurs.append({"pv": 12.0, "cd": rng.randf_range(0.5, 1.5)})
	var res := {}
	for k in d.butin:
		res[k] = round(rng.randf_range(d.butin[k][0], d.butin[k][1]))
	b.butin = {"ressources": res, "composants": []}
	return b


# Ajoute un véhicule neuf à l'arrière du convoi (tests, récompenses)
func ajouter_vehicule(type: String) -> Veh:
	var v := creer_vehicule(type, "joueur", x_tete - 30.0)
	convoi.append(v)
	_replacer(true)
	v.x_prev = v.x
	return v


func trouver(uid: int):
	for v in convoi:
		if v.uid == uid:
			return v
	for v in ennemis:
		if v.uid == uid:
			return v
	for b in batiments:
		if b.uid == uid:
			return b
	for v in epaves:
		if v.uid == uid:
			return v
	return null


# --- Ordres ----------------------------------------------------------------

func ordre_marche(m: String) -> void:
	if m in ["avancer", "halte", "recul"] and ordres.marche != m:
		ordres.marche = m
		if m != "halte":
			for v in convoi:
				v.reparation = false
			fouille_en_cours = {}


func ordre_cible(c: String) -> void:
	if c in ["proche", "vehicules", "batiments"]:
		ordres.cible = c


func ordre_visee(z: String) -> void:
	if z in ["libre", "roulement", "armement", "chassis"]:
		ordres.visee = z


func ordre_fouille(f: String) -> void:
	if f in ["auto", "arret"]:
		ordres.fouille = f


func ordre_tir(uid: int, actif: bool) -> void:
	var v = trouver(uid)
	if v is Veh and v.camp == "joueur":
		v.tir = actif


func ordre_reparer(uid: int, actif: bool, piece := "") -> bool:
	var v = trouver(uid)
	if not (v is Veh) or not (convoi.has(v) or v.recuperable()):
		return false
	if not actif:
		v.reparation = false
		return true
	if ordres.marche != "halte":
		log_("Réparation impossible en mouvement : ordonnez Halte.", "alerte")
		return false
	if not _mecanicien_possible(v):
		log_("Aucun mécanicien à portée : approchez le convoi.", "alerte")
		return false
	v.reparation = true
	v.rep_piece = piece
	v.rep_pret = 0.0
	v.rep_acc = 0.0
	return true


func _mecanicien_possible(v: Veh) -> bool:
	var F: Dictionary = donnees().fouille
	for c in convoi:
		if c.actif() and c.equipage_vivant() > 0:
			if c == v or convoi.has(v) or ecart(c.x, c.longueur, v.x, v.longueur) <= F.portee:
				return true
	return false


func peut_rejoindre(v: Veh) -> bool:
	return v.recuperable() and v.piece_ok("chassis") and v.piece_ok("roulement") and v.piece_ok("moteur") \
		and ordres.marche == "halte" and _mecanicien_possible(v)


# Un véhicule réparé se joint au convoi avec un survivant à bord
func rejoindre(uid: int) -> bool:
	var v = trouver(uid)
	if not (v is Veh) or not peut_rejoindre(v):
		return false
	epaves.erase(v)
	v.statut = "actif"
	v.camp = "joueur"
	v.reparation = false
	v.tir = true
	v.butin_pris = true
	v.equipage = [float(donnees().equipage_pv)]
	while reserve_survivants > 0 and v.equipage.size() < int(v.profil.equipage):
		v.equipage.append(float(donnees().equipage_pv))
		reserve_survivants -= 1
	v.x_prev = v.x
	for a in v.armes:
		a.cd = 1.0
	convoi.append(v)
	_replacer()
	log_("%s rejoint le convoi." % v.nom, "ok")
	evt({"t": "rejoint", "uid": v.uid})
	return true


func _recruter_survivant() -> bool:
	for v in convoi:
		if v.actif() and v.equipage.size() < int(v.profil.equipage):
			v.equipage.append(float(donnees().equipage_pv))
			return true
	for v in convoi:
		if v.actif():
			for i in v.equipage.size():
				if v.equipage[i] <= 0.0:
					v.equipage[i] = float(donnees().equipage_pv)
					return true
	reserve_survivants += 1   # pas de place : il suivra à pied jusqu'au prochain véhicule
	return true


func monter(uid: int) -> void:
	_deplacer_rang(uid, -1)


func descendre(uid: int) -> void:
	_deplacer_rang(uid, 1)


func _deplacer_rang(uid: int, sens: int) -> void:
	for i in convoi.size():
		if convoi[i].uid == uid:
			var j := i + sens
			if j >= 0 and j < convoi.size():
				var t = convoi[i]
				convoi[i] = convoi[j]
				convoi[j] = t
			return


func abandonner(uid: int) -> void:
	for i in convoi.size():
		var v: Veh = convoi[i]
		if v.uid == uid:
			if convoi.size() <= 1:
				log_("Impossible d'abandonner le dernier véhicule.", "alerte")
				return
			convoi.remove_at(i)
			v.x_prev = v.x
			v.statut = "abandonne"
			v.reparation = false
			v.butin = _butin_vehicule(v, 0.9)
			epaves.append(v)
			log_("%s abandonné : ses pièces peuvent être récupérées." % v.nom, "alerte")
			return


# --- Pas de simulation -----------------------------------------------------

func avancer(dt := DT) -> void:
	if fini:
		return
	temps += dt
	x_tete_prev = x_tete
	for v in convoi + ennemis:
		v.x_prev = v.x
	_marche(dt)
	_ia_ennemis(dt)
	for v in convoi.duplicate():
		if v.actif():
			_armes_vehicule(v, dt)
	for e in ennemis.duplicate():
		if e.actif():
			_armes_vehicule(e, dt)
	for b in batiments:
		if b.actif():
			_armes_batiment(b, dt)
	_reparer(dt)
	_fouiller(dt)
	_rencontres()
	_nettoyer()
	distance_max = maxf(distance_max, x_tete)
	var vivants := 0
	for v in convoi:
		if v.actif():
			vivants += 1
	if vivants == 0:
		fini = true
		log_("Le convoi est anéanti. Distance parcourue : %d m." % int(distance_max), "alerte")


func _replacer(immediat := false) -> void:
	var gap: float = donnees().ecart_convoi
	var bord := x_tete
	for v in convoi:
		v.x_cible = bord - v.longueur
		bord = v.x_cible - gap
		if immediat:
			v.x = v.x_cible


func _marche(dt: float) -> void:
	var vit := 0.0
	blocage = ""
	var actifs: Array = convoi.filter(func(v): return v.actif())
	if ordres.marche != "halte" and not actifs.is_empty():
		var vmax := INF
		var immobilise := false
		for v in actifs:
			vmax = minf(vmax, v.vitesse())
			immobilise = immobilise or not v.mobile()
		if immobilise:
			blocage = "Un véhicule est immobilisé : réparez-le ou abandonnez-le."
		elif stocks.fuel_l <= 0.0:
			blocage = "Panne sèche : plus de carburant."
		elif not fouille_en_cours.is_empty():
			blocage = "Fouille en cours."
		else:
			vit = vmax if ordres.marche == "avancer" else -0.6 * vmax
			if vit > 0.0:
				for e in ennemis:
					if e.actif() and e.x - x_tete < 1.6 and e.x + e.longueur > x_tete - 8.0:
						vit = 0.0
						blocage = "La route est barrée par un véhicule ennemi."
						break
	x_tete += vit * dt
	vitesse_convoi = vit
	if vit != 0.0:
		var litres := 0.0
		for v in actifs:
			litres += v.profil.conso / 100.0 * absf(vit) * dt
		stocks.fuel_l = maxf(0.0, stocks.fuel_l - litres)
	_replacer()
	for v in convoi:
		v.x = move_toward(v.x, v.x_cible, (absf(vit) + 6.0) * dt)
		v.vitesse_act = vit


func _ia_ennemis(dt: float) -> void:
	for e in ennemis:
		e.vitesse_act = 0.0
		if e.actif() and e.mode == "approche" and e.mobile():
			var stand: float = e.profil.get("standoff", 32.0)
			if e.x - x_tete > stand:
				e.x -= e.vitesse() * dt
				e.vitesse_act = e.vitesse()


# --- Tir -------------------------------------------------------------------

func _armes_vehicule(v: Veh, dt: float) -> void:
	if v.equipage_vivant() == 0:
		return
	var D := donnees()
	for a in v.armes:
		a.cd -= dt
		if a.cd > 0.0 or not v.piece_ok(a.piece):
			continue
		var w: Dictionary = D.armes[a.id]
		if v.camp == "joueur":
			if not v.tir:
				a.cd = 0.0
				continue
			if stocks.ammo < w.munitions:
				if not _alerte_muni:
					_alerte_muni = true
					log_("Plus de munitions : récupérez-en sur les épaves.", "alerte")
				a.cd = 0.0
				continue
		var cible = _choisir_cible(v, w)
		if cible == null:
			a.cd = 0.0
			continue
		_tirer(v, a, w, cible)


func _armes_batiment(b: Bat, dt: float) -> void:
	var D := donnees()
	var wf: Dictionary = D.armes.fusil
	for t in b.tireurs:
		t.cd -= dt
		if t.pv > 0.0 and t.cd <= 0.0:
			var cible = _choisir_cible(b, wf)
			if cible == null:
				t.cd = 0.0
			else:
				_tirer(b, t, wf, cible)
	if b.arme_fixe != "" and b.tireurs_vivants() > 0:
		b.cd_fixe -= dt
		if b.cd_fixe <= 0.0:
			var w: Dictionary = D.armes[b.arme_fixe]
			var cible = _choisir_cible(b, w)
			if cible == null:
				b.cd_fixe = 0.0
			else:
				_tirer(b, {"id": b.arme_fixe, "cd": 0.0, "fixe": true}, w, cible)


func _choisir_cible(att, w: Dictionary):
	var joueur: bool = att is Veh and att.camp == "joueur"
	if not joueur:
		# Ennemis : tirent sur le convoi, en priorité sur les véhicules de tête
		var poids := []
		var cands := []
		var rang := 0
		for v in convoi:
			if v.actif():
				if ecart(att.x, att.longueur, v.x, v.longueur) <= w.portee:
					cands.append(v)
					poids.append(1.0 / (1.0 + rang))
				rang += 1
		if cands.is_empty():
			return null
		var total := 0.0
		for p in poids:
			total += p
		var r := rng.randf() * total
		for i in cands.size():
			r -= poids[i]
			if r <= 0.0:
				return cands[i]
		return cands[cands.size() - 1]
	var meilleur = null
	var score_min := INF
	for e in ennemis:
		if not e.actif():
			continue
		if w.classe == "mitrailleuse" and e.profil.blindage > 25.0:
			continue   # la mitrailleuse ne perce pas un blindé : on économise les munitions
		var g := ecart(att.x, att.longueur, e.x, e.longueur)
		if g > w.portee:
			continue
		var s := g + (1000.0 if ordres.cible == "batiments" else 0.0)
		if s < score_min:
			score_min = s
			meilleur = e
	for b in batiments:
		if not b.actif():
			continue
		var g := ecart(att.x, att.longueur, b.x, b.longueur)
		if g > w.portee:
			continue
		var s := g + (1000.0 if ordres.cible == "vehicules" else 0.0)
		if s < score_min:
			score_min = s
			meilleur = b
	return meilleur


func _tirer(att, a: Dictionary, w: Dictionary, cible) -> void:
	var joueur: bool = att is Veh and att.camp == "joueur"
	var Z: Dictionary = donnees().zones
	if joueur:
		stocks.ammo -= w.munitions
		_alerte_muni = false
	var cd: float = w.cadence * rng.randf_range(0.9, 1.1)
	if a.has("fixe"):
		att.cd_fixe = cd
	else:
		a.cd = cd
	var g := ecart(att.x, att.longueur, cible.x, cible.longueur)
	var visee: String = ordres.visee if joueur else "libre"
	var chance: float = w.precision * clampf(1.25 - 0.6 * g / w.portee, 0.45, 1.0)
	if att is Veh:
		chance *= att.facteur_precision()
	if visee != "libre":
		chance *= Z.visee_precision
	if cible is Bat:
		chance = minf(0.95, chance * 1.2)
	var touche := rng.randf() < chance
	var zone := ""
	if touche:
		if cible is Veh:
			zone = _toucher_vehicule(att, w, cible, visee)
		else:
			zone = _toucher_batiment(w, cible, visee)
	var x0: float = att.bord_avant() if att is Veh else (att.x + att.longueur * (0.0 if cible.x < att.x else 1.0))
	evt({"t": "tir", "de": att.uid, "vers": cible.uid, "x0": x0, "classe": w.classe, "touche": touche, "zone": zone})


func _zone(v: Veh, visee: String) -> String:
	var Z: Dictionary = donnees().zones
	var ids := []
	var poids := []
	for id in v.pieces:
		if v.pieces[id].pv > 0.0:
			ids.append(id)
			poids.append(Z.poids[genre_piece(id)])
	if visee != "libre":
		var groupe := []
		for id in ids:
			if (visee == "roulement" and id == "roulement") or (visee == "armement" and id.begins_with("a")) or (visee == "chassis" and id == "chassis"):
				groupe.append(id)
		if not groupe.is_empty() and rng.randf() < Z.visee_chance:
			return groupe[rng.randi() % groupe.size()]
	var total := 0.0
	for p in poids:
		total += p
	var r := rng.randf() * total
	for i in ids.size():
		r -= poids[i]
		if r <= 0.0:
			return ids[i]
	return ids[ids.size() - 1]


func _toucher_vehicule(att, w: Dictionary, v: Veh, visee: String) -> String:
	var D := donnees()
	var Z: Dictionary = D.zones
	var E: Dictionary = D.effets
	var zone := _zone(v, visee)
	var genre := genre_piece(zone)
	var arm: float = v.profil.blindage * Z.blindage_zone[genre]
	if genre == "cabine" and v.profil.ouvert:
		arm *= 0.1
	var d: float = w.degats * w.penetration / (w.penetration + arm)
	var p: Dictionary = v.pieces[zone]
	var avant: float = p.pv
	p.pv = maxf(0.0, p.pv - d)
	if w.classe == "canon" and zone != "chassis":
		v.pieces.chassis.pv = maxf(0.0, v.pieces.chassis.pv - d * 0.25)
	var dc := 0.0
	if genre == "cabine":
		dc = d * 0.9
	elif not v.piece_ok("cabine"):
		dc = d * E.cabine_hs_equipage
	if dc > 0.0:
		_blesser_equipage(v, dc)
	if avant > 0.0 and p.pv <= 0.0 and zone != "chassis":
		evt({"t": "casse", "uid": v.uid, "piece": zone})
		if v.camp == "joueur":
			log_("%s : %s détruit(e)." % [v.nom, p.nom], "alerte")
	if v.pieces.chassis.pv <= 0.0:
		_detruire(v)
	elif v.equipage_vivant() == 0 and v.actif():
		_neutraliser(v)
	return zone


func _blesser_equipage(v: Veh, d: float) -> void:
	var vivants := []
	for i in v.equipage.size():
		if v.equipage[i] > 0.0:
			vivants.append(i)
	if vivants.is_empty():
		return
	var i: int = vivants[rng.randi() % vivants.size()]
	v.equipage[i] = maxf(0.0, v.equipage[i] - d)
	if v.equipage[i] <= 0.0 and v.camp == "joueur":
		log_("%s : un membre d'équipage est hors de combat." % v.nom, "alerte")


func _toucher_batiment(w: Dictionary, b: Bat, visee: String) -> String:
	var d: float = w.degats * w.penetration / (w.penetration + b.blindage)
	var zone := "structure"
	if w.classe == "canon":
		b.pv = maxf(0.0, b.pv - d)
		_blesser_tireur(b, d * 0.6)   # l'éclat de l'obus blesse les tireurs
	elif b.tireurs_vivants() > 0 and (visee in ["libre", "armement"]) :
		_blesser_tireur(b, w.degats)
		zone = "tireur"
	else:
		b.pv = maxf(0.0, b.pv - d)
	if b.pv <= 0.0:
		for t in b.tireurs:
			t.pv = 0.0
	if b.actif() and (b.pv <= 0.0 or b.tireurs_vivants() == 0):
		b.statut = "neutralise"
		ennemis_detruits += 1
		b.butin.composants = []
		log_("%s neutralisé : fouillez-le pour récupérer le butin." % b.nom, "ok")
		evt({"t": "epave", "uid": b.uid})
	return zone


func _blesser_tireur(b: Bat, d: float) -> void:
	for t in b.tireurs:
		if t.pv > 0.0:
			t.pv = maxf(0.0, t.pv - d)
			return


func _detruire(v: Veh) -> void:
	v.statut = "epave"
	v.reparation = false
	for id in v.pieces:
		v.pieces[id].pv *= 0.5
	v.pieces.chassis.pv = 0.0
	for i in v.equipage.size():
		v.equipage[i] = 0.0
	v.butin = _butin_vehicule(v, 0.4)
	_sortir_du_combat(v)
	evt({"t": "epave", "uid": v.uid})
	if v.camp == "joueur":
		log_("%s est détruit !" % v.nom, "alerte")
	else:
		ennemis_detruits += 1
		log_("%s ennemi détruit." % v.nom, "ok")


func _neutraliser(v: Veh) -> void:
	v.statut = "abandonne"
	v.butin = _butin_vehicule(v, 0.8)
	_sortir_du_combat(v)
	evt({"t": "epave", "uid": v.uid})
	if v.camp == "joueur":
		log_("L'équipage de %s est hors de combat : le véhicule est perdu." % v.nom, "alerte")
	else:
		ennemis_detruits += 1
		log_("%s ennemi neutralisé : réparable et récupérable." % v.nom, "ok")


func _sortir_du_combat(v: Veh) -> void:
	v.x_prev = v.x
	convoi.erase(v)
	ennemis.erase(v)
	epaves.append(v)


func _butin_vehicule(v: Veh, facteur: float) -> Dictionary:
	var res := {
		"metal": round(v.profil.metal * facteur),
		"fuel_l": round(rng.randf_range(0.3, 1.0) * v.profil.reservoir * facteur),
		"ammo": round(rng.randf_range(6.0, 18.0) * v.armes.size() * facteur),
	}
	var comps := []
	for id in v.pieces:
		if id == "chassis":
			continue
		var p: Dictionary = v.pieces[id]
		var etat: float = p.pv / p.max
		if etat >= 0.15:
			var classe := ""
			if id.begins_with("a"):
				classe = donnees().armes[v.profil.armes[int(id.substr(1))]].classe
			comps.append({"kind": genre_piece(id), "classe": classe, "nom": "%s (%s)" % [p.nom, v.nom], "etat": etat})
	return {"ressources": res, "composants": comps}


# --- Réparation ------------------------------------------------------------

func _piece_a_reparer(v: Veh) -> String:
	if v.rep_piece != "":
		var p0 = v.pieces.get(v.rep_piece)
		return v.rep_piece if p0 != null and p0.pv < p0.max - 0.5 else ""
	var ordre := ["roulement", "moteur"]
	for p in v.pieces:
		if p.begins_with("a"):
			ordre.append(p)
	ordre.append_array(["suspension", "cabine", "chassis"])
	for id in ordre:
		if v.pieces[id].pv < v.pieces[id].max - 0.5:
			return id
	return ""


func _reparer(dt: float) -> void:
	if ordres.marche != "halte":
		return
	var R: Dictionary = donnees().reparation
	for v in convoi + epaves:
		if not v.reparation:
			continue
		if not _mecanicien_possible(v):
			v.reparation = false
			continue
		v.rep_pret += dt
		if v.rep_pret < R.delai_depart:
			continue
		var id := _piece_a_reparer(v)
		if id == "":
			v.reparation = false
			v.rep_acc = 0.0
			v.rep_piece = ""
			log_("%s : réparations terminées." % v.nom, "ok")
			evt({"t": "repare", "uid": v.uid})
			continue
		var p: Dictionary = v.pieces[id]
		if p.pv <= 0.0:
			v.rep_acc += dt
			if v.rep_acc < R.delai_piece_s:
				continue
			v.rep_acc = 0.0
			var idx := _composant_pour(v, id)
			if idx >= 0:
				var c: Dictionary = composants[idx]
				composants.remove_at(idx)
				p.pv = maxf(1.0, c.etat * p.max)
				log_("%s : %s remplacé(e) par une pièce récupérée." % [v.nom, p.nom], "ok")
			elif stocks.metal >= R.metal_bricolage:
				stocks.metal -= R.metal_bricolage
				p.pv = R.etat_bricolage * p.max
				log_("%s : %s rafistolé(e) avec du métal." % [v.nom, p.nom], "info")
			else:
				v.reparation = false
				log_("%s : ni pièce de rechange, ni assez de métal pour %s." % [v.nom, p.nom], "alerte")
		else:
			var gain: float = R.pv_par_s * dt
			var cout: float = gain * R.metal_par_pv
			if stocks.metal < cout:
				v.reparation = false
				log_("Plus de métal pour réparer %s." % v.nom, "alerte")
			else:
				stocks.metal -= cout
				p.pv = minf(p.max, p.pv + gain)


func _composant_pour(v: Veh, id: String) -> int:
	var meilleur := -1
	var e_max := -1.0
	for i in composants.size():
		var c: Dictionary = composants[i]
		var ok := false
		if id.begins_with("a"):
			var classe: String = donnees().armes[v.profil.armes[int(id.substr(1))]].classe
			ok = c.kind == "arme" and c.classe == classe
		else:
			ok = c.kind == id
		if ok and c.etat > e_max:
			e_max = c.etat
			meilleur = i
	return meilleur


# --- Fouille ---------------------------------------------------------------

func menace() -> bool:
	var F: Dictionary = donnees().fouille
	for e in ennemis:
		if e.actif() and absf(e.x - x_tete) < F.menace_distance:
			return true
	for b in batiments:
		if b.actif() and ecart(x_tete - 1.0, 1.0, b.x, b.longueur) < F.menace_distance * 0.75:
			return true
	return false


func a_fouiller():
	var F: Dictionary = donnees().fouille
	var meilleur = null
	var g_min := INF
	var cands: Array = []
	for v in epaves:
		if not v.butin_pris:
			cands.append(v)
	for b in batiments:
		if b.statut == "neutralise" and not b.butin_pris:
			cands.append(b)
	for c in cands:
		for v in convoi:
			if v.actif():
				var g := ecart(v.x, v.longueur, c.x, c.longueur)
				if g <= F.portee and g < g_min:
					g_min = g
					meilleur = c
	return meilleur


func _fouiller(dt: float) -> void:
	var F: Dictionary = donnees().fouille
	if fouille_en_cours.is_empty():
		var peut: bool = ordres.marche == "halte" or (ordres.marche == "avancer" and ordres.fouille == "auto")
		if peut and not menace():
			var c = a_fouiller()
			if c != null:
				fouille_en_cours = {"uid": c.uid, "restant": F.duree_base, "total": F.duree_base}
				evt({"t": "fouille", "uid": c.uid})
	else:
		if menace() or ordres.marche == "recul":
			fouille_en_cours = {}
			log_("Fouille interrompue.", "alerte")
			return
		fouille_en_cours.restant -= dt
		if fouille_en_cours.restant <= 0.0:
			var c = trouver(fouille_en_cours.uid)
			fouille_en_cours = {}
			if c != null:
				_recolter(c)


func _recolter(c) -> void:
	c.butin_pris = true
	var res: Dictionary = c.butin.ressources
	var morceaux := []
	var noms := {"ammo": "munitions", "fuel_l": "L carburant", "metal": "métal"}
	for k in res:
		if res[k] <= 0:
			continue
		if k == "survivants":
			for i in int(res[k]):
				if _recruter_survivant():
					morceaux.append("un survivant se joint à vous")
		else:
			stocks[k] = stocks.get(k, 0.0) + res[k]
			morceaux.append("+%d %s" % [int(res[k]), noms.get(k, k)])
	# Les pièces ne se prennent que sur les épaves détruites ; un véhicule entier se répare
	var comps: Array = c.butin.composants if (c is Bat or c.statut == "epave") else []
	for comp in comps:
		composants.append(comp)
		morceaux.append("%s %d %%" % [comp.nom, int(comp.etat * 100)])
	if composants.size() > 20:
		composants = composants.slice(composants.size() - 20)
	log_("Butin : " + (", ".join(morceaux) if not morceaux.is_empty() else "rien d'utile."), "ok")
	evt({"t": "butin", "uid": c.uid})


# --- Rencontres ------------------------------------------------------------

func _rencontres() -> void:
	if x_tete + 80.0 < _prochain_x or ennemis.size() >= 5:
		return
	var R: Dictionary = donnees().rencontres
	_n_rencontres += 1
	var r := RandomNumberGenerator.new()
	r.seed = graine * 7919 + _n_rencontres
	var niveau := int(_prochain_x / R.palier_m)
	var liste := []
	var total := 0.0
	for e in R.liste:
		if niveau >= e.niveau_min and niveau <= e.niveau_max:
			liste.append(e)
			total += e.poids
	var tirage := r.randf() * total
	var choix: Dictionary = liste[liste.size() - 1]
	for e in liste:
		tirage -= e.poids
		if tirage <= 0.0:
			choix = e
			break
	if _n_rencontres == 1 and R.has("premiere"):
		choix = R.premiere
	var x := x_tete + 80.0
	var debut := x
	for t in choix.get("vehicules", []):
		var e := creer_vehicule(t, "ennemi", x)
		e.mode = choix.get("mode", "approche")
		ennemis.append(e)
		x += e.longueur + r.randf_range(5.0, 12.0)
	for bt in choix.get("batiments", []):
		var b := creer_batiment(bt, x + r.randf_range(4.0, 14.0))
		batiments.append(b)
		x = b.x + b.longueur
	for t in choix.get("trouvailles", []):
		var f := creer_vehicule(t, "joueur", x)
		f.statut = "trouvee"
		f.equipage = []
		var casses := 0
		for id in f.pieces:
			if id != "chassis" and r.randf() < 0.5:
				var q := 0.0 if r.randf() < 0.5 else r.randf_range(0.1, 0.7)
				f.pieces[id].pv = f.pieces[id].max * q
				casses += 1
		if casses == 0:
			f.pieces.roulement.pv = 0.0
		f.butin = _butin_vehicule(f, 0.6)
		epaves.append(f)
		x += f.longueur + 6.0
	if choix.has("ruine"):
		var b := creer_batiment(choix.ruine, x + r.randf_range(2.0, 10.0))
		b.statut = "neutralise"
		b.pv = b.pv_max * 0.35
		for t in b.tireurs:
			t.pv = 0.0
		b.butin.ressources["survivants"] = 1 if (choix.get("survivant", false) or r.randf() < 0.4) else 0
		batiments.append(b)
		x = b.x + b.longueur
	var hostile := not ennemis.is_empty() or batiments.any(func(b): return b.actif())
	evt({"t": "contact", "ennemi": hostile})
	log_("%s à %d m." % ["Contact" if hostile else "Du nouveau", int(debut - x_tete)], "info")
	_prochain_x = x + r.randf_range(R.intervalle[0], R.intervalle[1])


func _nettoyer() -> void:
	var limite := x_tete - 260.0
	epaves = epaves.filter(func(v): return v.x + v.longueur > limite)
	batiments = batiments.filter(func(b): return b.x + b.longueur > limite)


# --- Lecture pour tests et interface --------------------------------------

func resume() -> String:
	var s := "t=%.0fs x=%.0fm muni=%.0f carb=%.0f metal=%.0f" % [temps, x_tete, stocks.ammo, stocks.fuel_l, stocks.metal]
	for v in convoi:
		s += " | %s ch%.0f ro%.0f" % [v.type, v.pieces.chassis.pv, v.pieces.roulement.pv]
	return s
