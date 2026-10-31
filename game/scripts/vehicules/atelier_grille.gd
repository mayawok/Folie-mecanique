# Atelier guidé sur grille (DEC-035) : le joueur glisse chaque pièce à sa place sur la grille du châssis
# (cellules de 25 cm). Début de partie : peu de liberté, chaque pièce n'a qu'un emplacement, dessiné en
# fantôme ; une pièce ne se pose que lorsque celles dont elle dépend sont en place (le cadre d'abord).
# La logique (pièces disponibles, validation, transformation du véhicule) reste dans le modèle.
class_name AtelierGrille
extends Control

signal ferme(assemble: bool)

const C_FOND := Color(0.06, 0.065, 0.07)
const C_GRILLE := Color(1, 1, 1, 0.07)
const C_CADRE := Color(1, 1, 1, 0.22)
const C_ACCENT := Color("#E8A33D")
const C_TEXTE := Color("#F2EEE6")
const C_DISCRET := Color("#A8A196")
const C_VERT := Color("#5FB36B")
const CELL_M := 0.25

var m                          # CombatModele
var uid := 0                   # véhicule transformé (0 = premier véhicule)
var plan := {}                 # assemblage visé
var items: Array = []          # {id, fiche, slot: Rect2i, etat: bac|pose|monte, noeud, carte: Rect2}
var _gw := 10
var _gh := 6
var _cell := 60.0
var _grille := Rect2()         # rectangle de la grille à l'écran
var _drag = null               # item en cours de déplacement
var _prise := Vector2.ZERO     # décalage doigt -> coin de la pièce
var _message := ""
var _msg_t := 0.0
var _btn_ok: Button
var _btn_plus_tard: Button
var _titre := ""


func ouvrir(modele, vehicule_uid: int, plan_id: String) -> void:
	m = modele
	uid = vehicule_uid
	plan = Assemblage.de_type(plan_id)
	var ch := Assemblage.piece(plan.chassis)
	_gw = int(ch.grille[0])
	_gh = int(ch.grille[1])
	var v = m.trouver(uid) if uid != 0 else null
	var montees: Array = Assemblage.ids(v.assemblage) if v != null else []
	_titre = "Assembler : %s" % plan.nom if v == null else "%s → %s" % [v.nom, plan.nom]
	# Le châssis, puis les pièces du plan ; celles déjà montées sur le véhicule restent en place
	var a_placer: Array = [{"piece": plan.chassis, "pos": [0, 0]}] + plan.pieces
	for p in a_placer:
		var f := Assemblage.piece(p.piece)
		var e: Array = f.get("emprise", ch.grille)
		var it := {"id": p.piece, "fiche": f, "slot": Rect2i(int(p.pos[0]), int(p.pos[1]), int(e[0]), int(e[1])), "etat": "bac"}
		var k: int = montees.find(p.piece)
		if k >= 0:
			montees.remove_at(k)
			it.etat = "monte"
		items.append(it)


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	for it in items:
		var n := VehiculeDessin.new()
		n.equipage = false
		n.configurer_d(_dessin(it.fiche))
		add_child(n)
		it.noeud = n
	_btn_ok = Button.new()
	_btn_ok.text = "Démarrer"
	_btn_ok.custom_minimum_size = Vector2(300, 90)
	_btn_ok.pressed.connect(_terminer)
	add_child(_btn_ok)
	if uid != 0:
		_btn_plus_tard = Button.new()
		_btn_plus_tard.text = "Plus tard"
		_btn_plus_tard.custom_minimum_size = Vector2(240, 90)
		_btn_plus_tard.pressed.connect(func():
			ferme.emit(false)
			queue_free())
		add_child(_btn_plus_tard)
	_disposer()
	resized.connect(_disposer)


# Description de dessin d'une pièce seule : ses éléments, découpés dans le dessin du véhicule de référence.
func _dessin(f: Dictionary) -> Dictionary:
	var d: Dictionary = f.get("dessin", {})
	var ref: Dictionary = VehiculeDessin.donnees().vehicules.get(d.get("ref", ""), {})
	var res := {"longueur": _gw * CELL_M, "hauteur": _gh * CELL_M, "teinte": ref.get("teinte", "joueur"), "course": 0.0,
		"formes": [], "roues": [], "roues_fond": [], "armes": [], "equipage": []}
	for k in ["formes", "roues", "roues_fond", "armes"]:
		for i in d.get(k, []):
			res[k].append(ref[k][int(i)])
	return res


