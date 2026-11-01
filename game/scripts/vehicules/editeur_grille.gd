# Grille de construction libre (DEC-043), refaite pour l'iPhone (DEC-056 à DEC-058), puis en icônes (DEC-080) :
# - grille la plus grande possible, peu de texte ;
# - barre d'icônes à droite : coche (construire), croix (quitter), une icône par catégorie ;
# - la catégorie choisie ouvre un tiroir simplifié : vignettes des pièces (miniature du vrai dessin), listes courtes ;
# - toute pièce posée se reprend au doigt pour la déplacer, ou se lâche hors de la grille pour la retirer ;
# - tôles tracées d'un coin à l'autre (glisser), à l'angle voulu ; peinture de bande ; remorques ; véhicules du jeu (bac à sable) ;
# - vue de la grille : pincer pour zoomer ou dézoomer, bouton « déplacer » (flèche à quatre têtes) pour faire glisser la vue, bouton « cadrer » (DEC-081) ;
# - tiroir : chaque pièce est dessinée à l'échelle réduite dans une vignette à sa proportion, vignettes rangées sans chevauchement (DEC-081) ;
# - roues et suspensions sont des pièces glissées : elles s'aimantent sur l'essieu ou le pont rigide le plus proche (DEC-081).
# Aucune règle ici : tout passe par ConstructionLibre et CombatModele (grille_de, palette_grille, construire_grille).
class_name EditeurGrille
extends Control

signal ferme(construit: bool)

const C_FOND := Color(0.06, 0.065, 0.07)
const C_ZONE := Color(0.09, 0.095, 0.1)
const FOND_GRILLE: Texture2D = preload("res://assets/decor/fond_grille.png")
const C_GRILLE := Color(1, 1, 1, 0.07)
const C_CADRE := Color(1, 1, 1, 0.22)
const C_ACCENT := Color("#E8A33D")
const C_TEXTE := Color("#F2EEE6")
const C_DISCRET := Color("#A8A196")
const C_VERT := Color("#5FB36B")
const C_ROUGE := Color("#D9674A")
const C_SOL := Color(0.55, 0.45, 0.3)
const C_TUILE := Color(0.12, 0.115, 0.11, 0.82)
# Barre d'icônes : deux actions, puis les catégories dans l'ordre de construction
const ACTIONS := ["valider", "quitter"]
const ONGLETS := [["chassis", "Châssis"], ["essieux", "Essieux"], ["roues", "Roues"], ["suspension", "Suspension"], ["moteur", "Moteurs"],
	["poste", "Postes"], ["coque", "Carrosserie"], ["toles", "Tôles"], ["arme", "Armes"], ["equipement", "Options"], ["equipage", "Équipage"],
	["peinture", "Peinture"], ["vehicule", "Véhicule"], ["plans", "Plans"], ["vehicules", "Véhicules"]]
const AIDES := {"chassis": "Glissez d'un coin à l'autre", "essieux": "Touchez une colonne", "roues": "Glissez vers un essieu",
	"suspension": "Glissez sur un pont rigide", "moteur": "Glissez sur la grille", "poste": "Glissez sur la grille",
	"coque": "Glissez ; se superposent", "toles": "Glissez d'un point à un autre", "arme": "Glissez sur la grille",
	"equipement": "Collées à l'extérieur", "equipage": "Touchez un siège", "peinture": "Ton de tout le véhicule",
	"vehicule": "Glissez le véhicule entier", "plans": "Enregistrer ou charger", "vehicules": "Partir d'un véhicule"}
# Peintures de bande (DEC-080) : un ton par faction, à régler
const PEINTURES := [["", "Sans"], ["#5E6238", "Kaki"], ["#B0623A", "Rouille"], ["#3A3A38", "Suie"], ["#C9A23A", "Jaune"],
	["#6A86A8", "Bleu horizon"], ["#8A3030", "Sang"], ["#D8D4C8", "Hiver"], ["#4E6E58", "Vert-de-gris"]]
const COULEURS := {"moteur": Color("#A8552F"), "radiateur": Color("#6A6A60"), "cabine": Color("#5E6238"), "poste": Color("#6E5A3A"), "arme": Color("#9A2F2F"),
	"equipement": Color("#8A7A3A"), "coque": Color("#7A6A55"), "greffe": Color("#6A5A4A")}
# Essieux, roues et liaisons : lus dans le catalogue par famille (ajouter un modèle = une entrée dans pieces.json)
static func _famille(fam: String) -> Array:
	var res: Array = Assemblage.catalogue().pieces.keys().filter(func(id): return Assemblage.piece(id).get("famille", "") == fam and not Assemblage.piece(id).get("retire", false))
	res.sort_custom(func(p, q): return float(Assemblage.piece(p).get("charge_kg", 0)) < float(Assemblage.piece(q).get("charge_kg", 0)))
	return res
const NOMS_ROLES := {"conducteur": "Conducteur", "tireur": "Tireur", "chargeur": "Chargeur", "chef": "Chef de char",
	"mecanicien": "Mécanicien", "infirmier": "Infirmier", "passager": "Passager"}
const AIDE_ROLES := {"conducteur": "obligatoire", "tireur": "sert une arme", "chargeur": "recharge plus vite", "chef": "précision +10 %",
	"mecanicien": "répare plus vite", "infirmier": "soigne", "passager": "aucun rôle"}
const BROUILLON := "user://grille_brouillon.json"
const DECALAGE_DOIGT := 1.6   # la pièce glissée flotte au-dessus du doigt (en cases) pour rester visible
const ZOOM_MIN := 0.4         # vue de la grille : taille d'une case, de 0,4 à 3,5 fois le cadrage de base
const ZOOM_MAX := 3.5
const RAYON_AIMANT := 3.0     # roues et suspensions : distance (en cases) à laquelle une pièce s'aimante sur son essieu ou son pont
const LABEL_H := 24.0         # tiroir : hauteur du titre sous chaque vignette
const ECART := 8.0            # tiroir : écart entre vignettes

var m                       # CombatModele
var uid := 0                # véhicule modifié (0 = véhicule neuf)
var a := {}                 # grille en cours
var onglet := "chassis"
var outil := {"chassis": "acier", "essieux": "essieu_leger", "roues": "roue_moyenne", "suspension": "liaison_lames"}
var _palette: Array = []    # [{id, n}] ; n = -1 : sans limite
var _glisse := ""           # pièce tenue au doigt
var _miroir := false        # coque retournée (avant vers l'arrière), DEC-067
var _scie := ""             # "" | "v" | "h" : la scie coupe la coque touchée (DEC-072)
var _extra := {}            # morceau scié tenu au doigt : coupe, emprise, lot
var _essieu_tenu := {}      # essieu repris au doigt : lâché hors de la grille, il est retiré (DEC-076)
var _ecorche := false       # vue écorchée forcée dans l'onglet Carrosserie
var _suppr_plans := false   # onglet Plans : toucher un plan le supprime
var _rect0 := Vector2i(-99, -99)   # coin de départ du rectangle de châssis
var _rect1 := Vector2i(-99, -99)
var _depl := false   # véhicule entier tenu au doigt (DEC-082)
var _depl0 := Vector2i.ZERO
var _depl_b := {}
var _tole0 := Vector2i(-99, -99)   # tôle en cours de tracé (coins de cases)
var _tole1 := Vector2i(-99, -99)
var _appui := false
var _doigt := Vector2.ZERO
var _vue := Rect2i(8, 0, 24, 10)   # fenêtre de cadrage de base (en cases) : le véhicule et une marge
var _zone := Rect2()        # fenêtre de la grille à l'écran : tout ce qui dépasse est coupé
var _cell := 40.0           # côté d'une case à l'écran (px), zoom compris
var _cell0 := 40.0          # côté d'une case au cadrage de base
var _ox := 0.0              # écran : bord gauche de la colonne 0
var _oy := 0.0              # écran : ligne du sol (bas de la rangée 0)
var _cam_manuelle := false  # le joueur a zoomé ou déplacé la vue : on ne la recadre plus tout seul
var _deplacer := false      # outil « déplacer » : un doigt fait glisser la vue
var _pan_actif := false
var _pan_depart := Vector2.ZERO
var _pan_o := Vector2.ZERO
var _toques := {}           # doigts posés : index -> position (pincement)
var _pince := false
var _pince_d0 := 1.0
var _pince_cell := 40.0
var _pince_monde := Vector2.ZERO
var _bloque := false        # geste annulé par un pincement : la souris émulée est ignorée jusqu'au prochain appui
var _avant := {}            # grille au début du geste en cours (annulation si un deuxième doigt se pose)
var _lia_prise := false     # la suspension tenue vient de la grille (hors de la grille, elle est retirée)
var _rev := 0               # change à chaque modification de la grille
var _coins: Array = []      # coins où accrocher une tôle (mis en cache)
var _coins_rev := -1
var _rail := Rect2()        # barre d'icônes
var _tiroir := Rect2()      # tiroir de la catégorie
var _rect_nom := Rect2()
var _mg := {}
var _page := 0
var _cartes: Array = []     # [{rect, action, actif}] : tout ce qui se touche en dehors de la grille
var _an := {}
var _message := ""
var _msg_t := 0.0
var _confirmer := false     # armes sans tireur : deuxième appui sur la coche pour confirmer
var _apercu: VehiculeDessin
var _monde: Control         # fenêtre de la grille (coupe ce qui dépasse) : quadrillage, véhicule, repères
var _surcouche: Control     # repères posés sur le véhicule, dans la fenêtre
var _dessus: Control        # interface : nom, barre d'icônes, tiroir, bilan, boutons de vue
static var _minis := {}     # id -> formes de la pièce seule (miniatures du tiroir)


func ouvrir(modele, vehicule_uid: int) -> void:
	m = modele
	uid = vehicule_uid
	a = m.grille_de(uid)
	_palette = m.palette_grille(uid)
	var b := _lire_brouillon()
	if not b.is_empty():
		a = b
		_dire("Brouillon repris.")


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:   # un doigt peut se perdre quand la page passe en arrière-plan
		_toques.clear()
		_pince = false


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	# Fenêtre de la grille : elle coupe ce qui dépasse quand on zoome (quadrillage, véhicule, repères)
	_monde = Control.new()
	_monde.clip_contents = true
	_monde.mouse_filter = MOUSE_FILTER_IGNORE
	_monde.draw.connect(_dessiner_grille)
	add_child(_monde)
	_apercu = VehiculeDessin.new()
	_apercu.equipage = true
	_apercu.plat = true   # l'aperçu reste droit même si le véhicule est penché (DEC-082)
	_apercu.mouse_filter = MOUSE_FILTER_IGNORE
	_monde.add_child(_apercu)
	_surcouche = Control.new()
	_surcouche.mouse_filter = MOUSE_FILTER_IGNORE
	_surcouche.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_surcouche.draw.connect(_dessiner_surcouche)
	_monde.add_child(_surcouche)
	_dessus = Control.new()
	_dessus.mouse_filter = MOUSE_FILTER_IGNORE
	_dessus.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_dessus.draw.connect(_dessiner_dessus)
	add_child(_dessus)
	resized.connect(func():   # écran retourné : on recadre
		_cam_manuelle = false
		_disposer())
	_maj(true)


func _choisir_onglet(id: String) -> void:
	onglet = id
	_scie = ""
	_page = 0
	_glisse = ""
	_suppr_plans = false
	_deplacer = false   # choisir une catégorie, c'est vouloir construire
	_disposer()


