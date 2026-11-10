# Capture : poursuivants arrivés par l'arrière, pillard à l'abordage avec une lance explosive (DEC-077).
#   xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 \
#     --resolution 1280x720 -s res://tests/capture_abordage.gd -- /chemin/dossier
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


func _process(_d: float) -> bool:
	frame += 1
	if frame == 3:
		vue._nouvelle_partie(11, {}, false)
		var m = vue.m
		m._prochain_x = 1.0e9
		m.stocks.gazole = 300.0
		for v in m.convoi:
			m.ordre_tir(v.uid, false)
		var xq: float = m.x_tete
		for v in m.convoi:
			xq = minf(xq, v.x)
		for t in ["citroen_traction", "bmw_r75"]:
			var e = m.creer_vehicule(t, "ennemi", xq - 25.0)
			m.preparer_poursuivant(e, {"abordeurs": 2, "types": ["bombe", "lame"]})
			e.armes = []
			m.ennemis.append(e)
			xq -= 12.0
		m.ordre_marche("avancer")
		vue.vitesse_sim = 1
	if frame > 3 and not vue.m.abordeurs.is_empty() and vue.m.abordeurs[0].etat == "saut" and float(vue.m.abordeurs[0].t) > 0.4:
		root.get_texture().get_image().save_png("%s/abordage.png" % dossier)
		print("capture abordage")
		quit(0)
	if frame > 2400:
		root.get_texture().get_image().save_png("%s/abordage.png" % dossier)
		print("capture abordage (délai)")
		quit(0)
	return false
