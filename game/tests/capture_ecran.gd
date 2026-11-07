# Capture de l'écran de transformation (DEV-016) : T23 à l'atelier, onglet Structure, après une rallonge.
#   xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 --resolution 1280x720 -s res://tests/capture_ecran.gd -- /dossier
extends SceneTree

var frame := 0
var dossier := "/tmp"
var ecran: EcranTransformation


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		dossier = args[0]
	ecran = EcranTransformation.new()
	var res := [{"piece": "essieu_lourd", "etat": 0.9}, {"piece": "roue_grande", "etat": 0.8}]
	ecran.ouvrir(BaseVehicule.creer("citroen_t23"), {"niveau": 2, "metal": 20.0, "mecaniciens": 1, "reserve": res})
	root.add_child(ecran)


func _process(_d: float) -> bool:
	frame += 1
	if frame == 3:
		ecran._faire(TransformationBase.de_onglet(TransformationBase.entrees(ecran.a, ecran.ctx), "structure").filter(func(e): return e.id == "rallonge_milieu")[0])
	if frame == 8:
		root.get_texture().get_image().save_jpg("%s/ecran.jpg" % dossier, 0.85)
		print("capture ecran")
		quit()
	return false