# --- Mise en page : barre d'icônes à droite, tiroir à sa gauche, la grille prend tout le reste -------
func _disposer() -> void:
	if size.x < 10.0:
		return
	_mg = ZonesSures.marges(size)
	var g: float = _mg.g
	var d: float = size.x - _mg.d
	var haut := 10.0 + float(_mg.h)
	var bas := size.y - float(_mg.b) - 6.0
	var n := ACTIONS.size() + ONGLETS.size()
	var rangs := int(ceil(n / 2.0))
	var ic := clampf(floorf((bas - haut - (rangs - 1) * 8.0) / rangs), 56.0, 92.0)
	_rail = Rect2(Vector2(d - 2.0 * ic - 8.0, haut), Vector2(2.0 * ic + 8.0, rangs * (ic + 8.0) - 8.0))
	var tw := clampf(size.x * 0.16, 280.0, 330.0)
	_tiroir = Rect2(Vector2(_rail.position.x - 12.0 - tw, haut), Vector2(tw, bas - haut))
	_rect_nom = Rect2(Vector2(g, haut), Vector2(minf(560.0, _tiroir.position.x - g - 20.0), 44.0))
	_zone = Rect2(Vector2(g, haut + 52.0), Vector2(_tiroir.position.x - 16.0 - g, bas - haut - 52.0 - 64.0))
	if _monde == null:
		return
	_monde.position = _zone.position
	_monde.size = _zone.size
	if _cam_manuelle:
		_cadrer_base()
		_borner_camera()
	else:
		_cadrer()
	_placer_apercu()
	queue_redraw()
	_monde.queue_redraw()
	_surcouche.queue_redraw()
	_dessus.queue_redraw()


# Taille d'une case au cadrage de base : la fenêtre `_vue` (le véhicule et une marge) remplit la zone
func _cadrer_base() -> void:
	var sous_sol := 2.2   # place pour les roues sous la ligne 0
	_cell0 = floorf(minf(_zone.size.x / float(_vue.size.x), _zone.size.y / (float(_vue.size.y) + sous_sol)))


# Cadrage de base : zoom 1, véhicule centré
func _cadrer() -> void:
	_cadrer_base()
	_cell = _cell0
	var sous_sol := 2.2
	var taille := Vector2(_vue.size) * _cell
	var coin := _zone.position + Vector2((_zone.size.x - taille.x) * 0.5, (_zone.size.y - taille.y - sous_sol * _cell) * 0.5)
	_ox = coin.x - float(_vue.position.x) * _cell
	_oy = coin.y + taille.y


# La grille reste toujours un peu visible : on ne peut pas la perdre hors de l'écran
func _borner_camera() -> void:
	var G := ConstructionLibre.taille()
	var marge := 90.0
	_cell = clampf(_cell, _cell0 * ZOOM_MIN, _cell0 * ZOOM_MAX)
	_ox = clampf(_ox, _zone.position.x + marge - float(G.x) * _cell, _zone.end.x - marge)
	_oy = clampf(_oy, _zone.position.y + marge, _zone.end.y - marge + float(G.y) * _cell)


func _rafraichir_camera() -> void:
	_zoomer_apercu()
	_monde.queue_redraw()
	_surcouche.queue_redraw()
	_dessus.queue_redraw()


func _recadrer() -> void:   # bouton « cadrer » : retour au cadrage de base
	_cam_manuelle = false
	_ajuster_vue()
	_disposer()


# Zoom autour d'un point de l'écran : le point reste sous le doigt
func _zoomer_autour(f: Vector2, k: float) -> void:
	var w := _mon(f)
	_cell = clampf(_cell * k, _cell0 * ZOOM_MIN, _cell0 * ZOOM_MAX)
	_ox = f.x - w.x * _cell
	_oy = f.y + w.y * _cell
	_cam_manuelle = true
	_borner_camera()
	_rafraichir_camera()


# Cases visibles dans la fenêtre (limitées à la grille)
func _cases_visibles() -> Rect2i:
	var G := ConstructionLibre.taille()
	var a0 := _mon(Vector2(_zone.position.x, _zone.end.y))
	var a1 := _mon(Vector2(_zone.end.x, _zone.position.y))
	var x0 := clampi(int(floor(a0.x)), 0, G.x)
	var x1 := clampi(int(ceil(a1.x)), 0, G.x)
	var y0 := clampi(int(floor(a0.y)), 0, G.y)
	var y1 := clampi(int(ceil(a1.y)), 0, G.y)
	return Rect2i(x0, y0, maxi(0, x1 - x0), maxi(0, y1 - y0))


# Fenêtre affichée : le véhicule et une marge autour, au moins `grille_vue_min` cases
func _ajuster_vue() -> void:
	var G := ConstructionLibre.taille()
	var mini_v: Array = ConstructionLibre.R().get("grille_vue_min", [24, 10])
	var x0 := G.x
	var x1 := 0
	var y1 := 0
	for c in a.get("cases", []):
		x0 = mini(x0, int(c[0]))
		x1 = maxi(x1, int(c[0]) + 1)
		y1 = maxi(y1, int(c[1]) + 1)
	for p in a.get("pieces", []):
		var e: Array = p.get("emprise", Assemblage.piece(String(p.piece)).emprise)
		x0 = mini(x0, int(p.pos[0]))
		x1 = maxi(x1, int(p.pos[0]) + int(e[0]))
		y1 = maxi(y1, int(p.pos[1]) + int(e[1]))
	for t in a.get("toles", []):
		x0 = mini(x0, mini(int(t[0]), int(t[2])))
		x1 = maxi(x1, maxi(int(t[0]), int(t[2])))
		y1 = maxi(y1, maxi(int(t[1]), int(t[3])))
	if x1 <= x0:
		x0 = G.x / 2
		x1 = x0
	var w := clampi(x1 - x0 + 4, int(mini_v[0]), G.x)
	var h := clampi(y1 + 3, int(mini_v[1]), G.y)
	var cx := (x0 + x1) / 2
	var gx := clampi(cx - w / 2, 0, G.x - w)
	_vue = Rect2i(gx, 0, w, h)


# --- Changements ------------------------------------------------------------------------------
func _maj(revoir_vue := false) -> void:
	if not a.get("nom_choisi", false):
		a.nom = ConstructionLibre.nom_propose(a)
	_an = ConstructionLibre.analyser(a)
	_confirmer = false
	_rev += 1
	if revoir_vue:
		_ajuster_vue()
	_ecrire_brouillon()
	_disposer()


func _placer_apercu(b := {}) -> void:
	var source: Dictionary = a if b.is_empty() else b
	if source.get("cases", []).is_empty():
		_apercu.visible = false
		return
	var F := ConstructionLibre.forme(source, _ecorche or not onglet in ["coque", "equipage", "peinture", "vehicules", "toles", "vehicule"])   # coques transparentes quand on règle la mécanique
	_apercu.ppm = _cell / ConstructionLibre.C
	_apercu.configurer_d(F)
	_apercu.visible = true
	_apercu.position = _px(float(F.x0), float(F.sol)) - _zone.position - Vector2(0, _apercu.size.y)   # l'aperçu vit dans la fenêtre


# Zoom ou déplacement de la vue : le dessin du véhicule suit sans être recalculé
func _zoomer_apercu() -> void:
	if _apercu == null or not _apercu.visible or _apercu.D.is_empty():
		return
	_apercu.ppm = _cell / ConstructionLibre.C
	_apercu.custom_minimum_size = Vector2(_apercu.D.longueur, _apercu.D.hauteur) * _apercu.ppm
	_apercu.size = _apercu.custom_minimum_size
	_apercu.position = _px(float(_apercu.D.x0), float(_apercu.D.sol)) - _zone.position - Vector2(0, _apercu.size.y)
	_apercu.queue_redraw()


func _process(delta: float) -> void:
	if m == null:
		return
	_msg_t = maxf(0.0, _msg_t - delta)
	_dessus.queue_redraw()
	_surcouche.queue_redraw()


func _peut_construire() -> bool:
	return _an.get("ok", false) and (m.bac_a_sable or m.stocks.metal >= m.cout_grille(uid, a))


func _restant(id: String, n: int) -> int:
	if n < 0:
		return -1
	return n - ConstructionLibre.utilisees(a, id)


func _mon(pos: Vector2) -> Vector2:   # écran -> cases (nombres décimaux)
	return Vector2((pos.x - _ox) / _cell, (_oy - pos.y) / _cell)


func _case(pos: Vector2) -> Vector2i:
	var q := _mon(pos)
	return Vector2i(int(floor(q.x)), int(floor(q.y)))


func _coin(pos: Vector2) -> Vector2i:   # coin de case le plus proche (tôles)
	var q := _mon(pos)
	return Vector2i(int(round(q.x)), int(round(q.y)))


func _px(x: float, y: float) -> Vector2:   # cases (absolues) -> écran
	return Vector2(_ox + x * _cell, _oy - y * _cell)


func _dans_grille(pos: Vector2) -> bool:
	return _zone.has_point(pos)


# --- Toucher ----------------------------------------------------------------------------------
func _gui_input(e: InputEvent) -> void:
	if e is InputEventMagnifyGesture:   # pavé tactile d'un ordinateur
		_zoomer_autour(e.position, e.factor)
		accept_event()
		return
	if e is InputEventMouseButton and (e.button_index == MOUSE_BUTTON_WHEEL_UP or e.button_index == MOUSE_BUTTON_WHEEL_DOWN):   # molette (ordinateur)
		if e.pressed and _zone.has_point(e.position):
			_zoomer_autour(e.position, 1.15 if e.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15)
		accept_event()
		return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		_doigt = e.position
		if e.pressed:
			if _pince:
				accept_event()
				return
			_bloque = false
			_appui = true
			for c in _cartes:
				if c.rect.has_point(e.position):
					if c.actif:
						c.action.call()
					accept_event()
					return
			if _deplacer and _zone.has_point(e.position):
				_pan_actif = true
				_pan_depart = e.position
				_pan_o = Vector2(_ox, _oy)
			elif _dans_grille(e.position):
				_avant = a.duplicate(true)
				_appuyer(_case(e.position))
		else:
			if not _bloque and not _pan_actif:
				_relacher(e.position)
			_pan_actif = false
			_appui = false
			_avant = {}
		accept_event()
	elif e is InputEventMouseMotion:
		_doigt = e.position
		if _pince or _bloque:
			accept_event()
			return
		if _pan_actif and _appui:
			_ox = _pan_o.x + (e.position.x - _pan_depart.x)
			_oy = _pan_o.y + (e.position.y - _pan_depart.y)
			_cam_manuelle = true
			_borner_camera()
			_rafraichir_camera()
			accept_event()
			return
		if _appui and onglet == "chassis" and _rect0.x > -99:
			var c := _case(e.position)
			_rect1 = Vector2i(clampi(c.x, 0, ConstructionLibre.taille().x - 1), clampi(c.y, 0, ConstructionLibre.taille().y - 1))
		if _appui and _tole0.x > -99:
			_tole1 = _coin(e.position)
		if _appui and _depl:
			var c2 := _case(e.position)
			var bd := ConstructionLibre.deplacer(_avant, c2.x - _depl0.x, c2.y - _depl0.y)
			if not bd.is_empty():
				_depl_b = bd
				_placer_apercu(bd)
		if _glisse != "":
			_placer_apercu(_candidat())
		accept_event()


