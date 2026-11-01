# Grille de construction libre (DEC-043), accessible à tout moment pour chaque véhicule (le jeu est en pause).
# Trois étapes : 1. peindre le châssis case par case (acier ou blindage), 2. poser les essieux dessous et choisir
# leurs roues (trois tailles) ou chenilles, 3. poser moteurs, cabines et armes (mitrailleuse, canon, mortier).
# Tout est compatible ; l'écran montre en direct le sol, le centre de gravité, la charge de chaque essieu et les défauts.
# Aucune règle ici : tout passe par ConstructionLibre et CombatModele (grille_de, palette_grille, construire_grille).
class_name EditeurGrille
extends Control

signal ferme(construit: bool)

const C_FOND := Color(0.06, 0.065, 0.07)
const C_GRILLE := Color(1, 1, 1, 0.06)
const C_CADRE := Color(1, 1, 1, 0.22)
const C_ACCENT := Color("#E8A33D")
const C_TEXTE := Color("#F2EEE6")
const C_DISCRET := Color("#A8A196")
const C_VERT := Color("#5FB36B")
const C_ROUGE := Color("#D9674A")
const C_SOL := Color(0.55, 0.45, 0.3)
const COULEURS := {"acier": Color("#77736A"), "blindage": Color("#4C5236"), "origine": Color("#6E6A5C"),
	"moteur": Color("#A8552F"), "cabine": Color("#5E6238"), "arme": Color("#9A2F2F")}
const ESSIEUX := ["essieu_leger", "essieu_lourd", "essieu_char"]
const TRAINS := ["roue_petite", "roue_moyenne", "roue_grande", "chenille"]
const PAR_PAGE := 6

var m                       # CombatModele
var uid := 0                # véhicule modifié (0 = véhicule neuf)
var a := {}                 # grille en cours
var etape := 1
var pinceau := "acier"      # acier | blindage | "" (gomme)
var essieu_choisi := "essieu_leger"
var train_choisi := "roue_moyenne"
var _palette: Array = []    # [{id, n}] ; n = -1 : sans limite
var _sel := ""              # pièce choisie (étape 3)
var _appui := false
var _derniere := Vector2i(-99, -99)
var _doigt := Vector2.ZERO
var _grille := Rect2()
var _cell := 18.0
var _page := 0
var _cartes: Array = []
var _an := {}
var _message := ""
var _msg_t := 0.0
var _boutons_etape: Array = []
var _boutons_outils: Array = []
var _btn_ok: Button
var _btn_annuler: Button
var _btn_haut: Button
var _btn_bas: Button
var _apercu: VehiculeDessin


func ouvrir(modele, vehicule_uid: int) -> void:
	m = modele
	uid = vehicule_uid
	a = m.grille_de(uid)
	_palette = m.palette_grille(uid)


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	_apercu = VehiculeDessin.new()
	_apercu.equipage = true
	add_child(_apercu)
	for i in 3:
		var b := _bouton(["1 · Châssis", "2 · Essieux", "3 · Pièces"][i], func(): _etape(i + 1), 190)
		_boutons_etape.append(b)
	_btn_ok = _bouton("Construire", _terminer, 230)
	_btn_annuler = _bouton("Annuler", func():
		ferme.emit(false)
		queue_free(), 180)
	_btn_haut = _bouton("▲", func(): _page = maxi(0, _page - 1), 80)
	_btn_bas = _bouton("▼", func(): _page += 1, 80)
	_etape(1)
	resized.connect(_disposer)


func _bouton(texte: String, action: Callable, largeur: float) -> Button:
	var b := Button.new()
	b.text = texte
	b.custom_minimum_size = Vector2(largeur, 58)
	b.pressed.connect(action)
	add_child(b)
	return b


# Outils de l'étape : pinceaux, essieux et trains, ou rien (les pièces sont des cartes dessinées)
func _etape(n: int) -> void:
	etape = n
	for b in _boutons_outils:
		b.queue_free()
	_boutons_outils.clear()
	match n:
		1:
			for p in [["Acier", "acier"], ["Blindage", "blindage"], ["Gomme", ""]]:
				var sorte: String = p[1]
				_boutons_outils.append(_bouton(p[0], func(): pinceau = sorte, 150))
			_boutons_outils.append(_bouton("+ plaque", func(): _plaque(1), 150))
			_boutons_outils.append(_bouton("− plaque", func(): _plaque(-1), 150))
		2:
			for id in ESSIEUX:
				_boutons_outils.append(_bouton(Assemblage.piece(id).nom.replace("Essieu ", "Ess. "), func(): essieu_choisi = id, 150))
			for id in TRAINS:
				_boutons_outils.append(_bouton(String(Assemblage.piece(id).nom).get_slice(" (", 0), func(): train_choisi = id, 150))
	_maj()


