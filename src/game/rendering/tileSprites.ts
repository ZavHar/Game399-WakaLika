import exitWhiteUrl from '../../assets/tiles/exit-white.svg'
import ghostHouseWhiteUrl from '../../assets/tiles/ghost-house-white.svg'
import wallAtlasUrl from '../../assets/tiles/maze-wall-atlas.png'
import pelletWhiteUrl from '../../assets/tiles/pellet-white.svg'

const WALL_ATLAS_TILE_SIZE = 32
const WALL_ATLAS_COLS = 7

type WallSourceRect = {
  sx: number
  sy: number
  sw: number
  sh: number
}

type SpriteSet = {
  pellet: HTMLImageElement
  exit: HTMLImageElement
  ghostHouse: HTMLImageElement
  wallAtlas: HTMLImageElement
}

let loadedSpriteSet: SpriteSet | null = null
let loadingPromise: Promise<SpriteSet> | null = null

function loadImage(src: string): Promise<HTMLImageElement> {
  return new Promise((resolve, reject) => {
    const img = new Image()
    img.onload = () => resolve(img)
    img.onerror = () => reject(new Error(`Failed to load sprite: ${src}`))
    img.src = src
  })
}

/**
 * 8-neighbor bit order: N, NE, E, SE, S, SW, W, NW
 */
export function wallNeighborMask(getIsWall: (dx: number, dy: number) => boolean): number {
  const bits = [
    [0, -1],
    [1, -1],
    [1, 0],
    [1, 1],
    [0, 1],
    [-1, 1],
    [-1, 0],
    [-1, -1],
  ] as const
  let out = 0
  for (let i = 0; i < bits.length; i++) {
    const [dx, dy] = bits[i]
    if (getIsWall(dx, dy)) out |= 1 << i
  }
  return out
}

/**
 * Source tile index lookup from rhdunn/maze-tileset `tiles.256` (CC-BY-SA 3.0).
 * Indexed by 8-neighbor bitmask value encoded as:
 * NW=16, N=1, NE=64, W=4, E=8, SW=32, S=2, SE=128.
 */
const WALL_TILE_LOOKUP_256: number[] = [
  16, 7, 6, 3, 5, 11, 9, 12, 4, 10, 8, 13, 2, 14, 15, 1,
  16, 7, 6, 3, 5, 25, 9, 45, 4, 10, 8, 13, 2, 41, 15, 37,
  16, 7, 6, 3, 5, 11, 23, 43, 4, 10, 8, 13, 2, 14, 39, 35,
  16, 7, 6, 3, 5, 25, 23, 19, 4, 10, 8, 13, 2, 41, 39, 31,
  16, 7, 6, 3, 5, 11, 9, 12, 4, 24, 8, 44, 2, 40, 15, 36,
  16, 7, 6, 3, 5, 25, 9, 45, 4, 24, 8, 44, 2, 21, 15, 33,
  16, 7, 6, 3, 5, 11, 23, 43, 4, 24, 8, 44, 2, 40, 39, 46,
  16, 7, 6, 3, 5, 25, 23, 19, 4, 24, 8, 44, 2, 21, 39, 29,
  16, 7, 6, 3, 5, 11, 9, 12, 4, 10, 22, 42, 2, 14, 38, 34,
  16, 7, 6, 3, 5, 25, 9, 45, 4, 10, 22, 42, 2, 41, 38, 47,
  16, 7, 6, 3, 5, 11, 23, 43, 4, 10, 22, 42, 2, 14, 20, 32,
  16, 7, 6, 3, 5, 25, 23, 19, 4, 10, 22, 42, 2, 41, 20, 27,
  16, 7, 6, 3, 5, 11, 9, 12, 4, 24, 22, 18, 2, 40, 38, 30,
  16, 7, 6, 3, 5, 25, 9, 45, 4, 24, 22, 18, 2, 21, 38, 28,
  16, 7, 6, 3, 5, 11, 23, 43, 4, 24, 22, 18, 2, 40, 20, 26,
  16, 7, 6, 3, 5, 25, 23, 19, 4, 24, 22, 18, 2, 21, 20, 17,
]

function toTileSetMask(mask: number): number {
  const n = (mask & (1 << 0)) !== 0
  const ne = (mask & (1 << 1)) !== 0
  const e = (mask & (1 << 2)) !== 0
  const se = (mask & (1 << 3)) !== 0
  const s = (mask & (1 << 4)) !== 0
  const sw = (mask & (1 << 5)) !== 0
  const w = (mask & (1 << 6)) !== 0
  const nw = (mask & (1 << 7)) !== 0

  let out = 0
  if (n) out += 1
  if (s) out += 2
  if (w) out += 4
  if (e) out += 8
  if (nw) out += 16
  if (sw) out += 32
  if (ne) out += 64
  if (se) out += 128
  return out
}

export function getWallSpriteRect(mask: number): WallSourceRect {
  const tileSetMask = toTileSetMask(mask)
  const tileIndex = WALL_TILE_LOOKUP_256[tileSetMask] ?? 0
  const sx = (tileIndex % WALL_ATLAS_COLS) * WALL_ATLAS_TILE_SIZE
  const sy = Math.floor(tileIndex / WALL_ATLAS_COLS) * WALL_ATLAS_TILE_SIZE
  return { sx, sy, sw: WALL_ATLAS_TILE_SIZE, sh: WALL_ATLAS_TILE_SIZE }
}

export function getBoardSpriteSet(): SpriteSet | null {
  if (loadedSpriteSet) return loadedSpriteSet
  if (!loadingPromise) {
    loadingPromise = Promise.all([
      loadImage(pelletWhiteUrl),
      loadImage(exitWhiteUrl),
      loadImage(ghostHouseWhiteUrl),
      loadImage(wallAtlasUrl),
    ]).then(([pellet, exit, ghostHouse, wallAtlas]) => {
      loadedSpriteSet = { pellet, exit, ghostHouse, wallAtlas }
      return loadedSpriteSet
    })
  }
  return null
}
