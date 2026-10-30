# Lance la scène du mode convoi, joue une partie scriptée et enregistre des captures d'écran.
#   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path game --rendering-driver opengl3 -s res://tests/capture_convoi.gd -- /chemin/dossier
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


func _pas(secondes: float) -> void:
	for i in int(secondes / CombatModele.DT):
		vue.m.avancer()


func _photo(nom: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png("%s/%s.png" % [dossier, nom])
	print("capture ", nom, " ", img.get_size())


func _process(_d: float) -> bool:
	frame += 1
	match frame:
		3:
			vue._nouvelle_partie(11)
			vue.m.stocks.fuel_l = 500.0
		8:
			_photo("1_depart")
			vue.m.ordre_marche("avancer")
			vue.m.ennemis.append(vue.m.creer_vehicule("citroen_t23", "ennemi", vue.m.x_tete + 70.0))
			vue.m.batiments.append(vue.m.creer_batiment("ferme", vue.m.x_tete + 52.0))
			vue.m.ennemis.append(vue.m.creer_vehicule("bmw_r75", "ennemi", vue.m.x_tete + 90.0))
			vue.m._prochain_x = 1.0e9
			_pas(12.0)
		40:
			_photo("2_approche")
			_pas(8.0)
		60:
			_photo("3_combat")
			vue.m.ordre_visee("roulement")
			_pas(15.0)
		90:
			_photo("4_combat_visee")
			vue.selectionner(vue.m.convoi[1].uid)
			_pas(40.0)
		130:
			_photo("5_apres")
			print(vue.m.resume())
			print("journal:")
			for e in vue.m.journal.slice(maxi(0, vue.m.journal.size() - 12)):
				print("  ", e.txt)
		140:
			quit(0)
	return false