func _plaque(d: int) -> void:
	a.plaques = maxi(0, int(a.get("plaques", 0)) + d)
	_maj()


func _disposer() -> void:
	var g := ConstructionLibre.taille()
	var zone := Vector2(size.x * 0.62, size.y * 0.52)
	_cell = floorf(minf(zone.x / g.x, zone.y / g.y))
	_grille = Rect2(Vector2(size.x * 0.02, size.y * 0.13), Vector2(g) * _cell)
	for i in _boutons_etape.size():
		_boutons_etape[i].position = Vector2(size.x * 0.40 + i * 200, 8)
		_boutons_etape[i].modulate = C_ACCENT if etape == i + 1 else Color.WHITE
	var x_bac := size.x * 0.66
	for i in _boutons_outils.size():
		var col := i % 3 if etape == 1 or i < 3 else (i - 3) % 2
		var lig := i / 3 if etape == 1 or i < 3 else 1 + (i - 3) / 2
		_boutons_outils[i].position = Vector2(x_bac + col * 158, size.y * 0.15 + lig * 66)
		_boutons_outils[i].custom_minimum_size.x = 150
	_btn_haut.visible = etape == 3
	_btn_bas.visible = etape == 3
	_btn_haut.position = Vector2(x_bac, size.y * 0.15 + PAR_PAGE * 52 + 4)
	_btn_bas.position = Vector2(x_bac + 90, size.y * 0.15 + PAR_PAGE * 52 + 4)
	_btn_ok.position = Vector2(size.x - 250, size.y - 72)
	_btn_annuler.position = Vector2(size.x - 440, size.y - 72)
	queue_redraw()


# Recalcule l'analyse et l'aperçu dessiné après chaque changement
func _maj() -> void:
	_an = ConstructionLibre.analyser(a)
	if not a.cases.is_empty():
		var F := ConstructionLibre.forme(a)
		_apercu.ppm = clampf(minf(size.y * 0.24 / maxf(0.5, float(F.hauteur)), size.x * 0.55 / maxf(0.5, float(F.longueur))), 8.0, 70.0)
		_apercu.configurer_d(F)
		_apercu.visible = true
	else:
		_apercu.visible = false
	_disposer()
	_apercu.position = Vector2(size.x * 0.03, size.y * 0.985 - _apercu.size.y)


func _process(delta: float) -> void:
	_msg_t = maxf(0.0, _msg_t - delta)
	_btn_ok.disabled = not _an.get("ok", false) or (not m.bac_a_sable and m.stocks.metal < m.cout_grille(uid, a))
	_btn_haut.disabled = _page <= 0
	_btn_bas.disabled = (_page + 1) * PAR_PAGE >= _palette.size()
	queue_redraw()


func _restant(id: String, n: int) -> int:
	if n < 0:
		return -1
	return n - a.pieces.filter(func(p): return p.piece == id).size()


func _case(pos: Vector2) -> Vector2i:
	return Vector2i(int(floor((pos.x - _grille.position.x) / _cell)), int(floor((_grille.end.y - pos.y) / _cell)))


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		_doigt = e.position
		if e.pressed:
			_appui = true
			_derniere = Vector2i(-99, -99)
			if etape == 3:
				for c in _cartes:
					if c.rect.has_point(e.position) and c.reste != 0:
						_sel = c.id
						accept_event()
						return
			if _grille.has_point(e.position):
				_toucher(_case(e.position), true)
		else:
			if etape == 3 and _sel != "" and _grille.grow(_cell).has_point(e.position) and _derniere == Vector2i(-99, -99):
				_poser_piece(e.position)
			_appui = false
		accept_event()
	elif e is InputEventMouseMotion:
		_doigt = e.position
		if _appui and etape == 1 and _grille.has_point(e.position):
			_toucher(_case(e.position), false)
		accept_event()


