# Capture : les 10 nouveaux véhicules aux couleurs des factions, un véhicule en feu, un Molotov en vol.
#   xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 --resolution 1280x720 -s res://tests/capture_lot_f.gd -- /tmp
extends SceneTree

var vue
var frame := 0
var dossier := "/tmp"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		dossier = args[0]
	vue = load("res://scenes/convoi.tscn").instantiate()
	root.add_child(vue)


func _photo(nom: String) -> void:
	root.get_texture().get_image().save_png("%s/%s.png" % [dossier, nom])
	print("capture ", nom)


func _process(_d: float) -> bool:
	frame += 1
	var m = vue.m
	if frame == 3:
		vue._nouvelle_partie(11, {}, false)
		m = vue.m
		m._prochain_x = 1.0e9
		m.batiments.clear()
		m.epaves.clear()
		var types := ["moto_zundapp", "moto_harley", "moto_gnome", "peugeot_202", "juvaquatre", "kubelwagen", "citroen_h", "opel_blitz", "gmc_cckw", "laffly_s15"]
		var facs: Array = CarteMonde.donnees().factions.keys()
		var x: float = m.x_tete + 14.0
		var i := 0
		for t in types:
			var e = m.creer_vehicule(t, "ennemi", x)
			e.mode = "barrage"
			e.faction = String(facs[i % facs.size()]) if i < 9 else "bandits"
			m.ennemis.append(e)
			x += e.longueur + 1.2
			i += 1
		m.ennemis[3].feu = 30.0
		m.ennemis[3].feu_dps = 0.0
		m.ordre_marche("arret")
	if frame == 40:
		_photo("lot_f_a")
		quit()
	return false
