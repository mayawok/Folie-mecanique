# Planche de véhicules assemblés (G4) : compare le dessin d'origine et le dessin fabriqué depuis les pièces.
#   xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 --resolution 1280x720 \
#     -s res://tests/capture_assemblages.gd -- /chemin/dossier [pixels par mètre] [types...]
extends SceneTree

var frame := 0
var dossier := "/tmp"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		dossier = args[0]
	var fond := ColorRect.new()
	fond.color = Color("#C9B48A")
	fond.size = Vector2(1280, 720)
	root.add_child(fond)
	var sol := ColorRect.new()
	sol.color = Color("#8C7A55")
	sol.position = Vector2(0, 330)
	sol.size = Vector2(1280, 390)
	root.add_child(sol)
	var cas := []
	var liste := ["willys_mb", "citroen_traction", "citroen_t23", "m3_stuart", "m4_sherman", "tiger_1"]
	var ppm := 30.0
	if args.size() > 1:
		ppm = float(args[1])
	if args.size() > 2:
		liste = Array(args.slice(2))
	var x := 20.0
	var y := 320.0
	for k in 2:   # rangée du haut : dessin historique ; rangée du bas : dessin fabriqué depuis les pièces
		x = 20.0
		for t in liste:
			var a := Assemblage.de_type(t)
			a.plaques = 0 if k == 0 else 1
			var cle: String = t if k == 0 else FormeAssemblage.enregistrer(a)
			var d := VehiculeDessin.new()
			d.ppm = ppm
			d.configurer(cle)
			d.position = Vector2(x, y - d.size.y)
			root.add_child(d)
			x += d.size.x + 24.0
		y += 300.0


func _process(_d: float) -> bool:
	frame += 1
	if frame == 5:
		root.get_texture().get_image().save_png("%s/assemblages.png" % dossier)
		print("capture assemblages")
		quit()
	return false
