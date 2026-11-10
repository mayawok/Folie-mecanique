# Monde autour du convoi : carte et secteurs, cycle jour/nuit, abri et barricades, fantassins et animaux,
# camps (hostiles, fortifiés ou alliés, annoncés de loin), voyageurs qui offrent des échanges et des quêtes.
# Logique pure et déterministe (utilise le générateur du modèle) ; testable sans écran.
class_name MondeJeu
extends RefCounted

const JOUR_S := 400.0
const HEURE_DEBUT := 0.30     # matin
const CREPUSCULE := 0.62
const AUBE := 0.95
const FACTIONS := {1: "Faction 1", 2: "Faction 2", 3: "Faction 3"}
const ATTITUDE := {1: "ami", 2: "neutre", 3: "hostile"}   # relation du joueur avec chaque faction
const PREFIXES := ["Fort-", "Mont-", "Val-", "Port-", "Pont-", "Croix-", "Sainte-", "Haut-", "", ""]
const RACINES := ["Cendre", "Verdun", "Brume", "Sable", "Rouille", "Lorne", "Marne", "Orme", "Fer", "Gris", "Acier", "Corbeau", "Épave", "Vigie"]


class Pieton:
	var uid := 0
	var type := "pillard"
	var camp := "ennemi"
	var x := 0.0
	var x_prev := 0.0
	var longueur := 0.7
	var hauteur := 1.7
	var pv := 10.0
	var pv_max := 10.0
	var vit := 2.3
	var portee := 28.0
	var animal := false
	var statut := "actif"      # actif | mort
	var mort_t := 0.0
	var but := 0                # uid de la cible visée
	var arme := {"cd": 1.0}
	var morsure := 2.5
	var dir := -1.0
	var ecrase_t := 0.0
	var veh := 0                # soldat : uid de son véhicule
	var mode := "pose"          # soldat : pose | retour
	var calme_t := 0.0
	var slot := 0

	func actif() -> bool:
		return statut == "actif"


var m                          # CombatModele
var secteurs: Array = []       # {id, nom, pos: Vector2 (0..1), niveau, faction}
var secteur := 0               # secteur actuel
var secteur_prec := -1         # secteur d'où l'on vient : sortie « retour » des villes (DEC-168)
var x_entree := 0.0            # abscisse d'entrée dans le secteur
var trajet := {}               # {dest, reste, total} : zone calme entre deux secteurs
var heure := HEURE_DEBUT
var jour := 1
var pietons: Array = []
var pnj: Array = []            # {uid, x, type, nom, offre, statut, peau}
var dialogue := {}             # {pnj: uid}
var quete := {}                # {titre, abattre, depart, recompense}
var repos_t := 0.0             # > 0 : l'équipage se repose dans un camp allié
var _assaut_t := 40.0
var oiseau := {}               # oiseau en vol (DEV-004, DEC-097) : {t, duree, x0, y} ; vide = aucun
var _oiseau_t := -1.0          # délai avant le prochain oiseau (-1 = à tirer)
var _rng_oiseau: RandomNumberGenerator   # générateur propre : ne décale pas les tirages du combat
var _crep_fait := false
var _aube_fait := false
var _marteau_t := 0.0
var _uid := 90000


func _init(modele) -> void:
	m = modele
	_generer_carte()
	x_entree = m.x_tete


# --- Carte -----------------------------------------------------------------