func _toucher(cell: Vector2i, premier: bool) -> void:
	if cell == _derniere:
		return
	match etape:
		1:
			_derniere = cell
			a = ConstructionLibre.peindre(a, cell, pinceau)
			_maj()
		2:
			if not premier:
				return
			_derniere = cell
			var ex := ConstructionLibre.essieu_en(a, cell.x)
			if not ex.is_empty() and ex.piece == essieu_choisi and ex.train == train_choisi:
				a = ConstructionLibre.retirer_essieu(a, cell.x)
			else:
				var b := ConstructionLibre.poser_essieu(a, cell.x, essieu_choisi, train_choisi)
				if b.is_empty():
					_dire("Peignez d'abord une case de châssis dans cette colonne.")
				else:
					a = b
					_son()
			_maj()
		3:
			if not premier:
				return
			var i := ConstructionLibre.piece_en(a, cell)
			if i >= 0:   # toucher une pièce posée la reprend
				_derniere = cell
				_sel = String(a.pieces[i].piece)
				a = ConstructionLibre.retirer(a, i)
				_maj()


func _cible(pos: Vector2, id: String) -> Vector2i:
	var e: Array = Assemblage.piece(id).emprise
	return Vector2i(int(floor((pos.x - _grille.position.x) / _cell - float(e[0]) * 0.5 + 0.5)), int(floor((_grille.end.y - pos.y) / _cell - float(e[1]) * 0.5 + 0.5)))


func _poser_piece(pos: Vector2) -> void:
	var reste := 0
	for c in _palette:
		if c.id == _sel:
			reste = _restant(c.id, int(c.n))
	if reste == 0:
		_dire("Plus de %s en réserve." % Assemblage.piece(_sel).nom)
		return
	var b := ConstructionLibre.poser(a, _sel, _cible(pos, _sel))
	if b.is_empty():
		_dire("%s doit reposer sur le châssis ou une autre pièce, sans chevaucher." % Assemblage.piece(_sel).nom)
	else:
		a = b
		_son()
		_maj()


func _son() -> void:
	var so := get_node_or_null("/root/Son")
	if so:
		so.effet("sfx_atelier", -6.0)


func _terminer() -> void:
	if m.construire_grille(uid, a):
		ferme.emit(true)
		queue_free()
	else:
		_dire(m.journal[-1].txt if not m.journal.is_empty() else "Impossible de construire.")


func _dire(t: String) -> void:
	_message = t
	_msg_t = 3.5


# --- Dessin ------------------------------------------------------------------------------------
func _px(x: float, y: float) -> Vector2:   # cellules -> écran
	return Vector2(_grille.position.x + x * _cell, _grille.end.y - y * _cell)


