import { Tile, type LevelHalf } from './levels'
import type { GameState } from '../data/types'

export function countPellets(half: LevelHalf): number {
  return half.tiles.reduce(
    (acc, row) =>
      acc +
      row.filter((t) => t === Tile.Pellet || t === Tile.PowerPellet).length,
    0,
  )
}

export function isWall(globalX: number, y: number, state: GameState): boolean {
  const { leftHalf, rightHalf } = state
  const leftWidth = leftHalf.width
  const fullWidth = leftHalf.width + rightHalf.width
  const h = leftHalf.height

  const wrapX = (x: number) => ((x % fullWidth) + fullWidth) % fullWidth
  const wrapY = (yy: number) => ((yy % h) + h) % h

  const wx = wrapX(globalX)
  const wy = wrapY(y)

  if (wx < leftWidth) {
    return leftHalf.tiles[wy]![wx] === Tile.Wall
  }

  const localX = wx - leftWidth
  return rightHalf.tiles[wy]![localX] === Tile.Wall
}

export function isExitTile(globalX: number, y: number, state: GameState): boolean {
  return tileType(globalX, y, state) === Tile.Exit
}

export function isGhostHouseTile(
  globalX: number,
  y: number,
  state: GameState,
): boolean {
  return tileType(globalX, y, state) === Tile.GhostHouse
}

/** Pac cannot enter walls, exits, or ghost house cells. */
export function isPacBlocked(globalX: number, y: number, state: GameState): boolean {
  const t = tileType(globalX, y, state)
  return t === Tile.Wall || t === Tile.Exit || t === Tile.GhostHouse
}

/**
 * Ghost movement blocker for one step from `from` -> `to`.
 * - Walls always block.
 * - Exit blocks unless ghost is currently on Exit or GhostHouse (door behavior).
 * - GhostHouse is allowed for ghosts.
 */
export function isGhostStepBlocked(
  fromX: number,
  fromY: number,
  toX: number,
  toY: number,
  state: GameState,
  opts?: { allowExitDoor?: boolean; restrictToGhostHouse?: boolean },
): boolean {
  const to = tileType(toX, toY, state)
  if (opts?.restrictToGhostHouse) return to !== Tile.GhostHouse
  if (to === Tile.Wall) return true
  if (to !== Tile.Exit) return false
  if (opts?.allowExitDoor) return false
  const from = tileType(fromX, fromY, state)
  return from !== Tile.Exit && from !== Tile.GhostHouse
}

export function tileType(globalX: number, y: number, state: GameState): Tile {
  const { leftHalf, rightHalf } = state
  const leftWidth = leftHalf.width
  const fullWidth = leftHalf.width + rightHalf.width

  const h = leftHalf.height
  const wrapX = (x: number) => ((x % fullWidth) + fullWidth) % fullWidth
  const wrapY = (yy: number) => ((yy % h) + h) % h

  const wx = wrapX(globalX)
  const wy = wrapY(y)

  if (wx < leftWidth) {
    return leftHalf.tiles[wy]![wx]!
  }

  const localX = wx - leftWidth
  return rightHalf.tiles[wy]![localX]!
}

export function setTileType(
  globalX: number,
  y: number,
  state: GameState,
  type: Tile,
): GameState {
  const leftWidth = state.leftHalf.width

  if (globalX < leftWidth) {
    const tiles = state.leftHalf.tiles.map((row) => [...row])
    tiles[y][globalX] = type
    return {
      ...state,
      leftHalf: { ...state.leftHalf, tiles },
    }
  }

  const localX = globalX - leftWidth
  const tiles = state.rightHalf.tiles.map((row) => [...row])
  tiles[y][localX] = type
  return {
    ...state,
    rightHalf: { ...state.rightHalf, tiles },
  }
}
