# Halte du camion (bivouac) : vie de l'équipage pendant un arrêt, de jour comme de nuit. Module pur, sans écran, déterministe.
# Phases : route -> freinage -> descente -> camp -> rappel -> remontee -> demarrage -> route.
# - Descente : chacun sort par sa portière ; la vigie ouvre la trappe et monte sur le toit.
# - Camp : la vigie surveille depuis le toit, les mécaniciens réparent (moteur, roues), le cuisinier allume un feu et cuisine,
#   les autres s'assoient près du feu.
# - Rappel (« Repartir ») : le cuisinier éteint le feu, chacun revient à sa portière et remonte ; la vigie redescend par la trappe,
#   qui se referme. Le camion ne redémarre qu'une fois tout le monde à bord : le départ n'est pas instantané.
# Positions en mètres dans le repère du camion (x vers l'avant, y vers le haut depuis le sol), ancrages de BerlietConfig.ancrages_m.
class_name Bivouac
extends RefCounted

const MARCHE := 1.35          # m/s à pied
const FREIN := 3.0            # m/s² au freinage
const ACCEL := 1.4            # m/s² au démarrage
const ECART_SORTIE := 0.9     # s entre deux équipiers à la même portière
const DUREE_TRAPPE := 0.7     # s pour ouvrir ou fermer la trappe
const MONTEE_TOIT := 1.2      # s pour sortir de la trappe (ou y redescendre)
const HAUTEUR_TRAPPE := 1.5   # m parcourus dans la trappe
const ALLUMAGE := 4.0         # s pour que le feu prenne
const EXTINCTION := 2.5       # s pour l'éteindre

# Équipage par défaut : rôle, silhouette, portière
const EQUIPAGE := [
	{"nom": "Chef", "role": "vigie", "variante": "chef", "porte": "trappe"},
	{"nom": "Mécano", "role": "mecanicien", "variante": "mecano", "porte": "porte_avant", "poste": "moteur"},
	{"nom": "Mécano 2", "role": "mecanicien", "variante": "mecano", "porte": "porte_arriere", "poste": "roue"},
	{"nom": "Cuisinière", "role": "cuisinier", "variante": "survivante", "porte": "porte_arriere"},
	{"nom": "Tireur", "role": "repos", "variante": "tireur", "porte": "porte_arriere"},
]

var phase := "route"
var vitesse := 0.0             # m/s du camion
var vitesse_route := 6.0
var trappe := 0.0              # 0 fermée .. 1 ouverte
var feu := 0.0                 # 0 éteint .. 1 vif
var fumee := 0.0               # fumée du feu qu'on vient d'éteindre
var t := 0.0
var A: Dictionary              # ancrages (m)
var equipiers: Array = []      # {nom, role, variante, porte, poste, x, y, etat, delai, cible, dir, pas, action}


func _init(ancrages: Dictionary, equipage: Array = EQUIPAGE, en_route := true) -> void:
	A = ancrages
	for e in equipage:
		var q: Dictionary = e.duplicate()
		q.merge({"x": _x_porte(q), "y": 0.0, "etat": "a_bord", "delai": 0.0, "cible": 0.0, "dir": 1.0, "pas": 0.0, "action": ""})
		equipiers.append(q)
	if en_route:
		vitesse = vitesse_route


# --- Ordres ---------------------------------------------------------------------------------------------------
func arreter() -> bool:
	if phase not in ["route", "demarrage"]:
		return false
	phase = "freinage"
	return true


func repartir() -> bool:
	if phase not in ["descente", "camp"]:
		return false
	phase = "rappel"
	for q in equipiers:
		_rappeler(q)
	return true


func a_bord() -> int:
	var n := 0
	for q in equipiers:
		if q.etat == "a_bord":
			n += 1
	return n


func dehors() -> int:
	return equipiers.size() - a_bord()


func vigie():
	for q in equipiers:
		if q.role == "vigie":
			return q
	return null


# Portière en cours d'usage (pour l'animer plus tard) : vrai si quelqu'un sort ou entre par elle
func porte_utilisee(porte: String) -> bool:
	for q in equipiers:
		if q.porte == porte and q.etat in ["sort", "monte"]:
			return true
	return false


# --- Simulation --------------------------------------------------------------------------------------------------
func avancer(dt: float) -> void:
	t += dt
	fumee = maxf(0.0, fumee - dt * 0.12)
	match phase:
		"route":
			vitesse = minf(vitesse_route, vitesse + ACCEL * dt)
		"freinage":
			vitesse = maxf(0.0, vitesse - FREIN * dt)
			if vitesse <= 0.0:
				_debut_descente()
		"descente", "camp":
			_camp(dt)
			if phase == "descente" and _tous_postes():
				phase = "camp"
		"rappel", "remontee":
			_rentrer(dt)
		"demarrage":
			vitesse = minf(vitesse_route, vitesse + ACCEL * dt)
			if vitesse >= vitesse_route:
				phase = "route"


