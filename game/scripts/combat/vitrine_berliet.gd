# Vitrine du Berliet GDR (Kit de développement) : changer toutes les pièces du camion (châssis, pneus avant et arrière,
# échappement, réservoir, module arrière, trappe) et essayer la halte de l'équipage (Bivouac), de jour ou de nuit.
# Aucune règle ici : BerlietConfig (pièces), Bivouac (équipage) ; cet écran ne fait que dessiner et transmettre les choix.
class_name VitrineBerliet
extends Control

signal ferme

const PANNEAU_L := 470.0
const ORDRE := [["chassis", "Châssis"], ["pneu_av", "Pneus avant"], ["pneu_ar", "Pneus arrière"],
	["echappement", "Échappement"], ["reservoir", "Réservoir"], ["module", "Module arrière"]]

var config := BerlietConfig.defaut()
var modele = null         # CombatModele : si fourni, les choix s'appliquent au camion de l'expédition (DEC-139)
var bivouac: Bivouac
var camion: BerlietDessin
var nuit := false
var distance := 0.0
var _arriere: Node2D      # calque derrière le camion (vigie dans la trappe)
var _avant: Node2D        # calque devant le camion (équipage au sol et sur le toit)
var _lumiere: Node2D      # feu de camp et fumées (non assombris la nuit)
var _infos: Label
var _btn_halte: Button
var _btn_trappe: Button
var _boutons := {}        # clé -> {valeur: Button}
var _fumees := []         # {p (m, repère monde), age}
var _t_fumee := 0.0
var _trappe_manuelle := 0.0  # trappe ouverte à la main (équipage à bord)


class Calque extends Node2D:
	var dessin: Callable
	func _draw() -> void:
		dessin.call(self)


func _ready() -> void:
	if modele != null:
		config = modele.berliet_config   # même dictionnaire : la vitrine règle le camion du convoi
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	_arriere = Calque.new()
	_arriere.dessin = _dessiner_arriere
	add_child(_arriere)
	camion = BerlietDessin.new()
	add_child(camion)
	_avant = Calque.new()
	_avant.dessin = _dessiner_avant
	add_child(_avant)
	_lumiere = Calque.new()
	_lumiere.dessin = _dessiner_lumiere
	add_child(_lumiere)
	_construire_panneau()
	_nouveau_bivouac()
	_maj()


func _nouveau_bivouac() -> void:
	bivouac = Bivouac.new(BerlietConfig.ancrages_m(config))


func _construire_panneau() -> void:
	var fond := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.08, 0.09, 0.94)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(12)
	fond.add_theme_stylebox_override("panel", sb)
	fond.set_anchors_and_offsets_preset(PRESET_RIGHT_WIDE)
	fond.offset_left = -PANNEAU_L
	fond.offset_right = -16
	fond.offset_top = 16
	fond.offset_bottom = -16
	add_child(fond)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	fond.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 8)
	sc.add_child(v)
	_titre(v, "BERLIET GDR")
	_infos = Label.new()
	_infos.add_theme_font_size_override("font_size", 23)
	_infos.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_infos)
	var hb := HBoxContainer.new()
	v.add_child(hb)
	_btn_halte = _bouton(hb, "S'arrêter", _halte)
	_btn_halte.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bn := _bouton(hb, "Jour / nuit", func(): nuit = not nuit)
	bn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_trappe = _bouton(v, "Trappe : ouvrir", _basculer_trappe)
	for o in ORDRE:
		var cle: String = o[0]
		_titre(v, o[1])
		var f := HFlowContainer.new()
		f.add_theme_constant_override("h_separation", 6)
		f.add_theme_constant_override("v_separation", 6)
		v.add_child(f)
		_boutons[cle] = {}
		for val in BerlietConfig.options(cle):
			var b := _bouton(f, BerlietConfig.libelle(cle, val), func(): _choisir(cle, val))
			b.toggle_mode = true
			b.custom_minimum_size = Vector2(130, 52)
			_boutons[cle][str(val)] = b
	_titre(v, "")
	_bouton(v, "Fermer", func():
		ferme.emit()
		queue_free())


func _titre(parent: Control, t: String) -> void:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_color", Color("#E8A33D"))
	parent.add_child(l)


