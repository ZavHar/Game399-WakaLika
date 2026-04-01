import type { Vec2 } from '../board/levels'
import {
  PAC_TILES_PER_SEC,
  PELLET_COLLECT_RADIUS,
  TURN_CENTER_EPS,
} from '../data/constants'
import { isPacBlocked } from '../board/grid'
import type { Direction, GameState } from '../data/types'
import { dirToVec, isOppositeDir } from '../data/utils'

/** True if the adjacent tile in `dir` from Pac-Man's current cell is not a wall. */
export function canPacStartTurnInDirection(
  state: GameState,
  dir: Direction,
): boolean {
  const v = dirToVec(dir)
  const gx = Math.floor(state.pacPosition.x)
  const gy = Math.floor(state.pacPosition.y)
  return !isPacBlocked(gx + v.x, gy + v.y, state)
}

function distanceToTileCenter(px: number, py: number): number {
  const cx = Math.floor(px) + 0.5
  const cy = Math.floor(py) + 0.5
  return Math.abs(px - cx) + Math.abs(py - cy)
}

/** True when Pac is "in" the cell enough to eat pellets / fruit (center-based). */
export function canCollectPelletOrFruitAtPosition(pos: Vec2): boolean {
  const cx = Math.floor(pos.x) + 0.5
  const cy = Math.floor(pos.y) + 0.5
  const dx = pos.x - cx
  const dy = pos.y - cy
  return dx * dx + dy * dy <= PELLET_COLLECT_RADIUS * PELLET_COLLECT_RADIUS
}

/**
 * Resolve movement direction: instant 180°; 90° only when aligned to tile center and legal.
 */
function resolvePacDirectionForFrame(
  state: GameState,
  desiredDir: Direction,
): Direction {
  const dir = state.pacDirection
  if (desiredDir === dir) return dir

  if (isOppositeDir(dir, desiredDir)) {
    return desiredDir
  }

  if (
    distanceToTileCenter(state.pacPosition.x, state.pacPosition.y) >
    TURN_CENTER_EPS
  ) {
    return dir
  }
  if (!canPacStartTurnInDirection(state, desiredDir)) {
    return dir
  }
  return desiredDir
}

/**
 * Blocked by a wall → stay on the **center** of the last open tile (…+0.5), never near x.0.
 * Also handles same-column moves (floor unchanged) where the loop below would not run.
 */
function clampPacAxis(
  state: GameState,
  prev: Vec2,
  next: Vec2,
  dir: Direction,
): Vec2 {
  const v = dirToVec(dir)
  let nx = next.x
  let ny = next.y

  if (v.x !== 0) {
    const gy = Math.floor(prev.y)
    const laneY = gy + 0.5
    ny = laneY

    if (v.x > 0) {
      const from = Math.floor(prev.x)
      const to = Math.floor(nx)
      if (isPacBlocked(from + 1, gy, state)) {
        nx = Math.min(nx, from + 0.5)
      }
      for (let c = from + 1; c <= to; c++) {
        if (isPacBlocked(c, gy, state)) {
          nx = Math.min(nx, c - 0.5)
          break
        }
      }
    } else {
      const from = Math.floor(prev.x)
      const to = Math.floor(nx)
      if (isPacBlocked(from - 1, gy, state)) {
        nx = Math.max(nx, from + 0.5)
      }
      for (let c = from - 1; c >= to; c--) {
        if (isPacBlocked(c, gy, state)) {
          nx = Math.max(nx, c + 1.5)
          break
        }
      }
    }

    if (isPacBlocked(Math.floor(nx), gy, state)) {
      nx = Math.floor(prev.x) + 0.5
    }
  } else if (v.y !== 0) {
    const gx = Math.floor(prev.x)
    const laneX = gx + 0.5
    nx = laneX

    if (v.y > 0) {
      const from = Math.floor(prev.y)
      const to = Math.floor(ny)
      if (isPacBlocked(gx, from + 1, state)) {
        ny = Math.min(ny, from + 0.5)
      }
      for (let r = from + 1; r <= to; r++) {
        if (isPacBlocked(gx, r, state)) {
          ny = Math.min(ny, r - 0.5)
          break
        }
      }
    } else {
      const from = Math.floor(prev.y)
      const to = Math.floor(ny)
      if (isPacBlocked(gx, from - 1, state)) {
        ny = Math.max(ny, from + 0.5)
      }
      for (let r = from - 1; r >= to; r--) {
        if (isPacBlocked(gx, r, state)) {
          ny = Math.max(ny, r + 1.5)
          break
        }
      }
    }

    if (isPacBlocked(gx, Math.floor(ny), state)) {
      ny = Math.floor(prev.y) + 0.5
    }
  }

  return { x: nx, y: ny }
}

/** Continuous Pac-Man: one source of truth for position + direction. */
export function advancePacmanContinuous(
  state: GameState,
  dt: number,
  desiredDir: Direction,
): GameState {
  const dir = resolvePacDirectionForFrame(state, desiredDir)
  const v = dirToVec(dir)
  const speed = PAC_TILES_PER_SEC
  let x = state.pacPosition.x
  let y = state.pacPosition.y

  const turned90 =
    dir !== state.pacDirection && !isOppositeDir(state.pacDirection, dir)

  if (turned90) {
    x = Math.floor(x) + 0.5
    y = Math.floor(y) + 0.5
  } else if (dir === 'left' || dir === 'right') {
    y = Math.floor(y) + 0.5
  } else {
    x = Math.floor(x) + 0.5
  }

  const prev = { x, y }
  const nx = x + v.x * speed * dt
  const ny = y + v.y * speed * dt
  const clamped = clampPacAxis(state, prev, { x: nx, y: ny }, dir)

  // Limited warp snapping:
  // Allow Pac to briefly leave the visible [0..bw) range (renderer can show it under warp),
  // then snap him back only if he goes further than ~1 tile outside.
  const bw = state.leftHalf.width + state.rightHalf.width
  const bh = state.leftHalf.height
  const snapIfBeyond = 1

  let sx = clamped.x
  let sy = clamped.y
  if (sx < -snapIfBeyond) sx += bw
  else if (sx >= bw + snapIfBeyond) sx -= bw
  if (sy < -snapIfBeyond) sy += bh
  else if (sy >= bh + snapIfBeyond) sy -= bh

  return {
    ...state,
    pacPosition: { x: sx, y: sy },
    // Rendering now double-draws at both wrapped positions, so warp offsets are unused.
    pacWarpOffsetX: 0,
    pacWarpOffsetY: 0,
    pacDirection: dir,
  }
}
