# Test d'endurance : joue longtemps à vitesse x3 et affiche mémoire, objets et nœuds toutes les 600 images.
#   xvfb-run -a godot --path game --rendering-driver opengl3 --resolution 1280x720 -s res://tests/soak.gd
extends SceneTree

var vue
var frame := 0


func _initialize() -> void:
	vue = load("res://scenes/convoi.tscn").instantiate()
	root.add_child(vue)


func _process(_d: float) -> bool:
	frame += 1
	if frame == 3:
		vue._nouvelle_partie(7)
		vue.m.stocks.fuel_l = 1.0e6
		vue.m.stocks.ammo = 1.0e6
		vue.m.ordre_marche("avancer")
		vue.vitesse_sim = 3
	if frame > 3 and vue.m.fini:
		vue._nouvelle_partie(frame)
		vue.m.stocks.fuel_l = 1.0e6
		vue.m.stocks.ammo = 1.0e6
		vue.m.ordre_marche("avancer")
	if frame % 600 == 0:
		print("f=%d t=%.0f mem=%.1fMo objets=%d noeuds=%d orphelins=%d ennemis=%d epaves=%d bat=%d pietons=%d journal=%d" % [frame, vue.m.temps, Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, Performance.get_monitor(Performance.OBJECT_COUNT), Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), vue.m.ennemis.size(), vue.m.epaves.size(), vue.m.batiments.size(), vue.m.monde.pietons.size(), vue.m.journal.size()])
	if frame >= 7200:
		quit(0)
	return false
