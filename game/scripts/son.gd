# Sons et musiques (chargé automatiquement sous le nom « Son », voir project.godot).
# Les fichiers se déposent dans assets/audio/ avec les noms de docs/audio/ELEVENLABS.md
# (formats .ogg, .mp3 ou .wav). Un fichier absent est ignoré sans erreur :
# le jeu fonctionne en silence tant que les sons ne sont pas produits.
extends Node

const DOSSIER := "res://assets/audio/"
const PREFERER_SYNTH := false   # DEC-090 : les fichiers fournis (ElevenLabs) passent avant les sons synthétisés, gardés en secours
const OPTIONS := "user://options.cfg"
const BUS := ["Musique", "Effets", "Voix"]
const FONDU := 1.5

var _cache := {}
var _musique: Array[AudioStreamPlayer] = []
var _musique_nom := ""
var _ambiance: AudioStreamPlayer
var _ambiance_nom := ""
var _moteur: AudioStreamPlayer
var _moteur_nom := ""
var _voix: AudioStreamPlayer
var _effets: Array[AudioStreamPlayer] = []
var volumes := {"Musique": 0.7, "Effets": 0.8, "Voix": 0.9}


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	for b in BUS:
		if AudioServer.get_bus_index(b) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, b)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	for i in 2:
		_musique.append(_lecteur("Musique"))
	_ambiance = _lecteur("Effets")
	_moteur = _lecteur("Effets")
	_voix = _lecteur("Voix")
	for i in 6:
		_effets.append(_lecteur("Effets"))
	var cfg := ConfigFile.new()
	if cfg.load(OPTIONS) == OK:
		for b in BUS:
			volumes[b] = float(cfg.get_value("volumes", b, volumes[b]))
	for b in BUS:
		regler(b, volumes[b], false)
	_ecouter_page()


# --- Silence hors du jeu (DEC-073) : appli en arrière-plan, autre onglet, écran verrouillé ---------
var _cb_page   # rappel JavaScript gardé en mémoire (sinon il est libéré)


func _ecouter_page() -> void:
	if not OS.has_feature("web"):
		return
	_cb_page = JavaScriptBridge.create_callback(func(_args): _silence(JavaScriptBridge.eval("document.hidden", true) == true))
	var w = JavaScriptBridge.get_interface("window")
	w.godotPage = _cb_page
	JavaScriptBridge.eval("""
		document.addEventListener('visibilitychange', function () { window.godotPage(); });
		window.addEventListener('pagehide', function () { window.godotPage(); });
		window.addEventListener('pageshow', function () { window.godotPage(); });
	""", true)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			_silence(true)
		NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_WM_WINDOW_FOCUS_IN:
			_silence(false)


func _silence(oui: bool) -> void:
	AudioServer.set_bus_mute(0, oui)   # bus principal : coupe musique, effets et voix d'un coup


func _lecteur(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p


func _flux(nom: String) -> AudioStream:
	if _cache.has(nom):
		return _cache[nom]
	var f: AudioStream = null
	# Tolère un dossier « Audio » ou une majuscule au début du nom (envoi depuis GitHub)
	# Sons synthétisés (tools/synth_audio.py) d'abord : WAV simples, lisibles partout. Mettre PREFERER_SYNTH à false pour les mp3.
	for dossier in ([DOSSIER + "synth/"] if PREFERER_SYNTH else []) + [DOSSIER, "res://assets/Audio/"]:
		for n in [nom, nom.capitalize().replace(" ", "_"), nom[0].to_upper() + nom.substr(1)]:
			for ext in (["wav", "ogg", "mp3"] if dossier.ends_with("synth/") else ["ogg", "mp3", "wav"]):
				var chemin := "%s%s.%s" % [dossier, n, ext]
				if f == null and ResourceLoader.exists(chemin):
					f = load(chemin)
	_cache[nom] = f
	return f


func _en_boucle(f: AudioStream) -> AudioStream:
	if f is AudioStreamMP3 or f is AudioStreamOggVorbis:
		f.loop = true
	elif f is AudioStreamWAV:
		f.loop_mode = AudioStreamWAV.LOOP_FORWARD
		f.loop_end = int(f.get_length() * f.mix_rate)
	return f


# Musique en boucle, avec fondu enchaîné. nom vide = silence.
# Une seule musique audible à la fois (DEC-090) : un nouveau changement annule le fondu en cours
# et coupe net tout lecteur qui n'est pas en train de disparaître.
var _tw_musique: Tween


func musique(nom: String) -> void:
	if nom == _musique_nom:
		return
	_musique_nom = nom
	if _tw_musique != null and _tw_musique.is_valid():
		_tw_musique.kill()
	var ancien := _musique[0]
	var nouveau := _musique[1]
	_musique.reverse()
	nouveau.stop()
	_tw_musique = create_tween().set_parallel(true)
	var f := _flux(nom) if nom != "" else null
	if f:
		nouveau.stream = _en_boucle(f)
		nouveau.volume_db = -40.0
		nouveau.play()
		_tw_musique.tween_property(nouveau, "volume_db", 0.0, FONDU)
	if ancien.playing:
		_tw_musique.tween_property(ancien, "volume_db", -40.0, FONDU)
		_tw_musique.chain().tween_callback(ancien.stop)
	elif not f:
		_tw_musique.kill()


# Fond sonore en boucle (vent, nuit).
func ambiance(nom: String) -> void:
	_boucle(_ambiance, nom, "_ambiance_nom")


# Bruit de moteur en boucle (garage, menu). nom vide = arrêt.
func moteur(nom: String) -> void:
	_boucle(_moteur, nom, "_moteur_nom")


# Hauteur de la boucle moteur : suit le régime (DEC-232)
func moteur_hauteur(h: float) -> void:
	_moteur.pitch_scale = clampf(h, 0.5, 2.0)


func _boucle(p: AudioStreamPlayer, nom: String, champ: String) -> void:
	if get(champ) == nom:
		return
	set(champ, nom)
	p.stop()
	var f := _flux(nom) if nom != "" else null
	if f:
		p.stream = _en_boucle(f)
		p.play()


# Bruitage ponctuel.
func effet(nom: String, volume_db := 0.0) -> void:
	var f := _flux(nom)
	if not f:
		return
	for p in _effets:
		if not p.playing:
			p.stream = f
			p.volume_db = volume_db
			p.play()
			return


# Réplique parlée (une à la fois).
func voix(nom: String) -> void:
	var f := _flux(nom)
	if f:
		_voix.stream = f
		_voix.play()


# Volume d'un bus, de 0 à 1, mémorisé dans les options.
func regler(bus: String, valeur: float, memoriser := true) -> void:
	volumes[bus] = clampf(valeur, 0.0, 1.0)
	var i := AudioServer.get_bus_index(bus)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(volumes[bus], 0.0001)))
	AudioServer.set_bus_mute(i, volumes[bus] <= 0.001)
	if memoriser:
		var cfg := ConfigFile.new()
		for b in BUS:
			cfg.set_value("volumes", b, volumes[b])
		cfg.save(OPTIONS)
