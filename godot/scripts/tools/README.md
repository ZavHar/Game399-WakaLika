## Level Pipeline (Phase 7)

This keeps the React level editor as the authoring tool while making Godot loading deterministic.

- Source of truth: `res://assets/data/levelGrids.json`
- Active runtime layout: `res://assets/data/active_layout.txt`

Use the helper script:

```powershell
& "C:/Users/Angel/Miscellaneous Saves/Installed Programs/Godot_v4.6.2-stable_win64.exe/Godot_v4.6.2-stable_win64.exe" --headless --path "<repo>/godot" --script "res://scripts/tools/LevelPipeline.gd" list
```

```powershell
& "C:/Users/Angel/Miscellaneous Saves/Installed Programs/Godot_v4.6.2-stable_win64.exe/Godot_v4.6.2-stable_win64.exe" --headless --path "<repo>/godot" --script "res://scripts/tools/LevelPipeline.gd" validate
```

```powershell
& "C:/Users/Angel/Miscellaneous Saves/Installed Programs/Godot_v4.6.2-stable_win64.exe/Godot_v4.6.2-stable_win64.exe" --headless --path "<repo>/godot" --script "res://scripts/tools/LevelPipeline.gd" set-active Classical
```

Godot `WallsView.gd` now reads `active_layout.txt`; if missing/empty, it falls back to the first sorted layout.
