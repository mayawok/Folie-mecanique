# Couche 2 de la vue du convoi : camp de réparation, survivants, carte, halte et villes (DEC-140 à 143).
# Chaîne : vue_base <- vue_dessin <- vue_ville <- vue_interface <- convoi_vue (ConvoiVue).
# Une couche n'appelle une fonction d'une couche plus haute que par call("nom", ...).
extends "res://scripts/combat/vue_dessin.gd"

# --- Camp de réparation (DEV-018) -----------------------------------------------------------------
# Option à proposer : la réparation qui correspond à la panne (essieu ou roues cassés, moteur HS), sinon la première possible
func _option_camp(v) -> Dictionary:
	var opts: Array = m.camp_options(v.uid)
	var voulu := ""
	if not v.piece_ok("roulement"):
		voulu = "changer_essieu"
	elif not v.piece_ok("moteur"):
		voulu = "changer_moteur"
	for o in opts:
		if String(o.op) == voulu:
			return o
	return opts[0] if not opts.is_empty() else {}


func _maj_bouton_camp(sel) -> void:
	if m.camp_actif():
		var pause_camp: bool = String(m.camp_rep.camp.etat) == "interrompue"
		_btn_camp.text = Textes.t("vue_interface.001") if pause_camp else "Interrompre le camp"
		_btn_camp.disabled = false
		return
	var o := _option_camp(sel)
	if o.is_empty():
		_btn_camp.text = Textes.t("vue_interface.002")
		_btn_camp.disabled = true
		return
	var en_vue: bool = not m.ennemis.filter(func(e): return e.actif()).is_empty()
	_btn_camp.text = Textes.t("vue_interface.003", [String(o.nom).to_lower(), int(ceil(float(o.duree_s) / 60.0))])
	_btn_camp.disabled = not bool(o.ok) or en_vue
	if not bool(o.ok):
		_btn_camp.text += " — " + String(o.raison)
	elif en_vue:
		_btn_camp.text += " — ennemis en vue"


func _action_camp() -> void:
	_demarrer_audio()
	if m.camp_actif():
		if String(m.camp_rep.camp.etat) == "interrompue":
			m.camp_reprendre()
		else:
			m.camp_interrompre()
		return
	var sel = m.trouver(selection)
	if not (sel is CombatModele.Veh):
		return
	var o := _option_camp(sel)
	if not o.is_empty():
		m.camp_etablir(sel.uid, String(o.op), o.params)


func _texte_camp() -> String:
	var C: Dictionary = m.camp_rep.camp
	var fait := 1.0 - float(C.restant_s) / maxf(1.0, float(C.duree_s))
	var etat := "TRAVAUX INTERROMPUS" if String(C.etat) == "interrompue" else "CAMP DE RÉPARATION"
	var l := "%s : %d %%, encore %d s" % [etat, int(fait * 100.0), int(ceil(float(C.restant_s)))]
	if not m.ennemis.filter(func(e): return e.actif()).is_empty():
		l += "\nATTAQUE : défendez le camp, les travaux sont suspendus."
	return l


func _ouvrir_surv() -> void:
	_pause_surv = pause
	pause = true
	_surv_sel = {}
	_surv_sig = ""
	_voile_surv.visible = true

func _fermer_surv() -> void:
	_voile_surv.visible = false
	pause = _pause_surv

func _maj_survivants() -> void:
	var liste: Array = m.liste_survivants()
	var sig := str(_surv_sel)
	for q in liste:
		sig += "%s%d%s%d|" % [q.nom, int(q.pv), q.lieu, q.veh_uid]
	sig += str(m.ordres.marche)
	if sig == _surv_sig:
		return
	_surv_sig = sig
	for ch in _liste_surv.get_children():
		ch.queue_free()
	for ch in _pied_surv.get_children():
		ch.queue_free()
	for q in liste:
		var ligne := HBoxContainer.new()
		ligne.add_theme_constant_override("separation", 20)
		_liste_surv.add_child(ligne)
		var ln := _label(q.nom, ligne, 28)
		ln.custom_minimum_size = Vector2(260, 0)
		var etat: String = m.etat_sante(q.pv)
		var le := _label("%s (%d/%d)" % [etat, int(q.pv), int(m.donnees().equipage_pv)], ligne, 26, {"En forme": C_VERT, "Blessé": C_ORANGE, "Gravement blessé": C_ROUGE, "Hors de combat": C_DISCRET}[etat])
		le.custom_minimum_size = Vector2(380, 0)
		var ll := _label(q.lieu, ligne, 31, C_DISCRET)
		ll.custom_minimum_size = Vector2(300, 0)
		if q.veh_uid >= 0 and q.pv > 0.0:
			var qq: Dictionary = q
			_bouton("Affecter", func():
				_surv_sel = {"veh": qq.veh_uid, "idx": qq.idx, "nom": qq.nom}
				_surv_sig = "", ligne, 190)
	if not _surv_sel.is_empty():
		_label("Affecter %s à :" % _surv_sel.nom, _pied_surv, 28, C_ACCENT)
		var rang := HBoxContainer.new()
		rang.add_theme_constant_override("separation", 12)
		_pied_surv.add_child(rang)
		for v in m.convoi:
			if v.uid != _surv_sel.veh and v.actif():
				var libre: bool = v.equipage.size() < int(v.profil.equipage)
				var vuid: int = v.uid
				var bb := _bouton("%s (%d/%d)" % [v.nom, v.equipage.size(), int(v.profil.equipage)], func():
					if m.affecter(_surv_sel.veh, _surv_sel.idx, vuid):
						_surv_sel = {}
					_surv_sig = "", rang, 0)
				bb.disabled = not libre
		_bouton("Annuler", func(): _surv_sel = {}; _surv_sig = "", rang, 0)
	if m.ordres.marche != "halte":
		_label("Mettez le convoi en Halte pour changer les affectations.", _pied_surv, 29, C_ORANGE)

