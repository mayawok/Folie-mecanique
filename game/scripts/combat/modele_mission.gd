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
var evenement := {}        # ville pillée (DEC-151) : {type, ville, phase: attente | chasse, pillards: [uid], butin}
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
	var plan := mission_plan(t, int(dest.id))
	return "« J'ai %s qui doivent arriver à %s. C'est une seule étape, %d m par la %s, sans détour.\n\nSur la route, on me parle de %s.%s %s\n\nJe vous donne des hommes : %s. Livrez tout à %s et le maire là-bas vous paiera : %s. »" % [
		T.cargaison, dest_nom, int(dest.distance_m), String(dest.porte).to_lower(), plan.presence, (" " + String(M.menace.pillards)) if plan.pillards_annonces else "",
		M.menace.incertitude, M.escorte_texte, dest_nom, texte_recompense(T.recompense)]


# Ce qui attend vraiment le convoi sur l'étape (DEC-150) : vagues tirées dans la table des rencontres du monde selon le niveau,
# et ce que le maire en sait (présence selon le niveau, pillards parfois signalés à tort ou passés sous silence).
# Même graine pour l'offre et l'acceptation : ce que le maire annonce correspond à la mission jouée.
func mission_plan(t: String, dest: int) -> Dictionary:
	var Me: Dictionary = MD().menace
	var niveau := maxi(int(monde.secteurs[monde.secteur].niveau), int(monde.secteurs[dest].niveau))
	var r := RandomNumberGenerator.new()
	r.seed = int(ville.get("graine", 0)) * 53 + dest * 11 + String(t).hash() % 1000
	var table: Array = donnees().rencontres.liste.filter(func(e): return not e.get("vehicules", []).is_empty() and niveau >= int(e.niveau_min) and niveau <= int(e.niveau_max))
	var n: int = int(Me.vagues_par_niveau[clampi(niveau, 0, Me.vagues_par_niveau.size() - 1)])
	var parts := []
	for i in n:
		parts.append(r.randf_range(float(Me.part_min), float(Me.part_max)))
	parts.sort()
	var vagues := []
	var total := 0.0
	for e in table:
		total += float(e.poids)
	for i in n:
		if table.is_empty():
			break
		var tirage := r.randf() * total
		var choix: Dictionary = table[table.size() - 1]
		for e in table:
			tirage -= float(e.poids)
			if tirage <= 0.0:
				choix = e
				break
		var v: Dictionary = choix.duplicate(true)
		v["part"] = parts[i]
		v["mode"] = String(choix.get("mode", "approche"))
		vagues.append(v)
	var vrais_pillards := vagues.any(func(v): return v.mode == "poursuite")
	var annonce := r.randf() < (float(Me.pillards_si_vrai) if vrais_pillards else float(Me.pillards_rumeur))
	var presence := ""
	for p in Me.presence:
		if niveau >= int(p[0]) and niveau <= int(p[1]):
			presence = String(p[2])
	return {"niveau": niveau, "vagues": vagues, "presence": presence, "pillards_annonces": annonce}


static func texte_recompense(rc: Dictionary) -> String:
	var mots := {"gazole": "%d L de gazole", "essence": "%d L d'essence", "ammo": "%d munitions", "metal": "%d métal", "eau": "%d bidons d'eau", "vivres": "%d caisses de vivres", "pieces": "%d pièce(s) de véhicule"}
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
		"module_avant": String(berliet_config.module), "phase": "prep", "vagues": 0, "plan": mission_plan(t, int(offre.dest)).vagues}
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
	_evenement()
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
	var vagues: Array = mission.plan
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
	log_(String(MD().menace.alerte_poursuite if String(v.get("mode", "")) == "poursuite" else MD().menace.alerte_approche), "alerte")
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


# --- Ville pillée : poursuite du convoi des pillards (DEC-151) ------------------------------------
func ville_poursuite() -> bool:
	if not ville_dedans() or not ville_pillee() or not evenement.is_empty():
		return false
	var P: Dictionary = VD().variantes.pillee
	evenement = {"type": "pillage", "ville": String(ville.nom), "phase": "attente", "pillards": [], "butin": P.butin.duplicate()}
	ville.phase = "depart"
	log_("En route ! Le convoi traverse %s à toute allure." % ville.nom, "alerte")
	evt({"t": "pillage", "etat": "poursuite"})
	return true


func _evenement() -> void:
	if evenement.is_empty():
		return
	var P: Dictionary = VD().variantes.pillee
	if String(evenement.phase) == "attente":
		if ville_active() and ville_phase() != "fin":
			return
		# le convoi des pillards roule devant, moins vite que nous
		var vmin := INF
		for v in convoi:
			if v.actif():
				vmin = minf(vmin, vitesse_attelee(v))
		var vp := maxf(1.5, (vmin if vmin < INF else 4.0) * float(P.pillards_vitesse_part))
		var x := x_tete + float(P.pillards_devant_m)
		for t in P.pillards:
			var e := creer_vehicule(String(t), "ennemi", x)
			e.mode = "convoi"
			_kit_convois[e.uid] = vp
			ennemis.append(e)
			evenement.pillards.append(e.uid)
			x += e.longueur + 6.0
		evenement.phase = "chasse"
		log_("Le convoi des pillards est en vue, %d m devant. Rattrapez-le !" % int(P.pillards_devant_m), "alerte")
		evt({"t": "contact", "ennemi": true})
		return
	var restants := ennemis.filter(func(e): return evenement.pillards.has(e.uid) and e.actif())
	if restants.is_empty():
		for k in evenement.butin:
			stocks[k] = float(stocks.get(k, 0.0)) + float(evenement.butin[k])
		mission_bilan = {"ok": true, "titre": "Réserves reprises", "texte": "Le convoi des pillards est détruit. Vous récupérez les réserves de %s : %s." % [evenement.ville, texte_recompense(evenement.butin)]}
		log_("Pillards détruits : vous récupérez %s." % texte_recompense(evenement.butin), "ok")
		evenement = {}
		evt({"t": "pillage", "etat": "reussi"})
		return
	var devant := INF
	for e in restants:
		devant = minf(devant, e.x - x_tete)
	if devant > float(P.pillards_perdus_m):
		mission_bilan = {"ok": false, "titre": "Pillards perdus", "texte": "Le convoi des pillards a disparu dans le no man's land avec les réserves de %s." % evenement.ville}
		log_("Les pillards ont disparu dans le no man's land.", "alerte")
		ennemis = ennemis.filter(func(e): return not evenement.pillards.has(e.uid))
		evenement = {}
		evt({"t": "pillage", "etat": "perdu"})


# --- Sauvegarde ------------------------------------------------------------------------------
func mission_sauver() -> Dictionary:
	return {"mission": mission.duplicate(true), "bilan": mission_bilan.duplicate(), "evenement": evenement.duplicate(true)}


func mission_charger(d: Dictionary) -> void:
	mission = d.get("mission", {}).duplicate(true)
	mission_bilan = d.get("bilan", {}).duplicate()
	evenement = d.get("evenement", {}).duplicate(true)
	if not evenement.is_empty():   # les ennemis ne sont pas sauvegardés : le convoi des pillards repart devant
		evenement.pillards = []
		evenement.phase = "attente"
	if mission_active():
		mission.dest = int(mission.dest)
		mission.vagues = int(mission.vagues)
		mission.escorte = mission.escorte.map(func(u): return int(u))
