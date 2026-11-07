extends SceneTree
func _init() -> void:
	var vue := ConvoiVue.new()
	root.add_child(vue)
	for i in 30: await process_frame
	vue._nouvelle_partie(7, {}, false, true)
	for i in 30: await process_frame
	vue._basculer_pause()
	for i in 20: await process_frame
	root.get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	quit()
