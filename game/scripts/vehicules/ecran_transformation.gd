class_name EcranTransformation
extends Control
# Écran de transformation d'une base (DEV-016, DEC-128) : aperçu à gauche, quatre onglets et liste d'actions à droite.
# Une action impossible reste visible, grisée, avec sa raison. Chaque action s'applique à une copie de travail ;
# « Annuler la dernière » revient en arrière, « Valider » rend la grille, le métal et le temps cumulés.
# La logique est dans TransformationBase ; ici, seulement l'interface.

signal ferme(valide: bool, grille: Dictionary, metal: float, duree_s: float)

const C_FOND := Color(0.06, 0.065, 0.07)
const C_ACCENT := Color("#E8A33D")
const C_TEXTE := Color("#F2EEE6")
const C_DISCRET := Color("#A8A196")
const C_ROUGE := Color("#D9674A")

var a: Dictionary = {}
var ctx: Dictionary = {}
var onglet := "structure"
var _pile: Array = []        # états précédents de la grille, pour annuler
var _metal := 0.0
var _duree := 0.0
var _apercu: VehiculeDessin
var _zone: Control
var _liste: VBoxContainer
var _rangee: HBoxContainer
var _bilan: Label


func ouvrir(grille: Dictionary, contexte: Dictionary) -> void:
	a = grille.duplicate(true)
	ctx = contexte.duplicate(true)


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var fond := ColorRect.new()
	fond.color = C_FOND
	fond.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(fond)
	var racine := HBoxContainer.new()
	racine.set_anchors_and_offsets_preset(PRESET_FULL_RECT, PRESET_MODE_MINSIZE, 12)
	racine.add_theme_constant_override("separation", 12)
	add_child(racine)
	var gauche := VBoxContainer.new()
	gauche.size_flags_horizontal = SIZE_EXPAND_FILL
	gauche.size_flags_stretch_ratio = 1.5
	racine.add_child(gauche)
	var titre := _texte(String(BaseVehicule.fiche(BaseVehicule.id_de(a)).nom), 26, C_ACCENT)
	gauche.add_child(titre)
	var zone := Control.new()
	zone.size_flags_vertical = SIZE_EXPAND_FILL
	zone.clip_contents = true
	zone.resized.connect(_ajuster)
	_zone = zone
	gauche.add_child(zone)
	_apercu = VehiculeDessin.new()
	_apercu.ppm = 30.0
	_apercu.mouse_filter = MOUSE_FILTER_IGNORE
	zone.add_child(_apercu)
	_bilan = _texte("", 20, C_TEXTE)
	gauche.add_child(_bilan)
	var pieds := HBoxContainer.new()
	pieds.add_theme_constant_override("separation", 10)
	gauche.add_child(pieds)
	pieds.add_child(_bouton("Annuler la dernière", _annuler_derniere, 56))
	pieds.add_child(_bouton("Quitter", func(): ferme.emit(false, a, 0.0, 0.0), 56))
	pieds.add_child(_bouton("Valider", func(): ferme.emit(true, a, _metal, _duree), 56, true))
	var droite := VBoxContainer.new()
	droite.size_flags_horizontal = SIZE_EXPAND_FILL
	racine.add_child(droite)
	_rangee = HBoxContainer.new()
	_rangee.add_theme_constant_override("separation", 6)
	droite.add_child(_rangee)
	var defile := ScrollContainer.new()
	defile.size_flags_vertical = SIZE_EXPAND_FILL
	defile.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	droite.add_child(defile)
	_liste = VBoxContainer.new()
	_liste.size_flags_horizontal = SIZE_EXPAND_FILL
	_liste.add_theme_constant_override("separation", 6)
	defile.add_child(_liste)
	_maj()


func _texte(t: String, taille: int, c: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", c)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _bouton(t: String, f: Callable, h: int, accent := false) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(0, h)
	b.size_flags_horizontal = SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 20)
	if accent:
		b.add_theme_color_override("font_color", C_ACCENT)
	b.pressed.connect(f)
	return b


func _choisir(id: String) -> void:
	onglet = id
	_maj()


func _annuler_derniere() -> void:
	if _pile.is_empty():
		return
	var p: Dictionary = _pile.pop_back()
	a = p.a
	_metal = float(p.metal)
	_duree = float(p.duree)
	_maj()


func _faire(e: Dictionary) -> void:
	var r := TransformationBase.appliquer(a, e)
	if not bool(r.ok):
		return
	_pile.append({"a": a, "metal": _metal, "duree": _duree})
	a = r.a
	_metal += float(e.metal)
	_duree += float(e.duree_s)
	for p in r.get("retire", []):   # la pièce déposée rejoint la réserve, la pièce posée en sort
		ctx.reserve = ctx.get("reserve", []) + [p]
	_maj()


# Aperçu : agrandi pour remplir la zone, centré
func _ajuster() -> void:
	if _zone == null or _zone.size.x < 50.0:
		return
	_apercu.ppm = 30.0
	_apercu.configurer(FormeAssemblage.enregistrer(a))
	var k := minf(_zone.size.x * 0.92 / maxf(_apercu.size.x, 1.0), _zone.size.y * 0.8 / maxf(_apercu.size.y, 1.0))
	_apercu.ppm = 30.0 * k
	_apercu.configurer(FormeAssemblage.enregistrer(a))
	_apercu.position = (_zone.size - _apercu.size) * 0.5


func _duree_txt(s: float) -> String:
	return "%d min %02d s" % [int(s) / 60, int(s) % 60]


func _maj() -> void:
	var ctx2 := ctx.duplicate()
	ctx2.metal = float(ctx.get("metal", 0.0)) - _metal   # le métal déjà engagé n'est plus disponible
	_apercu.configurer(FormeAssemblage.enregistrer(a))
	_ajuster()
	_bilan.text = Textes.t("ecran_transformation.001", [int(_metal), _duree_txt(_duree), String(BaseVehicule.regles().niveaux_lieu[str(BaseVehicule.niveau_effectif(ctx))])])
	for ch in _rangee.get_children():
		ch.queue_free()
	for o in TransformationBase.ONGLETS:
		var b := _bouton(String(o[1]), _choisir.bind(String(o[0])), 56, String(o[0]) == onglet)
		_rangee.add_child(b)
	for ch in _liste.get_children():
		ch.queue_free()
	var toutes := TransformationBase.entrees(a, ctx2)
	for e in TransformationBase.de_onglet(toutes, onglet):
		var carte := VBoxContainer.new()
		var b := _bouton(String(e.nom), _faire.bind(e), 60, bool(e.get("actif", false)))
		b.disabled = not bool(e.ok)
		carte.add_child(b)
		if bool(e.ok):
			carte.add_child(_texte("%d métal · %s" % [int(e.metal), _duree_txt(float(e.duree_s))], 16, C_DISCRET))
		else:
			carte.add_child(_texte(String(e.raison), 16, C_ROUGE))
		_liste.add_child(carte)
