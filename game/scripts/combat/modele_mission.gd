extends "res://scripts/combat/modele_ville.gd"
# Missions du maire (DEC-144 à DEC-147). Couche du modèle de combat, entre la ville et CombatModele.
# Le maire propose de transporter une cargaison (carburant, eau, vivres, munitions, pièces) jusqu'à la ville du secteur
# voisin le plus proche (une seule étape). Il annonce les ennemis et donne des hommes (escorte).
# Si on accepte : scène de l'atelier (le pont roulant pose la cargaison sur le Berliet), puis rassemblement sur la place
# (escorte autour du camion, cris de joie, tambours), le maire souhaite bonne chance, la porte s'ouvre et le convoi part
# tout seul vers la ville de destination. Sur la route : les vagues annoncées. À l'arrivée, cargaison livrée = récompense.
# Valeurs et textes : game/data/missions.json. Dessin des scènes : ville_dessin.gd et mission_dessin.gd.

static var _mdata := {}

var mission := {}          # {} ou {type, dest, dest_nom, origine, escorte:[uid], module_avant, phase: route, vagues: n posées}
var mission_bilan := {}    # dernière livraison ou dernier échec : {ok, titre, texte} (pour le panneau de la ville)


static func MD() -> Dictionary:
	if _mdata.is_empty():
		var f := FileAccess.open("res://data/missions.json", FileAccess.READ)
		_mdata = JSON.parse_string(f.get_as_text())
	return _mdata


func mission_active() -> bool:
	return not mission.is_empty()


func mission_en_route() -> bool:
	return mission_active() and String(mission.phase) == "route"


# --- Offres du maire -------------------------------------------------------------------------
# Destination : la ville du secteur voisin le plus proche, joignable en une étape sans détour
func mission_offres() -> Array:
	if not ville_dedans() or mission_active():
		return []
	var so: Array = ville_sorties()
	if so.is_empty():
		return []
	var dest: Dictionary = so[0]
	var r := RandomNumberGenerator.new()
	r.seed = int(ville.graine) * 31 + 7
	var dest_nom := ville_nommer(int(dest.id), r)
	var types: Array = MD().types.keys()
	if not bac_a_sable:   # en expédition, deux missions par ville ; le Kit les propose toutes
		var tires := []
		while tires.size() < mini(2, types.size()):
			var t = types[r.randi() % types.size()]
			if not tires.has(t):
				tires.append(t)
		types = tires
	var res := []
	for t in types:
		res.append({"type": t, "nom": MD().types[t].nom, "dest": int(dest.id), "dest_nom": dest_nom, "porte": dest.porte, "distance_m": dest.distance_m,
			"texte": _texte_offre(t, dest_nom, dest)})
	return res


func _texte_offre(t: String, dest_nom: String, dest: Dictionary) -> String:
	var M := MD()
	var T: Dictionary = M.types[t]
	var ennemis: Array = M.vagues.map(func(v): return String(v.annonce))
	return "« J'ai %s qui doivent arriver à %s. C'est une seule étape, %d m par la %s, sans détour.\n\nSur la route, attendez-vous à %s.\n\nJe vous donne des hommes : %s. Livrez tout à %s et le maire là-bas vous paiera : %s. »" % [
		T.cargaison, dest_nom, int(dest.distance_m), String(dest.porte).to_lower(), ", ".join(ennemis), M.escorte_texte, dest_nom, texte_recompense(T.recompense)]


static func texte_recompense(rc: Dictionary) -> String:
	var mots := {"fuel_l": "%d L de carburant", "ammo": "%d munitions", "metal": "%d métal", "eau": "%d bidons d'eau", "vivres": "%d caisses de vivres", "pieces": "%d pièce(s) de véhicule"}
	var l := []
	for k in rc:
		if mots.has(k):
			l.append(mots[k] % int(rc[k]))
	return ", ".join(l)


# --- Acceptation et scènes de départ -----------------------------------------------------------
func mission_accepter(t: String) -> bool:
	var offre := {}
	for o in mission_offres():
		if o.type == t:
			offre = o
	var vp = vehicule_principal()
	if offre.is_empty() or vp == null:
		return false
	mission = {"type": t, "dest": int(offre.dest), "dest_nom": String(offre.dest_nom), "origine": String(ville.nom), "escorte": [],
		"module_avant": String(berliet_config.module), "phase": "prep", "vagues": 0}
	mission_bilan = {}
	BerlietConfig.regler(berliet_config, "module", String(MD().types[t].module))
	_berliet_longueur()
	ville.phase = "chargement"
	ville.t = 0.0
	x_tete = float(ville.x0) + float(MD().pos_atelier_m)   # le camion est à l'atelier
	_replacer(true)
	log_("Mission acceptée : %s pour %s." % [String(MD().types[t].nom).to_lower(), mission.dest_nom], "ok")
	evt({"t": "mission", "etat": "chargement"})
	return true


func _berliet_longueur() -> void:
	for v in convoi:
		if v.principal:
			v.longueur = BerlietConfig.longueur_m(berliet_config)


# Hauteur (m) de la cargaison au-dessus de sa place pendant la scène de l'atelier (le pont roulant la descend)
func mission_module_leve() -> float:
	if ville_phase() != "chargement":
		return 0.0
	var u := clampf((float(ville.t) - 1.0) / 4.5, 0.0, 1.0)
	return 4.2 * (1.0 - u * u * (3.0 - 2.0 * u))


