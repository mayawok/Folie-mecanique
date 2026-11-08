# Captures de la vitrine du Berliet GDR : pièces, modules arrière, halte de jour et de nuit.
# xvfb-run godot --path game --rendering-driver opengl3 --resolution 1280x720 -s res://tests/capture_berliet.gd -- <dossier>
extends SceneTree


func _init() -> void:
	var dos: String = OS.get_cmdline_user_args()[0]
	var vit := VitrineBerliet.new()
	root.add_child(vit)
	for i in 10: await process_frame
	var cas := [
		["1_route_court_plateau", {"chassis": "court", "module": "plateau"}, "route", false],
		["2_long_citerne", {"chassis": "long", "module": "citerne", "echappement": 4, "reservoir": 2, "pneu_av": "crampons", "pneu_ar": "agraire"}, "route", false],
		["3_benne", {"chassis": "long", "module": "benne", "pneu_ar": "chaines", "pneu_av": "chaines"}, "route", false],
		["4_grue_halte_nuit", {"chassis": "long", "module": "grue", "reservoir": 4, "echappement": 2}, "camp", true],
		["5_troupes_halte_jour", {"chassis": "long", "module": "troupes", "pneu_av": "blindee", "pneu_ar": "blindee"}, "camp", false],
		["6_ridelles_remontee", {"chassis": "court", "module": "ridelles", "echappement": 1, "reservoir": 1}, "remontee", false],
	]
	for c in cas:
		var conf := BerlietConfig.defaut()
		for k in c[1]:
			BerlietConfig.regler(conf, k, c[1][k])
		vit.config = conf
		vit.nuit = c[3]
		vit.bivouac = Bivouac.new(BerlietConfig.ancrages_m(conf))
		vit.camion.stabilisateurs = 0.0
		if c[2] != "route":
			vit.bivouac.arreter()
			for i in 1200:
				vit.bivouac.avancer(1.0 / 30.0)
				if vit.bivouac.phase == "camp":
					break
			for i in 150: vit.bivouac.avancer(1.0 / 30.0)   # le feu prend
			vit.camion.stabilisateurs = 1.0
		if c[2] == "remontee":
			vit.bivouac.repartir()
			for i in 140: vit.bivouac.avancer(1.0 / 30.0)
		vit._maj()
		for i in 8: await process_frame
		var chemin: String = dos + "/berliet_" + c[0] + ".jpg"
		root.get_viewport().get_texture().get_image().save_jpg(chemin, 0.85)
		print("capture ", chemin, " phase ", vit.bivouac.phase, " dehors ", vit.bivouac.dehors())
	vit.queue_free()
	# Convoi : nouvelle expédition avec le Berliet, puis châssis long et citerne
	var vue := ConvoiVue.new()
	root.add_child(vue)
	for i in 30: await process_frame
	vue._nouvelle_partie(7)
	for i in 40: await process_frame
	vue.m.ordre_marche("avancer")
	vue.pause = false
	for i in 90: await process_frame
	root.get_viewport().get_texture().get_image().save_jpg(dos + "/berliet_7_convoi.jpg", 0.85)
	vue.m.berliet_regler("chassis", "long")
	vue.m.berliet_regler("module", "citerne")
	vue.m.berliet_regler("echappement", 4)
	for i in 60: await process_frame
	root.get_viewport().get_texture().get_image().save_jpg(dos + "/berliet_8_convoi_long.jpg", 0.85)
	print("convoi : ", vue.m.convoi[0].nom, " ", vue.m.convoi[0].longueur)
	quit()
