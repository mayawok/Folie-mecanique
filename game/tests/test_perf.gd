# Chantier Performance (DEC-262) : disques texturés, carrosserie en maillage, réglages communs, compteur d'images.
# godot --headless --path game -s res://tests/test_perf.gd
extends SceneTree

var echecs := 0


func ok(c: bool, t: String) -> void:
	print("OK  " if c else "ÉCHEC ", t)
	if not c:
		echecs += 1


func _init() -> void:
	Textes.langue = "fr"
	# Disques : deux textures, petite et grande, bord adouci
	var tp := Disque.texture(5.0)
	var tg := Disque.texture(80.0)
	ok(tp != null and tg != null and tp != tg and tp.get_width() < tg.get_width(), "disque : texture petite et grande")
	var img := tg.get_image()
	ok(img.get_pixel(128, 128).a > 0.99 and img.get_pixel(0, 0).a < 0.01, "disque : plein au centre, transparent dans les coins")
	# Réglages : écrire le compteur garde le gore, et inversement
	Gore.regler(1)
	CompteurImages.regler(true)
	Reglages.recharger()
	Gore._charge = false
	ok(Gore.lire() == 1 and CompteurImages.actif(), "réglages : gore et compteur cohabitent dans le même fichier")
	CompteurImages.regler(false)
	Gore.regler(2)
	ok(not CompteurImages.actif() and Gore.lire() == 2, "réglages : retour aux valeurs par défaut")
	ok(CompteurImages.texte().contains("i/s"), "compteur : texte affichable")
	ok(Textes.t("compteur.1") != "compteur.1", "textes du compteur présents")
	# Carrosserie en maillage : tous les polygones d'un plan qui se suivent forment un maillage, contours compris
	var n := VehiculeDessin.new()
	n.configurer("willys_mb")
	var D: Dictionary = n.D
	var attendus := 0
	var maillages := 0
	for z in range(-1, 4):
		var dans := false
		for i in D.formes.size():
			var f: Dictionary = D.formes[i]
			if int(f.get("z", 1)) != z:
				continue
			if f.has("pts"):
				attendus += (f.pts.size() - 2) * 3 + f.pts.size() * 6
				if not dans:
					dans = true
					var m: ArrayMesh = n._maillage(z, i)
					if m.get_surface_count() > 0:
						maillages += 1
						var arr := m.surface_get_arrays(0)
						attendus -= (arr[Mesh.ARRAY_VERTEX] as PackedVector2Array).size()
			else:
				dans = false
	ok(maillages >= 1 and attendus == 0, "Willys : carrosserie en %d maillage(s), sommets attendus tous présents (écart %d)" % [maillages, attendus])
	n.fixer_faction(Color(0.8, 0.1, 0.1))
	n._maillage(1, 0)
	ok(n._maillages_teinte == n._teinte, "maillages refaits quand la couleur de faction change")
	n.free()
	print("Échecs : ", echecs)
	quit(1 if echecs > 0 else 0)
