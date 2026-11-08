# Couche 2a du modèle : champs de mines (DEC-028). Aucun dessin ici.
# Chaîne : modele_base <- modele_tir <- modele_terrain <- modele_mines <- modele_meteo <- modele_atelier <- combat_modele.
# Les mines des champs sont des entrées de `mines` (comme celles du joueur) marquées d'un numéro de champ :
# elles explosent sous les véhicules par la même mécanique, et le demi-tour les retourne avec le reste.
# Champs tirés avec un générateur propre (rng_mines) : les autres tirages à graine fixe ne bougent pas.
# Toujours détectés avant d'y entrer ; le convoi s'arrête de lui-même. Trois moyens : détecteur de métaux,
# chien, fléau (chenilles en tête). Sans moyen : demi-tour ou traversée à l'aveugle.
extends "res://scripts/combat/modele_terrain.gd"

var _champs_annonces := {}


func mines_cfg() -> Dictionary:
	return donnees().mines_champs


func _init_mines() -> void:
	rng_mines.seed = graine * 6271 + 5
	var iv: Array = mines_cfg().intervalle
	_prochain_champ_x = rng_mines.randf_range(iv[0], iv[1])


# --- Génération ---------------------------------------------------------------
func _champs_generer() -> void:
	if not champs_on or en_kit or calme_ouverture() or (kit_calme and bac_a_sable):
		return
	var C := mines_cfg()
	while x_tete + 220.0 >= _prochain_champ_x:
		var x0 := _prochain_champ_x
		var iv: Array = C.intervalle
		_prochain_champ_x = x0 + rng_mines.randf_range(iv[0], iv[1])
		if not monde.trajet.is_empty() or ville_zone(x0):
			continue   # zone calme entre deux secteurs, abords d'une ville : pas de champ
		var p := float(C.proba_base) + float(C.proba_par_niveau) * monde.niveau_a(x0)
		if rng_mines.randf() > p:
			continue
		_champ_id += 1
		var n := rng_mines.randi_range(int(C.mines[0]), int(C.mines[1]))
		var x := x0
		for i in n:
			mines.append({"x": x, "arme_t": 0.0, "armee": true, "champ": _champ_id, "marquee": false})
			x += rng_mines.randf_range(C.pas[0], C.pas[1])


# Premier champ encore devant le convoi : {id, x0, x1, n, dist, marquees} ; vide s'il n'y en a pas.
func champ_devant() -> Dictionary:
	var par := {}
	for mn in mines:
		var id := int(mn.get("champ", 0))
		if id == 0 or mn.x < x_tete - 1.0:
			continue
		var g: Dictionary = par.get(id, {"id": id, "x0": INF, "x1": -INF, "n": 0, "marquees": 0})
		g.x0 = minf(g.x0, mn.x)
		g.x1 = maxf(g.x1, mn.x)
		g.n += 1
		if mn.get("marquee", false):
			g.marquees += 1
		par[id] = g
	var res := {}
	for id in par:
		if res.is_empty() or par[id].x0 < res.x0:
			res = par[id]
	if not res.is_empty():
		res.dist = res.x0 - x_tete
	return res


func _champs() -> void:
	var c := champ_devant()
	if c.is_empty():
		champ_traverse = false
		return
	if c.dist <= float(mines_cfg().alerte_m) and not _champs_annonces.has(c.id):
		_champs_annonces[c.id] = true
		log_("Champ de mines à %d m. Le convoi s'arrête avant d'y entrer." % int(c.dist), "alerte")
		evt({"t": "champ_mines"})


# --- Fléau : monté à l'avant d'un véhicule à chenilles ------------------------------
func fleau_pret() -> bool:
	return float(equip_demin.fleau_pv) > 0.0 and not convoi.is_empty() and convoi[0].actif() and convoi[0].chenille


# Le convoi s'arrête devant un champ tant qu'aucun moyen n'a servi (sauf traversée choisie ou fléau en tête).
func champ_bloque() -> bool:
	if champ_traverse or fleau_pret():
		return false
	var c := champ_devant()
	return not c.is_empty() and c.dist <= float(mines_cfg().arret_m)


func facteur_vitesse_mines() -> float:
	if not fleau_pret():
		return 1.0
	var c := champ_devant()
	if c.is_empty() or c.dist > 40.0:
		return 1.0
	return float(mines_cfg().fleau_vitesse)


func _mines(dt: float) -> void:
	if fleau_pret() and vitesse_convoi > 0.0:
		for mn in mines.duplicate():
			if int(mn.get("champ", 0)) > 0 and mn.x <= x_tete + 1.5 and mn.x >= x_tete - 4.0:
				mines.erase(mn)
				equip_demin.fleau_pv = float(equip_demin.fleau_pv) - float(mines_cfg().fleau_usure)
				evt({"t": "mine", "x": mn.x, "uid": -1})
				if float(equip_demin.fleau_pv) <= 0.0:
					equip_demin.fleau_pv = 0.0
					log_("Le fléau est hors d'usage.", "alerte")
					break
	super(dt)


