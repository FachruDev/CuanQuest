class_name SaveDb
extends RefCounted
## Pembungkus tipis plugin godot-sqlite (addons/godot-sqlite). Semua SQL simpanan lewat sini.
## Analogi web: mirip "db client" kecil di backend Node (mis. better-sqlite3): buka koneksi,
## jalankan query dengan parameter `?`, dan bungkus beberapa query dalam satu transaksi.
##
## Skema (lihat _create_schema):
## - player        : data global pemain (kuis, tutorial, petunjuk) sebagai key -> JSON
## - games         : riwayat permainan yang sudah selesai (semua, ditampilkan 10 terakhir)
## - slots         : satu baris per slot save (auto, slot_1..3) + sisa state (biner, lihat SaveManager)
## - price_daily   : harga harian per aset, 24 bulan terakhir (riwayat bertingkat)
## - price_monthly : harga penutupan bulanan per aset, sepanjang permainan
## - transactions  : riwayat transaksi per slot (maks GameState.portfolio.MAX_TRANSACTIONS)

## Versi skema. Naikkan saat struktur tabel berubah, lalu tambahkan langkah di MIGRATIONS.
## Analogi web: file migrasi di Laravel/Prisma; PRAGMA user_version = nomor migrasi terakhir.
const SCHEMA_VERSION := 2
## Perubahan untuk database lama: versi tujuan -> perintah SQL.
const MIGRATIONS := {
	2: ["ALTER TABLE transactions ADD COLUMN tax REAL NOT NULL DEFAULT 0;"],  # v1.5a: pajak transaksi
}
## Baris per perintah INSERT. Satu INSERT berisi banyak baris jauh lebih cepat daripada
## INSERT per baris; batas SQLite 32.766 parameter per perintah.
const ROWS_PER_INSERT := 300

var _db: SQLite
var _in_transaction := false


## Buka (atau buat) database di `path`. Mengembalikan false jika gagal.
func open(path: String) -> bool:
	_db = SQLite.new()
	_db.path = path
	_db.verbosity_level = SQLite.QUIET
	_db.foreign_keys = true  # hapus slot -> harga & transaksinya ikut terhapus (ON DELETE CASCADE)
	if not _db.open_db():
		push_error("Gagal membuka database %s: %s" % [path, _db.error_message])
		_db = null
		return false
	# WAL + synchronous NORMAL: menulis lebih hemat (lebih sedikit fsync = hemat baterai) dan
	# file tetap utuh walau app dimatikan Android di tengah penyimpanan.
	exec("PRAGMA journal_mode = WAL;")
	exec("PRAGMA synchronous = NORMAL;")
	return _create_schema()


func close() -> void:
	if _db != null:
		_db.close_db()
		_db = null


func is_open() -> bool:
	return _db != null


## Jalankan satu perintah SQL. `args` mengisi tanda `?` secara berurutan (aman dari SQL injection).
func exec(sql: String, args: Array = []) -> bool:
	if _db == null:
		return false
	var ok := _db.query_with_bindings(sql, args) if not args.is_empty() else _db.query(sql)
	if not ok:
		push_error("SQL gagal: %s\n%s" % [_db.error_message, sql.left(200)])
	return ok


## Jalankan SELECT dan kembalikan barisnya (Array of Dictionary, kunci = nama kolom).
func rows(sql: String, args: Array = []) -> Array:
	return _db.query_result if exec(sql, args) else []


## Nilai kolom pertama dari baris pertama, atau `default` jika tidak ada.
func value(sql: String, args: Array = [], default: Variant = null) -> Variant:
	var result := rows(sql, args)
	if result.is_empty():
		return default
	var first: Dictionary = result[0]
	return first.values()[0]


## INSERT banyak baris sekaligus. `values` berisi Array per baris, urut sesuai `columns`.
func insert_many(table: String, columns: PackedStringArray, values: Array) -> bool:
	var placeholder := "(" + ", ".join(_repeat("?", columns.size())) + ")"
	var head := "INSERT INTO %s (%s) VALUES " % [table, ", ".join(columns)]
	for start in range(0, values.size(), ROWS_PER_INSERT):
		var batch := values.slice(start, start + ROWS_PER_INSERT)
		var args: Array = []
		for row: Array in batch:
			args.append_array(row)
		if not exec(head + ", ".join(_repeat(placeholder, batch.size())) + ";", args):
			return false
	return true


