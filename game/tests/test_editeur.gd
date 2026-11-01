# Tests de l'écran de la grille (DEC-081) : pincement (zoom), outil déplacer, bouton cadrer, roues aimantées sur les essieux,
# suspension glissée sur un pont rigide, vignettes du tiroir sans chevauchement.
# Les événements tactiles sont envoyés à l'éditeur comme le fait le téléphone ; aucun rendu n'est nécessaire.
#   godot --headless --path game -s res://tests/test_editeur.gd
extends SceneTree

var echecs := 0
var ed: EditeurGrille


func ok(cond: bool, txt: String) -> void:
	print(("OK   " if cond else "ÉCHEC ") + txt)
	if not cond:
		echecs += 1


func _doigt(index: int, pos: Vector2, appui: bool) -> void:   # un doigt se pose ou se lève
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = appui
	ed._input(e)


func _doigt_glisse(index: int, pos: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = pos
	ed._input(e)


func _clic(pos: Vector2, appui: bool) -> void:   # souris émulée par le premier doigt
	var e := InputEventMouseButton.new()
	e.position = pos
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = appui
	ed._gui_input(e)


func _souris(pos: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = pos
	ed._gui_input(e)


# 16 cases d'acier à 2 cases du sol, rien d'autre
func _chassis() -> Dictionary:
	var a := ConstructionLibre.nouvelle("Essai")
	for x in range(2, 18):
		a = ConstructionLibre.peindre(a, Vector2i(x, 2), "acier")
	return a


func _charger(a: Dictionary) -> void:
	ed.a = a
	ed._cam_manuelle = false
	ed._maj(true)


func _initialize() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://grille_brouillon.json"))
	var m := CombatModele.new(3, {"bac_a_sable": true})
	ed = EditeurGrille.new()
	ed.ouvrir(m, 0)
	root.add_child(ed)
	ed.size = Vector2(1280, 590)
	ed._disposer()
	_charger(_chassis())

	print("— Fenêtre de la grille —")
	ok(ed._zone.size.x > 200.0 and ed._zone.size.y > 100.0, "la fenêtre de la grille a une taille (%s)" % str(ed._zone.size))
	ok(ed._cell0 >= 20.0 and absf(ed._cell - ed._cell0) < 0.01 and not ed._cam_manuelle, "cadrage de base : zoom 1 (%d px la case)" % int(ed._cell))
	ok(ed._case(ed._px(7.5, 3.5)) == Vector2i(7, 3), "écran -> case -> écran")

	print("— Pincement —")
	var c0 := ed._cell
	var milieu := Vector2(ed._zone.position.x + 300.0, ed._zone.position.y + 150.0)
	var monde0 := ed._mon(milieu)
	_doigt(0, milieu - Vector2(50, 0), true)
	ok(not ed._pince, "un seul doigt : pas de pincement")
	_doigt(1, milieu + Vector2(50, 0), true)
	ok(ed._pince, "deux doigts : pincement")
	_doigt_glisse(0, milieu - Vector2(100, 0))
	_doigt_glisse(1, milieu + Vector2(100, 0))
	ok(absf(ed._cell - c0 * 2.0) < 0.5 and ed._cam_manuelle, "les doigts s'écartent de moitié : zoom × 2 (%.1f → %.1f px)" % [c0, ed._cell])
	ok(ed._mon(milieu).distance_to(monde0) < 0.05, "le point pincé reste sous les doigts")
	_doigt_glisse(0, milieu - Vector2(25, 0))
	_doigt_glisse(1, milieu + Vector2(25, 0))
	ok(absf(ed._cell - c0 * 0.5) < 0.5, "les doigts se rapprochent : dézoom × 0,5 (%.1f px)" % ed._cell)
	_doigt(1, milieu + Vector2(25, 0), false)
	ok(not ed._pince, "un doigt levé : fin du pincement")
	_doigt(0, milieu - Vector2(25, 0), false)
	ed._zoomer_autour(milieu, 1000.0)
	ok(ed._cell <= ed._cell0 * EditeurGrille.ZOOM_MAX + 0.01, "zoom borné en avant")
	ed._zoomer_autour(milieu, 0.0001)
	ok(ed._cell >= ed._cell0 * EditeurGrille.ZOOM_MIN - 0.01, "zoom borné en arrière")
	ed._zoomer_autour(milieu, 2.0)
	var z := ed._cell
	ed._maj(true)
	ok(absf(ed._cell - z) < 0.01 and ed._cam_manuelle, "construire ne recadre pas une vue réglée à la main")
	ed._recadrer()
	ok(absf(ed._cell - ed._cell0) < 0.01 and not ed._cam_manuelle, "le bouton cadrer revient au cadrage de base")

	print("— Un deuxième doigt annule le geste du premier —")
	ed._choisir_onglet("essieux")
	var bas := ed._px(10.5, 1.5)
	_clic(bas, true)
	ok(ed.a.essieux.size() == 1, "un doigt sous le châssis pose un essieu")
	_doigt(0, bas, true)
	_doigt(1, bas + Vector2(80, 0), true)
	ok(ed.a.essieux.is_empty(), "le deuxième doigt défait l'essieu posé par le premier")
	_clic(bas, false)
	ok(ed.a.essieux.is_empty(), "le doigt qui se lève ne repose rien")
	_doigt(1, bas + Vector2(80, 0), false)
	_doigt(0, bas, false)
	ok(not ed._pince and ed._toques.is_empty(), "plus aucun doigt posé")

	print("— Outil déplacer (flèche à quatre têtes) —")
	ed._recadrer()
	ed._deplacer = true
	var p0 := Vector2(ed._zone.position.x + 200.0, ed._zone.position.y + 100.0)
	var ox0 := ed._ox
	var oy0 := ed._oy
	_clic(p0, true)
	_souris(p0 + Vector2(40, 25))
	_clic(p0 + Vector2(40, 25), false)
	ok(absf(ed._ox - (ox0 + 40.0)) < 0.5 and absf(ed._oy - (oy0 + 25.0)) < 0.5 and ed._cam_manuelle, "un doigt fait glisser la vue")
	ok(ed.a.cases.size() == 16 and ed.a.essieux.is_empty(), "rien n'est construit pendant le déplacement")
	ed._choisir_onglet("chassis")
	ok(not ed._deplacer, "choisir une catégorie rend la main à la construction")
	ed._recadrer()

	print("— Roues aimantées sur les essieux —")
	_charger(ConstructionLibre.poser_essieu(_chassis(), 4, "essieu_leger", ""))
	var ctr := ed._px(4.5, ed._y_axe(ed.a.essieux[0]))
	var u := ed._cell
	ok(ed._roue_cible(ctr + Vector2(2.0 * u, 1.0 * u), "roue_moyenne") == 4, "une roue à 2 cases de l'essieu s'y aimante")
	ok(ed._roue_cible(ed._px(30.5, 2.0), "roue_moyenne") == -1, "loin de tout essieu : rien")
	ed._choisir_onglet("roues")
	ed.outil.roues = "roue_moyenne"
	ed._glisse = "roue_moyenne"
	var lache := ctr + Vector2(1.5 * u, 0.5 * u) + Vector2(0, EditeurGrille.DECALAGE_DOIGT * u)   # le doigt est sous la roue visée
	_souris(lache)
	_clic(lache, false)
	ok(String(ed.a.essieux[0].train) == "roue_moyenne", "la roue lâchée près de l'essieu se monte dessus")
	ed._glisse = "roue_grande"
	ed.outil.roues = "roue_grande"
	_souris(lache)
	_clic(lache, false)
	ok(String(ed.a.essieux[0].train) == "roue_grande", "une autre roue remplace la première")
	ed.outil.roues = ""
	_clic(ctr + Vector2(0.4 * u, 0.3 * u), true)
	_clic(ctr + Vector2(0.4 * u, 0.3 * u), false)
	ok(String(ed.a.essieux[0].train) == "", "l'outil Démonter, touché près de l'essieu, retire la roue")
	ed.outil.roues = "roue_petite"
	_clic(ctr + Vector2(0.4 * u, 0.3 * u), true)
	_clic(ctr + Vector2(0.4 * u, 0.3 * u), false)
	ok(String(ed.a.essieux[0].train) == "roue_petite", "un simple toucher près de l'essieu monte la roue choisie")
	ed.outil.roues = "roue_moyenne"
	var n_ess: int = ed.a.essieux.size()
	ed._glisse = "roue_moyenne"
	var loin := ed._px(15.5, 5.0) + Vector2(0, EditeurGrille.DECALAGE_DOIGT * u)   # dans la grille, à plus de 10 cases de l'essieu
	_souris(loin)
	_clic(loin, false)
	ok(ed.a.essieux.size() == n_ess and String(ed.a.essieux[0].train) == "roue_petite", "lâchée loin de tout essieu, la roue ne se monte pas")

	print("— Suspension : une vraie pièce glissée sur un pont rigide —")
	_charger(ConstructionLibre.poser_essieu(_chassis(), 4, "pont_rigide_leger", "roue_moyenne", 0))
	u = ed._cell
	ok(ed._pont_cible(ed._px(5.5, 1.0)) == 4, "un pont rigide en l'air est visé à moins de 3 cases")
	ok(ed._pont_cible(ed._px(30.5, 1.0)) == -1, "loin du pont : rien")
	ed._choisir_onglet("suspension")
	ed._glisse = "liaison_lames"
	var lache2 := ed._px(5.0, 1.0) + Vector2(0, EditeurGrille.DECALAGE_DOIGT * u)
	_souris(lache2)
	_clic(lache2, false)
	ok(String(ed.a.essieux[0].get("liaison", "")) == "liaison_tirants", "écart de 50 cm : les lames ne conviennent pas, les tirants sont posés")
	ok(ConstructionLibre.liaison_ok(ed.a, ed.a.essieux[0]), "le pont est relié au châssis")
	_clic(ed._px(4.5, 1.0), true)   # on reprend la suspension au doigt
	ok(String(ed.a.essieux[0].get("liaison", "")) == "" and ed._glisse == "liaison_tirants" and ed._lia_prise, "toucher la suspension posée la reprend au doigt")
	var hors := Vector2(ed._tiroir.position.x + 50.0, ed._tiroir.position.y + 100.0)
	_souris(hors)
	_clic(hors, false)
	ok(String(ed.a.essieux[0].get("liaison", "")) == "" and ed._glisse == "", "lâchée hors de la grille, la suspension est retirée")
	ed._glisse = "liaison_tirants"
	_souris(lache2)
	_clic(lache2, false)
	_clic(ed._px(4.5, 1.0), true)
	_souris(ed._px(4.5, 1.0) + Vector2(10, 0))
	_clic(ed._px(4.5, 1.0) + Vector2(10, 0), false)
	ok(String(ed.a.essieux[0].get("liaison", "")) == "liaison_tirants", "reprise puis relâchée sur le même pont : elle se repose")
	var loin2 := ed._px(15.5, 6.0) + Vector2(0, EditeurGrille.DECALAGE_DOIGT * u)
	_charger(ConstructionLibre.poser_essieu(_chassis(), 4, "pont_rigide_leger", "roue_moyenne", 0))
	ed._choisir_onglet("suspension")
	ed._glisse = "liaison_lames"
	_souris(loin2)
	_clic(loin2, false)
	ok(String(ed.a.essieux[0].get("liaison", "")) == "", "lâchée loin du pont, la suspension ne se pose pas")

	print("— Tiroir : vignettes à l'échelle réduite, sans chevauchement —")
	var T := ed._tiroir
	for o in EditeurGrille.ONGLETS:
		ed._choisir_onglet(o[0])
		var items := ed._items()
		var pages := ed._pages_tiroir(items, T, T.position.y + 76.0, T.end.y - 64.0)
		var total := 0
		var chevauche := false
		var dehors := false
		for pg in pages:
			total += pg.size()
			for i in pg.size():
				var r: Rect2 = pg[i].r
				if r.position.x < T.position.x - 0.01 or r.end.x > T.end.x + 0.01 or r.position.y < T.position.y or r.end.y > T.end.y:
					dehors = true
				for j in range(i + 1, pg.size()):
					if r.intersects(pg[j].r):
						chevauche = true
		ok(total == items.size() and not chevauche and not dehors, "%s : %d vignettes sur %d page(s), sans chevauchement ni débordement" % [o[1], items.size(), pages.size()])
	ed._choisir_onglet("moteur")
	var pages_m := ed._pages_tiroir(ed._items(), T, T.position.y + 76.0, T.end.y - 64.0)
	var proportions := true
	for q in pages_m[0]:
		if not q.it.get("ligne", false):
			var r: Rect2 = q.r
			var ar: float = clampf(float(q.it.get("ar", 1.0)), 0.4, 6.0)
			if absf((r.size.x) / (r.size.y - EditeurGrille.LABEL_H) - ar) > 0.02:
				proportions = false
	ok(proportions, "chaque vignette de moteur a la proportion de sa pièce")

	ed._effacer_brouillon()
	print("TOUT EST OK" if echecs == 0 else "%d ÉCHEC(S)" % echecs)
	quit(1 if echecs > 0 else 0)
