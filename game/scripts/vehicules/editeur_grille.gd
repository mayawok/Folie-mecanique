# Éditeur libre sur grille (G3, DEC-036) : on glisse les pièces de la réserve sur la grille du châssis, elles
# s'aimantent (roues au sol, arme en haut, place libre la plus proche) ; toucher une pièce posée la reprend en main.
# Validation en direct (« ça roule ? »), statistiques calculées et aperçu du véhicule dessiné (G4).
# Aucune règle ici : tout passe par Assemblage (poser, retirer, apercu) et CombatModele.assembler.
class_name EditeurGrille
extends Control

signal ferme(construit: bool)

const C_FOND := Color(0.06, 0.065, 0.07)
const C_GRILLE := Color(1, 1, 1, 0.07)
const C_CADRE := Color(1, 1, 1, 0.22)
const C_ACCENT := Color("#E8A33D")
const C_TEXTE := Color("#F2EEE6")
const C_DISCRET := Color("#A8A196")
const C_VERT := Color("#5FB36B")
const C_ROUGE := Color("#D9674A")
const COULEURS := {"roulement": Color("#3E3C37"), "suspension": Color("#6B6F73"), "moteur": Color("#A8552F"), "cabine": Color("#5E6238"),
	"arme": Color("#9A2F2F"), "attelage": Color("#7A7468")}
const PAR_PAGE := 5

var m                           # CombatModele
var uid := 0                    # véhicule modifié (0 = véhicule neuf, construit sur un châssis de la réserve)
var a := {}                     # assemblage en cours
var _dispo: Array = []          # identifiants des pièces utilisables (réserve + pièces du véhicule modifié)
var _plaques0 := 0
var _page := 0
var _drag := ""                 # pièce tenue en main
var _doigt := Vector2.ZERO
var _grille := Rect2()
var _cell := 20.0
var _cartes: Array = []         # {rect, id, n}
var _message := ""
var _msg_t := 0.0
var _btn_ok: Button
var _btn_annuler: Button
var _btn_plus: Button
var _btn_moins: Button
var _btn_haut: Button
var _btn_bas: Button
var _btn_chassis: Button
var _apercu: VehiculeDessin
var _chassis_i := 0


func ouvrir(modele, vehicule_uid: int) -> void:
	m = modele
	uid = vehicule_uid
	var v = m.trouver(uid) if uid != 0 else null
	if v != null:
		a = v.assemblage.duplicate(true)
		_dispo = Assemblage.ids(v.assemblage) + m.ids_stock()
		_plaques0 = int(a.get("plaques", 0))
	else:
		_dispo = m.ids_stock()
		_choisir_chassis(0)


func _choisir_chassis(i: int) -> void:
	var liste: Array = m.chassis_en_reserve()
	_chassis_i = posmod(i, maxi(1, liste.size()))
	var id: String = liste[_chassis_i]
	a = Assemblage.nouvelle(id, "Frankenstein %s" % Assemblage.piece(id).nom.replace("Châssis ", ""))
	_plaques0 = 0


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	_apercu = VehiculeDessin.new()
	_apercu.equipage = true
	add_child(_apercu)
	_btn_ok = _bouton("Construire", _terminer, 250)
	_btn_annuler = _bouton("Annuler", func():
		ferme.emit(false)
		queue_free(), 200)
	_btn_plus = _bouton("+ plaque", func(): _plaques(1), 150)
	_btn_moins = _bouton("− plaque", func(): _plaques(-1), 150)
	_btn_haut = _bouton("▲", func(): _page = maxi(0, _page - 1), 80)
	_btn_bas = _bouton("▼", func(): _page += 1, 80)
	_btn_chassis = _bouton("Autre châssis", func():
		_choisir_chassis(_chassis_i + 1)
		_maj(), 220)
	_btn_chassis.visible = uid == 0 and m.chassis_en_reserve().size() > 1
	_disposer()
	_maj()
	resized.connect(_disposer)