# --- Moyens de déminage ---------------------------------------------------------------
func moyens_demin() -> Array:
	var res := []
	if equip_demin.detecteur:
		res.append("detecteur")
	if int(equip_demin.chien_pv) > 0:
		res.append("chien")
	return res


func _equipe_arme() -> bool:
	for v in convoi:
		if v.actif() and not v.armes.is_empty() and v.equipage_vivant() > 0:
			return true
	return false


# Raison pour laquelle le déminage ne peut pas commencer ("" = possible)
func raison_demin(moyen: String) -> String:
	var c := champ_devant()
	if c.is_empty() or c.dist > float(mines_cfg().alerte_m):
		return "Aucun champ de mines en vue."
	if not moyens_demin().has(moyen):
		return "Vous n'avez pas ce moyen de déminage."
	if ordres.marche != "halte":
		return "Arrêtez le convoi."
	if not _equipe_arme():
		return "Il faut une arme et un équipage pour faire sauter les mines."
	if stocks.ammo < 1.0:
		return "Plus de munitions pour faire sauter les mines."
	return ""


func ordre_deminer(moyen: String) -> bool:
	var r := raison_demin(moyen)
	if r != "":
		log_(r, "alerte")
		return false
	var c := champ_devant()
	demin = {"champ": c.id, "moyen": moyen, "t": 0.0}
	log_("Déminage au %s." % ("détecteur de métaux" if moyen == "detecteur" else "chien"), "info")
	return true


func ordre_traverser() -> bool:
	if champ_devant().is_empty():
		return false
	champ_traverse = true
	demin = {}
	log_("Traversée à l'aveugle : chaque mine touchée est un désastre.", "alerte")
	return true


func _demin(dt: float) -> void:
	if demin.is_empty():
		return
	if ordres.marche != "halte":
		demin = {}
		return
	var restantes := mines.filter(func(mn): return int(mn.get("champ", 0)) == demin.champ)
	if restantes.is_empty():
		demin = {}
		log_("Champ de mines déminé : la route est libre.", "ok")
		return
	if menace():
		return   # un démineur à pied est exposé : on attend que la menace passe
	if stocks.ammo < 1.0 or not _equipe_arme():
		demin = {}
		log_("Déminage interrompu : plus de quoi faire sauter les mines.", "alerte")
		return
	var C := mines_cfg()
	demin.t += dt
	var periode := float(C.detecteur_s) if demin.moyen == "detecteur" else float(C.chien_s)
	if demin.t < periode:
		return
	demin.t -= periode
	var cible = restantes[0]
	for mn in restantes:
		if mn.x < cible.x:
			cible = mn
	mines.erase(cible)
	if demin.moyen == "detecteur" and rng_mines.randf() < float(C.recupere):
		stocks.metal += float(donnees().embuscade.mine_cout)   # mine désamorcée, réutilisable en embuscade
		log_("Une mine est désamorcée et récupérée.", "ok")
		return
	stocks.ammo -= 1.0
	evt({"t": "mine", "x": cible.x, "uid": -1})
	if demin.moyen == "chien" and rng_mines.randf() < float(C.chien_blesse):
		equip_demin.chien_pv = int(equip_demin.chien_pv) - 1
		if int(equip_demin.chien_pv) <= 0:
			equip_demin.chien_pv = 0
			demin = {}
			log_("Le chien est tué par une explosion. On ne le reverra pas.", "alerte")
		else:
			log_("Le chien est blessé par un éclat.", "alerte")


# --- Trouvailles : moyens de déminage dans le butin -------------------------------------
func _recolter(c) -> void:
	super(c)
	if not champs_on:
		return
	var C := mines_cfg()
	var trouve := []
	if c is Bat:
		if c.type in ["bunker", "maison", "eglise"] and not equip_demin.detecteur and rng_mines.randf() < float(C.trouvaille_detecteur):
			equip_demin.detecteur = true
			trouve.append("un détecteur de métaux")
		if c.type in ["ferme", "grange"] and int(equip_demin.chien_pv) <= 0 and rng_mines.randf() < float(C.trouvaille_chien):
			equip_demin.chien_pv = int(C.chien_pv)
			trouve.append("un chien qui s'attache à vous")
	elif c is Veh and c.type == "m4_sherman" and c.statut == "epave" and float(equip_demin.fleau_pv) <= 0.0 \
			and rng_mines.randf() < float(C.trouvaille_fleau):
		equip_demin.fleau_pv = float(C.fleau_pv)
		trouve.append("un fléau à chaînes (monté sur chenilles)")
	if not trouve.is_empty():
		log_("Trouvé : %s." % ", ".join(trouve), "ok")
		evt({"t": "pieces"})
