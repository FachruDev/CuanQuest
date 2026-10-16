extends Node
## Simpan/muat game ke database SQLite di user:// (Autoload "SaveManager").
## Analogi web: GameState = store di memori (mis. Redux), SaveManager = "repository" yang
## memetakan store itu ke tabel database (lewat SaveDb). UI cukup memanggil fungsi di sini.
## Lokasi file di PC: %APPDATA%/Godot/app_userdata/Cuan Quest/cuan_quest.db
##
## - slot "auto"    : simpan otomatis tiap akhir bulan / event diputuskan / transaksi / app di-pause
## - slot_1..slot_3 : slot manual (Profil -> Simpan)
## - data pemain    : kuis, tutorial, petunjuk & riwayat permainan; tidak terikat slot
##
## Simpan bertahap: riwayat harga dan transaksi hanya ditulis bagian yang BARU sejak simpanan
## terakhir ke slot yang sama (lihat `_synced`), jadi simpan otomatis tetap ringan walau
## permainan sudah berjalan puluhan tahun.

const DB_FILE := "cuan_quest.db"
const AUTO_SLOT := "auto"
const MANUAL_SLOTS: Array[String] = ["slot_1", "slot_2", "slot_3"]
## Titik simpan bab (v2b): ditulis otomatis setiap bab kehidupan baru, bisa dimuat dari Profil.
const CHAPTER_SLOT := "chapter"
const HISTORY_SHOWN := 10  # riwayat permainan yang dimuat ke GameState.history
## File JSON versi lama (v1 sampai v1.5-0 langkah 4): diimpor sekali ke database lalu dihapus.
const LEGACY_PLAYER := "player.json"
const LEGACY_SAVE_DIR := "saves/"
const TX_COLUMNS: PackedStringArray = [
	"slot", "seq", "month", "kind", "asset_key", "amount", "units", "fee", "tax", "pnl"]

var db := SaveDb.new()
var _root := "user://"
## Isi database per slot untuk permainan yang sedang berjalan:
## slot -> {"run": GameState.run_id, "months": {asset_id: bulan terakhir}, "seq": transaksi terakhir}
## Jika `run` berbeda (game baru / baru dimuat), slot itu ditulis ulang penuh.
var _synced: Dictionary = {}
var _steps: Dictionary = {}  # asset_id -> titik harga per bulan (hari bursa / hari kalender)


func _ready() -> void:
	_root = _save_root()
	DirAccess.make_dir_recursive_absolute(_root)
	for def: Dictionary in DataLoader.load_json(GameState.ASSETS_PATH).get("assets", []):
		_steps[def["id"]] = MarketAsset.from_def(def).days_per_month()
	if db.open(_root + DB_FILE):
		_import_legacy_json()
	_load_player()
	GameState.state_committed.connect(func() -> void: save_slot(AUTO_SLOT))
	GameState.player_changed.connect(_save_player)
	GameState.game_ended.connect(_on_game_ended)
	# Ditunda ke akhir frame: bulan itu selesai diproses dulu (event bulan baru sudah diundi).
	GameState.chapter_changed.connect(func(_summary: Dictionary) -> void: save_slot.call_deferred(CHAPTER_SLOT))


## Android bisa mematikan app kapan saja saat di background, jadi simpan saat di-pause/ditutup.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if GameState.is_active and not GameState.is_over:
			save_slot(AUTO_SLOT)
		_save_player()


func save_slot(slot: String) -> bool:
	if not GameState.is_active or GameState.is_over or not db.is_open():
		return false
	var meta := {
		"saved_at": int(Time.get_unix_time_from_system()),
		"player_name": GameState.player_name,
		"avatar": GameState.avatar,
		"month": GameState.month,
		"net_worth": GameState.net_worth(),
	}
	var state := GameState.to_dict()
	var synced: Dictionary = _synced.get(slot, {})
	if int(synced.get("run", -1)) != GameState.run_id:
		synced = {}  # permainan lain di slot ini -> tulis ulang penuh
	var ok := db.transaction(func() -> bool: return _write_slot(slot, meta, state, synced))
	if ok:
		_synced[slot] = _sync_info(state)
	else:
		_synced.erase(slot)  # simpanan berikutnya ditulis ulang penuh
	return ok


