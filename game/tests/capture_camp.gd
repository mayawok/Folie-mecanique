# Capture : interface pendant un camp de réparation (DEV-018). Argument : chemin du jpg.
extends SceneTree
func _init() -> void:
	var vue := ConvoiVue.new()
	root.add_child(vue)
	for i in 30: await process_frame
	vue._nouvelle_partie(7, {}, false, true)
	for i in 30: await process_frame
	var m = vue.m
	m._prochain_x = INF
	var v = m.convoi[0]
	v.pieces.roulement.pv = 0.0
	m.pieces_stock.append({"piece": "essieu_lourd", "etat": 0.9})
	m.pieces_stock.append({"piece": "roue_grande", "etat": 0.8})
	vue.selection = v.uid
	for i in 15: await process_frame
	var o: Dictionary = vue._option_camp(v)
	print("option camp : ", o.get("op", ""), " ok=", o.get("ok", false))
	vue._action_camp()
	for i in 200: m.avancer()
	for i in 20: await process_frame
	print("camp actif : ", m.camp_actif(), " texte : ", vue._texte_camp() if m.camp_actif() else "")
	root.get_viewport().get_texture().get_image().save_jpg(OS.get_cmdline_user_args()[0], 0.85)
	quit()
