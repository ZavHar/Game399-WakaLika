import { Tile } from '../board/levels'
import type { Vec2 } from '../board/levels'
import { isPacBlocked, isWall, tileType } from '../board/grid'
import { findPathBfs, randomWalkableTileExcluding } from './pathfinding'
import type { GameState, Ghost } from '../data/types'
import { dirToVec, randomChoice, vecEquals } from '../data/utils'

/** Manhattan distance in tiles — orange ghost "flees" when within this range. */
export const ORANGE_SCATTER_DISTANCE = 8

export function pacTile(state: GameState): Vec2 {
  return {
    x: Math.floor(state.pacPosition.x),
    y: Math.floor(state.pacPosition.y),
  }
}

/** Pac-Man's tile as a path goal; if that cell is invalid, snap to nearest walkable. */
export function pacGoalTile(state: GameState): Vec2 {
  const pt = pacTile(state)
  if (!isPacBlocked(pt.x, pt.y, state)) return { ...pt }
  return nearestWalkableTile(state, pt.x, pt.y)
}

/**
 * Closest walkable tile to (gx, gy) (by Euclidean distance squared).
 * Used when an AI target lands in a wall or OOB.
 */
export function nearestWalkableTile(
  state: GameState,
  gx: number,
  gy: number,
): Vec2 {
  const bw = state.leftHalf.width + state.rightHalf.width
  const bh = state.leftHalf.height
  let best: Vec2 | null = null
  let bestD = Infinity
  for (let y = 0; y < bh; y++) {
    for (let x = 0; x < bw; x++) {
      if (isWall(x, y, state)) continue
      const t = tileType(x, y, state)
      if (t === Tile.Exit || t === Tile.GhostHouse) continue
      const dxRaw = Math.abs(x - gx)
      const dyRaw = Math.abs(y - gy)
      const dx = Math.min(dxRaw, bw - dxRaw)
      const dy = Math.min(dyRaw, bh - dyRaw)
      const d = dx ** 2 + dy ** 2
      if (d < bestD) {
        bestD = d
        best = { x, y }
      }
    }
  }
  return best ?? { x: 0, y: 0 }
}

function manhattan(a: Vec2, b: Vec2, bw: number, bh: number): number {
  const dxRaw = Math.abs(a.x - b.x)
  const dyRaw = Math.abs(a.y - b.y)
  const dx = Math.min(dxRaw, bw - dxRaw)
  const dy = Math.min(dyRaw, bh - dyRaw)
  return dx + dy
}

/**
 * Up to 4 tiles ahead of Pac-Man along travel direction.
 * If a farther tile is invalid/unreachable, fall back progressively: 3, 2, 1, then Pac-Man's tile.
 */
function pinkTargetTile(
  state: GameState,
  pac: Vec2,
  ghostPos: Vec2,
  ghostFacing: GameState['ghosts'][number]['direction'],
): Vec2 {
  const { x: dx, y: dy } = dirToVec(state.pacDirection)
  const bw = state.leftHalf.width + state.rightHalf.width
  const bh = state.leftHalf.height
  for (let k = 4; k >= 0; k--) {
    const x = pac.x + dx * k
    const y = pac.y + dy * k
    // Look-ahead should not "wrap off" the board when projecting tiles in Pac's
    // facing direction. If the projection leaves the board, Pac would hit an edge/wall.
    if (x < 0 || x >= bw || y < 0 || y >= bh) continue
    if (!isPacBlocked(x, y, state) && findPathBfs(ghostPos, { x, y }, state, ghostFacing)) {
      return { x, y }
    }
  }
  const fallback = pacGoalTile(state)
  if (findPathBfs(ghostPos, fallback, state, ghostFacing)) return fallback
  return randomWalkableTileExcluding(state, ghostPos)
}

/**
 * Each ghost gets a chase/scatter target every frame (classic-style roles).
 * Orange: chase like red when far; when near Pac-Man, wander to random tiles until far again.
 */
