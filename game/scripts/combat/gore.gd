class_name Gore
extends RefCounted
# Réglage du gore (DEC-257) : 0 coupé, 1 sang, 2 maximum (sang, corps, membres arrachés). Mémorisé entre deux parties.

const CHEMIN := "user://reglages.json"
static var niveau := 2
static var _charge := false


static func lire() -> int:
	if not _charge:
		_charge = true
		if FileAccess.file_exists(CHEMIN):
			var d = JSON.parse_string(FileAccess.get_file_as_string(CHEMIN))
			if d is Dictionary:
				niveau = clampi(int(d.get("gore", 2)), 0, 2)
	return niveau


static func regler(n: int) -> void:
	niveau = clampi(n, 0, 2)
	_charge = true
	var f := FileAccess.open(CHEMIN, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"gore": niveau}))
