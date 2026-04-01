import type { Vec2 } from '../board/levels'
import { isGhostStepBlocked, tileType } from '../board/grid'
import { Tile } from '../board/levels'
import {
  findPathBfs,
  randomWalkableTileExcluding,
} from './pathfinding'
import type { Direction, GameState } from '../data/types'
import { dirToVec, oppositeDirection, randomChoice } from '../data/utils'

function wrapCoord(val: number, size: number) {
  return ((val % size) + size) % size
}

function directionFromStep(from: Vec2, to: Vec2, bw: number, bh: number): Direction {
  const rightX = wrapCoord(from.x + 1, bw)
  const leftX = wrapCoord(from.x - 1, bw)
  const downY = wrapCoord(from.y + 1, bh)

  if (to.x === rightX && to.y === from.y) return 'right'
  if (to.x === leftX && to.y === from.y) return 'left'
  if (to.y === downY && to.x === from.x) return 'down'
  return 'up'
}

/** Move one ghost one tile along BFS path toward `destination`. */
export function tryMoveGhostOneTile(
  state: GameState,
  ghostIndex: number,
): GameState {
  const ghost = state.ghosts[ghostIndex]
  let dest = ghost.destination
  const pos = ghost.position
  const bw = state.leftHalf.width + state.rightHalf.width
  const bh = state.leftHalf.height

  const facing = ghost.direction
  const onGhostHouse = tileType(pos.x, pos.y, state) === Tile.GhostHouse
  const allowExitDoor =
    ghost.isIncapacitated && ghost.incapacitatedPhase === 'return_to_house'
  const restrictToGhostHouse =
    ghost.isIncapacitated &&
    ghost.incapacitatedPhase === 'waiting_in_house' &&
    onGhostHouse

  const isFeared = !ghost.isIncapacitated && state.fearMs > 0

  if (isFeared) {
    const reverse = oppositeDirection(facing)
    const candidates: Direction[] = []
    const dirs: Direction[] = ['up', 'down', 'left', 'right']
    for (const d of dirs) {
      if (d === reverse) continue
      const v = dirToVec(d)
      const nx = pos.x + v.x
      const ny = pos.y + v.y
      if (!isGhostStepBlocked(pos.x, pos.y, nx, ny, state)) candidates.push(d)
    }

    // Dead end: allow reverse if it's the only escape.
    if (candidates.length === 0) {
      const rv = dirToVec(reverse)
      const rx = pos.x + rv.x
      const ry = pos.y + rv.y
      if (!isGhostStepBlocked(pos.x, pos.y, rx, ry, state)) {
        const target: Vec2 = { x: rx, y: ry }
        return {
          ...state,
          ghosts: state.ghosts.map((g, i) =>
            i === ghostIndex
              ? { ...g, direction: reverse, position: target, destination: dest }
              : g,
          ),
        }
      }
      return state
    }

    // Keep moving forward; at intersections, randomly turn (never backwards unless forced above).
    const forward = facing
    const hasForward = candidates.includes(forward)
    const hasTurnOption = candidates.some((d) => d !== forward)
    const isIntersection = hasForward && hasTurnOption
    let chosen = forward
    if (!hasForward) {
      chosen = randomChoice(candidates)
    } else if (isIntersection) {
      const turnChoices = candidates.filter((d) => d !== forward)
      // Bias to keep moving forward, but still randomize at intersections.
      chosen = Math.random() < 0.65 ? forward : randomChoice(turnChoices)
    }

    const v = dirToVec(chosen)
    const target: Vec2 = { x: pos.x + v.x, y: pos.y + v.y }
    if (isGhostStepBlocked(pos.x, pos.y, target.x, target.y, state)) return state
    return {
      ...state,
      ghosts: state.ghosts.map((g, i) =>
        i === ghostIndex
          ? { ...g, direction: chosen, position: target, destination: dest }
          : g,
      ),
    }
  }

  let path = findPathBfs(pos, dest, state, facing, {
    allowExitDoor,
    restrictToGhostHouse,
  })
  if (!path) {
    dest = randomWalkableTileExcluding(state, pos)
    path = findPathBfs(pos, dest, state, facing, {
      allowExitDoor,
      restrictToGhostHouse,
    })
  }

  // At goal (or no path): stand still; destinations come from `updateGhostDestinations`.
  if (!path || path.length < 2) {
    return {
      ...state,
      ghosts: state.ghosts.map((g, i) =>
        i === ghostIndex ? { ...g, destination: dest } : g,
      ),
    }
  }

  const nextCell = path[1]
  const chosenDir = directionFromStep(pos, nextCell, bw, bh)
  const target: Vec2 = { x: nextCell.x, y: nextCell.y }

  if (
    isGhostStepBlocked(pos.x, pos.y, target.x, target.y, state, {
      allowExitDoor,
      restrictToGhostHouse,
    })
  ) {
    return {
      ...state,
      ghosts: state.ghosts.map((g, i) =>
        i === ghostIndex ? { ...g, destination: dest } : g,
      ),
    }
  }

  return {
    ...state,
    ghosts: state.ghosts.map((g, i) =>
      i === ghostIndex
        ? { ...g, direction: chosenDir, position: target, destination: dest }
        : g,
    ),
  }
}
