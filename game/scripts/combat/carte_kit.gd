# Carte du monde du Kit de développement (DEC-154) : toute la carte de conception d'un coup d'œil (villes-étapes, routes,
# ressources, sites, factions, dangers). Toucher un lieu l'ouvre ; « Y aller » y conduit le convoi (CombatModele.kit_aller).
# Aucune règle ici : données et calculs dans CarteMonde (carte_monde.gd), voyage dans le modèle.
# Dans le jeu final, la carte se découvrira peu à peu ; ici tout est affiché, c'est l'outil de conception.
class_name CarteKit
extends Control

signal ferme

const PANNEAU_L := 470.0
const RESSOURCES := ["petrole", "raffinerie", "gaz", "mine", "eau", "depot", "epaves"]
const COUCHES := [["regions", "Régions"], ["villes", "Villes"], ["routes", "Routes"], ["ressources", "Ressources"], ["sites", "Sites"],
	["factions", "Factions"], ["dangers", "Dangers"], ["legende", "Légende"]]

var modele = null          # CombatModele (Mode créatif) ; sans modèle, la carte se consulte sans voyage
var sel := ""              # lieu choisi
var couches := {"regions": true, "villes": true, "routes": true, "ressources": true, "sites": true, "factions": true, "dangers": false, "legende": true}
var zoom := 1.0
var decalage := Vector2.ZERO
var itineraire: Array = []
var _tex: Texture2D
var _infos: Label
var _btn_aller: Button
var _btn_iti: Button
var _appui := Vector2.INF  # point d'appui du doigt (pour distinguer toucher et glisser)
var _glisse := false
var _doigts := {}          # index -> position (pincement à deux doigts)
var _t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	var chemin := String(CarteMonde.donnees().get("image", ""))
	if ResourceLoader.exists(chemin):
		_tex = load(chemin)
	_construire_panneau()
	_maj()


func _process(d: float) -> void:
	_t += d
	queue_redraw()   # repère « vous êtes ici » animé


# --- Géométrie -------------------------------------------------------------------------------
func _zone_carte() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(maxf(100.0, size.x - PANNEAU_L), size.y))


func _rect_image() -> Rect2:
	var z := _zone_carte()
	var t := Vector2(1536, 1024) if _tex == null else _tex.get_size()
	var k: float = minf(z.size.x / t.x, z.size.y / t.y) * zoom
	var sz := t * k
	return Rect2(z.position + (z.size - sz) * 0.5 + decalage, sz)


func _ecran(p: Vector2) -> Vector2:
	var r := _rect_image()
	return r.position + p * r.size


func _carte(e: Vector2) -> Vector2:
	var r := _rect_image()
	return (e - r.position) / r.size


func _borner() -> void:
	zoom = clampf(zoom, 1.0, 4.0)
	var z := _zone_carte()
	var t := Vector2(1536, 1024) if _tex == null else _tex.get_size()
	var sz := t * minf(z.size.x / t.x, z.size.y / t.y) * zoom
	var jeu := ((sz - z.size) * 0.5).max(Vector2.ZERO)
	decalage = decalage.clamp(-jeu, jeu)


func zoomer(f: float, centre := Vector2.INF) -> void:
	if centre == Vector2.INF:
		centre = _zone_carte().get_center()
	var avant := _carte(centre)
	zoom *= f
	_borner()
	decalage += centre - _ecran(avant)
	_borner()


