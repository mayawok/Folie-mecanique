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
var _ouvrir_carte: Callable
var _vals: Array = []          # étiquettes de valeur des réglages en direct
var _lbl_region: Label
var _groupe := {"type": "moto_bmw", "n": 3, "mode": "approche"}
var _lbl_groupe: Label


static func tout_le_catalogue() -> Array:
	# Toutes les apparitions proposées (utilisé par les tests : chacune doit réussir)
	var res := []
	for liste in [ENNEMIS, POURSUITES, CONVOIS, DIVERS]:
		res.append_array(liste)
	for b in BATIMENTS:
		res.append([b[0], "batiment", {"type": b[1]}])
	return res


func _init(modele, son: Callable = Callable(), ouvrir_berliet: Callable = Callable(), ouvrir_carte: Callable = Callable()) -> void:
	m = modele
	_son = son
	_ouvrir_berliet = ouvrir_berliet
	_ouvrir_carte = ouvrir_carte
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
	if _ouvrir_carte.is_valid():
		_titre(v, "Monde")
		_bouton(v, "Carte du monde : villes, routes, ressources", func(): _ouvrir_carte.call())
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
	_titre(v, "Réputation (faction de la ville actuelle)")
	_rangee(v, [["−20", -20], ["−5", -5], ["+5", 5], ["+20", 20]], func(d): m.rep_changer(m.rep_faction_ici(), float(d), "Kit"))
	_titre(v, "Ville")
	_bouton(v, "Ville devant (enceinte, porte, mairie)", func(): m.kit_ville())
	_bouton(v, "Ville pillée devant (événement : poursuite)", func(): m.kit_ville("pillee"))
	_bouton(v, "Repaire du Baron devant (boss des Raffineurs)", func(): m.kit_ville("repaire"))
	_titre(v, "Groupe sur mesure")
	_rangee(v, CombatModele.KIT_VEHICULES.keys().map(func(k): return [CombatModele.KIT_VEHICULES[k], k]), func(k): _groupe.type = k; _maj())
	_rangee(v, [["−", -1], ["+", 1]], func(d): _groupe.n = clampi(int(_groupe.n) + int(d), 1, 8); _maj())
	_rangee(v, [["À l'approche", "approche"], ["Convoi devant", "convoi"], ["En face", "face"], ["Poursuite", "poursuite"]], func(k): _groupe.mode = k; _maj())
	_lbl_groupe = Label.new()
	_lbl_groupe.add_theme_font_size_override("font_size", 24)
	v.add_child(_lbl_groupe)
	_bouton(v, "Lancer le groupe", func(): _lancer_groupe())
	_titre(v, "Région de la quête (difficulté forcée)")
	_lbl_region = Label.new()
	_lbl_region.add_theme_font_size_override("font_size", 24)
	v.add_child(_lbl_region)
	var regs := [["Aucune", ""]]
	for R in CarteMonde.regions():
		regs.append([String(R.nom), String(R.id)])
	_rangee(v, regs, func(id): m.kit_regler_region_quete(String(id)); _maj())
	_titre(v, "Équilibrage en direct")
	for i in CombatModele.KIT_REGLAGES.size():
		_reglage(v, i)
	_bouton(v, "Copier les réglages (à me coller dans le chat)", func():
		DisplayServer.clipboard_set(m.kit_reglages_texte())
		_etat.text = m.kit_reglages_texte())
	_bouton(v, "Réinitialiser les réglages", func(): m.kit_reglages_reinitialiser(); _maj())
	_titre(v, "Divers")
	_rangee(v, DIVERS.map(func(e): return [e[0], e]), func(e): _lancer(e))
	_maj()
	visibility_changed.connect(_maj)


static func KIT_ZONES_LIBELLES() -> Array:
	return ["sable", "terre", "cailloux", "eau"].map(func(z): return [CombatModele.KIT_ZONES_NOMS[z], z])


func _lancer_groupe() -> void:
	var p: Dictionary = _groupe.duplicate()
	p["vitesse"] = _vitesse_convoi
	m.kit_apparaitre("groupe", p)


func _lancer(e: Array) -> void:
	var p: Dictionary = e[2].duplicate()
	if e[1] == "convoi_devant":
		p["vitesse"] = _vitesse_convoi
	m.kit_apparaitre(e[1], p)


func _maj() -> void:
	_btn_calme.text = "Route calme : OUI (rien n'arrive seul)" if m.kit_calme else "Route calme : NON (rencontres normales)"
	_etat.text = "Zone : %s" % CombatModele.KIT_ZONES_NOMS.get(m.kit_zone, m.kit_zone)
	for i in _vals.size():
		var val: float = m.kit_reglage_valeur(i)
		_vals[i].text = ("%d" if val >= 10.0 or CombatModele.KIT_REGLAGES[i].pas >= 1.0 else "%.2f") % val
	_lbl_groupe.text = "%d × %s · %s" % [int(_groupe.n), CombatModele.KIT_VEHICULES[_groupe.type], {"approche": "à l'approche", "convoi": "convoi devant", "face": "en face", "poursuite": "poursuite"}[_groupe.mode]]
	var rq: Dictionary = CarteMonde.region(m.kit_region_quete)
	var rc: Dictionary = CarteMonde.region(m.kit_region_courante())
	_lbl_region.text = "Quête : %s · Convoi : %s%s" % [rq.get("nom", "aucune"), rc.get("nom", "?"),
		(" · HORS RÉGION (+%d niveaux)" % m.malus_hors_region()) if m.malus_hors_region() > 0 else ""]


# Réglage en direct : libellé, bouton −, valeur, bouton +
func _reglage(parent: Control, i: int) -> void:
	var R: Dictionary = CombatModele.KIT_REGLAGES[i]
	var l := Label.new()
	l.text = String(R.nom)
	l.add_theme_font_size_override("font_size", 24)
	parent.add_child(l)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	parent.add_child(h)
	var moins := _bouton(h, "−", func(): m.kit_reglage_pas(i, -1); _maj())
	moins.custom_minimum_size = Vector2(90, 56)
	var val := Label.new()
	val.custom_minimum_size = Vector2(120, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val.add_theme_font_size_override("font_size", 28)
	h.add_child(val)
	_vals.append(val)
	var plus := _bouton(h, "+", func(): m.kit_reglage_pas(i, 1); _maj())
	plus.custom_minimum_size = Vector2(90, 56)


func _titre(parent: Control, t: String) -> void:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 29)
	l.add_theme_color_override("font_color", Color("#E8A33D"))
	parent.add_child(l)


func _bouton(parent: Control, t: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # un long libellé passe à la ligne : le panneau ne déborde plus de l'écran
	b.clip_text = true
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
