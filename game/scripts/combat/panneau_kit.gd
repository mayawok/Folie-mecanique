# Panneau « Kit » du Mode créatif (DEC-110, DEV-010) : zone et décor, heure, météo, route calme,
# apparitions à la demande (ennemis, convois à rattraper, poursuites, bâtiments, piétons, mines, voyageur, épave).
# Ne contient aucune règle : tout passe par les fonctions kit_* du modèle (modele_kit.gd).
class_name PanneauKit
extends PanelContainer

# Heures de la journée (voir monde.gd : 0,62 = crépuscule, 0,95 = aube)
const HEURES := [["Aube", 0.02], ["Matin", 0.3], ["Après-midi", 0.55], ["Soir", 0.68], ["Nuit", 0.85]]
# Apparitions : [libellé, genre, paramètres]
const ENNEMIS := [
	["Moto", "ennemi", {"type": "moto_bmw"}], ["Voiture", "ennemi", {"type": "citroen_traction"}],
	["Camion", "ennemi", {"type": "citroen_t23"}], ["Char", "ennemi", {"type": "m4_sherman"}]]
const POURSUITES := [
	["2 motos", "poursuite", {"types": ["bmw_r75", "moto_bmw"], "abordeurs": 2}],
	["2 voitures", "poursuite", {"types": ["citroen_traction", "willys_mb"], "abordeurs": 3}],
	["Moto, voiture, camion", "poursuite", {"types": ["bmw_r75", "citroen_traction", "citroen_t23"], "abordeurs": 3}]]
const CONVOIS := [
	["Marchands", "convoi_devant", {"types": ["citroen_t23", "willys_mb"]}],
	["Convoi armé", "convoi_devant", {"types": ["citroen_t23", "m3_half_track", "citroen_traction"]}],
	["Motos", "convoi_devant", {"types": ["bmw_r75", "moto_bmw", "moto_bmw"]}]]
const VITESSES := [["Lent 3 m/s", 3.0], ["Moyen 4,5", 4.5], ["Rapide 7", 7.0]]
const BATIMENTS := [["Maison", "maison"], ["Ferme", "ferme"], ["Grange", "grange"], ["Église", "eglise"],
	["Bunker", "bunker"], ["Camp pillard", "camp_pillard"]]
const DIVERS := [
	["Pillards ×3", "pillards", {"n": 3}], ["Loups ×3", "loups", {"n": 3}], ["Champ de mines", "mines", {"n": 8}],
	["Voyageur", "voyageur", {}], ["Épave", "epave", {"type": "citroen_traction"}]]

var m                      # CombatModele
var _vitesse_convoi := 4.5
var _btn_calme: Button
var _etat: Label
var _son: Callable
var _ouvrir_berliet: Callable


static func tout_le_catalogue() -> Array:
	# Toutes les apparitions proposées (utilisé par les tests : chacune doit réussir)
	var res := []
	for liste in [ENNEMIS, POURSUITES, CONVOIS, DIVERS]:
		res.append_array(liste)
	for b in BATIMENTS:
		res.append([b[0], "batiment", {"type": b[1]}])
	return res


func _init(modele, son: Callable = Callable(), ouvrir_berliet: Callable = Callable()) -> void:
	m = modele
	_son = son
	_ouvrir_berliet = ouvrir_berliet
	var fond := StyleBoxFlat.new()
	fond.bg_color = Color(0.07, 0.08, 0.09, 1.0)
	fond.set_corner_radius_all(10)
	fond.set_content_margin_all(12)
	add_theme_stylebox_override("panel", fond)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(sc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	_titre(v, "KIT DE DÉVELOPPEMENT")
	_etat = Label.new()
	_etat.add_theme_font_size_override("font_size", 24)
	v.add_child(_etat)
	if _ouvrir_berliet.is_valid():
		_titre(v, "Camion de l'expédition")
		_bouton(v, "Berliet GDR : pièces et halte", func(): _ouvrir_berliet.call())
	_titre(v, "Zone et décor")
	_rangee(v, KIT_ZONES_LIBELLES(), func(z): m.kit_regler_zone(z); _maj())
	_titre(v, "Heure")
	_rangee(v, HEURES.map(func(h): return [h[0], h[1]]), func(h): m.kit_regler_heure(float(h)))
	_titre(v, "Météo")
	_rangee(v, [["Tempête", "on"], ["Fin", "off"]], func(k): m.kit_tempete() if k == "on" else m.kit_fin_tempete())
	_titre(v, "Rencontres automatiques")
	_btn_calme = _bouton(v, "", func(): m.kit_regler_calme(not m.kit_calme); _maj())
	_titre(v, "Ennemi devant")
	_rangee(v, ENNEMIS.map(func(e): return [e[0], e]), func(e): _lancer(e))
	_titre(v, "Convoi à rattraper (devant)")
	_rangee(v, VITESSES, func(s): _vitesse_convoi = float(s))
	_rangee(v, CONVOIS.map(func(e): return [e[0], e]), func(e): _lancer(e))
	_titre(v, "Poursuite par l'arrière")
	_rangee(v, POURSUITES.map(func(e): return [e[0], e]), func(e): _lancer(e))
	_titre(v, "Bâtiments")
	_rangee(v, BATIMENTS.map(func(b): return [b[0], ["", "batiment", {"type": b[1]}]]), func(e): _lancer(e))
	_titre(v, "Ville")
	_bouton(v, "Ville devant (enceinte, porte, mairie)", func(): m.kit_ville())
	_bouton(v, "Ville pillée devant (événement : poursuite)", func(): m.kit_ville("pillee"))
	_titre(v, "Divers")
	_rangee(v, DIVERS.map(func(e): return [e[0], e]), func(e): _lancer(e))
	_maj()
	visibility_changed.connect(_maj)


static func KIT_ZONES_LIBELLES() -> Array:
	return ["sable", "terre", "cailloux", "eau"].map(func(z): return [CombatModele.KIT_ZONES_NOMS[z], z])


func _lancer(e: Array) -> void:
	var p: Dictionary = e[2].duplicate()
	if e[1] == "convoi_devant":
		p["vitesse"] = _vitesse_convoi
	m.kit_apparaitre(e[1], p)


func _maj() -> void:
	_btn_calme.text = "Route calme : OUI (rien n'arrive seul)" if m.kit_calme else "Route calme : NON (rencontres normales)"
	_etat.text = "Zone : %s" % CombatModele.KIT_ZONES_NOMS.get(m.kit_zone, m.kit_zone)


func _titre(parent: Control, t: String) -> void:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 29)
	l.add_theme_color_override("font_color", Color("#E8A33D"))
	parent.add_child(l)


func _bouton(parent: Control, t: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(0, 56)
	b.add_theme_font_size_override("font_size", 26)
	b.pressed.connect(func():
		action.call()
		if _son.is_valid():
			_son.call())
	parent.add_child(b)
	return b


# Rangée de boutons qui passent à la ligne : éléments [libellé, valeur]
func _rangee(parent: Control, elements: Array, action: Callable) -> void:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", 6)
	f.add_theme_constant_override("v_separation", 6)
	parent.add_child(f)
	for e in elements:
		var b := _bouton(f, String(e[0]), func(): action.call(e[1]))
		b.custom_minimum_size = Vector2(120, 56)