func load_slot(slot: String) -> bool:
	var state := _read_state(slot)
	if state.is_empty() or not GameState.load_from_dict(state):
		return false
	_synced[slot] = _sync_info(GameState.to_dict(), state["market"]["assets"])
	return true


## true jika slot berisi simpanan dari versi game lama (tidak bisa dimuat, tanpa migrasi).
func is_outdated(slot: String) -> bool:
	var version: Variant = db.value("SELECT version FROM slots WHERE slot = ?;", [slot])
	return version != null and int(version) != GameState.SAVE_VERSION


## Pesan gagal muat yang sesuai penyebabnya.
func load_error_text(slot: String) -> String:
	return tr("SAVE_OUTDATED") if is_outdated(slot) else tr("SAVE_LOAD_FAILED")


## Riwayat harga & transaksi slot ikut terhapus (ON DELETE CASCADE).
func delete_slot(slot: String) -> void:
	db.exec("DELETE FROM slots WHERE slot = ?;", [slot])
	_synced.erase(slot)


## Hapus SEMUA simpanan dan data pemain (Pengaturan -> Reset Data). Pengaturan tidak ikut dihapus.
func reset_all() -> void:
	db.transaction(func() -> bool:
		return db.exec("DELETE FROM slots;") and db.exec("DELETE FROM player;") \
			and db.exec("DELETE FROM games;"))
	_synced.clear()
	GameState.player_from_dict({})
	GameState.is_active = false


func has_slot(slot: String) -> bool:
	return int(db.value("SELECT COUNT(*) FROM slots WHERE slot = ?;", [slot], 0)) > 0


## Ringkasan slot untuk ditampilkan di daftar ({} jika kosong).
func slot_meta(slot: String) -> Dictionary:
	var found := db.rows("SELECT saved_at, player_name, avatar, month, net_worth FROM slots WHERE slot = ?;", [slot])
	if found.is_empty():
		return {}
	var row: Dictionary = found[0]
	return {"saved_at": int(row["saved_at"]), "player_name": String(row["player_name"]),
		"avatar": int(row["avatar"]), "month": int(row["month"]), "net_worth": float(row["net_worth"])}


## "Budi | Maret Tahun 2 | Rp12.345.678 | 12/10/2026 10:30"
func slot_summary(slot: String) -> String:
	var meta := slot_meta(slot)
	if meta.is_empty():
		return tr("SAVE_EMPTY")
	return "%s | %s | %s | %s" % [
		meta["player_name"], Fmt.game_date(int(meta["month"])), Fmt.rupiah(meta["net_worth"]),
		saved_at_text(meta)]


## Waktu simpan (jam lokal HP): "12/10/2026 10:30"
func saved_at_text(meta: Dictionary) -> String:
	var bias_minutes: int = Time.get_time_zone_from_system()["bias"]
	var dt := Time.get_datetime_dict_from_unix_time(int(meta["saved_at"]) + bias_minutes * 60)
	return "%02d/%02d/%d %02d:%02d" % [dt["day"], dt["month"], dt["year"], dt["hour"], dt["minute"]]


## Folder simpanan. Uji otomatis memakai `-- --save-root=user://_uji/` agar data asli tidak tersentuh.
func _save_root() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--save-root="):
			return arg.trim_prefix("--save-root=").trim_suffix("/") + "/"
	return "user://"


# --- Slot: tulis -----------------------------------------------------------------