func _generer_carte() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = m.graine * 31 + 7
	var noms := {}
	for i in 12:
		var col := i % 4
		var lig := i / 4
		var pos := Vector2(0.12 + 0.25 * col + r.randf_range(-0.07, 0.07), 0.2 + 0.3 * lig + r.randf_range(-0.07, 0.07))
		var nom := ""
		while nom == "" or noms.has(nom):
			nom = PREFIXES[r.randi() % PREFIXES.size()] + RACINES[r.randi() % RACINES.size()]
		noms[nom] = true
		secteurs.append({"id": i, "nom": nom, "pos": pos, "niveau": 0, "faction": 1 + r.randi() % 3})
	# Départ : le secteur le plus au sud-ouest
	var depart := 0
	var d_min := INF
	for s in secteurs:
		var d: float = s.pos.distance_to(Vector2(0.1, 0.85))
		if d < d_min:
			d_min = d
			depart = s.id
	secteur = depart
	for s in secteurs:
		var dd: float = s.pos.distance_to(secteurs[depart].pos)
		s.niveau = clampi(int(round(dd * 8.0 + r.randf_range(-0.7, 0.7))), 0, 7)
	secteurs[depart].niveau = 0
	secteurs[depart].faction = 1
	secteurs[depart].nom = "Les Cendres"


func niveau_a(x: float) -> int:
	var R: Dictionary = CombatModele.donnees().rencontres
	var bonus := 5 if m.bac_a_sable else 0   # bac à sable : les chars arrivent vite (DEC-053)
	return int(secteurs[secteur].niveau) + bonus + m.malus_hors_region() + int(maxf(0.0, x - x_entree) / R.palier_m)


func en_transit() -> bool:
	return not trajet.is_empty()


func distance_secteur(id: int) -> float:
	return secteurs[secteur].pos.distance_to(secteurs[id].pos)


func choisir_destination(id: int) -> bool:
	if id < 0 or id >= secteurs.size() or id == secteur or (en_transit() and trajet.dest == id):
		return false
	var total := 250.0 + distance_secteur(id) * 900.0
	trajet = {"dest": id, "reste": total, "total": total}
	m._prochain_x = INF
	var route := "de route" if m.mission_active() else "de route calme"   # en mission, la route est dangereuse (DEC-146)
	m.log_("Cap sur %s (%s, niveau %d) : %d m %s." % [secteurs[id].nom, FACTIONS[secteurs[id].faction], secteurs[id].niveau, int(total), route], "info")
	m.evt({"t": "cap"})
	return true


# --- Horloge, nuit, abri ---------------------------------------------------

func obscurite() -> float:
	var h := heure
	if h < CREPUSCULE - 0.04:
		return 0.0
	if h < CREPUSCULE + 0.06:
		return smoothstep(CREPUSCULE - 0.04, CREPUSCULE + 0.06, h)
	if h < AUBE - 0.04:
		return 1.0
	return 1.0 - smoothstep(AUBE - 0.04, AUBE + 0.04, h) if h < AUBE + 0.04 else 0.0


func nuit() -> bool:
	return obscurite() > 0.5


func periode() -> String:
	if heure < 0.2:
		return "Aube"
	if heure < 0.5:
		return "Matin"
	if heure < CREPUSCULE:
		return "Après-midi"
	if heure < 0.72:
		return "Soir"
	return "Nuit" if heure < AUBE else "Aube"


func a_abri() -> bool:
	for b in m.batiments:
		if b.garnison_vivants() > 0 or m._en_route(b) > 0:
			return true
	return false


func _tout_abrite() -> bool:
	for v in m.convoi:
		if v.equipage_vivant() > 0:
			return false
	for b in m.batiments:
		if b.garnison_vivants() > 0:
			return true
	return false


func alerte_nuit() -> bool:
	return heure >= CREPUSCULE - 0.02 and heure < AUBE and not _tout_abrite() and repos_t <= 0.0 and not m.ville_protegee() and not m.ville_calme()


func _facteur_temps() -> float:
	if nuit() and (_tout_abrite() or repos_t > 0.0 or m.halte_repos()):
		return 3.0
	return 1.0


func camp_proche():
	for b in m.batiments:
		if b.ami and CombatModele.ecart(m.x_tete - 1.0, 1.0, b.x, b.longueur) < 24.0:
			return b
	return null