func _mission(dt: float) -> void:
	if not mission_active():
		return
	var M := MD()
	match ville_phase():
		"chargement":
			ville.t += dt
			if float(ville.t) >= float(M.chargement_s):
				_rassembler()
		"rassemblement":
			ville.t += dt
			if float(ville.t) >= float(M.rassemblement_s):
				monde.choisir_destination(int(mission.dest))
				ville.dest = int(mission.dest)
				ville.phase = "depart"
				mission.phase = "route"
				evt({"t": "mission", "etat": "depart"})
	if mission_en_route():
		_mission_route()


# L'escorte rejoint le convoi sur la place : une moto devant le Berliet, le reste derrière
func _rassembler() -> void:
	ville.phase = "rassemblement"
	ville.t = 0.0
	x_tete = float(ville.x0) + float(MD().pos_rassemblement_m)
	var esc: Array = MD().escorte
	for i in esc.size():
		var e := creer_vehicule(String(esc[i]), "joueur", x_tete)
		mission.escorte.append(e.uid)
		if i == 0:
			convoi.insert(0, e)
		else:
			convoi.append(e)
	_replacer(true)
	var et := String(MD().escorte_texte)
	log_("%s rejoignent le convoi." % (et.left(1).to_upper() + et.substr(1)), "ok")
	evt({"t": "mission", "etat": "rassemblement"})


# Sous-titre des scènes (affiché en bas de l'écran pendant les scènes de départ)
func mission_sous_titre() -> String:
	var R: Dictionary = MD().repliques
	var t := float(ville.get("t", 0.0))
	match ville_phase():
		"chargement":
			return String(R.chargement) % ville.nom
		"rassemblement":
			if t < 4.0:
				return String(R.rassemblement)
			if t < 8.5:
				return String(R.bonne_chance) % mission.dest_nom
			return String(R.portes)
	return ""


# --- Sur la route ------------------------------------------------------------------------------
func _mission_route() -> void:
	var vp = vehicule_principal()
	if vp == null or not vp.actif():
		mission_echouer("Le Berliet est hors d'usage : la cargaison n'arrivera pas à %s." % mission.dest_nom)
		return
	if not monde.en_transit() or ville_protegee():
		return
	var vagues: Array = MD().vagues
	var i := int(mission.vagues)
	if i >= vagues.size():
		return
	var prog := 1.0 - float(monde.trajet.reste) / maxf(1.0, float(monde.trajet.total))
	if prog >= float(vagues[i].part):
		mission.vagues = i + 1
		_poser_vague(vagues[i])


func _poser_vague(v: Dictionary) -> void:
	if String(v.get("mode", "")) == "poursuite":
		var xp := _queue_x() - float(AB().depart_arriere)
		for t in v.vehicules:
			var e := creer_vehicule(String(t), "ennemi", xp)
			preparer_poursuivant(e, v)
			ennemis.append(e)
			xp -= e.longueur + 9.0
	else:
		var x := x_tete + 120.0
		for t in v.vehicules:
			var e := creer_vehicule(String(t), "ennemi", x)
			e.mode = String(v.get("mode", "approche"))
			ennemis.append(e)
			x += e.longueur + 8.0
	log_(String(v.alerte), "alerte")
	evt({"t": "contact", "ennemi": true})


func mission_echouer(raison: String) -> void:
	if not mission_active():
		return
	mission_bilan = {"ok": false, "titre": "Mission échouée", "texte": raison}
	mission = {}
	log_(raison, "alerte")
	evt({"t": "mission", "etat": "echec"})


# --- Livraison -------------------------------------------------------------------------------
func _mission_arrivee() -> void:
	if not mission_en_route() or int(ville.secteur) != int(mission.dest):
		return
	var M := MD()
	var T: Dictionary = M.types[mission.type]
	var rc: Dictionary = T.recompense
	var r := RandomNumberGenerator.new()
	r.seed = graine * 131 + int(mission.dest) * 17 + int(temps)
	for k in rc:
		if k == "pieces":
			for i in int(rc[k]):
				var pid: String = M.pieces_recompense[r.randi() % M.pieces_recompense.size()]
				pieces_stock.append({"piece": pid, "etat": 1.0})
		else:
			stocks[k] = float(stocks.get(k, 0.0)) + float(rc[k])
	# l'escorte reste dans la ville ; la cargaison est déchargée
	var esc: Array = mission.escorte
	convoi = convoi.filter(func(v): return not esc.has(v.uid))
	BerlietConfig.regler(berliet_config, "module", String(mission.module_avant))
	_berliet_longueur()
	_replacer(true)
	mission_bilan = {"ok": true, "titre": "Livraison à %s" % ville.nom,
		"texte": "« %s ! Vous êtes attendus depuis l'aube. » Le maire de %s vous remet : %s.\n\nLes hommes de %s restent ici ; on ne revoit jamais ceux qui s'éloignent." % [
			String(T.nom), ville.nom, texte_recompense(rc), mission.origine]}
	mission = {}
	log_("Cargaison livrée à %s : %s." % [ville.nom, texte_recompense(rc)], "ok")
	evt({"t": "mission", "etat": "livree"})


# --- Sauvegarde ------------------------------------------------------------------------------
func mission_sauver() -> Dictionary:
	return {"mission": mission.duplicate(true), "bilan": mission_bilan.duplicate()}


func mission_charger(d: Dictionary) -> void:
	mission = d.get("mission", {}).duplicate(true)
	mission_bilan = d.get("bilan", {}).duplicate()
	if mission_active():
		mission.dest = int(mission.dest)
		mission.vagues = int(mission.vagues)
		mission.escorte = mission.escorte.map(func(u): return int(u))