# --- Pincement ------------------------------------------------------------------------------------
# Deux doigts zooment et déplacent la vue. Le premier doigt arrive aussi comme souris émulée (c'est lui qui construit) ;
# les doigts sont suivis ici, par _input, qui voit tous les événements tactiles quoi qu'en fasse l'interface.
func _input(e: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if e is InputEventScreenTouch:
		_toucher(make_input_local(e))
	elif e is InputEventScreenDrag:
		_glisser_doigt(make_input_local(e))


func _toucher(e: InputEvent) -> void:
	if e.pressed:
		_toques[e.index] = e.position
		if _toques.size() == 2 and not _pince:
			_debut_pince()
	else:
		_toques.erase(e.index)
		if _toques.size() < 2:
			_pince = false


func _glisser_doigt(e: InputEvent) -> void:
	if not _toques.has(e.index):
		return
	_toques[e.index] = e.position
	if _pince and _toques.size() >= 2:
		var ks := _toques.keys()
		var p0: Vector2 = _toques[ks[0]]
		var p1: Vector2 = _toques[ks[1]]
		var milieu := (p0 + p1) * 0.5
		_cell = clampf(_pince_cell * maxf(p0.distance_to(p1), 1.0) / _pince_d0, _cell0 * ZOOM_MIN, _cell0 * ZOOM_MAX)
		_ox = milieu.x - _pince_monde.x * _cell   # le point pincé reste sous les doigts : on zoome et on déplace à la fois
		_oy = milieu.y + _pince_monde.y * _cell
		_cam_manuelle = true
		_borner_camera()
		_rafraichir_camera()


func _debut_pince() -> void:
	_annuler_geste()   # le premier doigt n'était pas un geste de construction
	var ks := _toques.keys()
	var p0: Vector2 = _toques[ks[0]]
	var p1: Vector2 = _toques[ks[1]]
	_pince = true
	_bloque = true
	_pince_d0 = maxf(p0.distance_to(p1), 1.0)
	_pince_cell = _cell
	_pince_monde = _mon((p0 + p1) * 0.5)


# Ce que faisait le premier doigt est défait (pièce reprise remise, tracé abandonné)
func _annuler_geste() -> void:
	_depl = false
	_depl_b = {}
	_rect0 = Vector2i(-99, -99)
	_tole0 = Vector2i(-99, -99)
	_glisse = ""
	_extra = {}
	_essieu_tenu = {}
	_lia_prise = false
	_pan_actif = false
	if not _avant.is_empty() and _avant != a:
		a = _avant
		_maj()
	_avant = {}
	_placer_apercu()


func _appuyer(cell: Vector2i) -> void:
	if onglet == "vehicule":
		_depl = true
		_depl0 = cell
		_depl_b = {}
		return
	if onglet == "toles":
		_tole0 = _coin(_doigt)
		_tole1 = _tole0
		return
	# Une pièce posée se reprend au doigt depuis n'importe quelle catégorie (DEC-076, DEC-080) ; une coque seulement en Carrosserie
	if onglet != "coque" and onglet != "essieux":
		var ip := ConstructionLibre.piece_en(a, cell)
		if ip >= 0 and (onglet != "chassis" or not _est_coque(String(a.pieces[ip].piece))):
			_prendre(ip)
			return
	match onglet:
		"chassis":
			_rect0 = cell
			_rect1 = cell
		"essieux":
			var ex := ConstructionLibre.essieu_en(a, cell.x)
			if not ex.is_empty() and ex.piece == outil.essieux:   # même essieu : on le reprend au doigt (déplacer, ou glisser hors de la grille)
				_essieu_tenu = ex.duplicate()
				a = ConstructionLibre.retirer_essieu(a, cell.x)
				_maj()
				return
			var ip := ConstructionLibre.piece_en(a, cell)
			if ip >= 0:
				_prendre(ip)
				return
			var b := ConstructionLibre.poser_essieu(a, cell.x, outil.essieux, String(ex.get("train", "")), cell.y)
			if b.is_empty():
				_dire("Pas de châssis au-dessus.")
				return
			a = b
			if Assemblage.piece(outil.essieux).get("pont", false):
				_dire("Pont à %d cm sous le châssis : reliez-le (Suspension)." % (ConstructionLibre.ecart_pont(a, ConstructionLibre.essieu_en(a, cell.x)) * 25))
			_son()
			_maj()
		"roues":   # un simple toucher monte la roue sur l'essieu le plus proche (DEC-081)
			_monter_roue(_roue_cible(_doigt, outil.roues), outil.roues)
		"suspension":   # la liaison posée se reprend au doigt ; sinon on relie le pont touché avec la pièce choisie (DEC-081)
			var x_pont := _pont_cible(_doigt)
			if x_pont < 0:
				_dire("Posez d'abord un pont rigide en l'air (Essieux).")
				return
			var lid_actuel := String(ConstructionLibre.essieu_en(a, x_pont).get("liaison", ""))
			if lid_actuel != "":
				var bd := ConstructionLibre.relier(a, x_pont, "")
				if not bd.is_empty():
					a = bd
					if outil.suspension != "":   # glissée ailleurs ou hors de la grille ; l'outil « Détacher » la retire simplement
						_glisse = lid_actuel
						_lia_prise = true
					_son()
					_maj()
				return
			if outil.suspension != "":
				_poser_liaison(_doigt, outil.suspension)
		"coque":
			var i := ConstructionLibre.piece_en(a, cell, true)
			if i >= 0 and _scie != "":
				var bs := ConstructionLibre.scier(a, i, cell, _scie)
				if bs.is_empty():
					_dire("Touchez l'intérieur de la coque.")
				else:
					a = bs
					_son()
					_maj()
				return
			if i >= 0:
				_prendre(i)


func _relacher(pos: Vector2) -> void:
	if _depl:
		_depl = false
		if not _depl_b.is_empty():
			a = _depl_b
			_son()
		elif _dans_grille(pos) and _case(pos) != _depl0:
			_dire("Le véhicule sortirait de la grille.")
		_depl_b = {}
		_maj(true)
		return
	if _tole0.x > -99:
		var q0 := _tole0
		var q1 := _coin(pos)
		_tole0 = Vector2i(-99, -99)
		if q0 == q1:   # simple toucher : retire la tôle touchée
			var i := ConstructionLibre.tole_en(a, _mon(pos))
			if i >= 0:
				a = ConstructionLibre.retirer_tole(a, i)
				_son()
				_maj()
			return
		var b := ConstructionLibre.poser_tole(a, q0, q1)
		if b.is_empty():
			_dire("Une tôle part du véhicule ou d'une autre tôle.")
		else:
			a = b
			_son()
			_maj(true)
		return
	if onglet == "chassis" and _rect0.x > -99:
		var sorte: String = outil.chassis
		var b := a
		for x in range(mini(_rect0.x, _rect1.x), maxi(_rect0.x, _rect1.x) + 1):
			for y in range(mini(_rect0.y, _rect1.y), maxi(_rect0.y, _rect1.y) + 1):
				b = ConstructionLibre.peindre(b, Vector2i(x, y), sorte)
		_rect0 = Vector2i(-99, -99)
		if b != a:
			a = b
			_son()
		_maj(true)
		return
	if not _essieu_tenu.is_empty():
		var et := _essieu_tenu
		_essieu_tenu = {}
		if _dans_grille(pos):
			var c := _case(pos)
			var b := ConstructionLibre.poser_essieu(a, c.x, String(et.piece), String(et.get("train", "")), c.y)
			if not b.is_empty():
				if String(et.get("liaison", "")) != "":
					var bl := ConstructionLibre.relier(b, c.x, String(et.liaison))
					b = bl if not bl.is_empty() else b
				a = b
				_son()
			else:
				_dire("Pas de châssis au-dessus : essieu retiré.")
		else:
			_dire("Essieu retiré.")
		_maj(true)
		return
	if _glisse == "":
		return
	var famille := String(Assemblage.piece(_glisse).get("famille", ""))
	if not famille in ConstructionLibre.FAMILLES_PIECES:   # roue ou suspension tenue au doigt : elle s'aimante sur l'essieu ou le pont le plus proche
		var tenue := _glisse
		var reprise := _lia_prise
		_glisse = ""
		_lia_prise = false
		if famille == "liaison":
			if _dans_grille(pos):
				_poser_liaison(_visee(pos), tenue)
			elif reprise:
				_dire("Suspension retirée.")
				_maj(true)
		elif _dans_grille(pos):
			_monter_roue(_roue_cible(_visee(pos), tenue), tenue)
		return
	if not _dans_grille(pos):
		_dire("%s retiré." % Assemblage.piece(_glisse).get("nom", "Pièce"))
	else:
		var b := ConstructionLibre.poser(a, _glisse, _cible(pos, _glisse), _miroir and _est_coque(_glisse), _extra)
		if b.is_empty():
			_dire("Pas de place ni d'appui ici.")
		else:
			a = b
			_son()
	_glisse = ""
	_maj(true)


# Monte (train_id) ou démonte ("") la roue de l'essieu de la colonne x ; x < 0 : aucun essieu à portée
func _monter_roue(x: int, train_id: String) -> void:
	if x < 0:
		_dire("Approchez la roue d'un essieu." if train_id != "" else "Touchez un essieu pour démonter sa roue.")
		return
	var b := ConstructionLibre.monter_train(a, x, train_id)
	if b.is_empty():
		_dire("Posez d'abord un essieu ici.")
		return
	a = b
	_son()
	_maj()


# « Démonter » (roues) ou « Détacher » (suspension) : on touche ensuite un essieu ou un pont, rien n'est tenu au doigt
func _vider_outil(cle: String) -> void:
	outil[cle] = ""
	_glisse = ""


# Suspension prise dans le tiroir : on la glisse ensuite sur un pont rigide
func _prendre_liaison(id: String) -> void:
	outil.suspension = id
	_tenir(id)
	var ponts: Array = a.get("essieux", []).filter(func(ex): return bool(Assemblage.piece(String(ex.piece)).get("pont", false)))
	if ponts.is_empty():
		_dire("Posez d'abord un pont rigide en l'air (Essieux).")


# --- Aimantation (DEC-081) ------------------------------------------------------------------------------
func _visee(pos: Vector2) -> Vector2:   # point visé par une pièce glissée : un peu au-dessus du doigt, comme les autres pièces
	return pos - Vector2(0, DECALAGE_DOIGT * _cell)


# Hauteur du centre d'un essieu (en cases) : un pont rigide est en l'air, les autres contre le châssis
func _y_axe(ex: Dictionary) -> float:
	var x := int(ex.x)
	if bool(Assemblage.piece(String(ex.piece)).get("pont", false)):
		return float(ex.get("y", ConstructionLibre.y_essieu(a, x)))
	return float(ConstructionLibre.y_essieu(a, x))


# Colonne de l'essieu le plus proche du point visé (l'essieu s'aimante), -1 si aucun n'est à portée
func _roue_cible(pos: Vector2, train_id: String) -> int:
	var q := _mon(pos)
	var d_roue := float(Assemblage.piece(train_id).get("diametre_cases", 2)) if train_id != "" else 2.0
	var meilleur := -1
	var dmin := INF
	for ex in a.get("essieux", []):
		var d := Vector2(q.x - (float(ex.x) + 0.5), q.y - _y_axe(ex)).length()
		if d < dmin:
			dmin = d
			meilleur = int(ex.x)
	return meilleur if dmin <= RAYON_AIMANT + d_roue * 0.5 else -1


# Colonne du pont rigide le plus proche du point visé (distance au lien entre le pont et le châssis), -1 si aucun
func _pont_cible(pos: Vector2) -> int:
	var q := _mon(pos)
	var meilleur := -1
	var dmin := INF
	for ex in a.get("essieux", []):
		if not bool(Assemblage.piece(String(ex.piece)).get("pont", false)):
			continue
		var x := int(ex.x)
		var yp := _y_axe(ex)
		var yc := float(ConstructionLibre.y_essieu(a, x))
		var haut := clampf(q.y, minf(yp, yc), maxf(yp, yc))   # point le plus proche sur le lien vertical
		var d := Vector2(q.x - (float(x) + 0.5), q.y - haut).length()
		if d < dmin:
			dmin = d
			meilleur = x
	return meilleur if dmin <= RAYON_AIMANT else -1


# Pose la suspension `lid` sur le pont rigide le plus proche du point visé ; si elle ne couvre pas l'écart, celle qui convient est prise et annoncée
func _poser_liaison(pos: Vector2, lid: String) -> void:
	var x := _pont_cible(pos)
	if x < 0:
		_dire("Approchez la suspension d'un pont rigide (Essieux).")
		return
	var ex := ConstructionLibre.essieu_en(a, x)
	var b := ConstructionLibre.relier(a, x, lid)
	if b.is_empty():
		var h := ConstructionLibre.ecart_pont(a, ex)
		var ok_ids := ConstructionLibre.liaisons_pour(h)
		if ok_ids.is_empty():
			_dire("Pont trop loin du châssis (%d cm)." % (h * 25))
			return
		lid = ok_ids[0]
		b = ConstructionLibre.relier(a, x, lid)
		_dire("À %d cm : %s." % [h * 25, Assemblage.piece(lid).nom])
	a = b
	_son()
	_maj(true)


# Case visée par la pièce tenue : centrée sur le doigt, un peu au-dessus pour rester visible
func _cible(pos: Vector2, id: String) -> Vector2i:
	var e: Array = _extra.get("emprise", Assemblage.piece(id).emprise)
	var q := _mon(_visee(pos))
	return Vector2i(int(floor(q.x - float(e[0]) * 0.5 + 0.5)), int(floor(q.y - float(e[1]) * 0.5 + 0.5)))


func _candidat() -> Dictionary:
	if _glisse == "" or not _dans_grille(_doigt):
		return {}
	if not Assemblage.piece(_glisse).get("famille", "") in ConstructionLibre.FAMILLES_PIECES:
		return {}
	return ConstructionLibre.poser(a, _glisse, _cible(_doigt, _glisse), _miroir and _est_coque(_glisse), _extra)


func _prendre(i: int) -> void:   # pièce posée reprise au doigt : la relâcher ailleurs la déplace, hors de la grille la retire
	_glisse = String(a.pieces[i].piece)
	_miroir = bool(a.pieces[i].get("miroir", false))
	_extra = {}
	for k in ["coupe", "emprise", "lot"]:
		if a.pieces[i].has(k):
			_extra[k] = a.pieces[i][k]
	a = ConstructionLibre.retirer(a, i)
	_an = ConstructionLibre.analyser(a)
	_placer_apercu(_candidat())


func _tenir(id: String) -> void:   # pièce prise dans le tiroir
	_glisse = id
	_extra = {}


func _charger_plan(plan: Dictionary) -> void:
	var r := PlansGrille.adapter(plan.a, _palette)
	a = r.a
	a.nom_choisi = true
	_dire("Plan chargé." if r.manquantes.is_empty() else "Absent de la réserve : " + ", ".join(r.manquantes))
	_maj(true)


# Bac à sable (DEC-080) : partir d'un vrai véhicule du jeu
func _charger_vehicule(type: String) -> void:
	var h := Assemblage.de_type(type)
	if h.is_empty():
		return
	a = ConstructionLibre.convertir(h, type)
	a.nom_choisi = true
	_dire("%s : modifiez-le librement." % String(a.nom))
	_maj(true)


# Transforme la grille en remorque : moteurs et radiateurs démontés, timon posé à l'avant (DEC-080)
func _en_remorque() -> void:
	a = ConstructionLibre.en_remorque(a)
	_dire("Remorque : elle sera tirée par le véhicule devant elle dans le convoi.")
	_maj(true)


func _basculer_ecorche() -> void:
	_ecorche = not _ecorche
	_placer_apercu()


func _est_coque(id: String) -> bool:
	return Assemblage.piece(id).get("famille", "") == "coque"


func _son() -> void:
	var so := get_node_or_null("/root/Son")
	if so:
		so.effet("sfx_atelier", -6.0)


func _quitter() -> void:
	_effacer_brouillon()
	ferme.emit(false)
	queue_free()


func _terminer() -> void:
	if not _peut_construire():
		var errs: Array = _an.get("erreurs", [])
		_dire(String(errs[0].texte) if not errs.is_empty() else "Pas assez de métal.")
		return
	var manque := ConstructionLibre.tireurs_requis(a) - ConstructionLibre.roles_de(a).count("tireur")
	if manque > 0 and not _confirmer:
		_confirmer = true
		_dire("%d arme%s sans tireur. Touchez encore la coche pour construire." % [manque, "s" if manque > 1 else ""])
		_choisir_onglet("equipage")
		return
	if m.construire_grille(uid, a):
		_effacer_brouillon()
		ferme.emit(true)
		queue_free()
	else:
		_dire(m.journal[-1].txt if not m.journal.is_empty() else "Impossible de construire.")


func _dire(t: String) -> void:
	_message = t
	_msg_t = 3.5


# --- Nom ----------------------------------------------------------------------------------------
func _renommer() -> void:
	if OS.has_feature("web"):
		var r = JavaScriptBridge.eval("prompt('Nom du véhicule', %s)" % JSON.stringify(String(a.get("nom", ""))), true)
		if typeof(r) == TYPE_STRING:
			_nommer(String(r))
		return
	var champ := LineEdit.new()
	champ.text = String(a.get("nom", ""))
	champ.add_theme_font_size_override("font_size", 26)
	champ.position = _rect_nom.position
	champ.size = _rect_nom.size
	add_child(champ)
	champ.grab_focus()
	champ.select_all()
	champ.text_submitted.connect(func(t):
		_nommer(t)
		champ.queue_free())
	champ.focus_exited.connect(func():
		if is_instance_valid(champ):
			champ.queue_free())


func _nommer(t: String) -> void:
	t = t.strip_edges().left(40)
	if t == "":   # nom vidé : on revient au nom proposé
		a.erase("nom_choisi")
	else:
		a.nom = t
		a.nom_choisi = true
	_maj()


# --- Brouillon (la page web peut se recharger : on ne perd pas sa construction) ----------------
func _ecrire_brouillon() -> void:
	var f := FileAccess.open(BROUILLON, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"uid": uid, "bac": m.bac_a_sable, "a": a}))