func _bouton(parent: Control, t: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(0, 54)
	b.add_theme_font_size_override("font_size", 23)
	b.pressed.connect(action)
	parent.add_child(b)
	return b


func _choisir(cle: String, val) -> void:
	var ok: bool = modele.berliet_regler(cle, val) if modele != null else BerlietConfig.regler(config, cle, val)
	if ok:
		if cle == "chassis":
			# les ancrages (feu, roues arrière) changent avec la longueur : nouvel équipage, à bord, même état de marche
			var roule := bivouac.phase in ["route", "demarrage"]
			bivouac = Bivouac.new(BerlietConfig.ancrages_m(config), Bivouac.EQUIPAGE, roule)
			if not roule:
				bivouac.arreter()
	_maj()


func _halte() -> void:
	if not bivouac.arreter():
		bivouac.repartir()
	_maj()


func _basculer_trappe() -> void:
	if bivouac.dehors() > 0:
		return
	_trappe_manuelle = 0.0 if _trappe_manuelle > 0.5 else 1.0
	_maj()


func _maj() -> void:
	camion.config = config
	for cle in _boutons:
		for val in _boutons[cle]:
			_boutons[cle][val].button_pressed = str(config[cle]) == val
	var V := BerlietConfig.valeurs(config)
	_infos.text = "%s\nCharge %.1f t · gazole %d L · moteur +%d %%\nVitesse sur route ×%.2f · tout-terrain ×%.2f\n(valeurs provisoires)" % [
		_texte_phase(), V.charge_t, V.gazole_l, int(V.bonus_puissance * 100.0), V.vitesse_route, V.tout_terrain]
	_btn_halte.text = "Repartir" if bivouac.phase in ["descente", "camp"] else "S'arrêter (halte)"
	_btn_halte.disabled = bivouac.phase in ["freinage", "rappel", "remontee"]
	_btn_trappe.text = "Trappe : fermer" if _trappe_manuelle > 0.5 else "Trappe : ouvrir"
	_btn_trappe.disabled = bivouac.dehors() > 0


func _texte_phase() -> String:
	match bivouac.phase:
		"route": return "En route."
		"freinage": return "Le camion s'arrête…"
		"descente": return "L'équipage descend (%d dehors)." % bivouac.dehors()
		"camp": return "Halte : vigie sur le toit, réparations, feu de camp."
		"rappel", "remontee": return "Tout le monde remonte (%d à bord sur %d)." % [bivouac.a_bord(), bivouac.equipiers.size()]
		"demarrage": return "Départ."
	return ""


# --- Boucle -------------------------------------------------------------------------------------------------------------
func _process(delta: float) -> void:
	var avant := bivouac.phase
	bivouac.avancer(delta)
	if bivouac.phase != avant or Engine.get_process_frames() % 15 == 0:
		_maj()
	distance += bivouac.vitesse * delta
	camion.ppm = _ppm()
	camion.position = _origine()
	camion.angle_roues = distance / 0.5
	var moteur := bivouac.vitesse > 0.0 or bivouac.phase == "demarrage"
	camion.secousse = sin(Time.get_ticks_msec() * 0.045) * (0.6 if moteur else 0.25) * camion.ppm * 0.01
	camion.trappe = maxf(bivouac.trappe, _trappe_manuelle)
	camion.stabilisateurs = move_toward(camion.stabilisateurs, 1.0 if bivouac.phase in ["descente", "camp"] else 0.0, delta * 0.8)
	camion.teinte = Color(0.42, 0.45, 0.62) if nuit else Color.WHITE
	# fumée d'échappement (repère monde : elle reste sur place quand le camion avance)
	_t_fumee -= delta
	if _t_fumee <= 0.0:
		_t_fumee = 0.12 if bivouac.vitesse > 0.5 else 0.45
		var s := camion.sortie_echappement() / camion.ppm
		_fumees.append({"p": Vector2(distance + s.x, -s.y), "age": 0.0})
	for f in _fumees:
		f.age += delta
		f.p = f.p + Vector2(0.0, delta * 0.9)
	_fumees = _fumees.filter(func(f): return f.age < 3.0)
	queue_redraw()
	camion.queue_redraw()
	_arriere.queue_redraw()
	_avant.queue_redraw()
	_lumiere.queue_redraw()
	_avant.modulate = camion.teinte
	_arriere.modulate = camion.teinte


func _zone() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(size.x - PANNEAU_L - 16.0, size.y))