func _ouvrir_carte() -> void:
	_pause_avant = pause
	pause = true
	_carte_sel = -1
	_voile_carte.visible = true
	_aide("002")
	_carte_ctl.queue_redraw()

func _fermer_carte() -> void:
	_voile_carte.visible = false
	pause = _pause_avant

func _partir() -> void:
	if m.ville_dedans():   # depuis une ville, on part par la porte de sortie (DEC-141)
		if _carte_sel >= 0 and m.ville_partir(_carte_sel):
			_fermer_carte()
		return
	if _carte_sel >= 0 and m.monde.choisir_destination(_carte_sel):
		m.ordre_marche("avancer")
		_fermer_carte()

# --- Ville (DEC-140 à DEC-143) ----------------------------------------------------------------
# Panneau de halte dans la nature (DEC-161) : visible quand le convoi est arrêté hors d'une ville
var _panneau_halte: VBoxContainer
var _halte_sig := ""

func _construire_halte() -> void:
	_panneau_halte = VBoxContainer.new()
	_panneau_halte.add_theme_constant_override("separation", 4)
	_panneau_halte.set_anchors_and_offsets_preset(PRESET_BOTTOM_RIGHT)
	_panneau_halte.offset_left = -440
	_panneau_halte.offset_right = -16
	_panneau_halte.offset_bottom = -BARRE_H - 136
	_panneau_halte.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_panneau_halte)


func _maj_halte() -> void:
	var montrer: bool = m.ordres.marche == "halte" and not m.ville_dedans() and not m.ville_protegee() and not m.convoi.is_empty()
	_panneau_halte.visible = montrer
	if not montrer:
		return
	var H: Dictionary = m.halte
	var sig := "%s|%s|%s|%d|%s" % [H.get("mode", ""), H.get("pret", false), H.get("nuit", false), m.cache_proche(), m._eclaireurs_t > 0.0]
	if sig == _halte_sig:
		return
	_halte_sig = sig
	for ch in _panneau_halte.get_children():
		ch.queue_free()
	if H.is_empty():
		_bouton("Monter le camp", func(): m.halte_bivouac(false), _panneau_halte, 300)
		_bouton("Camper pour la nuit", func(): m.halte_bivouac(true), _panneau_halte, 300)
		_bouton("Surveiller et réparer", func(): m.halte_garde(), _panneau_halte, 300)
		_bouton("Tendre une embuscade", func(): _embuscade(), _panneau_halte, 300)
	else:
		var b := _bouton("Éclaireurs partis…" if m._eclaireurs_t > 0.0 else "Envoyer des éclaireurs", func(): m.envoyer_eclaireurs(), _panneau_halte, 300)
		b.disabled = m._eclaireurs_t > 0.0
		_bouton("Faire une cache (un quart des réserves)", func(): _cache_quart(), _panneau_halte, 300)
		_bouton("Lever le camp", func(): m.halte_lever(), _panneau_halte, 300)
	if m.cache_proche() >= 0:
		_bouton("Déterrer la cache", func(): m.cache_reprendre(), _panneau_halte, 300)


func _deposer_quart() -> void:
	var res := {}
	for k in ["gazole", "essence", "ammo", "metal", "eau", "vivres"]:
		var q := floorf(float(m.stocks.get(k, 0.0)) * 0.25)
		if q > 0.0:
			res[k] = q
	m.ville_deposer(res)


