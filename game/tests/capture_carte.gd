# Capture de la carte du monde du Kit (DEC-154) : vue entière, puis zoom sur une ville choisie avec itinéraire et dangers.
#   xvfb-run -a godot --path game --rendering-driver opengl3 --resolution 1280x720 -s res://tests/capture_carte.gd -- /dossier
extends SceneTree

var vue
var carte
var frame := 0
var dossier := "/tmp"


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
		carte = vue._ouvrir_carte_kit()
	if frame == 40:
		root.get_texture().get_image().save_jpg("%s/carte_kit_1.jpg" % dossier, 0.85)
		carte.choisir("rhin")
		carte.calculer_itineraire()
		carte.couches["dangers"] = true
	if frame == 60:
		root.get_texture().get_image().save_jpg("%s/carte_kit_2.jpg" % dossier, 0.85)
		carte.zoomer(2.0, carte._ecran(CarteMonde.pos("capitale")))
	if frame == 80:
		root.get_texture().get_image().save_jpg("%s/carte_kit_3.jpg" % dossier, 0.85)
		print("captures carte_kit_1..3")
		quit(0)
	return false