func ordre_nuit() -> bool:
	m.ordre_marche("halte")
	var n := 0
	for v in m.convoi.duplicate():
		if m.ordre_debarquer(v.uid):
			n += 1
		m.ordre_camoufler(v.uid, true)
	for b in m.batiments:
		if b.statut == "neutralise" and (b.garnison.size() > 0 or m._en_route(b) > 0):
			b.barricade_cible = true
	if n == 0:
		m.log_("Aucun bâtiment à portée : approchez-vous d'une ruine ou d'une église.", "alerte")
		return false
	m.log_("L'équipage s'abrite et barricade le bâtiment pour la nuit.", "info")
	return true


func abri_proche() -> Dictionary:
	var meilleur := {}
	var g_min := INF
	for b in m.batiments:
		if b.statut == "neutralise" and b.pv > 0.0 and b.x + b.longueur > m.x_tete - 120.0:
			var g: float = CombatModele.ecart(m.x_tete - 1.0, 1.0, b.x, b.longueur)
			if g < g_min:
				g_min = g
				meilleur = {"nom": b.nom, "dist": g, "devant": b.x > m.x_tete}
	return meilleur


# --- Boucle ----------------------------------------------------------------

func avancer(dt: float) -> void:
	_horloge(dt)
	_cap(dt)
	_batiments(dt)
	_assauts(dt)
	_oiseau(dt)
	_pietons(dt)
	_voyageurs(dt)
	_quete()
	repos_t = maxf(0.0, repos_t - dt)


# Un oiseau traverse le ciel, rarement et seulement de jour (DEC-097 : « voir un oiseau est un événement rare, mis en valeur »).
# Délai tiré avec le générateur du modèle (graine de la partie) ; valeurs dans combat_proto.json → oiseau.
func _oiseau(dt: float) -> void:
	var O: Dictionary = m.donnees().get("oiseau", {})
	if O.is_empty():
		return
	if not oiseau.is_empty():
		oiseau.t += dt
		if oiseau.t >= oiseau.duree:
			oiseau = {}
		return
	if _rng_oiseau == null:
		_rng_oiseau = RandomNumberGenerator.new()
		_rng_oiseau.seed = int(m.graine) * 977 + 1
	if _oiseau_t < 0.0:
		_oiseau_t = _rng_oiseau.randf_range(float(O.delai_min_s), float(O.delai_max_s))
	if nuit() or m.tempete_active():
		return
	_oiseau_t -= dt
	if _oiseau_t > 0.0:
		return
	_oiseau_t = -1.0
	oiseau = {"t": 0.0, "duree": float(O.duree_s), "x0": m.x_tete + 40.0, "y": _rng_oiseau.randf_range(14.0, 22.0)}
	m.log_(String(O.message), "info")
	m.evt({"t": "oiseau"})


func _horloge(dt: float) -> void:
	heure += dt * _facteur_temps() / JOUR_S
	if heure >= 1.0:
		heure -= 1.0
		jour += 1
		_crep_fait = false
		_aube_fait = false
	if heure >= CREPUSCULE and not _crep_fait:
		_crep_fait = true
		if m.ville_protegee() or m.ville_calme():
			m.log_("La nuit tombe. Derrière les murs, le convoi ne risque rien.", "info")
		else:
			m.log_("La nuit tombe. Abritez-vous dans un bâtiment : les rôdeurs sortent.", "alerte")
		m.evt({"t": "nuit_tombe"})
	if heure >= AUBE and not _aube_fait:
		_aube_fait = true
		var soignes := 0
		for b in m.batiments:
			for g in b.garnison:
				if g.pv > 0.0:
					g.pv = 20.0
					soignes += 1
		m.log_("Le jour se lève.%s" % (" Les survivants ont repris des forces." if soignes > 0 else ""), "ok")
		m.evt({"t": "aube"})


