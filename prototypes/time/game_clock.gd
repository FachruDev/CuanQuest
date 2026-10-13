extends RefCounted
## Jam game prototipe. Waktu disimpan sebagai MENIT sejak hari ke-0 pukul 00:00.
##
## Detik nyata diubah menjadi langkah waktu tetap (fixed timestep): setiap langkah
## memajukan `step_minutes` menit game. Analogi web: seperti setInterval yang mengejar
## waktu yang tertinggal, tetapi hasil simulasi tidak bergantung pada frame rate HP.

const DAY_NAMES := ["Senin", "Selasa", "Rabu", "Kamis", "Jumat", "Sabtu", "Minggu"]
const MINUTES_PER_DAY := 1440

var minutes := 0
var speed := 1
var seconds_per_hour := 2.5
var step_minutes := 15
var days_per_month := 30
var months_per_year := 12
var max_steps_per_frame := 16

var _pause_reasons := {}   # alasan -> true; jam hanya berjalan jika kosong
var _accumulator := 0.0


func setup(clock_cfg: Dictionary, calendar_cfg: Dictionary) -> void:
	seconds_per_hour = clock_cfg["seconds_per_hour"]
	step_minutes = int(clock_cfg["step_minutes"])
	max_steps_per_frame = int(clock_cfg["max_steps_per_frame"])
	days_per_month = int(calendar_cfg["days_per_month"])
	months_per_year = int(calendar_cfg["months_per_year"])
	minutes = int(clock_cfg["start_hour"]) * 60


# --- Jeda ---------------------------------------------------------------------
# Beberapa alasan bisa aktif bersamaan (mis. popup terbuka DAN aplikasi ke latar).
# Jam baru berjalan lagi setelah SEMUA alasan dilepas, seperti reference counting.

func pause(reason: String) -> void:
	_pause_reasons[reason] = true


func resume(reason: String) -> void:
	_pause_reasons.erase(reason)


func is_paused() -> bool:
	return not _pause_reasons.is_empty()


func has_pause(reason: String) -> bool:
	return _pause_reasons.has(reason)


## Mengubah detik nyata frame ini menjadi jumlah langkah yang harus dijalankan.
func consume(real_delta: float) -> int:
	if is_paused():
		_accumulator = 0.0
		return 0
	_accumulator += real_delta * speed
	var step_seconds := seconds_per_hour * step_minutes / 60.0
	var steps := floori(_accumulator / step_seconds)
	if steps > max_steps_per_frame:
		# HP sempat tersendat: buang sisa waktu agar game tidak "ngebut" mengejar.
		steps = max_steps_per_frame
		_accumulator = 0.0
	else:
		_accumulator -= steps * step_seconds
	return steps


# --- Kalender (30 hari per bulan, 12 bulan per tahun, hari ke-0 = Senin) -------------

func day() -> int:
	return floori(minutes / float(MINUTES_PER_DAY))


func hour() -> int:
	return (minutes % MINUTES_PER_DAY) / 60


func minute() -> int:
	return minutes % 60


func weekday() -> int:
	return day() % 7


func is_weekend() -> bool:
	return weekday() >= 5


func day_of_month() -> int:
	return day() % days_per_month + 1


func month_index() -> int:
	return floori(day() / float(days_per_month))


func month_of_year() -> int:
	return month_index() % months_per_year + 1


func year() -> int:
	return floori(month_index() / float(months_per_year)) + 1


## Menit absolut untuk hari ke-`day_number` pukul `at_hour`:00.
func minutes_at(day_number: int, at_hour: int) -> int:
	return day_number * MINUTES_PER_DAY + at_hour * 60


## Kemunculan berikutnya pukul `at_hour`:00, sesudah saat ini.
func next_time_at_hour(at_hour: int) -> int:
	var target := minutes_at(day(), at_hour)
	return target if target > minutes else target + MINUTES_PER_DAY


## Kemunculan berikutnya tanggal `day_of_month_target` pukul `at_hour`:00.
func next_time_at_date(day_of_month_target: int, at_hour: int) -> int:
	var month_start := month_index() * days_per_month
	var target := minutes_at(month_start + day_of_month_target - 1, at_hour)
	return target if target > minutes else minutes_at(month_start + days_per_month + day_of_month_target - 1, at_hour)


func date_text() -> String:
	var month_name := TranslationServer.translate("MONTH_%d" % month_of_year())
	return "%s, %d %s Th %d" % [DAY_NAMES[weekday()], day_of_month(), month_name, year()]


func time_text() -> String:
	return "%02d:%02d" % [hour(), minute()]


func to_dict() -> Dictionary:
	return {"minutes": minutes, "speed": speed, "seconds_per_hour": seconds_per_hour, "accumulator": _accumulator}


func load_state(d: Dictionary) -> void:
	minutes = int(d["minutes"])
	speed = int(d["speed"])
	seconds_per_hour = float(d["seconds_per_hour"])
	_accumulator = float(d["accumulator"])
