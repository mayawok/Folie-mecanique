# Couche 0 du modèle du convoi : constantes, entités (Veh, Bat), état, création. Aucune logique de dessin.
# Chaîne : modele_base <- modele_tir <- modele_terrain <- combat_modele (CombatModele).
extends RefCounted

const DT := 0.1
const PIECES_BASE := ["chassis", "roulement", "suspension", "moteur", "cabine"]
const NOMS := {"chassis": "Châssis", "roulement": "Roues", "suspension": "Suspension", "moteur": "Moteur", "cabine": "Cabine"}
const FENETRES := {
	"ferme": [[0.22, 0.52], [0.78, 0.52], [0.5, 0.80]],
	"maison": [[0.3, 0.45], [0.7, 0.45], [0.5, 0.78]],
	"grange": [[0.2, 0.5], [0.8, 0.5], [0.5, 0.76]],
	"eglise": [[0.80, 0.78], [0.80, 0.50], [0.30, 0.38]],
	"bunker": [[0.25, 0.40], [0.5, 0.40], [0.75, 0.40]],
	"camp_pillard": [[0.1, 0.66], [0.35, 0.66], [0.65, 0.66], [0.9, 0.66]],
	"camp_fortifie": [[0.08, 0.78], [0.28, 0.78], [0.5, 0.78], [0.72, 0.78], [0.92, 0.78], [0.5, 0.48]],
	"camp_ami": [],
	"hangar": [[0.2, 0.5], [0.8, 0.5], [0.5, 0.78]],
}

static var _data := {}
static func donnees() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open("res://data/combat_proto.json", FileAccess.READ)
		_data = JSON.parse_string(f.get_as_text())
	return _data

static func ancre(v, id: String, x := NAN) -> Vector2:
	var D: Dictionary = VehiculeDessin.donnees().vehicules[v.type]
	var L: float = D.longueur
	var H: float = D.hauteur
	var p := Vector2(L * 0.5, H * 0.4)
	match id:
		"roulement":
			p = Vector2(L * 0.5, 0.4)
		"suspension":
			p = Vector2(L * 0.35, 0.7)
		"moteur":
			p = Vector2(L * 0.85, H * 0.35)
		"cabine":
			p = Vector2(L * 0.45, H * 0.6)
			var eq: Array = D.get("equipage", [])
			if not eq.is_empty():
				p = Vector2(eq[0].x, eq[0].y + 0.5)
		"chassis":
			p = Vector2(L * 0.5, H * 0.3)
		_:
			if id.begins_with("a"):
				var armes: Array = D.get("armes", [])
				var i := int(id.substr(1))
				if i < armes.size():
					p = Vector2(armes[i].x + armes[i].long * 0.4, armes[i].y + armes[i].get("pied", 0.0) * 0.6)
	var vx: float = v.x if is_nan(x) else x
	return Vector2(vx + (L - p.x if v.camp == "ennemi" else p.x), p.y)

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
	var noms: Array = []          # nom de chaque membre (même ordre)
	var statut := "actif"         # actif | abandonne | epave
	var mode := "approche"        # ennemis : approche | barrage
	var tir := true               # joueur : feu libre ou cessez-le-feu
	var reparation := false
	var rep_acc := 0.0
	var rep_pret := 0.0           # délai avant l'arrivée du mécanicien
	var rep_piece := ""           # pièce à réparer (vide = automatique)
	var x_prev := 0.0             # position au pas précédent (affichage fluide)
	var camo_voulu := false
	var garage := 0               # uid du bâtiment où le véhicule est rentré (réparation, à l'abri)
	var camo_t := 0.0
	var camoufle := false
	var x_cible := 0.0
	var vitesse_act := 0.0
	var butin := {}
	var butin_pris := false
	var assemblage := {}          # châssis + pièces placées (DEC-029)

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
	var garnison: Array = []      # survivants postés dans le bâtiment : {pv, cd, veh, premier, garde, slot}
	var revele_t := 0.0           # > 0 : l'ennemi a repéré la garnison
	var butin := {}
	var butin_pris := false
	var ami := false              # camp allié : ne tire pas, ne se cible pas
	var faction := 0
	var garage: Array = []        # uid des véhicules rentrés
	var garage_max := 0
	var barricade := 0.0          # 0..1 : planches clouées aux ouvertures
	var barricade_cible := false
	var blindage_base := 0.0
	var feu := false              # feu allumé à l'intérieur (nuit, garnison barricadée)

	func actif() -> bool:
		return statut == "actif" and not ami

	func fenetre(i: int) -> Vector2:
		var f: Array = CombatModele.FENETRES.get(type, [[0.5, 0.5]])
		var e: Array = f[mini(i, f.size() - 1)]
		return Vector2(x + e[0] * longueur, e[1] * hauteur)

	func garnison_vivants() -> int:
		var n := 0
		for g in garnison:
			if g.pv > 0.0:
				n += 1
		return n

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
var projectiles: Array = []       # balles et obus en vol : {a, b, t, T, touche, zone, ...}
var mines: Array = []             # {x, arme_t, armee}
var transits: Array = []          # équipages en marche vers un bâtiment ou un véhicule
var monde: MondeJeu
var fouille_demandee := 0         # uid du bâtiment ou de l'épave que le joueur veut fouiller
var _lore_dit := false
var _n_noms := 0
var reserve_survivants := 0      # recrues sans place : elles monteront dans le prochain véhicule
var pieces_stock: Array = []     # pièces de véhicule en réserve : {piece, etat} (grille, DEC-035)
var ouverture := false           # début de partie guidé : moto à assembler, trouvailles dans l'ordre
var etape_ouverture := 0         # indice de la prochaine trouvaille de l'ouverture
var en_kit := false              # aucun véhicule encore assemblé
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
	var a := Assemblage.de_type(type)
	assert(not a.is_empty(), "Véhicule sans assemblage : %s" % type)
	return creer_depuis_assemblage(a, camp, x, type)

