class_name DataLoader
extends RefCounted
## Membaca file konten JSON di folder data/.


static func load_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		return parsed
	push_error("Gagal membaca JSON: %s" % path)
	return {}
