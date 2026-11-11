# Couche 0 du modèle du convoi : constantes, entités (Veh, Bat), état, création. Aucune logique de dessin.
# Chaîne : modele_base <- modele_tir <- modele_terrain <- combat_modele (CombatModele).
extends RefCounted

const DT := 0.1
const PIECES_BASE := ["chassis", "roulement", "suspension", "moteur", "cabine"]
const NOMS := {"chassis": "Châssis", "roulement": "Roues", "suspension": "Suspension", "moteur": "Moteur", "cabine": "Cabine"}
const FENETRES := {
	"ferme": [[0.22, 0.52], [0.78, 0.52], [0.5, 0.80]],
	"maison": [[0.3, 0.45], [0.7, 0.45], [0.5, 0.78]],
	"grange": [[0.2, 0.5], [0.8, 0.5], [0.5, 0.76]],
	"eglise": [[0.80, 0.78], [0.80, 0.50], [0.30, 0.38]],
	"bunker": [[0.25, 0.40], [0.5, 0.40], [0.75, 0.40]],
	"camp_pillard": [[0.1, 0.66], [0.35, 0.66], [0.65, 0.66], [0.9, 0.66]],
	"camp_fortifie": [[0.08, 0.78], [0.28, 0.78], [0.5, 0.78], [0.72, 0.78], [0.92, 0.78], [0.5, 0.48]],
	"camp_ami": [],
	"hangar": [[0.2, 0.5], [0.8, 0.5], [0.5, 0.78]],
}

static var _data := {}
static func donnees() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open("res://data/combat_proto.json", FileAccess.READ)
		_data = JSON.parse_string(f.get_as_text())
	return _data

static func ancre(v, id: String, x := NAN) -> Vector2:
	var D: Dictionary = VehiculeDessin.donnees().vehicules[v.type]
	var L: float = D.longueur
	var H: float = D.hauteur
	var p := Vector2(L * 0.5, H * 0.4)
	match id:
		"roulement":
			p = Vector2(L * 0.5, 0.4)
		"suspension":
			p = Vector2(L * 0.35, 0.7)
		"moteur":
			p = Vector2(L * 0.85, H * 0.35)
		"cabine":
			p = Vector2(L * 0.45, H * 0.6)
			var eq: Array = D.get("equipage", [])
			if not eq.is_empty():
				p = Vector2(eq[0].x, eq[0].y + 0.5)
		"chassis":
			p = Vector2(L * 0.5, H * 0.3)
		_:
			if id.begins_with("a"):
				var armes: Array = D.get("armes", [])
				var i := int(id.substr(1))
				if i < armes.size():
					p = Vector2(armes[i].x + armes[i].long * 0.4, armes[i].y + armes[i].get("pied", 0.0) * 0.6)
	var vx: float = v.x if is_nan(x) else x
	return Vector2(vx + (L - p.x if v.camp == "ennemi" else p.x), p.y)

static func ecart(ax: float, al: float, bx: float, bl: float) -> float:
	return maxf(0.0, maxf(bx - (ax + al), ax - (bx + bl)))

static func genre_piece(id: String) -> String:
	return "arme" if id.begins_with("a") else id


