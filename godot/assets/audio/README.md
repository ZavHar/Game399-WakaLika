Drop audio files in this folder using **base names** below. For each sound, use **one** of: `.wav`, `.mp3`, or `.ogg` (Godot tries **`.wav` first**, then `.mp3`, then `.ogg` if multiple exist).

- `music_loop`
- `pellet`
- `pellet_alt` (second chomp; alternates with `pellet`. If missing, `pellet` is used for both.)
- `fruit`
- `ghost_eaten`
- `game_over`
- `ghost_alive` (per-ghost distance-attenuated loop while not feared)
- `ghost_fear` (single **global** loop while power-pellet fear is active; per-ghost loops are silent then)
- `ghost_incapacitated` (per-ghost distance-attenuated loop while eaten / eyes state, only when not in global fear)

Power pellets use the same alternating pellet chomp sounds as normal pellets (no separate `power_pellet.mp3` in Godot).

`GameAudio.gd` will auto-load these from `res://assets/audio/`.
If files are missing, the game keeps running and logs a warning.
