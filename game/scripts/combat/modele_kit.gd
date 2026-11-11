# Couche « Kit de développement » du Mode créatif (DEC-110, DEV-010).
# Chaîne : modele_base <- modele_tir <- modele_terrain <- modele_mines <- modele_meteo <- modele_abordage <- modele_kit <- modele_atelier <- combat_modele.
# Sert à fabriquer à la main le monde, les décors et les rencontres avant d'écrire un chapitre : zone, heure, météo,
# route calme (aucune rencontre automatique) et apparitions à la demande. Actif seulement en Mode créatif (bac_a_sable).
extends "res://scripts/combat/modele_choc.gd"

const KIT_ZONES := ["sable", "terre", "cailloux", "eau", "neige", "boue"]
const KIT_ZONES_NOMS := {"sable": "Sable", "terre": "Terre et herbe", "cailloux": "Cailloux", "eau": "Eau", "neige": "Neige", "boue": "Boue"}
# Véhicules d'apparition : id d'assemblage -> libellé court
const KIT_VEHICULES := {"bmw_r75": "Moto side-car", "moto_bmw": "Moto", "willys_mb": "Jeep", "citroen_traction": "Voiture",
	"citroen_t23": "Camion", "diamond_t": "Dépanneuse", "m3_half_track": "Half-track", "m3_stuart": "Char léger", "m4_sherman": "Sherman",
	"moto_zundapp": "Zündapp KS 750", "moto_harley": "Harley WLA", "moto_gnome": "Gnome & Rhône", "peugeot_202": "Peugeot 202", "juvaquatre": "Juvaquatre",
	"kubelwagen": "Kübelwagen", "citroen_h": "Citroën Type H", "opel_blitz": "Opel Blitz", "gmc_cckw": "GMC CCKW", "laffly_s15": "Laffly S15", "m16_mgmc": "M16 quadruple .50"}

var kit_zone := "terre"
var kit_lieu := "kerbrume"     # lieu de la carte où se trouve le convoi (Mode créatif seulement, non sauvegardé)
var kit_distance := 90.0       # distance d'apparition devant (ou derrière) le convoi, en mètres
var _kit_convois := {}         # uid d'un véhicule de convoi ennemi -> vitesse imposée (m/s)


func kit_actif() -> bool:
	return bac_a_sable


func kit_regler_calme(on: bool) -> void:
	kit_calme = on


func kit_regler_zone(z: String) -> bool:
	if z not in KIT_ZONES:
		return false
	kit_zone = z
	Terrain.zone = z
	return true


# Heure du jour : 0 = aube-matin, 0,62 = crépuscule, 0,95 = aube (voir monde.gd)
func kit_regler_heure(h: float) -> void:
	monde.heure = clampf(h, 0.0, 0.999)


func kit_tempete() -> bool:
	if not kit_actif():
		return false
	meteo_on = true
	tempete = {"phase": "annonce", "reste": 4.0, "duree": 60.0}
	log_("Kit : tempête de sable dans 4 s.", "alerte")
	return true


func kit_fin_tempete() -> void:
	tempete = {}


func _kit_x_devant() -> float:
	var xt := x_tete
	for v in convoi:
		xt = maxf(xt, v.x + v.longueur)
	return xt + kit_distance


func _kit_x_arriere() -> float:
	var xq := x_tete
	for v in convoi:
		xq = minf(xq, v.x)
	return xq - float(AB().depart_arriere)