func _debut_descente() -> void:
	phase = "descente"
	var par_porte := {}
	for q in equipiers:
		var n: int = par_porte.get(q.porte, 0)
		par_porte[q.porte] = n + 1
		q.delai = 0.4 + ECART_SORTIE * n
		q.etat = "attend"
		q.x = _x_porte(q)
		q.y = A.toit_y - HAUTEUR_TRAPPE if q.porte == "trappe" else 0.0
		q.cible = _x_poste(q)
		q.action = ""


func _camp(dt: float) -> void:
	var v = vigie()
	if v != null and v.etat in ["attend", "sort"]:
		trappe = minf(1.0, trappe + dt / DUREE_TRAPPE)
	for q in equipiers:
		match String(q.etat):
			"attend":
				q.delai -= dt
				if q.delai <= 0.0 and (q.porte != "trappe" or trappe >= 1.0):
					q.etat = "sort"
			"sort":
				if q.porte == "trappe":
					q.y = minf(A.toit_y, q.y + HAUTEUR_TRAPPE / MONTEE_TOIT * dt)
					if q.y >= A.toit_y:
						q.etat = "marche"
				else:
					q.etat = "marche"
			"marche":
				if _marcher(q, dt):
					q.etat = "poste"
					q.action = _action(q)
			"poste":
				_poste(q, dt)
	if v != null and v.etat in ["marche", "poste"]:
		trappe = maxf(0.4, trappe)   # la trappe reste entrouverte pendant la garde


func _poste(q: Dictionary, dt: float) -> void:
	match String(q.role):
		"vigie":
			# fait les cent pas sur le toit et regarde des deux côtés
			q.dir = 1.0 if fmod(t, 8.0) < 4.0 else -1.0
		"cuisinier":
			feu = minf(1.0, feu + dt / ALLUMAGE)
			q.dir = -1.0 if q.x > A.feu else 1.0
		"mecanicien":
			q.dir = 1.0 if q.cible >= q.x else -1.0
		"repos":
			q.dir = 1.0 if A.feu > q.x else -1.0


func _rappeler(q: Dictionary) -> void:
	if q.etat == "a_bord":
		return
	if q.role == "cuisinier" and feu > 0.0:
		q.etat = "eteint"
		q.action = "eteint"
		return
	q.etat = "rentre"
	q.action = ""
	q.cible = A.toit_x if q.porte == "trappe" else _x_porte(q)
	if q.etat == "rentre" and q.porte == "trappe" and q.y < A.toit_y - 0.01:
		q.etat = "descend"   # encore dans la trappe : il redescend directement


func _rentrer(dt: float) -> void:
	for q in equipiers:
		match String(q.etat):
			"attend":
				q.etat = "a_bord"   # pas encore sorti : reste à bord
			"sort", "marche", "poste":
				_rappeler(q)
			"eteint":
				var avant := feu
				feu = maxf(0.0, feu - dt / EXTINCTION)
				if avant > 0.0 and feu <= 0.0:
					fumee = 1.0
				if feu <= 0.0:
					q.etat = "rentre"
					q.action = ""
					q.cible = _x_porte(q)
			"rentre":
				if _marcher(q, dt):
					q.etat = "descend" if q.porte == "trappe" else "monte"
					q.delai = 0.5
			"descend":
				q.y -= HAUTEUR_TRAPPE / MONTEE_TOIT * dt
				if q.y <= A.toit_y - HAUTEUR_TRAPPE:
					q.etat = "a_bord"
			"monte":
				q.delai -= dt
				if q.delai <= 0.0:
					q.etat = "a_bord"
	var v = vigie()
	if v == null or v.etat == "a_bord":
		trappe = maxf(0.0, trappe - dt / DUREE_TRAPPE)
	elif v.etat in ["rentre", "descend"]:
		trappe = 1.0
	phase = "remontee"
	if a_bord() == equipiers.size() and trappe <= 0.0:
		phase = "demarrage"


# Avance vers la cible ; vrai une fois arrivé
func _marcher(q: Dictionary, dt: float) -> bool:
	var d: float = q.cible - q.x
	if absf(d) < 0.02:
		q.x = q.cible
		return true
	var pas := minf(absf(d), MARCHE * dt)
	q.dir = signf(d)
	q.x += pas * q.dir
	q.pas += pas
	return false


func _tous_postes() -> bool:
	for q in equipiers:
		if q.etat != "poste":
			return false
	return true


func _x_porte(q: Dictionary) -> float:
	match String(q.porte):
		"porte_avant":
			return A.porte_avant
		"porte_arriere":
			return A.porte_arriere
		"trappe":
			return A.toit_x
	return A.porte_arriere


func _x_poste(q: Dictionary) -> float:
	match String(q.role):
		"vigie":
			return A.toit_x - 0.3
		"mecanicien":
			if q.get("poste", "") == "roue" and not A.roues_ar.is_empty():
				return float(A.roues_ar[A.roues_ar.size() - 1]) + 0.7
			return A.moteur + 0.6
		"cuisinier":
			return A.feu + 0.7
		"repos":
			return A.feu - 1.0
	return A.feu


func _action(q: Dictionary) -> String:
	match String(q.role):
		"vigie": return "guet"
		"mecanicien": return "repare"
		"cuisinier": return "cuisine"
		"repos": return "assis"
	return ""