# La scène montrée va du feu de camp (moins 1,5 m) au pare-chocs avant
func _etendue_m() -> Vector2:
	var A := BerlietConfig.ancrages_m(config)
	return Vector2(float(A.feu) - 1.6, 2154.0 / BerlietConfig.ppm_art() + 0.6)


func _ppm() -> float:
	var z := _zone()
	var e := _etendue_m()
	return minf(z.size.x * 0.94 / (e.y - e.x), z.size.y * 0.62 / 4.5)


func _sol_y() -> float:
	return size.y * 0.8


# Origine du camion à l'écran (sol, au droit de u = 0) : le camion reste centré, le décor défile
func _origine() -> Vector2:
	var z := _zone()
	var e := _etendue_m()
	return Vector2(z.size.x * 0.5 - (e.x + e.y) * 0.5 * _ppm(), _sol_y())


# Point du repère camion (m, y vers le haut) -> écran
func _ecran(x: float, y: float) -> Vector2:
	return _origine() + Vector2(x, -y) * _ppm()


# --- Décor -----------------------------------------------------------------------------------------------------------
func _draw() -> void:
	var W := size.x
	var H := size.y
	var ciel_h := Color("#1B2236") if nuit else Color("#9FB3C2")
	var ciel_b := Color("#3A3A4A") if nuit else Color("#E2D2B0")
	var bandes := 24
	for i in bandes:
		var c := ciel_h.lerp(ciel_b, float(i) / bandes)
		draw_rect(Rect2(0, _sol_y() * i / bandes, W, _sol_y() / bandes + 1.0), c)
	if nuit:
		for i in 40:
			var sx := fmod(i * 137.5, W)
			var sy := fmod(i * 71.3, _sol_y() * 0.6)
			draw_circle(Vector2(sx, sy), 1.5, Color(1, 1, 0.9, 0.6))
	# collines lointaines (défilent lentement)
	var p := _ppm()
	var off := -fmod(distance * p * 0.08, 900.0)
	var coll := Color("#2A2E33") if nuit else Color("#8C8A78")
	var x := -900.0 + off
	while x < W + 900.0:
		var h0 := 70.0 + 50.0 * sin(x * 0.007) + 30.0 * sin(x * 0.019)
		var h1 := 70.0 + 50.0 * sin((x + 30.0) * 0.007) + 30.0 * sin((x + 30.0) * 0.019)
		draw_colored_polygon(PackedVector2Array([Vector2(x, _sol_y()), Vector2(x, _sol_y() - h0),
			Vector2(x + 31.0, _sol_y() - h1), Vector2(x + 31.0, _sol_y())]), coll)
		x += 30.0
	# sol de terre, cailloux qui défilent à la vitesse du camion
	var terre := Color("#3B3226") if nuit else Color("#7A6448")
	draw_rect(Rect2(0, _sol_y() - 4.0, W, H - _sol_y() + 4.0), terre)
	draw_rect(Rect2(0, _sol_y() - 4.0, W, 10.0), terre.darkened(0.25))
	var pas := 1.7 * p
	var o2 := -fmod(distance * p, pas)
	var k := 0
	x = o2
	while x < W:
		var j := int(floor((x - o2) / pas + distance * p / pas)) + k
		var y := _sol_y() + 14.0 + float(posmod(j * 37, 5)) * 0.07 * p
		draw_circle(Vector2(x + float(posmod(j * 53, 7)) * 0.1 * p, y), (0.05 + 0.02 * float(posmod(j, 3))) * p, terre.darkened(0.35))
		x += pas


# Derrière le camion : la vigie quand elle est dans la trappe (la cabine cache le bas du corps)
func _dessiner_arriere(ci: CanvasItem) -> void:
	for q in bivouac.equipiers:
		if q.porte == "trappe" and q.etat in ["sort", "descend"]:
			_perso(ci, q)


# Devant le camion : équipage au sol et sur le toit
func _dessiner_avant(ci: CanvasItem) -> void:
	for q in bivouac.equipiers:
		if q.etat in ["a_bord", "attend"]:
			continue
		if q.porte == "trappe" and q.etat in ["sort", "descend"]:
			continue
		_perso(ci, q)


