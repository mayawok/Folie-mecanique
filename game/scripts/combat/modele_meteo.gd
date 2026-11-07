# Couche 2b du modèle : tempête de sable (DEC-027). Aucun dessin ici.
# Chaîne : modele_base <- modele_tir <- modele_terrain <- modele_mines <- modele_meteo <- modele_atelier <- combat_modele.
# Surtout le jour, annoncée à droite, puis : précision et vitesse réduites, usure des véhicules ouverts,
# santé des équipages non abrités en baisse (jamais jusqu'à la mort). On s'abrite comme la nuit (monde.ordre_nuit).
# Hasard : générateur propre (rng_meteo) pour ne pas déranger les autres tirages à graine fixe.
extends "res://scripts/combat/modele_mines.gd"

var _usure_t := 0.0


func meteo_cfg() -> Dictionary:
	return donnees().tempete


func _init_meteo() -> void:
	rng_meteo.seed = graine * 104729 + 17
	var iv: Array = meteo_cfg().intervalle
	_tempete_t = rng_meteo.randf_range(iv[0], iv[1])


# Compte à rebours, annonce, tempête active, fin. Appelé à chaque pas de simulation.
func _meteo(dt: float) -> void:
	if not meteo_on:
		return
	var C := meteo_cfg()
	if tempete.is_empty():
		if calme_ouverture() or en_kit or (kit_calme and bac_a_sable):
			return
		_tempete_t -= dt
		if _tempete_t > 0.0:
			return
		if monde.nuit() and rng_meteo.randf() > float(C.proba_nuit):
			_tempete_t = float(C.report_s)   # la plupart des tempêtes tombent de jour
			return
		var a: Array = C.annonce
		var d: Array = C.duree
		var delai := rng_meteo.randf_range(a[0], a[1])
		tempete = {"phase": "annonce", "reste": delai, "duree": rng_meteo.randf_range(d[0], d[1])}
		log_("Tempête de sable dans %d s : un mur de sable approche. Abritez-vous." % int(delai), "alerte")
		evt({"t": "tempete_annonce"})
		return
	tempete.reste -= dt
	if tempete.phase == "annonce":
		if tempete.reste <= 0.0:
			tempete = {"phase": "active", "reste": tempete.duree, "duree": tempete.duree}
			_usure_t = 0.0
			log_("La tempête de sable éclate.", "alerte")
			evt({"t": "tempete_debut"})
		return
	_effets_tempete(dt)
	if tempete.reste <= 0.0:
		tempete = {}
		var iv: Array = C.intervalle
		_tempete_t = rng_meteo.randf_range(iv[0], iv[1])
		log_("La tempête de sable s'apaise. Reprenez la route quand l'équipage a rembarqué.", "ok")
		evt({"t": "tempete_fin"})


# Un équipage est à couvert s'il est dans un bâtiment (garnison) ou dans un véhicule fermé (blindé) ;
# un véhicule rentré dans un hangar ou une grange est protégé avec ses occupants.
func _expose(v: Veh) -> bool:
	return v.garage == 0 and bool(v.profil.get("ouvert", false))


func _effets_tempete(dt: float) -> void:
	var C := meteo_cfg()
	_usure_t += dt
	var usure := false
	if _usure_t >= float(C.usure_s):
		_usure_t -= float(C.usure_s)
		usure = true
	for v in convoi:
		if not v.actif() or not _expose(v):
			continue
		if usure:
			for id in ["moteur", "suspension"]:
				if v.pieces.has(id) and v.pieces[id].pv > 1.0:
					v.pieces[id].pv = maxf(1.0, v.pieces[id].pv - float(C.usure_pv))   # l'usure seule ne détruit jamais une pièce
		for i in v.equipage.size():
			if v.equipage[i] > float(C.sante_min):
				v.equipage[i] = maxf(float(C.sante_min), v.equipage[i] - float(C.sante_s) * dt)
	for t in transits:   # équipages en marche vers un abri : exposés
		for k in t.pvs.size():
			if t.pvs[k] > float(C.sante_min):
				t.pvs[k] = maxf(float(C.sante_min), t.pvs[k] - float(C.sante_s) * dt)
