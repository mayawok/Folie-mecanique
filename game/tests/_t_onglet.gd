extends SceneTree
var vue
var f := 0
func _initialize() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://convoi_save.json"))
	vue = load("res://scenes/convoi.tscn").instantiate()
	root.add_child(vue)
func _clic(p: Vector2, appui: bool) -> void:
	var e := InputEventMouseButton.new()
	e.position = p * (2.0 / 3.0)
	e.global_position = e.position
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = appui
	root.push_input(e)
func _process(_d: float) -> bool:
	f += 1
	if f == 5:
		vue._nouvelle_partie(3, {}, false, true)
	if f == 8:
		vue._ouvrir_editeur(0)
	if f == 12:
		var b: Button = vue._editeur._boutons_etape[1]
		print("bouton ", b.get_global_rect(), " visible ", b.visible)
		b.pressed.emit()
		print("signal -> etape ", vue._editeur.etape)
		vue._editeur._etape(1)
		var c := b.get_global_rect().get_center()
		_clic(c, true)
	if f == 13:
		_clic(vue._editeur._boutons_etape[1].get_global_rect().get_center(), false)
	if f == 15:
		print("clic -> etape ", vue._editeur.etape)
		quit()
	return false