# --- Entités ---------------------------------------------------------------
class Veh extends RefCounted:
	var uid := 0
	var type := ""
	var nom := ""
	var camp := "joueur"          # joueur | ennemi
	var profil: Dictionary
	var x := 0.0                  # bord arrière (gauche), mètres
	var longueur := 4.0
	var chenille := false
	var pieces := {}              # id -> {id, nom, pv, max}
	var armes: Array = []         # {piece, id, cd}
	var equipage: Array = []      # pv de chaque membre
	var noms: Array = []          # nom de chaque membre (même ordre)
	var statut := "actif"         # actif | abandonne | epave
	var mode := "approche"        # ennemis : approche | barrage
	var tir := true               # joueur : feu libre ou cessez-le-feu
	var reparation := false
	var rep_acc := 0.0
	var rep_pret := 0.0           # délai avant l'arrivée du mécanicien
	var rep_piece := ""           # pièce à réparer (vide = automatique)
	var x_prev := 0.0             # position au pas précédent (affichage fluide)
	var camo_voulu := false
	var garage := 0               # uid du bâtiment où le véhicule est rentré (réparation, à l'abri)
	var camo_t := 0.0
	var camoufle := false
	var x_cible := 0.0
	var vitesse_act := 0.0
	var butin := {}
	var butin_pris := false
	var assemblage := {}          # châssis + pièces placées (DEC-029)
	var troupes: Array = []       # pv des soldats assis sur les bancs (DEC-063)
	var allie := false            # convoi allié croisé sur la route (DEC-218) : ne tire pas, on ne lui tire pas dessus
	var salue := false
	var feu := 0.0                # secondes de combustion restantes (cocktail Molotov, réservoir qui explose, DEC-220)
	var feu_dps := 0.0
	var faction := ""             # id de faction (couleur de l'ennemi, DEC-221)
	var principal := false        # camion de l'expédition (Berliet) : gardé du début à la fin, ni abandonné ni démonté (DEC-139)
	var crevaison := 0.0   # secondes de pneus crevés (chausse-trappes) : l'ennemi ralentit
	var roues_perdues: Array = [] # indices des roues arrachées (DEC-080) : chacune ralentit, elles reviennent à la réparation
	var enlise_t := 0.0           # secondes passées enlisé avant l'arrivée des secours (physique des pneus, DEC-230)
	var degage := 0.0             # secondes restantes de marche au ralenti après un dégagement
	var enlise := false           # enlisé en ce moment (lu par la vue et le Kit)
	var ecart_acc := 0.0          # écart en plus ou en moins par rapport à sa place (effet accordéon, DEC-233)
	var u_suiv := 0.0             # vitesse retardée avec laquelle il suit la tête
	var cd_acc := 0.0             # délai entre deux tamponnements

	func remorque() -> bool:
		return bool(profil.get("remorque", false))

	func troupes_vivantes() -> int:
		var n := 0
		for pv in troupes:
			if pv > 0.0:
				n += 1
		return n

	# Un chef de char est assis au poste de commandement (ou a reçu ce rôle) : il reste à bord pendant les réparations
	func a_un_chef() -> bool:
		return profil.get("roles", []).has("chef") and equipage_vivant() > 0

	func actif() -> bool:
		return statut == "actif"

	# Véhicule laissé sur place mais entier : réparable et récupérable
	func recuperable() -> bool:
		return statut == "abandonne" or statut == "trouvee"

	func piece_ok(id: String) -> bool:
		return pieces.has(id) and pieces[id].pv > 0.0

	func ratio(id: String) -> float:
		return pieces[id].pv / pieces[id].max if pieces.has(id) else 0.0

	func equipage_vivant() -> int:
		var n := 0
		for pv in equipage:
			if pv > 0.0:
				n += 1
		return n

	func mobile() -> bool:
		return actif() and piece_ok("roulement") and piece_ok("moteur")

	func facteur_vitesse() -> float:
		var E: Dictionary = CombatModele.donnees().effets
		var f := 1.0
		if ratio("roulement") < E.seuil_bas:
			f *= E.roulement_bas
		if ratio("moteur") < E.seuil_bas:
			f *= E.moteur_bas
		if not piece_ok("suspension"):
			f *= E.suspension_hs_vitesse
		elif ratio("suspension") < E.seuil_bas:
			f *= E.suspension_bas
		f *= pow(float(E.get("roue_perdue", 0.75)), roues_perdues.size())
		if crevaison > 0.0:
			f *= float(E.get("crevaison_facteur", 0.35))
		f *= PhysiqueRoulage.facteur_vitesse(profil)   # pneus, surface et suspension (DEC-230)
		if enlise:
			var PH: Dictionary = PhysiqueRoulage.donnees()
			f *= float(PH.facteur_degagement) if degage > 0.0 else float(PH.facteur_enlise)
		return f

	func vitesse() -> float:
		return profil.vitesse * facteur_vitesse()

	func facteur_precision() -> float:
		var E: Dictionary = CombatModele.donnees().effets
		var f := 1.0
		if not piece_ok("suspension"):
			f *= E.suspension_hs_precision
		elif ratio("suspension") < E.seuil_bas:
			f *= E.suspension_bas_precision
		if not piece_ok("cabine"):
			f *= E.cabine_hs_precision
		if bool(profil.get("chef", false)):
			f *= float(CombatModele.donnees().equipage_roles.chef_precision)   # chef de char (DEC-050)
		f *= PhysiqueRoulage.facteur_precision(profil)   # secousses : suspension trop courte pour la vitesse et le sol (DEC-230)
		return f * float(profil.get("precision", 1.0))   # construction libre : recul, instabilité (DEC-043)

	func bord_avant() -> float:
		return x + longueur if camp == "joueur" else x

