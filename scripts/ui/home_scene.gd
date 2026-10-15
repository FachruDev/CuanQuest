class_name HomeScene
extends Control
## Ilustrasi "Hunian & Kendaraan" di Beranda (v1.5c langkah 4): latar + tempat tinggal + kendaraan
## yang berubah mengikuti kondisi pemain (menumpang -> kos -> kontrakan -> rumah sendiri; jalan
## kaki -> motor -> mobil).
##
## Ketiga lapisan memakai kanvas yang sama (624 x 260) sehingga cukup ditumpuk. Gambar sekarang
## masih pengganti sederhana; gambar final cukup menimpa file dengan nama yang sama
## (lihat docs/KEBUTUHAN_ASET.md).

const BG_ART := "res://assets/illustrations/home/bg.svg"
## Tempat tinggal: id hunian sewa (economy.json "housing") atau id properti yang dihuni (properties.json).
const HOME_ART := "res://assets/illustrations/home/%s.svg"
## Kendaraan utama (vehicles.json) atau "walk" jika belum punya kendaraan.
const VEHICLE_ART := "res://assets/illustrations/vehicle/%s.svg"
## Gambar pengganti jika file khusus belum ada (mis. properti baru di data tanpa gambar).
const HOME_FALLBACK := {"studio": "apartment", "house90": "house45", "subsidi": "house45"}
const HOME_DEFAULT := "kos"

var _layers: Array[TextureRect] = []


func _init() -> void:
	custom_minimum_size = Vector2(0, 250)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 3:
		var layer := TextureRect.new()
		layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		layer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(layer)
		_layers.append(layer)


func refresh() -> void:
	_layers[0].texture = _texture(BG_ART)
	var home := home_art_id()
	var path := HOME_ART % home
	if not ResourceLoader.exists(path):
		path = HOME_ART % HOME_FALLBACK.get(home, HOME_DEFAULT)
	_layers[1].texture = _texture(path)
	_layers[2].texture = _texture(VEHICLE_ART % vehicle_art_id())


## Rumah yang dihuni sendiri, atau pilihan tempat tinggal sewa.
static func home_art_id() -> String:
	var home := GameState.properties.home()
	return GameState.housing_id if home.is_empty() else str(home["id"])


static func vehicle_art_id() -> String:
	var primary := GameState.vehicles.primary()
	return "walk" if primary.is_empty() else str(primary["id"])


## "Kos · Jalan kaki" / "Rumah sendiri (Rumah Tipe 45) · Mobil & Motor".
static func caption() -> String:
	var housing := _t(GameState.housing_option()["name_key"])
	var defs: Array = GameState.vehicles.owned.map(func(e: Dictionary) -> Dictionary: return GameState.vehicles.def(e["id"]))
	defs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["price"]) > float(b["price"]))
	var names := PackedStringArray(defs.map(func(d: Dictionary) -> String: return _t(d["name"])))
	var ride := _t("HOME_SCENE_WALK") if names.is_empty() else " & ".join(names)
	return "%s · %s" % [housing, ride]


static func _texture(path: String) -> Texture2D:
	return load(path) if ResourceLoader.exists(path) else null


static func _t(key: String) -> String:
	return TranslationServer.translate(key)
