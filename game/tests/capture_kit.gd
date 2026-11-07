# Parcours écran du Kit (DEC-110) : Mode créatif, panneau ouvert, chaque zone, convoi à rattraper, poursuite.
#   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path game --rendering-driver opengl3 --resolution 1920x1080 \
#     -s res://tests/capture_kit.gd -- /chemin/dossier
extends SceneTree

var vue
var frame := 0
var dossier := "/tmp"
const ETAPES := [60, 140, 220, 300, 380, 460, 540]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		dossier = args[0]
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://convoi_save.json"))
	vue = load("res://scenes/convoi.tscn").instantiate()
	root.add_child(vue)


func _process(_d: float) -> bool:
	frame += 1
	if frame == 10:
		vue._nouvelle_partie(3, {}, false, true)
		var a := ConstructionLibre.voiture("moyen")
		a.nom = "Essai"
		vue.m.construire_grille(0, a)
		vue.pause = false
		vue.m.ordre_marche("avancer")
		vue._kit.visible = true
		vue.m.kit_apparaitre("convoi_devant", {"types": ["citroen_t23", "willys_mb"], "vitesse": 4.5})
	if frame == 100:
		vue.m.kit_regler_zone("terre")
		vue.m.kit_apparaitre("poursuite", {"types": ["bmw_r75", "citroen_traction"], "abordeurs": 1})
	if frame == 180:
		vue.m.kit_regler_zone("cailloux")
		vue.m.kit_apparaitre("batiment", {"type": "bunker"})
	if frame == 260:
		vue.m.kit_regler_zone("eau")
	if frame == 340:
		vue.m.kit_regler_zone("sable")
		vue.m.kit_regler_heure(0.85)
	if frame == 420:
		vue.m.kit_regler_heure(0.3)
		vue.m.kit_tempete()
	if frame in ETAPES:
		root.get_texture().get_image().save_png("%s/kit_%d.png" % [dossier, frame])
		print("capture ", frame, " zone=", vue.m.kit_zone)
	if frame == 560:
		quit(0)
	return false