class Bat extends RefCounted:
	var uid := 0
	var fac := ""                 # faction propriétaire (id de la carte) : réputation (DEC-217)
	var type := ""
	var nom := ""
	var x := 0.0
	var longueur := 8.0           # largeur du bâtiment (même nom que Veh pour les calculs d'écart)
	var hauteur := 4.0
	var pv := 100.0
	var pv_max := 100.0
	var blindage := 5.0
	var tireurs: Array = []       # {pv, cd}
	var arme_fixe := ""
	var cd_fixe := 0.0
	var statut := "actif"         # actif | neutralise
	var garnison: Array = []      # survivants postés dans le bâtiment : {pv, cd, veh, premier, garde, slot}
	var revele_t := 0.0           # > 0 : l'ennemi a repéré la garnison
	var butin := {}
	var butin_pris := false
	var ami := false              # camp allié : ne tire pas, ne se cible pas
	var faction := 0
	var garage: Array = []        # uid des véhicules rentrés
	var garage_max := 0
	var barricade := 0.0          # 0..1 : planches clouées aux ouvertures
	var barricade_cible := false
	var blindage_base := 0.0
	var feu := false              # feu allumé à l'intérieur (nuit, garnison barricadée)

	func actif() -> bool:
		return statut == "actif" and not ami

	func fenetre(i: int) -> Vector2:
		var f: Array = CombatModele.FENETRES.get(type, [[0.5, 0.5]])
		var e: Array = f[mini(i, f.size() - 1)]
		return Vector2(x + e[0] * longueur, e[1] * hauteur)

	func garnison_vivants() -> int:
		var n := 0
		for g in garnison:
			if g.pv > 0.0:
				n += 1
		return n

	func tireurs_vivants() -> int:
		var n := 0
		for t in tireurs:
			if t.pv > 0.0:
				n += 1
		return n


# --- État de la partie -----------------------------------------------------
var graine := 1
var rng := RandomNumberGenerator.new()
var temps := 0.0
var fini := false
var convoi: Array = []            # Veh, indice 0 = tête
var ennemis: Array = []
var batiments: Array = []
var epaves: Array = []            # véhicules hors combat, fouillables
var stocks := {"ammo": 0.0, "gazole": 0.0, "essence": 0.0, "metal": 0.0}
var composants: Array = []        # {kind, classe, nom, etat}
var ordres := {"marche": "halte", "cible": "proche", "visee": "libre", "fouille": "auto"}
var x_tete := 0.0                 # bord avant du premier véhicule
var x_tete_prev := 0.0
var regime := 3                 # régime moteur du convoi, 1 (ralenti) à 5 (maximum) ; table dans combat_proto.json → regime

func regime_donnees() -> Dictionary:
	var T: Array = donnees().get("regime", [])
	return T[clampi(regime, 1, maxi(1, T.size())) - 1] if not T.is_empty() else {"nom": "Normal", "vitesse": 1.0, "conso": 1.0, "usure": 1.0}


func regime_suivant() -> void:
	regime = regime % maxi(1, donnees().get("regime", []).size()) + 1
	log_(Textes.t("base.001", [regime_donnees().nom]), "info")