func _cap(dt: float) -> void:
	if trajet.is_empty():
		return
	trajet.reste -= maxf(0.0, m.vitesse_convoi) * dt
	if trajet.reste <= 0.0:
		secteur_prec = secteur
		secteur = trajet.dest
		x_entree = m.x_tete
		trajet = {}
		m._prochain_x = m.x_tete + 90.0
		var s: Dictionary = secteurs[secteur]
		m.log_("Vous entrez à %s : %s (%s), niveau %d." % [s.nom, FACTIONS[s.faction], ATTITUDE[s.faction], s.niveau], "ok")
		m.evt({"t": "secteur"})
		if m.mission_en_route():   # mission du maire : la ville de destination est au bout de l'étape (DEC-146)
			m.ville_creer(m.x_tete + float(m.MD().ville_arrivee_m))
		elif m.villes_on:   # une ville par secteur, un peu plus loin sur la route (DEC-141)
			m.ville_creer(m.x_tete + float(m.VD().apparition_secteur_m))


func _batiments(dt: float) -> void:
	_marteau_t = maxf(0.0, _marteau_t - dt)
	for b in m.batiments:
		b.blindage = b.blindage_base + 16.0 * b.barricade
		if b.barricade_cible and b.garnison_vivants() > 0 and b.barricade < 1.0:
			b.barricade = minf(1.0, b.barricade + dt / 10.0)
			if _marteau_t <= 0.0:
				_marteau_t = 1.6
				m.evt({"t": "marteau"})
		b.feu = obscurite() > 0.3 and b.garnison_vivants() > 0 and b.barricade >= 0.5


# --- Fantassins et animaux --------------------------------------------------

func creer_pieton(type: String, x: float) -> Pieton:
	var d: Dictionary = CombatModele.donnees().pietons[type]
	var p := Pieton.new()
	_uid += 1
	p.uid = _uid
	p.type = type
	p.x = x
	p.x_prev = x
	p.pv = float(d.pv)
	p.pv_max = float(d.pv)
	p.vit = float(d.vit) * m.rng.randf_range(0.9, 1.1)
	p.portee = float(d.get("portee", 1.0))
	p.animal = bool(d.animal)
	p.morsure = float(d.get("morsure", 2.5))
	p.arme = {"cd": m.rng.randf_range(0.5, 2.0)}
	pietons.append(p)
	return p


func pieton_proche(x: float, longueur: float, portee: float):
	var meilleur = null
	var g_min := INF
	for p in pietons:
		if p.actif() and p.camp == "ennemi":
			var g: float = CombatModele.ecart(x, longueur, p.x, p.longueur)
			if g <= portee and g < g_min:
				g_min = g
				meilleur = p
	return meilleur


func vivants() -> int:
	var n := 0
	for p in pietons:
		if p.actif() and p.camp == "ennemi":
			n += 1
	return n


# --- Troupes débarquées (DEC-063) ---------------------------------------------------------------
func debarquer_troupes(v) -> int:
	var n := 0
	var centre: float = v.x + v.longueur * 0.5
	for pv in v.troupes:
		if pv <= 0.0:
			continue
		var s := creer_pieton("soldat", centre + (n - 1.5) * 0.9)
		s.camp = "joueur"
		s.veh = v.uid
		s.pv = pv
		s.pv_max = float(CombatModele.donnees().equipage_pv)
		s.slot = n
		s.dir = 1.0
		n += 1
	v.troupes = []
	return n


func troupes_dehors(uid := 0) -> int:
	var n := 0
	for p in pietons:
		if p.camp == "joueur" and p.actif() and (uid == 0 or p.veh == uid):
			n += 1
	return n


func rappeler_troupes(uid: int) -> void:
	for p in pietons:
		if p.camp == "joueur" and p.actif() and p.veh == uid:
			p.mode = "retour"


