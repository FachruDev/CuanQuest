class_name GameModule
extends RefCounted
## Dasar semua modul GameState (karier, pendidikan, portofolio, ...).
##
## GameState (autoload, tipe GameStore) adalah root store; tiap modul memegang state satu
## domain beserta logikanya, dan memakai `gs` untuk data bersama: bulan, kas, kondisi,
## statistik, RNG, pasar, serta signal. Analogi web: satu "slice" Redux / satu store Pinia
## per fitur, dengan GameState sebagai root yang mengatur alur tiap bulan.
##
## Fungsi yang bisa di-override modul turunan (semuanya opsional):
## - load_data(): baca file data statis (sekali saat aplikasi mulai).
## - reset(): keadaan awal saat permainan baru.
## - save_to(d) / load_from(d): simpan & muat; kunci ditulis datar ke kamus save.
## - apply_effects(e): efek event/aktivitas milik modul ini (kunci "effects" di data event).
## - event_vars(id): isian teks event milik modul ini ({job}, {program}, ...).

var gs: GameStore


func _init(state: GameStore) -> void:
	gs = state


func load_data() -> void:
	pass


func reset() -> void:
	pass


func save_to(_d: Dictionary) -> void:
	pass


func load_from(_d: Dictionary) -> void:
	pass


func apply_effects(_e: Dictionary) -> void:
	pass


func event_vars(_id: String) -> Dictionary:
	return {}