export function updateGhostDestinations(state: GameState): GameState {
  const pt = pacGoalTile(state)
  const bw = state.leftHalf.width + state.rightHalf.width
  const bh = state.leftHalf.height
  const redGhost = state.ghosts.find((g) => g.id === 'red')
  if (!redGhost) return state

  type IncapPhase = NonNullable<Ghost['incapacitatedPhase']>

  const randomGhostHouseTile = (exclude?: Vec2): Vec2 => {
    const candidates: Vec2[] = []
    for (let y = 0; y < bh; y++) {
      for (let x = 0; x < bw; x++) {
        if (exclude && x === exclude.x && y === exclude.y) continue
        if (tileType(x, y, state) === Tile.GhostHouse) candidates.push({ x, y })
      }
    }
    if (candidates.length === 0) return randomWalkableTileExcluding(state, exclude ?? { x: 0, y: 0 })
    return randomChoice(candidates)
  }

  const ghosts: Ghost[] = state.ghosts.map((g): Ghost => {
    let destination: Vec2

    if (g.isIncapacitated) {
      const phase: IncapPhase = g.incapacitatedPhase ?? 'roam'
      const roamsLeft = g.incapacitatedRoamsLeft ?? 3
      const waitMs = g.incapacitatedWaitMs ?? 0
      const onGhostHouse = tileType(g.position.x, g.position.y, state) === Tile.GhostHouse

      if (phase === 'roam') {
        // Start with a random walk target, repeat 3 times.
        if (!g.incapacitatedPhase) {
          destination = randomWalkableTileExcluding(state, g.position)
          return {
            ...g,
            destination,
            incapacitatedPhase: 'roam',
            incapacitatedRoamsLeft: 3,
          }
        }

        if (vecEquals(g.position, g.destination)) {
          const nextRoamsLeft = roamsLeft - 1
          if (nextRoamsLeft > 0) {
            destination = randomWalkableTileExcluding(state, g.position)
            return {
              ...g,
              destination,
              incapacitatedPhase: 'roam',
              incapacitatedRoamsLeft: nextRoamsLeft,
            }
          }
          destination = randomGhostHouseTile(g.position)
          return {
            ...g,
            destination,
            incapacitatedPhase: 'return_to_house',
            incapacitatedRoamsLeft: 0,
          }
        }
        return g
      }

      if (phase === 'return_to_house') {
        // After 3 roams, go to a ghost house tile.
        if (vecEquals(g.position, g.destination)) {
          if (onGhostHouse) {
            const nextWaitMs = 2000 + Math.floor(Math.random() * 3001) // 2..5 seconds
            destination = randomGhostHouseTile(g.position)
            return {
              ...g,
              destination,
              incapacitatedPhase: 'waiting_in_house',
              incapacitatedWaitMs: nextWaitMs,
            }
          }
          // If we somehow reached a non-ghost-house tile, keep searching.
          destination = randomGhostHouseTile(g.position)
          return { ...g, destination, incapacitatedPhase: 'return_to_house' }
        }
        return g
      }

      // waiting_in_house
      if (waitMs <= 0) {
        // Countdown finished: return to normal state.
        // Destination will be set by normal AI logic below this tick.
        g = {
          ...g,
          isIncapacitated: false,
          incapacitatedPhase: undefined,
          incapacitatedRoamsLeft: 0,
          incapacitatedWaitMs: 0,
        }
      } else {
        // While waiting: keep moving among ghost house tiles.
        if (vecEquals(g.position, g.destination)) {
          destination = randomGhostHouseTile(g.position)
          return { ...g, destination, incapacitatedPhase: 'waiting_in_house', incapacitatedWaitMs: waitMs }
        }
        return g
      }
    }

    switch (g.id) {
      case 'red':
        destination = { ...pt }
        break

      case 'pink':
        destination = pinkTargetTile(state, pacTile(state), g.position, g.direction)
        break

      case 'blue': {
        const rx = redGhost.position.x
        const ry = redGhost.position.y
        const tx = pt.x + (pt.x - rx)
        const ty = pt.y + (pt.y - ry)
        if (!isWall(tx, ty, state)) {
          destination = { x: tx, y: ty }
        } else {
          destination = nearestWalkableTile(state, tx, ty)
        }
        break
      }

      case 'orange': {
        const near = manhattan(g.position, pt, bw, bh) <= ORANGE_SCATTER_DISTANCE
        const chaseGoal = pt
        if (near) {
          // Enter scatter immediately when becoming "near", rather than freezing on
          // a stale chase target tile.
          const enteringScatter = !g.isScattering
          const reachedGoal = vecEquals(g.position, g.destination)
          if (enteringScatter || reachedGoal) {
            destination = randomWalkableTileExcluding(state, g.position)
          } else {
            destination = g.destination
          }
          return { ...g, destination, isScattering: true }
        } else {
          destination = { ...chaseGoal }
          return { ...g, destination, isScattering: false }
        }
      }

      default:
        destination = g.destination
    }

    return { ...g, destination }
  })

  return { ...state, ghosts }
}