# Cible d'un soldat : l'ennemi le plus proche à portée de fusil (fantassin, animal ou véhicule)
func _cible_troupe(p: Pieton):
	var meilleur = null
	var g_min := INF
	for q in pietons:
		if q.camp == "ennemi" and q.actif():
			var g: float = CombatModele.ecart(p.x, p.longueur, q.x, q.longueur)
			if g <= p.portee and g < g_min:
				g_min = g
				meilleur = q
	for e in m.ennemis:
		if e.actif():
			var g2: float = CombatModele.ecart(p.x, p.longueur, e.x, e.longueur)
			if g2 <= p.portee and g2 < g_min:
				g_min = g2
				meilleur = e
	return meilleur


func _troupe(p: Pieton, dt: float) -> void:
	var T: Dictionary = CombatModele.donnees().troupes
	var v = m.trouver(p.veh)
	if not (v is CombatModele.Veh) or not m.convoi.has(v) or not v.actif():
		m.reserve_survivants += 1   # son véhicule n'est plus là : il suivra à pied jusqu'au prochain
		p.statut = "monte"
		return
	var centre: float = v.x + v.longueur * 0.5
	if m.ordres.marche == "avancer":
		p.mode = "retour"   # le convoi veut repartir : tout le monde remonte
	var cible = _cible_troupe(p) if p.mode != "retour" else null
	if cible != null:
		p.calme_t = 0.0
		var cx: float = cible.x + cible.longueur * 0.5
		p.dir = signf(cx - p.x) if cx != p.x else p.dir
		var gap: float = CombatModele.ecart(p.x, p.longueur, cible.x, cible.longueur)
		if gap > p.portee * 0.8 and absf(p.x + p.dir * p.vit * dt - centre) < float(T.ecart_max):
			p.x += p.dir * p.vit * dt   # s'approche un peu, sans s'éloigner de son véhicule
		p.arme.cd -= dt
		if p.arme.cd <= 0.0:
			m._tirer(p, p.arme, CombatModele.donnees().armes.fusil, cible)
		return
	p.calme_t += dt
	if p.mode != "retour" and p.calme_t >= float(T.calme_s):
		p.mode = "retour"   # plus personne à portée : on remonte
	if p.mode == "retour":
		var dx: float = centre - p.x
		p.dir = signf(dx) if absf(dx) > 0.01 else p.dir
		if absf(dx) <= v.longueur * 0.5 + 0.4:
			v.troupes.append(p.pv)
			p.statut = "monte"
		else:
			p.x += signf(dx) * minf(float(T.vitesse_rembarquement) * dt, absf(dx))


func toucher_pieton(p: Pieton, w: Dictionary) -> void:
	if not p.actif():
		return
	p.pv -= float(w.degats)
	if p.pv <= 0.0:
		p.statut = "mort"
		p.mort_t = 0.0
		if p.camp == "joueur":
			m.log_("Un soldat est tombé.", "alerte")
			m.evt({"t": "mort", "x": p.x, "animal": false})
			return
		m.ennemis_detruits += 1
		if not p.animal:
			m.stocks.ammo += 2.0
		m.evt({"t": "mort", "x": p.x, "animal": p.animal})


func _cible_pieton(p: Pieton):
	# Un animal flaire les abris occupés ; un pillard vise ce qu'il voit
	var meilleur = null
	var g_min := INF
	for v in m.convoi:
		if v.actif() and not v.camoufle:
			var g: float = CombatModele.ecart(p.x, p.longueur, v.x, v.longueur)
			if g < g_min:
				g_min = g
				meilleur = v
	for s in pietons:
		if s.camp == "joueur" and s.actif():
			var gs: float = CombatModele.ecart(p.x, p.longueur, s.x, s.longueur)
			if gs < g_min:
				g_min = gs
				meilleur = s
	for b in m.batiments:
		if b.statut == "neutralise" and b.garnison_vivants() > 0 and (p.animal or b.revele_t > 0.0):
			var g2: float = CombatModele.ecart(p.x, p.longueur, b.x, b.longueur)
			if g2 < g_min + (30.0 if p.animal else 0.0):
				g_min = g2
				meilleur = b
	return meilleur


