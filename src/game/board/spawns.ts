import type { Vec2 } from './levels'

/** Global Pac-Man spawn (not tied to individual level layouts). */
export const PAC_SPAWN: Vec2 = { x: 13, y: 26 }

/**
 * Fruit spawn points in local half coordinates.
 * Left fruit uses LEFT_FRUIT_SPAWN_LOCAL.
 * Right fruit mirrors across the center seam (global x = 2*halfWidth - 1 - leftX).
 */
export const LEFT_FRUIT_SPAWN_LOCAL: Vec2 = { x: 9, y: 17 }

export function mirroredRightGlobalX(leftLocalX: number, halfWidth: number): number {
  return 2 * halfWidth - 1 - leftLocalX
}