# Feu de camp et fumées
func _dessiner_lumiere(ci: CanvasItem) -> void:
	var p := _ppm()
	var orig := _origine()
	_feu(ci)
	for f in _fumees:
		var a: float = f.age / 3.0
		var pos := orig + Vector2(f.p.x - distance, -f.p.y) * p
		ci.draw_circle(pos, (0.08 + 0.3 * a) * p, Color(0.35, 0.33, 0.31, 0.22 * (1.0 - a)))
	if bivouac.fumee > 0.0:
		for i in 5:
			var hh := fmod(bivouac.t * 0.6 + i * 0.4, 2.0)
			ci.draw_circle(_ecran(bivouac.A.feu + 0.1 * sin(hh * 3.0 + i), 0.2 + hh), (0.15 + 0.2 * hh) * p,
				Color(0.5, 0.5, 0.5, 0.35 * bivouac.fumee * (1.0 - hh / 2.0)))


func _perso(ci: CanvasItem, q: Dictionary) -> void:
	var p := _ppm()
	# au sol, un peu en avant du camion (plus près de nous) ; sur le toit, à la hauteur du toit
	var pied := _ecran(q.x, q.y) + (Vector2(0, 0.25 * p) if q.y < 0.1 else Vector2.ZERO)
	var opts := {"miroir": q.dir < 0.0, "peau": bivouac.equipiers.find(q)}
	if q.etat in ["marche", "rentre"]:
		opts.phase = q.pas * 4.2
	match String(q.action):
		"repare":
			opts.travaille = bivouac.t * 5.0
		"cuisine":
			opts.assis = true
			opts.travaille = bivouac.t * 2.0
		"assis":
			opts.assis = true
		"eteint":
			opts.travaille = bivouac.t * 7.0
	if opts.get("assis", false):
		pied += Vector2(0, -0.35 * p)
	Silhouette.dessiner(ci, pied, p, String(q.variante), opts)


func _feu(ci: CanvasItem) -> void:
	var p := _ppm()
	var c := _ecran(bivouac.A.feu, 0.0) + Vector2(0, 0.3 * p)
	var f := bivouac.feu
	# pierres et bûches (restent après extinction)
	if f > 0.0 or bivouac.fumee > 0.0 or bivouac.phase in ["camp", "descente", "rappel", "remontee"]:
		for i in 6:
			var a := PI + PI * i / 5.0
			ci.draw_circle(c + Vector2(cos(a) * 0.38 * p, 0.05 * p), 0.09 * p, Color("#5A554E"))
		ci.draw_line(c + Vector2(-0.3, 0.02) * p, c + Vector2(0.3, -0.06) * p, Color("#3A2A1C"), 0.09 * p)
		ci.draw_line(c + Vector2(-0.28, -0.07) * p, c + Vector2(0.26, 0.03) * p, Color("#4A3422"), 0.08 * p)
	if f <= 0.0:
		return
	# lueur (forte la nuit)
	var lueur := (0.35 if nuit else 0.12) * f
	for i in 4:
		ci.draw_circle(c, (2.6 - i * 0.55) * p, Color(1.0, 0.55, 0.2, lueur * 0.25))
	var tt := bivouac.t
	for i in 5:
		var h := maxf(0.05, (0.35 + 0.25 * sin(tt * 9.0 + i * 1.7)) * f)
		var bx := (i - 2) * 0.09 * p
		var flamme := PackedVector2Array([c + Vector2(bx - 0.08 * p, 0), c + Vector2(bx + 0.08 * p, 0),
			c + Vector2(bx + 0.02 * p * sin(tt * 7.0 + i), -h * p)])
		ci.draw_colored_polygon(flamme, Color(1.0, 0.45 + 0.1 * i, 0.12, 0.85))
	# marmite sur trépied
	ci.draw_line(c + Vector2(-0.3, 0.0) * p, c + Vector2(0.0, -0.75) * p, Color("#2A2522"), 0.03 * p)
	ci.draw_line(c + Vector2(0.3, 0.0) * p, c + Vector2(0.0, -0.75) * p, Color("#2A2522"), 0.03 * p)
	ci.draw_rect(Rect2(c + Vector2(-0.14, -0.55) * p, Vector2(0.28, 0.2) * p), Color("#3A3632"))