# Écrasement (DEC-049) : un véhicule en marche qui passe sur un fantassin ou un animal le blesse ou le tue
func _ecrasements(dt: float) -> void:
	var E: Dictionary = m.donnees().ecrasement
	var vit := absf(m.vitesse_convoi)
	if vit < float(E.vitesse_min):
		return
	for p in pietons:
		if not p.actif() or p.camp != "ennemi":
			continue
		p.ecrase_t = maxf(0.0, p.ecrase_t - dt)
		if p.ecrase_t > 0.0:
			continue
		for v in m.convoi:
			if v.actif() and v.garage == 0 and CombatModele.ecart(p.x, p.longueur, v.x, v.longueur) <= 0.3:
				var t := float(v.profil.get("poids_kg", 1500.0)) / 1000.0
				p.ecrase_t = 1.2
				m.evt({"t": "ecrase", "x": p.x, "animal": p.animal})
				toucher_pieton(p, {"degats": t * vit * float(E.k)})
				if p.actif():
					p.x += signf(p.x - (v.x + v.longueur * 0.5)) * 1.5   # projeté sur le côté
				break


func _pietons(dt: float) -> void:
	_ecrasements(dt)
	for p in pietons:
		p.x_prev = p.x
		if not p.actif():
			p.mort_t += dt
			continue
		if p.camp == "joueur":
			_troupe(p, dt)
			continue
		var c = _cible_pieton(p)
		if c == null:
			continue
		var gap: float = CombatModele.ecart(p.x, p.longueur, c.x, c.longueur)
		var centre: float = c.x + c.longueur * 0.5
		p.dir = signf(centre - p.x) if centre != p.x else p.dir
		p.arme.cd -= dt
		var portee: float = p.portee
		if gap > portee:
			p.x += p.dir * p.vit * dt
			continue
		if p.animal:
			if p.arme.cd <= 0.0:
				p.arme.cd = 0.9
				m.evt({"t": "morsure", "x": p.x})
				if c is Pieton:
					toucher_pieton(c, {"degats": p.morsure * 2.0})
				elif c is CombatModele.Veh:
					if c.profil.get("ouvert", false):
						m._blesser_equipage(c, p.morsure)
					else:
						c.pieces.chassis.pv = maxf(1.0, c.pieces.chassis.pv - 0.6)
				else:
					c.pv = maxf(0.0, c.pv - 3.0 * (1.0 - 0.8 * c.barricade))
					if c.barricade < 0.5:
						m._blesser_garnison(c, 1.5)
		elif p.arme.cd <= 0.0:
			var W: Dictionary = CombatModele.donnees().armes.fusil
			m._tirer(p, p.arme, W, c)
			p.arme.cd = float(W.cadence) * 1.6 * m.rng.randf_range(0.9, 1.2)


func _assauts(dt: float) -> void:
	if m.kit_calme and m.bac_a_sable:
		return   # Mode créatif : pas de rôdeurs sans le Kit
	if m.calme_ouverture():
		return   # début de partie : pas encore d'arme, pas de rôdeurs
	if m.tempete_active():
		return   # la tempête cloue tout le monde au sol
	if trajet.size() > 0 and not nuit():
		return
	if not nuit():
		return
	if camp_proche() != null or m.ville_protegee() or m.ville_calme():
		return   # le camp allié ou la ville montent la garde
	_assaut_t -= dt
	if _assaut_t > 0.0 or vivants() >= 6:
		return
	var EQ: Dictionary = m.donnees().equilibrage   # meutes rares (DEC-097, DEC-113)
	_assaut_t = float(EQ.rodeurs_delai_abri) if a_abri() else float(EQ.rodeurs_delai)
	if not a_abri() and m.convoi.any(func(v): return v.actif() and int(v.profil.get("phares", 0)) > 0):
		_assaut_t /= float(m.donnees().phares.attire)   # les phares se voient de loin (DEC-048)
	var niv: int = niveau_a(m.x_tete)
	var devant: bool = m.rng.randf() < 0.6
	var x0: float = m.x_tete + 80.0 if devant else m.x_tete - 70.0
	var loups: bool = m.rng.randf() < 0.6
	var n: int = 2 + m.rng.randi() % 2 + mini(2, niv / 2)
	for i in n:
		creer_pieton("loup" if loups else "pillard", x0 + (i * 3.0) * (1.0 if devant else -1.0))
	m.log_("Des %s rôdent dans la nuit !" % ("loups" if loups else "pillards à pied"), "alerte")
	m.evt({"t": "meute" if loups else "pillards"})