func _bouton(texte: String, action: Callable, largeur: float) -> Button:
	var b := Button.new()
	b.text = texte
	b.custom_minimum_size = Vector2(largeur, 64)
	b.pressed.connect(action)
	add_child(b)
	return b


func _plaques(d: int) -> void:
	a.plaques = maxi(0, int(a.get("plaques", 0)) + d)
	_maj()


# Pièces de la réserve encore libres, regroupées : [{id, n}]
func _libres() -> Array:
	var c := Assemblage.compter(_dispo)
	for id in Assemblage.ids(a):
		c[id] = int(c.get(id, 0)) - 1
	var res := []
	for id in c:
		var f := Assemblage.piece(id)
		if int(c[id]) > 0 and not f.is_empty() and f.famille != "chassis":
			res.append({"id": id, "n": int(c[id]), "fiche": f})
	res.sort_custom(func(p, q): return String(p.fiche.famille) + String(p.fiche.nom) < String(q.fiche.famille) + String(q.fiche.nom))
	return res


func _cout_plaques() -> float:
	return maxf(0.0, float(int(a.get("plaques", 0)) - _plaques0)) * float(Assemblage.catalogue().regles.plaque.metal)


func _disposer() -> void:
	var g := Assemblage.taille_grille(a)
	var zone := Vector2(size.x * 0.6, size.y * 0.58)
	_cell = floorf(minf(zone.x / maxf(1.0, g.x), zone.y / maxf(1.0, g.y)))
	var taille := Vector2(g) * _cell
	_grille = Rect2(Vector2(size.x * 0.04, size.y * 0.2 + (zone.y - taille.y)), taille)
	var x_bac := size.x * 0.66
	_btn_haut.position = Vector2(x_bac, size.y * 0.2 + PAR_PAGE * 70 + 6)
	_btn_bas.position = Vector2(x_bac + 90, size.y * 0.2 + PAR_PAGE * 70 + 6)
	_btn_plus.position = Vector2(x_bac + 190, size.y * 0.2 + PAR_PAGE * 70 + 6)
	_btn_moins.position = Vector2(x_bac + 350, size.y * 0.2 + PAR_PAGE * 70 + 6)
	_btn_chassis.position = Vector2(size.x * 0.04, size.y * 0.08)
	_btn_ok.position = Vector2(size.x - 290, size.y - 84)
	_btn_annuler.position = Vector2(size.x - 510, size.y - 84)
	queue_redraw()


# Recalcule l'aperçu dessiné après chaque changement
func _maj() -> void:
	var F := FormeAssemblage.forme(a)
	_apercu.ppm = clampf(96.0 / maxf(0.5, float(F.hauteur)), 10.0, 28.0)
	_apercu.configurer_d(F)
	_apercu.position = Vector2(size.x * 0.04, size.y * 0.97 - _apercu.size.y)
	_disposer()


func _process(delta: float) -> void:
	_msg_t = maxf(0.0, _msg_t - delta)
	var ap := Assemblage.apercu(a)
	_btn_ok.disabled = not ap.ok or m.stocks.metal < _cout_plaques() or (uid != 0 and a == m.trouver(uid).assemblage)
	var n := _libres().size()
	_btn_haut.disabled = _page <= 0
	_btn_bas.disabled = (_page + 1) * PAR_PAGE >= n
	_btn_moins.disabled = int(a.get("plaques", 0)) <= 0
	queue_redraw()


func _cellule(doigt: Vector2, id: String) -> Vector2i:
	var e: Array = Assemblage.piece(id).emprise
	return Vector2i(int(floor((doigt.x - _grille.position.x) / _cell - float(e[0]) * 0.5 + 0.5)),
		int(floor((_grille.end.y - doigt.y) / _cell - float(e[1]) * 0.5 + 0.5)))


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed and _drag == "":
			_doigt = e.position
			for c in _cartes:
				if c.rect.has_point(e.position):
					_drag = c.id
					return
			if _grille.has_point(e.position):   # reprendre une pièce posée
				var cell := Vector2i(int((e.position.x - _grille.position.x) / _cell), int((_grille.end.y - e.position.y) / _cell))
				var i := Assemblage.piece_en(a, cell)
				if i >= 0:
					_drag = String(a.pieces[i].piece)
					a = Assemblage.retirer(a, i)
					_maj()
		elif not e.pressed and _drag != "":
			_lacher(e.position)
		accept_event()
	elif e is InputEventMouseMotion and _drag != "":
		_doigt = e.position
		accept_event()


