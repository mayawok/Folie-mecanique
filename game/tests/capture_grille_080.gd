# Capture DEC-080 : grille en icônes, poutres et moteur traversant, radiateur, caisse de tôles fermée, peinture,
# remorque attelée sur la route, roue arrachée qui roule derrière le convoi.
#   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path game --rendering-driver opengl3 \
#     -s res://tests/capture_grille_080.gd -- /chemin/dossier
extends SceneTree

var vue
var frame := 0
var dossier := "/tmp"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		dossier = args[0]
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://convoi_save.json"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://grille_brouillon.json"))
	vue = load("res://scenes/convoi.tscn").instantiate()
	root.add_child(vue)


func _photo(nom: String) -> void:
	root.get_texture().get_image().save_png("%s/%s.png" % [dossier, nom])
	print("capture ", nom)


func camion() -> Dictionary:
	var a := ConstructionLibre.nouvelle("Camion")
	for x in range(14, 34):
		a = ConstructionLibre.peindre(a, Vector2i(x, 3), "poutre")
	a = ConstructionLibre.poser_essieu(a, 17, "essieu_lourd", "roue_geante")
	a = ConstructionLibre.poser_essieu(a, 30, "essieu_lourd", "roue_geante")
	a = ConstructionLibre.poser(a, "moteur_diamond_t", Vector2i(26, 3))
	a = ConstructionLibre.poser(a, "radiateur_camion", Vector2i(34, 4))
	a = ConstructionLibre.poser(a, "poste_conduite", Vector2i(22, 4))
	a = ConstructionLibre.poser(a, "arme_mitrailleuse", Vector2i(18, 4))
	for q in [[14, 4, 14, 8], [14, 8, 23, 9], [23, 9, 26, 4], [26, 4, 14, 4]]:
		var b := ConstructionLibre.poser_tole(a, Vector2i(q[0], q[1]), Vector2i(q[2], q[3]))
		a = b if not b.is_empty() else a
	a = ConstructionLibre.poser(a, "greffe_pare_buffle", Vector2i(35, 3))
	a.peinture = "#B0623A"
	a.nom = "Le Rouillé"
	a.nom_choisi = true
	return a


func _process(_d: float) -> bool:
	frame += 1
	var m: CombatModele = vue.m if vue != null else null
	match frame:
		8:
			vue._nouvelle_partie(11, {}, false, true)
		20:
			vue._ouvrir_editeur(0)
		24:
			var ed = vue._editeur
			ed.a = camion()
			ed._choisir_onglet("toles")
			ed._maj(true)
			print("défauts : ", ed._an.get("defauts", []).map(func(d): return d.texte))
		28:
			_photo("g080_1_toles")
			var ed = vue._editeur
			ed._choisir_onglet("moteur")
			ed._ecorche = true
			ed._placer_apercu()
		32:
			_photo("g080_2_moteurs")
			var ed = vue._editeur
			ed._choisir_onglet("peinture")
		36:
			_photo("g080_3_peinture")
			var ed = vue._editeur
			ed._terminer()
			if vue._editeur != null:
				vue._editeur._terminer()   # armes sans tireur : on confirme
			var r := ConstructionLibre.en_remorque(camion())
			r.peinture = "#B0623A"
			var rv = m.creer_depuis_assemblage(r, "joueur", 0.0, "", 0)
			m.convoi.insert(1, rv)
			m._replacer(true)
			for v in m.convoi:
				v.x_prev = v.x
			m.ordre_marche("avancer")
		60:
			var j = m.convoi[0]
			j.pieces.roulement.pv = j.pieces.roulement.max * 0.1
			m._toucher_vehicule(null, {"degats": 1.0, "penetration": 100.0, "classe": "balle"}, j, "roulement", "roulement")
		64:
			vue.terrain.camera_x = m.convoi[1].x + 4.0
		80:
			_photo("g080_4_route")
			quit()
	return false