func _lire_brouillon() -> Dictionary:
	if not FileAccess.file_exists(BROUILLON):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(BROUILLON))
	if typeof(d) != TYPE_DICTIONARY or int(d.get("uid", -1)) != uid or bool(d.get("bac", false)) != m.bac_a_sable:
		return {}
	var b: Dictionary = d.get("a", {})
	if not ConstructionLibre.est_libre(b):
		return {}
	return PlansGrille.normaliser(b)


func _effacer_brouillon() -> void:
	if FileAccess.file_exists(BROUILLON):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BROUILLON))


# --- Contenu du tiroir ------------------------------------------------------------------------
# Vignette : {id, titre, n (-1 = sans compte), actif, choisi, action, mini: Callable(c, rect)} ; ligne : {ligne: true, titre, detail, …}
func _items() -> Array:
	var res := []
	match onglet:
		"chassis":
			for s in [["tube", "Tubes"], ["poutre", "Poutres"], ["acier", "Acier"], ["blindage", "Blindage"], ["", "Gomme"]]:
				var sorte: String = s[0]
				res.append({"titre": s[1], "choisi": outil.chassis == sorte, "action": func(): outil.chassis = sorte,
					"mini": func(c, r): _mini_case(c, r, sorte)})
		"essieux":
			for id in _famille("essieu"):
				var f := Assemblage.piece(id)
				res.append({"titre": _court(f.nom), "detail": "%.1f t" % (float(f.charge_kg) / 1000.0), "choisi": outil.essieux == id, "ar": 1.6,
					"action": func(): outil.essieux = id, "mini": func(c, r): _mini_essieu(c, r, bool(f.get("pont", false)))})
		"roues":   # la roue se glisse vers un essieu : elle s'y aimante (DEC-081)
			for id in _famille("train"):
				var f := Assemblage.piece(id)
				res.append({"titre": _court(f.nom), "choisi": outil.roues == id, "ar": 2.0 if String(f.get("type", "")) == "chenilles" else 1.0, "action": func():
					outil.roues = id
					_tenir(id), "mini": func(c, r): _mini_roue(c, r, id)})
			res.append({"titre": "Démonter", "choisi": outil.roues == "", "action": func(): _vider_outil("roues"),
				"mini": func(c, r): _mini_icone(c, r, "croix", C_ROUGE)})
		"suspension":   # vraie pièce : on la glisse sur un pont rigide, on la reprend au doigt pour la déplacer ou la retirer (DEC-081)
			for id in _famille("liaison"):
				var f := Assemblage.piece(id)
				res.append({"titre": _court(f.nom), "detail": "%d-%d cm" % [int(f.hauteur_min) * 25, int(f.hauteur_max) * 25], "choisi": outil.suspension == id, "ar": 1.7,
					"action": func(): _prendre_liaison(id), "mini": func(c, r): _mini_liaison(c, r, String(f.get("dessin", "lames")))})
			res.append({"titre": "Détacher", "choisi": outil.suspension == "", "action": func(): _vider_outil("suspension"),
				"mini": func(c, r): _mini_icone(c, r, "croix", C_ROUGE)})
		"toles":
			var n_t: int = a.get("toles", []).size()
			res.append({"ligne": true, "titre": "%d tôle%s" % [n_t, "s" if n_t > 1 else ""], "detail": "inclinée = plus épaisse ; fermée = caisse blindée", "actif": false})
			res.append({"ligne": true, "titre": "Toucher une tôle", "detail": "la retire", "actif": false})
			res.append({"ligne": true, "titre": "Tout retirer", "detail": "enlève toutes les tôles", "actif": n_t > 0, "action": func():
				a.toles = []
				_maj()})
		"vehicule":
			res.append({"ligne": true, "titre": "Glisser le véhicule", "detail": "le déplace sur la grille", "actif": false})
		"peinture":
			for pe in PEINTURES:
				var hex: String = pe[0]
				res.append({"titre": pe[1], "choisi": String(a.get("peinture", "")) == hex, "action": func():
					if hex == "":
						a.erase("peinture")
					else:
						a.peinture = hex
					_maj(), "mini": func(c, r): _mini_couleur(c, r, hex)})
		"plans":   # plans enregistrés (DEC-071)
			var nom := String(a.get("nom", "Plan"))
			res.append({"ligne": true, "titre": "Enregistrer « %s »" % nom, "detail": "remplace un plan du même nom",
				"actif": not a.get("cases", []).is_empty(), "action": func():
					PlansGrille.enregistrer(a)
					_dire("Plan « %s » enregistré." % nom)})
			res.append({"ligne": true, "titre": "Supprimer : %s" % ("oui, touchez un plan" if _suppr_plans else "non"), "detail": "", "choisi": _suppr_plans,
				"action": func(): _suppr_plans = not _suppr_plans})
			for pl in PlansGrille.lire():
				var plan: Dictionary = pl
				res.append({"ligne": true, "titre": String(plan.nom), "detail": "%d cases · %d pièces" % [plan.a.get("cases", []).size(), plan.a.get("pieces", []).size()],
					"action": func():
						if _suppr_plans:
							PlansGrille.supprimer(String(plan.nom))
							_dire("Plan supprimé.")
						else:
							_charger_plan(plan)})
		"vehicules":   # remorque ; véhicules du jeu en bac à sable (DEC-080)
			res.append({"ligne": true, "titre": "Remorque : %s" % ("oui" if ConstructionLibre.remorque(a) else "non"),
				"detail": "démonte moteurs et radiateurs, pose un timon", "choisi": ConstructionLibre.remorque(a), "action": func():
					if ConstructionLibre.remorque(a):
						a.erase("remorque")
						_maj()
					else:
						_en_remorque()})
			if m.bac_a_sable:
				res.append({"ligne": true, "titre": "Grille vide", "detail": "repartir de zéro", "action": func():
					a = ConstructionLibre.nouvelle()
					_maj(true)})
				for type in VehiculeDessin.donnees().vehicules:
					if Assemblage.de_type(type).is_empty():
						continue
					var t: String = type
					res.append({"ligne": true, "titre": String(VehiculeDessin.donnees().vehicules[t].nom), "detail": "véhicule du jeu", "action": func(): _charger_vehicule(t)})
		"equipage":
			var sieges := ConstructionLibre.sieges_equipage(a)
			if sieges.is_empty():
				res.append({"ligne": true, "titre": "Aucun siège", "detail": "posez un poste", "actif": false})
			for i in sieges.size():
				var s: Dictionary = sieges[i]
				var k: int = s.k
				var r: String = s.role
				res.append({"ligne": true, "titre": "%d · %s" % [i + 1, NOMS_ROLES[r]], "detail": AIDE_ROLES[r] + (" · fixe" if s.fixe else ""),
					"actif": not s.fixe, "action": func(): _changer_role(k)})
			var nt := ConstructionLibre.places_troupes(a)
			if nt > 0:
				res.append({"ligne": true, "titre": "Bancs : %d soldat%s" % [nt, "s" if nt > 1 else ""], "detail": "débarquables en combat", "actif": false})
		_:
			if onglet == "coque":   # réglages du plan carrosserie (DEC-067)
				res.append({"titre": "Retourner", "choisi": _miroir, "action": func(): _miroir = not _miroir,
					"mini": func(c, r): _mini_icone(c, r, "retourner", C_TEXTE)})
				res.append({"titre": {"": "Scie", "v": "Scie |", "h": "Scie —"}[_scie], "choisi": _scie != "",
					"action": func(): _scie = {"": "v", "v": "h", "h": ""}[_scie], "mini": func(c, r): _mini_icone(c, r, "scie", C_TEXTE)})
				res.append({"titre": "Écorché", "choisi": _ecorche, "action": _basculer_ecorche,
					"mini": func(c, r): _mini_icone(c, r, "oeil", C_TEXTE)})
			for it in _palette:
				var f := Assemblage.piece(it.id)
				var fam := String(f.get("famille", ""))
				var ici := fam == onglet or (onglet == "poste" and fam == "cabine") or (onglet == "equipement" and fam == "greffe") or (onglet == "moteur" and fam == "radiateur")
				if not ici:
					continue
				var reste := _restant(it.id, int(it.n))
				var id: String = it.id
				var det := ""
				match fam:
					"moteur": det = "%d ch" % int(f.puissance_ch)
					"radiateur": det = "%d ch" % int(f.refroidit_ch)
				var emp: Array = f.get("emprise", [1, 1])
				res.append({"titre": _court(f.nom), "detail": det, "n": reste, "actif": reste != 0, "choisi": _glisse == id,
					"ar": float(emp[0]) / maxf(1.0, float(emp[1])),   # la vignette a la proportion de la pièce
					"action": func(): _tenir(id), "mini": func(c, r): _mini_piece(c, r, id)})
			if res.is_empty():
				res.append({"ligne": true, "titre": "Rien en réserve", "detail": "fouillez des épaves", "actif": false})
	return res