var vitesse_convoi := 0.0
var trans := Transmission.etat_neuf()   # rapport, régime, démarrage, mode de conduite (DEC-232)
var blocage := ""                 # raison pour laquelle le convoi n'avance pas
var fouille_en_cours := {}
var journal: Array = []           # {t, txt, ton}
var evenements: Array = []        # effets pour la vue : tir, casse, epave, fouille
var distance_max := 0.0
var ennemis_detruits := 0
var _uid := 1
var _prochain_x := 130.0
var _n_rencontres := 0
var _alerte_muni := false
var pieges: Array = []            # chausse-trappes posées sur la route : {x, charges, t, touches}
var projectiles: Array = []       # balles et obus en vol : {a, b, t, T, touche, zone, ...}
var mines: Array = []             # {x, arme_t, armee}
var transits: Array = []          # équipages en marche vers un bâtiment ou un véhicule
var monde: MondeJeu
var fouille_demandee := 0         # uid du bâtiment ou de l'épave que le joueur veut fouiller
var _lore_dit := false
var _n_noms := 0
var reserve_survivants := 0      # recrues sans place : elles monteront dans le prochain véhicule
var berliet_config := BerlietConfig.defaut()   # (déplacé de combat_modele.gd : lu aussi par modele_mission.gd)
var pieces_stock: Array = []     # pièces de véhicule en réserve : {piece, etat} (grille, DEC-035)
var ouverture := false           # début de partie guidé : moto à assembler, trouvailles dans l'ordre
var etape_ouverture := 0         # indice de la prochaine trouvaille de l'ouverture
var bac_a_sable := false         # mode de développement : toutes les pièces, sans limite, métal infini (DEC-043)
var kit_calme := true             # Mode créatif : aucune rencontre, tempête, rôdeur ni champ de mines automatique (DEC-110)
var en_kit := false              # aucun véhicule encore assemblé
# Événements du monde (DEC-027, DEC-028) : actifs dans la partie jouée, désactivés pour les anciens tests d'équilibrage
var meteo_on := false
var champs_on := false
var tempete := {}                # {} | {phase: "annonce"|"active", reste, duree} (modele_meteo.gd)
var rng_meteo := RandomNumberGenerator.new()
var rng_mines := RandomNumberGenerator.new()
var rng_physique := RandomNumberGenerator.new()   # crevaisons au kilomètre (DEC-230)
var _tempete_t := 0.0            # délai avant la prochaine tempête
var _champ_id := 0
var _prochain_champ_x := 0.0
var demin := {}                  # déminage en cours : {champ, moyen, t}
var champ_traverse := false      # le joueur a choisi de traverser le champ à l'aveugle
var equip_demin := {"detecteur": false, "chien_pv": 0, "fleau_pv": 0.0}
var travaux := {}                # démontage en cours (grille G2) : {uid, reste}

# --- Ouverture guidée (utilisé par toutes les couches : calme, rencontres, événements) ---
func ouv() -> Dictionary:
	return donnees().get("ouverture", {})


# Vrai tant que les trouvailles de l'ouverture ne sont pas toutes apparues : pas d'ennemi.
func ouverture_en_cours() -> bool:
	return ouverture and etape_ouverture < ouv().get("etapes", []).size()


# Calme de l'ouverture : ni rencontre hostile ni rôdeurs tant que le joueur n'a pas trouvé d'arme.
func calme_ouverture() -> bool:
	if not ouverture:
		return false
	if ouverture_en_cours():
		return true
	for v in convoi:
		if not v.armes.is_empty():
			return false
	return not ids_stock().any(func(id): return Assemblage.piece(id).get("famille", "") == "arme")


# Villes (DEC-140) : redéfinies par modele_ville.gd ; ici, valeurs par défaut pour les couches inférieures
func ville_protegee() -> bool:
	return false

func ville_calme() -> bool:
	return false

func ville_zone(_x: float) -> bool:
	return false


func vehicule_principal():
	for v in convoi:
		if v.principal:
			return v
	return null


func ids_stock() -> Array:
	return pieces_stock.map(func(e): return e.piece)


func tempete_active() -> bool:
	return tempete.get("phase", "") == "active"