# --- Camps, annonces et génération des rencontres --------------------------------

func attitude(faction: int) -> String:
	return ATTITUDE[faction]


func annonces() -> Array:
	var res := []
	for b in m.batiments:
		if b.type.begins_with("camp") and b.statut == "actif" and b.x > m.x_tete + 4.0 and b.x - m.x_tete < 460.0:
			res.append({"nom": b.nom, "ami": b.ami, "faction": b.faction, "dist": b.x - m.x_tete, "fortifie": b.type == "camp_fortifie"})
	return res


func generer(choix: Dictionary, x: float, r: RandomNumberGenerator) -> float:
	var s: Dictionary = secteurs[secteur]
	if choix.has("camp"):
		var niv: int = niveau_a(x)
		var type := "camp_pillard"
		var ami := false
		var att: String = ATTITUDE[s.faction]
		var p_ami: float = 0.85 if att == "ami" else (0.45 if att == "neutre" else 0.08)
		if choix.camp == "ami":
			ami = true
		elif choix.camp == "auto":
			ami = r.randf() < p_ami
		if ami:
			type = "camp_ami"
		elif choix.camp == "fortifie" or (choix.camp == "auto" and (niv >= 3 or r.randf() < 0.35)):
			type = "camp_fortifie"
		var b = m.creer_batiment(type, x + 180.0)   # visible de loin : annoncé bien avant l'arrivée
		b.ami = ami
		b.faction = s.faction
		m.batiments.append(b)
		if not ami and type == "camp_fortifie" and niv >= 3:
			var e = m.creer_vehicule("citroen_traction", "ennemi", b.x + b.longueur + 6.0)
			e.mode = "barrage"
			m.ennemis.append(e)
		m.log_("%s %s (%s) droit devant, à %d m." % [b.nom, "allié" if ami else "hostile", FACTIONS[s.faction], int(b.x - m.x_tete)], "ok" if ami else "alerte")
		return b.x + b.longueur + 10.0
	if choix.has("pietons"):
		var k: String = choix.pietons[0]
		var n: int = int(choix.pietons[1]) + (m.rng.randi() % 2)
		for i in n:
			creer_pieton(k, x + 10.0 + i * 3.5)
		x += 10.0 + n * 3.5
		m.evt({"t": "meute" if k != "pillard" else "pillards"})
	if choix.has("pnj"):
		var offres: Array = CombatModele.donnees().pnj
		var idx: int = r.randi() % offres.size()
		_uid += 1
		var types := ["marchand", "refugie", "mecano", "eclaireur"]
		pnj.append({"uid": _uid, "x": x + 12.0, "type": types[idx % types.size()], "nom": offres[idx].get("nom", "Voyageur"),
			"offre": idx, "statut": "attend", "peau": r.randi() % 4})
		x += 14.0
		m.log_("Un voyageur vous attend au bord de la route.", "info")
	return x


# --- Voyageurs et quêtes -------------------------------------------------------

func _voyageurs(dt: float) -> void:
	for v in pnj:
		if v.statut == "attend" and dialogue.is_empty() and absf(m.x_tete - v.x) < 14.0:
			dialogue = {"pnj": v.uid}
			m.ordre_marche("halte")
			m.evt({"t": "voyageur"})
		elif v.statut == "parti":
			v.x += 1.8 * dt