static func _court(t: String) -> String:   # nom tenant sur une vignette
	return t if t.length() <= 16 else t.left(15) + "…"


func _changer_role(k: int) -> void:   # k : rang parmi les sièges libres (a.roles)
	if k < 0:
		return
	var roles: Array = a.get("roles", []).duplicate()
	while roles.size() <= k:
		roles.append("tireur")
	var j := ConstructionLibre.ROLES.find(String(roles[k]))
	roles[k] = ConstructionLibre.ROLES[(j + 1) % ConstructionLibre.ROLES.size()]
	a.roles = roles
	_maj()


# --- Dessin -----------------------------------------------------------------------------------
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), C_FOND)
	if FOND_GRILLE != null:   # fond d'atelier (grange), recadré pour couvrir l'écran
		var ts := FOND_GRILLE.get_size()
		var k: float = maxf(size.x / ts.x, size.y / ts.y)
		draw_texture_rect(FOND_GRILLE, Rect2((size - ts * k) * 0.5, ts * k), false)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.25))


# Quadrillage de toute la grille, dans la fenêtre : ce qui dépasse quand on zoome est coupé
func _dessiner_grille() -> void:
	var c := _monde
	c.draw_set_transform(-_zone.position)   # on dessine en coordonnées d'écran
	c.draw_rect(_zone, Color(C_ZONE, 0.55))
	var G := ConstructionLibre.taille()
	var v := _cases_visibles()
	if v.size.x > 0 and v.size.y > 0:
		var gauche := _px(v.position.x, 0).x
		var droite := _px(v.end.x, 0).x
		var haut := _px(0, v.end.y).y
		var bas := _px(0, v.position.y).y
		for i in range(v.position.x, v.end.x + 1):
			var x := _ox + float(i) * _cell
			c.draw_line(Vector2(x, haut), Vector2(x, bas), C_GRILLE, 1.0)
		for j in range(v.position.y, v.end.y + 1):
			var y := _oy - float(j) * _cell
			c.draw_line(Vector2(gauche, y), Vector2(droite, y), C_GRILLE, 1.0)
	c.draw_rect(Rect2(_px(0, G.y), Vector2(G.x, G.y) * _cell), C_CADRE, false, 2.0)
	if _deplacer:   # outil « déplacer » actif : la fenêtre est cerclée d'accent
		c.draw_rect(Rect2(_zone.position + Vector2(2, 2), _zone.size - Vector2(4, 4)), Color(C_ACCENT, 0.8), false, 3.0)


# Roue ou suspension tenue au doigt et pont ou essieu sur lequel elle s'aimante (-1 : aucun)
func _aimant_courant() -> int:
	if not _appui or _glisse == "" or not _dans_grille(_doigt):
		return -1
	var fam := String(Assemblage.piece(_glisse).get("famille", ""))
	if fam == "train":
		return _roue_cible(_visee(_doigt), _glisse)
	if fam == "liaison":
		return _pont_cible(_visee(_doigt))
	return -1


# Coins où accrocher une tôle (mis en cache : recalculés quand la grille change)
func _coins_de_toles() -> Array:
	if _coins_rev != _rev:
		_coins = []
		var G := ConstructionLibre.taille()
		for x in range(0, G.x + 1):
			for y in range(0, G.y + 1):
				if ConstructionLibre.coin_accroche(a, Vector2i(x, y)):
					_coins.append(Vector2i(x, y))
		_coins_rev = _rev
	return _coins


# Repères posés sur le véhicule, dans la fenêtre : sol, pièces, essieux, tracés en cours, pièce tenue
func _dessiner_surcouche() -> void:
	var c := _surcouche
	c.draw_set_transform(-_zone.position)
	var police := get_theme_default_font()
	var det: Dictionary = _an.get("detail", {})
	if det.has("sol"):
		var ys := _px(0, det.sol).y
		c.draw_line(Vector2(_zone.position.x, ys), Vector2(_zone.end.x, ys), C_SOL, 3.0)
	for p in a.get("pieces", []):   # contour léger des pièces posées (pour les reprendre au doigt)
		var e: Array = p.get("emprise", Assemblage.piece(String(p.piece)).emprise)
		c.draw_rect(Rect2(_px(int(p.pos[0]), int(p.pos[1]) + int(e[1])), Vector2(int(e[0]), int(e[1])) * _cell), Color(1, 1, 1, 0.14), false, 1.5)
	for e in ConstructionLibre.essieux_nus(a):   # essieux sans roue : un moyeu nu à monter
		var ctr := _px(float(e.x) + 0.5, _y_axe(e))
		c.draw_circle(ctr, _cell * 0.28, Color("#C9C6BC"))
		c.draw_arc(ctr, _cell * 0.9, 0, TAU, 24, Color(C_ACCENT, 0.8), 2.0)
	var x_aimant := _aimant_courant()
	var fam_tenue := String(Assemblage.piece(_glisse).get("famille", "")) if _glisse != "" else ""
	if onglet == "roues" or fam_tenue == "train":   # cibles des roues : un cercle autour de chaque essieu, le plus proche s'allume
		for ex in a.get("essieux", []):
			var vise := int(ex.x) == x_aimant
			c.draw_arc(_px(float(ex.x) + 0.5, _y_axe(ex)), _cell * (1.25 if vise else 0.95), 0, TAU, 28, Color(C_VERT if vise else C_ACCENT, 0.95 if vise else 0.5), 3.5 if vise else 2.0)
	if onglet == "suspension" or fam_tenue == "liaison":   # cibles des suspensions : les ponts rigides (orange tant qu'ils ne sont pas reliés)
		for ex in a.get("essieux", []):
			if not bool(Assemblage.piece(String(ex.piece)).get("pont", false)):
				continue
			var vise := int(ex.x) == x_aimant
			var relie := ConstructionLibre.liaison_ok(a, ex)
			c.draw_arc(_px(float(ex.x) + 0.5, _y_axe(ex)), _cell * (1.4 if vise else 1.1), 0, TAU, 28, Color(C_VERT if (vise or relie) else C_ACCENT, 0.95 if vise else 0.7), 3.5 if vise else 2.0)
	for d in det.get("essieux", []):   # charge sous chaque essieu
		var ctr := _px(float(d.x) + 0.5, float(d.y) - float(d.r))
		if d.has("charge") and float(d.charge) > float(d.capacite):
			c.draw_string(police, ctr + Vector2(-60, 26), "%.1f/%.1f t" % [float(d.charge) / 1000.0, float(d.capacite) / 1000.0], HORIZONTAL_ALIGNMENT_CENTER, 120, 16, C_ROUGE)
		elif not d.get("touche", true):
			c.draw_string(police, ctr + Vector2(-60, 26), "en l'air", HORIZONTAL_ALIGNMENT_CENTER, 120, 18, C_ROUGE)
	if det.has("cg"):
		var cg := _px(det.cg.x, det.cg.y)
		c.draw_circle(cg, 9.0, Color(1, 1, 1, 0.9))
		c.draw_line(cg - Vector2(12, 0), cg + Vector2(12, 0), Color.BLACK, 2.0)
		c.draw_line(cg - Vector2(0, 12), cg + Vector2(0, 12), Color.BLACK, 2.0)
	if onglet == "chassis" and _rect0.x > -99:   # rectangle de châssis en cours
		var x0 := mini(_rect0.x, _rect1.x)
		var r := Rect2(_px(x0, maxi(_rect0.y, _rect1.y) + 1), Vector2(absi(_rect1.x - _rect0.x) + 1, absi(_rect1.y - _rect0.y) + 1) * _cell)
		c.draw_rect(r, Color(C_ROUGE, 0.25) if outil.chassis == "" else Color(C_ACCENT, 0.3))
		c.draw_rect(r, C_ACCENT, false, 3.0)
		c.draw_string(police, r.position + Vector2(6, -10), "%.2f × %.2f m" % [r.size.x / _cell * ConstructionLibre.C, r.size.y / _cell * ConstructionLibre.C], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, C_TEXTE)
	if onglet == "toles":   # coins où accrocher une tôle, et tôle en cours avec son angle
		var vis := _cases_visibles()
		for q in _coins_de_toles():
			if q.x >= vis.position.x and q.x <= vis.end.x and q.y >= vis.position.y and q.y <= vis.end.y:
				c.draw_circle(_px(q.x, q.y), 3.5, Color(C_ACCENT, 0.7))
		if _tole0.x > -99:
			var pa := _px(_tole0.x, _tole0.y)
			var pb := _px(_tole1.x, _tole1.y)
			c.draw_line(pa, pb, C_ACCENT, maxf(4.0, _cell * 0.22))
			c.draw_circle(pa, 7.0, C_ACCENT)
			if _tole1 != _tole0:
				var dd := Vector2(_tole1 - _tole0).abs()
				var ang := int(round(rad_to_deg(atan2(dd.x, dd.y))))   # 0° : verticale
				c.draw_string(police, pb + Vector2(12, -12), "%d°" % ang, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, C_TEXTE)
	# Pièce tenue : cadre vert (posable) ou rouge (non) ; roue ou suspension aimantée sur son essieu
	if _glisse != "" and fam_tenue in ConstructionLibre.FAMILLES_PIECES and _dans_grille(_doigt):
		var e: Array = _extra.get("emprise", Assemblage.piece(_glisse).emprise)
		var q := _cible(_doigt, _glisse)
		var ok := not _candidat().is_empty()
		var r := Rect2(_px(q.x, q.y + int(e[1])), Vector2(int(e[0]), int(e[1])) * _cell)
		if not ok:
			c.draw_rect(r, Color(C_ROUGE, 0.35))
		c.draw_rect(r, C_VERT if ok else C_ROUGE, false, 3.0)
	elif _appui and fam_tenue == "train" and _dans_grille(_doigt):
		var centre := _visee(_doigt)
		if x_aimant >= 0:   # la roue saute sur l'essieu
			centre = _px(float(x_aimant) + 0.5, _y_axe(ConstructionLibre.essieu_en(a, x_aimant)))
		_fantome_roue(c, centre, _glisse)
	elif _appui and fam_tenue == "liaison" and x_aimant >= 0:
		_fantome_liaison(c, x_aimant, _glisse)


