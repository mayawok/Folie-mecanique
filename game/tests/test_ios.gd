# Préparation de l'appli iPhone native (DEC-260) : préréglage d'export iOS, icône, réglages du projet, zones sûres natives.
# godot --headless --path game -s res://tests/test_ios.gd
extends SceneTree

var echecs := 0


func ok(c: bool, t: String) -> void:
	print("OK  " if c else "ÉCHEC ", t)
	if not c:
		echecs += 1


func _init() -> void:
	# --- Préréglage d'export iOS ---
	var cfg := ConfigFile.new()
	ok(cfg.load("res://export_presets.cfg") == OK, "export_presets.cfg se lit")
	var ios := ""
	for s in cfg.get_sections():
		if cfg.get_value(s, "platform", "") == "iOS":
			ios = s
	ok(ios != "", "un préréglage iOS existe")
	var o := ios + ".options"
	var ident := String(cfg.get_value(o, "application/bundle_identifier", ""))
	ok(ident.count(".") >= 2 and not ident.contains(" ") and not ident.begins_with("com.example"), "identifiant d'appli valide (%s)" % ident)
	ok(int(cfg.get_value(o, "application/targeted_device_family", -1)) == 0, "iPhone seulement")
	ok(bool(cfg.get_value(o, "application/export_project_only", false)), "export du projet Xcode seulement (signature faite dans Xcode)")
	ok(String(cfg.get_value(ios, "include_filter", "")).contains("data/*.json"), "les données JSON sont emportées")
	ok(String(cfg.get_value(ios, "exclude_filter", "")).contains("tests/"), "les tests restent hors de l'appli")
	# --- Icône App Store : 1024 × 1024, opaque (Apple refuse la transparence) ---
	var chemin := String(cfg.get_value(o, "icons/app_store_1024x1024", ""))
	var img := Image.load_from_file(chemin) if chemin != "" else null
	ok(img != null and img.get_size() == Vector2i(1024, 1024), "icône App Store en 1024 × 1024")
	ok(img != null and img.detect_alpha() == Image.ALPHA_NONE, "icône App Store opaque")
	# --- Réglages du projet ---
	ok(int(ProjectSettings.get_setting("display/window/handheld/orientation", 0)) == 4, "paysage dans les deux sens (capteur)")
	ok(not bool(ProjectSettings.get_setting("display/window/ios/allow_high_refresh_rate", true)), "60 images/s sur iPhone (batterie)")
	ok(bool(ProjectSettings.get_setting("display/window/ios/suppress_ui_gesture", false)), "geste d'accueil protégé pendant le jeu")
	ok(int(ProjectSettings.get_setting("audio/general/ios/session_category", 0)) == 3, "son même en mode silencieux, comme sur le web")
	# --- Zones sûres natives : iPhone 14 Pro Max en paysage, île à gauche ---
	var z := ZonesSures.depuis_zone_systeme(Rect2i(177, 0, 2796 - 177 * 2, 1290 - 63), Vector2i(2796, 1290))
	ok(z.size() == 5 and is_equal_approx(z[0], 177.0) and is_equal_approx(z[2], 177.0) and is_equal_approx(z[3], 63.0) \
		and is_equal_approx(z[4], 2796.0), "zone sûre native convertie en marges [g, h, d, b, largeur]")
	ok(ZonesSures.depuis_zone_systeme(Rect2i(), Vector2i(2796, 1290)).is_empty(), "zone sûre vide : on garde la marge de confort")
	print("Échecs : ", echecs)
	quit(1 if echecs > 0 else 0)
