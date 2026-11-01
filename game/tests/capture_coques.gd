# Capture : coques de donneur posées par-dessus la mécanique (DEC-067), dont une vue écorchée.
#   xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 --resolution 1280x720 \
#     -s res://tests/capture_coques.gd -- /chemin/dossier
extends SceneTree

var frame := 0
var dossier := "/tmp"


func _base(nom: String, x1: int, train: String, essieu: String) -> Dictionary:
	var a := ConstructionLibre.nouvelle(nom)
	for x in range(2, x1):
		a = ConstructionLibre.peindre(a, Vector2i(x, 2), "acier")
	a = ConstructionLibre.poser_essieu(a, 4, essieu, train)
	a = ConstructionLibre.poser_essieu(a, x1 - 3, essieu, train)
	return a


func _p(a: Dictionary, id: String, cell: Vector2i, miroir := false) -> Dictionary:
	var b := ConstructionLibre.poser(a, id, cell, miroir)
	if b.is_empty():
		print("refusé : ", id)
		return a
	return b


func _vehicules() -> Array:
	var res := []
	var a := _base("Berline", 24, "roue_moyenne", "essieu_leger")   # berline sur châssis, moteur à nu devant
	a = _p(a, "poste_conduite", Vector2i(12, 3))
	a = _p(a, "coque_berline", Vector2i(2, 2))
	a = _p(a, "moteur_willys_mb", Vector2i(19, 3))
	res.append([a, false])
	res.append([a, true])   # même véhicule, vue écorchée
	var g := _base("Gigahorse", 26, "roue_grande", "essieu_lourd")   # deux berlines empilées
	g = _p(g, "poste_conduite", Vector2i(10, 3))
	g = _p(g, "coque_berline", Vector2i(3, 2))
	g = _p(g, "coque_berline", Vector2i(3, 7))
	g = _p(g, "moteur_m4_sherman", Vector2i(20, 3))
	res.append([g, false])
	var h := _base("Rehausse", 26, "roue_grande", "essieu_lourd")   # ponts rigides sur grands tirants (DEC-070)
	h = ConstructionLibre.poser_essieu(h, 4, "pont_rigide_lourd", "roue_geante", 0)   # ponts placés 50 cm sous le châssis
	h = ConstructionLibre.poser_essieu(h, 23, "pont_rigide_lourd", "roue_geante", 0)
	h = ConstructionLibre.relier(ConstructionLibre.relier(h, 4, "liaison_tirants"), 23, "liaison_tirants")
	h = _p(h, "poste_conduite", Vector2i(10, 3))
	h = _p(h, "coque_berline", Vector2i(3, 2))
	h = _p(h, "moteur_m4_sherman", Vector2i(20, 3))
	res.append([h, false])
	var l := ConstructionLibre.relier(ConstructionLibre.relier(ConstructionLibre.poser_essieu(ConstructionLibre.poser_essieu(h, 4, "pont_rigide_lourd", "roue_grande", 2), 23, "pont_rigide_lourd", "roue_grande", 2), 4, "liaison_lames"), 23, "liaison_lames")
	res.append([l, true])
	var w := _base("Greffe", 30, "roue_grande", "essieu_lourd")   # scie (DEC-072) : cabine de camion + arrière de berline
	w = _p(w, "poste_conduite", Vector2i(22, 3))
	w = _p(w, "coque_cabine_camion", Vector2i(19, 2))
	w = _p(w, "coque_berline", Vector2i(1, 2))
	w = ConstructionLibre.scier(w, w.pieces.size() - 1, Vector2i(11, 3), "v")
	w = ConstructionLibre.retirer(w, w.pieces.size() - 1)
	res.append([w, false])
	var t := _base("Toit coupe", 24, "roue_course", "essieu_leger")
	for x in range(2, 24):
		t = ConstructionLibre.peindre(t, Vector2i(x, 2), "tube")
	t = _p(t, "poste_conduite", Vector2i(12, 3))
	t = _p(t, "coque_berline", Vector2i(2, 2))
	t = ConstructionLibre.scier(t, t.pieces.size() - 1, Vector2i(8, 5), "h")
	t = ConstructionLibre.retirer(t, t.pieces.size() - 1)
	t = _p(t, "arme_mitrailleuse", Vector2i(12, 6))
	res.append([t, false])
	var c := _base("Bricole", 30, "chenille", "essieu_char")   # cabine de camion + nez d'avion retourné
	c = _p(c, "poste_conduite", Vector2i(22, 3))
	c = _p(c, "coque_cabine_camion", Vector2i(18, 2))
	c = _p(c, "coque_nez_avion", Vector2i(4, 2), true)
	c = _p(c, "arme_mitrailleuse", Vector2i(8, 7))
	res.append([c, false])
	return res


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		dossier = args[0]
	var i := 0
	for v in _vehicules():
		var cle := "coq_%d" % i
		print(v[0].nom, " pièces=", v[0].pieces.map(func(p): return p.piece))
		VehiculeDessin.donnees().vehicules[cle] = ConstructionLibre.forme(v[0], v[1])
		var d := VehiculeDessin.new()
		d.ppm = 42.0
		d.equipage = true
		d.configurer(cle)
		d.position = Vector2(20.0 + (i % 2) * 630.0, 180.0 + (i / 2) * 175.0 - d.size.y)
		root.add_child(d)
		i += 1


func _process(_d: float) -> bool:
	frame += 1
	if frame >= 2 and frame < 5:
		for ch in root.get_children():
			if ch is VehiculeDessin:
				ch.queue_redraw()
	if frame == 5:
		root.get_texture().get_image().save_png("%s/coques.png" % dossier)
		print("capture coques")
		quit()
	return false