# Roue tenue au doigt : à sa vraie taille, translucide
func _fantome_roue(c: Control, centre: Vector2, id: String) -> void:
	var f := Assemblage.piece(id)
	var dc := float(f.get("diametre_cases", 2))
	var d := dc * _cell
	if String(f.get("type", "")) == "chenilles":
		c.draw_circle(centre, d * 0.5, Color(0.12, 0.115, 0.105, 0.8))
		c.draw_circle(centre, d * 0.26, Color(0.35, 0.34, 0.31, 0.9))
		return
	var t := VehiculeDessin._tex("roue_petite" if dc < 2.5 else ("roue_moyenne" if dc < 4.0 else "roue_grande"))
	c.draw_texture_rect(t, Rect2(centre - Vector2(d, d) * 0.5, Vector2(d, d)), false, Color(1, 1, 1, 0.8))


# Suspension tenue au doigt : son vrai dessin entre le pont visé et le châssis
func _fantome_liaison(c: Control, x: int, lid: String) -> void:
	var ex := ConstructionLibre.essieu_en(a, x)
	if ex.is_empty():
		return
	var K := ConstructionLibre.C
	var G := ConstructionLibre.taille()
	var x_min := G.x
	var x_max := 0
	for q in a.get("cases", []):
		x_min = mini(x_min, int(q[0]))
		x_max = maxi(x_max, int(q[0]) + 1)
	var formes := []
	ConstructionLibre._formes_liaison(formes, String(Assemblage.piece(lid).get("dessin", "lames")), (float(x) + 0.5) * K,
		float(ConstructionLibre.y_essieu(a, x)) * K, _y_axe(ex) * K, float(x) + 0.5 < float(x_min + x_max) * 0.5)
	_mini_formes(c, Rect2(_px(0, G.y), Vector2(G.x, G.y) * _cell), formes, Rect2(0.0, 0.0, float(G.x) * K, float(G.y) * K))


# Interface : nom, message, barre d'icônes, tiroir, bilan, boutons de la vue
func _dessiner_dessus() -> void:
	var c := _dessus
	var police := get_theme_default_font()
	_cartes.clear()
	# Pièce tenue hors de la grille (ou sans cible) : une vignette suit le doigt
	if _glisse != "" and _appui:
		var fam := String(Assemblage.piece(_glisse).get("famille", ""))
		if not _dans_grille(_doigt) or (fam == "liaison" and _aimant_courant() < 0):
			_mini_piece_ou_roue(c, Rect2(_doigt - Vector2(44, 88), Vector2(88, 88)), _glisse)
	# Nom (touchez pour renommer) et message
	c.draw_rect(_rect_nom, Color(0, 0, 0, 0.35))
	c.draw_string(police, _rect_nom.position + Vector2(12, 31), "✎ " + String(a.get("nom", "Véhicule")) + ("   ·   remorque" if ConstructionLibre.remorque(a) else ""),
		HORIZONTAL_ALIGNMENT_LEFT, _rect_nom.size.x - 20, 22, C_TEXTE)
	_cartes.append({"rect": _rect_nom, "action": _renommer, "actif": true})
	if _msg_t > 0.0:
		var mr := Rect2(Vector2(_zone.position.x, _rect_nom.end.y + 6), Vector2(_tiroir.position.x - _zone.position.x - 16.0, 36))
		c.draw_rect(mr, Color(0, 0, 0, 0.6))
		c.draw_string(police, mr.position + Vector2(12, 26), _message, HORIZONTAL_ALIGNMENT_LEFT, mr.size.x - 20, 20, C_ACCENT)
	_dessiner_boutons_vue(c, police)
	_dessiner_rail(c, police)
	_dessiner_tiroir(c, police)
	_dessiner_bilan(c, police)


# Boutons de la vue, en bas à gauche de la grille : déplacer (flèche à quatre têtes) et cadrer
func _dessiner_boutons_vue(c: Control, police: Font) -> void:
	var t := 64.0
	var x := _zone.position.x + 10.0
	var y := _zone.end.y - t - 10.0
	var defs := [["deplacer", _deplacer, _basculer_deplacer], ["cadrer", false, _recadrer]]
	for i in defs.size():
		var r := Rect2(Vector2(x + float(i) * (t + 10.0), y), Vector2(t, t))
		var actif: bool = defs[i][1]
		c.draw_rect(r, Color(0.2, 0.17, 0.08, 0.92) if actif else C_TUILE)
		c.draw_rect(r, C_ACCENT if actif else Color(1, 1, 1, 0.3), false, 3.0 if actif else 1.5)
		_icone(c, r.grow(-t * 0.2), String(defs[i][0]), C_ACCENT if actif else C_TEXTE)
		_cartes.append({"rect": r, "action": defs[i][2], "actif": true})
	if _cam_manuelle:   # niveau de zoom
		c.draw_string(police, Vector2(x + 2.0 * (t + 10.0) + 4.0, y + t - 20.0), "%d %%" % int(round(_cell / _cell0 * 100.0)), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, C_DISCRET)


func _basculer_deplacer() -> void:
	_deplacer = not _deplacer
	_dire("Glissez un doigt pour déplacer la vue." if _deplacer else "Déplacement terminé : on construit de nouveau.")


func _dessiner_rail(c: Control, police: Font) -> void:
	var ic := (_rail.size.x - 8.0) * 0.5
	var ids: Array = ACTIONS.duplicate()
	for o in ONGLETS:
		ids.append(o[0])
	for i in ids.size():
		var id: String = ids[i]
		var r := Rect2(_rail.position + Vector2((i % 2) * (ic + 8.0), (i / 2) * (ic + 8.0)), Vector2(ic, ic))
		var choisi := id == onglet
		var actif := id != "valider" or _peut_construire()
		var fond := C_TUILE
		if id == "valider":
			fond = Color(0.16, 0.32, 0.18, 0.9) if actif else Color(0.15, 0.15, 0.15, 0.7)
		elif id == "quitter":
			fond = Color(0.35, 0.14, 0.12, 0.9)
		c.draw_rect(r, fond)
		c.draw_rect(r, C_ACCENT if choisi else Color(1, 1, 1, 0.15), false, 3.0 if choisi else 1.0)
		_icone(c, r.grow(-ic * 0.16), id, C_TEXTE if actif else C_DISCRET)
		var act: Callable
		match id:
			"valider": act = _terminer
			"quitter": act = _quitter
			_: act = func(): _choisir_onglet(id)
		_cartes.append({"rect": r, "action": act, "actif": true})


