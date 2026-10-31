# Test sans écran des véhicules en pièces (grille, étape G1) :
#   godot --headless --path game -s res://tests/test_assemblage.gd
# Vérifie : les 10 véhicules historiques sont valides et leurs statistiques calculées sont celles du jeu ;
# les règles de la grille (dépassement, chevauchement, pièces manquantes, surcharge) ; deux « Frankenstein ».
extends SceneTree

var echecs := 0
const ATTENDU := {   # profils de combat avant G1 (valeurs de référence)
	"willys_mb": [6.5, 2, 1.0, 12, 8, 2, true, ["mitrailleuse"], [55, 35, 25, 30, 25]],
	"bmw_r75": [7.5, 1, 0.8, 8, 6, 2, true, ["mitrailleuse"], [40, 28, 20, 28, 18]],
	"citroen_traction": [6.0, 4, 1.4, 14, 10, 2, false, ["mitrailleuse"], [70, 40, 28, 35, 30]],
	"citroen_t23": [5.0, 5, 2.5, 25, 16, 2, false, ["mitrailleuse"], [90, 50, 35, 45, 35]],
	"diamond_t": [4.5, 8, 4.0, 40, 25, 2, false, ["mitrailleuse"], [130, 70, 50, 70, 45]],
	"dukw": [3.8, 6, 4.5, 40, 22, 2, true, ["mitrailleuse"], [140, 65, 45, 60, 40]],
	"m3_half_track": [5.0, 12, 3.5, 30, 24, 3, true, ["mitrailleuse"], [150, 70, 45, 65, 50]],
	"m3_stuart": [5.5, 28, 3.5, 30, 30, 3, false, ["canon_leger", "mitrailleuse"], [170, 80, 50, 70, 55]],
	"m4_sherman": [4.5, 45, 5.0, 60, 45, 3, false, ["canon_75", "mitrailleuse"], [240, 110, 70, 100, 80]],
	"tiger_1": [3.2, 80, 9.0, 90, 70, 3, false, ["canon_88"], [380, 160, 100, 140, 120]],
}


func verifier(cond: bool, msg: String) -> void:
	print(("OK   " if cond else "ÉCHEC ") + msg)
	if not cond:
		echecs += 1


func _codes(a: Dictionary) -> Array:
	return Assemblage.valider(a).map(func(e): return e.code)


func _remplacer(a: Dictionary, famille: String, nouvelle: String) -> void:
	for p in a.pieces:
		if Assemblage.piece(p.piece).famille == famille:
			p.piece = nouvelle
			return


func _init() -> void:
	# 1. Historiques : valides, statistiques identiques au jeu
	for type in ATTENDU:
		var a := Assemblage.de_type(type)
		var err := Assemblage.valider(a)
		verifier(err.is_empty(), "%s valide %s" % [type, "" if err.is_empty() else str(err)])
		var s := Assemblage.statistiques(a)
		var r: Array = ATTENDU[type]
		var pv := [s.pv.chassis, s.pv.roulement, s.pv.suspension, s.pv.moteur, s.pv.cabine]
		var ok: bool = absf(s.vitesse - r[0]) < 0.001 and s.blindage == r[1] and absf(s.conso - r[2]) < 0.001 \
			and s.reservoir == r[3] and s.metal == r[4] and s.equipage == r[5] and s.ouvert == r[6] \
			and s.armes == r[7] and pv == r[8].map(func(x): return float(x))
		verifier(ok, "%s : statistiques calculées = profil du jeu (%.1f m/s, blindage %d, %d kg)" % [type, s.vitesse, s.blindage, s.poids_kg])

	# 2. Le combat utilise bien les statistiques calculées
	var m := CombatModele.new(1)
	var v: CombatModele.Veh = m.ajouter_vehicule("m4_sherman")
	verifier(v.profil.has("poids_kg") and v.pieces.chassis.max == 240.0, "le combat lit le profil calculé (Sherman)")

	# 3. Règles de la grille
	var a := Assemblage.de_type("willys_mb")
	a.pieces = a.pieces.filter(func(p): return Assemblage.piece(p.piece).famille != "moteur")
	verifier("moteur" in _codes(a), "sans moteur : refusé")
	a = Assemblage.de_type("willys_mb")
	a.pieces[0].pos = [5, 0]
	verifier("hors_grille" in _codes(a), "roues qui dépassent du châssis : refusé")
	a = Assemblage.de_type("willys_mb")
	a.pieces.append(a.pieces[2].duplicate(true))   # second moteur au même endroit
	var c := _codes(a)
	verifier("chevauchement" in c and "moteur" in c, "deux moteurs superposés : refusé")
	a = Assemblage.de_type("willys_mb")
	a.pieces[0].pos = [0, 1]
	verifier("roulement_haut" in _codes(a), "roues en l'air : refusé")

	# 4. Frankenstein n° 1 : Willys avec le moteur du Sherman (surchargé mais roule, plus lent)
	a = Assemblage.de_type("willys_mb")
	_remplacer(a, "moteur", "moteur_m4_sherman")
	verifier("hors_grille" in _codes(a), "moteur de Sherman à la place d'origine : ne rentre pas")
	for p in a.pieces:   # on déplace la cabine à l'arrière pour lui faire de la place
		if Assemblage.piece(p.piece).famille == "cabine":
			p.pos = [0, 3]
		elif Assemblage.piece(p.piece).famille == "moteur":
			p.pos = [5, 3]
	var err := Assemblage.valider(a)
	var s := Assemblage.statistiques(a)
	verifier(err.is_empty() and s.vitesse < 6.5 and s.conso == 5.0, "Willys à moteur de Sherman : valide, %.2f m/s, consomme 5" % s.vitesse)

	# 5. Frankenstein n° 2 : camion T23 armé du canon du Stuart
	a = Assemblage.de_type("citroen_t23")
	a.pieces.append({"piece": "arme_canon_leger", "pos": [0, 7]})
	err = Assemblage.valider(a)
	s = Assemblage.statistiques(a)
	verifier(err.is_empty() and "canon_leger" in s.armes and s.poids_kg > Assemblage.poids(Assemblage.de_type("citroen_t23")),
		"T23 au canon de 37 : valide, armes %s %s" % [str(s.armes), "" if err.is_empty() else str(err)])

	# 6. Canon du Tiger sur une Jeep : trop long et trop lourd
	a = Assemblage.de_type("willys_mb")
	a.pieces.append({"piece": "arme_canon_88", "pos": [0, 6]})
	c = _codes(a)
	verifier("hors_grille" in c or "surcharge" in c, "Willys au canon de 88 : refusé %s" % str(c))

	# 7. Plaques de blindage
	a = Assemblage.de_type("willys_mb")
	a.plaques = 3
	s = Assemblage.statistiques(a)
	verifier(s.blindage == 8 and s.vitesse <= 6.5, "Willys + 3 plaques : blindage 8")

	# 8. Démontage
	var d := Assemblage.demonter(Assemblage.de_type("m3_stuart"), {"moteur": 0.4})
	verifier(d.pieces.size() == 6 and d.metal > 0, "démontage du Stuart : 6 pièces + métal du châssis")

	print("Échecs : %d" % echecs)
	quit(1 if echecs > 0 else 0)