## Tulis satu slot. `synced` kosong = tulis ulang penuh; selain itu hanya data yang baru.
## `state` = hasil GameState.to_dict(). Riwayat harga & transaksi dipisah ke tabel sendiri;
## sisanya disimpan di kolom slots.state dalam format biner Godot (var_to_bytes), BUKAN JSON:
## pembaca angka teks Godot kadang meleset di digit terakhir (±10% angka desimal), sehingga
## permainan yang dimuat bisa bercabang sedikit dari aslinya. Biner selalu persis sama.
func _write_slot(slot: String, meta: Dictionary, state: Dictionary, synced: Dictionary) -> bool:
	if synced.is_empty() and not db.exec("DELETE FROM slots WHERE slot = ?;", [slot]):
		return false
	var version := int(state.get("version", 0))
	var compact := state.duplicate()
	var assets: Dictionary = {}
	var transactions: Array = []
	if version == GameState.SAVE_VERSION:  # save versi lama disimpan apa adanya (tidak bisa dimuat)
		var market: Dictionary = state["market"].duplicate()
		assets = market["assets"]
		var prices := {}
		for asset_id: String in assets:
			prices[asset_id] = {"price": assets[asset_id]["price"]}
		market["assets"] = prices
		compact["market"] = market
		transactions = compact.get("transactions", [])
		compact.erase("transactions")
	var saved := db.exec("""INSERT INTO slots (slot, version, saved_at, player_name, avatar, month, net_worth, state)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?)
		ON CONFLICT(slot) DO UPDATE SET version = excluded.version, saved_at = excluded.saved_at,
			player_name = excluded.player_name, avatar = excluded.avatar, month = excluded.month,
			net_worth = excluded.net_worth, state = excluded.state;""",
		[slot, version, int(meta["saved_at"]), String(meta["player_name"]), int(meta["avatar"]),
			int(meta["month"]), float(meta["net_worth"]), var_to_bytes(compact)])
	return saved and _write_prices(slot, assets, synced.get("months", {})) \
		and _write_transactions(slot, transactions, int(synced.get("seq", 0)))


## Riwayat harga bertingkat: harian (24 bulan terakhir) + penutupan bulanan (sepanjang permainan).
## Penomoran: titik awal permainan = bulan 0 hari 0, lalu hari 1..langkah untuk tiap bulan
## simulasi (lihat MarketAsset.step_month). Hanya bulan setelah `synced_months` yang ditulis.
func _write_prices(slot: String, assets: Dictionary, synced_months: Dictionary) -> bool:
	var daily: Array = []
	var monthly: Array = []
	var trims: Array = []
	for asset_id: String in assets:
		var closes: Array = assets[asset_id]["month_closes"]
		var history: Array = assets[asset_id]["history"]
		var last_month := closes.size() - 1
		var from_month := int(synced_months.get(asset_id, -1)) + 1  # bulan pertama yang belum tersimpan
		if from_month > last_month:
			continue
		for m in range(from_month, last_month + 1):
			monthly.append([slot, asset_id, m, float(closes[m])])
		var steps: int = _steps.get(asset_id, MarketAsset.TRADING_DAYS)
		var new_points := (last_month - from_month + 1) * steps + (1 if from_month == 0 else 0)
		for i in range(maxi(history.size() - new_points, 0), history.size()):
			var point := _history_point(i, history.size(), last_month, steps)
			daily.append([slot, asset_id, point.x, point.y, float(history[i])])
		if from_month > 0:  # simpan bertahap: buang harga harian yang sudah lewat 24 bulan
			trims.append([slot, asset_id, last_month - MarketAsset.DAILY_KEEP_MONTHS])
	for trim: Array in trims:
		if not db.exec("DELETE FROM price_daily WHERE slot = ? AND asset_id = ? AND month <= ?;", trim):
			return false
	return db.insert_many("price_monthly", ["slot", "asset_id", "month", "price"], monthly) \
		and db.insert_many("price_daily", ["slot", "asset_id", "month", "day", "price"], daily)