func _disposer() -> void:
	var zone := Vector2(size.x * 0.6, size.y * 0.62)
	_cell = floorf(minf(zone.x / _gw, zone.y / _gh))
	var g := Vector2(_gw, _gh) * _cell
	_grille = Rect2(Vector2(size.x * 0.05, size.y * 0.2 + (zone.y - g.y) * 0.5), g)
	var x_bac := _grille.end.x + size.x * 0.05
	var y := size.y * 0.2
	for it in items:
		if it.etat == "bac":
			it.carte = Rect2(Vector2(x_bac, y), Vector2(size.x - x_bac - size.x * 0.04, 92))
			y += 104
		var n: VehiculeDessin = it.noeud
		n.ppm = _cell / CELL_M
		n.configurer_d(n.D)
		if it != _drag:
			n.position = _grille.position
	_btn_ok.position = Vector2(size.x - 340, size.y - 130)
	if _btn_plus_tard:
		_btn_plus_tard.position = Vector2(size.x - 610, size.y - 130)
	queue_redraw()


# Une pièce peut se poser si le châssis est en place et si les familles qu'elle demande le sont aussi.
func _prete(it: Dictionary) -> bool:
	if it.fiche.famille == "chassis":
		return true
	var poses := items.filter(func(o): return o.etat != "bac")
	if not poses.any(func(o): return o.fiche.famille == "chassis"):
		return false
	for req in it.fiche.get("requiert", []):
		if not poses.any(func(o): return o.fiche.famille == req):
			return false
	return true


func _slot_ecran(it: Dictionary) -> Rect2:
	var s: Rect2i = it.slot
	return Rect2(Vector2(_grille.position.x + s.position.x * _cell, _grille.end.y - (s.position.y + s.size.y) * _cell), Vector2(s.size) * _cell)


func _complet() -> bool:
	return items.all(func(o): return o.etat != "bac")


func _process(delta: float) -> void:
	_msg_t = maxf(0.0, _msg_t - delta)
	_teintes()
	_btn_ok.disabled = not _complet()
	queue_redraw()


# Pièce posée : opaque ; pièce prête : fantôme bleuté à sa place ; pièce qui attend : invisible.
func _teintes() -> void:
	for it in items:
		var n: VehiculeDessin = it.noeud
		if it == _drag:
			n.modulate = Color(1, 1, 1, 0.95)
		elif it.etat == "bac":
			n.modulate = Color(0.75, 0.85, 1.0, 0.22) if _prete(it) else Color(1, 1, 1, 0)
		else:
			n.modulate = Color.WHITE


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			for it in items:
				if it.etat == "bac" and it.carte.has_point(e.position):
					_prendre(it, e.position)
					break
		elif _drag != null:
			_lacher(e.position)
		accept_event()
	elif e is InputEventMouseMotion and _drag != null:
		_drag.noeud.position = e.position - _prise
		accept_event()


func _prendre(it: Dictionary, doigt: Vector2) -> void:
	if not _prete(it):
		var manque: String = "le cadre" if it.fiche.famille != "chassis" and not items.any(func(o): return o.etat != "bac" and o.fiche.famille == "chassis") \
			else Assemblage.NOMS_FAMILLES.get(it.fiche.get("requiert", [""])[0], "une autre pièce")
		_dire("Posez d'abord %s." % manque)
		return
	_drag = it
	var centre := _slot_ecran(it).get_center() - _grille.position   # centre de la pièce dans le dessin
	_prise = centre
	it.noeud.position = doigt - _prise
	it.noeud.move_to_front()
	_teintes()


func _lacher(doigt: Vector2) -> void:
	var it = _drag
	_drag = null
	var cible := _slot_ecran(it)
	var tolerance := maxf(cible.size.length() * 0.5, _cell * 2.0)
	var tw := create_tween()
	if doigt.distance_to(cible.get_center()) <= tolerance:
		it.etat = "pose"
		tw.tween_property(it.noeud, "position", _grille.position, 0.12)
		var so := get_node_or_null("/root/Son")
		if so:
			so.effet("sfx_atelier", -6.0)
		_dire("%s en place." % it.fiche.nom if not _complet() else "Tout est en place : démarrez !")
		_disposer()
	else:
		tw.tween_property(it.noeud, "position", _grille.position, 0.15)
		_dire("Ce n'est pas sa place : visez l'emplacement en pointillés.")
	_teintes()