func tempete_annoncee() -> bool:
	return tempete.get("phase", "") == "annonce"

# Facteurs de la tempête, lus par le tir (précision) et la marche (vitesse)
func facteur_precision_meteo() -> float:
	return float(donnees().tempete.precision) if tempete_active() else 1.0

func facteur_vitesse_meteo() -> float:
	return float(donnees().tempete.vitesse) if tempete_active() else 1.0

func log_(txt: String, ton := "info") -> void:
	journal.append({"t": temps, "txt": txt, "ton": ton})
	if journal.size() > 60:
		journal.pop_front()

func evt(e: Dictionary) -> void:
	evenements.append(e)
	if evenements.size() > 300:
		evenements = evenements.slice(100)

func vider_evenements() -> Array:
	var e := evenements
	evenements = []
	return e


# --- Création --------------------------------------------------------------
func creer_vehicule(type: String, camp: String, x: float) -> Veh:
	var a := Assemblage.de_type(type)
	assert(not a.is_empty(), "Véhicule sans assemblage : %s" % type)
	return creer_depuis_assemblage(a, camp, x, type)

# Véhicule construit à partir d'un assemblage (châssis + pièces, DEC-029). Profil calculé, jamais saisi.
func creer_depuis_assemblage(a: Dictionary, camp: String, x: float, type := "", equipage := -1) -> Veh:
	var D := donnees()
	var v := Veh.new()
	v.uid = _uid
	_uid += 1
	v.camp = camp
	v.x = x
	v.x_prev = x
	appliquer_assemblage(v, a, {}, type)
	for i in (int(v.profil.equipage) if equipage < 0 else equipage):
		v.equipage.append(float(D.equipage_pv))
		v.noms.append(_nom_survivant())
	if camp == "ennemi" and D.feu.jets.has(v.type):   # pillards : cocktails Molotov et lances explosives (DEC-220)
		var wid: String = String(D.feu.jets[v.type])
		var pid := "a%d" % v.armes.size()
		v.profil = v.profil.duplicate()   # le profil peut être partagé : on n'y touche pas en place
		v.profil.armes = v.profil.armes + [wid]
		v.pieces[pid] = {"id": pid, "nom": D.armes[wid].nom, "pv": float(D.armes[wid].pv), "max": float(D.armes[wid].pv)}
		v.armes.append({"piece": pid, "id": wid, "cd": rng.randf_range(0.6, float(D.armes[wid].cadence)), "idx": v.armes.size()})
	return v

# (Re)construit un véhicule à partir d'un assemblage. etats : famille -> état 0..1 des pièces montées
# (pièces abîmées récupérées) ; une famille absente est neuve. L'équipage n'est pas touché.
func appliquer_assemblage(v: Veh, a: Dictionary, etats: Dictionary, type := "") -> void:
	var D := donnees()
	var p := Assemblage.statistiques(a)
	v.assemblage = a.duplicate(true)
	v.type = type if type != "" else FormeAssemblage.type_dessin(a)
	var forme: Dictionary = VehiculeDessin.donnees().vehicules[v.type]
	v.profil = p
	v.nom = forme.nom
	v.longueur = float(forme.longueur)
	v.chenille = forme.has("chenille")
	v.pieces = {}
	v.armes = []
	for id in PIECES_BASE:
		var pv := float(p.pv[id])
		v.pieces[id] = {"id": id, "nom": NOMS[id], "pv": pv * float(etats.get(id, 1.0)), "max": pv}
	if v.chenille:
		v.pieces.roulement.nom = "Chenilles"
	appliquer_valeurs_berliet(v)
	for i in p.armes.size():
		var wid: String = p.armes[i]
		var w: Dictionary = D.armes[wid]
		var pid := "a%d" % i
		v.pieces[pid] = {"id": pid, "nom": w.nom, "pv": float(w.pv) * float(etats.get("arme", 1.0)), "max": float(w.pv)}
		v.armes.append({"piece": pid, "id": wid, "cd": rng.randf_range(0.4, float(w.cadence)), "idx": i})

