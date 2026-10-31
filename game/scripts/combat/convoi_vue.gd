# Mode convoi : vue de profil du convoi, des ennemis et des bâtiments, avec les ordres tactiques.
class_name ConvoiVue
extends "res://scripts/combat/vue_interface.gd"


# --- Construction ----------------------------------------------------------
func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	theme = _theme()
	terrain = Terrain.new()
	terrain.ppm = ppm
	terrain.sol_y = SOL_Y
	terrain.ancre_x = 150.0
	terrain.z_index = -10   # le décor reste derrière véhicules, épaves et bâtiments
	add_child(terrain)
	couche = Control.new()
	couche.mouse_filter = MOUSE_FILTER_IGNORE
	couche.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(couche)
	fx = FxVue.new()
	fx.vue = self
	fx.mouse_filter = MOUSE_FILTER_IGNORE
	fx.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(fx)
	_construire_interface()
	var sv := _charger_sauvegarde()
	if sv.is_empty():
		_nouvelle_partie(int(Time.get_ticks_msec()) % 100000 + 1)
	else:
		_nouvelle_partie(int(sv.graine), sv)


# --- Sauvegarde : reprise après rechargement de la page (iPhone) ---------------------
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_sauver_vue()

func _input(e: InputEvent) -> void:
	# Le premier toucher peut tomber sur un bouton : on débloque l'audio sur n'importe quelle entrée
	if not _audio_ok and ((e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed) or (e is InputEventKey and e.pressed)):
		_demarrer_audio()

func _unhandled_key_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_SPACE: _basculer_pause()
			KEY_1: vitesse_sim = 1
			KEY_2: vitesse_sim = 2
			KEY_3: vitesse_sim = 3


# --- Boucle ----------------------------------------------------------------
func _process(delta: float) -> void:
	_temps += delta
	_ord_t = maxf(0.0, _ord_t - delta)
	_save_t += delta
	if _save_t >= 10.0:
		_save_t = 0.0
		if m.fini:
			_effacer_sauvegarde()
		else:
			_sauver_vue()
	if not pause and not m.fini:
		_acc += delta * vitesse_sim
		var pas := 0
		while _acc >= DT and pas < 8:
			m.avancer()
			_acc -= DT
			pas += 1
		_acc = minf(_acc, DT)
	_alpha = clampf(_acc / DT, 0.0, 1.0)
	for e in m.vider_evenements():
		_evenement(e)
	_vieillir(delta)
	terrain.nuit = m.monde.obscurite()
	_camera(delta)
	_synchroniser()
	_maj_persos(0.0 if pause else delta * vitesse_sim)
	_maj_sons()
	_maj_interface()

func _camera(delta: float) -> void:
	var gauche: float = _rx(m.convoi.back()) if not m.convoi.is_empty() else _rtete() - 20.0
	var droite := _rtete() + 20.0
	var plafond := 62.0
	for e in m.ennemis:
		if e.actif() and e.x - m.x_tete < 85.0:
			droite = maxf(droite, _rx(e) + e.longueur + 3.0)
	for b in m.batiments:
		var proche: bool = b.x - m.x_tete < 85.0 and b.x + b.longueur > gauche - 40.0
		if ((b.actif() or b.ami) and b.x - m.x_tete < 85.0) or (b.garnison.size() > 0 and proche):
			droite = maxf(droite, b.x + b.longueur + 3.0)
			if b.garnison.size() > 0:
				gauche = minf(gauche, b.x - 2.0)
		if proche:
			plafond = minf(plafond, 600.0 / b.hauteur)   # un grand bâtiment (église) doit tenir à l'écran
	var span := maxf(droite - gauche + 4.0, 26.0)
	var cible := clampf(1560.0 / span, 24.0, plafond)
	ppm = lerpf(ppm, cible, 1.0 - exp(-2.2 * delta))
	terrain.ppm = ppm
	if not (_pressing and _drag):
		_look_t -= delta
		if _look_t <= 0.0:
			_look_x = lerpf(_look_x, 0.0, 1.0 - exp(-2.5 * delta))
	terrain.camera_x = lerpf(terrain.camera_x, gauche - 2.0 + _look_x, 1.0 - exp(-4.0 * delta))
	var centre: float = (gauche + droite) * 0.5 + _look_x
	cam_h = lerpf(cam_h, Terrain.sol(centre) * 0.6 + Terrain.sol(_rtete()) * 0.4 - 0.5, 1.0 - exp(-3.0 * delta))
	terrain.sol_y = SOL_Y + cam_h * ppm