# --- Toucher -----------------------------------------------------------------------------------
func _gui_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		if e.pressed:
			_doigts[e.index] = e.position
		else:
			_doigts.erase(e.index)
	elif e is InputEventScreenDrag and _doigts.size() >= 2:
		var avant: Vector2 = _doigts[e.index]
		var autre: Vector2 = Vector2.ZERO
		for k in _doigts:
			if k != e.index:
				autre = _doigts[k]
		_doigts[e.index] = e.position
		var d0 := avant.distance_to(autre)
		if d0 > 10.0:
			zoomer(e.position.distance_to(autre) / d0, (e.position + autre) * 0.5)
		_glisse = true
		return
	elif e is InputEventMagnifyGesture:
		zoomer(e.factor, e.position)
	elif e is InputEventMouseButton:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP and e.pressed:
			zoomer(1.15, e.position)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN and e.pressed:
			zoomer(1.0 / 1.15, e.position)
		elif e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				_appui = e.position
				_glisse = false
			else:
				if not _glisse and _zone_carte().has_point(e.position):
					choisir(CarteMonde.lieu_proche(_carte(e.position), 0.035 / zoom))
				_appui = Vector2.INF
	elif e is InputEventMouseMotion and _appui != Vector2.INF and _doigts.size() < 2:
		if _glisse or e.position.distance_to(_appui) > 14.0:
			_glisse = true
			decalage += e.relative
			_borner()


func choisir(id: String) -> void:
	sel = id
	itineraire = []
	_maj()


func calculer_itineraire() -> void:
	itineraire = []
	if modele == null or sel == "":
		return
	var depart := String(modele.kit_lieu)
	var arrivee := sel
	if String(CarteMonde.lieu(arrivee).get("type", "")) != "ville":
		arrivee = _ville_proche(sel)
	if String(CarteMonde.lieu(depart).get("type", "")) != "ville":
		depart = _ville_proche(depart)
	itineraire = CarteMonde.chemin(depart, arrivee)
	_maj()


func _ville_proche(id: String) -> String:
	var p := CarteMonde.pos(id)
	var meilleur := ""
	var d_min := INF
	for v in CarteMonde.villes():
		var d := CarteMonde.pos(String(v.id)).distance_to(p)
		if d < d_min:
			d_min = d
			meilleur = String(v.id)
	return meilleur


