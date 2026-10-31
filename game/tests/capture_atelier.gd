# Début de partie guidé (DEC-035) joué par l'écran : atelier de la moto, route, grange, atelier du side-car.
# Glisse chaque pièce comme le ferait un doigt et enregistre des captures (si un rendu est disponible).
#   xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 \
#     --resolution 1280x720 -s res://tests/capture_atelier.gd -- /chemin/dossier
# Sans écran (vérifie seulement l'absence d'erreur) : godot --headless --path game -s res://tests/capture_atelier.gd
extends SceneTree

var vue
var frame := 0
var etape := 0
var dossier := "/tmp"
var echecs := 0
var t0 := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		dossier = args[0]
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://convoi_save.json"))
	vue = load("res://scenes/convoi.tscn").instantiate()
	root.add_child(vue)


func _photo(nom: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	root.get_texture().get_image().save_png("%s/%s.png" % [dossier, nom])
	print("capture ", nom)


func _souris(p: Vector2, appui: bool) -> void:
	var e := InputEventMouseButton.new()
	e.position = p
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = appui
	vue._atelier._gui_input(e)


func _glisser(at: AtelierGrille, it: Dictionary) -> void:
	_souris(it.carte.get_center(), true)
	var mv := InputEventMouseMotion.new()
	mv.position = at._slot_ecran(it).get_center()
	at._gui_input(mv)
	_souris(at._slot_ecran(it).get_center(), false)


func _verifier(c: bool, msg: String) -> void:
	print(("OK   " if c else "ÉCHEC ") + msg)
	if not c:
		echecs += 1


func _process(_d: float) -> bool:
	frame += 1
	var m: CombatModele = vue.m
	match etape:
		0:
			var at: AtelierGrille = vue._atelier
			if frame == 10:
				_verifier(at != null, "nouvelle partie : l'atelier de la moto s'ouvre")
				_photo("atelier_1_vide")
				var roue = at.items.filter(func(i): return i.fiche.famille == "roulement")[0]
				_glisser(at, roue)
				_verifier(roue.etat == "bac", "une roue ne se pose pas avant le cadre")
				_glisser(at, at.items[0])
				_glisser(at, roue)
			if frame == 16:
				_photo("atelier_2_cadre_roue")
				for it in at.items:
					if it.etat == "bac":
						_glisser(at, it)
				_verifier(at._complet(), "toutes les pièces de la moto sont posées")
			if frame == 22:
				_photo("atelier_3_moto_complete")
				at._terminer()
				etape = 1
		1:
			if frame == 30:
				_verifier(vue._atelier == null and m.convoi.size() == 1 and m.convoi[0].type == "moto_bmw", "la moto est sur la route")
				m.ordre_marche("avancer")
				vue.vitesse_sim = 3
			if frame == 60:
				_photo("route_4_moto")
			if frame > 30 and m.fouille_demandee == 0:
				for b in m.batiments:
					if not b.butin_pris and b.statut == "neutralise" and b.x - m.x_tete < 40.0:
						m.ordre_fouiller(b.uid)   # comme le bouton « Fouiller » au-dessus de la ruine
			if frame > 30 and vue._btn_atelier.visible:
				_photo("route_5_grange")
				vue._ouvrir_atelier()
				_verifier(vue._atelier != null and vue._atelier.plan.nom.contains("side-car"), "après la grange : l'atelier du side-car")
				t0 = frame
				etape = 2
			if frame > 4000:
				_verifier(false, "la grange n'a pas été fouillée à temps")
				etape = 9
		2:
			var at: AtelierGrille = vue._atelier
			if frame == t0 + 6:
				_photo("atelier_6_side_car")
				for it in at.items:
					if it.etat == "bac":
						_glisser(at, it)
			if frame == t0 + 12:
				_photo("atelier_7_side_car_complet")
				at._terminer()
			if frame == t0 + 40:
				_verifier(m.convoi[0].type == "side_bmw" and m.convoi[0].equipage.size() == 2, "side-car et passager sur la route")
				m.ordre_marche("avancer")
			if frame == t0 + 120:
				_photo("route_8_side_car")
				etape = 9
		9:
			print("Échecs : %d" % echecs)
			quit(1 if echecs > 0 else 0)
	return false