func _terminer() -> void:
	if not _complet():
		return
	if m.assembler(uid, plan):
		ferme.emit(true)
		queue_free()
	else:
		_dire(m.journal[-1].txt if not m.journal.is_empty() else "Impossible d'assembler.")


func _dire(t: String) -> void:
	_message = t
	_msg_t = 3.5


func _draw() -> void:
	var police := get_theme_default_font()
	draw_rect(Rect2(Vector2.ZERO, size), C_FOND)
	draw_string(police, Vector2(size.x * 0.05, size.y * 0.09), _titre, HORIZONTAL_ALIGNMENT_LEFT, -1, 44, C_TEXTE)
	var reste := items.filter(func(o): return o.etat == "bac").size()
	var aide := "Glissez chaque pièce à sa place sur la grille." if reste > 0 else "Le véhicule est complet."
	if _msg_t > 0.0:
		aide = _message
	draw_string(police, Vector2(size.x * 0.05, size.y * 0.15), aide, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, C_ACCENT if _msg_t > 0.0 else C_DISCRET)
	# Grille du châssis (25 cm par case) et sol
	for i in _gw + 1:
		var x := _grille.position.x + i * _cell
		draw_line(Vector2(x, _grille.position.y), Vector2(x, _grille.end.y), C_GRILLE, 1.0)
	for j in _gh + 1:
		var y := _grille.position.y + j * _cell
		draw_line(Vector2(_grille.position.x, y), Vector2(_grille.end.x, y), C_GRILLE, 1.0)
	draw_rect(_grille, C_CADRE, false, 2.0)
	draw_line(Vector2(_grille.position.x - 30, _grille.end.y), Vector2(_grille.end.x + 30, _grille.end.y), Color(0.55, 0.45, 0.3), 4.0)
	draw_string(police, _grille.position + Vector2(0, _grille.size.y + 44), "1 case = 25 cm", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, C_DISCRET)
	# Emplacements en pointillés des pièces prêtes à poser
	for it in items:
		if it.etat == "bac" and _prete(it) and it.fiche.famille != "chassis":
			var r := _slot_ecran(it)
			var c := C_ACCENT if it == _drag else Color(1, 1, 1, 0.45)
			for seg in [[r.position, Vector2(r.end.x, r.position.y)], [Vector2(r.end.x, r.position.y), r.end],
					[r.end, Vector2(r.position.x, r.end.y)], [Vector2(r.position.x, r.end.y), r.position]]:
				draw_dashed_line(seg[0], seg[1], c, 2.0, 10.0)
	# Bac des pièces
	var x_bac := _grille.end.x + size.x * 0.05
	draw_string(police, Vector2(x_bac, size.y * 0.2 - 18), "Pièces (%d)" % reste if reste > 0 else "Pièces : tout est monté", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, C_TEXTE)
	for it in items:
		if it.etat != "bac" or it == _drag:
			continue
		var pr := _prete(it)
		draw_rect(it.carte, Color(1, 1, 1, 0.08 if pr else 0.03))
		draw_rect(it.carte, C_ACCENT if pr else Color(1, 1, 1, 0.15), false, 2.0)
		draw_string(police, it.carte.position + Vector2(20, 40), it.fiche.nom, HORIZONTAL_ALIGNMENT_LEFT, it.carte.size.x - 40, 28, C_TEXTE if pr else C_DISCRET)
		var sous: String = "à poser d'abord" if it.fiche.famille == "chassis" else ("prête" if pr else "attend une autre pièce")
		draw_string(police, it.carte.position + Vector2(20, 74), sous, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, C_VERT if pr else C_DISCRET)
	# Caractéristiques une fois complet
	if reste == 0:
		var s := Assemblage.statistiques(plan)
		var txt := "Vitesse %.1f m/s · %d place%s · %s · %d kg" % [s.vitesse, s.equipage, "s" if s.equipage > 1 else "",
			"sans arme" if s.armes.is_empty() else "armé", int(s.poids_kg)]
		draw_string(police, Vector2(x_bac, size.y - 170), txt, HORIZONTAL_ALIGNMENT_LEFT, size.x - x_bac - 30, 26, C_VERT)