func _draw() -> void:
	var police := get_theme_default_font()
	var g := ConstructionLibre.taille()
	draw_rect(Rect2(Vector2.ZERO, size), C_FOND)
	var titre := String(a.get("nom", "Véhicule")) + ("  ·  bac à sable" if m.bac_a_sable else "")
	draw_string(police, Vector2(size.x * 0.02, 46), titre, HORIZONTAL_ALIGNMENT_LEFT, size.x * 0.37, 32, C_TEXTE)
	var aides := ["Peignez le châssis au doigt. Acier : léger ; blindage : lourd mais protège.",
		"Touchez une colonne : l'essieu se fixe sous la case la plus basse. Retouchez pour l'enlever.",
		"Choisissez une pièce puis touchez la grille. Touchez une pièce posée pour la reprendre."]
	draw_string(police, Vector2(size.x * 0.02, size.y * 0.115), _message if _msg_t > 0.0 else aides[etape - 1], HORIZONTAL_ALIGNMENT_LEFT, size.x * 0.62, 20, C_ACCENT if _msg_t > 0.0 else C_DISCRET)
	for i in g.x + 1:
		draw_line(_px(i, 0), _px(i, g.y), C_GRILLE, 1.0)
	for j in g.y + 1:
		draw_line(_px(0, j), _px(g.x, j), C_GRILLE, 1.0)
	draw_rect(_grille, C_CADRE, false, 2.0)
	var det: Dictionary = _an.get("detail", {})
	# Sol calculé : le point le plus bas, roue ou caisse
	if det.has("sol"):
		draw_line(_px(-0.5, det.sol), _px(g.x + 0.5, det.sol), C_SOL, 3.0)
	# Châssis
	for c in a.get("cases", []):
		var r := Rect2(_px(int(c[0]), int(c[1]) + 1), Vector2(_cell, _cell))
		draw_rect(r.grow(-1.0), COULEURS.get(String(c[2]), COULEURS.acier))
	# Essieux et trains, à leur vraie hauteur ; charge sous chaque roue
	var details: Array = det.get("essieux", [])
	for e in a.get("essieux", []):
		var x := int(e.x)
		var y := float(ConstructionLibre.y_essieu(a, x))
		var ft := Assemblage.piece(String(e.train))
		var rr := float(ft.diametre_cases) * 0.5 * _cell
		var centre := _px(x + 0.5, y)
		var info := {}
		for d in details:
			if d.x == x:
				info = d
		var porte: bool = info.get("touche", true)
		var col := Color("#3E3C37") if porte else Color(0.35, 0.2, 0.2)
		if ft.get("type", "") == "chenilles":
			draw_rect(Rect2(centre - Vector2(rr, rr), Vector2(rr, rr) * 2.0), col)
		else:
			draw_circle(centre, rr, col)
		draw_arc(centre, rr, 0, TAU, 20, Color(0, 0, 0, 0.7), 2.0)
		draw_circle(centre, maxf(2.0, _cell * 0.18), Color("#9A9890") if e.piece == "essieu_leger" else (Color("#C9C6BC") if e.piece == "essieu_lourd" else Color("#E8E4D8")))
		if info.has("charge"):
			var sur: bool = float(info.charge) > float(info.capacite)
			draw_string(police, centre + Vector2(-40, rr + 18), "%d/%d kg" % [int(info.charge), int(info.capacite)], HORIZONTAL_ALIGNMENT_CENTER, 80, 14, C_ROUGE if sur else C_DISCRET)
		elif not porte:
			draw_string(police, centre + Vector2(-40, rr + 18), "en l'air", HORIZONTAL_ALIGNMENT_CENTER, 80, 14, C_ROUGE)
	# Pièces
	for p in a.get("pieces", []):
		var f := Assemblage.piece(String(p.piece))
		var e: Array = f.emprise
		var r := Rect2(_px(int(p.pos[0]), int(p.pos[1]) + int(e[1])), Vector2(int(e[0]), int(e[1])) * _cell)
		draw_rect(r.grow(-1.0), COULEURS.get(f.famille, Color("#555")))
		draw_rect(r, Color(0, 0, 0, 0.6), false, 2.0)
		if r.size.x > 50.0:
			draw_string(police, r.position + Vector2(4, minf(r.size.y - 4.0, 17.0)), String(f.nom), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 6.0, 13, C_TEXTE)
	# Centre de gravité
	if det.has("cg"):
		var cg := _px(det.cg.x, det.cg.y)
		draw_circle(cg, 7.0, Color(1, 1, 1, 0.9))
		draw_line(cg - Vector2(10, 0), cg + Vector2(10, 0), Color.BLACK, 2.0)
		draw_line(cg - Vector2(0, 10), cg + Vector2(0, 10), Color.BLACK, 2.0)
	# Pièce choisie : fantôme là où elle se poserait
	if etape == 3 and _sel != "" and _grille.has_point(_doigt):
		var b := ConstructionLibre.poser(a, _sel, _cible(_doigt, _sel))
		if not b.is_empty():
			var q: Dictionary = b.pieces.back()
			var e: Array = Assemblage.piece(_sel).emprise
			draw_rect(Rect2(_px(int(q.pos[0]), int(q.pos[1]) + int(e[1])), Vector2(int(e[0]), int(e[1])) * _cell), Color(C_VERT, 0.45))
	_draw_panneau(police)


