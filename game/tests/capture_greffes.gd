# Capture : greffes posées sur une Jeep et une berline (DEC-079).
#   xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 --resolution 1280x720 \
#     -s res://tests/capture_greffes.gd -- /chemin/dossier
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
	var j := _base("Jeep a greffes", 24, "roue_moyenne", "essieu_leger")
	j = _p(j, "poste_conduite", Vector2i(10, 3))
	j = _p(j, "moteur_willys_mb", Vector2i(19, 3))
	j = _p(j, "greffe_pare_buffle", Vector2i(24, 2))
	j = _p(j, "greffe_bidons", Vector2i(2, 3))
	j = _p(j, "greffe_drapeau", Vector2i(4, 3))
	res.append([j, false])
	var k := _base("Piques", 24, "roue_moyenne", "essieu_leger")
	k = _p(k, "poste_conduite", Vector2i(10, 3))
	k = _p(k, "moteur_willys_mb", Vector2i(19, 3))
	k = _p(k, "coque_berline", Vector2i(2, 2))
	k = _p(k, "greffe_piques", Vector2i(6, 8))
	k = _p(k, "greffe_pare_buffle", Vector2i(24, 2))
	res.append([k, false])
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
		d.ppm = 120.0
		d.equipage = true
		d.configurer(cle)
		d.position = Vector2(20.0 + (i % 2) * 640.0, 300.0 - d.size.y)
		root.add_child(d)
		i += 1


func _process(_d: float) -> bool:
	frame += 1
	if frame >= 2 and frame < 5:
		for ch in root.get_children():
			if ch is VehiculeDessin:
				ch.queue_redraw()
	if frame == 5:
		root.get_texture().get_image().save_png("%s/greffes.png" % dossier)
		print("capture greffes")
		quit()
	return false