func _dessiner_tiroir(c: Control, police: Font) -> void:
	var T := _tiroir
	c.draw_rect(T, Color(0.05, 0.05, 0.05, 0.55))
	var titre := ""
	for o in ONGLETS:
		if o[0] == onglet:
			titre = o[1]
	c.draw_string(police, T.position + Vector2(12, 34), titre, HORIZONTAL_ALIGNMENT_LEFT, T.size.x - 20, 28, C_ACCENT)
	c.draw_string(police, T.position + Vector2(12, 60), String(AIDES.get(onglet, "")), HORIZONTAL_ALIGNMENT_LEFT, T.size.x - 20, 17, C_DISCRET)
	var pages := _pages_tiroir(_items(), T, T.position.y + 76.0, T.end.y - 64.0)
	_page = clampi(_page, 0, pages.size() - 1)
	for q in pages[_page]:
		var it: Dictionary = q.it
		var r: Rect2 = q.r
		var actif: bool = it.get("actif", true)
		var choisi: bool = it.get("choisi", false)
		c.draw_rect(r, C_TUILE if actif else Color(C_TUILE, 0.4))
		c.draw_rect(r, C_ACCENT if choisi else Color(1, 1, 1, 0.15), false, 3.0 if choisi else 1.0)
		if it.get("ligne", false):
			c.draw_string(police, r.position + Vector2(12, 30), String(it.titre), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 20, 21, C_TEXTE if actif else C_DISCRET)
			c.draw_string(police, r.position + Vector2(12, 56), String(it.get("detail", "")), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 20, 15, C_DISCRET)
		else:
			# La pièce elle-même, à l'échelle réduite, remplit sa vignette ; le titre est dessous
			var mr := Rect2(r.position + Vector2(5, 5), Vector2(r.size.x - 10.0, r.size.y - LABEL_H - 8.0))
			if it.has("mini"):
				it.mini.call(c, mr)
			c.draw_string(police, Vector2(r.position.x + 3.0, r.end.y - 8.0), String(it.titre), HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 6.0, 14, C_TEXTE if actif else C_DISCRET)
			var n: int = it.get("n", -1)
			if n >= 0:
				c.draw_string_outline(police, r.position + Vector2(r.size.x - 34, 20), "×%d" % n, HORIZONTAL_ALIGNMENT_RIGHT, 30, 16, 4, Color(0, 0, 0, 0.85))
				c.draw_string(police, r.position + Vector2(r.size.x - 34, 20), "×%d" % n, HORIZONTAL_ALIGNMENT_RIGHT, 30, 16, C_ACCENT if n > 0 else C_ROUGE)
			if String(it.get("detail", "")) != "":
				c.draw_string_outline(police, r.position + Vector2(6, 18), String(it.detail), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 40, 13, 4, Color(0, 0, 0, 0.85))
				c.draw_string(police, r.position + Vector2(6, 18), String(it.detail), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 40, 13, C_DISCRET)
		if it.has("action"):
			_cartes.append({"rect": r, "action": it.action, "actif": actif})
	if pages.size() > 1:   # pages du tiroir
		var bw := (T.size.x - 24.0) * 0.5
		var rh := Rect2(Vector2(T.position.x + 8, T.end.y - 56), Vector2(bw, 48))
		var rb := Rect2(Vector2(rh.end.x + 8, T.end.y - 56), Vector2(bw, 48))
		for z in [[rh, "▲", _page > 0, func(): _page -= 1], [rb, "▼", _page < pages.size() - 1, func(): _page += 1]]:
			c.draw_rect(z[0], C_TUILE if z[2] else Color(C_TUILE, 0.3))
			c.draw_string(police, z[0].position + Vector2(0, 34), z[1], HORIZONTAL_ALIGNMENT_CENTER, z[0].size.x, 24, C_TEXTE if z[2] else C_DISCRET)
			_cartes.append({"rect": z[0], "action": z[3], "actif": z[2]})


# Range les vignettes en rangées qui remplissent la largeur du tiroir : chaque vignette a la proportion de sa pièce (« ar »),
# donc la pièce occupe toute sa place ; rangées et vignettes ne se chevauchent jamais. Une page de plus quand le tiroir est plein.
func _pages_tiroir(items: Array, T: Rect2, y0: float, bas: float) -> Array:
	var W := T.size.x - 16.0
	var hmax := clampf((bas - y0 - ECART) * 0.5 - LABEL_H, 70.0, 130.0)   # deux rangées par page au mieux
	var hmin := 56.0
	var rangees := []
	var cur: Array = []
	var somme := 0.0
	for it in items:
		if it.get("ligne", false):
			if not cur.is_empty():
				rangees.append(_rangee(cur, somme, W, hmax))
				cur = []
				somme = 0.0
			rangees.append({"ligne": true, "items": [it], "h": 70.0})
			continue
		var ar := clampf(float(it.get("ar", 1.0)), 0.4, 6.0)
		if not cur.is_empty() and (W - ECART * float(cur.size())) / (somme + ar) < hmin:   # la rangée serait trop écrasée : on passe à la suivante
			rangees.append(_rangee(cur, somme, W, hmax))
			cur = []
			somme = 0.0
		cur.append(it)
		somme += ar
		if (W - ECART * float(cur.size() - 1)) / somme <= hmax:   # rangée pleine : les vignettes remplissent la largeur
			rangees.append(_rangee(cur, somme, W, hmax))
			cur = []
			somme = 0.0
	if not cur.is_empty():
		rangees.append(_rangee(cur, somme, W, hmax))
	var pages := [[]]
	var y := y0
	for rg in rangees:
		var h: float = rg.h
		var hr := h if rg.ligne else h + LABEL_H
		if y + hr > bas and not pages.back().is_empty():
			pages.append([])
			y = y0
		var x := T.position.x + 8.0
		for it in rg.items:
			var w: float = W if rg.ligne else clampf(float(it.get("ar", 1.0)), 0.4, 6.0) * h
			pages.back().append({"it": it, "r": Rect2(Vector2(x, y), Vector2(w, hr))})
			x += w + ECART
		y += hr + ECART
	return pages


func _rangee(its: Array, somme: float, W: float, hmax: float) -> Dictionary:
	var h := (W - ECART * float(its.size() - 1)) / maxf(somme, 0.1)   # hauteur qui remplit exactement la largeur
	return {"ligne": false, "items": its.duplicate(), "h": clampf(h, 40.0, hmax)}


func _dessiner_bilan(c: Control, police: Font) -> void:
	var x := _zone.position.x
	var lw := _tiroir.position.x - x - 24.0
	var y := size.y - float(_mg.get("b", 20.0)) - 40.0
	if not _an.get("ok", false):
		var errs: Array = _an.get("erreurs", [])
		if not errs.is_empty():
			c.draw_string(police, Vector2(x, y), "✗ " + String(errs[0].texte), HORIZONTAL_ALIGNMENT_LEFT, lw, 20, C_ROUGE)
		return
	var s: Dictionary = _an.stats
	var roule := float(s.vitesse) > 0.0
	c.draw_string(police, Vector2(x, y), ("▶ %.1f m/s" % s.vitesse) if roule else "■ immobile", HORIZONTAL_ALIGNMENT_LEFT, 170, 22, C_VERT if roule else C_ROUGE)
	var ligne := "%d kg   ·   blindage %d   ·   %d place%s" % [int(s.poids_kg), int(s.blindage), int(s.equipage), "s" if int(s.equipage) > 1 else ""]
	var cout: float = m.cout_grille(uid, a)
	if cout > 0.0:
		ligne += "   ·   %d / %d métal" % [int(ceil(cout)), int(m.stocks.metal)]
	c.draw_string(police, Vector2(x + 180, y), ligne, HORIZONTAL_ALIGNMENT_LEFT, lw - 180, 18, C_DISCRET)
	var defauts: Array = _an.defauts
	if not defauts.is_empty():
		var d: Dictionary = defauts[0]
		for q in defauts:
			if q.grave:
				d = q
				break
		c.draw_string(police, Vector2(x, y + 28), "• " + String(d.texte) + ("  (+%d)" % (defauts.size() - 1) if defauts.size() > 1 else ""), HORIZONTAL_ALIGNMENT_LEFT, lw, 17, C_ROUGE if d.grave else C_ACCENT)


# --- Icônes et miniatures (dessinées : aucune image à produire) --------------------------------
func _icone(c: Control, r: Rect2, id: String, col: Color) -> void:
	var w := r.size.x
	var o := r.position
	var ep := maxf(2.0, w * 0.07)
	match id:
		"valider":
			c.draw_polyline(PackedVector2Array([o + Vector2(w * 0.1, w * 0.55), o + Vector2(w * 0.4, w * 0.85), o + Vector2(w * 0.92, w * 0.18)]), C_VERT.lightened(0.2), ep * 1.6)
		"quitter":
			_mini_icone(c, r, "croix", Color("#F0A090"))
		"chassis":
			for i in 3:
				for j in 2:
					c.draw_rect(Rect2(o + Vector2(w * (0.05 + 0.31 * i), w * (0.3 + 0.24 * j)), Vector2(w * 0.27, w * 0.2)), col.darkened(0.2))
		"essieux":
			_mini_essieu(c, r, false)
		"roues":
			_tex_dans(c, r, VehiculeDessin._tex("roue_grande"))
		"suspension":   # ressort entre deux coupelles
			c.draw_rect(Rect2(o + Vector2(w * 0.2, w * 0.08), Vector2(w * 0.6, w * 0.08)), col)
			c.draw_rect(Rect2(o + Vector2(w * 0.2, w * 0.84), Vector2(w * 0.6, w * 0.08)), col)
			var zz := PackedVector2Array()
			for k in 9:
				zz.append(o + Vector2(w * (0.3 if k % 2 == 0 else 0.7), w * (0.16 + 0.085 * k)))
			c.draw_polyline(zz, Color("#C07A4A"), ep)
		"moteur":
			_tex_dans(c, r, VehiculeDessin._tex("moteur_moyen"))
		"poste":
			_mini_piece(c, r, "poste_conduite")
		"coque":
			_tex_dans(c, r, VehiculeDessin._tex("coques/coque_berline"))
		"toles":
			c.draw_line(o + Vector2(w * 0.15, w * 0.9), o + Vector2(w * 0.75, w * 0.1), Color("#6E7550"), ep * 2.2)
			for k in 3:
				c.draw_circle(o + Vector2(w * (0.27 + 0.2 * k), w * (0.74 - 0.27 * k)), ep * 0.45, Color("#C8C8B0"))
		"arme":
			_tex_dans(c, r, VehiculeDessin._tex("arme_mitrailleuse"))
		"equipement":
			_mini_piece(c, r, "greffe_pare_buffle")
		"equipage":
			c.draw_circle(o + Vector2(w * 0.5, w * 0.42), w * 0.18, Color("#D9A57A"))
			c.draw_rect(Rect2(o + Vector2(w * 0.28, w * 0.18), Vector2(w * 0.44, w * 0.14)), Color("#5E6238"))
			c.draw_rect(Rect2(o + Vector2(w * 0.25, w * 0.62), Vector2(w * 0.5, w * 0.3)), Color("#5E6238"))
		"peinture":
			var pc := Color(String(a.get("peinture", "#B0623A")))
			c.draw_circle(o + Vector2(w * 0.5, w * 0.6), w * 0.28, pc)
			c.draw_colored_polygon(PackedVector2Array([o + Vector2(w * 0.5, w * 0.08), o + Vector2(w * 0.25, w * 0.5), o + Vector2(w * 0.75, w * 0.5)]), pc)
		"plans":
			c.draw_rect(Rect2(o + Vector2(w * 0.15, w * 0.08), Vector2(w * 0.7, w * 0.84)), Color("#3E5C7A"))
			for k in 4:
				c.draw_line(o + Vector2(w * 0.25, w * (0.25 + 0.17 * k)), o + Vector2(w * 0.75, w * (0.25 + 0.17 * k)), Color("#C8D8E8"), 2.0)
		"vehicules":
			_tex_dans(c, r, VehiculeDessin._tex("vehicules/willys_mb"))
		"vehicule":   # caisse et flèche : déplacer le véhicule entier
			c.draw_rect(Rect2(o + Vector2(w * 0.1, w * 0.3), Vector2(w * 0.55, w * 0.3)), col, false, ep)
			c.draw_circle(o + Vector2(w * 0.22, w * 0.66), w * 0.08, col)
			c.draw_circle(o + Vector2(w * 0.53, w * 0.66), w * 0.08, col)
			c.draw_line(o + Vector2(w * 0.6, w * 0.85), o + Vector2(w * 0.85, w * 0.85), col, ep)
			c.draw_colored_polygon(PackedVector2Array([o + Vector2(w * 0.92, w * 0.85), o + Vector2(w * 0.78, w * 0.75), o + Vector2(w * 0.78, w * 0.95)]), col)
		"deplacer":   # flèche à quatre têtes
			var ct := o + Vector2(w * 0.5, w * 0.5)
			for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
				var pointe: Vector2 = ct + d * (w * 0.46)
				var perp := Vector2(-d.y, d.x)
				c.draw_line(ct, pointe - d * (w * 0.08), col, ep)
				c.draw_colored_polygon(PackedVector2Array([pointe, pointe - d * (w * 0.2) + perp * (w * 0.14), pointe - d * (w * 0.2) - perp * (w * 0.14)]), col)
		"cadrer":   # quatre coins : revenir au cadrage de base
			for sx in [0.0, 1.0]:
				for sy in [0.0, 1.0]:
					var coin := o + Vector2(w * (0.08 + 0.84 * sx), w * (0.08 + 0.84 * sy))
					var dx: float = 1.0 - 2.0 * sx
					var dy: float = 1.0 - 2.0 * sy
					c.draw_line(coin, coin + Vector2(dx * w * 0.3, 0.0), col, ep)
					c.draw_line(coin, coin + Vector2(0.0, dy * w * 0.3), col, ep)


