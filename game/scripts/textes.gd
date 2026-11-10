# Textes du jeu en français et en anglais (DEC-193). Aucun texte affiché ne doit être écrit en dur dans le code :
# on appelle Textes.t("cle", [valeurs]) ; les phrases vivent dans data/textes.json (« fr » et « en » ont les mêmes clés).
# Langue : celle de l'appareil si elle est connue (fr, en), sinon français ; Textes.langue peut être changée.
class_name Textes
extends RefCounted

static var langue := ""
static var _data := {}


static func donnees() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open("res://data/textes.json", FileAccess.READ)
		_data = JSON.parse_string(f.get_as_text())
	return _data


static func langue_active() -> String:
	if langue == "":
		langue = OS.get_locale_language()
	return langue if donnees().has(langue) else "fr"


# Texte d'une clé ; %s, %d… remplacés par args. Clé absente dans la langue : français ; absente partout : la clé elle-même.
static func t(cle: String, args: Array = []) -> String:
	var D := donnees()
	var s := ""
	if D[langue_active()].has(cle):
		s = String(D[langue_active()][cle])
	elif D.fr.has(cle):
		s = String(D.fr[cle])
	else:
		return cle
	return s % args if not args.is_empty() else s