func _synchroniser() -> void:
	var vus := {}
	for v in m.convoi + m.ennemis + m.epaves:
		vus[v.uid] = true
		var n: VehiculeDessin = noeuds.get(v.uid)
		if n != null and n.ennemi != (v.camp == "ennemi"):
			n.queue_free()   # véhicule récupéré : il change de camp
			noeuds.erase(v.uid)
			n = null
		if n == null:
			n = VehiculeDessin.new()
			n.type = v.type
			n.ppm = ppm
			n.ennemi = v.camp == "ennemi"
			n.miroir = v.camp == "ennemi"
			n.sol = Terrain.bosses
			couche.add_child(n)
			noeuds[v.uid] = n
		if absf(n.ppm - ppm) > 0.01 and not n.D.is_empty():
			n.ppm = ppm
			n.size = Vector2(n.D.longueur, n.D.hauteur) * ppm
			n.custom_minimum_size = n.size
		var x := _rx(v)
		n.x_monde = x
		n.vitesse = v.vitesse_act if (v.actif() and not pause) else 0.0
		n.equipage = v.actif()
		n.modulate = Color.WHITE if v.actif() else (Color(0.82, 0.8, 0.78) if v.recuperable() else Color(0.4, 0.38, 0.36))
		if v.camo_voulu:
			n.modulate = Color(0.55, 0.66, 0.5, 0.45 if v.camoufle else 0.8)
		n.modulate = n.modulate * Color.WHITE.lerp(Color(0.5, 0.55, 0.75), terrain.nuit)
		n.z_index = 0 if v.actif() else -1   # les épaves passent derrière les véhicules
		var cxv: float = x + v.longueur * 0.5
		n.pivot_offset = Vector2(n.size.x * 0.5, n.size.y)
		n.position = Vector2(terrain.ecran_x(cxv) - n.size.x * 0.5, _sy(cxv, true) - n.size.y)
		n.rotation = -atan2(Terrain.relief(x + v.longueur) - Terrain.relief(x), v.longueur)
		n.visible = v.garage == 0
	for b in m.batiments:
		vus[b.uid] = true
		var n: BatimentDessin = noeuds.get(b.uid)
		if n == null:
			n = BatimentDessin.new()
			n.bat = b
			n.ppm = ppm
			couche.add_child(n)
			noeuds[b.uid] = n
		n.ppm = ppm
		n.size = Vector2(b.longueur, b.hauteur) * ppm
		n.position = Vector2(terrain.ecran_x(b.x), _sy(b.x + b.longueur * 0.5) - n.size.y + 2.0)
		n.modulate = Color.WHITE.lerp(Color(0.42, 0.48, 0.72), terrain.nuit)
		n.z_index = -2
	for uid in noeuds.keys():
		if not vus.has(uid):
			noeuds[uid].queue_free()
			noeuds.erase(uid)


# --- Panneau d'état d'un véhicule (au toucher) ------------------------------
func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_pressing = true
			_drag = false
			_press = e.position
		else:
			if _pressing and not _drag:
				_tap(e.position)
			_pressing = false
			_drag = false
	elif e is InputEventMouseMotion and _pressing:
		if not _drag and e.position.distance_to(_press) > 16.0:
			_drag = true
		if _drag:
			_look_x = clampf(_look_x - e.relative.x / ppm, -70.0, 70.0)
			_look_t = 3.0
			accept_event()

func _tap(p: Vector2) -> void:
	_demarrer_audio()
	for ic in _icones:
		if ic.rect.has_point(p):
			_action_icone(ic)
			accept_event()
			return
	var trouve := 0
	for v in m.convoi + m.epaves:
		if v.statut == "epave":
			continue
		var D: Dictionary = VehiculeDessin.donnees().vehicules[v.type]
		var r := Rect2(Vector2(terrain.ecran_x(_rx(v)) - 12.0, _sy(_rx(v) + v.longueur * 0.5) - float(D.hauteur) * ppm - 50.0), Vector2(v.longueur * ppm + 24.0, float(D.hauteur) * ppm + 60.0))
		if r.has_point(p):
			trouve = v.uid
	ouvert = 0 if trouve == ouvert else trouve
	_bande_on = m.trouver(trouve) in m.convoi
	if _bande_on:
		selection = trouve
	accept_event()

func _action_icone(ic: Dictionary) -> void:
	var v = m.trouver(ic.uid)
	if not (v is CombatModele.Veh):
		return
	if ic.has("action"):
		if m.ordres.marche != "halte":
			m.ordre_marche("halte")
		if m.rejoindre(ic.uid):
			ouvert = 0
		return
	if v.reparation and v.rep_piece == ic.piece:
		m.ordre_reparer(ic.uid, false)
		return
	if m.ordres.marche != "halte":
		m.ordre_marche("halte")
	m.ordre_reparer(ic.uid, true, ic.piece)
