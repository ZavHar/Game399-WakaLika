/**
 * Tile layouts live in `levelGrids.json`:
 * 0 = empty, 1 = pellet, 2 = wall, 3 = exit, 4 = ghost house, 5 = power pellet.
 * Edit levels via the in-app editor at `/editor` (dev server writes the JSON file).
 */
import rawGrids from '../data/levelGrids.json'

export const enum Tile {
  Empty = 0,
  Pellet = 1,
  Wall = 2,
  Exit = 3,
  GhostHouse = 4,
  PowerPellet = 5,
}

export interface Vec2 {
  x: number
  y: number
}

export interface LevelHalf {
  id: string
  width: number
  height: number
  tiles: Tile[][]
}

/** One side of the map (left or mirrored right). */
export const HALF_WIDTH = 14

/** Full playfield: left half + right half (14 + 14). */
export const LEVEL_WIDTH = HALF_WIDTH * 2
/** Full playfield height in tiles. */
export const LEVEL_HEIGHT = 36

/** Mirror a half-level horizontally (right side = flipped left). */
export function flipLevelHalfHorizontally(half: LevelHalf): LevelHalf {
  return {
    ...half,
    id: `${half.id}-mirrored`,
    tiles: half.tiles.map((row) => [...row].reverse()),
  }
}

/** JSON stores tile IDs matching `Tile` enum (0..4). */
function gridFromData(grid: number[][]): Tile[][] {
  return grid.map((row) => row.map((n) => n as Tile))
}

type LevelGridsFile = Record<string, number[][]>

const grids = rawGrids as LevelGridsFile

/** Left-side maze halves only; mirror with flipLevelHalfHorizontally() for the right side. */
export const HALF_LAYOUTS: LevelHalf[] = Object.keys(grids)
  .sort((a, b) => a.localeCompare(b))
  .map((key) => ({
    id: key,
    width: HALF_WIDTH,
    height: LEVEL_HEIGHT,
    tiles: gridFromData(grids[key]!),
  }))
