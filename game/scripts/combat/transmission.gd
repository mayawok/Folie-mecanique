# Transmission, accélération et freinage du convoi (DEC-232, DEC-233, docs/design/TRANSMISSION.md).
# Module pur, sans écran, déterministe : la vitesse du convoi n'est plus une cible atteinte d'un coup mais un état qui évolue
# selon le rapport engagé, la pente, l'adhérence et le mode de conduite (calme ou urgence).
class_name Transmission
extends RefCounted

static var _data := {}


static func donnees() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open("res://data/transmission.json", FileAccess.READ)
		_data = JSON.parse_string(f.get_as_text())
	return _data


static func etat_neuf() -> Dictionary:
	return {"rapport": 1, "regime": 0.0, "coupure": 0.0, "demarreur": 0.0, "arret_t": 99.0, "urgence": false, "urgence_t": 0.0,
		"accel": 0.0, "air": 0.0, "air_dur": 0.0, "air_prev": 0.0, "glisse": 0.0, "glisse_log": false, "passages": 0, "nb": 5, "moteur_on": false, "evt": "", "collision_t": 0.0}


static func nb_rapports(vtop: float) -> int:
	return 4 if vtop < float(donnees().rapports_5_des) else 5


# Vitesse haute du rapport n (1 = première)
static func plafond(n: int, nb: int, vtop: float) -> float:
	var R: Array = donnees().rapports_4 if nb == 4 else donnees().rapports_5
	return maxf(0.1, vtop * float(R[clampi(n, 1, nb) - 1]))


# Accélération de base d'un véhicule : rapport puissance/poids (kW par tonne), remorques comprises
static func accel_base(puissance_ch: float, poids_kg: float) -> float:
	var D := donnees()
	var kw_t: float = puissance_ch * 0.7355 / maxf(0.2, poids_kg / 1000.0) if puissance_ch > 0.0 else float(D.kw_t_defaut)
	return clampf(float(D.k_accel) * kw_t, float(D.accel_min_base), float(D.accel_max_base))


# Accélération disponible dans le rapport n à la vitesse v : forte en bas, faible en haut, qui s'éteint près du plafond du rapport
static func a_dispo(n: int, nb: int, v: float, vtop: float, a_base: float) -> float:
	var D := donnees()
	var f_rapport := lerpf(float(D.couple_bas), float(D.couple_haut), float(n - 1) / maxf(1.0, float(nb - 1)))
	return a_base * f_rapport * clampf(1.1 - 0.6 * v / plafond(n, nb, vtop), 0.2, 1.1)


# Vitesse maximale d'où l'on peut encore s'arrêter sur dist mètres en freinant à frein m/s²
static func vitesse_sure(dist: float, frein: float) -> float:
	return sqrt(2.0 * frein * float(donnees().securite_freinage) * maxf(0.0, dist))


static func frein_dispo(adh: float, masse_f: float) -> float:
	var D := donnees()
	return float(D.frein) * clampf(adh, float(D.adh_frein_min), 1.0) * clampf(masse_f, 0.5, 1.0)


# Un pas de conduite. P : vtop (vitesse haute du convoi), a_base, pente (positive en montée), adh (0 à 1), masse_f (freinage).
# Rend la nouvelle vitesse. Met à jour T : rapport, régime, accélération, coupure de traction, événement ("monte", "retro").
static func pas(T: Dictionary, v: float, cible: float, dt: float, P: Dictionary) -> float:
	var D := donnees()
	var urg: bool = bool(T.urgence)
	var vtop := maxf(1.0, float(P.vtop))
	var nb := nb_rapports(vtop)
	T.nb = nb
	T.coupure = maxf(0.0, float(T.coupure) - dt)
	T.evt = ""
	var vv := v
	if v < 0.0 or cible < 0.0:   # marche arrière : approche simple, première engagée
		vv = move_toward(v, cible, float(D.recul_accel) * dt)
		T.rapport = 1
	else:
		var n: int = clampi(int(T.rapport), 1, nb)
		var haut := float(D.haut_urgence if urg else D.haut_calme)
		var bas := float(D.bas_urgence if urg else D.bas_calme)
		var a_b := float(P.a_base) * float(D.mult_urgence if urg else D.mult_calme)
		var a_g := 9.81 * float(P.pente) * float(D.part_pente)
		var reg := v / plafond(n, nb, vtop)
		if float(T.coupure) <= 0.0:
			var monte := cible > v + 0.15 and reg >= haut and n < nb
			var retro := false
			if n > 1:
				if reg < bas:
					retro = true
				elif cible > v + 0.15 and a_dispo(n, nb, v, vtop, a_b) - a_g < 0.25 and a_dispo(n - 1, nb, v, vtop, a_b) > a_dispo(n, nb, v, vtop, a_b):
					retro = true   # côte : le rapport inférieur tire mieux
			if monte:
				n += 1
				T.coupure = float(D.coupure_urgence if urg else D.coupure_calme)
				T.evt = "monte"
				T.passages = int(T.passages) + 1
			elif retro:
				n -= 1
				T.coupure = float(D.coupure_retro)
				T.evt = "retro"
				T.passages = int(T.passages) + 1
		T.rapport = n
		if cible > v:
			var a := a_dispo(n, nb, v, vtop, a_b) - a_g
			if float(T.coupure) > 0.0:
				a = -float(D.roue_libre)   # embrayage débrayé : on ne tire plus
			else:
				a = maxf(a, float(D.accel_min))
			vv = minf(cible, v + a * dt) if a > 0.0 else v + a * dt
		elif cible < v:
			var dec: float
			if cible <= 0.05 or v - cible > float(D.seuil_frein_fort):
				dec = frein_dispo(float(P.adh), float(P.masse_f))   # freinage
				if float(P.adh) < float(D.glisse_adh) and v > 5.0 and cible <= 0.05:
					T.glisse = 1.0
			else:
				dec = maxf(0.4, float(D.frein_moteur) + a_g)   # frein moteur (la descente le réduit, la montée l'aide)
			vv = maxf(cible, v - dec * dt)
	var n2 := int(T.rapport)
	var r := absf(vv) / plafond(n2, nb, vtop)
	T.regime = clampf(maxf(float(D.ralenti), r), 0.0, 1.15) * (0.7 if float(T.coupure) > 0.0 else 1.0)
	T.accel = (vv - v) / maxf(dt, 0.0001)
	return vv


# Renversement : la stabilité du véhicule (demi-empattement / hauteur du centre de gravité) contre un virage serré à cette vitesse
static func se_renverse(stabilite: float, v: float) -> bool:
	var D := donnees().demi_tour
	return absf(v) > float(D.vitesse_max) and stabilite < float(D.renverse_stab) * absf(v) / 8.0


# Effet accordéon : un suiveur réagit avec un retard tau à la vitesse h de la tête. u = sa vitesse retardée, e = son écart (m) par
# rapport à sa place : négatif quand la tête accélère (il s'éloigne), positif quand elle freine (il se rapproche) ; l'écart revient à zéro.
static func suiveur(u: float, e: float, h: float, tau: float, dt: float) -> Array:
	var A: Dictionary = donnees().accordeon
	var u2 := u + (h - u) * minf(1.0, dt / maxf(0.05, tau))
	var e2 := clampf(e + ((u2 - h) - e / float(A.retour)) * dt, -float(A.ecart_max), float(A.ecart_max))
	return [u2, e2]
