# Usure et fiabilité d'un véhicule (Grille V2, P3). Principes du porteur de projet (07/11) :
# - un véhicule d'origine n'est PAS plus fiable : dans ce monde il est vieux et en mauvais état (champ "etat" des pièces) ;
# - un moteur peu puissant ménage la boîte ; peu de charge et pas de châssis rallongé ménagent les essieux ;
# - améliorer doit rapporter : bien dimensionné et renforcé, un véhicule s'use deux fois moins vite que l'original ;
# - seul le mal dimensionné (moteur beaucoup trop petit, essieu surchargé, boîte dépassée) fatigue.
# Résultat : un multiplicateur d'usure par organe (1,0 = usure normale). Fonctions pures, graine explicite (AGENTS.md).
class_name FiabiliteVehicule
extends RefCounted


static func souplesse(a: Dictionary) -> float:   # flexion du châssis : crans de rallonge, divisée par les renforts
	if not a.has("base"):
		return 0.0
	var RG: Dictionary = BaseVehicule.regles().rigidite
	var cr: Dictionary = a.base.crans
	var s := float(RG.souplesse_par_cran_milieu) * float(cr.milieu) + float(RG.souplesse_par_cran_porte_a_faux) * float(int(cr.avant) + int(cr.arriere))
	return s * pow(float(BaseVehicule.regles().renfort.souplesse_par_renfort), float(a.base.renforts))


static func _fe(etat: float, U: Dictionary) -> float:   # facteur d'état : une pièce usée s'use plus vite
	return 1.0 + (1.0 - clampf(etat, 0.0, 1.0)) * float(U.etat_mauvais_facteur)


# Charge portée par chaque essieu (kg), par la règle du levier autour du centre de gravité (cellules). Même ordre que ess.
static func charges_essieux(ess: Array, masse_kg: float, cg_x: float) -> Array:
	var n := ess.size()
	var res := []
	if n == 0:
		return res
	var xs := []
	var moy := 0.0
	for e in ess:
		xs.append(float(e.x) + 0.5)
		moy += float(e.x) + 0.5
	moy /= float(n)
	var s2 := 0.0
	for x in xs:
		s2 += (float(x) - moy) * (float(x) - moy)
	var k := 0.0 if s2 < 0.000001 else (cg_x - moy) / s2
	var w := []
	var total := 0.0
	for x in xs:
		var wi := maxf(0.03, 1.0 / float(n) + k * (float(x) - moy))
		w.append(wi)
		total += wi
	for wi in w:
		res.append(masse_kg * float(wi) / total)
	return res


static func _mult_charge(ratio: float, plancher: float, surcharge: float) -> float:
	if ratio <= 1.0:
		return plancher + (1.0 - plancher) * ratio
	return 1.0 + surcharge * (ratio - 1.0)


static func _verdict(indice: float) -> String:
	for v in BaseVehicule.regles().verdicts:
		if indice < float(v[0]):
			return String(v[1])
	return "à bout"