# Apparitions à la demande. genre : ennemi | convoi_devant | poursuite | batiment | pillards | loups | mines | voyageur | epave
# p : type (id de véhicule ou de bâtiment), types (Array d'ids), n (nombre), vitesse (m/s, convoi_devant)
func kit_apparaitre(genre: String, p := {}) -> bool:
	if not kit_actif():
		return false
	var x := _kit_x_devant()
	match genre:
		"ennemi":
			var e := creer_vehicule(String(p.get("type", "citroen_traction")), "ennemi", x + float(p.get("dx", 0.0)))
			e.mode = "approche"
			ennemis.append(e)
			log_("Kit : %s ennemi à %d m." % [e.nom, int(x - x_tete)], "info")
		"allie":
			# Allié qui rejoint notre convoi (derrière le dernier véhicule) : il tire avec nos munitions comme les autres.
			# Ajouter un type à KIT_VEHICULES suffit pour le proposer ici (panneau Kit : « Allié rejoint le convoi »).
			var types_a: Array = p.get("types", [p.get("type", "willys_mb")])
			for t in types_a:
				if not KIT_VEHICULES.has(String(t)):
					return false
			for t in types_a:
				var al := creer_vehicule(String(t), "joueur", x_tete)
				convoi.append(al)
				log_("Kit : %s rejoint le convoi." % al.nom, "ok")
			_replacer(true)
		"convoi_devant":
			# convoi qui roule dans notre sens, devant nous : il faut le rattraper
			var types: Array = p.get("types", ["citroen_t23", "willys_mb"])
			var xe := x
			for t in types:
				var e := creer_vehicule(String(t), "ennemi", xe)
				e.mode = "convoi"
				_kit_convois[e.uid] = float(p.get("vitesse", 4.5))
				ennemis.append(e)
				xe += e.longueur + 6.0
			log_("Kit : un convoi de %d véhicules roule devant, à %d m." % [types.size(), int(x - x_tete)], "info")
		"face":   # convoi qui vient en face sur l'autre voie (DEC-215) : il nous croise, ou nous fonce dessus
			var types: Array = p.get("types", ["citroen_t23", "willys_mb"])
			var xf := x
			for t in types:
				var e := creer_vehicule(String(t), "ennemi", xf)
				e.mode = "face"
				if p.has("eperonne"):
					_intention[e.uid] = bool(p.eperonne)
				ennemis.append(e)
				xf += e.longueur + 6.0
			log_("Kit : un convoi de %d véhicules arrive en face, à %d m." % [types.size(), int(x - x_tete)], "info")
		"poursuite":
			var types: Array = p.get("types", ["bmw_r75", "citroen_traction"])
			var xp := _kit_x_arriere()
			for t in types:
				var e := creer_vehicule(String(t), "ennemi", xp)
				preparer_poursuivant(e, {"abordeurs": int(p.get("abordeurs", 2)), "types": p.get("abordage", ["lame", "bombe"])})
				ennemis.append(e)
				xp -= e.longueur + 8.0
			log_("Kit : %d véhicules vous rattrapent par l'arrière." % types.size(), "alerte")
		"batiment":
			var t := String(p.get("type", "maison"))
			if not donnees().batiments.has(t):
				return false
			var b := creer_batiment(t, x)
			batiments.append(b)
			log_("Kit : %s à %d m." % [b.nom, int(x - x_tete)], "info")
		"pillards", "loups":
			var n := int(p.get("n", 3))
			for i in n:
				monde.creer_pieton("pillard" if genre == "pillards" else "loup", x + i * 3.0)
			log_("Kit : %d %s à %d m." % [n, genre, int(x - x_tete)], "info")
		"mines":
			_champ_id += 1
			var C := mines_cfg()
			var xm := x
			for i in int(p.get("n", 8)):
				mines.append({"x": xm, "arme_t": 0.0, "armee": true, "champ": _champ_id, "marquee": false})
				xm += rng.randf_range(C.pas[0], C.pas[1])
			log_("Kit : champ de mines à %d m." % int(x - x_tete), "alerte")
		"voyageur":
			monde.generer({"pnj": true}, x, rng)
		"epave":
			var f := creer_vehicule(String(p.get("type", "citroen_traction")), "joueur", x)
			f.statut = "trouvee"
			f.equipage = []
			f.noms = []
			f.butin = _butin_vehicule(f, 0.6)
			epaves.append(f)
			log_("Kit : épave de %s à %d m." % [f.nom, int(x - x_tete)], "info")
		"groupe":
			# Groupe sur mesure (lot A) : n véhicules du même type, à l'approche, en convoi devant ou en poursuite
			var n := clampi(int(p.get("n", 3)), 1, 8)
			var t := String(p.get("type", "moto_bmw"))
			var mode := String(p.get("mode", "approche"))
			if not KIT_VEHICULES.has(t):
				return false
			var types := []
			for i in n:
				types.append(t)
			match mode:
				"poursuite":
					return kit_apparaitre("poursuite", {"types": types, "abordeurs": int(p.get("abordeurs", 2))})
				"allie":
					return kit_apparaitre("allie", {"types": types})
				"face":
					return kit_apparaitre("face", {"types": types})
				"convoi":
					return kit_apparaitre("convoi_devant", {"types": types, "vitesse": float(p.get("vitesse", 4.5))})
				_:
					var dx := 0.0
					for i in n:
						kit_apparaitre("ennemi", {"type": t, "dx": dx})
						dx += 7.0
			log_("Kit : groupe de %d x %s." % [n, KIT_VEHICULES[t]], "info")
		_:
			return false
	return true


# Vitesse d'un véhicule de convoi ennemi (plafonnée par sa propre vitesse)
func kit_vitesse_convoi(e) -> float:
	return minf(e.vitesse(), float(_kit_convois.get(e.uid, 4.5)))


