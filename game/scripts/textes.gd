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
		# Sans écran (tests, CI) : français, pour que les vérifications de texte restent stables
		langue = "fr" if DisplayServer.get_name() == "headless" else OS.get_locale_language()
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


# --- Données (DEC-263) : noms, répliques et descriptions des fichiers data/*.json --------------------------------------
# Les fichiers de données restent écrits en français. Au chargement, en anglais, les champs affichés (nom, titre, texte,
# répliques…) sont remplacés par leur traduction (bloc « donnees_en » de textes.json, clé = texte français exact ; préfixes
# pour les noms de pièces en série). Les identifiants et les autres champs ne sont jamais touchés.
const CHAMPS_TRADUITS := ["nom", "titre", "texte", "annonce", "message", "cargaison", "presence", "escorte_texte", "pillards",
	"incertitude", "alerte_poursuite", "alerte_approche", "cris", "chargement", "rassemblement", "bonne_chance", "phrases",
	"repliques", "recit", "accueil", "fiche", "verdicts", "theme", "txt"]


static func donnee(s: String) -> String:
	if langue_active() == "fr":
		return s
	var T: Dictionary = donnees().get("donnees_%s" % langue_active(), {})
	var tab: Dictionary = T.get("textes", {})
	if tab.has(s):
		return String(tab[s])
	var pre: Dictionary = T.get("prefixes", {})
	for p in pre:
		if s.begins_with(p) and s.length() > String(p).length():
			return String(pre[p]) % s.substr(String(p).length())
	return s


# Traduit sur place les champs affichés d'une donnée chargée (dictionnaire ou tableau, à toute profondeur) ; la rend.
static func traduire(o: Variant, cle := "") -> Variant:
	if langue_active() == "fr":
		return o
	if o is Dictionary:
		for k in o.keys():
			var v = o[k]
			if v is String:
				if String(k) in CHAMPS_TRADUITS:
					o[k] = donnee(v)
			else:
				traduire(v, String(k))
	elif o is Array:
		for i in o.size():
			if o[i] is String:
				if cle in CHAMPS_TRADUITS:
					o[i] = donnee(o[i])
			else:
				traduire(o[i], cle)
	return o