## (bulan, hari) untuk titik ke-`i` di MarketAsset.history. Titik terakhir = hari terakhir `last_month`.
static func _history_point(i: int, size: int, last_month: int, steps: int) -> Vector2i:
	var absolute := last_month * steps - (size - 1 - i)  # nomor hari sejak awal permainan
	if absolute <= 0:
		return Vector2i(0, 0)
	return Vector2i((absolute - 1) / steps + 1, (absolute - 1) % steps + 1)


## Transaksi baru saja (seq > synced_seq), lalu buang yang melewati batas MAX_TRANSACTIONS.
func _write_transactions(slot: String, transactions: Array, synced_seq: int) -> bool:
	var values: Array = []
	for i in transactions.size():  # terbaru di depan
		var t: Dictionary = transactions[i]
		var seq := int(t.get("seq", transactions.size() - i))  # save JSON lama belum punya seq
		if seq <= synced_seq:
			break
		values.append([slot, seq, int(t["month"]), String(t["kind"]), String(t["asset_key"]),
			float(t["amount"]), float(t["units"]), float(t["fee"]), float(t.get("tax", 0.0)), float(t.get("pnl", 0.0))])
	if values.is_empty():
		return true
	var newest: int = values[0][1]
	return db.insert_many("transactions", TX_COLUMNS, values) \
		and db.exec("DELETE FROM transactions WHERE slot = ? AND seq <= ?;",
			[slot, newest - GameState.portfolio.MAX_TRANSACTIONS])


## Catatan "sudah tersimpan sampai mana" untuk simpan bertahap berikutnya.
## `saved_assets`: hanya aset yang benar-benar ada di database (aset baru di data ditulis penuh nanti).
func _sync_info(state: Dictionary, saved_assets: Dictionary = {}) -> Dictionary:
	var months := {}
	var assets: Dictionary = state["market"]["assets"]
	for asset_id: String in assets:
		if saved_assets.is_empty() or saved_assets.has(asset_id):
			months[asset_id] = (assets[asset_id]["month_closes"] as Array).size() - 1
	var transactions: Array = state["transactions"]
	var seq := int(transactions[0]["seq"]) if not transactions.is_empty() else 0
	return {"run": GameState.run_id, "months": months, "seq": seq}


# --- Slot: baca ------------------------------------------------------------------

## Susun ulang dict GameState.to_dict() dari tabel. {} jika slot kosong / versi lama / rusak.
func _read_state(slot: String) -> Dictionary:
	var found := db.rows("SELECT version, state FROM slots WHERE slot = ?;", [slot])
	if found.is_empty() or int(found[0]["version"]) != GameState.SAVE_VERSION:
		return {}
	var blob: Variant = found[0]["state"]
	var parsed: Variant = bytes_to_var(blob) if blob is PackedByteArray else null  # tanpa objek: aman
	if not parsed is Dictionary:
		return {}
	var state: Dictionary = parsed
	var assets: Dictionary = state["market"]["assets"]
	for asset_id: String in assets:
		assets[asset_id]["history"] = []
		assets[asset_id]["month_closes"] = []
	for row: Dictionary in db.rows(
			"SELECT asset_id, price FROM price_daily WHERE slot = ? ORDER BY asset_id, month, day;", [slot]):
		if assets.has(row["asset_id"]):
			assets[row["asset_id"]]["history"].append(float(row["price"]))
	for row: Dictionary in db.rows(
			"SELECT asset_id, price FROM price_monthly WHERE slot = ? ORDER BY asset_id, month;", [slot]):
		if assets.has(row["asset_id"]):
			assets[row["asset_id"]]["month_closes"].append(float(row["price"]))
	var transactions: Array = []
	for row: Dictionary in db.rows(
			"SELECT seq, month, kind, asset_key, amount, units, fee, tax, pnl FROM transactions WHERE slot = ? ORDER BY seq DESC LIMIT ?;",
			[slot, GameState.portfolio.MAX_TRANSACTIONS]):
		transactions.append({"seq": int(row["seq"]), "month": int(row["month"]), "kind": String(row["kind"]),
			"asset_key": String(row["asset_key"]), "amount": float(row["amount"]), "units": float(row["units"]),
			"fee": float(row["fee"]), "tax": float(row["tax"]), "pnl": float(row["pnl"])})
	state["transactions"] = transactions
	return state


