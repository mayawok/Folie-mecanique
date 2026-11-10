# Capture : les voitures et camions surélevés, pneus tout-terrain, pots à flamme (DEC-224).
#   xvfb-run -a -s "-screen 0 1600x900x24" godot --path game --rendering-driver opengl3 --resolution 1600x900 -s res://tests/capture_vehicules_f.gd -- /tmp
extends SceneTree

var frame := 0
var dossier := "/tmp"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		dossier = args[0]
	var fond := ColorRect.new()
	fond.color = Color("#6d6a5a")
	fond.size = Vector2(1600, 900)
	root.add_child(fond)
	var types := ["peugeot_202", "juvaquatre", "kubelwagen", "citroen_h", "opel_blitz", "gmc_cckw", "laffly_s15", "moto_zundapp"]
	var x := 10.0
	var y := 20.0
	for t in types:
		var v := VehiculeDessin.new()
		v.type = t
		v.ppm = 52.0
		v.ennemi = true
		v.vitesse = 5.0
		v.configurer(t)
		if x + v.size.x > 1590:
			x = 10.0
			y += 240.0
		v.position = Vector2(x, y)
		root.add_child(v)
		x += v.size.x + 20.0


func _process(_d: float) -> bool:
	frame += 1
	if frame == 12:
		root.get_texture().get_image().save_png("%s/vehicules_f.png" % dossier)
		quit()
	return false