static func evaluer(a: Dictionary) -> Dictionary:
	var an := ConstructionLibre.analyser(a)
	if not bool(an.ok):
		return {"ok": false}
	var U: Dictionary = BaseVehicule.regles().usure
	var plafond := float(U.plafond)
	var det: Dictionary = an.detail
	var bs: Dictionary = a.get("base", {})
	var masse := float(det.poids_kg) + BaseVehicule.poids_supplementaire(a)
	var tonnes := maxf(0.1, masse / 1000.0)
	var puissance := float(det.puissance)
	var defauts := []
	# Moteur : sous-dimensionné pour la masse = il tourne à fond ; très sous-dimensionné = inadapté ; surpuissant = ménagé
	var besoin := float(ConstructionLibre.R().ch_par_tonne_requis) * tonnes
	var rapport := puissance / maxf(1.0, besoin)
	var m_moteur := 1.0
	if rapport < 1.0:
		m_moteur = 1.0 + float(U.moteur_sous_dimensionne) * (1.0 - rapport)
		if rapport < 0.5:
			m_moteur += float(U.moteur_inadapte_en_plus) * (0.5 - rapport) / 0.5
			defauts.append("Moteur inadapté : %d ch pour %.1f t" % [int(puissance), tonnes])
		else:
			defauts.append("Moteur juste : %d ch pour %.1f t" % [int(puissance), tonnes])
	else:
		m_moteur = maxf(float(U.moteur_plancher), 1.0 - float(U.moteur_surpuissant_gain) * (rapport - 1.0))
	var etat_m := 1.0
	for p in a.get("pieces", []):
		if String(Assemblage.piece(String(p.piece)).get("famille", "")) == "moteur":
			etat_m = minf(etat_m, float(p.get("etat", 1.0)))
	m_moteur = minf(plafond, m_moteur * _fe(etat_m, U))
	# Boîte : moins elle est sollicitée par la puissance, plus elle dure
	var boites: Dictionary = BaseVehicule.regles().boites
	var cap_boite := puissance * 1.5
	if boites.has(String(bs.get("boite", ""))):
		cap_boite = float(boites[String(bs.boite)].puissance_ch)
	var charge_b := puissance / maxf(1.0, cap_boite)
	var m_boite := minf(plafond, _mult_charge(charge_b, float(U.boite_plancher), float(U.boite_surcharge)) * _fe(float(bs.get("etat_boite", 1.0)), U))
	if charge_b > 1.0:
		defauts.append("Boîte dépassée : %d ch pour une boîte de %d ch" % [int(puissance), int(cap_boite)])
	# Essieux : charge portée / capacité, aggravée par la flexion du châssis rallongé
	var flex := souplesse(a)
	var ess: Array = det.essieux
	var charges := charges_essieux(ess, masse, float(det.cg.x))
	var liste := []
	var somme := 0.0
	for i in ess.size():
		var e: Dictionary = ess[i]
		var cap := minf(float(e.fiche_e.get("charge_kg", 1000)), float(e.fiche_t.get("charge_kg", 1000)))
		var ratio := float(charges[i]) / maxf(1.0, cap)
		var etat_e := 1.0
		for r in a.get("essieux", []):
			if int(r.x) == int(e.x):
				etat_e = float(r.get("etat", 1.0))
		var m := _mult_charge(ratio, float(U.essieu_plancher), float(U.essieu_surcharge)) * _fe(etat_e, U) * (1.0 + float(BaseVehicule.regles().rigidite.essieu_par_souplesse) * flex)
		m = minf(plafond, m)
		if ratio > 1.0:
			defauts.append("Essieu %d surchargé : %d kg pour %d kg" % [i + 1, int(charges[i]), int(cap)])
		liste.append({"x": int(e.x), "mult": m, "charge_kg": float(charges[i]), "capacite_kg": cap})
		somme += m
	var m_essieux := somme / float(maxi(1, ess.size()))
	# Châssis
	var m_chassis := _fe(float(bs.get("etat_chassis", 1.0)), U) * (1.0 + float(BaseVehicule.regles().rigidite.chassis_par_souplesse) * flex)
	m_chassis = minf(plafond, m_chassis * pow(float(BaseVehicule.regles().renfort.usure_chassis), float(bs.get("renforts", 0))))   # châssis renforcé : plus costaud que l'original
	if flex > 0.2:
		defauts.append("Châssis rallongé sans assez de renforts (souplesse %.2f)" % flex)
	var indice := 0.3 * m_moteur + 0.25 * m_boite + 0.25 * m_essieux + 0.2 * m_chassis
	return {"ok": true, "usure": {"moteur": m_moteur, "boite": m_boite, "essieux": liste, "chassis": m_chassis}, "indice": indice,
		"verdict": _verdict(indice), "defauts": defauts, "masse_kg": masse}


# Pannes tirées sur km kilomètres : [{organe: "moteur" | "boite" | "essieu" | "chassis", x: colonne de l'essieu ou -1}].
# Déterministe pour une graine donnée.
static func tirer_pannes(a: Dictionary, km: float, graine: int) -> Array:
	var ev := evaluer(a)
	if not bool(ev.ok):
		return []
	var taux := float(BaseVehicule.regles().pannes.taux_base_par_km)
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var res := []
	if rng.randf() < 1.0 - exp(-taux * float(ev.usure.moteur) * km):
		res.append({"organe": "moteur", "x": -1})
	if rng.randf() < 1.0 - exp(-taux * float(ev.usure.boite) * km):
		res.append({"organe": "boite", "x": -1})
	for e in ev.usure.essieux:
		if rng.randf() < 1.0 - exp(-taux * float(e.mult) * km):
			res.append({"organe": "essieu", "x": int(e.x)})
	if rng.randf() < 1.0 - exp(-taux * float(ev.usure.chassis) * km):
		res.append({"organe": "chassis", "x": -1})
	return res