# --- Data pemain & riwayat permainan ---------------------------------------------

func _save_player() -> void:
	db.transaction(func() -> bool: return _write_player(GameState.player_to_dict()))


## Simpan data pemain sebagai key -> JSON. Riwayat permainan punya tabel sendiri (games).
func _write_player(data: Dictionary) -> bool:
	for key: String in data:
		if key == "history":
			continue
		if not db.exec("""INSERT INTO player (key, value) VALUES (?, ?)
				ON CONFLICT(key) DO UPDATE SET value = excluded.value;""",
				[key, JSON.stringify(data[key], "", false, true)]):
			return false
	return true


func _load_player() -> void:
	var data := {}
	for row: Dictionary in db.rows("SELECT key, value FROM player;"):
		data[String(row["key"])] = JSON.parse_string(row["value"])
	var history: Array = []
	for row: Dictionary in db.rows("SELECT data FROM games ORDER BY id DESC LIMIT ?;", [HISTORY_SHOWN]):
		history.append(JSON.parse_string(row["data"]))
	data["history"] = history
	GameState.player_from_dict(data)


## Game over: catat di riwayat permainan, lalu hapus simpanan otomatis
## (slot manual tetap ada untuk "mengulang").
func _on_game_ended(_result: Dictionary) -> void:
	if not GameState.history.is_empty():
		_insert_game(GameState.history[0])
	delete_slot(AUTO_SLOT)


func _insert_game(game: Dictionary) -> bool:
	return db.exec("INSERT INTO games (ended_at, name, result, months, net_worth, data) VALUES (?, ?, ?, ?, ?, ?);",
		[int(game["date"]), String(game["name"]), String(game["type"]), int(game["months"]),
			float(game["net_worth"]), JSON.stringify(game, "", false, true)])


# --- Impor sekali dari file JSON lama --------------------------------------------

## Pindahkan player.json & saves/*.json (sebelum SQLite) ke database, lalu hapus file lamanya.
## Save versi sekarang ikut pindah utuh; save versi lama tetap ditolak saat dimuat (tanpa migrasi).
func _import_legacy_json() -> void:
	var player_path := _root + LEGACY_PLAYER
	var slot_files := {}
	for slot: String in [AUTO_SLOT] + MANUAL_SLOTS:
		var path := _root + LEGACY_SAVE_DIR + slot + ".json"
		if FileAccess.file_exists(path):
			slot_files[slot] = path
	var has_player := FileAccess.file_exists(player_path)
	if not has_player and slot_files.is_empty():
		return
	var ok := db.transaction(func() -> bool:
		if has_player:
			var player := _read_json(player_path)
			if not _write_player(player):
				return false
			var games: Array = player.get("history", [])
			for i in range(games.size() - 1, -1, -1):  # terlama dulu, agar id urut waktu
				if not _insert_game(games[i]):
					return false
		for slot: String in slot_files:
			var data := _read_json(slot_files[slot])
			if data.has("meta") and data.has("state") \
					and not _write_slot(slot, data["meta"], data["state"], {}):
				return false
		return true)
	if not ok:
		push_error("Impor simpanan JSON lama gagal; dicoba lagi saat game dibuka berikutnya.")
		return
	var paths: Array = slot_files.values()
	if has_player:
		paths.append(player_path)
	for path: String in paths:
		DirAccess.remove_absolute(path)
		if FileAccess.file_exists(path + ".tmp"):
			DirAccess.remove_absolute(path + ".tmp")
	DirAccess.remove_absolute(_root + LEGACY_SAVE_DIR)  # hanya terhapus jika sudah kosong


func _read_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