# --- Réglages d'équilibrage en direct et région de quête (lot A, DEC-171, DEC-172, DEC-178) ----------
# Chaque réglage : clé, libellé, pas, bornes. Les valeurs vivent dans combat_proto.json (donnees()) : on les change en mémoire
# pour la session, puis « Copier » donne le texte à reporter dans le fichier.
const KIT_REGLAGES := [
	{"cle": "equilibrage.ennemi_degats_subis", "nom": "Dégâts subis par les ennemis ×", "pas": 0.1, "min": 0.3, "max": 4.0},
	{"cle": "equilibrage.ennemi_degats_infliges", "nom": "Dégâts infligés par les ennemis ×", "pas": 0.1, "min": 0.1, "max": 3.0},
	{"cle": "equilibrage.ennemi_precision", "nom": "Précision des ennemis ×", "pas": 0.05, "min": 0.2, "max": 1.5},
	{"cle": "rencontres.intervalle", "nom": "Délai moyen entre rencontres (m)", "pas": 20.0, "min": 30.0, "max": 600.0},
	{"cle": "kit.malus_region", "nom": "Niveau en plus hors région de quête", "pas": 1.0, "min": 0.0, "max": 7.0},
]

var kit_region_quete := ""      # id de région (carte_monde.json) ; vide = pas de région de quête (aucun malus)
var kit_malus_region := 3       # niveau de rencontre ajouté hors de la région de quête (difficulté forcée)
static var _kit_defauts := {}   # valeurs d'origine, mémorisées au premier réglage


func kit_reglage_valeur(i: int) -> float:
	var k: String = KIT_REGLAGES[i].cle
	match k:
		"kit.malus_region":
			return float(kit_malus_region)
		"rencontres.intervalle":
			var iv: Array = donnees().rencontres.intervalle
			return (float(iv[0]) + float(iv[1])) * 0.5
		_:
			return float(donnees().equilibrage[k.get_slice(".", 1)])


# Change un réglage d'un pas (sens = +1 ou -1). Vrai si la valeur a bougé.
func kit_reglage_pas(i: int, sens: int) -> bool:
	if not kit_actif() or i < 0 or i >= KIT_REGLAGES.size():
		return false
	var R: Dictionary = KIT_REGLAGES[i]
	_kit_memoriser_defauts()
	var avant := kit_reglage_valeur(i)
	var apres := clampf(snappedf(avant + float(R.pas) * sens, float(R.pas) / 10.0), float(R.min), float(R.max))
	if is_equal_approx(avant, apres):
		return false
	match String(R.cle):
		"kit.malus_region":
			kit_malus_region = int(apres)
		"rencontres.intervalle":
			var iv: Array = donnees().rencontres.intervalle
			var f := apres / maxf(1.0, avant)
			donnees().rencontres.intervalle = [float(iv[0]) * f, float(iv[1]) * f]
		_:
			donnees().equilibrage[String(R.cle).get_slice(".", 1)] = apres
	return true


func _kit_memoriser_defauts() -> void:
	if _kit_defauts.is_empty():
		_kit_defauts = {"equilibrage": donnees().equilibrage.duplicate(true), "intervalle": donnees().rencontres.intervalle.duplicate()}


func kit_reglages_reinitialiser() -> void:
	if not _kit_defauts.is_empty():
		for k in _kit_defauts.equilibrage:
			donnees().equilibrage[k] = _kit_defauts.equilibrage[k]
		donnees().rencontres.intervalle = _kit_defauts.intervalle.duplicate()
	kit_malus_region = 3


# Texte JSON à reporter dans combat_proto.json
func kit_reglages_texte() -> String:
	var eq := {}
	for k in ["ennemi_degats_subis", "ennemi_degats_infliges", "ennemi_precision"]:
		eq[k] = snappedf(float(donnees().equilibrage[k]), 0.01)
	var iv: Array = donnees().rencontres.intervalle
	return JSON.stringify({"equilibrage": eq, "rencontres_intervalle": [roundi(float(iv[0])), roundi(float(iv[1]))],
		"malus_hors_region": kit_malus_region, "region_quete": kit_region_quete}, "  ")


# Région où se trouve le convoi dans le Kit (d'après le dernier lieu visité sur la carte)
func kit_region_courante() -> String:
	var l := CarteMonde.lieu(kit_lieu)
	if l.is_empty():
		return ""
	return String(CarteMonde.region_a(Vector2(l.pos[0], l.pos[1])).get("id", ""))


func kit_regler_region_quete(id: String) -> bool:
	if id != "" and CarteMonde.region(id).is_empty():
		return false
	kit_region_quete = id
	return true


# Difficulté forcée (DEC-172) : niveau de rencontre ajouté tant que le convoi est hors de la région de la quête principale
func malus_hors_region() -> int:
	if not kit_actif():
		return super()   # partie normale : région de la quête principale (monde.gd)
	if kit_region_quete == "":
		return 0
	var c := kit_region_courante()
	return kit_malus_region if (c != "" and c != kit_region_quete) else 0
