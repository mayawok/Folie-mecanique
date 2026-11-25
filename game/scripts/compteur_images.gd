# Compteur d'images (DEC-262) : images par seconde, temps de calcul d'une image, appels de dessin, nœuds et mémoire, en haut à
# gauche, par-dessus tout. Sert à mesurer le jeu sur l'iPhone sans Xcode. Activé dans Options (réglage mémorisé).
class_name CompteurImages
extends CanvasLayer

var _lbl: Label
var _t := 0.0


static func actif() -> bool:
	return bool(Reglages.lire("compteur", false))


static func regler(oui: bool) -> void:
	Reglages.ecrire("compteur", oui)


func _ready() -> void:
	layer = 120
	_lbl = Label.new()
	_lbl.position = Vector2(14, 6)
	_lbl.add_theme_font_size_override("font_size", 22)
	_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.6))
	_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_lbl.add_theme_constant_override("outline_size", 6)
	_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_lbl)


func _process(delta: float) -> void:
	visible = actif()
	if not visible:
		return
	_t -= delta
	if _t > 0.0:
		return
	_t = 0.5
	_lbl.text = texte()


static func texte() -> String:
	return "%d i/s · %.1f ms · %d appels · %d nœuds · %.0f Mo" % [Engine.get_frames_per_second(),
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0]
