# Capture Grille V2 (DEV-017) : le T23 de base puis rallongé (empattement, arrière, avant), avec ses visuels.
#   xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 --resolution 1280x720 \
#     -s res://tests/capture_base.gd -- /chemin/dossier [pixels par mètre]
extends SceneTree

var frame := 0
var dossier := "/tmp"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		dossier = args[0]
	var ppm := 26.0
	if args.size() > 1:
		ppm = float(args[1])
	var fond := ColorRect.new()
	fond.color = Color("#C9B48A")
	fond.size = Vector2(1280, 720)
	root.add_child(fond)
	var sol := ColorRect.new()
	sol.color = Color("#8C7A55")
	sol.position = Vector2(0, 340)
	sol.size = Vector2(1280, 380)
	root.add_child(sol)
	var base := BaseVehicule.creer("citroen_t23")
	var v1 := BaseVehicule.rallonger(base, "milieu", 2).a
	var v2 := BaseVehicule.rallonger(BaseVehicule.rallonger(BaseVehicule.rallonger(v1, "arriere", 1).a, "avant", 1).a, "milieu", 2).a
	var y := 330.0
	for a in [base, v1, v2]:
		var d := VehiculeDessin.new()
		d.ppm = ppm
		d.configurer(FormeAssemblage.enregistrer(a))
		d.position = Vector2(20.0, y - d.size.y)
		root.add_child(d)
		y += 0.0
		if a == base:
			d.position.y = 150.0 - d.size.y + 160.0
		elif a == v1:
			d.position.y = 330.0 - d.size.y + 0.0
			d.position.x = 20.0
		else:
			d.position.y = 520.0 - d.size.y + 0.0
			d.position.x = 20.0
	print("capture base")


func _process(_d: float) -> bool:
	frame += 1
	if frame == 6:
		root.get_texture().get_image().save_png("%s/base_t23.png" % dossier)
		print("capture base_t23")
		quit()
	return false
