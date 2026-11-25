# Réglages de l'appareil (user://reglages.json) : gore (DEC-257), compteur d'images (DEC-262)…
# Chaque réglage est une clé du même fichier ; écrire une clé garde les autres.
class_name Reglages
extends RefCounted

const CHEMIN := "user://reglages.json"
static var _d := {}
static var _charge := false


static func _charger() -> void:
	if _charge:
		return
	_charge = true
	_d = {}
	if FileAccess.file_exists(CHEMIN):
		var lu = JSON.parse_string(FileAccess.get_file_as_string(CHEMIN))
		if lu is Dictionary:
			_d = lu


static func lire(cle: String, defaut: Variant) -> Variant:
	_charger()
	return _d.get(cle, defaut)


static func ecrire(cle: String, valeur: Variant) -> void:
	_charger()
	_d[cle] = valeur
	var f := FileAccess.open(CHEMIN, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_d))


# Tests : oublier ce qui a été lu (le fichier a pu changer)
static func recharger() -> void:
	_charge = false