## Jalankan `body` (Callable yang mengembalikan bool) di dalam satu transaksi:
## semua perubahan tersimpan bersama (COMMIT) atau dibatalkan semua (ROLLBACK).
## Analogi web: `await db.transaction(async () => {...})`.
func transaction(body: Callable) -> bool:
	if _db == null:
		return false
	if _in_transaction:  # transaksi bersarang: ikut transaksi luar
		return body.call()
	if not exec("BEGIN IMMEDIATE;"):
		return false
	_in_transaction = true
	var ok: bool = body.call()
	_in_transaction = false
	if ok and exec("COMMIT;"):
		return true
	exec("ROLLBACK;")
	return false


func _create_schema() -> bool:
	var version := int(value("PRAGMA user_version;", [], 0))
	if version > SCHEMA_VERSION:
		push_error("Database dibuat oleh versi game yang lebih baru (skema %d)." % version)
		return false
	var statements: Array[String] = [
		"""CREATE TABLE IF NOT EXISTS player (
			key   TEXT PRIMARY KEY,
			value TEXT NOT NULL
		);""",
		"""CREATE TABLE IF NOT EXISTS games (
			id        INTEGER PRIMARY KEY AUTOINCREMENT,
			ended_at  INTEGER NOT NULL,
			name      TEXT NOT NULL,
			result    TEXT NOT NULL,
			months    INTEGER NOT NULL,
			net_worth REAL NOT NULL,
			data      TEXT NOT NULL
		);""",
		"""CREATE TABLE IF NOT EXISTS slots (
			slot        TEXT PRIMARY KEY,
			version     INTEGER NOT NULL,
			saved_at    INTEGER NOT NULL,
			player_name TEXT NOT NULL,
			avatar      INTEGER NOT NULL,
			month       INTEGER NOT NULL,
			net_worth   REAL NOT NULL,
			state       BLOB NOT NULL
		);""",
		"""CREATE TABLE IF NOT EXISTS price_daily (
			slot     TEXT NOT NULL REFERENCES slots(slot) ON DELETE CASCADE,
			asset_id TEXT NOT NULL,
			month    INTEGER NOT NULL,
			day      INTEGER NOT NULL,
			price    REAL NOT NULL,
			PRIMARY KEY (slot, asset_id, month, day)
		) WITHOUT ROWID;""",
		"""CREATE TABLE IF NOT EXISTS price_monthly (
			slot     TEXT NOT NULL REFERENCES slots(slot) ON DELETE CASCADE,
			asset_id TEXT NOT NULL,
			month    INTEGER NOT NULL,
			price    REAL NOT NULL,
			PRIMARY KEY (slot, asset_id, month)
		) WITHOUT ROWID;""",
		"""CREATE TABLE IF NOT EXISTS transactions (
			slot      TEXT NOT NULL REFERENCES slots(slot) ON DELETE CASCADE,
			seq       INTEGER NOT NULL,
			month     INTEGER NOT NULL,
			kind      TEXT NOT NULL,
			asset_key TEXT NOT NULL,
			amount    REAL NOT NULL,
			units     REAL NOT NULL,
			fee       REAL NOT NULL,
			tax       REAL NOT NULL DEFAULT 0,
			pnl       REAL NOT NULL,
			PRIMARY KEY (slot, seq)
		) WITHOUT ROWID;""",
	]
	# Database baru langsung dibuat dengan skema terbaru; database lama (versi 1..) menjalankan
	# migrasi yang belum pernah dijalankan.
	if version > 0:
		for target: int in range(version + 1, SCHEMA_VERSION + 1):
			statements.append_array(MIGRATIONS.get(target, []))
	statements.append("PRAGMA user_version = %d;" % SCHEMA_VERSION)
	return transaction(func() -> bool:
		for sql in statements:
			if not exec(sql):
				return false
		return true)


static func _repeat(text: String, count: int) -> PackedStringArray:
	var parts := PackedStringArray()
	parts.resize(count)
	parts.fill(text)
	return parts