func _cache_quart() -> void:
	var res := {}
	for k in ["gazole", "essence", "ammo", "metal", "eau", "vivres"]:
		var q := floorf(float(m.stocks.get(k, 0.0)) * 0.25)
		if q > 0.0:
			res[k] = q
	if not res.is_empty():
		m.cache_creer(res)

# Bouton de marche unique (DEC-160) : toucher = halte, glisser vers la droite = avancer, vers la gauche = reculer.
# En ville, le toucher ouvre le choix de la sortie comme avant.
const GLISSE_MARCHE_PX := BoutonMarche.SEUIL_PX

func action_marche_geste(dx: float) -> void:
	if m.ville_dedans() or (m.ville_protegee() and absf(dx) < GLISSE_MARCHE_PX):
		_action_marche()
		return
	if dx > GLISSE_MARCHE_PX:
		m.ordre_marche("avancer")
	elif dx < -GLISSE_MARCHE_PX:
		m.ordre_marche("recul")
	else:
		m.ordre_marche("halte")


func _action_marche() -> void:
	if m.ville_dedans():
		_ville_onglet = "sorties"
		_ville_ferme = false
		_dial_sig = ""
		return
	m.ordre_marche("halte" if m.ordres.marche == "avancer" else "avancer")

func _ville_aller(onglet: String) -> void:
	_ville_onglet = onglet
	_dial_sig = ""

func _remplir_ville() -> void:
	for ch in _boite_dial.get_children():
		ch.queue_free()
	var V: Dictionary = m.ville
	if m.ville_pillee() and _ville_onglet != "bilan":   # ville pillée : le récit du rescapé et la poursuite (DEC-151)
		_lbl_dial_titre.text = Textes.t("vue_interface.004", [V.nom])
		_lbl_dial_texte.text = String(CombatModele.VD().variantes.pillee.recit)
		_dialogue_bouton("Prendre la poursuite", func(): m.ville_poursuite(), m.evenement.is_empty())
		_dialogue_bouton("Fermer", func(): _ville_ferme = true)
		return
	match "mission" if _ville_onglet.begins_with("mission:") else _ville_onglet:
		"maire":
			_lbl_dial_titre.text = Textes.t("vue_interface.005", [V.nom])
			var offres: Array = m.mission_offres()
			if offres.is_empty():
				_lbl_dial_texte.text = m.ville_texte_maire()
			else:   # le maire propose ses missions (DEC-144)
				_lbl_dial_texte.text = Textes.t("vue_interface.006", [V.maire, V.nom])
				for o in offres:
					var ty: String = o.type
					_dialogue_bouton("%s pour %s (%d m)" % [o.nom, o.dest_nom, o.distance_m], func(): _ville_aller("mission:" + ty))
			_dialogue_bouton("Retour", func(): _ville_aller("accueil"))
		"marche":   # eau et vivres contre du métal (DEC-148)
			_lbl_dial_titre.text = Textes.t("vue_interface.007", [V.nom])
			_lbl_dial_texte.text = "Bidons d'eau et caisses de vivres, par lots de %d. Il vous reste %d jours d'eau et %d jours de vivres pour %d bouches." % [
				int(CombatModele.VD().marche.lot), int(minf(m.jours_de("eau"), 99.0)), int(minf(m.jours_de("vivres"), 99.0)), m.survivants_nourris()]
			for k in ["eau", "vivres"]:
				var kk: String = k
				var p: int = m.ville_prix_lot(kk)
				_dialogue_bouton("Acheter %d %s (%d métal)" % [int(CombatModele.VD().marche.lot), "bidons d'eau" if kk == "eau" else "caisses de vivres", p], func(): m.ville_acheter(kk); _ville_aller("marche"), m.bac_a_sable or m.stocks.metal >= p)
			_dialogue_bouton("Déposer un quart des réserves (reçu)", func(): _deposer_quart(); _ville_aller("marche"))   # DEC-157
			_dialogue_bouton("Présenter mes reçus (%d)" % m.recus.size(), func(): m.ville_retirer(); _ville_aller("marche"), not m.recus.is_empty())
			_dialogue_bouton("Retour", func(): _ville_aller("accueil"))
		"bilan":
			var b: Dictionary = m.mission_bilan
			_lbl_dial_titre.text = String(b.get("titre", V.nom))
			_lbl_dial_texte.text = String(b.get("texte", ""))
			_dialogue_bouton("Continuer", func(): _ville_aller("accueil"))
		"garage":
			_lbl_dial_titre.text = Textes.t("vue_interface.008")
			var c: int = m.ville_cout_reparation()
			if m.ville_a_reparer():
				_lbl_dial_texte.text = Textes.t("vue_interface.009", [(0 if m.bac_a_sable else c)])
				_dialogue_bouton("Faire réparer tout le convoi", func(): m.ville_reparer(); _ville_aller("garage"), m.bac_a_sable or m.stocks.metal >= c)
			else:
				_lbl_dial_texte.text = Textes.t("vue_interface.010")
			_dialogue_bouton("Retour", func(): _ville_aller("accueil"))
		"atelier":
			_lbl_dial_titre.text = Textes.t("vue_interface.011", [V.nom])
			_lbl_dial_texte.text = Textes.t("vue_interface.012")
			var vp = m.vehicule_principal()
			var cible: int = selection if m.trouver(selection) in m.convoi else (vp.uid if vp != null else 0)
			_dialogue_bouton("Ouvrir la grille", func(): call("_ouvrir_editeur", cible), cible != 0)
			_dialogue_bouton("Transformer (rallonge, plateau, blindage)", func(): call("_ouvrir_transformation", cible), cible != 0)
			_dialogue_bouton("Retour", func(): _ville_aller("accueil"))
		"sorties":
			_lbl_dial_titre.text = Textes.t("vue_interface.013", [V.nom])
			_lbl_dial_texte.text = Textes.t("vue_interface.014")
			for o in m.ville_sorties():
				var dest: int = o.id
				var t := "%s : %s, niveau %d, %d m" % [o.porte, o.secteur, o.niveau, o.distance_m]
				if String(o.ville) != "":
					t += " (ville : %s)" % o.ville
				_dialogue_bouton(t, func(): m.ville_partir(dest))
			_dialogue_bouton("Rester", func(): _ville_aller("accueil"))
		"mission":
			var ty: String = _ville_onglet.substr(8)
			var offre := {}
			for o in m.mission_offres():
				if o.type == ty:
					offre = o
			_lbl_dial_titre.text = Textes.t("vue_interface.015", [String(offre.get("nom", ty)).to_lower()])
			_lbl_dial_texte.text = String(offre.get("texte", ""))
			_dialogue_bouton("Accepter", func(): m.mission_accepter(ty), not offre.is_empty())
			_dialogue_bouton("Refuser", func(): _ville_aller("maire"))
		_:
			_lbl_dial_titre.text = V.nom
			_lbl_dial_texte.text = Textes.t("vue_interface.016")
			_dialogue_bouton("Mairie : parler au maire (missions)", func(): _ville_aller("maire"))
			_dialogue_bouton("Marché : eau et vivres", func(): _ville_aller("marche"))
			_dialogue_bouton("Garage : le mécanicien", func(): _ville_aller("garage"))
			_dialogue_bouton("Atelier : la grille", func(): _ville_aller("atelier"))
			_dialogue_bouton("Repartir : choisir la sortie", func(): _ville_aller("sorties"))
			_dialogue_bouton("Fermer", func(): _ville_ferme = true)