func _lacher(doigt: Vector2) -> void:
	var id := _drag
	_drag = ""
	if not _grille.grow(_cell * 2.0).has_point(doigt):
		_dire("%s retourne dans la réserve." % Assemblage.piece(id).nom)
		_maj()
		return
	var b := Assemblage.poser(a, id, _cellule(doigt, id))
	if b.is_empty():
		_dire("Pas de place ici pour %s." % Assemblage.piece(id).nom)
	else:
		a = b
		var so := get_node_or_null("/root/Son")
		if so:
			so.effet("sfx_atelier", -6.0)
	_maj()


func _terminer() -> void:
	if m.assembler(uid, a):
		ferme.emit(true)
		queue_free()
	else:
		_dire(m.journal[-1].txt if not m.journal.is_empty() else "Impossible d'assembler.")


func _dire(t: String) -> void:
	_message = t
	_msg_t = 3.5


func _rect_piece(id: String, pos: Vector2i) -> Rect2:
	var e: Array = Assemblage.piece(id).emprise
	return Rect2(Vector2(_grille.position.x + pos.x * _cell, _grille.end.y - (pos.y + int(e[1])) * _cell), Vector2(int(e[0]), int(e[1])) * _cell)


func _draw_piece(r: Rect2, id: String, alpha := 1.0, contour := Color(0, 0, 0, 0.6)) -> void:
	var f := Assemblage.piece(id)
	var c: Color = COULEURS.get(f.famille, Color("#555"))
	draw_rect(r, Color(c.r, c.g, c.b, 0.9 * alpha))
	draw_rect(r, contour, false, 2.0)
	var police := get_theme_default_font()
	if r.size.x > 60.0:
		draw_string(police, r.position + Vector2(5, minf(r.size.y - 5.0, 20.0)), String(f.nom), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 8.0, 15, Color(1, 1, 1, alpha))


