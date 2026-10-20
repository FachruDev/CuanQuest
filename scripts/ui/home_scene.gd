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
## Kendaraan utama: gambar model (vehicles.json "art" / id), lalu gambar jenisnya (motor / car) jika gambar
## model belum ada; "walk" jika belum punya kendaraan.
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
	var ride := vehicle_art_id()
	path = VEHICLE_ART % ride
	if not ResourceLoader.exists(path):
		path = VEHICLE_ART % vehicle_fallback_id()
	_layers[2].texture = _texture(path)


## Rumah yang dihuni sendiri, atau pilihan tempat tinggal sewa.
static func home_art_id() -> String:
	var home := GameState.properties.home()
	return GameState.housing_id if home.is_empty() else str(home["id"])


static func vehicle_art_id() -> String:
	var primary := GameState.vehicles.primary()
	return "walk" if primary.is_empty() else str(GameState.vehicles.def(primary["id"]).get("art", primary["id"]))


## Gambar jenis kendaraan utama (motor / car) untuk model yang belum punya gambar sendiri.
static func vehicle_fallback_id() -> String:
	var primary := GameState.vehicles.primary()
	return "walk" if primary.is_empty() else GameState.vehicles.category_of(primary["id"])


## "Kos · Jalan kaki" / "Rumah sendiri (Rumah Tipe 45) · SUV & Motor Matic 125 cc" / "... · SUV, Motor Sport
## 250 cc +2" (lebih dari dua kendaraan: dua termahal + jumlah sisanya).
static func caption() -> String:
	var housing := _t(GameState.housing_option()["name_key"])
	var defs: Array = GameState.vehicles.owned.map(func(e: Dictionary) -> Dictionary: return GameState.vehicles.def(e["id"]))
	defs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["price"]) > float(b["price"]))
	var names := PackedStringArray(defs.map(func(d: Dictionary) -> String: return _t(d["name"])))
	var ride := _t("HOME_SCENE_WALK")
	if names.size() > 2:
		ride = _t("HOME_SCENE_MORE") % [", ".join(names.slice(0, 2)), names.size() - 2]
	elif not names.is_empty():
		ride = " & ".join(names)
	return "%s · %s" % [housing, ride]


static func _texture(path: String) -> Texture2D:
	return load(path) if ResourceLoader.exists(path) else null


static func _t(key: String) -> String:
	return TranslationServer.translate(key)
