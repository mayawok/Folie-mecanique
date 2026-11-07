# Menu de pause : ouverture, reprise, retour au menu principal.
extends SceneTree

func _init() -> void:
	var echecs := 0
	var vue := ConvoiVue.new()
	root.add_child(vue)
	await process_frame
	vue._nouvelle_partie(7, {}, false, true)
	await process_frame
	vue.pause = false
	vue._basculer_pause()
	var ok1: bool = vue._calque_pause.visible and vue.pause
	print(("OK  " if ok1 else "FAIL ") + "le menu de pause s'ouvre et fige le jeu")
	vue._basculer_pause()
	var ok2: bool = not vue._calque_pause.visible and not vue.pause
	print(("OK  " if ok2 else "FAIL ") + "reprendre rétablit l'état d'avant")
	vue._basculer_pause()
	vue._fermer_menu_pause(false)
	vue.afficher_menu(true)
	var ok3: bool = vue._accueil_visible() and not vue._calque_pause.visible
	print(("OK  " if ok3 else "FAIL ") + "menu principal depuis la pause")
	echecs = int(not ok1) + int(not ok2) + int(not ok3)
	print("--- TOUT EST OK" if echecs == 0 else "--- ÉCHECS : %d" % echecs)
	quit(echecs)
