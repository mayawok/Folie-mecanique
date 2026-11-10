# Bulles d'aide discrètes (DEC-194) : chaque fonction est expliquée une seule fois, à sa première utilisation.
# Les fonctions déjà vues sont gardées dans user://aide.json (le joueur peut les revoir en les effaçant, ou via « Réinitialiser »).
class_name Aide
extends RefCounted

static var chemin := "user://aide.json"
static var _vus := {}
static var _charge := false


static func _charger() -> void:
	if _charge:
		return
	_charge = true
	if FileAccess.file_exists(chemin):
		var f := FileAccess.open(chemin, FileAccess.READ)
		var d = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			_vus = d


# Texte de la bulle à montrer maintenant ; vide si la fonction a déjà été expliquée. Marque la fonction comme vue.
static func prendre(cle: String) -> String:
	_charger()
	if _vus.has(cle):
		return ""
	_vus[cle] = true
	var f := FileAccess.open(chemin, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_vus))
	return Textes.t("aide." + cle)


static func vu(cle: String) -> bool:
	_charger()
	return _vus.has(cle)


static func reinitialiser() -> void:
	_vus = {}
	_charge = true
	var f := FileAccess.open(chemin, FileAccess.WRITE)
	if f != null:
		f.store_string("{}")
