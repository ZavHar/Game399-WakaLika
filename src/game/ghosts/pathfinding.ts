import { Tile } from '../board/levels'
import type { Vec2 } from '../board/levels'
import { isGhostStepBlocked, isWall, tileType } from '../board/grid'
import type { Direction, GameState } from '../data/types'
import { dirToVec, oppositeDirection, randomChoice } from '../data/utils'

function cellKey(x: number, y: number) {
  return `${x},${y}`
}

const dirs = [
  [0, -1],
  [0, 1],
  [-1, 0],
  [1, 0],
] as const

function wrapCoord(val: number, size: number) {
  return ((val % size) + size) % size
}

function countWalkableNeighbors(
  p: Vec2,
  state: GameState,
  opts?: { allowExitDoor?: boolean; restrictToGhostHouse?: boolean },
): number {
  let n = 0
  for (const [dx, dy] of dirs) {
    if (!isGhostStepBlocked(p.x, p.y, p.x + dx, p.y + dy, state, opts)) n++
  }
  return n
}

function isBackNeighbor(
  start: Vec2,
  facing: Direction,
  nx: number,
  ny: number,
  bw: number,
  bh: number,
): boolean {
  const v = dirToVec(oppositeDirection(facing))
  const ex = wrapCoord(start.x + v.x, bw)
  const ey = wrapCoord(start.y + v.y, bh)
  return nx === ex && ny === ey
}

/**
 * BFS shortest path. When `facing` is set, the first step from `start` will not
 * be a 180° (into the tile behind the ghost) unless that is the only walkable
 * neighbor (dead end).
 */
function findPathBfsCore(
  start: Vec2,
  goal: Vec2,
  state: GameState,
  facing: Direction | undefined,
  forbidFirstStepReverse: boolean,
  bw: number,
  bh: number,
  opts?: { allowExitDoor?: boolean; restrictToGhostHouse?: boolean },
): Vec2[] | null {
  if (start.x === goal.x && start.y === goal.y) return [start]
  if (isWall(goal.x, goal.y, state)) return null

  const queue: Vec2[] = [{ ...start }]
  const visited = new Set<string>([cellKey(start.x, start.y)])
  const parent = new Map<string, string | null>()
  parent.set(cellKey(start.x, start.y), null)

  const skipBack =
    forbidFirstStepReverse &&
    facing !== undefined &&
    countWalkableNeighbors(start, state, opts) > 1

  while (queue.length > 0) {
    const cur = queue.shift()!
    if (cur.x === goal.x && cur.y === goal.y) {
      const out: Vec2[] = []
      let k: string | null = cellKey(cur.x, cur.y)
      while (k) {
        const [sx, sy] = k.split(',').map(Number)
        out.push({ x: sx, y: sy })
        k = parent.get(k) ?? null
      }
      return out.reverse()
    }
    for (const [dx, dy] of dirs) {
      const nx = wrapCoord(cur.x + dx, bw)
      const ny = wrapCoord(cur.y + dy, bh)
      if (isGhostStepBlocked(cur.x, cur.y, nx, ny, state, opts)) continue
      if (
        skipBack &&
        cur.x === start.x &&
        cur.y === start.y &&
        facing !== undefined &&
        isBackNeighbor(start, facing, nx, ny, bw, bh)
      ) {
        continue
      }
      const nk = cellKey(nx, ny)
      if (visited.has(nk)) continue
      visited.add(nk)
      parent.set(nk, cellKey(cur.x, cur.y))
      queue.push({ x: nx, y: ny })
    }
  }
  return null
}

/**
 * Shortest path in tile steps from `start` to `goal` (inclusive), or null if unreachable.
 * Pass `facing` for ghosts: avoids an immediate 180° from `start` when other routes exist.
 */
export function findPathBfs(
  start: Vec2,
  goal: Vec2,
  state: GameState,
  facing?: Direction,
  opts?: { allowExitDoor?: boolean; restrictToGhostHouse?: boolean },
): Vec2[] | null {
  const bw = state.leftHalf.width + state.rightHalf.width
  const bh = state.leftHalf.height
  const ns: Vec2 = {
    x: wrapCoord(start.x, bw),
    y: wrapCoord(start.y, bh),
  }
  const ng: Vec2 = {
    x: wrapCoord(goal.x, bw),
    y: wrapCoord(goal.y, bh),
  }
  if (facing !== undefined) {
    const noReverse = findPathBfsCore(ns, ng, state, facing, true, bw, bh, opts)
    if (noReverse !== null) return noReverse
  }
  return findPathBfsCore(ns, ng, state, facing, false, bw, bh, opts)
}

/** Any random open cell (for ghost goals). */
export function randomWalkableTile(state: GameState): Vec2 {
  const bw = state.leftHalf.width + state.rightHalf.width
  const bh = state.leftHalf.height
  const candidates: Vec2[] = []
  for (let y = 0; y < bh; y++) {
    for (let x = 0; x < bw; x++) {
      if (isWall(x, y, state)) continue
      const t = tileType(x, y, state)
      if (t === Tile.Exit || t === Tile.GhostHouse) continue
      candidates.push({ x, y })
    }
  }
  if (candidates.length === 0) return { x: 0, y: 0 }
  return randomChoice(candidates)
}

/** Prefer a tile different from `exclude` when possible. */
export function randomWalkableTileExcluding(
  state: GameState,
  exclude: Vec2,
): Vec2 {
  const bw = state.leftHalf.width + state.rightHalf.width
  const bh = state.leftHalf.height
  const candidates: Vec2[] = []
  for (let y = 0; y < bh; y++) {
    for (let x = 0; x < bw; x++) {
      if (isWall(x, y, state)) continue
      if (x === exclude.x && y === exclude.y) continue
      const t = tileType(x, y, state)
      if (t === Tile.Exit || t === Tile.GhostHouse) continue
      candidates.push({ x, y })
    }
  }
  if (candidates.length === 0) return randomWalkableTile(state)
  return randomChoice(candidates)
}