func _dialogue_bouton(texte: String, action: Callable, actif := true) -> void:
	var b := _bouton(texte, action, _boite_dial, 0)
	b.disabled = not actif
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _embuscade() -> void:
	m.ordre_marche("halte")
	var n := 0
	for v in m.convoi.duplicate():
		if m.ordre_debarquer(v.uid):
			n += 1
		m.ordre_camoufler(v.uid, true)
	if n == 0:
		m.log_(Textes.t("vue_interface.017"), "info")

func _reprendre_route() -> void:
	for v in m.convoi.duplicate():
		m.ordre_rembarquer(v.uid)
		m.ordre_camoufler(v.uid, false)

func _basculer_camo() -> void:
	var v = m.trouver(selection)
	if v is CombatModele.Veh:
		m.ordre_camoufler(v.uid, not v.camo_voulu)

func _basculer_pause() -> void:
	if _calque_pause == null:
		call("_construire_menu_pause")
	if _calque_pause.visible:
		call("_fermer_menu_pause")
	elif not _accueil_visible():
		_pause_avant_menu = pause
		pause = true
		_calque_pause.visible = true

func _basculer_feu() -> void:
	var v = m.trouver(selection)
	if v is CombatModele.Veh:
		m.ordre_tir(selection, not v.tir)

func _basculer_rep() -> void:
	var v = m.trouver(selection)
	if v is CombatModele.Veh:
		m.ordre_reparer(selection, not v.reparation)

func selectionner(uid: int) -> void:
	selection = uid
	_aide("001")
	_bande_on = true

func _demi_tour() -> void:
	if m.ordre_demi_tour():
		_ord_t = 0.0
		terrain.camera_x = m.convoi.back().x
		_look_x = 0.0
		for n in noeuds.values():
			n.queue_free()
		noeuds.clear()

func _basculer_garage() -> void:
	var v = m.trouver(selection)
	if v is CombatModele.Veh:
		if v.garage != 0:
			m.ordre_sortir(v.uid)
		else:
			m.ordre_garer(v.uid)


