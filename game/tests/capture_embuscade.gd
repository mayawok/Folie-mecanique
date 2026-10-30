# Capture : église, alerte à droite, embuscade (garnison + Jeep camouflée), balles en vol.
#   xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 \
#     --resolution 1280x720 -s res://tests/capture_embuscade.gd -- /chemin/dossier
extends SceneTree

var vue
var frame := 0
var dossier := "/tmp"
var ee


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
		vue._nouvelle_partie(11)
		m = vue.m
		m._prochain_x = 1.0e9
		m.batiments.clear()
		m.epaves.clear()
		var b = m.creer_batiment("eglise", m.x_tete + 22.0)
		b.statut = "neutralise"
		b.butin_pris = true
		m.batiments.append(b)
		var b2 = m.creer_batiment("maison", m.x_tete + 52.0)
		b2.statut = "neutralise"
		b2.butin_pris = true
		m.batiments.append(b2)
		m.ordre_marche("halte")
		vue.vitesse_sim = 1
	if frame == 40:
		_photo("e1_eglise")
		ee = vue.m.creer_vehicule("m3_half_track", "ennemi", vue.m.x_tete + 125.0)
		vue.m.ennemis.append(ee)
	if frame == 70:
		_photo("e2_alerte")
		vue._embuscade()
	if frame == 250:
		_photo("e3_embuscade")
	if frame == 640:
		_photo("e4_combat")
	if frame == 700:
		_photo("e5_combat")
		quit(0)
	return false
