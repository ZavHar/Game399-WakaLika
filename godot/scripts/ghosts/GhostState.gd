extends RefCounted
class_name GhostState

var id: String = ""
var pos: Vector2i = Vector2i.ZERO
var dest: Vector2i = Vector2i.ZERO
var dir: int = 0
var speed_tiles_per_sec: float = 3.0
var step_acc: float = 0.0

var anim_from: Vector2i = Vector2i.ZERO
var anim_to: Vector2i = Vector2i.ZERO
var anim_t: float = 1.0

## Eaten during fear: eyes roam → return through exit → wait/shuffle in house (web parity).
var is_incapacitated: bool = false
var incapacitated_phase: String = ""
var incapacitated_roams_left: int = 0
var incapacitated_wait_ms: float = 0.0
var is_released: bool = true
var release_delay_ms: float = 0.0

## Wall-unstick recovery: snapshot before entering `INCAP_PHASE_UNSTICK`.
var unstick_saved_incap: bool = false
var unstick_saved_phase: String = ""
var unstick_saved_roams: int = 0
var unstick_saved_wait_ms: float = 0.0
