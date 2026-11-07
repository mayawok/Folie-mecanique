# Couche « Kit de développement » du Mode créatif (DEC-110, DEV-010).
# Chaîne : modele_base <- modele_tir <- modele_terrain <- modele_mines <- modele_meteo <- modele_abordage <- modele_kit <- modele_atelier <- combat_modele.
# Sert à fabriquer à la main le monde, les décors et les rencontres avant d'écrire un chapitre : zone, heure, météo,
# route calme (aucune rencontre automatique) et apparitions à la demande. Actif seulement en Mode créatif (bac_a_sable).
extends "res://scripts/combat/modele_abordage.gd"

const KIT_ZONES := ["sable", "terre", "cailloux", "eau"]
const KIT_ZONES_NOMS := {"sable": "Sable", "terre": "Terre et herbe", "cailloux": "Cailloux", "eau": "Eau"}
# Véhicules d'apparition : id d'assemblage -> libellé court
const KIT_VEHICULES := {"bmw_r75": "Moto side-car", "moto_bmw": "Moto", "willys_mb": "Jeep", "citroen_traction": "Voiture",
	"citroen_t23": "Camion", "diamond_t": "Dépanneuse", "m3_half_track": "Half-track", "m3_stuart": "Char léger", "m4_sherman": "Sherman"}

var kit_zone := "sable"
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
			var e := creer_vehicule(String(p.get("type", "citroen_traction")), "ennemi", x)
			e.mode = "approche"
			ennemis.append(e)
			log_("Kit : %s ennemi à %d m." % [e.nom, int(x - x_tete)], "info")
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
		_:
			return false
	return true


# Vitesse d'un véhicule de convoi ennemi (plafonnée par sa propre vitesse)
func kit_vitesse_convoi(e) -> float:
	return minf(e.vitesse(), float(_kit_convois.get(e.uid, 4.5)))
