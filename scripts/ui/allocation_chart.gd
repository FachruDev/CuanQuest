class_name AllocationChart
extends Control
## Grafik donat alokasi aset (GDD 5.7), digambar manual lewat _draw().
## Data: Array of { "label": String, "value": float, "color": Color }.

@export var empty_text_key := "ALLOC_EMPTY"
@export var empty_color := Color("#f4eadb")  ## cincin abu saat belum ada aset

var _slices: Array[Dictionary] = []


func _ready() -> void:
	resized.connect(queue_redraw)


func set_slices(slices: Array[Dictionary]) -> void:
	_slices = slices.filter(func(s: Dictionary) -> bool: return s["value"] > 0)
	queue_redraw()


func _draw() -> void:
	var total := 0.0
	for s: Dictionary in _slices:
		total += s["value"]
	var center := size / 2.0
	var radius := minf(size.x, size.y) / 2.0 - 4.0
	var thickness := radius * 0.42
	if total <= 0.0:
		draw_arc(center, radius - thickness / 2.0, 0, TAU, 64, empty_color, thickness, true)
		return

	var angle := -PI / 2.0  # mulai dari jam 12
	for s: Dictionary in _slices:
		var sweep: float = TAU * s["value"] / total
		var segments := maxi(4, int(64 * sweep / TAU))
		draw_arc(center, radius - thickness / 2.0, angle, angle + sweep, segments, s["color"], thickness, true)
		angle += sweep
