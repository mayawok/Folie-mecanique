# Marges sûres de l'écran (iPhone en paysage : encoche ou Dynamic Island, barre d'accueil, coins arrondis).
# Lit les marges du navigateur (env(safe-area-inset-*), fonction fmZonesSures du gabarit web) et garde en plus
# une marge de confort pour les pouces : les boutons ne collent jamais au bord (DEC-056).
class_name ZonesSures
extends RefCounted

const CONFORT_X := 0.045   # part de la largeur, de chaque côté, même sans encoche
const CONFORT_BAS := 0.03

static var _css := []       # [gauche, haut, droite, bas, largeur CSS] lus une fois


static func _lire() -> void:
	if OS.has_feature("web"):
		if not _css.is_empty():
			return
		var r = JavaScriptBridge.eval("window.fmZonesSures ? window.fmZonesSures() : ''", true)
		if typeof(r) == TYPE_STRING and String(r).count(",") == 4:
			for t in String(r).split(","):
				_css.append(float(t))
	elif OS.has_feature("mobile"):
		# Appli native (iOS, plus tard Android) : le système donne la zone sûre en pixels d'écran. Relue à chaque appel,
		# car elle change quand on retourne le téléphone (l'île passe de gauche à droite).
		_css = ZonesSures.depuis_zone_systeme(DisplayServer.get_display_safe_area(), DisplayServer.window_get_size())


# Zone sûre du système (pixels d'écran) → [gauche, haut, droite, bas, largeur], au même format que le navigateur.
# Séparée pour être testée sans téléphone.
static func depuis_zone_systeme(sure: Rect2i, ecran: Vector2i) -> Array:
	if ecran.x <= 0 or ecran.y <= 0 or sure.size.x <= 0 or sure.size.y <= 0:
		return []
	return [float(sure.position.x), float(sure.position.y), float(ecran.x - sure.end.x), float(ecran.y - sure.end.y),
		float(ecran.x)]


# Marges en unités de l'interface pour une zone de taille `taille` : {g, h, d, b}.
# Symétriques à gauche et à droite : l'île peut passer d'un côté à l'autre quand on retourne le téléphone.
static func marges(taille: Vector2) -> Dictionary:
	_lire()
	var k := 1.0
	var cote := 0.0
	var bas := 0.0
	var haut := 0.0
	if _css.size() == 5 and _css[4] > 0.0:
		k = taille.x / _css[4]
		cote = maxf(_css[0], _css[2]) * k
		haut = _css[1] * k
		bas = _css[3] * k
	# gc / dc : marges des éléments dans un coin (haut ou bas) : l'encoche et l'île sont au milieu du bord, ces éléments n'ont
	# à éviter que l'arrondi de l'écran. g / d : marges des éléments à hauteur du milieu de l'écran.
	return {"g": maxf(cote, taille.x * CONFORT_X), "d": maxf(cote, taille.x * CONFORT_X),
		"gc": taille.x * CONFORT_X, "dc": taille.x * CONFORT_X,
		"h": maxf(haut, 8.0), "b": maxf(bas, taille.y * CONFORT_BAS)}
