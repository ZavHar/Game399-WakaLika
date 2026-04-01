# Audio assets

## Design plan (where sounds are used)

- **Music (`music_loop.mp3`)** — Looped arcade-style bed. Starts after the first keyboard or pointer gesture (browser autoplay policy). Stops on game over.
- **Normal pellet (`pellet.mp3`)** — One-shot when Pac-Man eats a regular pellet.
- **Power pellet (`power_pellet.mp3`)** — Distinct cue when eating a power pellet (pairs with fear-mode visuals).
- **Fruit (`fruit.mp3`)** — Bonus when collecting the left or right tunnel fruit.
- **Ghost eaten (`ghost_eaten.mp3`)** — When a ghost is eaten while Pac-Man is in fear (power) mode.
- **Game over (`game_over.mp3`)** — On lethal ghost contact or when match time reaches zero.
- **Low-time tension (`low_time_warning.mp3`)** — One-shot when the match timer crosses into the last **10 seconds** (distinct from pellet SFX).

## Integration

Sounds are loaded in `src/game/audio/gameAudio.ts` via Howler (`howler`). Game logic sets one-frame flags in `src/game/audio/sfxTypes.ts`; `App.tsx` calls `playPelletSfx` / `playCollisionSfx` / `maybePlayLowTimeWarning` after sim steps.

## Credits and licensing

Replace or document sources before public release. **Freesound** previews and similar clips may require attribution or may forbid redistribution; verify each sound’s license on its original page.

| File | In-game role |
|------|----------------|
| `pellet.mp3` | Regular pellet |
| `power_pellet.mp3` | Power pellet |
| `fruit.mp3` | Tunnel fruit |
| `ghost_eaten.mp3` | Eat ghost (fear mode) |
| `game_over.mp3` | Game over |
| `low_time_warning.mp3` | Timer enters final 10s |
| `music_loop.mp3` | Background music |

`low_time_warning.mp3` — [Mixkit](https://mixkit.co) preview asset (`active_storage/sfx/2869`); [Mixkit Sound Effects Free License](https://mixkit.co/license/#sfxFreeLicense).

Suggested sources for **royalty-free / open** replacements: [Kenney](https://kenney.nl/assets) (CC0), [OpenGameArt](https://opengameart.org/), [Mixkit](https://mixkit.co/free-sound-effects/), [Freesound](https://freesound.org/) (check license per clip).

Add per-file **title, author, license, and URL** here when you lock final assets.