# --- Panneau -----------------------------------------------------------------------------------
func _construire_panneau() -> void:
	var fond := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.08, 0.09, 0.96)
	sb.set_content_margin_all(12)
	fond.add_theme_stylebox_override("panel", sb)
	fond.set_anchors_and_offsets_preset(PRESET_RIGHT_WIDE)
	fond.offset_left = -PANNEAU_L
	add_child(fond)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	fond.add_child(sc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	_titre(v, "CARTE DU MONDE (conception)")
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", 6)
	f.add_theme_constant_override("v_separation", 6)
	v.add_child(f)
	for c in COUCHES:
		var b := _bouton(f, String(c[1]), func(): pass)
		b.toggle_mode = true
		b.button_pressed = bool(couches[c[0]])
		b.custom_minimum_size = Vector2(140, 52)
		var cle: String = c[0]
		b.toggled.connect(func(on): couches[cle] = on)
	var hz := HBoxContainer.new()
	v.add_child(hz)
	for z in [["−", 1.0 / 1.4], ["+", 1.4], ["Cadrer", 0.0]]:
		var fz: float = z[1]
		var bz := _bouton(hz, String(z[0]), func():
			if fz == 0.0:
				zoom = 1.0
				decalage = Vector2.ZERO
			else:
				zoomer(fz))
		bz.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_infos = Label.new()
	_infos.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_infos.custom_minimum_size = Vector2(PANNEAU_L - 40, 0)
	_infos.add_theme_font_size_override("font_size", 24)
	v.add_child(_infos)
	_btn_aller = _bouton(v, "Y aller", func():
		if modele != null and sel != "" and modele.kit_aller(sel):
			_fermer())
	_btn_iti = _bouton(v, "Itinéraire depuis ma position", func(): calculer_itineraire())
	_bouton(v, "Fermer la carte", func(): _fermer())


func _fermer() -> void:
	ferme.emit()
	queue_free()


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
	b.add_theme_font_size_override("font_size", 25)
	b.pressed.connect(action)
	parent.add_child(b)
	return b


func _maj() -> void:
	if _infos == null:
		return
	_btn_aller.disabled = modele == null or sel == ""
	_btn_iti.disabled = modele == null or sel == ""
	if sel == "":
		var ici := CarteMonde.lieu(String(modele.kit_lieu)) if modele != null else {}
		_infos.text = "Touchez une ville ou un lieu.\nGlisser : déplacer. Pincer ou + / − : zoomer.\n\n%d villes-étapes, %d routes, %d lieux d'intérêt.%s" % [
			CarteMonde.villes().size(), CarteMonde.routes().size(), CarteMonde.lieux().size() - CarteMonde.villes().size(),
			("\n\nVous êtes à : " + String(ici.nom)) if not ici.is_empty() else ""]
		return
	_infos.text = texte_lieu(sel, itineraire)


# Fiche d'un lieu (publique pour les tests)
static func texte_lieu(id: String, iti: Array = []) -> String:
	var D := CarteMonde.donnees()
	var l := CarteMonde.lieu(id)
	if l.is_empty():
		return ""
	var t := String(l.type)
	var lignes := ["%s — %s" % [l.nom, D.types.get(t, {}).get("nom", t)]]
	var fac := String(l.get("faction", ""))
	var lf := "Faction : " + (String(D.factions[fac].nom) if D.factions.has(fac) else "aucune")
	if l.has("niveau"):
		lf += " · niveau %d" % int(l.niveau)
	lignes.append(lf)
	lignes.append("Zone de décor : %s" % CombatModele.KIT_ZONES_NOMS.get(String(l.get("zone", "")), String(l.get("zone", "?"))))
	if l.has("repere"):
		lignes.append("Repère réel : %s" % l.repere)
	var RG := CarteMonde.region_a(Vector2(l.pos[0], l.pos[1]))
	if not RG.is_empty():
		lignes.append("Région : %s — %s" % [RG.nom, RG.theme])
	if l.has("maire"):
		lignes.append("Maire : M. %s" % l.maire)
	if String(l.get("batiment", "")) != "":
		lignes.append("Dans le Kit : fait apparaître « %s »." % l.batiment)
	lignes.append("")
	lignes.append(String(l.get("note", "")))
	if t == "ville":
		lignes.append("")
		lignes.append("Routes :")
		for v in CarteMonde.voisins(id):
			var r: Dictionary = v.route
			lignes.append("→ %s : %s, danger %d, %d km" % [CarteMonde.lieu(v.id).nom, String(D.routes_types[r.type].nom).to_lower(),
				int(r.danger), int(CarteMonde.longueur_km(r))])
	if iti.size() >= 2:
		var km := 0.0
		var dmax := 0
		for i in iti.size() - 1:
			var r := CarteMonde.route_entre(iti[i], iti[i + 1])
			km += CarteMonde.longueur_km(r)
			dmax = maxi(dmax, int(r.danger))
		lignes.append("")
		lignes.append("Itinéraire : %s" % " → ".join(iti.map(func(x): return String(CarteMonde.lieu(x).nom))))
		lignes.append("%d étapes, %d km, danger maximal %d" % [iti.size() - 1, int(km), dmax])
	return "\n".join(lignes)


# --- Dessin ------------------------------------------------------------------------------------
# Régions : teinte de chaque région (ville-étape la plus proche) et nom au centre de ses villes
var _regions_cache := {}

func _regions(r: Rect2, f: Font) -> void:
	var n := 48
	if _regions_cache.is_empty():
		for i in n:
			for j in n:
				_regions_cache[Vector2i(i, j)] = String(CarteMonde.region_a(Vector2((i + 0.5) / n, (j + 0.5) / n)).get("id", ""))
	var cw := r.size / float(n)
	for k in _regions_cache:
		var R := CarteMonde.region(_regions_cache[k])
		if R.is_empty():
			continue
		var c := Color(String(R.couleur))
		c.a = 0.22
		draw_rect(Rect2(r.position + Vector2(k.x, k.y) * cw, cw + Vector2.ONE), c)
		for d in [Vector2i(1, 0), Vector2i(0, 1)]:   # frontière
			if _regions_cache.get(k + d, _regions_cache[k]) != _regions_cache[k]:
				var a := r.position + Vector2(k + d) * cw
				var b := a + (Vector2(0, cw.y) if d.x == 1 else Vector2(cw.x, 0))
				draw_line(a, b, Color(0.1, 0.08, 0.06, 0.6), 1.5)
	for R in CarteMonde.regions():
		var c0 := Vector2.ZERO
		for vid in R.villes:
			c0 += CarteMonde.pos(String(vid))
		c0 /= maxf(1.0, R.villes.size())
		var p := _ecran(c0) + Vector2(0, 30)
		var t := String(R.nom).to_upper()
		var tz := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
		draw_string_outline(f, p - Vector2(tz.x * 0.5, 0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, Color(0, 0, 0, 0.8))
		draw_string(f, p - Vector2(tz.x * 0.5, 0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(String(R.couleur)).lightened(0.35))


func _draw() -> void:
	var D := CarteMonde.donnees()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.05, 0.05))
	var r := _rect_image()
	if _tex != null:
		draw_texture_rect(_tex, r, false)
	draw_rect(r, Color(0, 0, 0, 0.22))
	var f := get_theme_default_font()
	var surligne := {}
	for i in maxi(0, itineraire.size() - 1):
		surligne[_cle(itineraire[i], itineraire[i + 1])] = true
	if couches.regions:
		_regions(r, f)
	# Routes
	if couches.routes:
		for rt in CarteMonde.routes():
			_route(rt, surligne.has(_cle(String(rt.a), String(rt.b))))
	# Lieux d'intérêt
	for l in CarteMonde.lieux():
		var t := String(l.type)
		if t == "ville":
			continue
		var couche := "ressources" if t in RESSOURCES else "sites"
		if not couches[couche] and String(l.id) != sel:
			continue
		var p := _ecran(Vector2(float(l.pos[0]), float(l.pos[1])))
		var rr := 11.0 + 3.0 * (zoom - 1.0)
		var col := Color(String(D.types.get(t, {}).get("couleur", "#888888")))
		draw_circle(p, rr + 3.0, Color(0, 0, 0, 0.75))
		draw_circle(p, rr, col)
		_glyphe(t, p, rr)
		if String(l.id) == sel:
			draw_arc(p, rr + 8.0, 0.0, TAU, 32, Color.WHITE, 3.0)
		if zoom >= 1.6 or String(l.id) == sel:
			_texte(f, p + Vector2(0, rr + 22.0), String(l.nom), 19, Color("#F6F0DC"))
	# Villes
	if couches.villes:
		for l in CarteMonde.villes():
			var p := _ecran(Vector2(float(l.pos[0]), float(l.pos[1])))
			var fac: Dictionary = D.factions.get(String(l.faction), {})
			if couches.factions and not fac.is_empty():
				var cf := Color(String(fac.couleur))
				draw_circle(p, 34.0, Color(cf.r, cf.g, cf.b, 0.28))
			draw_circle(p, 20.0, Color(0, 0, 0, 0.85))
			draw_circle(p, 16.0, Color("#E8A33D"))
			draw_circle(p, 9.0, Color(String(fac.get("couleur", "#444444"))) if couches.factions else Color("#3A2E24"))
			if String(l.id) == sel:
				draw_arc(p, 27.0, 0.0, TAU, 40, Color.WHITE, 3.5)
			_texte(f, p + Vector2(0, 46), String(l.nom), 25, Color("#F6F0DC"))
			if couches.dangers:
				_texte(f, p + Vector2(0, -26), "niv. %d" % int(l.niveau), 18, Color("#F0C060"))
	# Vous êtes ici
	if modele != null:
		var ici := CarteMonde.lieu(String(modele.kit_lieu))
		if not ici.is_empty():
			var p := _ecran(Vector2(float(ici.pos[0]), float(ici.pos[1])))
			var a := 0.5 + 0.5 * sin(_t * 4.0)
			draw_arc(p, 30.0 + 10.0 * a, 0.0, TAU, 40, Color(1, 1, 1, 0.8 - 0.5 * a), 3.0)
			var h := p + Vector2(0, -34)
			draw_colored_polygon(PackedVector2Array([h, h + Vector2(-13, -22), h + Vector2(13, -22)]), Color.WHITE)
			draw_polyline(PackedVector2Array([h, h + Vector2(-13, -22), h + Vector2(13, -22), h]), Color.BLACK, 2.0)
	if couches.legende:
		_legende(f, D)


func _cle(a: String, b: String) -> String:
	return a + "|" + b if a < b else b + "|" + a


func _route(rt: Dictionary, surligne: bool) -> void:
	var D := CarteMonde.donnees()
	var a := _ecran(CarteMonde.pos(String(rt.a)))
	var b := _ecran(CarteMonde.pos(String(rt.b)))
	var col := Color(String(D.routes_types.get(rt.type, {}).get("couleur", "#FFFFFF")))
	var w := 4.0
	if surligne:
		draw_line(a, b, Color(1, 1, 1, 0.9), 12.0)
	match String(rt.type):
		"rail":
			draw_line(a, b, Color(0, 0, 0, 0.8), 6.0)
			draw_line(a, b, Color("#8A8070"), 2.0)
			var n := int(a.distance_to(b) / 14.0)
			var nrm := (b - a).normalized().orthogonal() * 6.0
			for i in range(1, n):
				var q := a.lerp(b, float(i) / n)
				draw_line(q - nrm, q + nrm, Color(0.1, 0.1, 0.1), 2.0)
		"piste":
			draw_line(a, b, Color(0, 0, 0, 0.6), w + 3.0)
			draw_dashed_line(a, b, col, w, 12.0)
		_:
			draw_line(a, b, Color(0, 0, 0, 0.75), w + 3.0)
			draw_line(a, b, col, w)
	if couches.dangers:
		var m := (a + b) * 0.5
		var d := int(rt.danger)
		draw_circle(m, 13.0, Color(0, 0, 0, 0.85))
		draw_circle(m, 11.0, Color(0.35, 0.75, 0.35).lerp(Color(0.85, 0.15, 0.1), clampf((d - 1) / 6.0, 0.0, 1.0)))
		_texte(get_theme_default_font(), m + Vector2(0, 7), str(d), 18, Color.WHITE)


func _texte(f: Font, p: Vector2, t: String, taille: int, col: Color) -> void:
	var l := 320.0
	draw_string_outline(f, p - Vector2(l * 0.5, 0), t, HORIZONTAL_ALIGNMENT_CENTER, l, taille, 6, Color(0, 0, 0, 0.9))
	draw_string(f, p - Vector2(l * 0.5, 0), t, HORIZONTAL_ALIGNMENT_CENTER, l, taille, col)


# Petits pictogrammes dessinés par le code (aucune image à produire)
func _glyphe(t: String, p: Vector2, r: float) -> void:
	var k := r / 11.0
	var n := Color(0.08, 0.07, 0.06)
	var bl := Color(0.96, 0.93, 0.85)
	match t:
		"petrole":   # derrick
			draw_polyline(PackedVector2Array([p + Vector2(-5, 7) * k, p + Vector2(0, -8) * k, p + Vector2(5, 7) * k]), bl, 2.0)
			draw_line(p + Vector2(-3, 1) * k, p + Vector2(3, 1) * k, bl, 2.0)
		"raffinerie":
			draw_rect(Rect2(p + Vector2(-6, -1) * k, Vector2(8, 7) * k), n)
			draw_rect(Rect2(p + Vector2(3, -8) * k, Vector2(3, 14) * k), n)
		"gaz":   # flamme
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -8) * k, p + Vector2(5, 3) * k, p + Vector2(0, 7) * k, p + Vector2(-5, 3) * k]), n)
		"mine":   # pioches croisées
			draw_line(p + Vector2(-6, 6) * k, p + Vector2(6, -6) * k, bl, 2.5)
			draw_line(p + Vector2(-6, -6) * k, p + Vector2(6, 6) * k, bl, 2.5)
		"eau":   # goutte
			draw_circle(p + Vector2(0, 2) * k, 4.5 * k, bl)
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -8) * k, p + Vector2(4, 0) * k, p + Vector2(-4, 0) * k]), bl)
		"depot":   # fût
			draw_rect(Rect2(p + Vector2(-4, -6) * k, Vector2(8, 12) * k), bl)
			draw_line(p + Vector2(-4, -2) * k, p + Vector2(4, -2) * k, n, 1.5)
			draw_line(p + Vector2(-4, 2) * k, p + Vector2(4, 2) * k, n, 1.5)
		"epaves":   # ancre
			draw_line(p + Vector2(0, -7) * k, p + Vector2(0, 6) * k, bl, 2.0)
			draw_arc(p + Vector2(0, 1) * k, 5.5 * k, 0.2, PI - 0.2, 12, bl, 2.0)
		"bunker":   # coupole
			draw_arc(p + Vector2(0, 4) * k, 6.5 * k, PI, TAU, 12, bl, 2.5)
			draw_line(p + Vector2(-7, 4) * k, p + Vector2(7, 4) * k, bl, 2.5)
		"antenne":
			draw_line(p + Vector2(0, -6) * k, p + Vector2(0, 7) * k, bl, 2.0)
			draw_arc(p + Vector2(0, -3) * k, 5.0 * k, -PI * 0.8, -PI * 0.2, 8, bl, 1.5)
		"peage":   # barrière
			draw_rect(Rect2(p + Vector2(-7, -2) * k, Vector2(14, 4) * k), bl)
			draw_line(p + Vector2(-2, -2) * k, p + Vector2(-2, 2) * k, n, 2.0)
			draw_line(p + Vector2(3, -2) * k, p + Vector2(3, 2) * k, n, 2.0)
		"bataille":   # croix
			draw_line(p + Vector2(-5, -5) * k, p + Vector2(5, 5) * k, bl, 3.0)
			draw_line(p + Vector2(-5, 5) * k, p + Vector2(5, -5) * k, bl, 3.0)
		"preservee":   # arbre
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -8) * k, p + Vector2(6, 4) * k, p + Vector2(-6, 4) * k]), bl)
			draw_line(p + Vector2(0, 4) * k, p + Vector2(0, 8) * k, bl, 2.0)
		"desert":   # dunes
			draw_arc(p + Vector2(-3, 5) * k, 5.0 * k, PI, TAU, 8, n, 2.0)
			draw_arc(p + Vector2(4, 4) * k, 4.0 * k, PI, TAU, 8, n, 2.0)


