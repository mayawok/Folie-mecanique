# Capture : cabines décor (camion, voiture, blindée) posées au-dessus des postes et des bancs de troupes.
#   xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 --resolution 1280x720 \
#     -s res://tests/capture_cabines.gd -- /chemin/dossier
extends SceneTree

var frame := 0
var dossier := "/tmp"


func _construire(cab: String, haut: int) -> Dictionary:
	var a := ConstructionLibre.nouvelle(cab)
	for x in range(2, 30):
		a = ConstructionLibre.peindre(a, Vector2i(x, 2), "acier")
	a = ConstructionLibre.poser_essieu(a, 4, "essieu_leger", "roue_moyenne")
	a = ConstructionLibre.poser_essieu(a, 26, "essieu_leger", "roue_moyenne")
	a = ConstructionLibre.poser(a, "moteur_willys_mb", Vector2i(24, 3))
	a = ConstructionLibre.poser(a, "poste_conduite", Vector2i(20, 3))
	a = ConstructionLibre.poser(a, "poste_commande", Vector2i(17, 3))
	a = ConstructionLibre.poser(a, "banc_avant", Vector2i(4, 3))
	a = ConstructionLibre.poser(a, "banc_arriere", Vector2i(9, 3))
	a = ConstructionLibre.poser(a, cab, Vector2i(15, 3))
	print(cab, " pièces=", a.pieces.size())
	return a


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		dossier = args[0]
	var x := 20.0
	var i := 0
	for cab in ["cabine_camion", "cabine_voiture", "cabine_blindee", "cabine_bricolee"]:
		var a := _construire(cab, 3)
		var cle := "cap_%d" % i
		VehiculeDessin.donnees().vehicules[cle] = ConstructionLibre.forme(a)
		var d := VehiculeDessin.new()
		d.ppm = 80.0
		d.configurer(cle)
		d.position = Vector2(20.0 + (i % 2) * 620.0, 330.0 + (i / 2) * 340.0 - d.size.y)
		root.add_child(d)
		i += 1


func _process(_d: float) -> bool:
	frame += 1
	if frame >= 2 and frame < 5:   # les textures arrivent après le premier dessin : on redessine
		for ch in root.get_children():
			if ch is VehiculeDessin:
				ch.queue_redraw()
	if frame == 5:
		root.get_texture().get_image().save_png("%s/cabines.png" % dossier)
		print("capture cabines")
		quit()
	return false