func voyageur_actuel():
	if dialogue.is_empty():
		return null
	for v in pnj:
		if v.uid == dialogue.pnj:
			return v
	return null


func offre_de(v: Dictionary) -> Dictionary:
	return CombatModele.donnees().pnj[v.offre]


func peut_accepter(o: Dictionary) -> bool:
	for k in o.get("prend", {}):
		if m.stocks[k] < o.prend[k]:
			return false
	return not (o.has("quete") and not quete.is_empty())


func repondre(accepte: bool) -> void:
	var v = voyageur_actuel()
	if v == null:
		return
	var o: Dictionary = offre_de(v)
	if accepte and peut_accepter(o):
		for k in o.get("prend", {}):
			m.stocks[k] -= o.prend[k]
		for k in o.get("donne", {}):
			m.stocks[k] += o.donne[k]
		if o.get("survivant", 0) > 0:
			m._recruter_survivant()
		if o.has("quete"):
			quete = {"titre": o.titre, "abattre": int(o.quete.abattre), "depart": m.ennemis_detruits, "recompense": o.quete.recompense}
		m.log_("Marché conclu : %s." % o.titre, "ok")
	else:
		m.log_("Vous déclinez l'offre de %s." % v.nom, "info")
	v.statut = "parti"
	dialogue = {}
	m._dire_lore()


func _quete() -> void:
	if quete.is_empty():
		return
	if m.ennemis_detruits - quete.depart >= quete.abattre:
		for k in quete.recompense:
			m.stocks[k] += quete.recompense[k]
		m.log_("Quête accomplie : %s. Récompense reçue." % quete.titre, "ok")
		m.evt({"t": "quete"})
		quete = {}


# --- Camp allié ---------------------------------------------------------------

func actions_camp() -> Array:
	return [
		{"id": "munitions", "txt": "40 munitions contre 10 métal", "prend": {"metal": 10}, "donne": {"ammo": 40}},
		{"id": "carburant", "txt": "25 L de gazole contre 10 métal", "prend": {"metal": 10}, "donne": {"gazole": 25}},
		{"id": "essence", "txt": "25 L d'essence contre 12 métal", "prend": {"metal": 12}, "donne": {"essence": 25}},
		{"id": "atelier", "txt": "Atelier : toutes les pièces remises à 70 % (15 métal)", "prend": {"metal": 15}, "donne": {}},
		{"id": "repos", "txt": "Se reposer : soigne l'équipage (la nuit passe vite)", "prend": {}, "donne": {}},
	]


func camp_action(id: String) -> bool:
	if camp_proche() == null:
		return false
	for a in actions_camp():
		if a.id == id:
			for k in a.prend:
				if m.stocks[k] < a.prend[k]:
					m.log_("Pas assez de %s." % k, "alerte")
					return false
			for k in a.prend:
				m.stocks[k] -= a.prend[k]
			for k in a.donne:
				m.stocks[k] += a.donne[k]
			if id == "atelier":
				for v in m.convoi + m.epaves:
					if v.camp == "joueur":
						for pid in v.pieces:
							var pc: Dictionary = v.pieces[pid]
							pc.pv = maxf(pc.pv, pc.max * 0.7)
			elif id == "repos":
				for v in m.convoi:
					for i in v.equipage.size():
						if v.equipage[i] > 0.0:
							v.equipage[i] = float(m.donnees().equipage_pv)
				repos_t = 60.0
			m.log_("Camp allié : %s." % a.txt, "ok")
			return true
	return false


func nettoyer(limite: float) -> void:
	pietons = pietons.filter(func(p): return p.statut != "monte" and (p.actif() or p.mort_t < 8.0) and (p.x > limite - 60.0 or p.camp == "joueur"))
	pnj = pnj.filter(func(v): return v.x > limite and v.x < m.x_tete + 900.0)
