extends Control

const TARGET_FPS: int = 60
## 28 * 18, 36 * 18 — must match board CELL_PX * grid in views.
const BOARD_VIEWPORT_SIZE: Vector2i = Vector2i(504, 648)

func _ready() -> void:
	Engine.physics_ticks_per_second = TARGET_FPS
	var score_hud: Label = $CanvasLayerHud/ScoreLabel as Label
	var time_hud: Label = $CanvasLayerHud/TimeLabel as Label
	score_hud.add_to_group("game_score_hud")
	time_hud.add_to_group("game_time_hud")
	var vp: SubViewport = $MarginPlayfield/AspectBoard/SubViewportContainer/SubViewport as SubViewport
	vp.size = BOARD_VIEWPORT_SIZE
	# Match AspectRatioContainer to viewport (width / height); avoids float drift in .tscn.
	var ar: AspectRatioContainer = $MarginPlayfield/AspectBoard as AspectRatioContainer
	ar.ratio = float(BOARD_VIEWPORT_SIZE.x) / float(BOARD_VIEWPORT_SIZE.y)
	print("Waka-Lika Godot bootstrap OK.")
