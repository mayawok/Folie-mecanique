# Mesure de performance (chantier Performance iPhone, DEC-262) : combat chargé, gore maximum, puis temps de traitement
# (scripts et rappels de dessin) et appels de dessin, calque par calque (on cache un calque à la fois). Outil, pas un test.
#   xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 --resolution 1280x720 -s res://tests/mesure_perf.gd
extends SceneTree

var vue
var f := 0
var phase := 0
var phases := ["tout", "sans décor", "sans premier plan", "sans véhicules", "sans ombres", "sans lumières", "sans effets", "sans ville", "sans interface"]
var acc := {"process": 0.0, "appels": 0.0, "objets": 0.0, "n": 0}
const N := 90


func _initialize() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://convoi_save.json"))
	vue = load("res://scenes/convoi.tscn").instantiate()
	root.add_child(vue)


func _cacher(nom: String, oui: bool) -> void:
	match nom:
		"sans décor": vue.terrain.visible = not oui
		"sans premier plan": vue.terrain_avant.visible = not oui
		"sans véhicules": vue.couche.visible = not oui
		"sans ombres": vue.ombres.visible = not oui
		"sans lumières": vue.lumieres.visible = not oui
		"sans effets": vue.fx.visible = not oui
		"sans ville": vue.ville_calque.visible = not oui
		"sans interface":
			for c in vue.get_children():
				if c is CanvasLayer or (c is Control and not c in [vue.terrain, vue.terrain_avant, vue.couche, vue.ombres, vue.lumieres, vue.fx, vue.ville_calque, vue.bandeau, vue.mission_calque]):
					c.visible = not oui


func _process(_d: float) -> bool:
	f += 1
	if f == 3:
		vue._nouvelle_partie(7, {}, false, true)
		Gore.regler(2)
		var args := OS.get_cmdline_user_args()
		vue.m.kit_regler_zone(args[0] if args.size() > 0 else "terre")
		if not (args.size() > 1 and args[1] == "calques"):
			phases = ["tout"]
		vue.m.kit_regler_heure(0.45)
		vue.m._prochain_x = INF
		vue.pause = true   # le modèle est avancé à la main, un pas par image : même scène d'une mesure à l'autre
		vue.m.stocks.ammo = 1.0e6
		for v in vue.m.convoi:
			for p in v.pieces.values():
				p.pv *= 50.0   # le convoi tient le temps de la mesure
		vue.m.ordre_marche("avancer")
	if f == 60:
		vue.m.rng.seed = 5
		for k in 3:
			vue.m.kit_scenario("raid", "grand")
	if f > 3 and f < 330:
		vue.m.avancer()
	if f > 350:
		var i := (f - 351) / N
		if i >= phases.size():
			if phase < phases.size():
				print("%-18s traitement %6.1f ms   appels de dessin %6.0f   éléments %6.0f" % [phases[phase], acc.process / acc.n, acc.appels / acc.n, acc.objets / acc.n])
			print("ennemis=%d noeuds=%d" % [vue.m.ennemis.size(), Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
			var t0 := Time.get_ticks_usec()
			for k in 50:
				vue.m.avancer()
			print("modèle : %.2f ms par pas (0,1 s de jeu)" % ((Time.get_ticks_usec() - t0) / 50000.0))
			t0 = Time.get_ticks_usec()
			vue._sauver_vue()
			print("sauvegarde : %.1f ms, %d octets" % [(Time.get_ticks_usec() - t0) / 1000.0, FileAccess.get_file_as_bytes("user://convoi_save.json").size()])
			quit(0)
			return true
		if i != phase:
			print("%-18s traitement %6.1f ms   appels de dessin %6.0f   éléments %6.0f" % [phases[phase], acc.process / acc.n, acc.appels / acc.n, acc.objets / acc.n])
			_cacher(phases[phase], false)
			phase = i
			_cacher(phases[phase], true)
			acc = {"process": 0.0, "appels": 0.0, "objets": 0.0, "n": 0}
		if (f - 351) % N > 10:
			acc.process += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
			acc.appels += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			acc.objets += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
			acc.n += 1
	return false
