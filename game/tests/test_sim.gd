# Test sans écran : godot --headless --path game -s res://tests/test_sim.gd
extends SceneTree

func _init() -> void:
	var j := Jeu.new()
	for i in 3:
		print(j.passer_journee())
	var convoi := j.vehicules_prets().slice(0, 2)
	print(j.briefing("depot", convoi))
	var r := j.lancer("depot", convoi, "bout")
	print("\n".join(r.lignes))
	print(r.convoi, r.pillards, j.stocks)
	for i in 8:
		j.passer_journee()
	r = j.lancer("champ", j.vehicules_prets(), "repli")
	print("\n".join(r.lignes))
	print(j.journal.slice(-5), j.stocks, j.survivants.size())
	quit()