# --- Carburants : essence et gazole (DEC-094), capacité = réservoirs + citerne + bidons (DEC-190, DEC-206) ---
const CARBURANTS := ["gazole", "essence"]

func carburant_de(v) -> String:
	return String(v.profil.get("carburant", "essence"))

# Litres du réservoir d'un véhicule : le Berliet suit son niveau de réservoir (berliet.json), les autres leur châssis
func litres_reservoir(v) -> float:
	return float(v.profil.get("gazole_l", v.profil.get("reservoir", 0.0)))

func capacite_carburant(type: String) -> float:
	var C: Dictionary = donnees().carburants
	var c := float(C.bidons_l)
	for v in convoi:
		if v.statut == "actif" and carburant_de(v) == type:
			c += litres_reservoir(v)
			if v.type == "berliet_gdr" and String(berliet_config.module) == "citerne":
				c += float(C.citerne_l)
	return c

# Les stocks ne dépassent pas la capacité (le Mode créatif n'a pas de limite). Renvoie les litres perdus par carburant.
func borner_carburants() -> Dictionary:
	var perdu := {}
	if bac_a_sable:
		return perdu
	for t in CARBURANTS:
		var cap := capacite_carburant(t)
		var s := float(stocks.get(t, 0.0))
		if s > cap + 0.5:
			perdu[t] = s - cap
			stocks[t] = cap
	return perdu

# Premier carburant à sec parmi ceux que brûlent les véhicules actifs ("" si tout va bien)
func carburant_manquant() -> String:
	for t in CARBURANTS:
		if float(stocks.get(t, 0.0)) <= 0.0 and convoi.any(func(v): return v.actif() and carburant_de(v) == t and float(v.profil.conso) > 0.0):
			return Textes.t("carb." + t)
	return ""

# Niveau de rencontre ajouté hors de la région de la quête principale (DEC-172) ; redéfini par le Kit (modele_kit.gd)
func malus_hors_region() -> int:
	return monde.malus_region()

# Valeurs de jeu du Berliet GDR (DEV-022) : le profil de l'assemblage reste la base ; pneus, échappement, réservoir et châssis
# la modulent. Idempotent : appelée à chaque changement de pièce et à chaque reconstruction de l'assemblage.
func appliquer_valeurs_berliet(v: Veh) -> void:
	if v.type != "berliet_gdr":
		return
	var V := BerlietConfig.valeurs(berliet_config)
	var base_vit := float(v.profil.get("vitesse_assemblage", v.profil.vitesse))
	v.profil["vitesse_assemblage"] = base_vit
	v.profil.vitesse = base_vit * float(V.vitesse_route) * (1.0 + float(V.bonus_puissance)) * float(V.lame_vitesse)
	v.profil["lame_choc"] = float(V.lame_choc)   # lame avant (DEC-212) : multiplicateur de dégâts quand on enfonce un obstacle
	v.profil["lame_pv"] = int(V.lame_pv)
	v.profil["tout_terrain"] = float(V.tout_terrain)
	v.profil["charge_t"] = float(V.charge_t)
	v.profil["gazole_l"] = float(V.gazole_l)
	v.profil["puissance_ch"] = 150.0 * (1.0 + float(V.bonus_puissance))   # moteur du Berliet (DEC-232) : base de l'accélération
	v.profil["physique"] = {"pneu": "berliet_" + String(berliet_config.get("pneu_ar", "route")), "debattement": 0.45,
		"charge_essieu": float(v.profil.get("poids_kg", 6000.0)) * 0.5}   # pneus du camion (DEC-230)
	if v.pieces.has("roulement"):
		var r: Dictionary = v.pieces.roulement
		var base_max := float(v.profil.get("roulement_pv_assemblage", r.max))
		v.profil["roulement_pv_assemblage"] = base_max
		var rat: float = float(r.pv) / maxf(1.0, float(r.max))
		r.max = base_max * float(V.pv_roues)
		r.pv = r.max * rat