func _draw_panneau(police: Font) -> void:
	var x_bac := size.x * 0.66
	var lw := size.x - x_bac - size.x * 0.02
	var y := size.y * 0.15
	match etape:
		1:
			var nom: String = {"acier": "Acier", "blindage": "Blindage", "": "Gomme"}[pinceau]
			draw_string(police, Vector2(x_bac, y - 12), "Pinceau : %s · plaques : %d" % [nom, int(a.get("plaques", 0))], HORIZONTAL_ALIGNMENT_LEFT, lw, 20, C_TEXTE)
			y += 140
		2:
			var fe := Assemblage.piece(essieu_choisi)
			var ft := Assemblage.piece(train_choisi)
			draw_string(police, Vector2(x_bac, y - 12), "%s (%d kg max) + %s (%d kg max)" % [fe.nom, int(fe.charge_kg), String(ft.nom).get_slice(" (", 0), int(ft.charge_kg)], HORIZONTAL_ALIGNMENT_LEFT, lw, 18, C_TEXTE)
			y += 210
		3:
			_cartes.clear()
			draw_string(police, Vector2(x_bac, y - 12), "Pièces%s" % (" (sans limite)" if m.bac_a_sable else ""), HORIZONTAL_ALIGNMENT_LEFT, lw, 20, C_TEXTE)
			for k in range(_page * PAR_PAGE, mini(_palette.size(), (_page + 1) * PAR_PAGE)):
				var it: Dictionary = _palette[k]
				var f := Assemblage.piece(it.id)
				var reste := _restant(it.id, int(it.n))
				var r := Rect2(Vector2(x_bac, y + (k - _page * PAR_PAGE) * 52), Vector2(lw, 46))
				_cartes.append({"rect": r, "id": it.id, "reste": reste})
				var c: Color = COULEURS.get(f.famille, Color("#555"))
				draw_rect(r, Color(c.r, c.g, c.b, 0.35 if reste != 0 else 0.12))
				draw_rect(r, C_ACCENT if it.id == _sel else Color(1, 1, 1, 0.2), false, 2.0)
				var detail := ""
				match f.famille:
					"moteur": detail = "%d ch" % int(f.puissance_ch)
					"cabine": detail = "%d place%s%s" % [int(f.sieges), "s" if int(f.sieges) > 1 else "", ", ouverte" if f.ouvert else ""]
					"arme": detail = String(CombatModele.donnees().armes[f.arme].nom)
				draw_string(police, r.position + Vector2(10, 20), "%s%s" % [f.nom, "" if reste < 0 else " ×%d" % reste], HORIZONTAL_ALIGNMENT_LEFT, lw - 20, 17, C_TEXTE if reste != 0 else C_DISCRET)
				draw_string(police, r.position + Vector2(10, 40), "%s · %d×%d cases · %d kg" % [detail, int(f.emprise[0]), int(f.emprise[1]), int(f.get("poids_kg", 0))], HORIZONTAL_ALIGNMENT_LEFT, lw - 20, 14, C_DISCRET)
			y += PAR_PAGE * 52 + 92
	# Bilan : ça roule ? et tous les défauts
	if not _an.get("ok", false):
		for d in _an.get("erreurs", []):
			draw_string(police, Vector2(x_bac, y), "✕ " + String(d.texte), HORIZONTAL_ALIGNMENT_LEFT, lw, 17, C_ROUGE)
			y += 22
		return
	var s: Dictionary = _an.stats
	var det: Dictionary = _an.detail
	var roule := float(s.vitesse) > 0.0
	draw_string(police, Vector2(x_bac, y), ("Roule : %.1f m/s" % s.vitesse) if roule else "Ne roule pas", HORIZONTAL_ALIGNMENT_LEFT, lw, 20, C_VERT if roule else C_ROUGE)
	y += 22
	draw_string(police, Vector2(x_bac, y), "%d kg · %.0f ch/t · blindage %d · %d place%s · %d arme%s" % [int(s.poids_kg), det.ch_t, int(s.blindage),
		int(s.equipage), "s" if int(s.equipage) > 1 else "", s.armes.size(), "s" if s.armes.size() > 1 else ""], HORIZONTAL_ALIGNMENT_LEFT, lw, 15, C_DISCRET)
	y += 20
	var cout: float = m.cout_grille(uid, a)
	if cout > 0.0:
		draw_string(police, Vector2(x_bac, y), "Coût : %d métal (stock %d)" % [int(ceil(cout)), int(m.stocks.metal)], HORIZONTAL_ALIGNMENT_LEFT, lw, 15, C_ACCENT)
		y += 20
	for d in _an.defauts.slice(0, 5):
		draw_string(police, Vector2(x_bac, y), "• " + String(d.texte), HORIZONTAL_ALIGNMENT_LEFT, lw, 15, C_ROUGE if d.grave else C_ACCENT)
		y += 19
