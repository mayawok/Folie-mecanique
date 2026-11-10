# Simulation d'équilibrage (DEC-222) : un convoi d'essai affronte un ennemi qui arrive de face (béliers / harceleurs).
# Sortie : PV perdus par le convoi (%), ennemi détruit ou non, temps. Non lancé par la CI (lent).
# godot --headless --path game -s res://tests/sim_equilibrage.gd
extends SceneTree


func _init() -> void:
	Textes.langue = "fr"
	var cas := ["moto_zundapp", "moto_gnome", "peugeot_202", "kubelwagen", "opel_blitz", "gmc_cckw"]
	for t in cas:
		var pertes := 0.0
		var morts := 0
		var n := 3
		for s in n:
			var m := CombatModele.new(200 + s, {"bac_a_sable": true})
			var a := ConstructionLibre.voiture("moyen")
			a.nom = "Essai"
			m.construire_grille(0, a)
			m.ordre_marche("avancer")
			var v: CombatModele.Veh = m._tete()
			var pv0 := 0.0
			for id in v.pieces:
				pv0 += float(v.pieces[id].pv)
			var e := m.creer_vehicule(t, "ennemi", v.x + 110.0)
			e.mode = "approche"
			m.ennemis.append(e)
			for i in int(45.0 / CombatModele.DT):
				m.avancer()
			var pv1 := 0.0
			for id in v.pieces:
				pv1 += float(v.pieces[id].pv)
			pertes += 100.0 * (pv0 - pv1) / pv0
			if not e.actif():
				morts += 1
		print("%-14s pertes moyennes %.0f %% · ennemi détruit %d/%d" % [t, pertes / n, morts, n])
	quit()