const PRENOMS := ["Pierre", "Marie", "Jules", "Léa", "Hugo", "Inès", "Louis", "Camille", "Noé", "Alice", "Paul", "Jeanne", "Marc", "Élise", "Théo", "Sarah", "Émile", "Clara", "Victor", "Nina"]
const INITIALES := "BCDFGLMPRSTV"
func _nom_survivant() -> String:
	_n_noms += 1
	return "%s %s." % [PRENOMS[(_n_noms * 7 + graine) % PRENOMS.size()], INITIALES[(_n_noms * 5 + graine) % INITIALES.length()]]

func _aligner_noms(v: Veh) -> void:
	while v.noms.size() < v.equipage.size():
		v.noms.append(_nom_survivant())
	while v.noms.size() > v.equipage.size():
		v.noms.pop_back()

func creer_batiment(type: String, x: float) -> Bat:
	var d: Dictionary = donnees().batiments[type]
	var b := Bat.new()
	b.uid = _uid
	_uid += 1
	b.type = type
	b.nom = d.nom
	b.x = x
	b.longueur = d.largeur
	b.hauteur = d.hauteur
	b.pv = float(d.pv)
	b.pv_max = float(d.pv)
	b.blindage = float(d.blindage)
	b.arme_fixe = d.get("arme", "")
	b.blindage_base = b.blindage
	b.garage_max = int(d.get("garage", 0))
	for i in int(d.tireurs):
		b.tireurs.append({"pv": 12.0, "cd": rng.randf_range(0.5, 1.5), "slot": i})
	var res := {}
	for k in d.butin:
		res[k] = round(rng.randf_range(d.butin[k][0], d.butin[k][1]))
	b.butin = {"ressources": res, "composants": []}
	return b

func ajouter_vehicule(type: String) -> Veh:
	var v := creer_vehicule(type, "joueur", x_tete - 30.0)
	convoi.append(v)
	_replacer(true)
	v.x_prev = v.x
	return v

func trouver(uid: int):
	for v in convoi:
		if v.uid == uid:
			return v
	for v in ennemis:
		if v.uid == uid:
			return v
	for b in batiments:
		if b.uid == uid:
			return b
	for v in epaves:
		if v.uid == uid:
			return v
	for p in monde.pietons:
		if p.uid == uid:
			return p
	return null


# --- Pas de simulation -----------------------------------------------------
func _replacer(immediat := false) -> void:
	var gap: float = donnees().ecart_convoi
	var bord := x_tete
	for v in convoi:
		if v.remorque() and v != convoi[0]:
			bord += gap - float(donnees().get("ecart_remorque", 0.5))   # attelée au véhicule de devant (DEC-080)
		v.x_cible = bord - v.longueur + v.ecart_acc
		bord = v.x_cible - gap
		if immediat:
			v.x = v.x_cible


# Remorques (DEC-080) : un véhicule tire les remorques qui le suivent dans le convoi
func tracteur_de(v: Veh):
	var i := convoi.find(v)
	if i < 0 or not v.remorque():
		return null
	for k in range(i - 1, -1, -1):
		if not convoi[k].remorque():
			return convoi[k]
	return null


func remorques_de(v: Veh) -> Array:
	var res := []
	var i := convoi.find(v)
	if i < 0 or v.remorque():
		return res
	for k in range(i + 1, convoi.size()):
		if not convoi[k].remorque():
			break
		res.append(convoi[k])
	return res


# Vitesse avec ses remorques : la puissance se partage sur la masse totale
func vitesse_attelee(v: Veh) -> float:
	var M := float(v.profil.get("poids_kg", 1000.0))
	var Mr := 0.0
	for r in remorques_de(v):
		if r.actif():
			Mr += float(r.profil.get("poids_kg", 0.0))
	return v.vitesse() * sqrt(M / (M + Mr))


# --- Lecture pour tests et interface --------------------------------------
func resume() -> String:
	var s := "t=%.0fs x=%.0fm muni=%.0f carb=%.0f metal=%.0f" % [temps, x_tete, stocks.ammo, stocks.gazole, stocks.metal]
	for v in convoi:
		s += " | %s ch%.0f ro%.0f" % [v.type, v.pieces.chassis.pv, v.pieces.roulement.pv]
	return s
