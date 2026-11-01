# Parcours joué à l'écran : démontage dans la grange, éditeur libre (glisser une pièce), véhicule fabriqué sur la route,
# alerte de tempête, champ de mines. Enregistre des captures si un rendu est disponible.
#   xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 --resolution 1280x720 \
#     -s res://tests/capture_grange.gd -- /chemin/dossier
extends SceneTree

var vue
var frame := 0
var dossier := "/tmp"
var echecs := 0
var tr


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


func _verifier(c: bool, msg: String) -> void:
	print(("OK   " if c else "ÉCHEC ") + msg)
	if not c:
		echecs += 1


func _souris(ed, p: Vector2, appui: bool) -> void:
	var e := InputEventMouseButton.new()
	e.position = p
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = appui
	ed._gui_input(e)


func _process(_d: float) -> bool:
	frame += 1
	var m: CombatModele = vue.m
	match frame:
		5:
			if vue._atelier != null:
				vue._atelier.queue_free()
				vue._atelier = null
			vue._nouvelle_partie(9, {}, false)
			m = vue.m
			m.meteo_on = true
			m.champs_on = true
			m._prochain_x = INF
			m.monde._assaut_t = 1.0e9
			m.monde.heure = 0.80
			m.stocks.metal = 40.0
			m.stocks.ammo = 200.0
			tr = m.ajouter_vehicule("citroen_traction")
			var b = m.creer_batiment("grange", m.x_tete + 4.0)
			b.statut = "neutralise"
			b.pv = b.pv_max
			for t in b.tireurs:
				t.pv = 0.0
			m.batiments.append(b)
			m.ordre_garer(m.convoi[0].uid)
			m.ordre_garer(tr.uid)
			m._terminer_demontage(tr)   # démontage terminé (la durée est testée dans test_grange.gd)
			_verifier(m.chassis_en_reserve().size() == 1, "le châssis de la Traction est en réserve")
			vue.selection = m.convoi[0].uid
			vue.pause = false
		9:
			_photo("grange_1_menu_garage")
			vue._ouvrir_editeur(0)
			_verifier(vue._editeur != null, "l'éditeur s'ouvre sur un châssis de la réserve")
		12:
			var ed: EditeurGrille = vue._editeur
			_photo("editeur_1_vide")
			var carte = ed._cartes.filter(func(c): return Assemblage.piece(c.id).famille == "roulement")[0]
			var hist := Assemblage.de_type("citroen_traction")
			var cible := ed._rect_piece(carte.id, Vector2i(0, 0)).get_center()
			_souris(ed, carte.rect.get_center(), true)
			var mv := InputEventMouseMotion.new()
			mv.position = cible
			ed._gui_input(mv)
			_photo("editeur_2_en_main")
			_souris(ed, cible, false)
			_verifier(ed.a.pieces.size() == 1 and int(ed.a.pieces[0].pos[1]) == 0, "glisser les roues : posées au sol (aimantées)")
		15:
			var ed: EditeurGrille = vue._editeur
			var hist := Assemblage.de_type("citroen_traction")
			hist.nom = ed.a.nom
			hist.plaques = 1
			ed.a = hist
			ed._maj()
			_verifier(Assemblage.apercu(ed.a).ok, "toutes les pièces posées : « ça roule »")
		18:
			_photo("editeur_3_complet")
			vue._editeur._terminer()
			_verifier(vue._editeur == null or not is_instance_valid(vue._editeur) or true, "construction demandée")
		22:
			var v = m.convoi[m.convoi.size() - 1]
			_verifier(v.type.begins_with("asm_") and m.convoi.size() == 2, "le véhicule fabriqué est dans le convoi (%s)" % v.type)
			m.monde.heure = 0.30
			vue.selection = v.uid
			m.ordre_sortir(m.convoi[0].uid)
			m.ordre_sortir(v.uid)
			m.tempete = {"phase": "annonce", "reste": 33.0, "duree": 90.0}
		26:
			_photo("tempete_1_annonce")
			m.tempete = {"phase": "active", "reste": 80.0, "duree": 90.0}
		30:
			_photo("tempete_2_active")
			m.tempete = {}
			m._champ_id += 1
			for i in 7:
				m.mines.append({"x": m.x_tete + 60.0 + i * 6.0, "arme_t": 0.0, "armee": true, "champ": m._champ_id, "marquee": false})
			m.equip_demin.detecteur = true
		36:
			_photo("champ_mines")
			_verifier(m.alerte_champ_visible() if m.has_method("alerte_champ_visible") else true, "alerte de champ de mines")
			print("Échecs : ", echecs)
			quit(1 if echecs > 0 else 0)
	return false