func _mini_icone(c: Control, r: Rect2, id: String, col: Color) -> void:
	var w := r.size.x
	var o := r.position
	var ep := maxf(2.0, w * 0.08)
	match id:
		"croix":
			c.draw_line(o + Vector2(w * 0.2, w * 0.2), o + Vector2(w * 0.8, w * 0.8), col, ep * 1.4)
			c.draw_line(o + Vector2(w * 0.8, w * 0.2), o + Vector2(w * 0.2, w * 0.8), col, ep * 1.4)
		"retourner":
			c.draw_line(o + Vector2(w * 0.15, w * 0.35), o + Vector2(w * 0.85, w * 0.35), col, ep)
			c.draw_line(o + Vector2(w * 0.7, w * 0.2), o + Vector2(w * 0.85, w * 0.35), col, ep)
			c.draw_line(o + Vector2(w * 0.15, w * 0.65), o + Vector2(w * 0.85, w * 0.65), col, ep)
			c.draw_line(o + Vector2(w * 0.3, w * 0.8), o + Vector2(w * 0.15, w * 0.65), col, ep)
		"scie":
			c.draw_rect(Rect2(o + Vector2(w * 0.1, w * 0.3), Vector2(w * 0.65, w * 0.25)), Color("#B9B2A0"))
			var pts := PackedVector2Array()
			for k in 9:
				pts.append(o + Vector2(w * (0.1 + 0.08 * k), w * (0.55 + (0.08 if k % 2 == 0 else 0.0))))
			c.draw_polyline(pts, Color("#B9B2A0"), ep * 0.6)
			c.draw_rect(Rect2(o + Vector2(w * 0.72, w * 0.22), Vector2(w * 0.18, w * 0.42)), Color("#6D5032"))
		"oeil":
			c.draw_arc(o + Vector2(w * 0.5, w * 0.75), w * 0.45, -PI * 0.85, -PI * 0.15, 16, col, ep * 0.6)
			c.draw_arc(o + Vector2(w * 0.5, w * 0.25), w * 0.45, PI * 0.15, PI * 0.85, 16, col, ep * 0.6)
			c.draw_circle(o + Vector2(w * 0.5, w * 0.5), w * 0.12, col)


func _tex_dans(c: Control, r: Rect2, t: Texture2D) -> void:   # texture contenue dans r, centrée
	if t == null:
		return
	var k := minf(r.size.x / t.get_size().x, r.size.y / t.get_size().y)
	var s := t.get_size() * k
	c.draw_texture_rect(t, Rect2(r.position + (r.size - s) * 0.5, s), false)


func _mini_case(c: Control, r: Rect2, sorte: String) -> void:
	var o := r.position + r.size * 0.15
	var s := r.size.x * 0.7
	var h := s * 0.5
	match sorte:
		"":
			_mini_icone(c, r, "croix", C_ROUGE)
		"tube":
			for k in 2:
				var x0 := o.x + k * h
				c.draw_rect(Rect2(Vector2(x0, o.y + h * 0.5), Vector2(h, h)), Color("#8A8A80"), false, 2.0)
				c.draw_line(Vector2(x0, o.y + h * 1.5), Vector2(x0 + h, o.y + h * 0.5), Color("#8A8A80"), 2.0)
		"poutre":
			c.draw_rect(Rect2(Vector2(o.x, o.y + h * 0.5), Vector2(s, h * 0.18)), Color("#5A5A52"))
			c.draw_rect(Rect2(Vector2(o.x, o.y + h * 0.68), Vector2(s, h * 0.64)), Color("#3A3A34"))
			c.draw_rect(Rect2(Vector2(o.x, o.y + h * 1.32), Vector2(s, h * 0.18)), Color("#5A5A52"))
		_:
			var col := Color("#4C5236") if sorte == "blindage" else Color("#77736A")
			for k in 2:
				c.draw_rect(Rect2(Vector2(o.x + k * h, o.y + h * 0.5), Vector2(h - 3, h - 3)), col)


func _mini_essieu(c: Control, r: Rect2, pont: bool) -> void:
	var w := r.size.x
	var o := r.position
	c.draw_line(o + Vector2(w * 0.1, w * 0.5), o + Vector2(w * 0.9, w * 0.5), Color("#8C867A"), w * 0.08)
	for x in [0.15, 0.85]:
		c.draw_circle(o + Vector2(w * x, w * 0.5), w * 0.1, Color("#C9C6BC"))
	if pont:
		c.draw_circle(o + Vector2(w * 0.5, w * 0.5), w * 0.16, Color("#3C3C3A"))


func _mini_roue(c: Control, r: Rect2, id: String) -> void:
	var f := Assemblage.piece(id)
	if String(f.get("type", "")) == "chenilles":
		var o := r.position + Vector2(0, r.size.y * 0.3)
		var rr := Rect2(o + Vector2(r.size.x * 0.05, 0), Vector2(r.size.x * 0.9, r.size.y * 0.4))
		c.draw_rect(rr, Color("#1E1D1B"))
		for k in 4:
			c.draw_circle(rr.position + Vector2(rr.size.x * (0.14 + 0.24 * k), rr.size.y * 0.5), rr.size.y * 0.32, Color("#5A5650"))
		return
	var d := float(f.get("diametre_cases", 2))
	var k := clampf(d / 8.0, 0.35, 1.0)   # une grande roue paraît grande
	var s := r.size * k
	var t := VehiculeDessin._tex("roue_petite" if d < 2.5 else ("roue_moyenne" if d < 4.0 else "roue_grande"))
	c.draw_texture_rect(t, Rect2(r.position + Vector2((r.size.x - s.x) * 0.5, r.size.y - s.y), s), false)


func _mini_liaison(c: Control, r: Rect2, dessin: String) -> void:
	var formes := []
	ConstructionLibre._formes_liaison(formes, dessin, 0.65, 1.0, 0.35, true)
	_mini_formes(c, r, formes, Rect2(0.0, 0.1, 2.2, 1.0))


func _mini_couleur(c: Control, r: Rect2, hex: String) -> void:
	if hex == "":
		c.draw_rect(r.grow(-r.size.x * 0.15), Color("#77736A"), false, 3.0)
		_mini_icone(c, r.grow(-r.size.x * 0.2), "croix", C_DISCRET)
		return
	c.draw_rect(r.grow(-r.size.x * 0.12), Color(hex))
	c.draw_rect(r.grow(-r.size.x * 0.12), Color(1, 1, 1, 0.3), false, 2.0)


func _mini_piece_ou_roue(c: Control, r: Rect2, id: String) -> void:
	var fam := String(Assemblage.piece(id).get("famille", ""))
	if fam in ConstructionLibre.FAMILLES_PIECES:
		_mini_piece(c, r, id)
	elif fam == "liaison":
		_mini_liaison(c, r, String(Assemblage.piece(id).get("dessin", "lames")))
	else:
		_mini_roue(c, r, id)


# Miniature du vrai dessin d'une pièce : la pièce seule passée par ConstructionLibre.forme (mise en cache)
func _mini_piece(c: Control, r: Rect2, id: String) -> void:
	var f := Assemblage.piece(id)
	if f.get("famille", "") == "arme":
		var w := String(f.arme)
		var sid := "arme_mortier" if w == "mortier" else ("arme_lance_flammes" if w == "lance_flammes" else ("arme_mitrailleuse" if w.begins_with("mitrailleuse") else ("arme_canon_37" if w.contains("leger") else ("arme_canon_88" if w.contains("88") else "arme_canon_75"))))
		_tex_dans(c, r, VehiculeDessin._tex(sid))
		return
	if not _minis.has(id):
		var seule := {"libre": true, "nom": "", "cases": [], "essieux": [], "pieces": [{"piece": id, "pos": [0, 0]}]}
		_minis[id] = ConstructionLibre.forme(seule).formes
	var e: Array = f.get("emprise", [1, 1])
	_mini_formes(c, r, _minis[id], Rect2(0.0, 0.0, float(e[0]) * ConstructionLibre.C, float(e[1]) * ConstructionLibre.C))


# Dessine des formes (mètres, y vers le haut) contenues dans `bornes`, centrées dans r
func _mini_formes(c: Control, r: Rect2, formes: Array, bornes: Rect2) -> void:
	var k := minf(r.size.x / maxf(0.01, bornes.size.x), r.size.y / maxf(0.01, bornes.size.y))
	var off := r.position + Vector2((r.size.x - bornes.size.x * k) * 0.5, r.size.y - (r.size.y - bornes.size.y * k) * 0.5)
	var P := func(q) -> Vector2: return off + Vector2((float(q[0]) - bornes.position.x) * k, -(float(q[1]) - bornes.position.y) * k)
	var teinte := Color(String(a.get("peinture", "#5E6238")))
	for z in [-1, 0, 1, 2, 3]:
		for fo in formes:
			if int(fo.get("z", 1)) != z:
				continue
			var col := _coul(String(fo.get("c", "caisse")), teinte)
			if fo.has("pts"):
				var pts := PackedVector2Array()
				for q in fo.pts:
					pts.append(P.call(q))
				if pts.size() >= 3:
					c.draw_colored_polygon(pts, col)
			elif fo.has("ligne"):
				c.draw_line(P.call(fo.ligne[0]), P.call(fo.ligne[1]), col, maxf(1.5, float(fo.get("ep", 0.04)) * k))
			elif fo.has("sprite"):
				var q: Array = fo.r
				var t := VehiculeDessin._tex(String(fo.sprite))
				var hg: Vector2 = P.call([q[0], float(q[1]) + float(q[3])])
				var dst := Rect2(hg, Vector2(float(q[2]), float(q[3])) * k)
				if bool(fo.get("miroir", false)):
					dst = Rect2(hg + Vector2(dst.size.x, 0), Vector2(-dst.size.x, dst.size.y))
				var uv: Array = fo.get("uv", [])
				if uv.size() == 4:
					var ts := t.get_size()
					c.draw_texture_rect_region(t, dst, Rect2(float(uv[0]) * ts.x, float(uv[1]) * ts.y, (float(uv[2]) - float(uv[0])) * ts.x, (float(uv[3]) - float(uv[1])) * ts.y))
				else:
					c.draw_texture_rect(t, dst, false)


static func _coul(nom: String, teinte: Color) -> Color:
	match nom:
		"caisse": return teinte
		"sombre": return teinte.darkened(0.38)
		"clair": return teinte.lightened(0.18)
		"vitre": return Color("#2E3A40")
		"metal": return Color("#3C3C3A")
		"pneu": return Color("#1E1D1B")
		"bois": return Color("#6D5032")
		"toile": return Color("#8A8460")
	return Color(nom)