# Véhicule construit à partir d'un assemblage (châssis + pièces, DEC-029). Profil calculé, jamais saisi.
func creer_depuis_assemblage(a: Dictionary, camp: String, x: float, type := "", equipage := -1) -> Veh:
	var D := donnees()
	var v := Veh.new()
	v.uid = _uid
	_uid += 1
	v.camp = camp
	v.x = x
	v.x_prev = x
	appliquer_assemblage(v, a, {}, type)
	for i in (int(v.profil.equipage) if equipage < 0 else equipage):
		v.equipage.append(float(D.equipage_pv))
		v.noms.append(_nom_survivant())
	return v

# (Re)construit un véhicule à partir d'un assemblage. etats : famille -> état 0..1 des pièces montées
# (pièces abîmées récupérées) ; une famille absente est neuve. L'équipage n'est pas touché.
func appliquer_assemblage(v: Veh, a: Dictionary, etats: Dictionary, type := "") -> void:
	var D := donnees()
	var p := Assemblage.statistiques(a)
	v.assemblage = a.duplicate(true)
	v.type = type if type != "" else Assemblage.apparence(a)
	var forme: Dictionary = VehiculeDessin.donnees().vehicules[v.type]
	v.profil = p
	v.nom = forme.nom
	v.longueur = float(forme.longueur)
	v.chenille = forme.has("chenille")
	v.pieces = {}
	v.armes = []
	for id in PIECES_BASE:
		var pv := float(p.pv[id])
		v.pieces[id] = {"id": id, "nom": NOMS[id], "pv": pv * float(etats.get(id, 1.0)), "max": pv}
	if v.chenille:
		v.pieces.roulement.nom = "Chenilles"
	for i in p.armes.size():
		var wid: String = p.armes[i]
		var w: Dictionary = D.armes[wid]
		var pid := "a%d" % i
		v.pieces[pid] = {"id": pid, "nom": w.nom, "pv": float(w.pv) * float(etats.get("arme", 1.0)), "max": float(w.pv)}
		v.armes.append({"piece": pid, "id": wid, "cd": rng.randf_range(0.4, float(w.cadence)), "idx": i})

const PRENOMS := ["Pierre", "Marie", "Jules", "Léa", "Hugo", "Inès", "Louis", "Camille", "Noé", "Alice", "Paul", "Jeanne", "Marc", "Élise", "Théo", "Sarah", "Émile", "Clara", "Victor", "Nina"]
const INITIALES := "BCDFGLMPRSTV"
func _nom_survivant() -> String:
	_n_noms += 1
	return "%s %s." % [PRENOMS[(_n_noms * 7 + graine) % PRENOMS.size()], INITIALES[(_n_noms * 5 + graine) % INITIALES.length()]]

func _aligner_noms(v: Veh) -> void:
	while v.noms.size() < v.equipage.size():
		v.noms.append(_nom_survivant())
	while v.noms.size() > v.equipage.size():
		v.noms.pop_back()

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
	b.blindage_base = b.blindage
	b.garage_max = int(d.get("garage", 0))
	for i in int(d.tireurs):
		b.tireurs.append({"pv": 12.0, "cd": rng.randf_range(0.5, 1.5), "slot": i})
	var res := {}
	for k in d.butin:
		res[k] = round(rng.randf_range(d.butin[k][0], d.butin[k][1]))
	b.butin = {"ressources": res, "composants": []}
	return b

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
	for p in monde.pietons:
		if p.uid == uid:
			return p
	return null


# --- Pas de simulation -----------------------------------------------------
func _replacer(immediat := false) -> void:
	var gap: float = donnees().ecart_convoi
	var bord := x_tete
	for v in convoi:
		v.x_cible = bord - v.longueur
		bord = v.x_cible - gap
		if immediat:
			v.x = v.x_cible


# --- Lecture pour tests et interface --------------------------------------
func resume() -> String:
	var s := "t=%.0fs x=%.0fm muni=%.0f carb=%.0f metal=%.0f" % [temps, x_tete, stocks.ammo, stocks.fuel_l, stocks.metal]
	for v in convoi:
		s += " | %s ch%.0f ro%.0f" % [v.type, v.pieces.chassis.pv, v.pieces.roulement.pv]
	return s
