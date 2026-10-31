# Lance la scène du mode convoi, joue un parcours scripté (fouille d'une ruine, véhicule trouvé,
# réparation par un mécanicien, récupération) et enregistre des captures d'écran.
#   xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 \
#     --resolution 1280x720 -s res://tests/capture_convoi.gd -- /chemin/dossier
extends SceneTree

var vue
var frame := 0
var etape := 0
var attente := 0
var dossier := "/tmp"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		dossier = args[0]
	vue = load("res://scenes/convoi.tscn").instantiate()
	root.add_child(vue)


func _photo(nom: String) -> void:
	root.get_texture().get_image().save_png("%s/%s.png" % [dossier, nom])
	print("capture ", nom)


func _clic(p: Vector2) -> void:
	var e := InputEventMouseButton.new()
	e.position = p
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	vue._gui_input(e)
	var r := InputEventMouseButton.new()
	r.position = p
	r.button_index = MOUSE_BUTTON_LEFT
	r.pressed = false
	vue._gui_input(r)


func _trouvaille():
	for v in vue.m.epaves:
		if v.statut == "trouvee":
			return v
	return null


func _process(_d: float) -> bool:
	frame += 1
	var m = vue.m
	attente += 1
	match etape:
		0:
			if frame == 3:
				vue._nouvelle_partie(11, {}, false)
				m = vue.m
				m.stocks.fuel_l = 500.0
				etape = 1
				attente = 0
		1:
			if attente == 6:
				_photo("1_depart")
				m.ordre_marche("avancer")
				vue.vitesse_sim = 3
				etape = 2
				attente = 0
		2:
			if not m.fouille_en_cours.is_empty() and attente > 5:
				etape = 3
				attente = 0
		3:
			if attente == 25:
				_photo("2_fouille")
			if m.fouille_en_cours.is_empty() and attente > 30:
				m.ordre_marche("halte")
				etape = 4
				attente = 0
		4:
			if attente > 20:
				var v = _trouvaille()
				print("trouvaille: ", v.nom if v else "aucune", " pieces: ", v.pieces.keys() if v else "")
				if v != null:
					var D: Dictionary = VehiculeDessin.donnees().vehicules[v.type]
					_clic(Vector2(vue.terrain.ecran_x(vue._rx(v)) + v.longueur * vue.ppm * 0.5, vue.SOL_Y - D.hauteur * vue.ppm * 0.5))
				etape = 5
				attente = 0
		5:
			if attente == 4:
				_photo("3_panneau")
				var cassee = null
				for ic in vue._icones:
					if ic.has("piece"):
						cassee = ic
						break
				if cassee != null:
					print("clic sur la pièce ", cassee.piece)
					_clic(cassee.rect.get_center())
				etape = 6
				attente = 0
		6:
			if attente == 40:
				_photo("4_mecanicien")
			if attente > 60:
				var v = _trouvaille()
				if v != null:
					for id in v.pieces:
						v.pieces[id].pv = v.pieces[id].max
					m.composants.clear()
					vue.ouvert = v.uid
				etape = 7
				attente = 0
		7:
			if attente == 6:
				_photo("5_rejoindre")
				for ic in vue._icones:
					if ic.has("action"):
						_clic(ic.rect.get_center())
						break
				etape = 8
				attente = 0
		8:
			if attente == 12:
				_photo("6_convoi_2")
				print(m.resume())
				for e in m.journal.slice(maxi(0, m.journal.size() - 8)):
					print("  ", e.txt)
				quit(0)
	return false
