export const PELLET_SCORE = 10
export const FRUIT_SCORE = 200
export const LEVEL_DURATION = 600 // seconds

export const PAC_TILES_PER_SEC = 5
export const GHOST_TILES_PER_SEC = 3
export const MAX_TILE_STEPS_PER_FRAME = 8
/** Sub-steps per frame so buffered turns can commit as soon as the cell allows (continuous Pac). */
export const PAC_SUBSTEPS_PER_FRAME = 6

export const PELLET_COLLECT_RADIUS = 0.35
export const PAC_GHOST_COLLISION_RADIUS = 0.5

export const TURN_CENTER_EPS = 0.14

export const BUFFERED_DIR_RELEASE_CLEAR_MS = 100

/** How long (ms) the side-clear wall tint transitions take. */
export const SIDE_CLEAR_TRANSITION_DURATION_MS = 650

/** How long the fruit-triggered side refresh white flash lasts. */
export const FRUIT_SIDE_FLASH_DURATION_MS = 250
/** Max alpha of the white flash overlay (0..1). */
export const FRUIT_SIDE_FLASH_MAX_ALPHA = 0.35
/** Higher values make the flash fade out faster near the end. */
export const FRUIT_SIDE_FLASH_FADE_POW = 2

export const PACLIGHT_RADIUS_TILES = 5
export const PACLIGHT_MAX_ALPHA = 0.85
export const PACLIGHT_COLOR = '255, 255, 255'

export const GHOST_LIGHT_ALPHA = 1
export const GHOST_LIGHT_RADIUS_TILES = 3

/** Fear (power pellet) duration in ms. */
export const FEAR_DURATION_MS = 10_000
/** When fear is about to expire, ghosts flash for this long (ms). */
export const FEAR_FLASH_MS = 2_000

/**
 * Radial light easing exponent.
 * Larger values keep more brightness near the center (slower falloff),
 * while values closer to 1 approach a linear falloff.
 */
export const LIGHT_RADIAL_EASING_EXPONENT = 0.35
