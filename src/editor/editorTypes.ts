export const enum EditorTile {
  Empty = 0,
  Pellet = 1,
  Wall = 2,
  Exit = 3,
  GhostHouse = 4,
  PowerPellet = 5,
}

export type TileValue = 0 | 1 | 2 | 3 | 4 | 5

export function clampTile(n: number): TileValue {
  if (n === 0 || n === 1 || n === 2 || n === 3 || n === 4 || n === 5) return n
  return 2
}