func _legende(f: Font, D: Dictionary) -> void:
	var types: Array = D.types.keys().filter(func(t): return t != "ville")
	var x0 := 14.0
	var h := 26.0
	var y0 := size.y - 14.0 - h * (types.size() + 4)
	draw_rect(Rect2(Vector2(x0 - 8, y0 - 26), Vector2(250, h * (types.size() + 4) + 20)), Color(0, 0, 0, 0.62))
	draw_string(f, Vector2(x0, y0 - 4), "LÉGENDE", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#E8A33D"))
	var y := y0 + 14.0
	for rt in ["route", "piste", "rail"]:
		var a := Vector2(x0, y)
		var c := Color(String(D.routes_types[rt].couleur))
		if rt == "piste":
			draw_dashed_line(a, a + Vector2(30, 0), c, 4.0, 8.0)
		elif rt == "rail":
			draw_line(a, a + Vector2(30, 0), Color("#8A8070"), 3.0)
		else:
			draw_line(a, a + Vector2(30, 0), c, 4.0)
		draw_string(f, a + Vector2(40, 7), String(D.routes_types[rt].nom), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("#F6F0DC"))
		y += h
	for t in types:
		var p := Vector2(x0 + 15, y)
		draw_circle(p, 10.0, Color(String(D.types[t].couleur)))
		_glyphe(String(t), p, 10.0)
		draw_string(f, p + Vector2(25, 6), String(D.types[t].nom), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("#F6F0DC"))
		y += h
