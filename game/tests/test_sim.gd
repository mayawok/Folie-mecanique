# Test sans écran : godot --headless --path game -s res://tests/test_sim.gd
# Vérifie le temps réel : consommation horaire, expédition à retour différé,
# pénurie graduée, agitation bloquée pendant l'absence, plafond de 72 h, sauvegarde.
extends SceneTree

var echecs := 0

func verifier(cond: bool, msg: String) -> void:
	print(("OK   " if cond else "ÉCHEC ") + msg)
	if not cond:
		echecs += 1

func _init() -> void:
	var j := Jeu.new()
	j.effacer_partie()
	var eau0: float = j.stocks.water_l
	j.signaler_action()
	j.avancer_tests(6)
	verifier(j.stocks.water_l < eau0, "l'eau baisse heure par heure")
	# Expédition : rien n'est résolu au départ, tout l'est au retour
	var r := j.lancer("oasis", j.vehicules_prets().slice(0, 1), "repli")
	verifier(r.ok and j.expeditions.size() == 1 and j.rapports.is_empty(), "le convoi part, résultat différé")
	verifier(j.vehicules_prets().size() == 2, "le véhicule parti n'est plus disponible")
	j.signaler_action()
	j.avancer_tests(4)
	verifier(j.expeditions.is_empty() and j.rapports.size() == 1, "le convoi revient après 4 h avec un rapport")
	print("   ", j.rapports[0].lignes)
	# Pénurie pendant une absence : l'étape 3 attend le joueur
	j.stocks.water_l = 0
	j.stocks.food = 0
	j.derniere_action -= 3 * 86400
	j.avancer_tests(60)
	verifier(j.etape == 2, "absent : la pénurie s'arrête à l'étape 2 (étape %d)" % j.etape)
	j.signaler_action()
	j.avancer_tests(1)
	verifier(j.etape == 3, "présent : l'agitation se déclenche")
	j.avancer_tests(12)
	verifier(not j.decision.is_empty(), "une révolte attend une décision")
	j.decider("pardonner")
	# Plafond de rattrapage
	j.stocks.water_l = 150
	j.stocks.food = 40
	var b := j.avancer_tests(200)
	verifier(b.heures == 72, "rattrapage plafonné à 72 h (%d h)" % b.heures)
	# Sauvegarde
	var t: int = j.t
	var k := Jeu.new()
	verifier(k.t == t and k.survivants.size() == j.survivants.size(), "la partie est relue à l'identique")
	k.effacer_partie()
	print("Échecs : %d" % echecs)
	quit(echecs)