func _draw() -> void:
	var police := get_theme_default_font()
	var g := Assemblage.taille_grille(a)
	draw_rect(Rect2(Vector2.ZERO, size), C_FOND)
	var titre: String = String(a.get("nom", "Assemblage")) if uid != 0 else "Nouveau véhicule : %s" % a.get("nom", "")
	draw_string(police, Vector2(size.x * 0.04, size.y * 0.075) + (Vector2(240, 0) if _btn_chassis.visible else Vector2.ZERO), titre, HORIZONTAL_ALIGNMENT_LEFT, size.x * 0.6, 38, C_TEXTE)
	var aide := "Glissez les pièces sur la grille. Touchez une pièce posée pour la reprendre." if _msg_t <= 0.0 else _message
	draw_string(police, Vector2(size.x * 0.04, size.y * 0.15), aide, HORIZONTAL_ALIGNMENT_LEFT, size.x * 0.9, 26, C_ACCENT if _msg_t > 0.0 else C_DISCRET)
	# Grille et sol
	for i in g.x + 1:
		var x := _grille.position.x + i * _cell
		draw_line(Vector2(x, _grille.position.y), Vector2(x, _grille.end.y), C_GRILLE, 1.0)
	for j in g.y + 1:
		var y := _grille.position.y + j * _cell
		draw_line(Vector2(_grille.position.x, y), Vector2(_grille.end.x, y), C_GRILLE, 1.0)
	draw_rect(_grille, C_CADRE, false, 2.0)
	draw_line(Vector2(_grille.position.x - 20, _grille.end.y), Vector2(_grille.end.x + 20, _grille.end.y), Color(0.55, 0.45, 0.3), 4.0)
	# Pièces posées
	for p in a.get("pieces", []):
		_draw_piece(_rect_piece(String(p.piece), Vector2i(int(p.pos[0]), int(p.pos[1]))), String(p.piece))
	# Pièce en main : fantôme à l'endroit où elle s'aimanterait
	if _drag != "":
		var b := Assemblage.poser(a, _drag, _cellule(_doigt, _drag))
		if not b.is_empty():
			var q: Dictionary = b.pieces.back()
			_draw_piece(_rect_piece(_drag, Vector2i(int(q.pos[0]), int(q.pos[1]))), _drag, 0.55, C_VERT)
		var e: Array = Assemblage.piece(_drag).emprise
		_draw_piece(Rect2(_doigt - Vector2(int(e[0]), int(e[1])) * _cell * 0.5, Vector2(int(e[0]), int(e[1])) * _cell), _drag, 0.85, C_ACCENT)
	# Réserve
	var x_bac := size.x * 0.66
	var libres := _libres()
	draw_string(police, Vector2(x_bac, size.y * 0.2 - 14), "Réserve (%d)" % libres.size() if not libres.is_empty() else "Réserve vide", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, C_TEXTE)
	_cartes.clear()
	for k in range(_page * PAR_PAGE, mini(libres.size(), (_page + 1) * PAR_PAGE)):
		var it: Dictionary = libres[k]
		var r := Rect2(Vector2(x_bac, size.y * 0.2 + (k - _page * PAR_PAGE) * 70), Vector2(size.x - x_bac - size.x * 0.04, 62))
		_cartes.append({"rect": r, "id": it.id, "n": it.n})
		var c: Color = COULEURS.get(it.fiche.famille, Color("#555"))
		draw_rect(r, Color(c.r, c.g, c.b, 0.35))
		draw_rect(r, C_ACCENT if it.id == _drag else Color(1, 1, 1, 0.25), false, 2.0)
		draw_string(police, r.position + Vector2(14, 28), "%s%s" % [it.fiche.nom, " ×%d" % it.n if it.n > 1 else ""], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 28, 22, C_TEXTE)
		draw_string(police, r.position + Vector2(14, 52), "%d × %d cases · %d kg" % [int(it.fiche.emprise[0]), int(it.fiche.emprise[1]), int(it.fiche.get("poids_kg", 0))], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, C_DISCRET)
	# Plaques, validation et statistiques
	var y0 := size.y * 0.2 + PAR_PAGE * 70 + 92.0
	var pl := int(a.get("plaques", 0))
	draw_string(police, Vector2(x_bac, y0), "Plaques de blindage : %d%s · métal : %d" % [pl, " (−%d métal)" % int(_cout_plaques()) if _cout_plaques() > 0.0 else "", int(m.stocks.metal)], HORIZONTAL_ALIGNMENT_LEFT, size.x - x_bac - 20, 20, C_DISCRET)
	var ap := Assemblage.apercu(a)
	if ap.ok:
		var s: Dictionary = ap.stats
		draw_string(police, Vector2(x_bac, y0 + 30), "Ça roule : %.1f m/s · %d place%s · %s · blindage %d · %d kg" % [s.vitesse, s.equipage, "s" if s.equipage > 1 else "",
			"sans arme" if s.armes.is_empty() else "%d arme%s" % [s.armes.size(), "s" if s.armes.size() > 1 else ""], int(s.blindage), int(s.poids_kg)], HORIZONTAL_ALIGNMENT_LEFT, size.x - x_bac - 20, 20, C_VERT)
	else:
		for i in mini(2, ap.erreurs.size()):
			draw_string(police, Vector2(x_bac, y0 + 30 + i * 26), "• " + String(ap.erreurs[i].texte), HORIZONTAL_ALIGNMENT_LEFT, size.x - x_bac - 20, 20, C_ROUGE)
