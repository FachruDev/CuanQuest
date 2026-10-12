extends Node
## Efek suara & getar (Autoload "Sfx").
## Suara DIBUAT DENGAN KODE (gelombang sinus -> AudioStreamWAV), jadi belum butuh
## file audio sama sekali. Nanti bisa diganti file .ogg/.wav buatan sound designer.
##
## Semua tombol di game otomatis berbunyi "klik": setiap Button yang masuk ke scene tree
## disambungkan lewat signal SceneTree.node_added (tidak perlu disambung satu per satu).

const MIX_RATE := 22050
const PLAYER_COUNT := 4

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_player := 0


func _ready() -> void:
	_streams = {
		"click": _tone([880.0], 0.035, 0.18),
		"coin": _tone([988.0, 1319.0], 0.07, 0.25),
		"success": _tone([523.0, 659.0, 784.0], 0.09, 0.25),
		"fail": _tone([392.0, 311.0], 0.15, 0.25),
		"alert": _tone([660.0, 0.0, 660.0], 0.06, 0.22),
	}
	for i in PLAYER_COUNT:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	get_tree().node_added.connect(_on_node_added)


func play(sound: String) -> void:
	if not Settings.sfx_enabled or not _streams.has(sound):
		return
	var player := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	player.stream = _streams[sound]
	player.play()


## Getar hanya di perangkat mobile (Android butuh izin VIBRATE saat export, lihat M7).
func vibrate(duration_ms: int = 80) -> void:
	if Settings.vibration_enabled and OS.has_feature("mobile"):
		Input.vibrate_handheld(duration_ms)


func _on_node_added(node: Node) -> void:
	if node is BaseButton and not node.pressed.is_connected(_on_button_pressed):
		node.pressed.connect(_on_button_pressed)


func _on_button_pressed() -> void:
	play("click")


## Membuat bunyi dari rangkaian nada (Hz). 0 = jeda. Tiap nada memudar (fade-out) agar tidak "klik".
func _tone(frequencies: Array, note_seconds: float, volume: float) -> AudioStreamWAV:
	var samples_per_note := int(MIX_RATE * note_seconds)
	var data := PackedByteArray()
	data.resize(frequencies.size() * samples_per_note * 2)  # 16-bit = 2 byte per sampel
	var offset := 0
	for frequency: float in frequencies:
		for i in samples_per_note:
			var envelope := 1.0 - float(i) / samples_per_note
			var value := sin(TAU * frequency * i / MIX_RATE) * envelope * volume
			data.encode_s16(offset, int(value * 32767.0))
			offset += 2
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	return wav
