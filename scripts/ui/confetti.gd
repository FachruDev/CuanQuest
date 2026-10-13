class_name Confetti
extends Control
## Hujan confetti singkat untuk merayakan pencapaian (impian terwujud, tahap baru, target
## kemenangan). Digambar lewat _draw(), tanpa aset gambar, lalu menghapus dirinya sendiri.
## Pemakaian: Confetti.burst(node_induk)

const COLORS := [Color("#f6b93b"), Color("#23877b"), Color("#c2452d"), Color("#7b6cf6"), Color("#ffffff")]
const COUNT := 70
const DURATION := 2.4
const GRAVITY := 420.0

var _pieces: Array[Dictionary] = []
var _time := 0.0


static func burst(parent: Node) -> void:
	var confetti := Confetti.new()
	confetti.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	confetti.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(confetti)


func _ready() -> void:
	var area := get_viewport_rect().size
	for i in COUNT:
		_pieces.append({
			"pos": Vector2(randf() * area.x, randf_range(-area.y * 0.35, -10.0)),
			"vel": Vector2(randf_range(-90.0, 90.0), randf_range(120.0, 360.0)),
			"rot": randf() * TAU,
			"spin": randf_range(-6.0, 6.0),
			"size": Vector2(randf_range(10.0, 18.0), randf_range(6.0, 10.0)),
			"color": COLORS[i % COLORS.size()],
		})


func _process(delta: float) -> void:
	_time += delta
	if _time >= DURATION:
		queue_free()
		return
	for piece: Dictionary in _pieces:
		piece["vel"].y += GRAVITY * delta * 0.3
		piece["pos"] += piece["vel"] * delta
		piece["rot"] += piece["spin"] * delta
	queue_redraw()


func _draw() -> void:
	var alpha := clampf((DURATION - _time) / 0.6, 0.0, 1.0)  # memudar di 0,6 detik terakhir
	for piece: Dictionary in _pieces:
		draw_set_transform(piece["pos"], piece["rot"])
		var piece_size: Vector2 = piece["size"]
		draw_rect(Rect2(-piece_size / 2.0, piece_size), Color(piece["color"], alpha))
	draw_set_transform(Vector2.ZERO)
