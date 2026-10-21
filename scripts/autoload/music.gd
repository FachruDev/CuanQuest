extends Node
## Musik latar (Autoload "Music"), lihat docs/KEBUTUHAN_SUARA.md bagian 3 & 12.
##
## Tiap layar cukup memanggil `Music.play("<tema>")`; tema yang sama tidak diulang dari awal, jadi
## Judul -> Game Baru -> Tutorial tetap memutar lagu yang sama tanpa putus.
## - Lagu satu tema diputar bergantian (lagu 1 -> lagu 2 -> lagu 1 ...) dengan crossfade, jadi fade-out
##   di ujung tiap lagu menjadi transisi. Tema berisi satu lagu diulang dengan crossfade ujung ke awal.
## - Dua AudioStreamPlayer dipakai bergantian: satu memudar keluar, satu memudar masuk.
## - Volume & redam diatur di bus "Music" (dibuat saat mulai), terpisah dari efek suara.
## - Berhenti sementara saat aplikasi masuk ke latar belakang (Android), lanjut saat kembali.

const BUS := &"Music"
const DIR := "res://assets/audio/music/"
## Lagu per tema. Tema bab memakai id bab di data/life.json. File yang belum ada dilewati.
const THEMES := {
	"title": ["title_theme"],
	"early": ["chapter_early_1", "chapter_early_2"],
	"build": ["chapter_build_1", "chapter_build_2"],
	"peak": ["chapter_peak_1", "chapter_peak_2"],
	"retire": ["chapter_retire_1", "chapter_retire_2"],
	"end": ["end_theme"],
}
const CROSSFADE := 2.5  # detik, antarlagu dan saat ganti tema
const FADE_IN := 1.5  # detik, lagu pertama dari hening
const DUCK_LEVEL := 0.35  # redam ±9 dB saat popup tenang/sensitif
const DUCK_TIME := 0.6

## Tema yang sedang diputar ("" = hening).
var theme := ""

var _players: Array[AudioStreamPlayer] = []
var _tweens: Array[Tween] = [null, null]
var _active := 0
var _tracks: Array[AudioStream] = []
var _index := 0
var _next_timer: Timer
var _duckers: Dictionary = {}  # instance id popup -> true, selama popup itu meredam musik
var _duck := 1.0
var _duck_tween: Tween
var _bus := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bus = AudioServer.get_bus_index(BUS)
	if _bus == -1:
		AudioServer.add_bus()
		_bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(_bus, BUS)
		AudioServer.set_bus_send(_bus, &"Master")
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.bus = BUS
		add_child(player)
		_players.append(player)
	_next_timer = Timer.new()
	_next_timer.one_shot = true
	_next_timer.timeout.connect(_on_track_ending)
	add_child(_next_timer)
	_apply_volume()
	Settings.changed.connect(_on_settings_changed)


## Putar tema (lihat THEMES; "" = memudar sampai hening). Tema yang sedang main tidak diulang.
## `fade`: lama transisi (detik); bawaan CROSSFADE, atau FADE_IN bila sebelumnya hening.
func play(theme_id: String, fade: float = -1.0) -> void:
	if theme_id == theme:
		return
	theme = theme_id
	_tracks.clear()
	for id: String in THEMES.get(theme_id, []):
		var path: String = DIR + id + ".ogg"
		if ResourceLoader.exists(path):
			_tracks.append(load(path))
	_index = 0
	_restart(fade)


## Memudar sampai hening (mis. perpisahan di akhir hidup: ±3 detik, pedoman konten sensitif).
func stop(fade: float = CROSSFADE) -> void:
	play("", fade)


## Redam musik selama `popup` tampil; kembali normal saat popup ditutup atau dibuang.
## Untuk popup tenang/sensitif (depresi, masa senja, kondisi kritis, event "quiet").
func duck_while(popup: ModalPopup) -> void:
	var id := popup.get_instance_id()
	if _duckers.has(id):
		return
	_duckers[id] = true
	_set_ducked(true)
	var release := func() -> void:
		_duckers.erase(id)
		_set_ducked(not _duckers.is_empty())
	popup.closed.connect(release, CONNECT_ONE_SHOT)
	popup.tree_exiting.connect(release, CONNECT_ONE_SHOT)


func _restart(fade: float) -> void:
	_next_timer.stop()
	var was_playing := _players[_active].playing
	if fade < 0.0:
		fade = CROSSFADE if was_playing else FADE_IN
	if _tracks.is_empty() or not Settings.music_enabled:
		_fade(_active, 0.0, fade)
		return
	_start_track(fade)


## Lagu `_index` masuk di pemutar satunya, pemutar lama memudar keluar.
func _start_track(fade: float) -> void:
	_fade(_active, 0.0, fade)
	_active = 1 - _active
	var player := _players[_active]
	player.stream = _tracks[_index]
	player.volume_linear = 0.0
	player.play()
	_fade(_active, 1.0, fade)
	var length := player.stream.get_length()
	_next_timer.start(maxf(length - CROSSFADE, 1.0))


func _on_track_ending() -> void:
	_index = (_index + 1) % _tracks.size()
	_start_track(CROSSFADE)


func _fade(i: int, to: float, seconds: float) -> void:
	if _tweens[i] != null:
		_tweens[i].kill()
	var player := _players[i]
	if not player.playing:
		return
	var tween := create_tween()
	tween.tween_property(player, "volume_linear", to, maxf(seconds, 0.01))
	if to == 0.0:
		tween.tween_callback(player.stop)
	_tweens[i] = tween


func _set_ducked(on: bool) -> void:
	if _duck_tween != null:
		_duck_tween.kill()
	_duck_tween = create_tween()
	_duck_tween.tween_method(_set_duck, _duck, DUCK_LEVEL if on else 1.0, DUCK_TIME)


func _set_duck(value: float) -> void:
	_duck = value
	_apply_volume()


func _apply_volume() -> void:
	AudioServer.set_bus_volume_db(_bus, linear_to_db(Settings.music_volume * _duck))


func _on_settings_changed() -> void:
	_apply_volume()
	var running := not _next_timer.is_stopped()  # timer hanya jalan selama ada lagu yang diputar
	if Settings.music_enabled and not running and not _tracks.is_empty():
		_index = 0
		_start_track(FADE_IN)
	elif not Settings.music_enabled and running:
		_restart(0.3)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_RESUMED:
		var paused := what == NOTIFICATION_APPLICATION_PAUSED
		for player in _players:
			player.stream_paused = paused
		_next_timer.paused = paused
