# Capture DEC-083 : voitures sur plateforme (mode créatif), carrosserie changée, moteur à nu, pare-buffle, arme arrière ; puis sur la route.
#   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path game --rendering-driver opengl3 -s res://tests/capture_voiture.gd -- /chemin/dossier
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


func intercepteur() -> Dictionary:
	var a := ConstructionLibre.voiture("moyen")
	var o := Vector2i(int(a.plateforme.x), int(a.plateforme.y))
	for e in [["carrosserie_pickup", Vector2i(2, 1)], ["moteur_4cyl_nu", Vector2i(12, 2)], ["greffe_pare_buffle", Vector2i(18, 0)], ["arme_mitrailleuse", Vector2i(1, 3)]]:
		var r := ConstructionLibre.poser_emplacement(a, e[0], o + e[1])
		if r.is_empty():
			print("ÉCHEC pose ", e[0])
		else:
			a = r.a
	var b := ConstructionLibre.poser(a, "poste_equipier", o + Vector2i(5, 1))
	if not b.is_empty():
		a = b
	a.nom = "L'Écorcheur"
	a.nom_choisi = true
	a.peinture = "#5E6238"
	return a


func _process(_d: float) -> bool:
	frame += 1
	var m: CombatModele = vue.m if vue != null else null
	match frame:
		8:
			vue._nouvelle_partie(11, {}, false, true)
		14:
			vue.selection = m.convoi.back().uid
		20:
			vue._ouvrir_editeur(0)
		24:
			var ed = vue._editeur
			ed.a = ConstructionLibre.voiture("court")
			ed._choisir_onglet("voitures")
			ed._maj(true)
		28:
			_photo("p083_1_voitures_court")
			var ed = vue._editeur
			ed.a = intercepteur()
			ed._choisir_onglet("coque")
			ed._maj(true)
			print("classe : ", ed._an.stats.classe, " vitesse ", ed._an.stats.vitesse, " défauts ", ed._an.defauts.map(func(d): return d.texte))
		32:
			_photo("p083_2_intercepteur")
			var ed = vue._editeur
			m.bac_a_sable = false
			var avant: Dictionary = ed.a.duplicate(true)
			ed._choisir_onglet("chassis")
			ed._appuyer(Vector2i(int(ed.a.plateforme.x) + 6, int(ed.a.plateforme.y)))
			ed._relacher(ed._px(float(ed.a.plateforme.x) + 6.5, float(ed.a.plateforme.y) + 0.5))
			ed._choisir_onglet("essieux")
			ed._appuyer(Vector2i(int(ed.a.essieux[0].x), int(ed.a.plateforme.y)))
			print("OK  " if ed.a == avant else "ÉCHEC ", "hors mode créatif : châssis et essieux verrouillés")
			ed._glisse = "carrosserie_coupe"
			print("OK  " if ed._poser_ici(Vector2i(int(ed.a.plateforme.x), int(ed.a.plateforme.y))).has("refus") else "ÉCHEC ", "carrosserie d'une autre taille refusée")
			ed._glisse = ""
			ed._choisir_onglet("voitures")
			ed._maj(true)
		36:
			_photo("p083_3_verrou")
			var ed = vue._editeur
			m.bac_a_sable = true
			ed._terminer()
			if vue._editeur != null:
				vue._editeur._terminer()
			var v = m.convoi.back()
			v.x_prev = v.x
			m.ordre_marche("avancer")
		90:
			vue.selection = m.convoi.back().uid
			vue.terrain.camera_x = m.convoi.back().x + 5.0
		110:
			_photo("p083_4_route")
			quit()
	return false
