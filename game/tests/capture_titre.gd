# Écran d'accueil animé : captures à 0,5 s et 6 s, en 1920×1080 puis en écran large (iPhone, 2556×1179).
#   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path game --rendering-driver opengl3 --resolution 1920x1080 \
#     -s res://tests/capture_titre.gd -- /chemin/dossier
extends SceneTree

var vue
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
	if frame == 40 or frame == 400:
		root.get_texture().get_image().save_png("%s/titre_%d.png" % [dossier, frame])
		print("capture ", frame)
	if frame == 410:
		quit()
	return false
